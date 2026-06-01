#!/usr/bin/env bash
# ==============================================================================
# SCRIPT: usb-authorize.sh
# AUTHOR: Dr. Ozhan Akdag
# DESCRIPTION: TOCTOU zafiyetlerini engelleyen, hash/topoloji tabanlı doğrulama 
#              yapan ve tam deterministik (AWK) Zero-Trust yetkilendirme mimarisi.
# ==============================================================================

# 1. STRICT MODE (KATI HATA YÖNETİMİ)
set -Eeuo pipefail
IFS=$'\n\t'

LOCK_FILE="/var/tmp/usbguard_admin.lock"

# 2. FAIL-FAST: KOMUT VE SERVİS KONTROLLERİ (Ön Uç Savunması)
if ! command -v usbguard >/dev/null 2>&1; then
    echo "[FATAL] 'usbguard' komutu bulunamadı. Sistemde yüklü olduğundan emin olun." >&2
    exit 1
fi

if ! systemctl is-active --quiet usbguard.service; then
    echo "[FATAL] usbguard servisi şu anda aktif değil! Önce servisi başlatın." >&2
    exit 1
fi

# 3. TRAP & CLEANUP: rm komutu kaldırıldı (Inode Split-Brain Koruması)
cleanup() {
    local exit_code=$?
    if [ -n "${LOCK_FD:-}" ]; then
        exec {LOCK_FD}>&- 
    fi
    if [ "$exit_code" -ne 0 ]; then
        echo -e "\n[!] İşlem iptal edildi veya anormal sonlandı (Kod: $exit_code)." >&2
    fi
    exit "$exit_code"
}
trap cleanup EXIT INT TERM

# 4. ATOMIC LOCK (Yarış Durumu Koruması)
exec {LOCK_FD}>"$LOCK_FILE"
if ! flock -n "$LOCK_FD"; then
    echo "[HATA] Sistemde halihazırda çalışan bir işlem var." >&2
    exit 1
fi

# 5. ROOT DOĞRULAMASI
if [ "$(id -u)" -ne 0 ]; then
    echo "[HATA] Bu betik sudo yetkileri ile çalıştırılmalıdır." >&2
    exit 1
fi

echo "======================================================"
echo "[+] ENGELLENEN (BLOCKED) USB CİHAZLARI TARANIYOR..."
echo "======================================================"

BLOCKED_DEVICES=$(usbguard list-devices -b)

if [ -z "$BLOCKED_DEVICES" ]; then
    echo "[-] Şu anda engellenmiş durumda olan bir cihaz bulunmuyor."
    exit 0
fi

echo "$BLOCKED_DEVICES"
echo "------------------------------------------------------"

# 6. GİRDİ DOĞRULAMASI
read -r -p "Onaylamak istediğiniz cihazın ID numarasını girin: " TARGET_ID

if ! [[ "$TARGET_ID" =~ ^[0-9]+$ ]]; then
    echo "[HATA] Lütfen sadece sayısal bir ID değeri girin!" >&2
    exit 1
fi

# ==============================================================================
# 7. ÇAPRAZ DOĞRULAMA (Deterministik AWK Mimarisi)
# Grep yerine veriyi matematiksel bir matris gibi işleyerek format 
# kaymalarına (boşluk/sekme) karşı tam bağışıklık sağlandı.
# ==============================================================================
DEVICE_LINE=$(echo "$BLOCKED_DEVICES" | awk -F: -v id="$TARGET_ID" '$1 == id {print $0}' || true)

if [ -z "$DEVICE_LINE" ]; then
    echo "[HATA] Girdiğiniz ID ($TARGET_ID) engellenen cihazlar listesinde bulunamadı!" >&2
    exit 1
fi

# 8. HASH VE TOPOLOJİK ÇIPA (VIA-PORT) ÇIKARTIMI
DEVICE_HASH=$(echo "$DEVICE_LINE" | sed -n 's/.*hash "\([^"]*\)".*/\1/p')
DEVICE_PORT=$(echo "$DEVICE_LINE" | sed -n 's/.*via-port "\([^"]*\)".*/\1/p')

if [ -z "$DEVICE_HASH" ] && [ -z "$DEVICE_PORT" ]; then
    echo "[FATAL] Cihazın Hash veya Port değeri okunamadı!" >&2
    echo "[INFO] USBGuard çıktı formatı değişmiş olabilir. Güvenlik gereği iptal ediliyor." >&2
    exit 1
fi

echo -e "\n[!] HEDEF CİHAZ DOĞRULANDI:"
echo ">>> Cihaz Verisi  : $DEVICE_LINE"
echo ">>> Kripto Hash   : ${DEVICE_HASH:-Yok/Okunamadı}"
echo ">>> Topolojik Port: ${DEVICE_PORT:-Yok/Okunamadı}"
echo "------------------------------------------------------"

# 9. GEÇİCİ İZİN (SANDBOX EVRESİ)
read -r -p "Bu cihaza test için GEÇİCİ (Temporary) izin vermek istiyor musunuz? (yes/no): " CONFIRM_TEMP

if [[ ! "$CONFIRM_TEMP" =~ ^(yes|y|Y|YES)$ ]]; then
    echo "[-] İşlem kullanıcı tarafından iptal edildi."
    exit 0
fi

usbguard allow-device "$TARGET_ID"

echo -e "\n[*] GEÇİCİ İZİN VERİLDİ."
echo "[INFO] Lütfen cihazınızda donanım testlerinizi gerçekleştirin."
echo "------------------------------------------------------"

# 10. KOGNİTİF SÜRTÜNME VE KALICI ONAY
echo "KALICI OLARAK EKLENECEK CİHAZ:"
echo "$DEVICE_LINE"
echo ""
read -r -p "Bu işlemi onaylıyorsanız PERMANENT yazın: " FINAL_CONFIRM

# ==============================================================================
# 11. DİNAMİK ID DOĞRULAMASI (Hardware 2FA / TOCTOU Koruması / Pure AWK)
# Uzun ve kırılgan pipe'lar (grep | awk | tr | head) yerine, 
# veriyi tek hamlede yakalayan deterministik AWK kullanıldı.
# ==============================================================================
if [ -n "$DEVICE_HASH" ]; then
    CURRENT_ID=$(usbguard list-devices | awk -F: -v search="hash \"$DEVICE_HASH\"" '$0 ~ search {gsub(/^[ \t]+/, "", $1); print $1; exit}')
elif [ -n "$DEVICE_PORT" ]; then
    CURRENT_ID=$(usbguard list-devices | awk -F: -v search="via-port \"$DEVICE_PORT\"" '$0 ~ search {gsub(/^[ \t]+/, "", $1); print $1; exit}')
fi

if [ -z "$CURRENT_ID" ]; then
    echo -e "\n[FATAL] Cihaz test sırasında sistemden (veya porttan) ÇIKARILMIŞ!" >&2
    echo "Olası bir Race Condition engellendi. İşlem iptal edildi." >&2
    exit 1
fi

if [[ "$FINAL_CONFIRM" == "PERMANENT" ]]; then
    usbguard allow-device "$CURRENT_ID" -p
    echo -e "\n[✔] BAŞARILI: Cihaz ($CURRENT_ID) güvenli listeye kalıcı olarak eklendi."
else
    echo -e "\n[!] Kalıcı onay verilmedi (Yanlış kelime veya iptal)."
    echo "[-] Cihaz tekrar ENGELLENİYOR..."
    usbguard block-device "$CURRENT_ID"
    echo "[-] Cihaz başarıyla engellendi."
fi
