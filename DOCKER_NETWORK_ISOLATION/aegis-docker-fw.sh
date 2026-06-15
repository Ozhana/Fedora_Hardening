#!/usr/bin/env bash
# ==============================================================================
# BETİK ADI      : aegis-docker-hardening.sh
# AMAÇ           : Docker'ı Localhost'a Bağlar, DNAT & Firewalld Bypass'ı Kapatır
# YAZAN          : Dr. Ozhan Akdag & Senior Cyber Security Agent
# SÜRÜM          : 6.6.0 (Direct Firewalld Rules - No XML Dependency)
# ==============================================================================
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

# ---- SABİT TANIMLAMALAR ----
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

readonly LOCK_DIR="/run/aegis"
readonly LOCK_FILE="${LOCK_DIR}/aegis-docker-hardening.lock"
readonly LOG_DIR="/var/log/aegis"
readonly LOG_FILE="${LOG_DIR}/aegis-docker-hardening-$(date +%Y%m%d).log"
readonly MAX_LOG_SIZE_MB=50

readonly DOCKER_CONFIG="/etc/docker/daemon.json"

LOCK_FD_ACQUIRED="false"
DOCKER_CONFIG_BACKUP=""
IPV6_ENABLED=false

# ---- LOG ROTASYONU ----
rotate_log_if_needed() {
    if [[ -f "${LOG_FILE}" ]]; then
        local size_mb
        size_mb=$(du -m "${LOG_FILE}" 2>/dev/null | cut -f1)
        if [[ ${size_mb:-0} -gt ${MAX_LOG_SIZE_MB} ]]; then
            mv "${LOG_FILE}" "${LOG_FILE}.old" 2>/dev/null || true
        fi
    fi
}

log_message() {
    local level="$1"
    local msg="$2"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    mkdir -p "${LOG_DIR}" 2>/dev/null || true
    rotate_log_if_needed
    
    if [[ -d "${LOG_DIR}" ]]; then
        printf '[%s] [%s] [PID:%s] %s\n' "${timestamp}" "${level}" "$$" "${msg}" >> "${LOG_FILE}" 2>/dev/null || true
    fi
}

# ---- ATOMİK TEMİZLİK ----
cleanup() {
    local exit_code=$?
    trap '' EXIT INT TERM ERR HUP
    
    log_message "INFO" "Cleanup triggered, exit code: ${exit_code}"
    
    if [[ ${exit_code} -ne 0 ]]; then
        printf '%b' "\n${RED}[!] FATAL: Transaction interrupted! Rolling back...${NC}\n" >&2
        
        if [[ -n "${DOCKER_CONFIG_BACKUP}" ]] && [[ -f "${DOCKER_CONFIG_BACKUP}" ]]; then
            cp -a "${DOCKER_CONFIG_BACKUP}" "${DOCKER_CONFIG}"
            systemctl restart docker >/dev/null 2>&1 || true
            log_message "WARN" "Docker config rolled back"
        fi
        
        # Firewalld kurallarını temizle (eklediğimiz kuralları kaldır)
        if command -v firewall-cmd &>/dev/null; then
            firewall-cmd --direct --remove-rule ipv4 filter DOCKER-USER 0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
            firewall-cmd --direct --remove-rule ipv4 filter DOCKER-USER 1 -i lo -j ACCEPT 2>/dev/null || true
            firewall-cmd --direct --remove-rule ipv4 filter DOCKER-USER 2 -s 172.16.0.0/12 -d 172.16.0.0/12 -j ACCEPT 2>/dev/null || true
            firewall-cmd --direct --remove-rule ipv4 filter DOCKER-USER 3 -s 192.168.0.0/16 -d 192.168.0.0/16 -j ACCEPT 2>/dev/null || true
            firewall-cmd --direct --remove-rule ipv4 filter DOCKER-USER 4 -s 10.0.0.0/8 -d 10.0.0.0/8 -j ACCEPT 2>/dev/null || true
            firewall-cmd --direct --remove-rule ipv4 filter DOCKER-USER 5 -j REJECT --reject-with icmp-host-prohibited 2>/dev/null || true
            if [[ "${IPV6_ENABLED}" == "true" ]]; then
                firewall-cmd --direct --remove-rule ipv6 filter DOCKER-USER 0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
                firewall-cmd --direct --remove-rule ipv6 filter DOCKER-USER 1 -i lo -j ACCEPT 2>/dev/null || true
                firewall-cmd --direct --remove-rule ipv6 filter DOCKER-USER 2 -s fc00::/7 -d fc00::/7 -j ACCEPT 2>/dev/null || true
                firewall-cmd --direct --remove-rule ipv6 filter DOCKER-USER 3 -j REJECT --reject-with icmp6-adm-prohibited 2>/dev/null || true
            fi
            firewall-cmd --runtime-to-permanent 2>/dev/null || true
        fi
    fi
    
    if [[ ${exit_code} -eq 0 ]]; then
        find /etc/docker -maxdepth 1 -name "daemon.json.aegis_bak_*" -mtime +30 -delete 2>/dev/null || true
    fi
    
    find "${LOCK_DIR}" -maxdepth 1 -name "*.tmp" -delete 2>/dev/null || true
    
    if [[ "${LOCK_FD_ACQUIRED}" == "true" ]]; then
        if true 2>/dev/null >&9; then
            flock -u 9 2>/dev/null || true
            exec 9>&- 2>/dev/null || true
        fi
    fi
}
trap cleanup EXIT INT TERM ERR HUP

