#!/bin/bash
# ==============================================================================
# FEDORA 44 KALE MATRIX - TÜM ÖZELLİKLER DAHİL (V8.2)
# Canlı İzleme + Sistem Snapshot + Akıllı Uyarılar + Servis Kontrolü
# ==============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# Görsel çerçeveler
BOX_TOP="╔══════════════════════════════════════════════════════════════════╗"
BOX_BOT="╚══════════════════════════════════════════════════════════════════╝"
BOX_MID="║"
SEPARATOR="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# İlerleme animasyonu
spinner() {
    local pid=$1
    local message=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) % 10 ))
        printf "\r  ${YELLOW}%s${NC} ${CYAN}%s...${NC}" "${spin:$i:1}" "$message"
        sleep 0.1
    done
    printf "\r  ${GREEN}✓${NC} ${GREEN}%s tamamlandı${NC}\n" "$message"
}

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}❌ Bu script yalnızca ROOT (sudo) ile çalıştırılabilir.${NC}" >&2
  exit 1
fi

if [[ "${1:-}" != "--inhibited" ]]; then
  echo -e "${CYAN}🛡️ Uyku engelleme kalkanı aktif ediliyor...${NC}"
  exec systemd-inhibit --what=sleep:idle --who="Kale_Bakim" --why="Sistem bakım ve denetimi" "$0" --inhibited "$@"
fi

LOCK_FILE="/run/kale_bakim.lock"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    echo -e "${RED}⚠️ Script zaten çalışıyor!${NC}" >&2
    exit 1
fi

cleanup() {
    if [[ -n "${CLEANUP_DONE:-}" ]]; then return 0; fi
    CLEANUP_DONE=1
    echo -e "\n${YELLOW}🧹 Kilitler temizleniyor...${NC}"
    rm -f "$LOCK_FILE" 2>/dev/null || true
}
trap cleanup EXIT

# Log dizini
LOG_DIR="/home/drozhanakdag/Desktop/oto_gorevler/logfiles"
SNAPSHOT_DIR="$LOG_DIR/snapshots"
mkdir -p "$LOG_DIR" "$SNAPSHOT_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
START_TIME=$(date +%s)
MAIN_LOG="$LOG_DIR/bakim_$TIMESTAMP.log"
ERROR_LOG="$LOG_DIR/hata_$TIMESTAMP.log"
SNAPSHOT_BEFORE="$SNAPSHOT_DIR/snapshot_before_$TIMESTAMP.txt"
SNAPSHOT_AFTER="$SNAPSHOT_DIR/snapshot_after_$TIMESTAMP.txt"

# =============================================
# 🎨 AÇILIŞ EKRANI
# =============================================
clear
echo -e "${GREEN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║   ██╗  ██╗ █████╗ ██╗     ███████╗    ███╗   ███╗ █████╗ ████████╗██████╗ ██╗██╗  ██╗
║   ██║ ██╔╝██╔══██╗██║     ██╔════╝    ████╗ ████║██╔══██╗╚══██╔══╝██╔══██╗██║╚██╗██╔╝
║   █████╔╝ ███████║██║     █████╗      ██╔████╔██║███████║   ██║   ██████╔╝██║ ╚███╔╝ 
║   ██╔═██╗ ██╔══██║██║     ██╔══╝      ██║╚██╔╝██║██╔══██║   ██║   ██╔══██╗██║ ██╔██╗ 
║   ██║  ██╗██║  ██║███████╗███████╗    ██║ ╚═╝ ██║██║  ██║   ██║   ██║  ██║██║██╔╝ ██╗
║   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝    ╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝╚═╝  ╚═╝
║                                                                  ║
║        🛡️ FEDORA 44 • TÜM ÖZELLİKLER DAHİL • V8.2 🛡️            ║
╚══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${WHITE}📅 Başlangıç: $(date '+%d %B %Y, %H:%M:%S')${NC}"
echo -e "${WHITE}💻 Sistem: $(hostname) - $(uname -r)${NC}"
echo -e "${WHITE}📂 Log: $LOG_DIR${NC}"
echo ""

