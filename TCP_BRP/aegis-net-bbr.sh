#!/usr/bin/env bash
# V8_AEGIS: TCP BBR Çekirdek Optimizasyonu (Sıfır Entropi Final)
set -euo pipefail

# 1. Kök Yetki Kontrolü
if [[ $EUID -ne 0 ]]; then
    echo "[FATAL] Bu betik root (sudo) yetkisiyle çalıştırılmalıdır."
    exit 1
fi

SYSCTL_FILE="/etc/sysctl.d/99-aegis-bbr.conf"
BACKUP_DIR=""

# Semantik Durum Bayrakları
DISK_WRITTEN=0
ROLLBACK_DONE=0
ROLLBACK_INCOMPLETE=0
BBR_WAS_LOADED=0
NETWORK_STATE_CHANGED=0

# 2. Idempotency (Sıfır Entropi)
CURRENT_CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
CURRENT_QDISC=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "unknown")

if [[ "$CURRENT_CC" == "bbr" && "$CURRENT_QDISC" == "fq" && -f "$SYSCTL_FILE" ]]; then
    systemd-cat -t aegis-net-bbr -p info <<< "[INFO] TCP BBR ve FQ zaten Kernel'a mühürlü. İdempotent çıkış."
    exit 0
fi

# 3. Kognitif Sürtünme
echo "============================================================"
echo "🛡️ AEGIS TCP BBR VE FQ KERNEL OPTİMİZASYONU"
echo "============================================================"
read -rp "Devam etmek için büyük harflerle PERMANENT yazınız: " CONFIRM

if [[ "$CONFIRM" != "PERMANENT" ]]; then
    echo "[-] Onay alınamadı. İşlem iptal ediliyor."
    exit 0
fi

# 4. State Preservation (İzole Yedekleme Gecikmeli Başlatma)
BACKUP_DIR=$(mktemp -d -p /tmp aegis-bbr-backup.XXXXXX)

if [[ -f "$SYSCTL_FILE" ]]; then
    if ! cp -a "$SYSCTL_FILE" "$BACKUP_DIR/99-aegis-bbr.conf.bak"; then
        systemd-cat -t aegis-net-bbr -p err <<< "[FATAL] Yedekleme başarısız oldu. İşlem durduruluyor."
        rm -rf "$BACKUP_DIR"
        exit 1
    fi
fi

if grep -qw "tcp_bbr" /proc/modules 2>/dev/null || [[ -d "/sys/module/tcp_bbr" ]]; then
    BBR_WAS_LOADED=1
fi

if [[ "$CURRENT_QDISC" != "fq" || "$CURRENT_CC" != "bbr" ]]; then
    NETWORK_STATE_CHANGED=1
fi

# 5. Trap Mimarisi ve Deterministik Rollback
cleanup() {
    local exit_code=$?
    trap - EXIT INT TERM ERR
    
    if [[ $ROLLBACK_DONE -eq 1 ]]; then
        [[ -n "$BACKUP_DIR" && -d "$BACKUP_DIR" && "$BACKUP_DIR" == /tmp/aegis-bbr-backup.* ]] && rm -rf "$BACKUP_DIR"
        exit "$exit_code"
    fi
    
    if [[ $exit_code -ne 0 ]]; then
        systemd-cat -t aegis-net-bbr -p warning <<< "[!] HATA: BBR optimizasyonu çöktü! Gerçek Rollback başlatılıyor..."
        
        # RAM State Rollback
        if [[ "$CURRENT_QDISC" != "unknown" ]]; then
            sysctl -w net.core.default_qdisc="$CURRENT_QDISC" >/dev/null 2>&1
        fi
        if [[ "$CURRENT_CC" != "unknown" ]]; then
            sysctl -w net.ipv4.tcp_congestion_control="$CURRENT_CC" >/dev/null 2>&1
        fi
        
        # modprobe -r Yarış Durumu (Race Condition) Kontrolü
        if [[ $BBR_WAS_LOADED -eq 0 ]]; then
            if ! modprobe -r tcp_bbr 2>/dev/null; then
                systemd-cat -t aegis-net-bbr -p err <<< "[WARN] tcp_bbr modülü çekirdekten koparılamadı (Mevcut soketler kullanıyor olabilir)."
                ROLLBACK_INCOMPLETE=1
            fi
        fi

        # Disk State Rollback
        if [[ $DISK_WRITTEN -eq 1 ]]; then
            if [[ -f "$BACKUP_DIR/99-aegis-bbr.conf.bak" ]]; then
                if ! mv "$BACKUP_DIR/99-aegis-bbr.conf.bak" "$SYSCTL_FILE"; then
                    systemd-cat -t aegis-net-bbr -p err <<< "[FATAL] Rollback: $SYSCTL_FILE geri yüklenemedi!"
                    ROLLBACK_INCOMPLETE=1
                fi
            else
                if [[ -f "$SYSCTL_FILE" ]]; then
                    if ! rm -f "$SYSCTL_FILE"; then
                         systemd-cat -t aegis-net-bbr -p err <<< "[FATAL] Rollback: $SYSCTL_FILE silinemedi!"
                         ROLLBACK_INCOMPLETE=1
                    fi
                fi
            fi
            
            sync -f /etc/sysctl.d 2>/dev/null || true
        fi
        
        if [[ $ROLLBACK_INCOMPLETE -eq 1 ]]; then
             systemd-cat -t aegis-net-bbr -p emerg <<< "[CRITICAL] Rollback KISMEN tamamlandı! Sistem durumu yozlaşmış olabilir."
        else
             systemd-cat -t aegis-net-bbr -p err <<< "[-] Rollback kusursuz tamamlandı. Sistem eski Kernel durumuna döndürüldü."
        fi
    fi
    
    ROLLBACK_DONE=1
    [[ -n "$BACKUP_DIR" && -d "$BACKUP_DIR" && "$BACKUP_DIR" == /tmp/aegis-bbr-backup.* ]] && rm -rf "$BACKUP_DIR"
    exit "$exit_code"
}
trap cleanup EXIT INT TERM ERR

