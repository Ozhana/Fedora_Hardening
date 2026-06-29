#!/usr/bin/env bash
# ================================================================
# AEGIS TELEMETRY KURULUM BETİĞİ V10.1
# FEDORA 44 TEMİZ KURULUM İÇİN OPTİMİZE EDİLMİŞTİR
# ================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[-] KRİTİK HATA: Root yetkisi gerekli (sudo).${NC}" >&2
    exit 1
fi

echo -e "${GREEN}[*] AEGIS TELEMETRY V10.1 KURULUMU BAŞLATILIYOR...${NC}"

# -----------------------------------------------------------------
# 1. ESKİ KALINTILARI TEMİZLE
# -----------------------------------------------------------------
echo "[*] Eski servis dosyaları temizleniyor..."
systemctl stop aegis-telemetry.timer 2>/dev/null || true
systemctl stop aegis-telemetry.service 2>/dev/null || true
systemctl disable aegis-telemetry.timer 2>/dev/null || true
systemctl disable aegis-telemetry.service 2>/dev/null || true
rm -f /etc/systemd/system/aegis-telemetry.{service,timer} 2>/dev/null || true
systemctl daemon-reload

# -----------------------------------------------------------------
# 2. PARSER BETİĞİNİ OLUŞTUR
# -----------------------------------------------------------------
PARSER="/usr/local/bin/aegis-telemetry-parser.sh"
echo "[*] Parser betiği oluşturuluyor: $PARSER"

cat > "$PARSER" << 'EOF'
#!/usr/bin/env bash
# AEGIS TELEMETRY PARSER V10.1
set -euo pipefail

REPORT_DIR="/var/log/aegis"
REPORT_FILE="${REPORT_DIR}/telemetry_$(date +%Y%m%d).report"
TMP_LOG="/tmp/aegis_raw_$$.tmp"
MAX_LINES=5000

mkdir -p "$REPORT_DIR" 2>/dev/null || true

# -----------------------------------------------------------------
# LOGLARI TOPLA
# -----------------------------------------------------------------
set +e
journalctl -t fapolicyd --since "today" --no-pager 2>/dev/null | \
    tail -n $MAX_LINES | grep -E "deny_audit|deny" > "$TMP_LOG" 2>/dev/null
GREP_STATUS=$?
set -e

# -----------------------------------------------------------------
# RAPORU OLUŞTUR
# -----------------------------------------------------------------
{
    echo "================================================================="
    echo "[ AEGIS TELEMETRY RAPORU - $(date '+%Y-%m-%d %H:%M:%S') ]"
    echo "Host: $(hostname 2>/dev/null || echo 'Unknown')"
    echo "================================================================="

    if [ $GREP_STATUS -eq 1 ] || [ ! -s "$TMP_LOG" ]; then
        echo "[+] KUSURSUZ GÜN: Hiç ihlal yok."
        echo "================================================================="
        rm -f "$TMP_LOG" 2>/dev/null || true
        exit 0
    fi

    TOTAL=$(wc -l < "$TMP_LOG" 2>/dev/null || echo "0")
    echo "[!] TOPLAM ENGELLEME: $TOTAL"
    echo "-----------------------------------------------------------------"
    
    echo "[*] EN ÇOK ENGELLENEN SÜREÇLER (Top 10):"
    awk -F'exe=' '{print $2}' "$TMP_LOG" 2>/dev/null | \
        awk -F' ' '{print $1}' 2>/dev/null | \
        sort | uniq -c | sort -nr | head -10 | \
        while read count proc; do
            [ -n "$proc" ] && echo "  $count kez: $proc"
        done

    echo "-----------------------------------------------------------------"
    echo "[*] EN ÇOK ENGELLENEN DOSYALAR (Top 10):"
    awk -F'path=' '{print $2}' "$TMP_LOG" 2>/dev/null | \
        awk -F' ' '{print $1}' 2>/dev/null | \
        sort | uniq -c | sort -nr | head -10 | \
        while read count path; do
            [ -n "$path" ] && echo "  $count kez: $path"
        done

    echo "-----------------------------------------------------------------"
    echo "[*] RİSK SKORU ANALİZİ:"
    RISK=0
    if grep -q "/tmp/" "$TMP_LOG" 2>/dev/null; then
        RISK=$((RISK+10))
        echo "  [!] /tmp/ dizininde erişim engeli"
    fi
    if grep -q "/home/" "$TMP_LOG" 2>/dev/null; then
        RISK=$((RISK+5))
        echo "  [!] /home/ dizininde erişim engeli"
    fi
    if grep -q "/dev/shm" "$TMP_LOG" 2>/dev/null; then
        RISK=$((RISK+8))
        echo "  [!] /dev/shm paylaşımlı bellek erişim engeli"
    fi
    if grep -q "/etc/" "$TMP_LOG" 2>/dev/null; then
        RISK=$((RISK+15))
        echo "  [!] /etc/ dizininde erişim engeli (KRİTİK)"
    fi
    echo "  Risk Skoru: $RISK/100"
    echo "================================================================="
    echo "[i] Detaylı inceleme:"
    echo "    journalctl -t fapolicyd --since today | grep deny"
} > "$REPORT_FILE"