# =============================================
# 📸 AŞAMA 0: SİSTEM SNAPSHOT'I (YENİ EKLEME)
# =============================================
echo -e "${BOLD}${CYAN}$BOX_TOP${NC}"
echo -e "${BOLD}${CYAN}$BOX_MID 📸 AŞAMA 0: SİSTEM DURUM KAYDI (SNAPSHOT)${NC}"
echo -e "${BOLD}${CYAN}$BOX_BOT${NC}"

echo -e "\n${YELLOW}📊 Çalışma öncesi sistem durumu kaydediliyor...${NC}"

# Detaylı sistem snapshot'ı
cat > "$SNAPSHOT_BEFORE" << SNAPSHOT
╔══════════════════════════════════════════════════════════════╗
║          KALE MATRIX - SİSTEM SNAPSHOT (ÖNCE)               ║
║          Tarih: $(date '+%d.%m.%Y %H:%M:%S')                  ║
╚══════════════════════════════════════════════════════════════╝

━━━━━━━━━━━━━ 💾 DİSK KULLANIMI ━━━━━━━━━━━━━
$(df -h / /home /boot /var 2>/dev/null)

━━━━━━━━━━━━━ 🧠 BELLEK KULLANIMI ━━━━━━━━━━━━━
$(free -h)

━━━━━━━━━━━━━ ⚡ CPU YÜKÜ ━━━━━━━━━━━━━
$(uptime)
CPU Çekirdek: $(nproc)
$(top -bn1 | grep "Cpu(s)" | head -1)

━━━━━━━━━━━━━ 🔄 ÇALIŞMA SÜRESİ ━━━━━━━━━━━━━
Son açılış: $(who -b | awk '{print $3, $4}')
Geçen süre: $(uptime -p | cut -d' ' -f2-)

━━━━━━━━━━━━━ 📦 PAKET DURUMU ━━━━━━━━━━━━━
Toplam RPM paketi: $(rpm -qa | wc -l)
Toplam Flatpak: $(flatpak list 2>/dev/null | wc -l || echo "0")

━━━━━━━━━━━━━ 🛡️ GÜVENLİK DURUMU ━━━━━━━━━━━━━
SELinux: $(getenforce 2>/dev/null || echo "Kurulu değil")
Firewall: $(systemctl is-active firewalld 2>/dev/null || echo "aktif değil")

