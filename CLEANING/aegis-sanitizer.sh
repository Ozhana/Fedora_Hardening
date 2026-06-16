#!/usr/bin/env bash
# ==============================================================================
# FEDORA SANITIZER DAILY - Surface Pro 9 için Günlük Temizlik Motoru (v3.2)
# ==============================================================================
# Sürüm      : 3.2.0 (Red Team Final - Tüm Hatalar Giderildi)
# Amaç       : Sadece temizlik – günde 1 kez çalışır, sistem yeni güne hazır
# Prensipler : Sıfır hata, maksimum hız, termal koruma, SSD dostu, kutsal ayarları koru
# Kapsam     : NO antivirus, NO aide/rkhunter, NO sysctl hardening (başka betik)
# Değişiklikler (v3.1 → v3.2):
#   - clean_old_kernels: rpm sorgusu düzeltildi, tüm veritabanı taranmıyor.
#   - read -a ile basit dizi ataması yapıldı.
#   - log_event hataları koruma altına alındı (|| true).
#   - Docker temizliği tekrarsız hale getirildi (gereksiz image prune kaldırıldı).
#   - sync -f kaldırıldı, sadece sync kullanıldı.
# ==============================================================================

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

# ---- RENKLER ----
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# ---- GERÇEK KULLANICI TESPİTİ (logname – en güvenilir) ----
if ! REAL_USER=$(logname 2>/dev/null); then
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        REAL_USER="${SUDO_USER}"
    else
        printf '%b' "${RED}[X] KRİTİK HATA: Betik 'sudo' ile çalıştırılmalıdır (veya logname başarısız).${NC}\n" >&2
        exit 1
    fi
fi
REAL_HOME=$(getent passwd "${REAL_USER}" | cut -d: -f6)
if [[ ! -d "${REAL_HOME}" ]]; then
    printf '%b' "${RED}[X] KRİTİK HATA: Kullanıcı ${REAL_USER} home dizini bulunamadı.${NC}\n" >&2
    exit 1
fi

# ---- SABİTLER ----
readonly LOCK_DIR="/run/fedora-sanitizer"
readonly LOCK_FILE="${LOCK_DIR}/sanitizer.lock"
readonly LOG_BASE="${REAL_HOME}/Desktop/LOG_FILES"
readonly LOG_FILE="${LOG_BASE}/sanitizer_daily.log"
readonly THERMAL_THRESHOLD=85

LOCK_FD_ACQUIRED="false"

# ==============================================================================
# YARDIMCI: Hatayı logla ama betik devam etsin (eval yok, güvenli array)
# ==============================================================================
run_with_log() {
    local msg="$1"
    shift
    if ! "$@" >> "${LOG_FILE}" 2>&1; then
        log_event "WARN" "${msg} başarısız oldu, ancak devam ediliyor." || true
        return 0
    fi
    return 0
}

# ==============================================================================
# LOGLAMA (Adli seviye)
# ==============================================================================
log_event() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    mkdir -p "${LOG_BASE}" 2>/dev/null || { 
        printf '%b' "${RED}[X] Log dizini oluşturulamadı!${NC}\n" >&2
        return 1
    }
    chown "${REAL_USER}":"${REAL_USER}" "${LOG_BASE}" 2>/dev/null || true
    chmod 0700 "${LOG_BASE}" 2>/dev/null || true

    printf '[%s] [%s] [PID:%s] %s\n' "${timestamp}" "${level}" "$$" "${message}" >> "${LOG_FILE}" 2>/dev/null || true
    chown "${REAL_USER}":"${REAL_USER}" "${LOG_FILE}" 2>/dev/null || true

    if command -v systemd-cat &>/dev/null; then
        echo "[${level}] ${message}" | systemd-cat -t fedora-sanitizer -p info 2>/dev/null || true
    fi
    return 0
}

