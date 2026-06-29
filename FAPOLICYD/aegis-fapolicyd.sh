#!/usr/bin/env bash
# ================================================================
# AEGIS FAPOLICYD KURULUM VE YAPILANDIRMA BETİĞİ V10.1
# FEDORA 44 TEMİZ KURULUM İÇİN OPTİMİZE EDİLMİŞTİR
# ================================================================

set -euo pipefail

# Renkli çıktı
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# -----------------------------------------------------------------
# 1. YETKİ KONTROLÜ
# -----------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[-] KRİTİK HATA: Root yetkisi gerekli (sudo).${NC}" >&2
    exit 1
fi

echo -e "${GREEN}[*] AEGIS FAPOLICYD V10.1 KURULUMU BAŞLATILIYOR...${NC}"
echo "[*] Sistem: $(cat /etc/fedora-release 2>/dev/null || echo 'Fedora')"

# -----------------------------------------------------------------
# 2. DEĞİŞKENLER
# -----------------------------------------------------------------
CONFIG_DIR="/etc/fapolicyd"
RULES_DIR="/etc/fapolicyd/rules.d"
DB_DIR="/var/lib/fapolicyd"
CONFIG_FILE="${CONFIG_DIR}/fapolicyd.conf"
BACKUP_DIR="${CONFIG_DIR}_bak_$(date +%Y%m%d_%H%M%S)"

# -----------------------------------------------------------------
# 3. MEVCUT DURUMUN KAYDEDİLMESİ (ROLLBACK İÇİN)
# -----------------------------------------------------------------
INITIAL_ACTIVE=$(systemctl is-active fapolicyd 2>/dev/null || echo "inactive")
INITIAL_ENABLED=$(systemctl is-enabled fapolicyd 2>/dev/null || echo "disabled")

# -----------------------------------------------------------------
# 4. ROLLBACK FONKSİYONU
# -----------------------------------------------------------------
rollback() {
    local line=$1
    local cmd=$2
    echo -e "\n${RED}[!] HATA: $line satırında '${cmd}' başarısız oldu.${NC}" >&2
    echo "[*] Rollback başlatılıyor..."
    
    # Servisi durdur
    systemctl stop fapolicyd 2>/dev/null || true
    
    # Konfigürasyonu geri yükle
    if [ -d "$BACKUP_DIR" ] && [ -n "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        rm -rf "${CONFIG_DIR:?}" 2>/dev/null || true
        cp -a "$BACKUP_DIR" "$CONFIG_DIR" 2>/dev/null || true
        echo "[*] Konfigürasyon yedekten geri yüklendi."
    fi
    
    # Servisi eski durumuna getir
    if [ "$INITIAL_ACTIVE" = "active" ]; then
        systemctl start fapolicyd 2>/dev/null || true
    fi
    case "$INITIAL_ENABLED" in
        enabled)  systemctl enable fapolicyd 2>/dev/null || true ;;
        disabled) systemctl disable fapolicyd 2>/dev/null || true ;;
    esac
    
    echo -e "${RED}[-] Sistem önceki durumuna döndürüldü.${NC}" >&2
    exit 1
}

trap 'rollback $LINENO "$BASH_COMMAND"' ERR

# -----------------------------------------------------------------
# 5. DİZİNLERİ OLUŞTUR
# -----------------------------------------------------------------
echo "[*] Dizinler oluşturuluyor..."
mkdir -p "$CONFIG_DIR" "$RULES_DIR" "$DB_DIR" 2>/dev/null || true

# -----------------------------------------------------------------
# 6. PAKET KURULUMU (FEDORA 44 UYUMLU - PLUGIN YOK)
# -----------------------------------------------------------------
echo "[*] Paket durumu kontrol ediliyor..."

# SADECE fapolicyd paketini kontrol et (plugin Fedora 44'te yok)
if ! rpm -q fapolicyd &>/dev/null; then
    echo "[*] fapolicyd paketi kuruluyor..."
    dnf install -y fapolicyd
else
    echo "[+] fapolicyd paketi zaten kurulu."
fi

# fapolicyd-dnf-plugin yok, atla
echo "[i] Not: fapolicyd-dnf-plugin Fedora 44'te mevcut değil, atlanıyor."

