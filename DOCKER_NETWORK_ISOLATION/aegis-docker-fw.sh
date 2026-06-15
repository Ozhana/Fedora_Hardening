#!/usr/bin/env bash
# ==============================================================================
# BETİK ADI      : aegis-docker-hardening.sh
# AMAÇ           : Docker'ı Localhost'a Bağlar, DNAT & Firewalld Bypass'ı Kapatır
# YAZAN          : Dr. Ozhan Akdag & Senior Cyber Security Agent
# SÜRÜM          : 7.0.0 (Direct Passthrough - Atomic Rule Injection)
# KRİTER         : No iptables-restore, per-rule addition, full idempotency
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

# Durum bayrakları
LOCK_FD_ACQUIRED="false"
DOCKER_CONFIG_BACKUP=""
IPV6_ENABLED=false
RULES_APPLIED=false

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
        
        if [[ "${RULES_APPLIED}" == "true" ]]; then
            # Eklenen kuralları temizle
            firewall-cmd --direct --remove-passthrough ipv4 -A DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
            firewall-cmd --direct --remove-passthrough ipv4 -A DOCKER-USER -i lo -j ACCEPT 2>/dev/null || true
            firewall-cmd --direct --remove-passthrough ipv4 -A DOCKER-USER -s 172.16.0.0/12 -d 172.16.0.0/12 -j ACCEPT 2>/dev/null || true
            firewall-cmd --direct --remove-passthrough ipv4 -A DOCKER-USER -s 192.168.0.0/16 -d 192.168.0.0/16 -j ACCEPT 2>/dev/null || true
            firewall-cmd --direct --remove-passthrough ipv4 -A DOCKER-USER -s 10.0.0.0/8 -d 10.0.0.0/8 -j ACCEPT 2>/dev/null || true
            firewall-cmd --direct --remove-passthrough ipv4 -A DOCKER-USER -j REJECT --reject-with icmp-host-prohibited 2>/dev/null || true
            
            if [[ "${IPV6_ENABLED}" == "true" ]]; then
                firewall-cmd --direct --remove-passthrough ipv6 -A DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
                firewall-cmd --direct --remove-passthrough ipv6 -A DOCKER-USER -i lo -j ACCEPT 2>/dev/null || true
                firewall-cmd --direct --remove-passthrough ipv6 -A DOCKER-USER -s fc00::/7 -d fc00::/7 -j ACCEPT 2>/dev/null || true
                firewall-cmd --direct --remove-passthrough ipv6 -A DOCKER-USER -j REJECT --reject-with icmp6-adm-prohibited 2>/dev/null || true
            fi
            
            firewall-cmd --reload >/dev/null 2>&1 || true
            log_message "WARN" "Firewall rules rolled back"
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
    for cmd in systemctl docker firewall-cmd iptables ip6tables; do
        command -v "${cmd}" &>/dev/null || missing+=("${cmd}")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        printf '%b' "${RED}[-] Missing: ${missing[*]}${NC}\n" >&2
        exit 1
    fi
    
    if systemctl is-active --quiet docker; then
        log_message "INFO" "Docker is running"
    else
        printf '%b' "${YELLOW}[!] Docker is not running. Starting...${NC}\n"
        systemctl start docker
        sleep 2
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

# ---- DOCKER-USER ZİNCİRİNİ OLUŞTUR (MANUEL) ----
create_docker_user_chain() {
    # Docker çalışıyor olmalı, yoksa zincir oluşmaz
    if ! iptables -L DOCKER-USER -n &>/dev/null; then
        iptables -N DOCKER-USER 2>/dev/null || true
        # FORWARD'dan DOCKER-USER'a yönlendirme yoksa ekle
        if ! iptables -C FORWARD -j DOCKER-USER 2>/dev/null; then
            iptables -I FORWARD -j DOCKER-USER 2>/dev/null || true
        fi
        log_message "INFO" "Created DOCKER-USER chain (IPv4)"
    fi
    
    if [[ "${IPV6_ENABLED}" == "true" ]]; then
        if ! ip6tables -L DOCKER-USER -n &>/dev/null; then
            ip6tables -N DOCKER-USER 2>/dev/null || true
            if ! ip6tables -C FORWARD -j DOCKER-USER 2>/dev/null; then
                ip6tables -I FORWARD -j DOCKER-USER 2>/dev/null || true
            fi
            log_message "INFO" "Created DOCKER-USER chain (IPv6)"
        fi
    fi
}