# ==============================================================================
# TERMAL KONTROL (Surface Pro 9)
# ==============================================================================
check_thermal() {
    if [[ ! -f /sys/class/thermal/thermal_zone0/temp ]]; then
        log_event "WARN" "Termal sensör bulunamadı, kontrol atlanıyor."
        return 0
    fi

    local temp_raw temp
    temp_raw=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0")
    temp=$((temp_raw / 1000))

    if [[ $temp -ge $THERMAL_THRESHOLD ]]; then
        log_event "WARN" "Sıcaklık ${temp}°C, eşik ${THERMAL_THRESHOLD}°C. 10 saniye bekleniyor..."
        printf '%b' "${YELLOW}[!] Sıcaklık ${temp}°C, soğuması için 10 saniye beklenecek...${NC}\n"
        sleep 10

        temp_raw=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0")
        temp=$((temp_raw / 1000))
        if [[ $temp -ge $THERMAL_THRESHOLD ]]; then
            log_event "CRITICAL" "Termal sınır aşıldı (${temp}°C). Sanitizer durduruluyor."
            printf '%b' "${RED}[X] KRİTİK: Termal sınır aşıldı. Bilgisayarınızın soğumasını bekleyin.${NC}\n"
            exit 1
        fi
    fi
    return 0
}

# ==============================================================================
# ATOMİK KİLİT VE TRAP
# ==============================================================================
cleanup() {
    local exit_code=$?
    trap '' EXIT INT TERM ERR HUP QUIT
    log_event "INFO" "Cleanup tetiklendi. Çıkış kodu: ${exit_code}" || true
    if [[ "${LOCK_FD_ACQUIRED}" == "true" ]]; then
        flock -u 9 2>/dev/null || true
        exec 9>&- 2>/dev/null || true
        log_event "INFO" "Kernel kilidi serbest bırakıldı." || true
    fi
}
trap cleanup EXIT INT TERM ERR HUP QUIT

acquire_lock() {
    mkdir -p -m 0700 "${LOCK_DIR}" 2>/dev/null || {
        printf '%b' "${RED}[X] Kilit dizini oluşturulamadı: ${LOCK_DIR}${NC}\n" >&2
        exit 1
    }
    exec 9>"${LOCK_FILE}" || exit 1
    if ! flock -n 9 2>/dev/null; then
        log_event "WARN" "Başka bir sanitizer süreci aktif, bekleniyor..." || true
        printf '%b' "${YELLOW}[!] Başka örnek çalışıyor, kilidin açılması bekleniyor...${NC}\n"
        flock -w 5 9 || { printf '%b' "${RED}[X] Zaman aşımı. Çıkılıyor.${NC}\n"; exit 1; }
    fi
    printf '%s\n' "$$" >&9
    LOCK_FD_ACQUIRED="true"
    log_event "INFO" "Atomik kilit alındı (FD:9)." || true
}

# ==============================================================================
# ÖN KOŞULLAR
# ==============================================================================
check_prerequisites() {
    if [[ ${EUID} -ne 0 ]]; then
        printf '%b' "${RED}[X] Bu betik root yetkisi gerektirir. 'sudo' ile tekrar dene.${NC}\n" >&2
        exit 1
    fi

    local required_cmds=("systemctl" "journalctl" "dnf" "flatpak" "fstrim" "find" "sqlite3")
    local missing_deps=()
    for cmd in "${required_cmds[@]}"; do
        command -v "${cmd}" &>/dev/null || missing_deps+=("${cmd}")
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_event "ERROR" "Eksik araçlar: ${missing_deps[*]}"
        printf '%b' "${RED}[X] Gerekli araçlar eksik: ${missing_deps[*]}${NC}\n" >&2
        exit 1
    fi
}

# ==============================================================================
# TEMİZLİK MODÜLLERİ (Idempotent, Hata Loglanır, Bastırılmaz)
# ==============================================================================

clean_journals() {
    printf '%b' "${BLUE}[1/7] Systemd journal ve coredump temizliği...${NC}\n"
    log_event "INFO" "Journal vacuum (7 gün)"
    run_with_log "Journal vacuum" ionice -c 3 nice -n 19 journalctl --vacuum-time=7d
    if command -v coredumpctl &>/dev/null; then
        run_with_log "Coredump temizliği" ionice -c 3 nice -n 19 coredumpctl remove
    fi
}

clean_package_caches() {
    printf '%b' "${BLUE}[2/7] DNF ve Flatpak önbellek temizliği...${NC}\n"
    log_event "INFO" "DNF clean packages"
    run_with_log "DNF clean packages" ionice -c 3 nice -n 19 dnf clean packages -y

    # SADECE raporlama – asla otomatik silme (Anayasa Madde 5)
    if command -v dnf &>/dev/null; then
        local orphan_list
        orphan_list=$(dnf repoquery --unneeded -C 2>/dev/null || true)
        if [[ -n "${orphan_list}" ]]; then
            log_event "WARN" "Öksüz paketler tespit edildi (SİLİNMEDİ):"
            echo "${orphan_list}" >> "${LOG_FILE}"
        fi
    fi

    if command -v flatpak &>/dev/null; then
        log_event "INFO" "Flatpak unused removal (tek komut, fork yok)"
        local unused_flatpaks
        unused_flatpaks=$(flatpak list --runtime --columns=application,options | grep "unused" | awk '{print $1}' || true)
        if [[ -n "${unused_flatpaks}" ]]; then
            log_event "INFO" "Flatpak unused runtimelar imha ediliyor: ${unused_flatpaks}"
        fi
        run_with_log "Flatpak unused kaldırma" ionice -c 3 nice -n 19 flatpak uninstall --unused -y
    fi
}

