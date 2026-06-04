#!/bin/bash
if [[ $EUID -ne 0 ]]; then echo "[!] HATA: Root yetkisi gerek."; exit 1; fi
modprobe usb-storage && modprobe uas
USB_PORT=$(lsusb -t | grep -o 'Port=[0-9]*' | head -n1 | cut -d= -f2)
[[ -n "$USB_PORT" ]] && echo "$USB_PORT" > /sys/bus/usb/drivers/usb/bind 2>/dev/null
echo "[+] USB Alt sistemi aktif."
