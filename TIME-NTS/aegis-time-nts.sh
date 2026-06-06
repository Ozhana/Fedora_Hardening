#!/usr/bin/env bash
# V30_AEGIS: Chrony NTS (Network Time Security) Zırhı - Absolute Zero Assumption
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $EUID -ne 0 ]]; then
    echo "[FATAL] Bu betik root (sudo) yetkisiyle çalıştırılmalıdır."
    exit 1
fi

for cmd in chronyd chronyc systemctl flock awk grep sed cp rm mv timeout bash mktemp sync; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "[FATAL] Gerekli sistem aracı bulunamadı: $cmd"
        exit 1
    fi
done

# 1. NTS ve Parser Kabiliyet Doğrulaması (Verify Before Trust)
if ! chronyd -v | grep -q '+NTS'; then
    echo "[FATAL] Kurulu Chrony sürümü NTS (+NTS) desteği ile derlenmemiş!"
    exit 1
fi

if ! chronyd -h 2>&1 | grep -qw -- '-p'; then
    echo "[FATAL] Kurulu Chrony sürümü '-p' (Print Config) parametresini desteklemiyor."
    exit 1
fi

CHRONY_CONF="/etc/chrony.conf"
mkdir -p /run/lock
LOCKFILE="/run/lock/aegis-time-nts.lock"
exec 9>"$LOCKFILE"
if ! flock -n 9; then
    echo "[FATAL] Betik zaten çalışıyor (Lock). İptal edildi."
    exit 1
fi

# 2. İdempotency (Blok İçi Safiyet)
if [[ -f "$CHRONY_CONF" ]]; then
    BLOCK_CONTENT=$(sed -n '/^# BEGIN V30_AEGIS/,/^# END V30_AEGIS/p' "$CHRONY_CONF" 2>/dev/null || echo "")
    if [[ -n "$BLOCK_CONTENT" ]]; then
        if echo "$BLOCK_CONTENT" | grep -qxF "server time.cloudflare.com iburst nts" && \
           echo "$BLOCK_CONTENT" | grep -qxF "server nts.netnod.se iburst nts" && \
           echo "$BLOCK_CONTENT" | grep -qxF "server ptbtime1.ptb.de iburst nts"; then
            echo "[INFO] Chrony NTS (V30) eksiksiz mühürlü. İdempotent çıkış."
            exit 0
        fi
    fi
fi

echo "============================================================"
echo "🛡️ AEGIS CHRONY NTS (ZAMAN ŞİFRELEMESİ) OPTİMİZASYONU (V30)"
echo "============================================================"
read -rp "Devam etmek için büyük harflerle PERMANENT yazınız: " CONFIRM

if [[ "$CONFIRM" != "PERMANENT" ]]; then
    echo "[-] Onay alınamadı. İşlem iptal ediliyor."
    exit 0
fi

# 3. Gerçek Ağ Pre-flight Doğrulaması (TCP SYN/ACK Sınırı)
echo "[*] NTS (TCP 4460) Soket Erişimleri Donanım Seviyesinde Test Ediliyor..."
NTS_REACHABLE=0
for nts_server in "time.cloudflare.com" "nts.netnod.se" "ptbtime1.ptb.de"; do
    if timeout 3 bash -c "</dev/tcp/$nts_server/4460" 2>/dev/null; then
        NTS_REACHABLE=1
        echo "  [+] $nts_server:4460 -> TCP SOKETİ AÇIK (TLS/NTS-KE Bekleniyor)"
    else
        echo "  [-] $nts_server:4460 -> ERİŞİM YOK"
    fi
done

if [[ $NTS_REACHABLE -eq 0 ]]; then
    echo "[FATAL] Hiçbir NTS sunucusunun 4460 portuna ulaşılamıyor. Kurulum iptal."
    exit 1
fi

BACKUP_DIR=$(mktemp -d -p /run aegis-chrony-backup.XXXXXX)
if [[ ! -f "$CHRONY_CONF" ]]; then
    echo "[FATAL] $CHRONY_CONF bulunamadı."
    if ! rm -rf "$BACKUP_DIR"; then systemd-cat -t aegis-time-nts -p err <<< "[!] Backup dizini silinemedi."; fi
    exit 1
fi

if ! cp -a "$CHRONY_CONF" "$BACKUP_DIR/chrony.conf.bak"; then
    echo "[FATAL] Konfigürasyon yedeği alınamadı!"
    if ! rm -rf "$BACKUP_DIR"; then systemd-cat -t aegis-time-nts -p err <<< "[!] Backup dizini silinemedi."; fi
    exit 1
