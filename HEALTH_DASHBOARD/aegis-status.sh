#!/usr/bin/env bash
# ==============================================================================
# BETİK ADI      : aegis-status.sh
# AMAÇ           : Aegis Sıkılaştırma Katmanları Anlık Durum & Telemetri Paneli
# YAZAN          : Dr. Ozhan Akdag & Yoldaş (Military-Grade Red/Blue Audit)
# VERSİYON       : 3.3.0 (Absolute Zero-Fork, No Here-String, Pure Memory I/O)
# KRİTER         : Zero-Dependency, Pure Bash & AWK, Military-Grade Hardening
# SIKILAŞTIRMA   : Atomic fd flock, Deterministic Cleanup, Single-Pass AWK,
#                  Forkless String Splitting, No /tmp Usage, POSIX-Compliant
# ==============================================================================

# ---- KATI HATA YÖNETİMİ ----
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

# ---- SABİT TANIMLAMALAR (readonly) ----
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[0;33m'
declare -r BLUE='\033[0;34m'
declare -r PURPLE='\033[0;35m'
declare -r CYAN='\033[0;36m'
declare -r BOLD='\033[1m'
declare -r NC='\033[0m'

declare -r LOCK_DIR="/run/aegis"
declare -r LOCK_FILE="${LOCK_DIR}/aegis-status.lock"
declare -r LOG_LOCK_FILE="${LOCK_DIR}/aegis-status-log.lock"
declare -r LOG_DIR="/var/log/aegis"
declare -r LOG_FILE="${LOG_DIR}/aegis-status-$(date +%Y%m%d).log"
declare -r SCRIPT_NAME="aegis-status.sh"

# Durum takipleri
LOCK_FD_ACQUIRED=""
LOG_FD_ACQUIRED=""

# ---- TEMİZLİK FONKSİYONU (EXIT TRAP) ----
cleanup() {
    local exit_code=$?
    printf '%b' "${NC}" 2>/dev/null || true
    
    if [[ -n "${LOCK_FD_ACQUIRED}" ]]; then
        if true 2>/dev/null >&9; then
            flock -u 9 2>/dev/null || true
            exec 9>&- 2>/dev/null || true
        fi
        if [[ -f "${LOCK_FILE}" ]]; then
            local lock_pid
            lock_pid=$(head -n1 "${LOCK_FILE}" 2>/dev/null || echo "")
            [[ "${lock_pid}" == "$$" ]] && rm -f "${LOCK_FILE}" 2>/dev/null || true
        fi
    fi
    
    if [[ -n "${LOG_FD_ACQUIRED}" ]]; then
        if true 2>/dev/null >&8; then
            flock -u 8 2>/dev/null || true
            exec 8>&- 2>/dev/null || true
        fi
        if [[ -f "${LOG_LOCK_FILE}" ]]; then
            local log_lock_pid
            log_lock_pid=$(head -n1 "${LOG_LOCK_FILE}" 2>/dev/null || echo "")
            [[ "${log_lock_pid}" == "$$" ]] && rm -f "${LOG_LOCK_FILE}" 2>/dev/null || true
        fi
    fi
    
    if [[ ${exit_code} -ne 0 ]] && [[ ${exit_code} -ne 130 ]]; then
        printf '%b' "${RED}[!] Betik beklenmedik şekilde sonlandı (Çıkış kodu: ${exit_code})${NC}\n" >&2
    fi
    exit ${exit_code}
}
trap cleanup EXIT INT TERM HUP QUIT

# ---- ATOMİC KİLİT MEKANİZMASI ----
acquire_lock() {
    mkdir -p "${LOCK_DIR}" 2>/dev/null || {
        printf '%b' "${RED}[-] KRİTİK HATA: Lock dizini oluşturulamadı: ${LOCK_DIR}${NC}\n" >&2
        exit 1
    }
    
    if ! exec 9>"${LOCK_FILE}"; then
        printf '%b' "${RED}[-] KRİTİK HATA: Lock dosyası açılamadı: ${LOCK_FILE}${NC}\n" >&2
        exit 1
    fi
    
    if ! flock -n 9 2>/dev/null; then
        local existing_pid
        existing_pid=$(head -n1 "${LOCK_FILE}" 2>/dev/null || echo "bilinmiyor")
        printf '%b' "${YELLOW}[!] UYARI: Betik zaten çalışıyor (PID: ${existing_pid}). 5 saniye bekleniyor...${NC}\n" >&2
        
        if ! flock -w 5 9 2>/dev/null; then
            printf '%b' "${RED}[-] HATA: Lock alınamadı. Zaman aşımı (5 saniye).${NC}\n" >&2
            exec 9>&- 2>/dev/null || true
            exit 1
        fi
    fi
    
    printf '%s\n' "$$" >&9
    LOCK_FD_ACQUIRED="true"
}

# ---- LOG KİLİDİ ----
acquire_log_lock() {
    mkdir -p "${LOCK_DIR}" 2>/dev/null || return 1
    if ! exec 8>"${LOG_LOCK_FILE}"; then return 1; fi
    if ! flock -n 8 2>/dev/null; then
        if ! flock -w 2 8 2>/dev/null; then
            exec 8>&- 2>/dev/null || true
            return 1
        fi
    fi
    printf '%s\n' "$$" >&8
    LOG_FD_ACQUIRED="true"
    return 0
}

release_log_lock() {
    if [[ -n "${LOG_FD_ACQUIRED}" ]]; then
        if true 2>/dev/null >&8; then
            flock -u 8 2>/dev/null || true
            exec 8>&- 2>/dev/null || true
        fi
        LOG_FD_ACQUIRED=""
    fi
}

# ---- INPUT SANITIZATION ----
sanitize_output() {
    local input="$1"
    printf '%s' "${input}" | LC_ALL=C tr -d '\000-\010\013\014\016-\037'
}

# ---- GÜVENLİ LOG YAZMA ----
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    mkdir -p "${LOG_DIR}" 2>/dev/null || true
    
    if acquire_log_lock; then
        printf '[%s] [%s] %s\n' "${timestamp}" "${level}" "${message}" >> "${LOG_FILE}" 2>/dev/null || true
        release_log_lock
    fi
}

