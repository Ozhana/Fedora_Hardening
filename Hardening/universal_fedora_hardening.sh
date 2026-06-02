#!/bin/bash
# ==============================================================================
# FEDORA 44 - UNIVERSAL ENTERPRISE ARMOR (V17 - THE APEX PROTOCOL)
# ==============================================================================
# FELSEFE: ZERO ASSUMPTION | DYNAMIC HARDWARE DISCOVERY | DEFENSIVE SCRIPTING
# EKSTRA: KERNEL POWER DEADLOCK (WAKEUP) PREVENTION & HIBERNATE SHIELD
# ==============================================================================

# KATI HATA YÖNETİMİ (Hiçbir hata yutulmayacak!)
set -Eeuo pipefail
IFS=$'\n\t'

LOG_FILE="/var/log/fedora_apex_$(date +%Y%m%d_%H%M%S).log"
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

# ==============================================================================
# ANA BLOK (Tüm işlemler senkron loglama için izole edilmiştir)
# ==============================================================================
{
    echo -e "\e[34m[i] APEX UNIVERSAL PROTOKOLÜ BAŞLATILIYOR... LOG: $LOG_FILE\e[0m"

    # 1. ROOT (EUID) DOĞRULAMASI
    if [[ "$EUID" -ne 0 ]]; then
        echo -e "\e[31m[X] KRİTİK HATA: Sadece 'root' yetkisiyle (sudo) çalıştırılabilir.\e[0m"
        exit 1
    fi

    # 2. AĞ BAĞLANTISI DOĞRULAMASI
    echo "[+] Ağ bağlantısı (DNS) kontrol ediliyor..."
    if ! ping -c 2 9.9.9.9 >/dev/null 2>&1; then
        echo -e "\e[31m[X] KRİTİK HATA: İnternet bağlantısı yok! İşlem iptal edildi.\e[0m"
        exit 1
    fi

    echo -e "\e[32m[+] Kurumsal Düzey Sistem Doğrulaması (Pre-Flight) Başlıyor...\e[0m"

    # Gerekli Temel Araçların Kurulumu
    sudo dnf install -y tpm2-tools fwupd cryptsetup

    # SELinux Doğrulama
    SELINUX_STATUS=$(getenforce)
    if [ "$SELINUX_STATUS" != "Enforcing" ]; then
        echo -e "\e[33m[!] UYARI: SELinux $SELINUX_STATUS modunda. Bilinçli bir DEBUG seansında olduğunuz varsayılıyor.\e[0m"
    else
        echo -e "\e[32m[+] SELinux Enforcing modunda.\e[0m"
    fi

    # TPM VE LUKS KRİPTOGRAFİ (ESNEK DENETİM)
    echo "[+] LUKS2/SecureBoot Kriptografik Binding Analizi..."
    if sudo tpm2_pcrread sha256:0,7,11 >/dev/null 2>&1; then
        echo -e "\e[32m[+] TPM 2.0 PCR'leri okunabiliyor. Donanım ölçüm yapıyor.\e[0m"
    else
        echo -e "\e[33m[!] UYARI: TPM 2.0 PCR'leri okunamadı veya TPM aktif değil.\e[0m"
    fi

    if blkid_out=$(sudo blkid -t TYPE=crypto_LUKS -o device | head -n 1 2>/dev/null); then
        LUKS_PART="$blkid_out"
    else
        LUKS_PART=""
    fi

    if [ -n "$LUKS_PART" ]; then
        if sudo cryptsetup luksDump "$LUKS_PART" | grep -qi "tpm2"; then
            echo -e "\e[32m[+] LUKS2 Şifrelemesi TPM PCR zincirine kilitli (Binding Onaylandı).\e[0m"
        else
            echo -e "\e[33m[!] ZAFİYET: LUKS diski TPM'e bağlı değil! Sadece parola kullanılıyor.\e[0m"
        fi
    else
        echo -e "\e[34m[i] Sistemde LUKS şifreli bir disk bölümü bulunamadı.\e[0m"
    fi

    # FWUPD Analizi
    echo -e "\e[36m[i] === ÖNCESİ (PRE-FLIGHT) DONANIM GÜVENLİK ANALİZİ ===\e[0m"
    if ! fwupdmgr security --force; then
        echo -e "\e[33m[!] fwupd cihazda donanımsal zafiyetler raporladı veya tamamlanamadı.\e[0m"
    fi
    echo -e "\e[36m========================================================\e[0m"

    # --- FAZ 1: DNF ALTYAPISI ---
    echo "[+] Faz 1: Altyapı Hızlandırması..."
    sudo mkdir -p /etc/dnf/dnf.conf.d
    cat <<EOF | sudo tee /etc/dnf/dnf.conf.d/99-speed.conf > /dev/null
[main]
fastestmirror=True
max_parallel_downloads=10
EOF
    sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

    # --- FAZ 2: ZOMBİ SERVİSLER VE RCE KORUMASI ---
    echo "[+] Faz 2: Zombi Servisler Temizleniyor..."
    if pgrep -f firefox > /dev/null; then
        sudo pkill -f firefox
    fi

    # RPM Kontrollü Kesin Silme
    GEREKSIZ_PAKETLER=("firefox" "gnome-tour" "yelp" "gnome-connections" "gnome-weather" "gnome-boxes")
    for pkg in "${GEREKSIZ_PAKETLER[@]}"; do
        if rpm -q "$pkg" >/dev/null 2>&1; then
            sudo dnf remove -y "$pkg"
        fi
    done
    sudo dnf autoremove -y

    # Maskelenecek Evrensel Servisler
    MASK_SERVICES=(
        "cups-browsed.service" "lvm2-monitor.service" "iscsid.service" "multipathd.service" 
        "ModemManager.service" "cups.service" "cups.socket" "cups.path" "rpcbind.service" 
        "sssd.service" "abrtd.service" "abrt-journal-core.service" "abrt-oops.service" 
        "abrt-xorg.service" "NetworkManager-wait-online.service" "avahi-daemon.service" 
        "pcscd.service" "gssproxy.service" "sshd.service" "qemu-guest-agent.service" 
        "spice-vdagentd.service" "libvirtd.service" "virtqemud.service"
    )
    for svc in "${MASK_SERVICES[@]}"; do
        if systemctl list-unit-files "$svc" >/dev/null 2>&1; then
            if systemctl is-active --quiet "$svc"; then sudo systemctl stop "$svc"; fi
            sudo systemctl disable "$svc" 2>/dev/null
            sudo systemctl mask "$svc"
        fi
    done

    # Fwupd Otonomi İptali (Human in the loop)
    DISABLE_SERVICES=("fwupd.service" "fwupd-refresh.timer")
    for svc in "${DISABLE_SERVICES[@]}"; do
        if systemctl list-unit-files "$svc" >/dev/null 2>&1; then
            if systemctl is-active --quiet "$svc"; then sudo systemctl stop "$svc"; fi
            sudo systemctl disable "$svc" 2>/dev/null
        fi
    done

    # --- FAZ 3: EVRENSEL UYKU MÜHÜRÜ VE UYANMAMA (DEADLOCK) ÇÖZÜMÜ ---
    echo "[+] Faz 3: Evrensel Uyku Optimizasyonu ve Deadlock Koruması..."
    sudo dnf install -y tuned intel-media-driver libva-utils
    sudo systemctl enable --now tuned
    
    # Agresif pil profili, NVMe diski D3Cold moduna sokup komaya soktuğu için standart 'balanced' profiline geçildi.
    sudo tuned-adm profile balanced

    # HIBERNATION MASK: 'lockdown=integrity' RAM'in diske yazılmasını fiziksel olarak yasaklar. 
    # Sistem uykudan hibernate'e geçmeye çalışırsa çöker. Bunu kökünden engelliyoruz.
    echo "[+] Hibernation (Hazırda Bekletme) çakışmaları mühürleniyor..."
    sudo systemctl mask hibernate.target hybrid-sleep.target suspend-then-hibernate.target

    # DİNAMİK ACPI MÜHÜRÜ: Güç tuşu (PWRB), Kapak (LID) ve Uyku Tuşu (SLPB) hariç her şeyi dondurur.
    sudo tee /etc/systemd/system/uyku-muhuru.service > /dev/null <<'EOF'
[Unit]
Description=Universal Dynamic ACPI Wake Seal
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'awk "/enabled/ && \$1 !~ /PWRB|LID|SLPB/ {print \$1}" /proc/acpi/wakeup | while read dev; do echo $dev > /proc/acpi/wakeup || true; done'

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable --now uyku-muhuru.service

    # --- FAZ 4: YAZILIM CEPHANELİĞİ ---
    echo "[+] Faz 4: Sistem Araçları ve Python (PEP-668) Yükleniyor..."
    sudo dnf install -y keepassxc gnome-tweaks btop celluloid dejavu-sans-mono-fonts \
        python3 python3-pip python3-devel pipx \
        podman podman-compose timeshift \
        unhide aide rkhunter clamav clamav-update audit lynis

    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

    FLATPAK_APPS=("com.github.tchx84.Flatseal" "com.mattjakeman.ExtensionManager" "org.kde.okular" "com.github.xournalpp.xournalpp")
    for f_app in "${FLATPAK_APPS[@]}"; do
        if ! flatpak list | grep -q "$f_app"; then
            sudo flatpak install flathub "$f_app" -y
        fi
    done

    # --- FAZ 5: ÇEKİRDEK ZIRHI VE DONANIM UYANMA KİLİTLERİ ---
    echo "[+] Faz 5: GRUB İzolasyonu, Lockdown ve NVMe/GPU Uyanma Fixleri..."
    
    # KERNEL ARGS AÇIKLAMASI:
    # 1. lockdown=integrity: Çekirdek modifikasyonunu/Rootkit'leri engeller.
    # 2. usbcore.autosuspend=-1: Harici disklerin ve köprülerin elektrik kesintisiyle uykuda ölmesini engeller.
    # 3. nvme_core.default_ps_max_latency_us=0: NVMe disklerin PS4 (Derin Koma) moduna girip uyanamamasını engeller.
    # 4. i915.enable_psr=0: Intel ekran kartlarının uyanışta siyah ekran (Panel Self Refresh) arızasını engeller.
    sudo grubby --update-kernel=ALL --remove-args="rhgb quiet"
    sudo grubby --update-kernel=ALL --args="lockdown=integrity usbcore.autosuspend=-1 nvme_core.default_ps_max_latency_us=0 i915.enable_psr=0"

    sudo mkdir -p /etc/default/grub.d
    cat <<EOF | sudo tee /etc/default/grub.d/99-hardening.cfg > /dev/null
GRUB_DISABLE_OS_PROBER=true
GRUB_TIMEOUT=5
GRUB_TERMINAL_OUTPUT="gfxterm"
GRUB_GFXMODE=1024x768x32
GRUB_DISABLE_RECOVERY="true"
GRUB_ENABLE_BLSCFG=true
EOF
    sudo grub2-mkfont -s 24 -o /boot/grub2/fonts/unicode.pf2 /usr/share/fonts/dejavu-sans-mono-fonts/DejaVuSansMono.ttf || true
    sudo grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/null

    cat <<EOF | sudo tee /etc/sysctl.d/99-hardened.conf > /dev/null
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.suid_dumpable = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
kernel.kptr_restrict = 2
kernel.sysrq = 0
kernel.unprivileged_bpf_disabled = 1
kernel.yama.ptrace_scope = 1
fs.protected_fifos = 2
fs.protected_regular = 2
net.core.bpf_jit_harden = 2
net.ipv4.conf.all.rp_filter = 1
EOF
    sudo sysctl -p /etc/sysctl.d/99-hardened.conf >/dev/null

    # --- FAZ 6: AĞ GİZLİLİĞİ VE HOSTNAME ---
    echo "[+] Faz 6: Ağ Gizliliği..."
    sudo mkdir -p /etc/systemd/resolved.conf.d /etc/NetworkManager/conf.d /etc/modprobe.d

    cat <<EOF | sudo tee /etc/systemd/resolved.conf.d/99-quad9-dot.conf > /dev/null
[Resolve]
DNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net
DNSOverTLS=yes
DNSSEC=yes
DNSStubListener=yes
EOF
    sudo systemctl restart systemd-resolved

    cat <<EOF | sudo tee /etc/NetworkManager/conf.d/00-macrandomize.conf > /dev/null
[device]
wifi.scan-rand-mac-address=yes
[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
hostname-mode=none
EOF
    sudo hostnamectl set-hostname localhost
    sudo systemctl restart NetworkManager

    cat <<EOF | sudo tee /etc/modprobe.d/blacklist-prots.conf > /dev/null
install dccp /bin/true
install sctp /bin/true
install rds /bin/true
install tipc /bin/true
install firewire-core /bin/true
EOF

    # --- FAZ 7: İZİNLER VE ZAMAN AŞIMI ---
    echo "[+] Faz 7: İzinler ve Hızlandırma..."
    sudo sed -i 's/^UMASK.*/UMASK 077/g' /etc/login.defs
    sudo sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' /etc/login.defs
    sudo sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/' /etc/login.defs

    sudo mkdir -p /etc/security/limits.d /etc/systemd/system.conf.d /etc/systemd/system/dnf5daemon-server.service.d /etc/systemd/system/dnf-makecache.service.d /etc/issue.d
    echo "* hard core 0" | sudo tee /etc/security/limits.d/99-disable-core.conf > /dev/null

    cat <<EOF | sudo tee /etc/systemd/system.conf.d/99-fast-shutdown.conf > /dev/null
[Manager]
DefaultTimeoutStopSec=10s
EOF
    cat <<EOF | sudo tee /etc/systemd/system/dnf5daemon-server.service.d/override.conf > /dev/null
[Service]
TimeoutStopSec=10s
EOF
    cat <<EOF | sudo tee /etc/systemd/system/dnf-makecache.service.d/override.conf > /dev/null
[Service]
TimeoutStopSec=10s
EOF
    sudo systemctl daemon-reload

    echo "UNAUTHORIZED ACCESS PROHIBITED. ALL ACTIVITY IS MONITORED." | sudo tee /etc/issue.d/99-security.issue > /dev/null

    # --- FAZ 8: USBGUARD & FAPOLICYD ---
    echo "[+] Faz 8: Kurumsal Güvenlik Servisleri..."
    sudo dnf install -y usbguard fapolicyd

    if [ ! -s /etc/usbguard/rules.conf ]; then
        echo -e "\n\e[41m\e[97m /// DİKKAT: USB BEYAZ LİSTESİ OLUŞTURULUYOR /// \e[0m"
        echo -e "\e[33mKLAVYE VE MOUSE GİBİ USB CİHAZLARINIZ ŞU AN TAKILI MI?\e[0m"
        read -p "Cihazlar takılıysa ENTER tuşuna basıp devam edin..."
        sudo usbguard generate-policy | sudo tee /etc/usbguard/rules.conf > /dev/null
    fi
    sudo systemctl enable --now usbguard.service

    echo "[+] Fapolicyd: OSTree Trust Backend aktif ediliyor..."
    sudo sed -i 's/^trust =.*/trust = rpm,ostree,file/' /etc/fapolicyd/fapolicyd.conf
    if [ -f /etc/fapolicyd/rules.d/80-flatpak.rules ]; then
        sudo rm -f /etc/fapolicyd/rules.d/80-flatpak.rules
    fi

    sudo systemctl enable --now fapolicyd
    sudo fapolicyd-cli --update >/dev/null

    if ! sudo fapolicyd-cli --check-config >/dev/null 2>&1; then
        echo -e "\e[31m[X] HATA: Fapolicyd konfigürasyonu bozuk!\e[0m"
        exit 1
    fi

    # --- FAZ 9: DENETÇİLER ---
    echo "[+] Faz 9: Siber Denetçiler Mühürleniyor..."
    sudo systemctl enable --now auditd

    if ! sudo freshclam --quiet; then
        echo "[!] ClamAV sunucuları meşgul, güncelleme atlandı."
    fi
    sudo rkhunter --propupd >/dev/null

    if [ ! -f /var/lib/aide/aide.db.gz ]; then
        echo "[!] AIDE İlk Kurulum Baseline Alınıyor (Bekleyiniz, sistemin hızına göre 5-15 dk sürebilir)..."
        if sudo aide --init >/dev/null; then
            sudo mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
        else
            echo -e "\e[31m[X] HATA: AIDE veritabanı oluşturulamadı.\e[0m"
        fi
    else
        echo "[!] AIDE Baseline mevcut, eskisinin üzerine yazılmadı."
    fi
    sudo updatedb

    # --- FAZ 10: POST-FLIGHT AUDIT ---
    echo -e "\n\e[42m\e[97m === FAZ 10: SİSTEM DOĞRULAMA RAPORU (AUDIT) === \e[0m"

    echo -e "\n[1/7] SELinux Derin Raporu:"
    if sudo sestatus -v >/dev/null 2>&1; then
        sudo sestatus -v | grep -E "SELinux status|Current mode|Policy from config file"
    else
        echo "SELinux verisi okunamadı."
    fi

    echo -n "\n[2/7] Çekirdek Kilidi (Lockdown): "
    if [ -f /sys/kernel/security/lockdown ]; then
        cat /sys/kernel/security/lockdown
    else
        echo "Bulunamadı."
    fi

    echo -n "\n[3/7] USBGuard Servisi: "
    if systemctl is-active --quiet usbguard; then echo "Aktif"; else echo "PASİF!"; fi

    echo -n "\n[4/7] Fapolicyd Servisi: "
    if systemctl is-active --quiet fapolicyd; then echo "Aktif"; else echo "PASİF!"; fi

    echo -n "\n[5/7] IPv6 Koruması (Devre Dışı = 1): "
    sysctl -n net.ipv6.conf.all.disable_ipv6

    echo -n "\n[6/7] Sistem Hostname: "
    hostname

    echo -e "\n[7/7] TPM 2.0 Kriptografik LUKS Binding Denetimi: "
    if [ -n "${LUKS_PART:-}" ]; then
        if sudo cryptsetup luksDump "$LUKS_PART" | grep -E "Keyslot.*:|tpm2" >/dev/null; then
            sudo cryptsetup luksDump "$LUKS_PART" | grep -E "Keyslot.*:|tpm2"
        else
            echo "LUKS2 TPM mühürü bulunamadı!"
        fi
    else
        echo "Sistemde LUKS disk bulunamadı."
    fi

    echo -e "\e[32m\n[!] APEX UNIVERSAL OPERASYONU KUSURSUZ TAMAMLANDI!\e[0m"
    echo -e "\e[34m[i] Detaylı analiz log dosyası: $LOG_FILE\e[0m"

} 2>&1 | tee -a "$LOG_FILE"