fi

SERVICE_WAS_ACTIVE=0
SERVICE_WAS_ENABLED=$(systemctl is-enabled chronyd 2>/dev/null || echo "unknown")
if systemctl is-active --quiet chronyd; then
    SERVICE_WAS_ACTIVE=1
fi

DISK_WRITTEN=0
ROLLBACK_DONE=0
TMP_CONF=$(mktemp -p /etc chrony.XXXXXX.conf)

# 4. Deterministik Trap ve Katı State Rollback (|| true KESİNLİKLE YASAK)
cleanup() {
    local exit_code=$?
    trap - EXIT INT TERM ERR
    
    if [[ $ROLLBACK_DONE -eq 1 ]]; then
        if [[ -d "${BACKUP_DIR:-}" ]]; then if ! rm -rf "$BACKUP_DIR"; then systemd-cat -t aegis-time-nts -p err <<< "[!] RM FAIL"; fi; fi
        if [[ -f "${TMP_CONF:-}" ]]; then if ! rm -f "$TMP_CONF"; then systemd-cat -t aegis-time-nts -p err <<< "[!] RM FAIL"; fi; fi
        return 0
    fi
    
    if [[ $exit_code -ne 0 ]]; then
        echo "[!] HATA: NTS Mühürlemesi Çöktü! Gerçek Rollback Başlatılıyor..." | systemd-cat -t aegis-time-nts -p warning
        
        # Atomik Disk State Rollback (cp -> sync -> mv)
        if [[ $DISK_WRITTEN -eq 1 && -f "$BACKUP_DIR/chrony.conf.bak" ]]; then
            TMP_ROLLBACK=$(mktemp -p /etc chrony-rollback.XXXXXX.conf)
            if cp -a "$BACKUP_DIR/chrony.conf.bak" "$TMP_ROLLBACK"; then
                if sync -f "$TMP_ROLLBACK"; then
                    if mv "$TMP_ROLLBACK" "$CHRONY_CONF"; then
                        if ! sync -f /etc; then
                            echo "[WARNING] Rollback: Dizin senkronizasyonu (sync /etc) başarısız." | systemd-cat -t aegis-time-nts -p warning
                        fi
                    else
                        echo "[EMERG] Rollback: mv başarısız!" | systemd-cat -t aegis-time-nts -p emerg
                    fi
                else
                    echo "[EMERG] Rollback: sync başarısız!" | systemd-cat -t aegis-time-nts -p emerg
                fi
            else
                echo "[EMERG] Rollback: cp başarısız!" | systemd-cat -t aegis-time-nts -p emerg
            fi
        fi
        
        # Systemd State Matrisi Restorasyonu
        case "$SERVICE_WAS_ENABLED" in
            "enabled")
                if ! systemctl enable chronyd >/dev/null 2>&1; then echo "[EMERG] Rollback: chronyd enable yapılamadı." | systemd-cat -t aegis-time-nts -p emerg; fi
                ;;
            "disabled")
                if ! systemctl disable chronyd >/dev/null 2>&1; then echo "[EMERG] Rollback: chronyd disable yapılamadı." | systemd-cat -t aegis-time-nts -p emerg; fi
                ;;
            "masked")
                if ! systemctl mask chronyd >/dev/null 2>&1; then echo "[EMERG] Rollback: chronyd mask yapılamadı." | systemd-cat -t aegis-time-nts -p emerg; fi
                ;;
            *)
                echo "[INFO] Rollback: systemctl ($SERVICE_WAS_ENABLED) state'ine dokunulmadı." | systemd-cat -t aegis-time-nts -p info
                ;;
        esac

        if [[ $SERVICE_WAS_ACTIVE -eq 1 ]]; then
            if ! systemctl restart chronyd >/dev/null 2>&1; then
                echo "[FATAL] Rollback Sonrası Kriz: Chronyd servisi eski durumuna döndürülemedi!" | systemd-cat -t aegis-time-nts -p emerg
            fi
        else
            if ! systemctl stop chronyd >/dev/null 2>&1; then
                echo "[EMERG] Rollback: chronyd durdurulamadı." | systemd-cat -t aegis-time-nts -p emerg
            fi
        fi
        
        echo "[-] Rollback tamamlandı. Hatalar yukarıda raporlandı." | systemd-cat -t aegis-time-nts -p err
    fi
    
    ROLLBACK_DONE=1
    if [[ -d "${BACKUP_DIR:-}" ]]; then if ! rm -rf "$BACKUP_DIR"; then systemd-cat -t aegis-time-nts -p err <<< "[!] RM FAIL"; fi; fi
    if [[ -f "${TMP_CONF:-}" ]]; then if ! rm -f "$TMP_CONF"; then systemd-cat -t aegis-time-nts -p err <<< "[!] RM FAIL"; fi; fi
    exit "$exit_code"
}
trap cleanup EXIT INT TERM ERR