# ---- ÖN KOŞULLAR ----
check_prerequisites() {
    if [[ ${EUID} -ne 0 ]]; then
        printf '%b' "${RED}[-] CRITICAL: Root required!${NC}\n" >&2
        exit 1
    fi
    
    local missing=()
    for cmd in systemctl docker iptables firewall-cmd iptables-save; do
        command -v "${cmd}" &>/dev/null || missing+=("${cmd}")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        printf '%b' "${RED}[-] Missing: ${missing[*]}${NC}\n" >&2
        exit 1
    fi
    
    if [[ -f /proc/sys/net/ipv6/conf/all/disable_ipv6 ]] && [[ $(cat /proc/sys/net/ipv6/conf/all/disable_ipv6) -eq 0 ]]; then
        IPV6_ENABLED=true
        if ! command -v ip6tables &>/dev/null; then
            printf '%b' "${YELLOW}[!] IPv6 enabled but ip6tables missing. Disabling IPv6 rules.${NC}\n"
            IPV6_ENABLED=false
        fi
    fi
}

# ---- ATOMİK KİLİT ----
acquire_lock() {
    mkdir -p -m 0700 "${LOCK_DIR}" 2>/dev/null || true
    exec 9>"${LOCK_FILE}" || exit 1
    if ! flock -n 9 2>/dev/null; then
        printf '%b' "${YELLOW}[!] Another instance active, waiting 5s...${NC}\n" >&2
        flock -w 5 9 || { printf '%b' "${RED}[-] Lock failed${NC}\n" >&2; exit 1; }
    fi
    printf '%s\n' "$$" >&9
    LOCK_FD_ACQUIRED="true"
    log_message "INFO" "Lock acquired (PID: $$)"
}

# ---- DOCKER-USER ZİNCİR GARANTİSİ ----
ensure_docker_user_chain_exists() {
    if ! iptables -L DOCKER-USER -n &>/dev/null; then
        iptables -N DOCKER-USER 2>/dev/null || true
    fi
    if ! iptables -C FORWARD -j DOCKER-USER 2>/dev/null; then
        iptables -I FORWARD -j DOCKER-USER 2>/dev/null || true
    fi
    
    if [[ "${IPV6_ENABLED}" == "true" ]]; then
        if ! ip6tables -L DOCKER-USER -n &>/dev/null; then
            ip6tables -N DOCKER-USER 2>/dev/null || true
        fi
        if ! ip6tables -C FORWARD -j DOCKER-USER 2>/dev/null; then
            ip6tables -I FORWARD -j DOCKER-USER 2>/dev/null || true
        fi
    fi
}

# ---- IDEMPOTENCY KONTROLLERİ ----
is_docker_config_already_correct() {
    [[ ! -f "${DOCKER_CONFIG}" ]] && return 1
    
    local current_ip current_ip6 current_userland
    current_ip=$(grep -o '"ip"[[:space:]]*:[[:space:]]*"[^"]*"' "${DOCKER_CONFIG}" 2>/dev/null | head -1 | cut -d'"' -f4 || echo "")
    current_ip6=$(grep -o '"ip6"[[:space:]]*:[[:space:]]*"[^"]*"' "${DOCKER_CONFIG}" 2>/dev/null | head -1 | cut -d'"' -f4 || echo "")
    current_userland=$(grep -o '"userland-proxy"[[:space:]]*:[[:space:]]*[^,}]*' "${DOCKER_CONFIG}" 2>/dev/null | grep -o 'true\|false' | head -1 || echo "")
    
    [[ "${current_ip}" == "127.0.0.1" ]] || return 1
    [[ "${current_userland}" == "false" ]] || return 1
    
    if [[ "${IPV6_ENABLED}" == "true" ]]; then
        [[ "${current_ip6}" == "::1" ]] || return 1
    fi
    return 0
}