# -----------------------------------------------------------------
# TEMİZLİK VE ARŞİV
# -----------------------------------------------------------------
rm -f "$TMP_LOG" 2>/dev/null || true
find "$REPORT_DIR" -name "*.report" -mtime +30 -delete 2>/dev/null || true
exit 0
EOF

chmod +x "$PARSER"
echo "[+] Parser betiği oluşturuldu."

# -----------------------------------------------------------------
# 3. SYSTEMD SERVİS DOSYASI
# -----------------------------------------------------------------
echo "[*] Systemd servisi oluşturuluyor..."

cat > /etc/systemd/system/aegis-telemetry.service << EOF
[Unit]
Description=AEGIS Telemetry Parser
After=fapolicyd.service
Requires=fapolicyd.service
ConditionPathExists=/usr/sbin/fapolicyd
ConditionPathExists=$PARSER

[Service]
Type=oneshot
ExecStart=$PARSER
User=root
Nice=19
IOSchedulingClass=idle
EOF

# -----------------------------------------------------------------
# 4. SYSTEMD TIMER DOSYASI
# -----------------------------------------------------------------
echo "[*] Systemd timer oluşturuluyor..."

cat > /etc/systemd/system/aegis-telemetry.timer << EOF
[Unit]
Description=AEGIS Telemetry Timer (Daily 23:59)
Requires=fapolicyd.service

[Timer]
OnCalendar=*-*-* 23:59:00
Persistent=true
AccuracySec=1s

[Install]
WantedBy=timers.target
EOF

# -----------------------------------------------------------------
# 5. AKTİVASYON
# -----------------------------------------------------------------
echo "[*] Systemd servisleri aktifleştiriliyor..."
systemctl daemon-reload
systemctl enable aegis-telemetry.service 2>/dev/null || true
systemctl enable --now aegis-telemetry.timer 2>/dev/null || true

# -----------------------------------------------------------------
# 6. DOĞRULAMA
# -----------------------------------------------------------------
echo "================================================================="

if systemctl is-active --quiet aegis-telemetry.timer 2>/dev/null; then
    echo -e "${GREEN}[✓] TELEMETRY TIMER AKTİF${NC}"
    echo "[i] Timer durumu:"
    systemctl list-timers aegis-telemetry.timer --no-pager 2>/dev/null | grep -v "NEXT" | tail -1 || echo "    Timer aktif"
else
    echo -e "${YELLOW}[!] Timer aktif değil, manuel çalıştırma deneniyor...${NC}"
    if bash "$PARSER"; then
        echo -e "${GREEN}[✓] Parser başarıyla çalıştı.${NC}"
    else
        echo -e "${RED}[-] Parser çalıştırılamadı!${NC}"
        exit 1
    fi
fi

echo "================================================================="
echo -e "${GREEN}[✓] AEGIS TELEMETRY KURULUMU TAMAMLANDI${NC}"
echo "================================================================="
echo "  Rapor Dizini  : /var/log/aegis/"
echo "  Rapor Formatı : telemetry_YYYYMMDD.report"
echo "  Timer         : Her gece 23:59"
echo "================================================================="
echo -e "${YELLOW}[i] Manuel çalıştırmak için:${NC}"
echo "    sudo $PARSER"
echo -e "${YELLOW}[i] Raporları görmek için:${NC}"
echo "    cat /var/log/aegis/telemetry_$(date +%Y%m%d).report"
echo "================================================================="