if ! cp -a "$CHRONY_CONF" "$TMP_CONF"; then
    echo "[FATAL] TMP dosyasına kopyalama başarısız."
    exit 1
fi

BLOCK_CONTENT=$(sed -n '/^# BEGIN V30_AEGIS/,/^# END V30_AEGIS/p' "$TMP_CONF" 2>/dev/null || echo "")
if [[ -n "$BLOCK_CONTENT" ]]; then
    if ! sed -i '/^# BEGIN V30_AEGIS/,/^# END V30_AEGIS/d' "$TMP_CONF"; then
        echo "[FATAL] Eski AEGIS bloğu temizlenemedi."
        exit 1
    fi
fi

cat << 'EOF' >> "$TMP_CONF"
# BEGIN V30_AEGIS: NTS (Network Time Security) Zırhı
server time.cloudflare.com iburst nts
server nts.netnod.se iburst nts
server ptbtime1.ptb.de iburst nts
ntsdumpdir /var/lib/chrony
# END V30_AEGIS
EOF

if ! chronyd -p -f "$TMP_CONF" >/dev/null 2>&1; then
    echo "[FATAL] Chronyd yeni konfigürasyon bloğunu parse edemedi!" | systemd-cat -t aegis-time-nts -p err
    exit 1
fi

if ! mv "$TMP_CONF" "$CHRONY_CONF"; then
    echo "[FATAL] Mühürleme (mv) başarısız oldu!"
    exit 1
fi
DISK_WRITTEN=1

if ! sync -f /etc; then
    echo "[WARNING] POSIX Dizin Mührü (sync /etc) başarısız." | systemd-cat -t aegis-time-nts -p warning
fi

if ! systemctl enable chronyd >/dev/null 2>&1; then
    echo "[FATAL] Chronyd servisi etkinleştirilemedi!"
    exit 1
fi

if ! systemctl restart chronyd; then
    echo "[FATAL] Chronyd yeni NTS konfigürasyonu ile yeniden başlatılamadı!" | systemd-cat -t aegis-time-nts -p err
    exit 1
fi

echo "[*] NTS Cookie Exchange ve Zaman Senkronizasyonu bekleniyor (Max 60s)..."
SYNC_SUCCESS=0
for i in {1..60}; do
    if chronyc tracking 2>/dev/null | grep -q "Leap status.*Normal"; then
        if chronyc -N authdata 2>/dev/null | awk '
            /^Name\/IP/ {
                for(j=1;j<=NF;j++) {
                    if($j=="Type") t=j;
                    if($j=="Cook") c=j;
                }
            }
            /^[a-zA-Z0-9]/ && !/^Name\/IP/ {
                if(t && c && $t=="NTS" && $c>0) { found=1; exit }
            }
            END { if(!found) exit 1 }
        '; then
            SYNC_SUCCESS=1
            break
        fi
    fi
    sleep 1
done

if [[ $SYNC_SUCCESS -eq 0 ]]; then
    echo "[FATAL] NTS senkronizasyonu (Cookie Exchange veya Leap Status) 60 saniye içinde sağlanamadı!" | systemd-cat -t aegis-time-nts -p err
    exit 1
fi

echo "[+] Chrony NTS aktif. TLS zaman şifrelemesi Kernel'a mühürlendi." | systemd-cat -t aegis-time-nts -p info

echo "============================================================"
echo "✅ [BAŞARILI] Chrony NTS (Zaman Şifrelemesi) Mühürlendi! (V30)"
echo "============================================================"
echo "🛡️ CHRONY TRACKING DURUMU:"
chronyc tracking | grep -E "Reference ID|Leap status"
echo "------------------------------------------------------------"
echo "🛡️ NTS (AUTHDATA) DURUMU:"
chronyc -N authdata
echo "------------------------------------------------------------"
echo "🛡️ ZAMAN KAYNAKLARI (SOURCES):"
chronyc sources -v | tail -n 5
echo "============================================================"