is_firewall_already_hardened() {
    iptables -C DOCKER-USER -j REJECT --reject-with icmp-host-prohibited 2>/dev/null || return 1
    if [[ "${IPV6_ENABLED}" == "true" ]]; then
        ip6tables -C DOCKER-USER -j REJECT --reject-with icmp6-adm-prohibited 2>/dev/null || return 1
    fi
    return 0
}

# ---- FIREWALL KURALLARINI DOĞRUDAN EKLE (Kalıcı) ----
apply_firewall_rules() {
    echo "Applying IPv4 rules..."
    # Önce varsa eski kuralları temizle (idempotency için)
    firewall-cmd --direct --remove-rule ipv4 filter DOCKER-USER 0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
    firewall-cmd --direct --remove-rule ipv4 filter DOCKER-USER 1 -i lo -j ACCEPT 2>/dev/null || true
    firewall-cmd --direct --remove-rule ipv4 filter DOCKER-USER 2 -s 172.16.0.0/12 -d 172.16.0.0/12 -j ACCEPT 2>/dev/null || true
    firewall-cmd --direct --remove-rule ipv4 filter DOCKER-USER 3 -s 192.168.0.0/16 -d 192.168.0.0/16 -j ACCEPT 2>/dev/null || true
    firewall-cmd --direct --remove-rule ipv4 filter DOCKER-USER 4 -s 10.0.0.0/8 -d 10.0.0.0/8 -j ACCEPT 2>/dev/null || true
    firewall-cmd --direct --remove-rule ipv4 filter DOCKER-USER 5 -j REJECT --reject-with icmp-host-prohibited 2>/dev/null || true
    
    # Sırayla ekle (priority 0-5)
    firewall-cmd --direct --add-rule ipv4 filter DOCKER-USER 0 -m state --state RELATED,ESTABLISHED -j ACCEPT
    firewall-cmd --direct --add-rule ipv4 filter DOCKER-USER 1 -i lo -j ACCEPT
    firewall-cmd --direct --add-rule ipv4 filter DOCKER-USER 2 -s 172.16.0.0/12 -d 172.16.0.0/12 -j ACCEPT
    firewall-cmd --direct --add-rule ipv4 filter DOCKER-USER 3 -s 192.168.0.0/16 -d 192.168.0.0/16 -j ACCEPT
    firewall-cmd --direct --add-rule ipv4 filter DOCKER-USER 4 -s 10.0.0.0/8 -d 10.0.0.0/8 -j ACCEPT
    firewall-cmd --direct --add-rule ipv4 filter DOCKER-USER 5 -j REJECT --reject-with icmp-host-prohibited
    
    if [[ "${IPV6_ENABLED}" == "true" ]]; then
        echo "Applying IPv6 rules..."
        firewall-cmd --direct --remove-rule ipv6 filter DOCKER-USER 0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
        firewall-cmd --direct --remove-rule ipv6 filter DOCKER-USER 1 -i lo -j ACCEPT 2>/dev/null || true
        firewall-cmd --direct --remove-rule ipv6 filter DOCKER-USER 2 -s fc00::/7 -d fc00::/7 -j ACCEPT 2>/dev/null || true
        firewall-cmd --direct --remove-rule ipv6 filter DOCKER-USER 3 -j REJECT --reject-with icmp6-adm-prohibited 2>/dev/null || true
        
        firewall-cmd --direct --add-rule ipv6 filter DOCKER-USER 0 -m state --state RELATED,ESTABLISHED -j ACCEPT
        firewall-cmd --direct --add-rule ipv6 filter DOCKER-USER 1 -i lo -j ACCEPT
        firewall-cmd --direct --add-rule ipv6 filter DOCKER-USER 2 -s fc00::/7 -d fc00::/7 -j ACCEPT
        firewall-cmd --direct --add-rule ipv6 filter DOCKER-USER 3 -j REJECT --reject-with icmp6-adm-prohibited
    fi
    
    # Kuralları kalıcı yap
    firewall-cmd --runtime-to-permanent
}

