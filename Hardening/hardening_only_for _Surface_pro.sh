#!/bin/bash
# ==============================================================================
# FEDORA 44/45/46 - SURFACE PRO 9 (POST-INSTALL SPEED & OS HARDENING PROTOCOL)
# ==============================================================================
# FELSEFE: PURE BOOTSTRAPPING | POST-INSTALL OPTIMIZATION | CYBER DECEPTION
# REPO: https://github.com/Ozhana/Fedora_Hardening
# ==============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

LOG_FILE="/var/log/fedora_post_install.log"
touch "$LOG_FILE" && chmod 600 "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

echo -e "\e[34m[i] FEDORA İLK KURULUM SONRASI SERTLEŞTİRME VE HIZ PROTOKOLÜ BAŞLATILDI...\e[0m"

# --- FAZ 0: YETKİ VE AĞ DOĞRULAMASI ---
if [[ "$EUID" -ne 0 ]]; then
    echo -e "\e[31m[X] KRİTİK HATA: Sadece root (sudo) yetkisiyle çalıştırılabilir.\e[0m"
    exit 1
fi

echo "[+] Paket yöneticisi ve depo erişilebilirliği doğrulanıyor..."
local_rc=0
set +e
dnf check-update --refresh >/dev/null 2>&1
local_rc=$?
set -e

if [[ $local_rc -ne 0 && $local_rc -ne 100 ]]; then
    echo -e "\e[33m[!] UYARI: Depolara erişilemiyor. Lütfen ağ bağlantınızı kontrol edin. İşlem durduruldu.\e[0m"
    exit 1
fi

# --- FAZ 1: DNF ALTYAPI HIZLANDIRMA VE DEPOLAR (IDEMPOTENT) ---
echo -e "\e[32m[+] Faz 1: DNF Eşzamanlı İndirme ve RPM Fusion Kontrolü...\e[0m"
mkdir -p /etc/dnf/dnf.conf.d
cat <<EOF > /etc/dnf/dnf.conf.d/99-speed.conf
[main]
fastestmirror=True
max_parallel_downloads=10
EOF

if ! rpm -q rpmfusion-free-release >/dev/null 2>&1 || ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
    echo "[+] RPM Fusion depoları kuruluyor..."
    dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
                    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
else
    echo "[i] RPM Fusion depoları zaten mevcut, geçiliyor."
fi

# --- FAZ 2: SAFRALARIN ARINDIRILMASI VE ZOMBI SERVİS MÜHÜRLERİ ---
echo -e "\e[32m[+] Faz 2: Varsayılan Bloatware Temizliği ve Saldırı Yüzeyi Küçültme...\e[0m"
pkill -f firefox || true

BLOAT_PKGS=(firefox gnome-tour yelp gnome-connections gnome-weather gnome-boxes)
for pkg in "${BLOAT_PKGS[@]}"; do
    rpm -q "$pkg" >/dev/null 2>&1 && dnf remove -y "$pkg" || true
done
dnf autoremove -y

ZOMBI_SERVICES=(
    "cups-browsed.service" "lvm2-monitor.service" "iscsid.service" "multipathd.service"
    "ModemManager.service" "avahi-daemon.service" "pcscd.service" "gssproxy.service"
    "abrtd.service" "abrt-journal-core.service" "cups.service" "cups.socket" "cups.path"
)
for svc in "${ZOMBI_SERVICES[@]}"; do
    if [ "$(systemctl show -p LoadState "$svc" | cut -d= -f2)" != "not-found" ]; then
        systemctl is-active --quiet "$svc" && systemctl stop "$svc" || true
        systemctl disable "$svc" >/dev/null 2>&1 || true
        systemctl mask "$svc" >/dev/null 2>&1 || true
    fi
done

# --- FAZ 3: SURFACE PRO 9 DONANIM VE GÜÇ YÖNETİMİ ---
echo -e "\e[32m[+] Faz 3: Surface Pro 9 Termal Yönetim ve Donanımsal %80 Şarj Sınırı...\e[0m"
rpm -q tuned >/dev/null 2>&1 || dnf install -y tuned
systemctl enable --now tuned >/dev/null 2>&1 || true
tuned-adm profile balanced

systemctl mask hibernate.target hybrid-sleep.target suspend-then-hibernate.target >/dev/null 2>&1 || true

cat <<'EOF' > /etc/systemd/system/surface-battery-limit.service
[Unit]
Description=Surface Pro 9 Batarya Sarj Sinirlayici (%80)
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'for d in /sys/class/power_supply/BAT*; do if [ -f "\$d/charge_control_limit_max_threshold" ]; then echo 80 > "\$d/charge_control_limit_max_threshold"; fi; done'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload && systemctl enable --now surface-battery-limit.service >/dev/null 2>&1 || true

# --- FAZ 4: KERNEL HARDENING VE GRUB DUAL-BOOT REPAIR ---
echo -e "\e[32m[+] Faz 4: Çekirdek Güvenlik Parametreleri ve Windows Seçenek Tamiri...\e[0m"

