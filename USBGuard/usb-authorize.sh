#!/bin/bash
# ==============================================================================
# ENTERPRISE-GRADE USB AUTHORIZATION MATRIX (V4 - Native Mühürleme)
# ==============================================================================
# AUTHOR: Dr. Ozhan Akdag 
# DESC  : BadUSB ve RubberDucky korumalı (Human-in-the-loop) cihaz onaylama betiği.
#         USBGuard native komutları ve anlık durum senkronizasyonu kullanır.
# ==============================================================================

set -Eeuo pipefail

# 1. Kalkanları Kontrol Et
if ! command -v usbguard &> /dev/null; then
    echo "[HATA] USBGuard sistemde bulunamadı. Koruma kalkanı aktif değil!"
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
    echo "[HATA] Bu operasyon mutlak Root (sudo) yetkisi gerektirir."
    exit 1
fi

echo "======================================================"
echo "[+] ENGELLENEN (BLOCKED) USB CİHAZLARI TARANIYOR..."
echo "======================================================"

# Engellenen cihazları listele
BLOCKED_DEVICES=$(usbguard list-devices -b)

if [ -z "$BLOCKED_DEVICES" ]; then
    echo "✅ [GÜVENLİ] Kapıda bekleyen şüpheli veya engellenmiş bir donanım yok."
    exit 0
fi

echo "$BLOCKED_DEVICES"
echo "------------------------------------------------------"
read -r -p "Onaylamak istediğiniz cihazın ID numarasını girin (İptal için Enter): " TARGET_ID

if [ -z "$TARGET_ID" ]; then
    echo "İşlem iptal edildi."
    exit 0
fi

# Cihazın gerçekten engellenenler listesinde olup olmadığını doğrula (Verify)
if ! echo "$BLOCKED_DEVICES" | grep -q "^$TARGET_ID:"; then
    echo "[HATA] Geçersiz ID! Cihaz kapıda değil veya ID yanlış."
    exit 1
fi

# Sadece hedef cihazın satırını çek
DEVICE_LINE=$(echo "$BLOCKED_DEVICES" | grep "^$TARGET_ID:")

echo -e "\n[!] HEDEF CİHAZ DOĞRULANDI:"
echo ">>> $DEVICE_LINE"
echo "------------------------------------------------------"

# 2. Geçici İzin (Korumalı Test Aşaması)
read -r -p "Bu cihaza test için GEÇİCİ (Temporary) izin vermek istiyor musunuz? (yes/no): " TEMP_ALLOW

if [[ "$TEMP_ALLOW" =~ ^(yes|y|Y)$ ]]; then
    # Geçici izin ver
    usbguard allow-device "$TARGET_ID"
    echo -e "\n[*] GEÇİCİ İZİN VERİLDİ."
    echo "[INFO] Lütfen cihazınızda donanım testlerinizi gerçekleştirin."
else
    echo -e "\n[INFO] Test aşaması atlanıyor..."
fi

echo "------------------------------------------------------"
echo "KALICI OLARAK EKLENECEK CİHAZ:"
echo "$DEVICE_LINE"
echo ""

# 3. Kalıcı Mühür (Idempotent)
read -r -p "Bu işlemi onaylıyorsanız PERMANENT yazın: " CONFIRM

if [ "$CONFIRM" == "PERMANENT" ]; then
    # Kuralı Native olarak (ve -p ile kalıcı olarak) mühürle
    usbguard allow-device "$TARGET_ID" -p
    
    # İllüzyonu (RAM-Disk Gecikmesini) kırmak için servisi anında senkronize et
    usbguard reload-rules
    
    echo -e "\n[✔] BAŞARILI: Cihaz güvenli listeye native olarak kazındı ve sistem senkronize edildi."
else
    echo -e "\n[!] İŞLEM İPTAL EDİLDİ: Kalıcı izin verilmedi."
    
    # Eğer geçici izin verildiyse ve iptal edildiyse, cihazı geri blockla (Temizlik)
    if [[ "$TEMP_ALLOW" =~ ^(yes|y|Y)$ ]]; then
        usbguard block-device "$TARGET_ID"
        echo "[INFO] Cihazın geçici izni geri alındı ve tekrar kapıya konuldu."
    fi
fi
