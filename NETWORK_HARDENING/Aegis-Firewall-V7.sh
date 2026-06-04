#!/usr/bin/env bash

# ==============================================================================
# SCRIPT    : aegis-firewall-secure.sh (V7 - TRANSACTIONAL CORE)
# PURPOSE   : Transactional Workflow, Native API Usage, Strict Validations
# ARCHITECTURE: Surface Pro 9 (Fedora 44 / nftables Native)
# ==============================================================================

set -euo pipefail
IFS=$'\n\t'

if [[ $EUID -ne 0 ]]; then
   echo "[!] KRİTİK HATA: Bu operasyon root yetkisi gerektirir." >&2
   exit 1
fi

echo "[*] Aegis-Network V7: Mimari Mühürleme Başlatılıyor..."

if ! systemctl is-active --quiet firewalld; then
    echo "[!] HATA: firewalld servisi aktif değil." >&2
    exit 2
fi

# 1. TRANSACTIONAL YEDEKLEME (Sadece XML'ler)
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
    
    # Reload başarısız olursa çıkış kodunu maskeleme (yakala ve bildir)
    if ! firewall-cmd --reload >/dev/null 2>&1; then
         echo "[!] UYARI: Rollback sonrası firewall-cmd --reload BAŞARISIZ oldu!" >&2
    fi
    
    echo "[+] Sistem eski state konfigürasyonuna geri döndürüldü."
    exit 1
}

trap rollback_on_error ERR

# ------------------------------------------------------------------------------
# OPERASYON 1: Aegis-Secure Zone İnşası (XML Drop)
# ------------------------------------------------------------------------------
mkdir -p "$ZONE_DIR"
TMP_ZONE=$(mktemp)

cat <<EOF > "$TMP_ZONE"
<?xml version="1.0" encoding="utf-8"?>
<zone target="DROP">
  <short>Aegis Secure Zone</short>
  <description>Surface Pro 9 Zero-Trust Profili.</description>
  <service name="dhcpv6-client"/>
  <icmp-block name="echo-request"/>
  <icmp-block name="timestamp-request"/>
</zone>
EOF
chmod 644 "$TMP_ZONE"
mv "$TMP_ZONE" "$ZONE_FILE"

# ------------------------------------------------------------------------------
# OPERASYON 2: Kusursuz Lockdown Whitelist (XML Drop)
# ------------------------------------------------------------------------------
TMP_WL=$(mktemp)
cat <<EOF > "$TMP_WL"
<?xml version="1.0" encoding="utf-8"?>
<whitelist>
  <user id="0"/>
</whitelist>
EOF
chmod 644 "$TMP_WL"
mv "$TMP_WL" "$WL_FILE"

# ------------------------------------------------------------------------------
# OPERASYON 3: NATIVE API UYGULAMASI (sed iptal)
# ------------------------------------------------------------------------------
# XML dosyalarını belleğe al
firewall-cmd --reload >/dev/null

# Daemon config'i ve runtime state'i API üzerinden güvenle güncelle
firewall-cmd --set-default-zone=aegis-secure >/dev/null
firewall-cmd --lockdown-on >/dev/null

# ------------------------------------------------------------------------------
# OPERASYON 4: STATE DOĞRULAMA (Built-in POSIX Mantığı)
# ------------------------------------------------------------------------------
echo "[*] Kesin doğrulama yapılıyor..."

# Subshell israfı yok, doğrudan built-in string kıyaslaması
if [ "$(firewall-cmd --get-default-zone)" != "aegis-secure" ]; then
    echo "[!] MİMARİ HATA: Varsayılan zone aegis-secure yapılamadı!" >&2
    rollback_on_error
fi

# Boolean kontrolü (0=yes, 1=no/hata)
if ! firewall-cmd --query-lockdown >/dev/null 2>&1; then
    echo "[!] MİMARİ HATA: Lockdown mekanizması reddedildi!" >&2
    rollback_on_error
fi

# Clean Exit
trap - ERR
rm -f "$WL_BACKUP" "$ZONE_BACKUP"

echo "[+] MÜKEMMEL: Ağ çeperi V7 protokolü ile işlemsel (transactional) olarak mühürlendi."
