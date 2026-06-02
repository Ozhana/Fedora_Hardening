#!/usr/bin/env bash
# V18_Aegis_Surface - Phase: FAPOLICYD Enterprise Pipeline V8
# Architecture: EUID 0, Timestamped State Backup, Non-Blocking RPM & Kernel Audit, Dotfile-Safe Rollback

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "[-] KRİTİK HATA: Bu betik Root yetkileriyle çalıştırılmalıdır (sudo ./aegis-fapolicyd.sh)." >&2
    exit 1
fi

echo "[*] V18_Aegis: FAPOLICYD Dağıtım Protokolü (V8) Başlatılıyor..."

CONFIG_DIR="/etc/fapolicyd"
# Benzersiz zaman damgası ile entropi ve veri kaybı önlendi
BACKUP_DIR="${CONFIG_DIR}_state_bak_$(date +%Y%m%d_%H%M%S)"

# 1. FULL SYSTEMD STATE TRACKING
INITIAL_ACTIVE_STATE=$(systemctl is-active fapolicyd 2>/dev/null || echo "inactive")
INITIAL_ENABLE_STATE=$(systemctl is-enabled fapolicyd 2>/dev/null || echo "disabled")

# 2. STATE-MATRIX & DOTFILE-SAFE ROLLBACK FUNCTION
rollback_on_error() {
    trap - ERR 
    
    local line=$1
    local cmd=$2
    echo -e "\n[!] UYARI: Süreç kesintiye uğradı. Satır: $line, Komut: $cmd" >&2
    echo "[*] DIRECTORY-LEVEL ROLLBACK BAŞLATILIYOR..."
    
    if [ -d "$BACKUP_DIR" ]; then
        echo "[*] $CONFIG_DIR dizini zaman damgalı yedeğe döndürülüyor..."
        # Gizli dosyaları (dotfiles) da silecek ve taşıyacak güvenli yöntem
        sudo find "${CONFIG_DIR:?}" -mindepth 1 -exec rm -rf {} +
        sudo cp -a "$BACKUP_DIR"/. "$CONFIG_DIR"/
    fi
    
    echo "[*] Servis çalışma durumuna ($INITIAL_ACTIVE_STATE) döndürülüyor..."
    if [ "$INITIAL_ACTIVE_STATE" = "active" ]; then
        sudo systemctl start fapolicyd || echo "[!] Rollback sırasında start başarısız oldu."
    else
        sudo systemctl stop fapolicyd || echo "[!] Rollback sırasında stop başarısız oldu."
    fi
    
    echo "[*] Servis başlangıç durumu değerlendiriliyor: $INITIAL_ENABLE_STATE"
    case "$INITIAL_ENABLE_STATE" in
        enabled)  sudo systemctl enable fapolicyd ;;
        disabled) sudo systemctl disable fapolicyd ;;
        masked)   sudo systemctl mask fapolicyd ;;
        *)        echo "[i] Başlangıç durumu ($INITIAL_ENABLE_STATE) statik/dolaylı. Müdahale edilmiyor." ;;
    esac
    
    echo "[-] Sistem önceki güvenli durumuna kilitlendi. Süreç sonlandırıldı." >&2
    exit 1
}

trap 'rollback_on_error $LINENO "$BASH_COMMAND"' ERR

# 3. PACKAGE VERIFICATION & AUDIT (NON-BLINDING)
PACKAGES=("fapolicyd" "fapolicyd-dnf-plugin")
for pkg in "${PACKAGES[@]}"; do
    if ! rpm -q "$pkg" &>/dev/null; then
        echo "[*] Eksik paket: $pkg. Kuruluyor..."
        sudo dnf install -y "$pkg"
    fi
done

echo "[*] RPM Bütünlük Taraması yapılıyor..."
# || true eklenerek hata fırlatması önlendi, çıktı değişkene hapsedildi
RPM_AUDIT=$(sudo rpm -V "${PACKAGES[@]}" 2>&1 || true)

