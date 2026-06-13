#!/usr/bin/env bash

# ==============================================================================
# SCRIPT    : aegis-firewall-secure.sh (V7.2 - FIRESANDBOX OPTIMIZED)
# PURPOSE   : Transactional Workflow, Zero-Trust Lockdown with Localized Tmp
# ARCHITECTURE: Fedora 44 / RHEL / Enterprise Hardening with Containers
# ==============================================================================

set -euo pipefail
IFS=$'\n\t'

if [[ $EUID -ne 0 ]]; then
   echo "[!] KRİTİK HATA: Bu operasyon root yetkisi gerektirir." >&2
   exit 1
fi

echo "[*] Aegis-Network V7.2: Docker Uyumlu Mimari Mühürleme Başlatılıyor..."

if ! systemctl is-active --quiet firewalld; then
    echo "[!] HATA: firewalld servisi aktif değil." >&2
    exit 2
fi

# 1. TRANSACTIONAL YEDEKLEME
WL_FILE="/etc/firewalld/lockdown-whitelist.xml"
WL_BACKUP="/etc/firewalld/lockdown-whitelist.xml.aegis_bak"

ZONE_DIR="/etc/firewalld/zones"
ZONE_FILE="${ZONE_DIR}/aegis-secure.xml"
ZONE_BACKUP="${ZONE_DIR}/aegis-secure.xml.aegis_bak"

[ -f "$WL_FILE" ] && cp -a "$WL_FILE" "$WL_BACKUP"
[ -f "$ZONE_FILE" ] && cp -a "$ZONE_FILE" "$ZONE_BACKUP"

rollback_on_error() {
    echo "[!] KRİTİK HATA TESPİTİ: Transactional Rollback Devrede..."
    [ -f "$WL_BACKUP" ] && mv "$WL_BACKUP" "$WL_FILE"
    if [ -f "$ZONE_BACKUP" ]; then
        mv "$ZONE_BACKUP" "$ZONE_FILE"
    else
        rm -f "$ZONE_FILE"
    fi
    firewall-cmd --reload >/dev/null 2>&1 || true
    echo "[+] Sistem eski konfigürasyon durumuna geri döndürüldü."
    exit 1
}

trap rollback_on_error ERR

# ------------------------------------------------------------------------------
# OPERASYON 1: Aegis-Secure Zone İnşası (XML Drop)
# ------------------------------------------------------------------------------
mkdir -p "$ZONE_DIR"

# DÜZELTME: Geçici dosyayı /etc/firewalld içinde oluşturuyoruz (Sandbox yetki kilitlerini aşmak için)
TMP_ZONE=$(mktemp -p "$ZONE_DIR" tmp.zone.XXXXXXXX.xml)

cat <<EOF > "$TMP_ZONE"
<?xml version="1.0" encoding="utf-8"?>
<zone target="DROP">
  <short>Aegis Secure Zone</short>
  <description>Zero-Trust Docker Friendly Profile.</description>
  <icmp-block name="echo-request"/>
  <icmp-block name="timestamp-request"/>
  <icmp-block name="network-redirect"/>
</zone>
EOF
chmod 644 "$TMP_ZONE"
mv "$TMP_ZONE" "$ZONE_FILE"

# ------------------------------------------------------------------------------
# OPERASYON 2: Kusursuz Lockdown Whitelist (Docker İçin İzin Bölgesi)
# ------------------------------------------------------------------------------
# DÜZELTME: Geçici dosyayı yerel dizinde oluşturuyoruz
TMP_WL=$(mktemp -p "/etc/firewalld" tmp.wl.XXXXXXXX.xml)

cat <<EOF > "$TMP_WL"
<?xml version="1.0" encoding="utf-8"?>
<whitelist>
  <user id="0"/>
  <command name="/usr/bin/python3*"/>
  <command name="/usr/sbin/iptables*"/>
  <command name="/usr/sbin/nft*"/>
</whitelist>
EOF
chmod 644 "$TMP_WL"
mv "$TMP_WL" "$WL_FILE"

# ------------------------------------------------------------------------------
# OPERASYON 3: NATIVE API UYGULAMASI
# ------------------------------------------------------------------------------
firewall-cmd --reload >/dev/null

firewall-cmd --set-default-zone=aegis-secure >/dev/null
firewall-cmd --set-log-denied=all >/dev/null
firewall-cmd --lockdown-on >/dev/null

# ------------------------------------------------------------------------------
# OPERASYON 4: STATE DOĞRULAMA
# ------------------------------------------------------------------------------
echo "[*] Kesin doğrulama yapılıyor..."

if [ "$(firewall-cmd --get-default-zone)" != "aegis-secure" ]; then
    echo "[!] MİMARİ HATA: Varsayılan zone ayarlanamadı!" >&2
    rollback_on_error
fi

if ! firewall-cmd --query-lockdown >/dev/null 2>&1; then
    echo "[!] MİMARİ HATA: Lockdown mekanizması reddedildi!" >&2
    rollback_on_error
fi

# Temiz Çıkış
trap - ERR
rm -f "$WL_BACKUP" "$ZONE_BACKUP"
echo "[+] MÜKEMMEL: Sistem hem Docker/n8n uyumlu hale getirildi hem de V7.2 mühürü vuruldu."
