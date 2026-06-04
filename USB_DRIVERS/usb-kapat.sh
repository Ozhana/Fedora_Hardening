#!/bin/bash
if [[ $EUID -ne 0 ]]; then echo "[!] HATA: Root yetkisi gerek."; exit 1; fi
MOUNT_POINTS=$(lsblk -no MOUNTPOINT | grep '^/run/media')
[[ -n "$MOUNT_POINTS" ]] && umount -l $MOUNT_POINTS 2>/dev/null
USB_PORT=$(lsusb -t | grep -o 'Port=[0-9]*' | head -n1 | cut -d= -f2)
[[ -n "$USB_PORT" ]] && echo "$USB_PORT" > /sys/bus/usb/drivers/usb/unbind 2>/dev/null
modprobe -r uas usb-storage 2>/dev/null
echo "[+] USB donanım seviyesinde kilitlendi."
