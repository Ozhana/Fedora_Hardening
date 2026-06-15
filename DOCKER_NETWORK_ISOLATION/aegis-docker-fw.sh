#!/usr/bin/env bash
# ==============================================================================
# BETİK ADI      : aegis-docker-hardening.sh
# AMAÇ           : Docker'ı Localhost'a Bağlar, DNAT & Firewalld Bypass'ı Kapatır
# YAZAN          : Dr. Ozhan Akdag & Senior Cyber Security Agent
# SÜRÜM          : 6.1.0 (Asenkron Çekirdek Bariyeri Yamalı - Stable Baseline)
# KRİTER         : No sync, No lockfile deletion, Full idempotency, Async-Proof
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
readonly DIRECT_XML="/etc/firewalld/direct.xml"

# Durum bayrakları
LOCK_FD_ACQUIRED="false"
DOCKER_CONFIG_BACKUP=""
FIREWALL_BACKUP=""
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

# ---- ATOMİK TEMİZLİK (LOCK FILE ASLA SİLİNMEZ) ----
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
        
        if [[ -n "${FIREWALL_BACKUP}" ]] && [[ -f "${FIREWALL_BACKUP}" ]]; then
            cp -a "${FIREWALL_BACKUP}" "${DIRECT_XML}"
            firewall-cmd --reload >/dev/null 2>&1 || true
            log_message "WARN" "Firewalld direct.xml rolled back"
        fi
    fi
    
    if [[ ${exit_code} -eq 0 ]]; then
        find /etc/docker -maxdepth 1 -name "daemon.json.aegis_bak_*" -mtime +30 -delete 2>/dev/null || true
        find "$(dirname "${DIRECT_XML}")" -maxdepth 1 -name "direct.xml.aegis_bak_*" -mtime +30 -delete 2>/dev/null || true
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
    for cmd in systemctl docker iptables firewall-cmd iptables-save ip6tables-save; do
        command -v "${cmd}" &>/dev/null || missing+=("${cmd}")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        printf '%b' "${RED}[-] Missing: ${missing[*]}${NC}\n" >&2
        exit 1
    fi
    
    if [[ -f /proc/sys/net/ipv6/conf/all/disable_ipv6 ]] && [[ $(cat /proc/sys/net/ipv6/conf/all/disable_ipv6) -eq 0 ]]; then
        IPV6_ENABLED=true
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
        iptables -I FORWARD -j DOCKER-USER 2>/dev/null || true
        log_message "INFO" "Created DOCKER-USER (IPv4)"
    fi
    
    if [[ "${TRIGGER_IPV6:-$IPV6_ENABLED}" == "true" ]] && ! ip6tables -L DOCKER-USER -n &>/dev/null; then
        ip6tables -N DOCKER-USER 2>/dev/null || true
        ip6tables -I FORWARD -j DOCKER-USER 2>/dev/null || true
        log_message "INFO" "Created DOCKER-USER (IPv6)"
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
    else
        if [[ -n "${current_ip6}" ]] && [[ "${current_ip6}" != "::1" ]]; then
            return 1
        fi
    fi
    return 0
}

is_firewall_already_hardened() {
    local v4_dump v6_dump
    v4_dump=$(iptables-save 2>/dev/null || echo "")
    
    local required_v4=(
        "-A DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT"
        "-A DOCKER-USER -i lo -j ACCEPT"
        "-A DOCKER-USER -s 172.16.0.0/12 -d 172.16.0.0/12 -j ACCEPT"
        "-A DOCKER-USER -s 192.168.0.0/16 -d 192.168.0.0/16 -j ACCEPT"
        "-A DOCKER-USER -s 10.0.0.0/8 -d 10.0.0.0/8 -j ACCEPT"
        "-A DOCKER-USER -j REJECT --reject-with icmp-host-prohibited"
    )
    for rule in "${required_v4[@]}"; do
        [[ "${v4_dump}" == *"${rule}"* ]] || return 1
    done
    
    if [[ "${IPV6_ENABLED}" == "true" ]]; then
        v6_dump=$(ip6tables-save 2>/dev/null || echo "")
        local required_v6=(
            "-A DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT"
            "-A DOCKER-USER -i lo -j ACCEPT"
            "-A DOCKER-USER -s fc00::/7 -d fc00::/7 -j ACCEPT"
            "-A DOCKER-USER -j REJECT --reject-with icmp6-adm-prohibited"
        )
        for rule in "${required_v6[@]}"; do
            [[ "${v6_dump}" == *"${rule}"* ]] || return 1
        done
    fi
    return 0
}

# ---- FAZ 1: DOCKER LOCALHOST ----
configure_docker_localhost() {
    if is_docker_config_already_correct; then
        printf '%b' "${GREEN}✅ Docker config already correct. Skipping restart.${NC}\n"
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
            printf '%b' "${YELLOW}[!] Existing daemon.json is malformed. Moving to quarantine.${NC}\n"
            mv "${DOCKER_CONFIG}" "${DOCKER_CONFIG}.corrupt_$(date +%Y%m%d_%H%M%S)"
        else
            DOCKER_CONFIG_BACKUP="${DOCKER_CONFIG}.aegis_bak_$(date +%Y%m%d_%H%M%S)"
            cp -a "${DOCKER_CONFIG}" "${DOCKER_CONFIG_BACKUP}"
            log_message "INFO" "Backup created: ${DOCKER_CONFIG_BACKUP}"
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
    
    systemctl restart docker
    local max_wait=10
    for ((i=0; i<max_wait; i++)); do
        if systemctl is-active --quiet docker; then
            log_message "INFO" "Docker restarted successfully"
            return 0
        fi
        sleep 1
    done
    
    printf '%b' "${RED}[-] Docker failed to start with new config! Rolling back.${NC}\n" >&2
    exit 1
}