# 6. Çekirdek Desteği Doğrulaması
AVAILABLE_CC=$(cat /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null || echo "")

if ! grep -qw "bbr" <<< "$AVAILABLE_CC"; then
    if ! modprobe tcp_bbr 2>/dev/null; then
        systemd-cat -t aegis-net-bbr -p err <<< "[FATAL] Kernel 'bbr' modülünü desteklemiyor veya yükleyemedi."
        exit 1
    fi
    AVAILABLE_CC=$(cat /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null || echo "")
    if ! grep -qw "bbr" <<< "$AVAILABLE_CC"; then
        systemd-cat -t aegis-net-bbr -p err <<< "[FATAL] Kernel BBR doğrulamasını geçemedi."
        exit 1
    fi
fi

# 7. Canlı Kernel Testi
if ! sysctl -w net.core.default_qdisc=fq >/dev/null || ! sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null; then
    systemd-cat -t aegis-net-bbr -p err <<< "[FATAL] Canlı Kernel parametreleri reddetti!"
    exit 1
fi

LIVE_CC=$(sysctl -n net.ipv4.tcp_congestion_control)
if [[ "$LIVE_CC" != "bbr" ]]; then
    systemd-cat -t aegis-net-bbr -p err <<< "[FATAL] Kernel, BBR algoritmasını canlı bellekte reddetti!"
    exit 1
fi

# 8. Atomik Disk Mühürlemesi ve Enterprise Fsync Doğrulaması
TMP_SYS=$(mktemp -p /etc/sysctl.d 99-aegis-bbr.XXXXXX.conf)
cat << 'EOF' > "$TMP_SYS"
# V8_AEGIS: TCP BBR Optimizasyonu (Auto-load)
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF

if ! sync -f "$TMP_SYS"; then
    systemd-cat -t aegis-net-bbr -p err <<< "[FATAL] Metadata senkronizasyonu (sync) başarısız oldu!"
    exit 1
fi

if ! mv "$TMP_SYS" "$SYSCTL_FILE"; then
    systemd-cat -t aegis-net-bbr -p err <<< "[FATAL] $SYSCTL_FILE atomik olarak taşınamadı!"
    exit 1
fi

DISK_WRITTEN=1

if ! sync -f /etc/sysctl.d; then
    systemd-cat -t aegis-net-bbr -p err <<< "[FATAL] POSIX Dizin Mührü (sync) dizine uygulanamadı!"
    exit 1
fi

# 9. Dar Yükleme ve Nihai State Doğrulaması
if ! sysctl --load="$SYSCTL_FILE" >/dev/null; then
    systemd-cat -t aegis-net-bbr -p err <<< "[FATAL] sysctl --load dosyayı uygulayamadı!"
    exit 1
fi

FINAL_CC=$(sysctl -n net.ipv4.tcp_congestion_control)
FINAL_QDISC=$(sysctl -n net.core.default_qdisc)

if [[ "$FINAL_CC" != "bbr" || "$FINAL_QDISC" != "fq" ]]; then
    systemd-cat -t aegis-net-bbr -p err <<< "[FATAL] Nihai durum doğrulaması başarısız! Sistem yapılandırmayı kaybetti."
    exit 1
fi

systemd-cat -t aegis-net-bbr -p info <<< "[+] TCP BBR & FQ kalıcı olarak mühürlendi. Kernel: $(uname -r)"

# 10. Operasyonel Çıktı ve Telemetri
echo "============================================================"
echo "✅ [BAŞARILI] Kernel TCP BBR ve FQ Optimizasyonu Aktif!"
if [[ $NETWORK_STATE_CHANGED -eq 1 ]]; then
    echo "   -> Ağ yapılandırması (Network State) değişti. Tüm"
    echo "      soketlerin BBR mimarisine geçmesi için uygun bir"
    echo "      vakitte REBOOT etmeniz tavsiye edilir."
else
    echo "   -> Sistem zaten ideal mimaride. REBOOT gerekli değildir."
fi
echo "============================================================"