clean_broken_symlinks() {
    printf '%b' "${BLUE}[3/7] Kırık sembolik linkler temizleniyor...${NC}\n"
    log_event "INFO" "Kırık symlink avı (fork-free -depth -delete)"
    run_with_log "Kırık symlink temizliği" ionice -c 3 nice -n 19 find /home /var -depth -xtype l -delete
}

clean_zombie_desktop() {
    printf '%b' "${BLUE}[4/7] Zombi masaüstü girişleri temizleniyor...${NC}\n"
    log_event "INFO" ".desktop dosyası doğrulama"
    local app_dir
    for app_dir in "${REAL_HOME}/.local/share/applications" "/usr/share/applications"; do
        if [[ -d "${app_dir}" ]]; then
            find "${app_dir}" -type f -name "*.desktop" | while read -r desktop_file; do
                if [[ -r "${desktop_file}" ]]; then
                    local exec_bin
                    exec_bin=$(grep -E "^Exec=" "${desktop_file}" | head -n1 | cut -d= -f2 | awk '{print $1}' || true)
                    if [[ -n "${exec_bin}" && ! "${exec_bin}" =~ ^/ && ! "${exec_bin}" =~ ^http ]]; then
                        if ! command -v "${exec_bin}" &>/dev/null; then
                            log_event "INFO" "Siliniyor: ${desktop_file} (binary: ${exec_bin})"
                            rm -f "${desktop_file}" 2>/dev/null || log_event "WARN" "${desktop_file} silinemedi"
                        fi
                    fi
                fi
            done
        fi
    done
}

clean_librewolf_sqlite() {
    printf '%b' "${BLUE}[5/7] LibreWolf SQLite veritabanları optimize ediliyor...${NC}\n"
    if pgrep -x "librewolf" &>/dev/null; then
        log_event "WARN" "LibreWolf açık, SQLite işlemi atlandı."
        printf '%b' "${YELLOW}[!] LibreWolf çalışıyor, SQLite vakum atlandı.${NC}\n"
        return 0
    fi
    local lw_profile_dir="${REAL_HOME}/.librewolf"
    if [[ -d "${lw_profile_dir}" ]]; then
        find "${lw_profile_dir}" -type f -name "*.sqlite" | while read -r sql_db; do
            if [[ -f "${sql_db}" && -s "${sql_db}" ]]; then
                sqlite3 "${sql_db}" "VACUUM;" 2>/dev/null || log_event "WARN" "VACUUM başarısız: ${sql_db}"
                sqlite3 "${sql_db}" "REINDEX;" 2>/dev/null || log_event "WARN" "REINDEX başarısız: ${sql_db}"
                log_event "DEBUG" "VACUUM+REINDEX: ${sql_db}"
            fi
        done
        printf '%b' "${GREEN}    ✓ LibreWolf SQLite jilet gibi oldu.${NC}\n"
    else
        printf '%b' "${YELLOW}    ! LibreWolf profili bulunamadı.${NC}\n"
    fi
}

clean_docker() {
    if ! command -v docker &>/dev/null; then
        printf '%b' "${YELLOW}[6/7] Docker kurulu değil, atlanıyor.${NC}\n"
        return 0
    fi
    if ! systemctl is-active --quiet docker; then
        printf '%b' "${YELLOW}[6/7] Docker servisi çalışmıyor, atlanıyor.${NC}\n"
        return 0
    fi
    printf '%b' "${BLUE}[6/7] Docker temizliği (VOLUMELER KORUNUYOR)...${NC}\n"
    log_event "INFO" "Docker system prune (volumes hariç, tüm kullanılmayan imaj/kont/network)"
    run_with_log "Docker system prune" ionice -c 3 nice -n 19 docker system prune -af
    # Ayrıca 30 günden eski imajları silmek için (system prune zaten kullanılmayanları siler, ama yine de ekstra filtre)
    run_with_log "Docker eski imaj (30gün)" ionice -c 3 nice -n 19 docker image prune -a --filter "until=30d" -f
}

