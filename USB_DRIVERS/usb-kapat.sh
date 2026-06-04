#!/bin/bash
# V10.2_AEGIS: USB Modül İzolasyonu & Cerrahi Söküm (Stable)
if [[ $EUID -ne 0 ]]; then echo "[!] HATA: Root yetkisi gerek."; exit 1; fi

echo "🛡️ [SİSTEM] USB Söküm Protokolü başlatılıyor..."
sync

MOUNT_POINTS=$(lsblk -nrpo TRAN,MOUNTPOINT | awk '$1=="usb" && $2!="" {print $2}')

if [[ -n "$MOUNT_POINTS" ]]; then
    echo "[!] USB Mount noktaları tespit edildi, güvenli söküm başlıyor..."
    while IFS= read -r mp; do
        umount "$mp" 2>/dev/null || umount -l "$mp"
    done <<< "$MOUNT_POINTS"
fi

if modprobe -r uas usb-storage 2>/dev/null; then
    # Terminoloji düzeltildi ve Systemd Audit eklendi
    echo "🔒 [SİSTEM] USB depolama sürücüleri çekirdekten kaldırıldı."
    systemd-cat -t aegis-usb -p info <<< "USB Depolama modulleri (usb-storage, uas) basariyla sokuldu. Portlar depolamaya kapatildi."
else
    echo "[!] HATA: Modüller kilitli. (Arka planda okuma/yazma işlemi devam ediyor olabilir)"
    systemd-cat -t aegis-usb -p warning <<< "USB Depolama modulleri sökülemedi: Cihaz mesgul."
    exit 1
fi
