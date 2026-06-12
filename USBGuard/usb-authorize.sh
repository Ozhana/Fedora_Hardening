#!/bin/bash
# ==============================================================================
# ENTERPRISE-GRADE USB AUTHORIZATION MATRIX (V4 - Native Mühürleme)
# ==============================================================================
# AUTHOR: Dr. Ozhan Akdag 
# DESC  : BadUSB ve RubberDucky korumalı (Human-in-the-loop) cihaz onaylama betiği.
#         USBGuard native komutları ve anlık durum senkronizasyonu kullanır.
# ==============================================================================

#!/usr/bin/env bash
# ==============================================================================
# AEGIS KATMAN-02a — USBGuard Zero-Trust (TEMİZ REVİZYON)
# ==============================================================================
set -Eeuo pipefail
export IFS=$'\n\t'
export LC_ALL=C
export PATH='/usr/sbin:/usr/bin:/sbin:/bin'
umask 077

# --- RENK TANIMLARI ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- KÖK KONTROLÜ ---
if [[ "${EUID}" -ne 0 ]]; then
    echo -e "${RED}[-] KRİTİK HATA: Root yetkisi gerekli. sudo ile çalıştırın.${NC}"
    exit 1
fi

# --- KULLANICI TESPİTİ ---
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo 'root')}"
REAL_HOME=$(eval echo "~${REAL_USER}")

# --- MASAÜSTÜ LOG KLASÖRÜ ---
LOG_DIR="${REAL_HOME}/Desktop/LOG_FILES"
mkdir -p "$LOG_DIR"
chown "${REAL_USER}:${REAL_USER}" "$LOG_DIR" 2>/dev/null || true
LOG_FILE="${LOG_DIR}/Layer02_USBGuard.log"

# --- LOG BAŞLAT ---
echo -e "${CYAN}======================================================================${NC}"
echo -e "${CYAN}🛡️ AEGIS KATMAN-02a: USBGUARD ZERO-TRUST DONANIM KALKANI${NC}"
echo -e "${CYAN}Tarih     : $(date +'%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${CYAN}Kullanıcı : ${REAL_USER}${NC}"
echo -e "${CYAN}Log       : ${LOG_FILE}${NC}"
echo -e "${CYAN}======================================================================${NC}"

# --- LOGLAMA FONKSİYONU ---
log() {
    local msg="[$(date +'%H:%M:%S')] $1"
    echo -e "$msg"
    echo "$msg" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE"
}

# --- TEMİZLİK ---
cleanup() {
    trap - EXIT INT TERM HUP QUIT
    local ec=$?
    log "${YELLOW}[*] Süreç sonlandı. Çıkış kodu: $ec${NC}"
    exit "$ec"
}
trap cleanup EXIT INT TERM HUP QUIT

# --- TERMAL KONTROL ---
log "${CYAN}[*] Termal kontrol yapılıyor...${NC}"
for zone in /sys/class/thermal/thermal_zone*/temp; do
    if [[ -r "$zone" ]]; then
        temp=$(( $(cat "$zone") / 1000 ))
        name=$(cat "${zone%/*}/type" 2>/dev/null || echo "bilinmeyen")
        if [[ $temp -gt 75 ]]; then
            log "${RED}[!] TERMAL UYARI: $name = ${temp}°C (eşik: 75°C)${NC}"
            if [[ "${1:-}" != "--force" ]]; then
                log "${YELLOW}[*] 10 saniye bekleniyor...${NC}"
                sleep 10
                temp=$(( $(cat "$zone") / 1000 ))
                if [[ $temp -gt 80 ]]; then
                    log "${RED}[-] KRİTİK SICAKLIK: Betik durduruldu. --force ile tekrar deneyin.${NC}"
                    exit 1
                fi
            fi
        else
            log "${GREEN}[+] $name = ${temp}°C (normal)${NC}"
        fi
    fi
done

# --- PAKET KONTROLÜ ---
if ! rpm -q usbguard &>/dev/null; then
    log "${YELLOW}[*] USBGuard kuruluyor...${NC}"
    dnf install -y usbguard
    log "${GREEN}[+] USBGuard kuruldu.${NC}"
else
    log "${GREEN}[+] USBGuard zaten kurulu: $(rpm -q usbguard)${NC}"
fi

# --- KONFİGÜRASYON ---
DAEMON_CONF="/etc/usbguard/usbguard-daemon.conf"
log "${CYAN}[*] Daemon konfigürasyonu yapılıyor...${NC}"

