#!/usr/bin/env bash
# ==============================================================================
# BETİK ADI      : aegis-kernel-hardening.sh
# AMAÇ           : Linux Çekirdek Sıkılaştırma & Çalışma Zamanı Bellek Koruması
# YAZAN          : Dr. Ozhan Akdag & Yoldaş (Military-Grade Red/Blue Audit)
# SÜRÜM          : 12.0-FINAL (Production-Ready, Diminishing Returns Eşiği)
# KRİTER         : Zero-Dependency, Pure Bash & Sysctl Hardening
# SIKILAŞTIRMA   : PID-Verified Lock, Separate Latch Ordering, BTRFS Journal Trust
# ==============================================================================

set -Euo pipefail
IFS=$'\n\t'
umask 077

# ---- SABİT TANIMLAMALAR (readonly) ----
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[0;33m'
declare -r BLUE='\033[0;34m'
declare -r CYAN='\033[0;36m'
declare -r BOLD='\033[1m'
declare -r NC='\033[0m'

declare -r LOCK_DIR="/run/aegis"
declare -r LOCK_FILE="${LOCK_DIR}/kernel-hardening.lock"
declare -r SYSCTL_CONF="/etc/sysctl.d/99-aegis-kernel-hardening.conf"
declare -r LOG_BASE="/var/log/aegis"
declare -r LOG_FILE="${LOG_BASE}/kernel_hardening.log"

# Durum bayrakları (State Flags)
LOCK_FD=""
LOCK_ACQUIRED=""
DISK_WRITTEN=""
FAILED_PARAMS_LOG=""
AGGRESSIVE_MODE=0

# Parametre Matrisleri
declare -gA TARGET_PARAMS=()
declare -gA LATCH_PARAMS=()
declare -gA AGGRESSIVE_PARAMS=()

# ---- TEMİZLİK VE GÜVENLİ ÇÖKÜŞ (EXIT TRAP) ----
cleanup() {
    local exit_code=$?
    trap '' EXIT INT TERM ERR HUP
    set +o pipefail 2>/dev/null || true
    
    log_event "INFO" "Cleanup başlatıldı, çıkış kodu: ${exit_code}"
    
    if [[ ${exit_code} -ne 0 && ${exit_code} -ne 130 ]]; then
        printf '%b' "${RED}[!] FATAL: Protokol yarıda kesildi! (Kod: ${exit_code})${NC}\n" >&2
        [[ "${DISK_WRITTEN}" != "true" ]] && find "${LOCK_DIR}" -maxdepth 1 -name 'sysctl-hardening.*.tmp' -delete 2>/dev/null || true
    fi

    [[ -n "${LOCK_FD}" ]] && exec {LOCK_FD}>&- 2>/dev/null || true
    
    if [[ -n "${LOCK_ACQUIRED}" && -f "${LOCK_FILE}" ]]; then
        local lock_pid
        lock_pid=$(head -n1 "${LOCK_FILE}" 2>/dev/null || echo "0")
        [[ "${lock_pid}" == "$$" ]] && rm -f "${LOCK_FILE}" 2>/dev/null || true
    fi
    
    [[ -n "${FAILED_PARAMS_LOG}" && -f "${FAILED_PARAMS_LOG}" ]] && rm -f "${FAILED_PARAMS_LOG}" 2>/dev/null || true
    
    log_event "INFO" "Cleanup tamamlandı."
    exit ${exit_code}
}
trap cleanup EXIT INT TERM ERR HUP

# ---- ADLİ LOGLAMA ----
log_event() {
    local level="$1" message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    mkdir -p "${LOG_BASE}" 2>/dev/null || true
    chmod 0700 "${LOG_BASE}" 2>/dev/null || true
    
    [[ -d "${LOG_BASE}" ]] && printf '[%s] [%s] [PID:%s] %s\n' "${timestamp}" "${level}" "$$" "${message}" >> "${LOG_FILE}" 2>/dev/null || true
    
    if command -v systemd-cat &>/dev/null; then
        (set +o pipefail 2>/dev/null || true; echo "[${level}] ${message}" | systemd-cat -t aegis-kernel -p info 2>/dev/null || true)
    fi
}

# ---- ATOMİC KİLİT MEKANİZMASI ----
acquire_lock() {
    mkdir -p -m 0700 "${LOCK_DIR}" 2>/dev/null || true
    [[ ! -d "${LOCK_DIR}" ]] && { printf '%b' "${RED}[-] KRİTİK: İzolasyon alanı oluşturulamadı.${NC}\n" >&2; exit 1; }
    
    local fd
    exec {fd}>"${LOCK_FILE}" || { printf '%b' "${RED}[-] KRİTİK: Kilit kanalı açılamadı.${NC}\n" >&2; exit 1; }
    LOCK_FD="${fd}"
    
    if ! flock -n "${LOCK_FD}" 2>/dev/null; then
        local existing_pid=$(head -n1 "${LOCK_FILE}" 2>/dev/null || echo "bilinmiyor")
        printf '%b' "${YELLOW}[!] Aegis zaten çalışıyor (PID: ${existing_pid}). Bekleniyor...${NC}\n" >&2
        flock -w 5 "${LOCK_FD}" 2>/dev/null || { printf '%b' "${RED}[-] HATA: Zaman aşımı. Kilit alınamadı.${NC}\n" >&2; exec {LOCK_FD}>&- 2>/dev/null || true; LOCK_FD=""; exit 1; }
    fi
    
    printf '%s\n' "$$" >&"${LOCK_FD}"
    LOCK_ACQUIRED="true"
    log_event "INFO" "Kilit başarıyla rezerve edildi (FD: ${LOCK_FD})"
}

# ---- ROOT KONTROLÜ ----
check_root() {
    [[ ${EUID} -ne 0 ]] && { printf '%b' "${RED}[-] HATA: Bu askeri katman root yetkisi gerektirir!${NC}\n" >&2; exit 1; }
    log_event "INFO" "Root yetkisi doğrulandı"
}

# ---- ÖNKOŞUL KONTROLLERİ ----
check_prerequisites() {
    [[ ! -d "/etc/sysctl.d" ]] && { printf '%b' "${RED}[-] HATA: /etc/sysctl.d bulunamadı.${NC}\n" >&2; exit 1; }
    [[ ! -f "/proc/sys/kernel/yama/ptrace_scope" ]] && { printf '%b' "${RED}[-] KRİTİK HATA: Yama LSM modülü aktif değil!${NC}\n" >&2; exit 1; }
    log_event "INFO" "Önkoşul doğrulamaları başarılı"
}

# ---- PARAMETRE MATRİS YÖNETİMİ ----
build_standard_params() {
    TARGET_PARAMS=(
        ["kernel.kptr_restrict"]="2"
        ["kernel.dmesg_restrict"]="1"
        ["fs.protected_hardlinks"]="1"
        ["fs.protected_symlinks"]="1"
        ["kernel.yama.ptrace_scope"]="2"
        ["net.core.bpf_jit_harden"]="2"
        ["kernel.randomize_va_space"]="2"
        ["kernel.panic_on_oops"]="1"
    )
    LATCH_PARAMS=()
}

get_aggressive_params() {
    AGGRESSIVE_PARAMS=()
    [[ -f "/proc/sys/kernel/perf_event_paranoid" ]] && AGGRESSIVE_PARAMS["kernel.perf_event_paranoid"]="3"
    [[ -f "/proc/sys/kernel/unprivileged_userns_clone" ]] && AGGRESSIVE_PARAMS["kernel.unprivileged_userns_clone"]="0"
    [[ -f "/proc/sys/net/core/bpf_jit_kallsyms" ]] && AGGRESSIVE_PARAMS["net.core.bpf_jit_kallsyms"]="0"
    [[ -f "/proc/sys/dev/tty/ldisc_autoload" ]] && AGGRESSIVE_PARAMS["dev.tty.ldisc_autoload"]="0"
    [[ -f "/proc/sys/fs/suid_dumpable" ]] && AGGRESSIVE_PARAMS["fs.suid_dumpable"]="0"
    [[ -f "/proc/sys/kernel/sysrq" ]] && AGGRESSIVE_PARAMS["kernel.sysrq"]="0"
    
    # Geri alınamaz tek yönlü sürgüler (Latch)
    [[ -f "/proc/sys/kernel/modules_disabled" ]] && LATCH_PARAMS["kernel.modules_disabled"]="1"
    [[ -f "/proc/sys/kernel/kexec_load_disabled" ]] && LATCH_PARAMS["kernel.kexec_load_disabled"]="1"
}

# ---- İNSAN ONAY MEKANİZMASI ----
human_authorization() {
    printf '%b' "${BLUE}======================================================================${NC}\n"
    printf '%b' "${CYAN}${BOLD}    🛡️  AEGIS KERNEL HARDENING & MEMORY ISOLATION (V12-FINAL)${NC}\n"
    printf '%b' "${BLUE}======================================================================${NC}\n"
    
    printf '%b' "${YELLOW}[SORU 1/3]: AGRESİF MOD etkinleştirilsin mi?${NC}\n"
    printf '%b' "  ${RED}GERİ ALINAMAZ SÜRGÜLER İÇERİR:${NC} modules_disabled, kexec_load_disabled\n"
    printf '  [E/e] Evet, [H/h] Hayır: '
    local choice
    read -r choice || { printf '\n'; choice="h"; }
    
    if [[ "${choice}" =~ ^[Ee]$ ]]; then
        AGGRESSIVE_MODE=1
        get_aggressive_params
        for param in "${!AGGRESSIVE_PARAMS[@]}"; do TARGET_PARAMS["${param}"]="${AGGRESSIVE_PARAMS[$param]}"; done
        log_event "INFO" "Agresif mod şablonu matrise enjekte edildi"
    fi
    
    printf '\n%b' "${YELLOW}[SORU 2/3]: BPF lockdown (unprivileged_bpf_disabled=1) uygulansın mı?${NC}\n"
    printf '  [E/e] Evet, [H/h] Hayır: '
    read -r choice || { printf '\n'; choice="h"; }
    [[ "${choice}" =~ ^[Ee]$ && -f "/proc/sys/kernel/unprivileged_bpf_disabled" ]] && LATCH_PARAMS["kernel.unprivileged_bpf_disabled"]="1"
    
    printf '\n%b' "${YELLOW}[SORU 3/3]:${NC} Operasyonu nihai olarak onaylayın.\n"
    local token=$(dd if=/dev/urandom bs=4 count=1 2>/dev/null | od -A n -t x1 | tr -d ' \n')
    printf '  Token [%b%s%b]: ' "${GREEN}" "${token}" "${NC}"
    read -r choice || { printf '\n'; exit 0; }
    [[ "${choice}" != "${token}" ]] && { printf '%b' "${RED}[-] HATA: Token eşleşmedi. İptal edildi.${NC}\n" >&2; exit 0; }
    log_event "INFO" "İnsan onayı başarıyla geçildi"
}

# ---- IDEMPOTENCY KONTROLÜ (POST-AUTH) ----
check_idempotency() {
    local all_match=1
    for param in "${!TARGET_PARAMS[@]}"; do
        [[ "$(sysctl -n "${param}" 2>/dev/null || echo "HATA")" != "${TARGET_PARAMS[$param]}" ]] && { all_match=0; break; }
    done
    [[ ${all_match} -eq 1 ]] && for param in "${!LATCH_PARAMS[@]}"; do
        [[ "$(sysctl -n "${param}" 2>/dev/null || echo "HATA")" != "${LATCH_PARAMS[$param]}" ]] && { all_match=0; break; }
    done
    if [[ ${all_match} -eq 1 && -f "${SYSCTL_CONF}" ]]; then
        printf '%b' "${GREEN}[*] INFO: Çekirdek zırhı zaten istenen seviyede mühürlü. Çıkılıyor.${NC}\n"
        exit 0
    fi
}

# ---- OPERASYON SÜRECİ (MAIN) ----
main() {
    log_event "INFO" "Ana döngü tetiklendi"
    
    printf '%b' "${BLUE}[*] Faz 1: Pre-flight uyumluluk denetimi...${NC}\n"
    for param in "${!TARGET_PARAMS[@]}" "${!LATCH_PARAMS[@]}"; do
        local proc_path="/proc/sys/${param//./\/}"
        [[ ! -e "${proc_path}" ]] && { printf '%b' "${RED}[-] HATA: ${proc_path} mevcut değil!${NC}\n" >&2; exit 1; }
        [[ ! -w "${proc_path}" ]] && { printf '%b' "${RED}[-] HATA: ${proc_path} salt-okunur!${NC}\n" >&2; exit 1; }
    done
    printf '%b' "${GREEN}   Tüm parametreler çekirdek mimarisiyle uyumlu.${NC}\n"
    
    printf '%b' "${BLUE}[*] Faz 2: Konfigürasyon diske mühürleniyor...${NC}\n"
    local tmp_conf=$(mktemp -p "${LOCK_DIR}" sysctl-hardening.XXXXXX.tmp)
    FAILED_PARAMS_LOG=$(mktemp -p "${LOCK_DIR}" failed-params.XXXXXX.log)
    chmod 0600 "${FAILED_PARAMS_LOG}"
    
    cat > "${tmp_conf}" << EOF
# AEGIS KERNEL HARDENING V12-FINAL
# MODE: $([ ${AGGRESSIVE_MODE} -eq 1 ] && echo "AGGRESSIVE" || echo "STANDARD")
# GENERATED: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF
    for param in "${!TARGET_PARAMS[@]}"; do printf '%s = %s\n' "${param}" "${TARGET_PARAMS[$param]}" >> "${tmp_conf}"; done
    for param in "${!LATCH_PARAMS[@]}"; do printf '%s = %s\n' "${param}" "${LATCH_PARAMS[$param]}" >> "${tmp_conf}"; done
    chmod 0640 "${tmp_conf}"
    
    # POSIX Atomik Rename Taşıması
    mv "${tmp_conf}" "${SYSCTL_CONF}" || { rm -f "${tmp_conf}" 2>/dev/null; exit 1; }
    DISK_WRITTEN="true"
    log_event "INFO" "Konfigürasyon kalıcı alana işlendi: ${SYSCTL_CONF}"
    
    printf '%b' "${BLUE}[*] Faz 3: Parametreler canlı çekirdeğe yükleniyor...${NC}\n"
    local failed_params=()
    for param in "${!TARGET_PARAMS[@]}"; do
        LC_ALL=C sysctl -w "${param}=${TARGET_PARAMS[$param]}" >/dev/null 2>&1 || failed_params+=("${param}")
    done
    for param in "${!LATCH_PARAMS[@]}"; do
        LC_ALL=C sysctl -w "${param}=${LATCH_PARAMS[$param]}" >/dev/null 2>&1 || failed_params+=("${param}")
    done
    
    [[ ${#failed_params[@]} -gt 0 ]] && { printf '%b' "${RED}[-] KRİTİK HATA: Yüklenemeyen parametreler: ${failed_params[*]}${NC}\n" >&2; exit 1; }
    printf '%b' "${GREEN}   Canlı çekirdek sıkılaştırması başarıyla tamamlandı.${NC}\n"
    
    printf '%b' "${BLUE}[*] Faz 4: Nihai bütünlük doğrulaması...${NC}\n"
    local all_ok=1
    for param in "${!TARGET_PARAMS[@]}"; do
        [[ "$(sysctl -n "${param}" 2>/dev/null)" != "${TARGET_PARAMS[$param]}" ]] && { all_ok=0; printf '%b' "${RED}   [UYUŞMAZLIK] ${param}${NC}\n"; }
    done
    for param in "${!LATCH_PARAMS[@]}"; do
        [[ "$(sysctl -n "${param}" 2>/dev/null)" != "${LATCH_PARAMS[$param]}" ]] && { all_ok=0; printf '%b' "${RED}   [UYUŞMAZLIK LATCH] ${param}${NC}\n"; }
    done
    
    if [[ ${all_ok} -eq 1 ]]; then
        printf '%b' "${BLUE}----------------------------------------------------------------------${NC}\n"
        printf '%b' "${GREEN}✅ [BAŞARILI] Çekirdek bellek zırhı ve süreç hiyerarşisi mühürlendi.${NC}\n"
        printf '%b' "${BLUE}======================================================================${NC}\n"
        log_event "SUCCESS" "Protokol başarıyla nihayete erdirildi"
    else
        printf '%b' "${RED}[-] MİMARİ HATA: Durum doğrulaması başarısız!${NC}\n" >&2
        exit 1
    fi
}

# ---- ORKESTRASYON TETİKLEMESİ ----
check_root
acquire_lock
check_prerequisites
build_standard_params
human_authorization
check_idempotency
main
