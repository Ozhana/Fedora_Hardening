#!/usr/bin/env bash
# ==============================================================================
# BETİK ADI      : aegis-docker-hardening.sh
# SÜRÜM          : 7.1.0 (Manual Chain Creation + Direct Rules)
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
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# ---- SABİTLER ----
readonly LOCK_DIR="/run/aegis"
readonly LOCK_FILE="${LOCK_DIR}/aegis-docker-hardening.lock"
readonly LOG_DIR="/var/log/aegis"
readonly LOG_FILE="${LOG_DIR}/aegis-docker-hardening-$(date +%Y%m%d).log"
readonly DOCKER_CONFIG="/etc/docker/daemon.json"

# Durum
LOCK_FD_ACQUIRED="false"
DOCKER_BACKUP=""
IPV6_ENABLED=false

# ---- LOG FONKSİYONU ----
log_message() {
    mkdir -p "${LOG_DIR}" 2>/dev/null || true
    printf '[%s] [%s] %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$1" "$2" >> "${LOG_FILE}" 2>/dev/null || true
}

# ---- TEMİZLİK ----
cleanup() {
    local exit_code=$?
    trap '' EXIT INT TERM ERR HUP
    if [[ ${exit_code} -ne 0 ]] && [[ -n "${DOCKER_BACKUP}" ]] && [[ -f "${DOCKER_BACKUP}" ]]; then
        cp -a "${DOCKER_BACKUP}" "${DOCKER_CONFIG}" 2>/dev/null || true
        systemctl restart docker 2>/dev/null || true
        log_message "WARN" "Rollback: Docker config restored"
    fi
    find "${LOCK_DIR}" -maxdepth 1 -name "*.tmp" -delete 2>/dev/null || true
    if [[ "${LOCK_FD_ACQUIRED}" == "true" ]]; then
        exec 9>&- 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM ERR HUP

# ---- ÖN KONTROL ----
check_prerequisites() {
    if [[ ${EUID} -ne 0 ]]; then
        echo -e "${RED}[-] Root required!${NC}" >&2
        exit 1
    fi
    for cmd in systemctl docker iptables firewall-cmd; do
        command -v "${cmd}" &>/dev/null || { echo -e "${RED}[-] Missing: ${cmd}${NC}" >&2; exit 1; }
    done
    if [[ -f /proc/sys/net/ipv6/conf/all/disable_ipv6 ]] && [[ $(cat /proc/sys/net/ipv6/conf/all/disable_ipv6) -eq 0 ]]; then
        IPV6_ENABLED=true
    fi
}

# ---- KİLİT ----
acquire_lock() {
    mkdir -p -m 0700 "${LOCK_DIR}" 2>/dev/null || true
    exec 9>"${LOCK_FILE}" || exit 1
    flock -n 9 || { echo -e "${YELLOW}[!] Another instance running, waiting...${NC}" >&2; flock -w 5 9 || exit 1; }
    printf '%s\n' "$$" >&9
    LOCK_FD_ACQUIRED="true"
}

# ---- DOCKER CONFIG (localhost binding) ----
configure_docker() {
    if [[ -f "${DOCKER_CONFIG}" ]]; then
        # Basit kontrol: ip zaten 127.0.0.1 mi?
        if grep -q '"ip"[[:space:]]*:[[:space:]]*"127.0.0.1"' "${DOCKER_CONFIG}" 2>/dev/null; then
            echo -e "${GREEN}✅ Docker already bound to localhost. Skipping.${NC}"
            return 0
        fi
        DOCKER_BACKUP="${DOCKER_CONFIG}.aegis_bak_$(date +%Y%m%d_%H%M%S)"
        cp -a "${DOCKER_CONFIG}" "${DOCKER_BACKUP}"
    fi
    
    local tmp_conf
    tmp_conf=$(mktemp -p "${LOCK_DIR}" docker.XXXXXX.tmp) || exit 1
    
    if [[ "${IPV6_ENABLED}" == "true" ]]; then
        cat << 'EOF' > "${tmp_conf}"
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
        cat << 'EOF' > "${tmp_conf}"
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
    
    mv "${tmp_conf}" "${DOCKER_CONFIG}"
    chmod 0644 "${DOCKER_CONFIG}"
    systemctl restart docker
    sleep 2
    systemctl is-active --quiet docker || { echo -e "${RED}[-] Docker failed to start${NC}" >&2; exit 1; }
    echo -e "${GREEN}✅ Docker configured to localhost only.${NC}"
}

# ---- DOCKER-USER ZİNCİRİNİ MANUEL OLUŞTUR ----
create_docker_user_chain() {
    # Zincir yoksa oluştur
    if ! iptables -L DOCKER-USER -n &>/dev/null; then
        iptables -N DOCKER-USER 2>/dev/null || true
        echo -e "${BLUE}[*] Created DOCKER-USER chain${NC}"
    fi
    # FORWARD'dan bu zincire yönlendirme var mı?
    if ! iptables -C FORWARD -j DOCKER-USER 2>/dev/null; then
        iptables -I FORWARD -j DOCKER-USER 2>/dev/null || true
        echo -e "${BLUE}[*] Added DOCKER-USER jump from FORWARD${NC}"
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

# ---- FIREWALLD DIRECT KURALLARI (passthrough değil, doğrudan add-rule) ----
apply_firewall_rules() {
    echo -e "${BLUE}[*] Applying direct firewalld rules...${NC}"
    
    # Önce mevcut direct kuralları temizle (çakışma olmaması için)
    local existing_rules
    existing_rules=$(firewall-cmd --direct --get-all-rules 2>/dev/null | grep DOCKER-USER || true)
    for rule in "${existing_rules}"; do
        firewall-cmd --direct --remove-rule $rule 2>/dev/null || true
    done
    
    # IPv4 kuralları (sıra önemli!)
    firewall-cmd --direct --add-rule ipv4 filter DOCKER-USER 0 -m state --state RELATED,ESTABLISHED -j ACCEPT
    firewall-cmd --direct --add-rule ipv4 filter DOCKER-USER 1 -i lo -j ACCEPT
    firewall-cmd --direct --add-rule ipv4 filter DOCKER-USER 2 -s 172.16.0.0/12 -d 172.16.0.0/12 -j ACCEPT
    firewall-cmd --direct --add-rule ipv4 filter DOCKER-USER 3 -s 192.168.0.0/16 -d 192.168.0.0/16 -j ACCEPT
    firewall-cmd --direct --add-rule ipv4 filter DOCKER-USER 4 -s 10.0.0.0/8 -d 10.0.0.0/8 -j ACCEPT
    firewall-cmd --direct --add-rule ipv4 filter DOCKER-USER 5 -j REJECT --reject-with icmp-host-prohibited
    
    if [[ "${IPV6_ENABLED}" == "true" ]]; then
        firewall-cmd --direct --add-rule ipv6 filter DOCKER-USER 0 -m state --state RELATED,ESTABLISHED -j ACCEPT
        firewall-cmd --direct --add-rule ipv6 filter DOCKER-USER 1 -i lo -j ACCEPT
        firewall-cmd --direct --add-rule ipv6 filter DOCKER-USER 2 -s fc00::/7 -d fc00::/7 -j ACCEPT
        firewall-cmd --direct --add-rule ipv6 filter DOCKER-USER 3 -j REJECT --reject-with icmp6-adm-prohibited
    fi
    
    # Kuralları kalıcı yap
    firewall-cmd --runtime-to-permanent 2>/dev/null || true
    
    echo -e "${GREEN}✅ Firewall direct rules applied${NC}"
}

# ---- DOĞRULAMA ----
verify() {
    echo -e "${BLUE}[*] Verifying kernel rules...${NC}"
    sleep 2
    
    if iptables -C DOCKER-USER -j REJECT --reject-with icmp-host-prohibited 2>/dev/null; then
        echo -e "${GREEN}✅ REJECT rule active in DOCKER-USER chain${NC}"
    else
        echo -e "${RED}[-] REJECT rule NOT found! Dumping chain:${NC}"
        iptables -L DOCKER-USER -n 2>/dev/null || true
        exit 1
    fi
}

# ---- ANA ----
main() {
    clear
    echo -e "${BLUE}${BOLD}========================================================================${NC}"
    echo -e "${CYAN}${BOLD}    🛡️  AEGIS DOCKER HARDENING v7.1.0 (Direct Rules + Chain Creation)${NC}"
    echo -e "${BLUE}${BOLD}========================================================================${NC}"
    
    echo -e "${BLUE}[*] Phase 1: Configuring Docker localhost binding...${NC}"
    configure_docker
    
    echo -e "${BLUE}[*] Creating DOCKER-USER chain if missing...${NC}"
    create_docker_user_chain
    
    echo -e "${BLUE}[*] Phase 2: Applying firewall rules...${NC}"
    apply_firewall_rules
    
    echo -e "${BLUE}[*] Phase 3: Verification...${NC}"
    verify
    
    echo -e "${BLUE}------------------------------------------------------------------------${NC}"
    echo -e "${GREEN}✅ SUCCESS: Docker hardened successfully.${NC}"
    echo -e "${BLUE}========================================================================${NC}"
    log_message "SUCCESS" "Hardening v7.1.0 completed"
}

check_prerequisites
acquire_lock
main