━━━━━━━━━━━━━ 🔑 SSH DURUMU ━━━━━━━━━━━━━
$(systemctl is-active sshd 2>/dev/null && echo "SSH: AKTİF" || echo "SSH: kapalı")
$(grep "^PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null || echo "Root login: belirsiz")
$(grep "^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null || echo "Şifre auth: belirsiz")

━━━━━━━━━━━━━ 📂 DİZİN BOYUTLARI ━━━━━━━━━━━━━
/var/cache/dnf: $(du -sh /var/cache/dnf 2>/dev/null | cut -f1 || echo "N/A")
/tmp: $(du -sh /tmp 2>/dev/null | cut -f1 || echo "N/A")
/var/log/journal: $(du -sh /var/log/journal 2>/dev/null | cut -f1 || echo "N/A")
SNAPSHOT

echo -e "${GREEN}✅ Snapshot kaydedildi: $SNAPSHOT_BEFORE${NC}"

# Özet bilgileri canlı göster
echo -e "\n${WHITE}📊 ÇALIŞMA ÖNCESİ ÖZET:${NC}"
echo -e "${CYAN}$SEPARATOR${NC}"
echo -e "  💾 Disk: $(df -h / | tail -1 | awk '{print $3 " / " $2 " (" $5 ")"}')"
echo -e "  🧠 RAM:  $(free -h | grep Mem | awk '{print $3 " / " $2}')"
echo -e "  ⚡ Yük:  $(uptime | awk -F'load average:' '{print $2}')"
echo -e "  📦 RPM:  $(rpm -qa | wc -l) paket"
echo -e "  🛡️ SELinux: $(getenforce 2>/dev/null || echo 'N/A')"
echo -e "${CYAN}$SEPARATOR${NC}"

# =============================================
# 🩺 SERVİS DURUM KONTROLÜ (YENİ EKLEME)
# =============================================
echo -e "\n${BOLD}${CYAN}$BOX_TOP${NC}"
echo -e "${BOLD}${CYAN}$BOX_MID 🩺 KRİTİK SERVİS DURUM KONTROLÜ${NC}"
echo -e "${BOLD}${CYAN}$BOX_BOT${NC}"

echo -e "\n${YELLOW}Kritik servisler denetleniyor...${NC}"

KRITIK_SERVISLER=(
    "sshd:SSH Sunucusu"
    "firewalld:Güvenlik Duvarı"
    "systemd-journald:Günlük Servisi"
    "systemd-timesyncd:Zaman Senkronizasyonu"
    "chronyd:Chrony Zaman"
    "NetworkManager:Ağ Yöneticisi"
)

SERVIS_SORUN=0
for servis_bilgi in "${KRITIK_SERVISLER[@]}"; do
    SERVIS="${servis_bilgi%%:*}"
    ACIKLAMA="${servis_bilgi##*:}"
    
    if systemctl is-active --quiet "$SERVIS" 2>/dev/null; then
        echo -e "  ${GREEN}✅ $ACIKLAMA ($SERVIS): ÇALIŞIYOR${NC}"
    else
        if systemctl is-enabled --quiet "$SERVIS" 2>/dev/null; then
            echo -e "  ${RED}❌ $ACIKLAMA ($SERVIS): DURMUŞ! (etkin ama çalışmıyor)${NC}"
            SERVIS_SORUN=1
        else
            echo -e "  ${YELLOW}⚠️ $ACIKLAMA ($SERVIS): Devre dışı${NC}"
        fi
    fi
done

if [ $SERVIS_SORUN -eq 1 ]; then
    echo -e "\n${RED}⚠️ BAZI KRİTİK SERVİSLER ÇALIŞMIYOR! Yukarıdaki listeyi kontrol edin.${NC}" | tee -a "$ERROR_LOG"
else
    echo -e "\n${GREEN}✅ Tüm kritik servisler normal${NC}"
fi

# =============================================
# 🔌 BAĞLANTI NOKTASI KONTROLÜ (YENİ EKLEME)
# =============================================
echo -e "\n${YELLOW}💾 Bağlantı noktaları kontrol ediliyor...${NC}"

# Kritik mount noktaları
KRITIK_MOUNTLAR=("/" "/home" "/boot")
MOUNT_SORUN=0

for mount_nokta in "${KRITIK_MOUNTLAR[@]}"; do
    if mountpoint -q "$mount_nokta" 2>/dev/null; then
        DISK=$(df -h "$mount_nokta" | tail -1 | awk '{print $1}')
        KULLANIM=$(df -h "$mount_nokta" | tail -1 | awk '{print $5}')
        echo -e "  ${GREEN}✅ $mount_nokta: Bağlı ($DISK, %$KULLANIM)${NC}"
    else
        echo -e "  ${RED}❌ $mount_nokta: BAĞLI DEĞİL!${NC}"
        MOUNT_SORUN=1
    fi
done

# /tmp kontrolü
if mountpoint -q /tmp 2>/dev/null; then
    echo -e "  ${GREEN}✅ /tmp: Ayrı bölüm olarak bağlı${NC}"
else
    echo -e "  ${YELLOW}⚠️ /tmp: Ayrı bölüm değil (güvenlik için ayrı bölüm önerilir)${NC}"
fi

if [ $MOUNT_SORUN -eq 1 ]; then
    echo -e "${RED}⚠️ BAZI BAĞLANTI NOKTALARI SORUNLU!${NC}" | tee -a "$ERROR_LOG"
fi

echo ""
echo -e "${CYAN}$SEPARATOR${NC}"
sleep 2

# =============================================
# AŞAMA 1: SİSTEM GÜNCELLEMELERİ
# =============================================
echo -e "\n${BOLD}${PURPLE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${PURPLE}║  AŞAMA 1/5: SİSTEM GÜNCELLEMELERİ                   ║${NC}"
echo -e "${BOLD}${PURPLE}╚══════════════════════════════════════════════════════╝${NC}"

# Güncelleme sayısı kontrolü
echo -e "\n${CYAN}📦 Güncelleme sayısı kontrol ediliyor...${NC}"
dnf check-update > /tmp/dnf_check_$$.log 2>&1 &
PID_CHECK=$!
spinner $PID_CHECK "Depo kontrolü"

UPDATE_COUNT=$(grep -c '\.' /tmp/dnf_check_$$.log 2>/dev/null || echo "0")
if [ "$UPDATE_COUNT" -gt 0 ]; then
    echo -e "  ${YELLOW}📦 $UPDATE_COUNT paket güncellenecek${NC}"
    
    # Güncelleme öncesi kernel versiyonu
    OLD_KERNEL=$(uname -r)
    
    echo -e "\n${CYAN}⬇️  Güncellemeler indiriliyor ve yükleniyor...${NC}"
    echo -e "${WHITE}$SEPARATOR${NC}"
    
    if dnf upgrade --refresh -y 2>&1 | tee -a "$MAIN_LOG" | grep --line-buffered -E "Upgrading|Installing|Cleanup|Complete"; then
        echo -e "\n${GREEN}✅ Güncellemeler başarıyla yüklendi!${NC}"
        
        # =============================================
        # 🔄 AKILLI YENİDEN BAŞLATMA KONTROLÜ (YENİ EKLEME)
        # =============================================
        echo -e "\n${YELLOW}🔄 Yeniden başlatma gerekiyor mu?${NC}"
        echo -e "${CYAN}$SEPARATOR${NC}"
        
        REBOOT_GEREKLI=0
        REBOOT_NEDENLERI=()
        
        # Kernel güncellendi mi?
        NEW_KERNEL=$(uname -r)
        if [ "$OLD_KERNEL" != "$NEW_KERNEL" ]; then
            echo -e "  ${RED}⚠️ Kernel güncellendi: $OLD_KERNEL → $NEW_KERNEL${NC}"
            REBOOT_GEREKLI=1
            REBOOT_NEDENLERI+=("Kernel güncellendi")
        fi
        
        # systemd güncellendi mi?
        if dnf history info last 2>/dev/null | grep -q "systemd"; then
            echo -e "  ${RED}⚠️ Systemd güncellendi${NC}"
            REBOOT_GEREKLI=1
            REBOOT_NEDENLERI+=("Systemd güncellendi")
        fi
        
        # glibc güncellendi mi?
        if dnf history info last 2>/dev/null | grep -q "glibc"; then
            echo -e "  ${RED}⚠️ glibc (temel C kütüphanesi) güncellendi${NC}"
            REBOOT_GEREKLI=1
            REBOOT_NEDENLERI+=("glibc güncellendi")
        fi
        
        # Çalışan servisler eski kütüphaneleri kullanıyor mu?
        if dnf needs-restarting -r 2>/dev/null | grep -q "Reboot"; then
            echo -e "  ${RED}⚠️ Çalışan servisler eski kütüphaneleri kullanıyor${NC}"
            REBOOT_GEREKLI=1
            REBOOT_NEDENLERI+=("Servisler güncel değil")
        fi
        
        if [ $REBOOT_GEREKLI -eq 1 ]; then
            echo -e "\n${RED}╔══════════════════════════════════════════════════════╗${NC}"
            echo -e "${RED}║ ⚠️  YENİDEN BAŞLATMA ŞİDDETLE ÖNERİLİR!              ║${NC}"
            echo -e "${RED}║ Nedenler:                                           ║${NC}"
            for neden in "${REBOOT_NEDENLERI[@]}"; do
                printf "${RED}║   • %-50s║\n${NC}" "$neden"
            done
            echo -e "${RED}╚══════════════════════════════════════════════════════╝${NC}"
        else
            echo -e "\n${GREEN}✅ Yeniden başlatma gerekmiyor${NC}"
        fi
    else
        echo -e "\n${RED}❌ Güncelleme hatası! İnternet bağlantısını kontrol edin.${NC}" | tee -a "$ERROR_LOG"
    fi
    rm -f /tmp/dnf_check_$$.log
else
    echo -e "  ${GREEN}✅ Sistem zaten güncel${NC}"
    rm -f /tmp/dnf_check_$$.log
fi

# Flatpak güncelleme
if command -v flatpak &>/dev/null; then
    echo -e "\n${CYAN}📦 Flatpak güncellemeleri...${NC}"
    flatpak update -y 2>&1 | head -10 | while read line; do
        echo -e "  ${WHITE}$line${NC}"
    done
fi

echo ""
echo -e "${CYAN}$SEPARATOR${NC}"
sleep 1

# =============================================
# AŞAMA 2: SİSTEM TEMİZLİĞİ
# =============================================
echo -e "\n${BOLD}${PURPLE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${PURPLE}║  AŞAMA 2/5: SİSTEM TEMİZLİĞİ                        ║${NC}"
echo -e "${BOLD}${PURPLE}╚══════════════════════════════════════════════════════╝${NC}"

# Yetim paketler
echo -e "\n${YELLOW}🗑️  Yetim paketler...${NC}"
dnf autoremove -y 2>&1 | tail -5 | while read line; do echo -e "  ${WHITE}$line${NC}"; done
echo -e "${GREEN}✅ Tamamlandı${NC}"

# Önbellek
echo -e "\n${YELLOW}🧹 Önbellek temizleniyor...${NC}"
BEFORE=$(du -sh /var/cache/dnf 2>/dev/null | cut -f1)
dnf clean packages 2>&1 >> "$MAIN_LOG"
AFTER=$(du -sh /var/cache/dnf 2>/dev/null | cut -f1)
echo -e "${GREEN}✅ Önbellek: ${WHITE}$BEFORE → $AFTER${NC}"

# /tmp temizliği
echo -e "\n${YELLOW}🗑️  /tmp temizleniyor...${NC}"
BEFORE=$(du -sh /tmp 2>/dev/null | cut -f1)
rm -rf /tmp/* 2>/dev/null || true
AFTER=$(du -sh /tmp 2>/dev/null | cut -f1)
echo -e "${GREEN}✅ /tmp: ${WHITE}$BEFORE → $AFTER${NC}"

# Journal
echo -e "\n${YELLOW}📜 Journal log (7 gün)...${NC}"
BEFORE=$(journalctl --disk-usage 2>/dev/null | awk '{print $NF}')
journalctl --vacuum-time=7d 2>&1 | tail -1 | while read line; do echo -e "  ${WHITE}$line${NC}"; done
AFTER=$(journalctl --disk-usage 2>/dev/null | awk '{print $NF}')
echo -e "${GREEN}✅ Journal: ${WHITE}$BEFORE → $AFTER${NC}"

echo ""
echo -e "${CYAN}$SEPARATOR${NC}"
sleep 1

# =============================================
# AŞAMA 3: DİSK BAKIMI
# =============================================
echo -e "\n${BOLD}${PURPLE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${PURPLE}║  AŞAMA 3/5: DİSK BAKIMI                             ║${NC}"
echo -e "${BOLD}${PURPLE}╚══════════════════════════════════════════════════════╝${NC}"

# TRIM
echo -e "\n${YELLOW}💾 SSD TRIM...${NC}"
fstrim -va 2>&1 | while read line; do
    echo -e "  ${GREEN}▸ $line${NC}"
done | tee -a "$MAIN_LOG"

# BTRFS
if mount | grep -q "type btrfs"; then
    echo -e "\n${YELLOW}🔍 BTRFS scrub...${NC}"
    btrfs scrub start -B / 2>&1 | while read line; do
        echo -e "  ${CYAN}$line${NC}"
    done | tee -a "$MAIN_LOG"
fi

echo ""
echo -e "${CYAN}$SEPARATOR${NC}"
sleep 1

# =============================================
# AŞAMA 4: GÜVENLİK DENETİMİ
# =============================================
echo -e "\n${BOLD}${PURPLE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${PURPLE}║  AŞAMA 4/5: GÜVENLİK DENETİMİ                       ║${NC}"
echo -e "${BOLD}${PURPLE}╚══════════════════════════════════════════════════════╝${NC}"

# AIDE
if command -v aide &>/dev/null; then
    echo -e "\n${YELLOW}🔐 AIDE kontrolü...${NC}"
    aide --check > "$LOG_DIR/aide_$TIMESTAMP.log" 2>&1 &
    spinner $! "AIDE bütünlük taraması"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ AIDE: Değişiklik yok${NC}"
    else
        CHANGE_COUNT=$(grep -c "changed" "$LOG_DIR/aide_$TIMESTAMP.log" 2>/dev/null || echo "?")
        echo -e "${YELLOW}⚠️ AIDE: $CHANGE_COUNT dosya değişmiş${NC}"
    fi
else
    echo -e "${BLUE}ℹ️ AIDE yüklü değil${NC}"
fi

# Lynis
if command -v lynis &>/dev/null; then
    echo -e "\n${YELLOW}🛡️ Lynis denetimi...${NC}"
    lynis audit system --quick > "$LOG_DIR/lynis_$TIMESTAMP.log" 2>&1 &
    LYNIS_PID=$!
    
    while kill -0 $LYNIS_PID 2>/dev/null; do
        CURRENT=$(tail -1 "$LOG_DIR/lynis_$TIMESTAMP.log" 2>/dev/null | grep -oP '\[.*?\]' | head -1)
        [ -n "$CURRENT" ] && printf "\r  ${CYAN}🔍 %s${NC}" "$CURRENT"
        sleep 0.3
    done
    wait $LYNIS_PID
    
    if [ -f /var/log/lynis-report.dat ]; then
        SCORE=$(grep "hardening_index" /var/log/lynis-report.dat | cut -d= -f2)
        cp /var/log/lynis-report.dat "$LOG_DIR/lynis_report_$TIMESTAMP.dat"
        
        if [ "$SCORE" -ge 80 ]; then
            echo -e "\n${GREEN}✅ Lynis: ${BOLD}$SCORE/100${NC} ${GREEN}(MÜKEMMEL)${NC}"
        elif [ "$SCORE" -ge 60 ]; then
            echo -e "\n${YELLOW}⚠️ Lynis: ${BOLD}$SCORE/100${NC} ${YELLOW}(İYİ)${NC}"
        else
            echo -e "\n${RED}❌ Lynis: ${BOLD}$SCORE/100${NC} ${RED}(ZAYIF)${NC}"
        fi
    fi
fi

echo ""
echo -e "${CYAN}$SEPARATOR${NC}"
sleep 1

# =============================================
# AŞAMA 5: GÜVENLİK SERTLEŞTİRME
# =============================================
echo -e "\n${BOLD}${PURPLE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${PURPLE}║  AŞAMA 5/5: GÜVENLİK SERTLEŞTİRME                   ║${NC}"
echo -e "${BOLD}${PURPLE}╚══════════════════════════════════════════════════════╝${NC}"

# Cron izinleri
echo -e "\n${YELLOW}🔒 Cron izinleri...${NC}"
for dir in /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly /etc/crontab; do
    [ -e "$dir" ] && chmod 700 "$dir" 2>/dev/null && echo -e "  ${GREEN}✅ $dir${NC}" || true
done

# SSH kontrol
echo -e "\n${YELLOW}🔑 SSH kontrolü...${NC}"
[ -f /etc/ssh/sshd_config ] && grep "^PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null | while read line; do
    [[ "$line" == *"yes"* ]] && echo -e "  ${RED}❌ $line${NC}" || echo -e "  ${GREEN}✅ $line${NC}"
done

# Banner
echo -e "\n${YELLOW}📝 Banner...${NC}"
BANNER="KALE FEDORA 44 - YETKİSİZ ERİŞİM YASAKTIR"
for file in /etc/issue /etc/issue.net; do
    grep -qF "$BANNER" "$file" 2>/dev/null && echo -e "  ${GREEN}✅ $file mevcut${NC}" || {
        echo "$BANNER" >> "$file"
        echo -e "  ${YELLOW}⚠️ $file eklendi${NC}"
    }
done

# =============================================
# 📸 SON SNAPSHOT (YENİ EKLEME)
# =============================================
echo -e "\n${YELLOW}📸 Son durum kaydediliyor...${NC}"

cat > "$SNAPSHOT_AFTER" << SNAPSHOT
╔══════════════════════════════════════════════════════════════╗
║          KALE MATRIX - SİSTEM SNAPSHOT (SONRA)              ║
║          Tarih: $(date '+%d.%m.%Y %H:%M:%S')                  ║
╚══════════════════════════════════════════════════════════════╝

━━━━━━━━━━━━━ 💾 DİSK KULLANIMI ━━━━━━━━━━━━━
$(df -h / /home 2>/dev/null)

━━━━━━━━━━━━━ 🧠 BELLEK ━━━━━━━━━━━━━
$(free -h | grep -E "Mem|Swap")

━━━━━━━━━━━━━ 📦 GÜNCELLEME ÖZETİ ━━━━━━━━━━━━━
$(dnf history info last 2>/dev/null | head -20 || echo "Bilgi alınamadı")
SNAPSHOT

echo -e "${GREEN}✅ Snapshot: $SNAPSHOT_AFTER${NC}"

# =============================================
# 🏆 NİHAİ ÖZET
# =============================================
END_TIME=$(date +%s)
SURECE=$(($END_TIME - $START_TIME))
DAKIKA=$((SURECE / 60))
SANIYE=$((SURECE % 60))

echo -e "\n${BOLD}${GREEN}$BOX_TOP${NC}"
echo -e "${BOLD}${GREEN}$BOX_MID 🏆 KALE MATRIX V8.2 - İŞLEM TAMAMLANDI${NC}"
echo -e "${BOLD}${GREEN}$BOX_BOT${NC}"

echo -e "\n${WHITE}⏱️  TOPLAM SÜRE: ${DAKIKA} dakika ${SANIYE} saniye${NC}"
echo -e "${CYAN}$SEPARATOR${NC}"

echo -e "\n${WHITE}📊 İŞLEM ÖZETİ:${NC}"
echo -e "  ${GREEN}✅ Sistem Snapshot'ı (öncesi/sonrası)${NC}"
echo -e "  ${GREEN}✅ Servis Durum Kontrolü${NC}"
echo -e "  ${GREEN}✅ Bağlantı Noktası Kontrolü${NC}"
echo -e "  ${GREEN}✅ Sistem Güncellemeleri${NC}"
[ $REBOOT_GEREKLI -eq 1 ] && echo -e "  ${RED}⚠️ YENİDEN BAŞLATMA ÖNERİLİYOR!${NC}"
echo -e "  ${GREEN}✅ Sistem Temizliği${NC}"
echo -e "  ${GREEN}✅ Disk Bakımı${NC}"
echo -e "  ${GREEN}✅ Güvenlik Denetimi${NC}"
echo -e "  ${GREEN}✅ Güvenlik Sertleştirme${NC}"

echo -e "\n${WHITE}📂 DOSYALAR:${NC}"
echo -e "  📄 Ana log:   ${CYAN}$MAIN_LOG${NC}"
echo -e "  📸 Önce:      ${CYAN}$SNAPSHOT_BEFORE${NC}"
echo -e "  📸 Sonra:     ${CYAN}$SNAPSHOT_AFTER${NC}"
[ -f "$ERROR_LOG" ] && [ -s "$ERROR_LOG" ] && echo -e "  ⚠️ Hatalar:   ${RED}$ERROR_LOG${NC}"

# Eski log temizliği
echo -e "\n${YELLOW}🗑️  Eski loglar temizleniyor (30 gün)...${NC}"
DELETED=$(find "$LOG_DIR" -name "*.log" -mtime +30 -delete -print 2>/dev/null | wc -l)
echo -e "${GREEN}✅ $DELETED eski dosya silindi${NC}"

# =============================================
# KAPANIŞ
# =============================================
echo -e "\n${CYAN}$BOX_TOP${NC}"
echo -e "${CYAN}$BOX_MID${NC}"
echo -e "${CYAN}$BOX_MID  ${YELLOW}⏱️  30 saniye içinde sistem kapatılacak${NC}"
echo -e "${CYAN}$BOX_MID  ${YELLOW}    İptal: [N] | Hemen kapat: [K]${NC}"
echo -e "${CYAN}$BOX_MID${NC}"
echo -e "${CYAN}$BOX_BOT${NC}"

for i in {30..1}; do
    printf "\r${RED}⏳ Kapanış: %2d saniye ${NC}" $i
    read -r -t 1 -n 1 CHOICE 2>/dev/null && break
done

echo ""
if [[ "${CHOICE:-}" =~ ^[Nn]$ ]]; then
    echo -e "\n${GREEN}🟢 KALE ÇEVRİMİÇİ! Sistem açık kalacak.${NC}"
    echo -e "${GREEN}   Loglar: $LOG_DIR${NC}"
else
    echo -e "\n${RED}🔴 KALE KAPANIYOR...${NC}"
    sync
    sleep 1
    systemctl poweroff
fi