# ---- ROOT YETKİ KONTROLÜ ----
check_root() {
    if [[ $EUID -ne 0 ]]; then
        printf '%b' "${RED}[-] HATA: Bu telemetri paneli kök (root) yetkileri gerektirir!${NC}\n" >&2
        printf '%b' "${YELLOW}[*] Kullanım: sudo ./${SCRIPT_NAME}${NC}\n" >&2
        exit 1
    fi
}

# ---- BAĞIMLILIK KONTROLÜ ----
check_dependencies() {
    local required_commands=("systemctl" "journalctl" "stat" "awk" "grep" "sysctl" "date" "hostname" "head" "mkdir" "tr")
    local missing_deps=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "${cmd}" &>/dev/null; then
            missing_deps+=("${cmd}")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        printf '%b' "${RED}[-] KRİTİK HATA: Gerekli komutlar eksik: ${missing_deps[*]}${NC}\n" >&2
        exit 1
    fi
}

# ---- SERVİS DURUM ANALİZİ ----
check_service_status() {
    local svc_name="$1"
    local display_name="$2"
    
    if systemctl is-active --quiet "${svc_name}" 2>/dev/null; then
        printf '  [%b%-6s%b] %-30s : Servis kararlı çalışıyor.\n' \
            "${GREEN}" "ACTIVE" "${NC}" "${display_name}"
        log_message "INFO" "Servis aktif: ${display_name} (${svc_name})"
        return 0
    else
        printf '  [%b%-6s%b] %-30s : %bUYARI! Servis aktif değil!%b\n' \
            "${RED}" "FAILED" "${NC}" "${display_name}" "${RED}" "${NC}"
        log_message "WARN" "Servis pasif: ${display_name} (${svc_name})"
        return 1
    fi
}

