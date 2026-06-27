#!/usr/bin/env bash
# AEGIS AIDE Updater & Auditor - KALICI ÇÖZÜM V7
# Bu betik, AIDE veritabanını günceller ve audit log'u tutar.

set -euo pipefail
umask 0077

# Sabitler
FLAG_FILE="/run/aegis_aide_pending.flag"
PROCESS_FLAG="/run/aegis_aide_processing.flag"
AIDE_CONF="/etc/aide.conf"
AUDIT_LOG="/var/log/aegis_aide_audit.log"
LOCK_FILE="/run/aegis_aide.lock"

# ============== 1. YETKİ KONTROLÜ ==============
if [[ $EUID -ne 0 ]]; then
    echo "[HATA] Root yetkisi gerekli!" >&2
    exit 1
fi

# ============== 2. KONFİG KONTROLÜ ==============
if [[ ! -r "$AIDE_CONF" ]]; then
    echo "[HATA] $AIDE_CONF okunamıyor!" >&2
    exit 1
fi

# ============== 3. RACE CONDITION KORUMASI ==============
if ! mv "$FLAG_FILE" "$PROCESS_FLAG" 2>/dev/null; then
    echo "[BİLGİ] Zaten çalışıyor veya pending yok"
    exit 0
fi

# ============== 4. KİLİT MEKANİZMASI ==============
exec 9>> "$LOCK_FILE"
if ! flock -n 9; then
    echo "[BİLGİ] Başka bir işlem çalışıyor"
    touch "$FLAG_FILE" 2>/dev/null || true
    rm -f "$PROCESS_FLAG" 2>/dev/null || true
    exit 0
fi

# ============== 5. TEMİZLİK FONKSİYONU ==============
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo "[KRİTİK] İşlem çöktü! Kod: $exit_code"
        touch "$FLAG_FILE" 2>/dev/null || true
        rm -f "$PROCESS_FLAG" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

# ============== 6. KONFİG AYRIŞTIRMA (DÜZELTİLMİŞ) ==============
# database_out değerini al ve file: önekini kaldır
AIDE_DB_OUT_RAW=$(awk -F= '/^[[:space:]]*database_out[[:space:]]*=/ {gsub(/[[:space:]]/, "", $2); print $2; exit}' "$AIDE_CONF" | cut -d'#' -f1)
if [[ "$AIDE_DB_OUT_RAW" =~ file: ]]; then
    AIDE_DB_NEW="${AIDE_DB_OUT_RAW#*file:}"
else
    AIDE_DB_NEW="$AIDE_DB_OUT_RAW"
fi
AIDE_DB_NEW=$(echo "$AIDE_DB_NEW" | xargs)
AIDE_DB_NEW="${AIDE_DB_NEW:-/var/lib/aide/aide.db.new.gz}"

# database değerini al ve file: önekini kaldır
AIDE_DB_IN_RAW=$(awk -F= '/^[[:space:]]*database[[:space:]]*=/ {gsub(/[[:space:]]/, "", $2); print $2; exit}' "$AIDE_CONF" | cut -d'#' -f1)
if [[ "$AIDE_DB_IN_RAW" =~ file: ]]; then
    AIDE_DB="${AIDE_DB_IN_RAW#*file:}"
else
    AIDE_DB="$AIDE_DB_IN_RAW"
fi
AIDE_DB=$(echo "$AIDE_DB" | xargs)
AIDE_DB="${AIDE_DB:-/var/lib/aide/aide.db.gz}"

AIDE_DIR=$(dirname "$AIDE_DB")

logger -t aegis-aide "[BİLGİ] Veritabanı yolları: $AIDE_DB_NEW -> $AIDE_DB"

if [[ ! -d "$AIDE_DIR" ]]; then
    mkdir -p "$AIDE_DIR"
    chmod 700 "$AIDE_DIR"
fi

# ============== 7. CHATTR TESTİ ==============
SUPPORTS_IMMUTABLE=false
if TEST_FILE=$(mktemp "$AIDE_DIR/.aide_test.XXXXXX" 2>/dev/null); then
    if chattr +i "$TEST_FILE" 2>/dev/null; then
        SUPPORTS_IMMUTABLE=true
        chattr -i "$TEST_FILE" 2>/dev/null
    fi
    rm -f "$TEST_FILE"
fi

# ============== 8. ZIRHI KALDIR ==============
if [[ "$SUPPORTS_IMMUTABLE" == true && -f "$AIDE_DB" ]]; then
    chattr -i "$AIDE_DB" 2>/dev/null || true
fi

# ============== 9. AIDE GÜNCELLEME ==============
echo "=====================================================" >> "$AUDIT_LOG"
echo "AEGIS AIDE AUDIT: $(date --iso-8601=seconds)" >> "$AUDIT_LOG"
echo "=====================================================" >> "$AUDIT_LOG"

set +e
aide --update >> "$AUDIT_LOG" 2>&1
AIDE_EXIT_CODE=$?
set -e

# ============== 10. SONUÇ KONTROLÜ ==============
if [[ -f "$AIDE_DB_NEW" && -s "$AIDE_DB_NEW" ]]; then
    sync -f "$AIDE_DB_NEW"

    if [[ -f "$AIDE_DB" ]]; then
        chattr -i "$AIDE_DB" 2>/dev/null || true
    fi

    mv -f "$AIDE_DB_NEW" "$AIDE_DB"
    sync -f "$AIDE_DB"

    if [[ "$SUPPORTS_IMMUTABLE" == true ]]; then
        chattr +i "$AIDE_DB" 2>/dev/null || true
    fi

    rm -f "$PROCESS_FLAG" 2>/dev/null || true

    echo "[BAŞARI] AIDE güncellendi! Exit kod: $AIDE_EXIT_CODE" >> "$AUDIT_LOG"
    logger -t aegis-aide "[BAŞARI] AIDE güncellendi"

    exit 0
else
    echo "[HATA] Yeni veritabanı oluşturulamadı!" >> "$AUDIT_LOG"
    echo "[HATA] Aranan yol: $AIDE_DB_NEW" >> "$AUDIT_LOG"

    touch "$FLAG_FILE" 2>/dev/null || true
    rm -f "$PROCESS_FLAG" 2>/dev/null || true

    logger -t aegis-aide "[HATA] Yeni veritabanı bulunamadı: $AIDE_DB_NEW"
    exit 1
fi