# -----------------------------------------------------------------
# 7. YEDEKLEME
# -----------------------------------------------------------------
if [ -d "$CONFIG_DIR" ] && [ -n "$(ls -A "$CONFIG_DIR" 2>/dev/null)" ]; then
    echo "[*] Konfigürasyon yedekleniyor: $BACKUP_DIR"
    cp -a "$CONFIG_DIR" "$BACKUP_DIR"
else
    echo "[i] Konfigürasyon dizini boş, yedek oluşturulmadı."
    mkdir -p "$BACKUP_DIR"
fi

# -----------------------------------------------------------------
# 8. KONFİGÜRASYON DOSYASINI OLUŞTUR
# -----------------------------------------------------------------
echo "[*] Konfigürasyon dosyası oluşturuluyor..."

cat > "$CONFIG_FILE" << 'EOF'
# AEGIS FAPOLICYD KONFİGÜRASYONU - FEDORA 44
permissive = 1
nice_val = 14
q_size = 8192
uid = fapolicyd
gid = fapolicyd
do_stat_report = 0
detailed_report = 0
db_max_size = 100
subj_cache_size = 16381
obj_cache_size = 32768
watch_fs = ext2,ext3,ext4,tmpfs,xfs,vfat,iso9660,btrfs
trust = file
integrity = sha256
syslog_format = rule,dec,perm,auid,pid,exe,:,path,ftype,trust
rpm_sha256_only = 0
allow_filesystem_mark = 0
report_interval = 0
reset_strategy = never
timing_collection = off
EOF

chmod 644 "$CONFIG_FILE"
echo "[+] Konfigürasyon oluşturuldu."

# -----------------------------------------------------------------
# 9. VERİTABANI TEMİZLİĞİ
# -----------------------------------------------------------------
if systemctl is-active --quiet fapolicyd 2>/dev/null; then
    echo "[*] Servis durduruluyor..."
    systemctl stop fapolicyd
    sleep 2
fi

