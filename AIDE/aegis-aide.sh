#!/usr/bin/env bash
# V18_AEGIS_SURFACE: Asynchronous AIDE Updater & Auditor (Zero-Entropy V6)

set -euo pipefail
umask 0077

FLAG_FILE="/run/aegis_aide_pending.flag"
PROCESS_FLAG="/run/aegis_aide_processing.flag"
AIDE_CONF="/etc/aide.conf"
AUDIT_LOG="/var/log/aegis_aide_audit.log"
LOCK_FILE="/run/aegis_aide.lock"

# 1. Kök Yetki Kontrolü
if [[ $EUID -ne 0 ]]; then
    systemd-cat -t aegis-aide -p err <<< "[FATAL] Bu betik root yetkileriyle çalıştırılmalıdır."
    exit 1
fi

# 2. Config State Check
if [[ ! -r "$AIDE_CONF" ]]; then
    systemd-cat -t aegis-aide -p err <<< "[FATAL] $AIDE_CONF okunamıyor veya mevcut değil."
    exit 1
fi

# 3. Race Condition Kalkanı: Atomic Move
if ! mv "$FLAG_FILE" "$PROCESS_FLAG" 2>/dev/null; then
    exit 0
fi

# 4. Kilit Mekanizması
exec 9>> "$LOCK_FILE"
if ! flock -n 9; then
    systemd-cat -t aegis-aide -p info <<< "[BİLGİ] AIDE taraması halihazırda çalışıyor. State korunuyor."
    # Hata Örtbas Edilmez (|| true kaldırıldı)
    if ! touch "$FLAG_FILE" 2>/dev/null; then
        systemd-cat -t aegis-aide -p warning <<< "[UYARI] Rollback: pending.flag oluşturulamadı (/run dolu/SELinux)."
    fi
    if ! rm -f "$PROCESS_FLAG" 2>/dev/null; then
        systemd-cat -t aegis-aide -p warning <<< "[UYARI] Rollback: processing.flag temizlenemedi."
    fi
    exit 0
fi

# 5. Trap: Cleanup ve Hata Yönetimi
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        systemd-cat -t aegis-aide -p emerg <<< "[KRİTİK] AIDE Update & Audit işlemi çöktü! Çıkış kodu: $exit_code"
        if ! touch "$FLAG_FILE" 2>/dev/null; then
            systemd-cat -t aegis-aide -p warning <<< "[UYARI] Cleanup: pending.flag geri yüklenemedi."
        fi
        if ! rm -f "$PROCESS_FLAG" 2>/dev/null; then
            systemd-cat -t aegis-aide -p warning <<< "[UYARI] Cleanup: processing.flag silinemedi."
        fi
    fi
}
trap cleanup EXIT INT TERM

# 6. Dinamik Config Ayrıştırma
AIDE_DB_OUT_RAW=$(awk -F= '/^[[:space:]]*database_out[[:space:]]*=/ {gsub(/[[:space:]]/, "", $2); print $2; exit}' "$AIDE_CONF")
AIDE_DB_NEW="${AIDE_DB_OUT_RAW#file:}"
AIDE_DB_NEW="${AIDE_DB_NEW:-/var/lib/aide/aide.db.new.gz}"

AIDE_DB_IN_RAW=$(awk -F= '/^[[:space:]]*database[[:space:]]*=/ {gsub(/[[:space:]]/, "", $2); print $2; exit}' "$AIDE_CONF")
AIDE_DB="${AIDE_DB_IN_RAW#file:}"
AIDE_DB="${AIDE_DB:-/var/lib/aide/aide.db.gz}"

AIDE_DIR=$(dirname "$AIDE_DB")

# 7. BTRFS chattr Capability Testi
SUPPORTS_IMMUTABLE=false
if TEST_FILE=$(mktemp "$AIDE_DIR/.aide_test.XXXXXX" 2>/dev/null); then
    if chattr +i "$TEST_FILE" 2>/dev/null; then
        SUPPORTS_IMMUTABLE=true
        chattr -i "$TEST_FILE" 2>/dev/null
    fi
    rm -f "$TEST_FILE"
else
    systemd-cat -t aegis-aide -p warning <<< "[UYARI] chattr capability testi başarısız oldu."
fi

# 8. Zırhı İndir
if [[ "$SUPPORTS_IMMUTABLE" == true && -f "$AIDE_DB" ]]; then
    if ! chattr -i "$AIDE_DB" 2>/dev/null; then
        systemd-cat -t aegis-aide -p warning <<< "[UYARI] $AIDE_DB zırhı indirilemedi."
    fi
fi

systemd-cat -t aegis-aide -p info <<< "[+] AIDE Audit & Update operasyonu başlatıldı..."

# 9. Çift Kademeli Tarama
set +e
{
    echo -e "\n====================================================="
    echo "AEGIS AIDE AUDIT: $(date --iso-8601=seconds)"
    echo "====================================================="
    aide --update
} >> "$AUDIT_LOG" 2>&1
AIDE_EXIT_CODE=$?
set -e

# 10. Değişimi Onayla, NVMe Flush (sync) ve Zırhı Kapat
if [[ -f "$AIDE_DB_NEW" && -s "$AIDE_DB_NEW" ]]; then
    
    sync -f "$AIDE_DB_NEW"
    mv -f "$AIDE_DB_NEW" "$AIDE_DB"
    # İkinci Atomic Sync: Inode hedef isim altındayken metadatayı NVMe'ye çivile
    sync -f "$AIDE_DB"
    
    if [[ "$SUPPORTS_IMMUTABLE" == true ]]; then
        if ! chattr +i "$AIDE_DB" 2>/dev/null; then
            systemd-cat -t aegis-aide -p warning <<< "[UYARI] Yeni AIDE DB chattr ile mühürlenemedi."
        fi
    fi
    
    if ! rm -f "$PROCESS_FLAG" 2>/dev/null; then
        systemd-cat -t aegis-aide -p warning <<< "[UYARI] İşlem sonrası processing.flag silinemedi."
    fi
    systemd-cat -t aegis-aide -p info <<< "[+] AIDE güncellendi (Exit: $AIDE_EXIT_CODE). Rapor eklendi."
else
    systemd-cat -t aegis-aide -p emerg <<< "[FATAL] Yeni veritabanı bulunamadı veya BOŞ (0 byte)!"
    exit 1
fi