# ---- FAZ 2: AEGIS FIREWALL SHIELD ----
install_aegis_shield() {
    if is_firewall_already_hardened; then
        printf '%b' "${GREEN}✅ Firewall rules already active. Skipping.${NC}\n"
        return 0
    fi
    
    # CRITICAL: Asenkron Çekirdek Bariyeri (Arka planda uyanan dockerd'nin zincirleri kernel'a basmasını bekle)
    printf '%b' "${BLUE}[*] Waiting for asynchronus Docker Netfilter hooks to settle in the kernel...${NC}\n"
    local settled=false
    for ((i=0; i<10; i++)); do
        if iptables -L DOCKER-USER -n &>/dev/null; then
            settled=true
            break
        fi
        sleep 1
    done
    
    if [[ "${settled}" == "false" ]]; then
        printf '%b' "${YELLOW}[!] UYARI: DOCKER-USER zinciri çekirdekte bulunamadı. Manuel enjeksiyon deneniyor...${NC}\n"
        ensure_docker_user_chain_exists
    fi
    
    if [[ -f "${DIRECT_XML}" ]]; then
        FIREWALL_BACKUP="${DIRECT_XML}.aegis_bak_$(date +%Y%m%d_%H%M%S)"
        cp -a "${DIRECT_XML}" "${FIREWALL_BACKUP}"
        log_message "INFO" "Firewall backup: ${FIREWALL_BACKUP}"
    fi
    
    local tmp_xml
    tmp_xml=$(mktemp -p "${LOCK_DIR}" direct.XXXXXX.tmp) || exit 1
    
    cat << 'EOF' > "${tmp_xml}"
<?xml version="1.0" encoding="utf-8"?>
<direct>
  <passthrough ipv="ipv4">-A DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT</passthrough>
  <passthrough ipv="ipv4">-A DOCKER-USER -i lo -j ACCEPT</passthrough>
  <passthrough ipv="ipv4">-A DOCKER-USER -s 172.16.0.0/12 -d 172.16.0.0/12 -j ACCEPT</passthrough>
  <passthrough ipv="ipv4">-A DOCKER-USER -s 192.168.0.0/16 -d 192.168.0.0/16 -j ACCEPT</passthrough>
  <passthrough ipv="ipv4">-A DOCKER-USER -s 10.0.0.0/8 -d 10.0.0.0/8 -j ACCEPT</passthrough>
  <passthrough ipv="ipv4">-A DOCKER-USER -j REJECT --reject-with icmp-host-prohibited</passthrough>

  <passthrough ipv="ipv6">-A DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT</passthrough>
  <passthrough ipv="ipv6">-A DOCKER-USER -i lo -j ACCEPT</passthrough>
  <passthrough ipv="ipv6">-A DOCKER-USER -s fc00::/7 -d fc00::/7 -j ACCEPT</passthrough>
  <passthrough ipv="ipv6">-A DOCKER-USER -j REJECT --reject-with icmp6-adm-prohibited</passthrough>
</direct>
EOF
    
    chmod 0600 "${tmp_xml}"
    mv "${tmp_xml}" "${DIRECT_XML}"
    
    if ! firewall-cmd --reload >/dev/null 2>&1; then
        printf '%b' "${RED}[-] firewalld rejected new rules!${NC}\n" >&2
        exit 1
    fi
    
    # Nihai Adli Çekirdek Doğrulaması
    if ! iptables -C DOCKER-USER -j REJECT --reject-with icmp-host-prohibited 2>/dev/null; then
        printf '%b' "${RED}[-] Kernel verification failed! Rules present in direct.xml but missing from runtime netfilter tree.${NC}\n" >&2
        exit 1
    fi
    log_message "INFO" "Aegis firewall shield installed"
}

# ---- ANA AKIŞ ----
main() {
    clear
    printf '%b' "${BLUE}${BOLD}========================================================================${NC}\n"
    printf '%b' "${CYAN}${BOLD}    🛡️  INCORPORATED AEGIS DOCKER HARDENING v6.1.0 (Async-Proof Barrier)${NC}\n"
    printf '%b' "${BLUE}${BOLD}========================================================================${NC}\n"
    
    printf '%b' "${BLUE}[*] Phase 1: Securing Docker to localhost...${NC}\n"
    configure_docker_localhost
    
    ensure_docker_user_chain_exists
    
    printf '%b' "${BLUE}[*] Phase 2: Installing Aegis Netfilter shield...${NC}\n"
    install_aegis_shield
    
    printf '%b' "${BLUE}------------------------------------------------------------------------${NC}\n"
    printf '%b' "${GREEN}✅ SUCCESS: Hardening Applied and Verified Against Asynchronous Kernel Delays.${NC}\n"
    printf '%b' "${BLUE}========================================================================${NC}\n"
    log_message "SUCCESS" "Full hardening completed (v6.1.0)"
}

check_prerequisites
acquire_lock
main