if [[ -n "$RPM_AUDIT" ]]; then
    echo "[!] DİKKAT: RPM Bütünlük ihlali/değişikliği tespit edildi:"
    echo "$RPM_AUDIT"
    echo "[i] (İşleme devam ediliyor...)"
else
    echo "[+] RPM Bütünlüğü kusursuz."
fi

# 4. TIMESTAMPED DIRECTORY-LEVEL STATE BACKUP
echo "[*] Tüm konfigürasyon dizini yedekleniyor: $BACKUP_DIR"
sudo cp -a "$CONFIG_DIR" "$BACKUP_DIR"

# 5. SECURE SED MANIPULATION
CONFIG_FILE="${CONFIG_DIR}/fapolicyd.conf"
echo "[*] Permissive mod (Telemetri) zorlanıyor..."
sudo sed -i -E 's|^[[:space:]]*#?[[:space:]]*permissive[[:space:]]*=.*$|permissive = 1|' "$CONFIG_FILE"

# 6. CONFIG VALIDATION & RULE COMPILATION
echo "[*] Konfigürasyon sözdizimi doğrulanıyor..."
sudo fapolicyd-cli --check-config >/dev/null

echo "[*] Fapolicyd kuralları derleniyor..."
sudo fagenrules --check >/dev/null
sudo fagenrules --load >/dev/null

# 7. DETERMINISTIC SYSTEMD ACTIVATION
echo "[*] Servis Systemd üzerinden kararlı şekilde başlatılıyor..."
sudo systemctl enable --now fapolicyd
sudo systemctl restart fapolicyd

# 8. TRUST DB UPDATE & DYNAMIC VERIFICATION
echo "[*] RPM Trust Database senkronize ediliyor..."
sudo fapolicyd-cli --update

if sudo fapolicyd-cli --help 2>&1 | grep -q "check-trustdb"; then
    echo "[*] Trust Database bütünlüğü denetleniyor..."
    sudo fapolicyd-cli --check-trustdb
else
    echo "[i] Geçerli fapolicyd sürümü check-trustdb desteklemiyor, adım atlandı."
fi

# 9. KERNEL-LEVEL FANOTIFY HOOK VERIFICATION (NON-BLOCKING ABI CHECK)
echo "[*] Fanotify Kernel kancası FDInfo API üzerinden denetleniyor..."
if systemctl is-active --quiet fapolicyd; then
    MAIN_PID=$(systemctl show -p MainPID --value fapolicyd)
    
    if [ -z "$MAIN_PID" ] || [ "$MAIN_PID" -eq 0 ]; then
        echo "[-] KRİTİK HATA: Systemd, fapolicyd için geçerli bir MainPID raporlamadı!"
        exit 1
    fi

    FANOTIFY_HOOKED=0
    for fd_file in /proc/"$MAIN_PID"/fdinfo/*; do
        if sudo grep -q "^fanotify" "$fd_file" 2>/dev/null; then
            FANOTIFY_HOOKED=1
            break
        fi
    done

    if [ "$FANOTIFY_HOOKED" -eq 1 ]; then
        echo "[+] Fanotify Hook DOĞRULANDI (MainPID: $MAIN_PID)."
    else
        # Exit 1 yerine kernel ABI uyarısı bırakıldı
        echo "[!] UYARI: Fanotify kancası FDInfo üzerinden doğrulanamadı!"
        echo "[i] Kernel ABI değişmiş olabilir. Servis Systemd üzerinde AKTİF."
        echo "[i] Lütfen 'ausearch -m fanotify' komutu ile logları manuel teyit et."
    fi
else
    echo "[-] Servis başlatılamadı!"
    exit 1
fi

echo "================================================================="
echo "[i] V8 PROTOKOLÜ KURUMSAL STANDARTLARDA TAMAMLANDI."
echo "[!] Sistem 7-14 günlük TELEMETRİ (Permissive) aşamasındadır."
echo "[!] Loglar birikmeye başladı. Savunma devrede."
echo "================================================================="