if [[ -f "$DAEMON_CONF" ]]; then
    cp "$DAEMON_CONF" "${DAEMON_CONF}.backup"
    
    sed -i 's/^ImplicitPolicyTarget=.*/ImplicitPolicyTarget=block/' "$DAEMON_CONF"
    sed -i 's/^IPCAllowedUsers=.*/IPCAllowedUsers=root/' "$DAEMON_CONF"
    sed -i 's/^IPCAllowedGroups=.*/IPCAllowedGroups=usbguard/' "$DAEMON_CONF"
    sed -i 's/^DeviceRulesWithPort=.*/DeviceRulesWithPort=true/' "$DAEMON_CONF"
    
    if grep -q "^RestoreControllerDeviceState=" "$DAEMON_CONF"; then
        sed -i 's/^RestoreControllerDeviceState=.*/RestoreControllerDeviceState=true/' "$DAEMON_CONF"
    else
        echo "RestoreControllerDeviceState=true" >> "$DAEMON_CONF"
    fi
    
    restorecon "$DAEMON_CONF" 2>/dev/null || true
    log "${GREEN}[+] Daemon konfigürasyonu tamam.${NC}"
else
    log "${RED}[-] HATA: $DAEMON_CONF bulunamadı.${NC}"
    exit 1
fi

# --- USBGUARD GRUBU ---
if ! getent group usbguard &>/dev/null; then
    groupadd -r usbguard
    log "${GREEN}[+] usbguard grubu oluşturuldu.${NC}"
fi

# --- BASELINE ---
RULES_FILE="/etc/usbguard/rules.conf"

if [[ -s "$RULES_FILE" ]] && [[ "$(wc -l < "$RULES_FILE")" -gt 0 ]]; then
    log "${GREEN}[+] Mevcut kurallar korunuyor ($(wc -l < "$RULES_FILE") kural).${NC}"