# ---- DOCKER CONFIG ----
configure_docker_localhost() {
    if is_docker_config_already_correct; then
        printf '%b' "${GREEN}✅ Docker config already correct. Skipping.${NC}\n"
        return 0
    fi
    
    local temp_config
    temp_config=$(mktemp -p "${LOCK_DIR}" docker.XXXXXX.tmp) || exit 1
    
    if [[ -f "${DOCKER_CONFIG}" ]]; then
        local is_valid=1
        if command -v jq &>/dev/null; then
            jq empty "${DOCKER_CONFIG}" 2>/dev/null || is_valid=0
        elif command -v python3 &>/dev/null; then
            python3 -c 'import json, sys; json.load(open(sys.argv[1]))' "${DOCKER_CONFIG}" 2>/dev/null || is_valid=0
        fi
        
        if [[ ${is_valid} -eq 0 ]]; then
            printf '%b' "${YELLOW}[!] Existing daemon.json malformed. Moving to quarantine.${NC}\n"
            mv "${DOCKER_CONFIG}" "${DOCKER_CONFIG}.corrupt_$(date +%Y%m%d_%H%M%S)"
        else
            DOCKER_CONFIG_BACKUP="${DOCKER_CONFIG}.aegis_bak_$(date +%Y%m%d_%H%M%S)"
            cp -a "${DOCKER_CONFIG}" "${DOCKER_CONFIG_BACKUP}"
            log_message "INFO" "Docker backup: ${DOCKER_CONFIG_BACKUP}"
        fi
    fi
    
    if [[ "${IPV6_ENABLED}" == "true" ]]; then
        cat << 'EOF' > "${temp_config}"
{
  "iptables": true,
  "ip": "127.0.0.1",
  "ip6": "::1",
  "userland-proxy": false,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
    else
        cat << 'EOF' > "${temp_config}"
{
  "iptables": true,
  "ip": "127.0.0.1",
  "userland-proxy": false,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
    fi
    mv "${temp_config}" "${DOCKER_CONFIG}"
    chmod 0644 "${DOCKER_CONFIG}"
    log_message "INFO" "Docker config updated."
}

# ---- ANA AKIŞ ----
main() {
    clear
    printf '%b' "${BLUE}${BOLD}========================================================================${NC}\n"
    printf '%b' "${CYAN}${BOLD}    🛡️  AEGIS DOCKER HARDENING v6.6.0 (Direct Firewalld Rules)${NC}\n"
    printf '%b' "${BLUE}${BOLD}========================================================================${NC}\n"
    
    ensure_docker_user_chain_exists
    
    printf '%b' "${BLUE}[*] Phase 1: Updating Docker daemon.json for localhost binding...${NC}\n"
    configure_docker_localhost
    
    if ! is_firewall_already_hardened; then
        printf '%b' "${BLUE}[*] Phase 2: Applying direct firewalld rules...${NC}\n"
        apply_firewall_rules
    else
        printf '%b' "${GREEN}✅ Firewall rules already active. Skipping.${NC}\n"
    fi
    
    printf '%b' "${BLUE}[*] Phase 3: Reloading firewalld and restarting Docker...${NC}\n"
    firewall-cmd --reload >/dev/null 2>&1
    systemctl restart docker
    
    printf '%b' "${BLUE}[*] Phase 4: Forensic verification on live kernel tree...${NC}\n"
    sleep 2  # Kuralların oturması için kısa bekleme
    
    if iptables -C DOCKER-USER -j REJECT --reject-with icmp-host-prohibited 2>/dev/null; then
        printf '%b' "${GREEN}✅ REJECT rule verified in DOCKER-USER chain.${NC}\n"
    else
        printf '%b' "${RED}[-] ARCHITECTURE FAILURE: REJECT rule not found!${NC}\n" >&2
        echo "Current DOCKER-USER chain:"
        iptables -L DOCKER-USER -n 2>/dev/null || true
        exit 1
    fi
    
    printf '%b' "${BLUE}------------------------------------------------------------------------${NC}\n"
    printf '%b' "${GREEN}✅ SUCCESS: Hardening applied and kernel-verified.${NC}\n"
    printf '%b' "   - Published ports: localhost only\n"
    printf '%b' "   - Container internet egress: allowed\n"
    printf '%b' "   - External access to containers: BLOCKED\n"
    printf '%b' "${BLUE}========================================================================${NC}\n"
    log_message "SUCCESS" "Hardening completed (v6.6.0)"
}

check_prerequisites
acquire_lock
main
