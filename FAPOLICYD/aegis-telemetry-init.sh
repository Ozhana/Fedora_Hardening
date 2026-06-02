#!/usr/bin/env bash
# V18_Aegis_Surface - Phase: Telemetry Pipeline
# Architecture: EUID 0, Systemd Timer, Native Journalctl Parsing, Fail-Safe Grep

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "[-] KRİTİK HATA: Bu betik Root yetkileriyle çalıştırılmalıdır." >&2
    exit 1
fi

echo "[*] V18_Aegis: Telemetri Süzgeci ve Görev Zamanlayıcı Kuruluyor..."

PARSER_BIN="/usr/local/bin/aegis-telemetry-parser.sh"
SERVICE_FILE="/etc/systemd/system/aegis-telemetry.service"
TIMER_FILE="/etc/systemd/system/aegis-telemetry.timer"

# ==========================================
# 1. PARSER SCRIPT İNŞASI
# ==========================================
echo "[*] Ayrıştırıcı (Parser) betiği oluşturuluyor: $PARSER_BIN"
cat << 'EOF' > "$PARSER_BIN"
#!/usr/bin/env bash
set -euo pipefail

REPORT_FILE="/var/log/aegis_telemetry.report"
TMP_LOG="/tmp/aegis_raw_telemetry.tmp"

# Önceki raporu arşive kaldır (Entropiyi önle)
if [ -f "$REPORT_FILE" ]; then
    mv "$REPORT_FILE" "${REPORT_FILE}.$(date +%Y%m%d)"
fi

echo "=================================================================" > "$REPORT_FILE"
echo "[ V18 AEGIS - FAPOLICYD GÜNLÜK TELEMETRİ ÖZETİ ]" >> "$REPORT_FILE"
echo "Tarih: $(date)" >> "$REPORT_FILE"
echo "=================================================================" >> "$REPORT_FILE"

# Grep'in exit 1 (bulunamadı) durumunu || true ile örtbas etmek yerine 
# set +e ile güvenli bir state check yapıyoruz.
set +e
journalctl -t fapolicyd --since "today" --no-pager | grep "deny_audit" > "$TMP_LOG"
GREP_STATUS=$?
set -e

if [ $GREP_STATUS -eq 1 ]; then
    echo "[+] KUSURSUZ GÜN: Herhangi bir deny_audit ihlali tespit edilmedi." >> "$REPORT_FILE"
    rm -f "$TMP_LOG"
    exit 0
elif [ $GREP_STATUS -ne 0 ]; then
    echo "[-] KRİTİK HATA: Journalctl logları okunamadı. Status: $GREP_STATUS" >> "$REPORT_FILE"
    exit 1
fi

echo "[!] AŞAĞIDAKİ SÜREÇLER ENFORCING MODUNDA ENGELLENECEKTİR:" >> "$REPORT_FILE"
echo "-----------------------------------------------------------------" >> "$REPORT_FILE"

# Logları ayrıştır, gereksiz gürültüyü sil ve istatistiksel frekansına göre sırala
# Regex/Awk, fapolicyd'nin exe= ve path= parametrelerini jilet gibi keser.
awk -F'exe=' '{print $2}' "$TMP_LOG" | awk -F' ' '{print "SÜREÇ: " $1}' | sort | uniq -c | sort -nr >> "$REPORT_FILE"

echo "-----------------------------------------------------------------" >> "$REPORT_FILE"
echo "[i] Detaylı hedef analizi için çalıştırın:" >> "$REPORT_FILE"
echo "    > sudo journalctl -t fapolicyd --since today | grep deny_audit" >> "$REPORT_FILE"

rm -f "$TMP_LOG"
EOF

chmod +x "$PARSER_BIN"

# ==========================================
# 2. SYSTEMD SERVICE İNŞASI
# ==========================================
echo "[*] Systemd Servisi oluşturuluyor: $SERVICE_FILE"
cat << EOF > "$SERVICE_FILE"
[Unit]
Description=V18 Aegis Fapolicyd Telemetry Parser
After=fapolicyd.service
Requires=fapolicyd.service

[Service]
Type=oneshot
ExecStart=$PARSER_BIN
User=root
EOF

# ==========================================
# 3. SYSTEMD TIMER İNŞASI (CRON ALTERNATİFİ)
# ==========================================
echo "[*] Systemd Görev Zamanlayıcısı oluşturuluyor: $TIMER_FILE"
cat << EOF > "$TIMER_FILE"
[Unit]
Description=V18 Aegis Telemetry Timer (Nightly 23:59)

[Timer]
# Her gece 23:59'da tetikle
OnCalendar=*-*-* 23:59:00
# Surface uykudaysa (Hibernate/Sleep), uyandığı an geçmiş görevi çalıştır
Persistent=true
# Rastgele gecikmeyi sıfırla, kesin saatte çalıştır
AccuracySec=1us

[Install]
WantedBy=timers.target
EOF

# ==========================================
# 4. SYSTEMD AKTİVASYON
# ==========================================
echo "[*] Systemd daemon yeniden yükleniyor..."
sudo systemctl daemon-reload

echo "[*] Aegis Telemetri Zamanlayıcısı (Timer) aktifleştiriliyor..."
sudo systemctl enable --now aegis-telemetry.timer

if systemctl is-active --quiet aegis-telemetry.timer; then
    echo "================================================================="
    echo "[✓] TELEMETRİ TÜNELİ BAŞARIYLA İNŞA EDİLDİ."
    echo "[i] Timer Durumu:"
    systemctl list-timers aegis-telemetry.timer --no-pager
    echo "================================================================="
    echo "[i] Raporlar her gece 23:59'da şu konuma yazılacaktır:"
    echo "    > /var/log/aegis_telemetry.report"
    echo "================================================================="
else
    echo "[-] KRİTİK HATA: Timer başlatılamadı!" >&2
    exit 1
fi