grubby --update-kernel=ALL --remove-args="rhgb quiet" || true
grubby --update-kernel=ALL --args="lockdown=integrity usbcore.autosuspend=-1 nvme_core.default_ps_max_latency_us=0 i915.enable_psr=0" || true

mkdir -p /etc/default/grub.d
cat <<EOF > /etc/default/grub.d/99-surface-hardening.cfg
GRUB_DISABLE_OS_PROBER=false
GRUB_TIMEOUT=5
GRUB_TERMINAL_OUTPUT="gfxterm"
GRUB_GFXMODE=1024x768x32
GRUB_DISABLE_RECOVERY="true"
GRUB_ENABLE_BLSCFG=true
EOF
grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/null 2>&1

local_tmp_conf="/etc/sysctl.d/99-hardened.conf"
: > "$local_tmp_conf"
declare -A POST_SYSCTL=(
    ["fs.protected_hardlinks"]="1"
    ["fs.protected_symlinks"]="1"
    ["fs.suid_dumpable"]="0"
    ["fs.protected_fifos"]="2"
    ["fs.protected_regular"]="2"
    ["kernel.kptr_restrict"]="2"
    ["kernel.sysrq"]="0"
    ["kernel.unprivileged_bpf_disabled"]="1"
    ["net.core.bpf_jit_harden"]="2"
    ["net.ipv4.conf.all.log_martians"]="1"
    ["net.ipv4.conf.all.accept_redirects"]="0"
    ["net.ipv4.conf.all.send_redirects"]="0"
    ["net.ipv4.conf.all.rp_filter"]="1"
    ["net.ipv6.conf.all.disable_ipv6"]="1"
)
for key in "${!POST_SYSCTL[@]}"; do
    if [ -d "/proc/sys/${key//./\/}" ] || [ -f "/proc/sys/${key//./\/}" ]; then
        echo "$key = ${POST_SYSCTL[$key]}" >> "$local_tmp_conf"
    fi
done
if [ -s "$local_tmp_conf" ]; then sysctl -p "$local_tmp_conf" >/dev/null; fi

# --- FAZ 5: AĞ GİZLİLİK KATMANI VE WINDOWS SİBER YANILTMA (DECEPTION) ---
echo -e "\e[32m[+] Faz 5: Gizli Ağ Profili ve Sahte Windows Hostname Entegrasyonu...\e[0m"
mkdir -p /etc/systemd/resolved.conf.d /etc/NetworkManager/conf.d /etc/modprobe.d

cat <<EOF > /etc/systemd/resolved.conf.d/99-quad9-dot.conf
[Resolve]
DNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net
DNSOverTLS=yes
DNSSEC=yes
DNSStubListener=yes
EOF
systemctl restart systemd-resolved

cat <<EOF > /etc/NetworkManager/conf.d/00-macrandomize.conf
[device]
wifi.scan-rand-mac-address=yes
[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
hostname-mode=none
EOF

# SİBER YANILTMA: Orijinal Windows kalıbında sahte bir Hostname üretimi
# Örnek Çıktı: DESKTOP-A7B2X9R veya LAPTOP-F4K8M1Z
PREFIX_POOL=("DESKTOP" "LAPTOP")
RANDOM_PREFIX=${PREFIX_POOL[$((RANDOM % 2))]}
RANDOM_SUFFIX=$(head /dev/urandom | tr -dc 'A-Z0-9' | head -c 7)
FAKE_WINDOWS_HOSTNAME="${RANDOM_PREFIX}-${RANDOM_SUFFIX}"

echo "[+] Ağdaki gözlemcileri yanıltmak için sahte Windows kimliği atanıyor: $FAKE_WINDOWS_HOSTNAME"
hostnamectl set-hostname "$FAKE_WINDOWS_HOSTNAME" && systemctl restart NetworkManager

cat <<EOF > /etc/modprobe.d/blacklist-prots.conf
install dccp /bin/true
install sctp /bin/true
install rds /bin/true
install tipc /bin/true
install firewire-core /bin/true
EOF

# --- FAZ 6: GÜVENLİK İZİNLERİ VE FAST SHUTDOWN SÜRESİ ---
echo -e "\e[32m[+] Faz 6: Dosya Sistemi İzin Sıkılaştırması ve Hızlı Kapanma VIP Ayarı...\e[0m"
sed -i 's/^UMASK.*/UMASK 077/g' /etc/login.defs
sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' /etc/login.defs
sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/' /etc/login.defs

mkdir -p /etc/security/limits.d /etc/systemd/system.conf.d
echo "* hard core 0" > /etc/security/limits.d/99-disable-core.conf

cat <<EOF > /etc/systemd/system.conf.d/99-fast-shutdown.conf
[Manager]
DefaultTimeoutStopSec=10s
EOF
systemctl daemon-reload

echo -e "\e[32m\n[!] AEGIS İLK KURULUM VE SİBER YANILTMA TABANLI HARDENING PROTOKOLÜ TAMAMLANDI!\e[0m"
echo -e "\e[34m[i] Cihaz ağ taramalarında artık standart bir Windows 10/11 istemcisi gibi parlayacaktır.\e[0m"
echo -e "\e[34m[i] İşlem günlük kaydı: $LOG_FILE\e[0m"
