#!/bin/bash
# V22.1_AEGIS: USB Sistem Radarı ve Çoklu Parametre Telemetri Motoru
# Surface Pro 9 + Fedora Workstation için dondurulmuş nihai kararlı sürüm.

set -euo pipefail

# 1. SIGINT / SIGTERM Sinyal Kalkanı (Terminal State Preservation)
trap "echo -e '\n[!] Radar durduruldu. Güvenli çıkış yapılıyor...'; exit 0" INT TERM

# 2. EUID Kök Denetimi
if [[ $EUID -ne 0 ]]; then
    echo "[!] FATAL: Bu radar Kernel Sysfs ağacını okur. ROOT yetkisi gerektirir."
    exit 1
fi

# 3. Ön Uç Bağımlılık Doğrulaması (Hard Requirement)
for cmd in lsusb lsblk usbguard awk journalctl systemctl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "[!] FATAL: Sistem bileşeni eksik: $cmd"
        exit 1
    fi
done

# Varsayılan Değişken Tanımlamaları
MODE="STANDARD"
SYS_HEALTH="BELİRSİZ"

# Parametre Yakalayıcı (CLI Argument Parser)
if [[ $# -gt 0 ]]; then
    case "$1" in
        --json) MODE="JSON" ;;
        --simulate) MODE="SIMULATE" ;;
        --watch) MODE="WATCH" ;;
        *)
            echo "Kullanım: usb-radar [--json | --simulate | --watch]"
            exit 1
            ;;
    esac
fi