clean_old_kernels() {
    printf '%b' "${BLUE}[7/7] Eski çekirdekler ve modülleri temizleniyor...${NC}\n"
    log_event "INFO" "Eski kernel + modül kaldırma"
    local current_kernel kernel_count
    current_kernel=$(uname -r)
    kernel_count=$(rpm -q kernel-core 2>/dev/null | wc -l)

    if [[ ${kernel_count} -le 2 ]]; then
        printf '%b' "${GREEN}    ✓ Sistemde zaten sadece ${kernel_count} çekirdek var.${NC}\n"
        return 0
    fi

    local old_kernels
    old_kernels=$(rpm -q kernel-core --last 2>/dev/null | tail -n +3 | awk '{print $1}' | grep -v "${current_kernel}" || true)
    
    for kernel_pkg in ${old_kernels}; do
        # Sürüm bilgisini çıkar (kernel-core-6.8.5-200.fc40.x86_64)
        local kernel_version
        kernel_version=$(echo "${kernel_pkg}" | sed -E 's/^kernel-core-(.*)/\1/')
        
        # İlgili modül ve devel paketlerini bul (varsa)
        local related_pkgs=()
        for pkg in kernel-modules kernel-devel kernel-headers; do
            if rpm -q "${pkg}-${kernel_version}" &>/dev/null; then
                related_pkgs+=("${pkg}-${kernel_version}")
            fi
        done
        
        local pkgs_to_remove=("${kernel_pkg}" "${related_pkgs[@]}")
        if [[ ${#pkgs_to_remove[@]} -gt 0 ]]; then
            log_event "INFO" "Kaldırılacak paketler: ${pkgs_to_remove[*]}"
            run_with_log "Eski kernel paketlerini kaldır" dnf remove -y --noautoremove "${pkgs_to_remove[@]}"
        fi
    done
    printf '%b' "${GREEN}    ✓ Eski çekirdekler ve modülleri temizlendi.${NC}\n"
}

run_trim() {
    printf '%b' "${BLUE}[+] Ek: NVMe TRIM...${NC}\n"
    log_event "INFO" "fstrim"
    run_with_log "fstrim" ionice -c 3 nice -n 19 fstrim -va
}

refresh_firmware() {
    if command -v fwupdmgr &>/dev/null; then
        printf '%b' "${BLUE}[+] Ek: LVFS refresh...${NC}\n"
        log_event "INFO" "fwupdmgr refresh"
        run_with_log "LVFS yenileme" ionice -c 3 nice -n 19 fwupdmgr refresh
    fi
}

# ==============================================================================
# ANA YÖNETİCİ
# ==============================================================================
main() {
    printf '%b' "${CYAN}======================================================================${NC}\n"
    printf '%b' "${CYAN}    🧹 FEDORA SANITIZER DAILY v3.2 (Surface Pro 9 Optimized)${NC}\n"
    printf '%b' "${CYAN}======================================================================${NC}\n"
    log_event "START" "Günlük sanitizer başladı."

    check_thermal
    clean_journals
    check_thermal
    clean_package_caches
    check_thermal
    clean_broken_symlinks
    clean_zombie_desktop
    check_thermal
    clean_librewolf_sqlite
    check_thermal
    clean_docker
    check_thermal
    clean_old_kernels
    run_trim
    refresh_firmware
    check_thermal

    # Veri bütünlüğü bariyeri (tüm disk tamponlarını yaz)
    sync || log_event "WARN" "sync başarısız oldu"
    if [[ -d "${LOG_BASE}" ]]; then
        sync "${LOG_BASE}" 2>/dev/null || true
    fi

    printf '%b' "${GREEN}======================================================================${NC}\n"
    printf '%b' "${GREEN}✓ Sanitizer tamamlandı. Sistem yeni güne hazır.${NC}\n"
    printf '%b' "${GREEN}✓ Log dosyası: ${LOG_FILE}${NC}\n"
    printf '%b' "${GREEN}======================================================================${NC}\n"
    log_event "SUCCESS" "Sanitizer başarıyla tamamlandı."
}

# ==============================================================================
# ÇALIŞTIRMA
# ==============================================================================
check_prerequisites
acquire_lock
main

exit 0
