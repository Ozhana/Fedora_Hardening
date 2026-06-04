#!/bin/bash
# V10.2_AEGIS: USB Modül Aktivasyonu (Stable)
if [[ $EUID -ne 0 ]]; then echo "[!] HATA: Root yetkisi gerek."; exit 1; fi

modprobe usb-storage
modprobe uas 2>/dev/null || true

echo "🔓 [SİSTEM] USB Depolama sürücüleri aktif edildi."
systemd-cat -t aegis-usb -p info <<< "USB Depolama modulleri yüklendi. Portlar depolamaya acildi."