# Canlı İzleme Döngüsü
while true; do

    # Veri Toplama Evresi (Verify, Don't Assume)
    USB_STORAGE_LOADED=$( [[ -d /sys/module/usb_storage ]] && echo "YÜKLÜ" || echo "KAPALI" )
    UAS_LOADED=$( [[ -d /sys/module/uas ]] && echo "YÜKLÜ" || echo "KAPALI" )
    
    USBGUARD_STATE=$(systemctl show -p ActiveState --value usbguard 2>/dev/null || echo "not-found")
    [[ "$USBGUARD_STATE" == "active" ]] && STATUS_USBGUARD="AKTİF" || STATUS_USBGUARD="PASİF"

    # Don't Assume, Verify: Sütun kaymalarına karşı zırhlandırılmış Mount Analizi (Risk Analizi Modeli)
    DISK_RAW=$(lsblk -nrpo TRAN,TYPE,MOUNTPOINT | awk '$1=="usb" && $2=="disk"')
    if [[ -z "$DISK_RAW" ]]; then
        STATUS_DISK="YOK"
    else
        # 3. Kolonun boşluk içermediğini ve bir path içerdiğini doğrula
        if echo "$DISK_RAW" | awk '$3 != "" {print $3}' | grep -q "^/"; then
            STATUS_DISK="MOUNT_EDİLMİŞ"
        else
            STATUS_DISK="TAKILI_UNMOUNTED"
        fi
    fi

    # Deterministik Awk Sayacı (String Fragility ve Pipe Entropisi Yok Edildi)
    TOTAL_ALLOW=$(usbguard list-devices 2>/dev/null | awk '$2=="allow" {count++} END {print count+0}')
    TOTAL_BLOCK=$(usbguard list-devices 2>/dev/null | awk '$2=="block" {count++} END {print count+0}')

    # 4 Boyutlu ve Objektif Durum Matrisi Analizi
    if [[ "$STATUS_USBGUARD" == "AKTİF" && "$USB_STORAGE_LOADED" == "KAPALI" ]]; then
        SYS_HEALTH="MÜHÜRLÜ_GÜVENLİ"
    elif [[ "$STATUS_USBGUARD" == "AKTİF" && "$USB_STORAGE_LOADED" == "YÜKLÜ" ]]; then
        SYS_HEALTH="KATMANLI_GÜVENLİ_STORAGE_AÇIK"
    elif [[ "$STATUS_USBGUARD" == "PASİF" && "$USB_STORAGE_LOADED" == "KAPALI" ]]; then
        SYS_HEALTH="KISMEN_KORUMALI_MODÜL_İZOLASYONU"
    else
        SYS_HEALTH="TEHLİKE_SAVUNMASIZ"
    fi

    # --- SÜZGEÇ 1: SAF JSON ÇIKTISI (--json) ---
    if [[ "$MODE" == "JSON" ]]; then
        cat << EOF
{
  "aegis_radar": {
    "timestamp": "$(date --iso-8601=seconds)",
    "system_state": "$SYS_HEALTH",
    "kernel_modules": {
      "usb_storage": "$USB_STORAGE_LOADED",
      "uas": "$UAS_LOADED"
    },
    "hardware_firewall": {
      "usbguard_service": "$STATUS_USBGUARD",
      "devices_allowed": $TOTAL_ALLOW,
      "devices_blocked": $TOTAL_BLOCK
    },
    "storage_devices": {
      "status": "$STATUS_DISK"
    }
  }
}
EOF
        exit 0

    # --- SÜZGEÇ 2: SİMÜLASYON MODU (--simulate) ---
    elif [[ "$MODE" == "SIMULATE" ]]; then
        echo "🔮 [DRY-RUN] AEGIS TELEMETRİ SİMÜLASYONU TETİKLENDİ"
        echo "--------------------------------------------------------"
        echo "  [>] Eğer şu an bir USB depolama saldırısı gerçekleşseydi:"
        if [[ "$STATUS_USBGUARD" == "AKTİF" ]]; then
            echo "    [*] Katman 1 (USBGuard) : Cihaz imzası taranacak ve BLOKLANACAK."
        else
            echo "    [!] Katman 1 (USBGuard) : DEVRE DIŞI! Zararlı donanım sisteme sızabilir!"
        fi
        
        if [[ "$USB_STORAGE_LOADED" == "KAPALI" ]]; then
            echo "    [*] Katman 2 (Kernel)   : usb-storage sökük. Sürücü tetiklenmeyecek (Mass Storage Blindness)."
        else
            echo "    [!] Katman 2 (Kernel)   : Sürücüler aktif. Donanım sızarsa veri hattı otomatik açılır."
        fi
        echo "--------------------------------------------------------"
        exit 0
    fi

    # --- SÜZGEÇ 3: STANDART VE WATCH MODU ÇIKTISI ---
    if [[ "$MODE" == "WATCH" ]]; then clear; fi
    
    echo "========================================================"
    echo " 🛡️ V22.1_AEGIS: SURFACE PRO 9 USB THREAT RADAR"
    [[ "$MODE" == "WATCH" ]] && echo " [YENİLENİYOR - CANLI İZLEME MODU (Zaman: $(date +%H:%M:%S))]"
    echo "========================================================"
    
    echo -e "\n[+] 1. ÇEKİRDEK VE DRIVER DURUMU"
    echo "    usb-storage Modülü : $USB_STORAGE_LOADED"
    echo "    uas Modülü         : $UAS_LOADED"
    echo "    USBGuard Servisi   : $STATUS_USBGUARD"
    
    echo -e "\n[+] 2. USBGUARD DONANIM ANALİZİ"
    if [[ "$TOTAL_BLOCK" -eq 0 ]]; then
        if [[ "$TOTAL_ALLOW" -gt 0 ]]; then
            echo "    [✔] Durum Temiz: Engellenen cihaz yok. $TOTAL_ALLOW cihaz beyaz listede (ALLOW)."
        else
            echo "    [-] Donanım Hattı: Sistemde hiçbir USB donanımı saptanmadı."
        fi
    else
        echo "    [❌ ALERT] Engellenen Tehdit Sayısı: $TOTAL_BLOCK"
        usbguard list-devices 2>/dev/null | awk '$2=="block"' | awk '{
            match($0, /id [0-9A-Fa-f:]+/); id=substr($0, RSTART+3, RLENGTH-3);
            match($0, /name "[^"]*"/); name=substr($0, RSTART+6, RLENGTH-7);
            printf "      -> [BLOCKED] ID: %-10s | %s\n", id, name;
        }'
    fi
    
    echo -e "\n========================================================"
    echo " GÜVENLİK VE METADATA ÖZETİ:"
    echo -e "  -> USB Depolama Donanımı : $STATUS_DISK"
    echo -e "  -> SİSTEMİN SAĞLIK KODU  : $SYS_HEALTH"
    echo -e "========================================================\n"

    # Döngü Kontrolü ve Watch Gecikmesi
    if [[ "$MODE" == "WATCH" ]]; then
        sleep 2
    else
        exit 0
    fi
done