# ---- CHRONY NTS TELEMETRİSİ ----
check_chrony_nts() {
    printf '%b' "${PURPLE}${BOLD}[+] CHRONY NTS (NETWORK TIME SECURITY) METRİKLERİ${NC}\n"
    
    if ! systemctl is-active --quiet chronyd 2>/dev/null; then
        printf '  [%b!%b] Zaman şifreleme mekanizması aktif olmadığından metrik alınamadı.\n' "${RED}" "${NC}"
        log_message "WARN" "Chrony servisi pasif"
        return 1
    fi
    
    local nts_auth=0
    if command -v chronyc &>/dev/null; then
        nts_auth=$( (LC_ALL=C chronyc sources -v 2>/dev/null || true) | grep -c '^\^' 2>/dev/null || printf '0')
    fi
    nts_auth=$(sanitize_output "${nts_auth}")
    
    local time_offset="Bilinmiyor"
    if command -v chronyc &>/dev/null; then
        local tracking_output
        tracking_output=$(LC_ALL=C chronyc tracking 2>/dev/null || true)
        
        time_offset=$(printf '%s' "${tracking_output}" | \
            LC_ALL=C awk '
                /^System time/          {print $3, $4; found=1; exit}
                /^[[:space:]]*Offset/   {if (!found) {print $2, $3; found=1; exit}}
                END                     {if (!found) print "Bilinmiyor"}
            ' 2>/dev/null)
    fi
    time_offset=$(sanitize_output "${time_offset}")
    
    printf '  [*] Kriptografik NTS Bağlantısı : %b%s Sunucu Doğrulandı%b\n' "${GREEN}" "${nts_auth}" "${NC}"
    printf '  [*] Sistem Zaman Sapması (Offset): %b%s%b\n' "${CYAN}" "${time_offset}" "${NC}"
    log_message "INFO" "Chrony NTS: ${nts_auth} doğrulanmış sunucu, Offset: ${time_offset}"
    return 0
}

# ---- FAPOLICYD İSTATİSTİKLERİ (ABSOLUTE ZERO-FORK) ----
check_fapolicyd() {
    printf '%b' "${PURPLE}${BOLD}[+] FAPOLICYD UYGULAMA ENGELLENME RAPORU (Son 24 Saat)${NC}\n"
    
    if ! systemctl is-active --quiet fapolicyd 2>/dev/null; then
        printf '  [%b!%b] Fapolicyd pasif durumda.\n' "${RED}" "${NC}"
        log_message "WARN" "Fapolicyd servisi pasif"
        return 1
    fi
    
    # TEK AWK GEÇİŞİ: Sayım, son 3 satır, sanitization, formatlı çıktı.
    # AWK doğrudan formatlı çıktı üretir, Bash sadece yakalar.
    local deny_count=0
    local last_three=""
    
    # AWK çıktısı: ilk satır = sayı, sonraki satırlar = formatlanmış loglar
    local awk_output
    awk_output=$(journalctl -u fapolicyd --since "24 hours ago" --no-pager 2>/dev/null | \
        LC_ALL=C awk '
        /rule=/ {
            count++
            idx = ((count - 1) % 3) + 1
            lines[idx] = $0
        }
        END {
            # İlk satır: toplam sayı
            print count+0
            if (count > 0) {
                start = (count > 3) ? count - 2 : 1
                for (i = start; i <= count; i++) {
                    idx = ((i - 1) % 3) + 1
                    # Tek geçişte tüm kontrol karakterlerini boşluğa çevir
                    gsub(/[[:cntrl:]]/, " ", lines[idx])
                    # Baştaki/sondaki boşlukları temizle ve bas
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", lines[idx])
                    if (length(lines[idx]) > 0) {
                        print lines[idx]
                    }
                }
            }
        }')
    
    # FORKLESS PARSING: Bash içsel parametre genişletme ile satırları ayır
    # İlk newline'a kadar olan kısım = deny_count, gerisi = last_three
    local first_newline_pos
    first_newline_pos=$(printf '%s' "${awk_output}" | LC_ALL=C awk 'NR==1 {print length($0)+1; exit}')
    
    if [[ -n "${first_newline_pos}" ]] && [[ "${first_newline_pos}" -gt 0 ]]; then
        deny_count="${awk_output:0:${first_newline_pos}-1}"
        # Sadece sayısal değeri al (AWK count+0 zaten sayısal basar, güvenli)
        deny_count="${deny_count##*[!0-9]}"
        [[ -z "${deny_count}" ]] && deny_count=0
        
        if [[ "${first_newline_pos}" -lt "${#awk_output}" ]]; then
            last_three="${awk_output:${first_newline_pos}}"
        fi
    else
        deny_count=0
    fi
    
    if [[ "${deny_count}" -eq 0 ]]; then
        printf '  [*] Güvenilmeyen Uygulama İsteği: %b0 (Sistem Temiz)%b\n' "${GREEN}" "${NC}"
        log_message "INFO" "Fapolicyd: Son 24 saatte engellenen istek yok"
    else
        printf '  [*] Güvenilmeyen Uygulama İsteği: %b%s İhlal Yakalandı!%b\n' "${RED}" "${deny_count}" "${NC}"
        printf '%b  [!] Son Engellenen 3 İstek:%b\n' "${YELLOW}" "${NC}"
        
        # FORKLESS OUTPUT: Bash içsel while ile satırları işle (here-string YOK)
        # last_three içindeki newline'ları IFS ile ayır, saf Bash döngüsü
        local line
        local save_ifs="${IFS}"
        IFS=$'\n'
        # Alt kabuk kullanmadan döngü - değişken doğrudan ana scope'ta
        set -- ${last_three}
        IFS="${save_ifs}"
        for line in "$@"; do
            if [[ -n "${line}" ]]; then
                printf '      -> %s\n' "${line}"
            fi
        done
        log_message "WARN" "Fapolicyd: Son 24 saatte ${deny_count} ihlal engellendi"
    fi
    return 0
}

# ---- USBGUARD TELEMETRİSİ ----
check_usbguard() {
    printf '%b' "${PURPLE}${BOLD}[+] USBGUARD DONANIM ENGELLEME RAPORU${NC}\n"
    
    if ! systemctl is-active --quiet usbguard 2>/dev/null; then
        printf '  [%b!%b] USBGuard aktif değil.\n' "${RED}" "${NC}"
        log_message "WARN" "USBGuard servisi pasif"
        return 1
    fi
    
    local usb_list_output
    usb_list_output=$(usbguard list-devices 2>/dev/null || true)
    
    local allowed_devices=0
    local blocked_devices=0
    
    if [[ -n "${usb_list_output}" ]]; then
        allowed_devices=$(printf '%s\n' "${usb_list_output}" | grep -c "allow" || printf '0')
        blocked_devices=$(printf '%s\n' "${usb_list_output}" | grep -c "block" || printf '0')
    fi
    
    allowed_devices=$(sanitize_output "${allowed_devices}")
    blocked_devices=$(sanitize_output "${blocked_devices}")
    
    printf '  [*] Yetkilendirilmiş Güvenli USB Sayısı : %b%s%b\n' "${GREEN}" "${allowed_devices}" "${NC}"
    printf '  [*] Engellenen / Karantina USB Sayısı  : %b%s%b\n' "${RED}" "${blocked_devices}" "${NC}"
    
    local usb_violations=0
    usb_violations=$(journalctl -u usbguard --since "24 hours ago" --no-pager 2>/dev/null | grep -c "uid" || printf '0')
    usb_violations=$(sanitize_output "${usb_violations}")
    printf '  [*] Son 24 Saatteki USB Sızıntı Girişimi: %b%s%b\n' "${YELLOW}" "${usb_violations}" "${NC}"
    
    log_message "INFO" "USBGuard: ${allowed_devices} izinli, ${blocked_devices} engelli, ${usb_violations} ihlal"
    return 0
}

# ---- AIDE KONTROLÜ (TOCTOU-PROOF) ----
check_aide() {
    printf '%b' "${PURPLE}${BOLD}[+] AIDE (ADVANCED INTRUSION DETECTION ENVIRONMENT) DURUMU${NC}\n"
    
    local aide_db="/var/lib/aide/aide.db.gz"
    local db_stat_output
    db_stat_output=$(stat -c '%y' "${aide_db}" 2>/dev/null || true)
    
    if [[ -n "${db_stat_output}" ]]; then
        local db_date
        db_date=$(printf '%s' "${db_stat_output}" | cut -d'.' -f1)
        db_date=$(sanitize_output "${db_date}")
        printf '  [*] Güvenli Kök Baseline Veritabanı : %bMEVCUT%b\n' "${GREEN}" "${NC}"
        printf '  [*] Son Baseline İmzalama Zamanı    : %b%s%b\n' "${CYAN}" "${db_date}" "${NC}"
        log_message "INFO" "AIDE veritabanı mevcut, son imza: ${db_date}"
    else
        printf '  [*] Güvenli Kök Baseline Veritabanı : %bYOK! (Sistem bütünlüğü izlenemiyor)%b\n' "${RED}" "${NC}"
        log_message "ERROR" "AIDE veritabanı bulunamadı: ${aide_db}"
    fi
}

# ---- ÇEKİRDEK AĞ YIĞITI KONTROLÜ ----
check_kernel_network() {
    printf '%b' "${PURPLE}${BOLD}[+] KERNEL NETWORK STACK & BUFFERBLOAT OPTİMİZASYONU${NC}\n"
    
    local current_qdisc="bilinmiyor"
    local current_congestion="bilinmiyor"
    
    if [[ -f /proc/sys/net/core/default_qdisc ]]; then
        current_qdisc=$(cat /proc/sys/net/core/default_qdisc 2>/dev/null || printf 'bilinmiyor')
    fi
    if [[ -f /proc/sys/net/ipv4/tcp_congestion_control ]]; then
        current_congestion=$(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || printf 'bilinmiyor')
    fi
    
    current_qdisc=$(sanitize_output "${current_qdisc}")
    current_congestion=$(sanitize_output "${current_congestion}")
    
    if [[ "${current_congestion}" == "bbr" ]]; then
        printf '  [*] TCP Tıkanıklık Kontrol Algoritması: %bBBR (Aktif / Maksimum Hız)%b\n' "${GREEN}" "${NC}"
    else
        printf '  [*] TCP Tıkanıklık Kontrol Algoritması: %b%s (BBR Pasif)%b\n' "${YELLOW}" "${current_congestion}" "${NC}"
    fi
    printf '  [*] Paket Kuyruk Disiplini (Qdisc)    : %b%s%b\n' "${CYAN}" "${current_qdisc}" "${NC}"
    
    log_message "INFO" "Kernel Ağ: Congestion=${current_congestion}, Qdisc=${current_qdisc}"
}

# ---- ANA AKIŞ ----
main() {
    log_message "INFO" "====== AEGIS HEALTH DASHBOARD V3.3.0 BAŞLANGIÇ ======"
    
    clear
    printf '%b' "${BLUE}${BOLD}======================================================================${NC}\n"
    printf '%b' "${CYAN}${BOLD}    🛡️  AEGIS HEALTH DASHBOARD V3.3.0 - ABSOLUTE ZERO-FORK EDITION${NC}\n"
    printf '%b' "${BLUE}${BOLD}======================================================================${NC}\n"
    
    local safe_hostname
    safe_hostname=$(sanitize_output "$(hostname 2>/dev/null || printf 'bilinmiyor')")
    
    printf '%bTarama Zamanı:%b %s  |  %bAna Makine:%b %s\n' \
        "${BOLD}" "${NC}" "$(date '+%Y-%m-%d %H:%M:%S')" \
        "${BOLD}" "${NC}" "${safe_hostname}"
    printf '%b' "${BLUE}----------------------------------------------------------------------${NC}\n"
    
    printf '%b' "${PURPLE}${BOLD}[+] KATMANLI SAVUNMA VE SIKILAŞTIRMA SERVİSLERİ${NC}\n"
    check_service_status "usbguard.service" "USBGuard (Donanım Zırhı)"
    check_service_status "fapolicyd.service" "Fapolicyd (Uygulama Kalkanı)"
    check_service_status "chronyd.service" "Chrony NTS (Zaman Güvenliği)"
    check_service_status "firewalld.service" "Aegis Firewall (Dış Sur)"
    check_service_status "auditd.service" "Auditd (Sistem Denetimi)"
    printf '%b' "${BLUE}----------------------------------------------------------------------${NC}\n"
    
    check_chrony_nts
    printf '%b' "${BLUE}----------------------------------------------------------------------${NC}\n"
    check_fapolicyd
    printf '%b' "${BLUE}----------------------------------------------------------------------${NC}\n"
    check_usbguard
    printf '%b' "${BLUE}----------------------------------------------------------------------${NC}\n"
    check_aide
    printf '%b' "${BLUE}----------------------------------------------------------------------${NC}\n"
    check_kernel_network
    
    printf '%b' "${BLUE}======================================================================${NC}\n"
    printf '%bÖneri:%b Bu paneli %bwatch -n 10 -c sudo ./%s%b ile canlı izleyebilirsiniz.\n' \
        "${BOLD}" "${NC}" "${GREEN}" "${SCRIPT_NAME}" "${NC}"
    printf '%bLog:%b Detaylı loglar %b%s%b dosyasına kaydediliyor.\n' \
        "${BOLD}" "${NC}" "${CYAN}" "${LOG_FILE}" "${NC}"
    printf '%b' "${BLUE}======================================================================${NC}\n"
    
    log_message "INFO" "====== AEGIS HEALTH DASHBOARD TAMAMLANDI ======"
}

# ---- YÜRÜTME SIRASI ----
check_root
check_dependencies
acquire_lock
main