else
    log "${CYAN}======================================================================${NC}"
    log "${CYAN}[!] BAŞLANGIÇ DONANIM HARİTASI (BASELINE)${NC}"
    log "${CYAN}======================================================================${NC}"
    
    POLICY=$(usbguard generate-policy 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')
    
    echo ""
    echo "Aşağıda şu an takılı olan TÜM USB cihazlarınız listeleniyor:"
    echo "----------------------------------------------------------------------"
    echo "$POLICY"
    echo "----------------------------------------------------------------------"
    echo ""
    echo -e "${YELLOW}⚠️  Bu listede size ait olmayan, şüpheli bir cihaz var mı?${NC}"
    echo -e "${YELLOW}⚠️  TÜM cihazlar güvenliyse büyük harflerle PERMANENT yazın.${NC}"
    echo -e "${YELLOW}⚠️  Emin değilseniz Enter'a basın (iptal olur).${NC}"
    echo ""
    
    read -r -p "Cevabınız: " CONFIRM
    
    if [[ "$CONFIRM" == "PERMANENT" ]]; then
        echo "$POLICY" > "$RULES_FILE"
        chmod 600 "$RULES_FILE"
        restorecon "$RULES_FILE" 2>/dev/null || true
        log "${GREEN}[+] Baseline oluşturuldu ($(wc -l < "$RULES_FILE") kural).${NC}"
    else
        log "${RED}[-] Baseline iptal edildi. Cihazlar izinli listeye eklenmedi.${NC}"
        log "${YELLOW}[*] İpucu: Tekrar çalıştırıp PERMANENT yazabilirsiniz.${NC}"
        exit 0
    fi
fi

# --- SERVİSİ BAŞLAT ---
log "${CYAN}[*] USBGuard servisi başlatılıyor...${NC}"
systemctl daemon-reload
systemctl enable usbguard.service
systemctl restart usbguard.service

sleep 2
if systemctl is-active --quiet usbguard.service; then
    log "${GREEN}[+] USBGuard servisi AKTİF.${NC}"
else
    log "${RED}[-] HATA: Servis başlamadı!${NC}"
    log "${RED}[-] Kurtarma: sudo systemctl stop usbguard (tüm cihazları açar)${NC}"
    exit 1
fi

# --- YETKİLENDİRME ARACINI KUR ---
AUTH_BIN="/usr/local/bin/usb-authorize.sh"

cat > "$AUTH_BIN" << 'AUTH_SCRIPT'
#!/usr/bin/env bash
set -Eeuo pipefail
export PATH='/usr/sbin:/usr/bin:/sbin:/bin'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [[ "${EUID}" -ne 0 ]]; then
    echo -e "${RED}[-] Root yetkisi gerekli.${NC}"
    exit 1
fi

exec 8>/run/lock/aegis_usb_auth.lock
if ! flock -n 8; then
    echo -e "${RED}[-] Başka bir yetkilendirme işlemi devam ediyor.${NC}"
    exit 1
fi

DEVICE_ID=""

cleanup() {
    trap - EXIT INT TERM HUP QUIT
    if [[ -n "$DEVICE_ID" ]]; then
        echo -e "\n${YELLOW}[!] Temizlik: Cihaz geri bloke ediliyor...${NC}"
        usbguard block-device "$DEVICE_ID" 2>/dev/null || true
    fi
    exec 8>&- 2>/dev/null || true
    exit 0
}
trap cleanup EXIT INT TERM HUP QUIT

echo -e "${CYAN}======================================================${NC}"
echo -e "${CYAN}🛡️ ENGELLENEN USB CİHAZLARI${NC}"
echo -e "${CYAN}======================================================${NC}"

BLOCKED=$(usbguard list-devices -b 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')

if [[ -z "$BLOCKED" ]]; then
    echo -e "${GREEN}✅ Engellenen cihaz yok.${NC}"
    exit 0
fi

echo "$BLOCKED"
echo ""
read -r -p "Yetkilendirilecek cihaz ID'si: " TARGET_ID

if [[ ! "$TARGET_ID" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}[-] Geçersiz ID.${NC}"
    exit 1
fi

if ! echo "$BLOCKED" | grep -qF "${TARGET_ID}:"; then
    echo -e "${RED}[-] Cihaz listede yok.${NC}"
    exit 1
fi

echo ""
echo -e "${CYAN}Cihaz detayı:${NC}"
echo "$BLOCKED" | grep -F "${TARGET_ID}:"
echo ""
read -r -p "Geçici izin verilsin mi? (yes/no): " TEMP

if [[ ! "$TEMP" =~ ^(yes|y|Y)$ ]]; then
    echo -e "${YELLOW}[*] İptal edildi.${NC}"
    exit 0
fi

usbguard allow-device "$TARGET_ID"
DEVICE_ID="$TARGET_ID"
echo -e "${GREEN}[*] GEÇİCİ İZİN VERİLDİ.${NC}"
echo -e "${YELLOW}[INFO] Cihazı test edin.${NC}"
echo ""

read -r -p "Kalıcı mühür için PERMANENT yazın: " FINAL

if [[ "$FINAL" != "PERMANENT" ]]; then
    echo -e "${YELLOW}[*] Kalıcı izin verilmedi. Cihaz bloke ediliyor...${NC}"
    usbguard block-device "$TARGET_ID" 2>/dev/null || true
    DEVICE_ID=""
    exit 0
fi

# Kalıcı mühür - cihazı ALLOWED listesinde ara
if ! usbguard list-devices -a 2>/dev/null | grep -qF "${TARGET_ID}:"; then
    echo -e "${RED}[-] Cihaz bağlantısı koptu!${NC}"
    usbguard block-device "$TARGET_ID" 2>/dev/null || true
    DEVICE_ID=""
    exit 1
fi

usbguard allow-device "$TARGET_ID" -p
usbguard reload-rules 2>/dev/null || true
echo -e "${GREEN}[✔] BAŞARILI: Cihaz kalıcı listeye eklendi.${NC}"
DEVICE_ID=""
AUTH_SCRIPT

chmod 700 "$AUTH_BIN"
restorecon "$AUTH_BIN" 2>/dev/null || true
log "${GREEN}[+] Yetkilendirme aracı kuruldu: /usr/local/bin/usb-authorize.sh${NC}"

# --- ÖZET ---
echo ""
echo -e "${CYAN}======================================================================${NC}"
echo -e "${GREEN}🛡️ AEGIS KATMAN-02a TAMAMLANDI${NC}"
echo -e "${CYAN}======================================================================${NC}"
echo -e "USBGuard: $(systemctl is-active usbguard.service)"
echo -e "Kurallar: $(wc -l < "$RULES_FILE") cihaz izinli"
echo -e "Kullanım: sudo usb-authorize.sh"
echo -e "${CYAN}======================================================================${NC}"