echo "[*] Veritabanı hazırlanıyor..."
rm -rf "${DB_DIR:?}"/* 2>/dev/null || true
mkdir -p "$DB_DIR"
touch "$DB_DIR/trust.db"
chown fapolicyd:fapolicyd "$DB_DIR" 2>/dev/null || true
chown fapolicyd:fapolicyd "$DB_DIR/trust.db" 2>/dev/null || true
chmod 750 "$DB_DIR" 2>/dev/null || true
chmod 640 "$DB_DIR/trust.db" 2>/dev/null || true
echo "[+] Veritabanı hazır."

# -----------------------------------------------------------------
# 10. SELINUX POLİTİKASI
# -----------------------------------------------------------------
echo "[*] SELinux durumu kontrol ediliyor..."

if command -v audit2allow &>/dev/null && command -v semodule &>/dev/null; then
    ORIG_SELINUX=$(getenforce 2>/dev/null || echo "Disabled")
    
    if [ "$ORIG_SELINUX" = "Enforcing" ]; then
        echo "[*] SELinux geçici olarak permissive moda alınıyor..."
        setenforce 0 2>/dev/null || true
    fi
    
    echo "[*] SELinux politikası oluşturuluyor..."
    TEMP_DIR=$(mktemp -d)
    ausearch -c 'fapolicyd' --raw 2>/dev/null | audit2allow -M "$TEMP_DIR/fapolicyd-policy" 2>/dev/null || true
    
    if [ -f "$TEMP_DIR/fapolicyd-policy.pp" ]; then
        semodule -i "$TEMP_DIR/fapolicyd-policy.pp" 2>/dev/null && echo "[+] SELinux politikası yüklendi." || echo "[!] Politika yüklenemedi."
    else
        echo "[i] SELinux politikası gerekmedi."
    fi
    
    rm -rf "$TEMP_DIR" 2>/dev/null || true
    
    if [ "$ORIG_SELINUX" = "Enforcing" ]; then
        echo "[*] SELinux tekrar enforcing moda alınıyor..."
        setenforce 1 2>/dev/null || true
    fi
else
    echo "[!] audit2allow/semodule bulunamadı, SELinux politikası atlandı."
fi

# -----------------------------------------------------------------
# 11. KONFİGÜRASYON DOĞRULAMA
# -----------------------------------------------------------------
echo "[*] Konfigürasyon doğrulanıyor..."
if ! fapolicyd-cli --check-config >/dev/null 2>&1; then
    echo -e "${RED}[-] Konfigürasyon hatası!${NC}"
    rollback $LINENO "fapolicyd-cli --check-config"
fi
echo "[+] Konfigürasyon geçerli."

# -----------------------------------------------------------------
# 12. KURALLARI DERLE
# -----------------------------------------------------------------
echo "[*] Kurallar derleniyor..."
fagenrules --check >/dev/null 2>&1 || true
fagenrules --load >/dev/null 2>&1 || true

# -----------------------------------------------------------------
# 13. SERVİSİ BAŞLAT
# -----------------------------------------------------------------
echo "[*] Servis başlatılıyor..."
systemctl daemon-reload
systemctl enable fapolicyd 2>/dev/null || true
systemctl start fapolicyd
sleep 3

# -----------------------------------------------------------------
# 14. SERVİS KONTROLÜ
# -----------------------------------------------------------------
if systemctl is-active --quiet fapolicyd; then
    echo -e "${GREEN}[+] Fapolicyd servisi başarıyla çalışıyor.${NC}"
else
    echo -e "${RED}[-] Servis başlatılamadı!${NC}"
    echo "=== SON 10 SATIR LOG ==="
    journalctl -u fapolicyd -n 10 --no-pager 2>/dev/null || true
    rollback $LINENO "systemctl start fapolicyd"
fi

# -----------------------------------------------------------------
# 15. TRUST DATABASE GÜNCELLEME
# -----------------------------------------------------------------
echo "[*] Trust Database güncelleniyor..."

if ! fapolicyd-cli --update 2>/dev/null; then
    echo "[!] --update başarısız, manuel dosya ekleniyor..."
    for dir in /usr/bin /usr/sbin /usr/lib /usr/lib64; do
        if [ -d "$dir" ]; then
            fapolicyd-cli -f add "$dir" -t file 2>/dev/null || true
        fi
    done
    echo "[+] Manuel ekleme tamamlandı."
fi

# -----------------------------------------------------------------
# 16. FANOTIFY HOOK KONTROLÜ
# -----------------------------------------------------------------
echo "[*] Fanotify hook kontrol ediliyor..."
MAIN_PID=$(systemctl show -p MainPID --value fapolicyd 2>/dev/null || echo "")

if [ -n "$MAIN_PID" ] && [ "$MAIN_PID" != "0" ] && [ -d "/proc/$MAIN_PID/fdinfo" ]; then
    HOOKED=0
    for f in /proc/"$MAIN_PID"/fdinfo/*; do
        if [ -f "$f" ] && grep -q "^fanotify" "$f" 2>/dev/null; then
            HOOKED=1
            break
        fi
    done
    
    if [ $HOOKED -eq 1 ]; then
        echo -e "${GREEN}[+] Fanotify hook aktif (PID: $MAIN_PID).${NC}"
    else
        echo -e "${YELLOW}[!] UYARI: Fanotify hook doğrulanamadı.${NC}"
    fi
else
    echo -e "${YELLOW}[!] PID alınamadı, hook kontrolü atlandı.${NC}"
fi

# -----------------------------------------------------------------
# 17. ÖZET RAPOR
# -----------------------------------------------------------------
echo "================================================================="
echo -e "${GREEN}[✓] AEGIS FAPOLICYD KURULUMU TAMAMLANDI${NC}"
echo "================================================================="
echo "  Servis Durumu : $(systemctl is-active fapolicyd 2>/dev/null || echo 'Bilinmiyor')"
echo "  Trust Backend  : file"
echo "  Mod            : Permissive (Telemetri Aşaması)"
echo "  SELinux        : $(getenforce 2>/dev/null || echo 'Bilinmiyor')"
echo "  Konfigürasyon  : $CONFIG_FILE"
echo "  Veritabanı     : $DB_DIR/trust.db"
echo "================================================================="
echo -e "${YELLOW}[!] NOT: Sistem 7-14 gün telemetri modunda çalışacak.${NC}"
echo -e "${YELLOW}[!] Ardından permissive=0 yaparak enforcing moda geçin.${NC}"
echo "================================================================="