# ---- IDEMPOTENCY KONTROLLERİ ----
is_docker_config_already_correct() {
    [[ ! -f "${DOCKER_CONFIG}" ]] && return 1
    
    local current_ip current_ip6 current_userland
    current_ip=$(grep -o '"ip"[[:space:]]*:[[:space:]]*"[^"]*"' "${DOCKER_CONFIG}" 2>/dev/null | head -1 | cut -d'"' -f4 || echo "")
    current_userland=$(grep -o '"userland-proxy"[[:space:]]*:[[:space:]]*[^,}]*' "${DOCKER_CONFIG}" 2>/dev/null | grep -o 'true\|false' | head -1 || echo "")
    
    [[ "${current_ip}" == "127.0.0.1" ]] || return 1
    [[ "${current_userland}" == "false" ]] || return 1
    
    if [[ "${IPV6_ENABLED}" == "true" ]]; then
        current_ip6=$(grep -o '"ip6"[[:space:]]*:[[:space:]]*"[^"]*"' "${DOCKER_CONFIG}" 2>/dev/null | head -1 | cut -d'"' -f4 || echo "")
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

# ---- DOCKER CONFIG ----
configure_docker_localhost() {
    if is_docker_config_already_correct; then
        printf '%b' "${GREEN}✅ Docker config already correct. Skipping.${NC}\n"
        return 0
    fi
    
    printf '%b' "${BLUE}[*] Phase 1: Updating Docker daemon.json for localhost binding...${NC}\n"
    
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
            log_message "INFO" "Docker backup created"
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
    
    printf '%b' "${RED}[-] Docker failed to start! Rolling back.${NC}\n" >&2
    exit 1
}

# ---- FIREWALL KURALLARINI UYGULA (Direct Passthrough) ----
apply_firewall_rules() {
    printf '%b' "${BLUE}[*] Phase 2: Applying direct firewalld rules...${NC}\n"
    
    # Önce DOCKER-USER zincirinin var olduğundan emin ol
    create_docker_user_chain
    
    # IPv4 kurallarını teker teker ekle
    local ipv4_rules=(
        "-A DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT"
        "-A DOCKER-USER -i lo -j ACCEPT"
        "-A DOCKER-USER -s 172.16.0.0/12 -d 172.16.0.0/12 -j ACCEPT"
        "-A DOCKER-USER -s 192.168.0.0/16 -d 192.168.0.0/16 -j ACCEPT"
        "-A DOCKER-USER -s 10.0.0.0/8 -d 10.0.0.0/8 -j ACCEPT"
        "-A DOCKER-USER -j REJECT --reject-with icmp-host-prohibited"
    )
    
    for rule in "${ipv4_rules[@]}"; do
        if ! firewall-cmd --direct --add-passthrough ipv4 "${rule}" 2>/dev/null; then
            printf '%b' "${RED}[-] Failed to add IPv4 rule: ${rule}${NC}\n" >&2
            exit 1
        fi
        printf '%b' "${GREEN}  + Added IPv4: ${rule}${NC}\n"
    done
    
    # IPv6 kuralları (sadece aktifse)
    if [[ "${IPV6_ENABLED}" == "true" ]]; then
        local ipv6_rules=(
            "-A DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT"
            "-A DOCKER-USER -i lo -j ACCEPT"
            "-A DOCKER-USER -s fc00::/7 -d fc00::/7 -j ACCEPT"
            "-A DOCKER-USER -j REJECT --reject-with icmp6-adm-prohibited"
        )
        for rule in "${ipv6_rules[@]}"; do
            if ! firewall-cmd --direct --add-passthrough ipv6 "${rule}" 2>/dev/null; then
                printf '%b' "${YELLOW}[!] Failed to add IPv6 rule (IPv6 may be disabled): ${rule}${NC}\n"
            else
                printf '%b' "${GREEN}  + Added IPv6: ${rule}${NC}\n"
            fi
        done
    fi
    
    RULES_APPLIED=true
    log_message "INFO" "Firewall rules applied via direct passthrough"
}

# ---- KERNEL DOĞRULAMA ----
verify_kernel_rules() {
    printf '%b' "${BLUE}[*] Phase 4: Forensic verification on live kernel tree...${NC}\n"
    
    local verified=false
    local max_retries=10
    
    for ((i=1; i<=max_retries; i++)); do
        if iptables -C DOCKER-USER -j REJECT --reject-with icmp-host-prohibited 2>/dev/null; then
            verified=true
            break
        fi
        sleep 1
    done
    
    # Teşhis için mevcut durumu göster
    echo "DOCKER-USER chain contents:"
    iptables -L DOCKER-USER -n 2>/dev/null || echo "Chain not found"
    
    if [[ "${verified}" == "false" ]]; then
        printf '%b' "${RED}[-] ARCHITECTURE FAILURE: REJECT rule not found in DOCKER-USER chain!${NC}\n" >&2
        exit 1
    fi
    
    printf '%b' "${GREEN}✅ Kernel verification passed.${NC}\n"
}

# ---- ANA AKIŞ ----
main() {
    clear
    printf '%b' "${BLUE}${BOLD}========================================================================${NC}\n"
    printf '%b' "${CYAN}${BOLD}    🛡️  AEGIS DOCKER HARDENING v7.0.0 (Direct Passthrough)${NC}\n"
    printf '%b' "${BLUE}${BOLD}========================================================================${NC}\n"
    
    # Önce DOCKER-USER zincirini garanti altına al
    create_docker_user_chain
    
    # Docker config
    configure_docker_localhost
    
    # Firewall kuralları (sadece eksikse)
    if ! is_firewall_already_hardened; then
        apply_firewall_rules
        firewall-cmd --reload >/dev/null 2>&1
        sleep 1
    else
        printf '%b' "${GREEN}✅ Firewall rules already active. Skipping.${NC}\n"
    fi
    
    # Doğrulama
    verify_kernel_rules
    
    printf '%b' "${BLUE}------------------------------------------------------------------------${NC}\n"
    printf '%b' "${GREEN}✅ SUCCESS: Docker hardened successfully.${NC}\n"
    printf '%b' "   - Published ports: localhost only\n"
    printf '%b' "   - External access to containers: BLOCKED\n"
    printf '%b' "   - Container-to-container (private net): ALLOWED\n"
    printf '%b' "${BLUE}========================================================================${NC}\n"
    log_message "SUCCESS" "Hardening completed v7.0.0"
}

# ---- YÜRÜTME ----
check_prerequisites
acquire_lock
main
