#!/bin/bash
# ==============================================================================
# KALE ANTİVİRÜS TARAMA - CANLI İZLEME MODU (V2.0)
# rkhunter + clamav sıralı derin tarama | Tüm çıktılar terminalde
# ==============================================================================

set -Eeuo pipefail

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

# Dönen animasyon
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
    wait "$pid"
    local exit_code=$?
    printf "\r\033[K"  # Satırı temizle
    return $exit_code
}

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}❌ Bu script yalnızca ROOT (sudo) ile çalıştırılabilir.${NC}" >&2
  exit 1
fi

# Uyku engelleme
if [[ "${1:-}" != "--inhibited" ]]; then
  echo -e "${CYAN}🛡️ Uyku engelleme kalkanı aktif ediliyor...${NC}"
  exec systemd-inhibit --what=sleep:idle --who="Kale_Antivirus" --why="Virüs ve rootkit taraması" "$0" --inhibited "$@"
fi

# Kilit mekanizması
LOCK_FILE="/run/kale_antivirus.lock"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    echo -e "${RED}⚠️ Antivirüs taraması zaten çalışıyor! İkinci örnek reddedildi.${NC}" >&2
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
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
START_TIME=$(date +%s)

AV_LOG="$LOG_DIR/antivirus_$TIMESTAMP.log"
RKHUNTER_LOG="$LOG_DIR/rkhunter_$TIMESTAMP.log"
CLAMAV_LOG="$LOG_DIR/clamav_$TIMESTAMP.log"

# =============================================
# 🎨 AÇILIŞ EKRANI
# =============================================
clear
echo -e "${RED}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║   █████╗ ███╗   ██╗████████╗██╗    ██╗   ██╗██╗██████╗ ██╗   ██╗███████╗
║  ██╔══██╗████╗  ██║╚══██╔══╝██║    ██║   ██║██║██╔══██╗██║   ██║██╔════╝
║  ███████║██╔██╗ ██║   ██║   ██║    ██║   ██║██║██████╔╝██║   ██║███████╗
║  ██╔══██║██║╚██╗██║   ██║   ██║    ╚██╗ ██╔╝██║██╔══██╗██║   ██║╚════██║
║  ██║  ██║██║ ╚████║   ██║   ██║     ╚████╔╝ ██║██║  ██║╚██████╔╝███████║
║  ╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝   ╚═╝      ╚═══╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝
║                                                                  ║
║           🦠 KALE ANTİVİRÜS • CANLI İZLEME • V2.0 🦠             ║
╚══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${WHITE}📅 Başlangıç: $(date '+%d %B %Y, %H:%M:%S')${NC}"
echo -e "${WHITE}💻 Sistem: $(hostname) - $(uname -r)${NC}"
echo -e "${WHITE}📂 Log: $LOG_DIR${NC}"
echo ""

# =============================================
# 📦 ÖN KONTROL: GEREKLİ PAKETLER
# =============================================
echo -e "${BOLD}${CYAN}$BOX_TOP${NC}"
echo -e "${BOLD}${CYAN}$BOX_MID 📦 GEREKLİ ARAÇLAR KONTROL EDİLİYOR${NC}"
echo -e "${BOLD}${CYAN}$BOX_BOT${NC}"

EKSIK_PAKET=0

echo -e "\n${YELLOW}ClamAV kontrol ediliyor...${NC}"
if command -v clamscan &>/dev/null; then
    CLAMAV_VERSION=$(clamscan --version 2>/dev/null | head -1)
    echo -e "  ${GREEN}✅ ClamAV yüklü: ${WHITE}$CLAMAV_VERSION${NC}"
else
    echo -e "  ${RED}❌ ClamAV YÜKLÜ DEĞİL!${NC}"
    echo -e "  ${YELLOW}  Yüklemek için: sudo dnf install clamav clamav-update -y${NC}"
    EKSIK_PAKET=1
fi

if command -v freshclam &>/dev/null; then
    echo -e "  ${GREEN}✅ Freshclam (güncelleme aracı) yüklü${NC}"
else
    echo -e "  ${RED}❌ Freshclam YÜKLÜ DEĞİL!${NC}"
    EKSIK_PAKET=1
fi

echo -e "\n${YELLOW}Rkhunter kontrol ediliyor...${NC}"
if command -v rkhunter &>/dev/null; then
    RKHUNTER_VERSION=$(rkhunter --version 2>/dev/null | head -1)
    echo -e "  ${GREEN}✅ Rkhunter yüklü: ${WHITE}$RKHUNTER_VERSION${NC}"
else
    echo -e "  ${RED}❌ Rkhunter YÜKLÜ DEĞİL!${NC}"
    echo -e "  ${YELLOW}  Yüklemek için: sudo dnf install rkhunter -y${NC}"
    EKSIK_PAKET=1
fi

if [ $EKSIK_PAKET -eq 1 ]; then
    echo -e "\n${RED}⚠️ Eksik paketler var! Lütfen yukarıdaki komutlarla yükleyin.${NC}"
    echo -e "${RED}   Script şimdi sonlanacak.${NC}"
    exit 1
fi

echo -e "\n${GREEN}✅ Tüm gerekli araçlar yüklü!${NC}"
echo -e "${CYAN}$SEPARATOR${NC}"
sleep 1

# =============================================
# 🦠 AŞAMA 1: CLAMAV VERİTABANI GÜNCELLEME
# =============================================
echo -e "\n${BOLD}${PURPLE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${PURPLE}║  AŞAMA 1/4: CLAMAV VERİTABANI GÜNCELLEME            ║${NC}"
echo -e "${BOLD}${PURPLE}╚══════════════════════════════════════════════════════╝${NC}"

echo -e "\n${YELLOW}⬇️  ClamAV virüs tanımları indiriliyor...${NC}"
echo -e "${WHITE}$SEPARATOR${NC}"

# freshclam çıktısını CANLI göster
freshclam --stdout 2>&1 | while IFS= read -r line; do
    if echo "$line" | grep -qi "daily\|main\|bytecode\|database\|updated\|fresh"; then
        echo -e "  ${CYAN}▸ $line${NC}"
    elif echo "$line" | grep -qi "error\|fail\|cannot"; then
        echo -e "  ${RED}▸ $line${NC}"
    elif echo "$line" | grep -qi "up to date\|already"; then
        echo -e "  ${GREEN}▸ $line${NC}"
    else
        echo -e "  ${WHITE}▸ $line${NC}"
    fi
done | tee -a "$AV_LOG"

FRESHCLAM_EXIT=${PIPESTATUS[0]}
if [ $FRESHCLAM_EXIT -eq 0 ]; then
    echo -e "\n${GREEN}✅ ClamAV veritabanı güncel!${NC}"
else
    echo -e "\n${YELLOW}⚠️ ClamAV güncellemede bazı uyarılar (normal olabilir)${NC}"
fi

echo -e "\n${WHITE}📊 GÜNCEL VERİTABANI BİLGİSİ:${NC}"
if [ -d /var/lib/clamav ]; then
    echo -e "  📅 Main:  $(stat -c '%y' /var/lib/clamav/main.cvd 2>/dev/null | cut -d'.' -f1 || echo 'N/A')"
    echo -e "  📅 Daily: $(stat -c '%y' /var/lib/clamav/daily.cvd 2>/dev/null | cut -d'.' -f1 || echo 'N/A')"
    echo -e "  📅 Bytecode: $(stat -c '%y' /var/lib/clamav/bytecode.cvd 2>/dev/null | cut -d'.' -f1 || echo 'N/A')"
    echo -e "  📏 Boyut: $(du -sh /var/lib/clamav 2>/dev/null | cut -f1 || echo 'N/A')"
fi

echo ""
echo -e "${CYAN}$SEPARATOR${NC}"
sleep 1

# =============================================
# 🕵️ AŞAMA 2: RKHUNTER VERİTABANI GÜNCELLEME
# =============================================
echo -e "\n${BOLD}${PURPLE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${PURPLE}║  AŞAMA 2/4: RKHUNTER VERİTABANI GÜNCELLEME          ║${NC}"
echo -e "${BOLD}${PURPLE}╚══════════════════════════════════════════════════════╝${NC}"

echo -e "\n${YELLOW}⬇️  Rkhunter özellik veritabanı güncelleniyor...${NC}"
echo -e "${WHITE}$SEPARATOR${NC}"

# rkhunter update çıktısını CANLI göster
rkhunter --update 2>&1 | while IFS= read -r line; do
    if echo "$line" | grep -qi "downloading\|updated\|checking\|mirror"; then
        echo -e "  ${CYAN}▸ $line${NC}"
    elif echo "$line" | grep -qi "error\|fail\|warning"; then
        echo -e "  ${YELLOW}▸ $line${NC}"
    elif echo "$line" | grep -qi "complete\|finished\|success"; then
        echo -e "  ${GREEN}▸ $line${NC}"
    else
        echo -e "  ${WHITE}▸ $line${NC}"
    fi
done | tee -a "$AV_LOG"

RKHUNTER_UPDATE_EXIT=${PIPESTATUS[0]}
if [ $RKHUNTER_UPDATE_EXIT -eq 0 ]; then
    echo -e "\n${GREEN}✅ Rkhunter veritabanı güncellendi!${NC}"
else
    echo -e "\n${YELLOW}⚠️ Rkhunter güncellemede uyarılar (bazı ayna hataları normaldir)${NC}"
fi

echo -e "\n${WHITE}📊 RKHUNTER VERİTABANI:${NC}"
if [ -f /var/lib/rkhunter/db/rkhunter.dat ]; then
    echo -e "  📅 Güncelleme: $(stat -c '%y' /var/lib/rkhunter/db/rkhunter.dat 2>/dev/null | cut -d'.' -f1 || echo 'N/A')"
    echo -e "  📏 Boyut: $(du -sh /var/lib/rkhunter 2>/dev/null | cut -f1 || echo 'N/A')"
fi

echo ""
echo -e "${CYAN}$SEPARATOR${NC}"
sleep 1

# =============================================
# 🕵️ AŞAMA 3: RKHUNTER ROOTKIT TARAMASI
# =============================================
echo -e "\n${BOLD}${RED}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${RED}║  AŞAMA 3/4: RKHUNTER ROOTKIT TARAMASI 🔍            ║${NC}"
echo -e "${BOLD}${RED}╚══════════════════════════════════════════════════════╝${NC}"

echo -e "\n${YELLOW}🔍 Sistem rootkit ve zararlı yazılım taraması başlıyor...${NC}"
echo -e "${YELLOW}   Bu işlem birkaç dakika sürebilir, sabırlı olun...${NC}"
echo -e "${WHITE}$SEPARATOR${NC}"

# rkhunter taramasını CANLI göster (önemli satırları vurgula)
RKHUNTER_TEMP="/tmp/rkhunter_live_$$.log"

# Arka planda çalıştır ve çıktıyı canlı göster
rkhunter --check --sk --nocolor > "$RKHUNTER_TEMP" 2>&1 &
RKHUNTER_PID=$!

# Tarama ilerlemesini canlı göster
LAST_LINE=""
while kill -0 $RKHUNTER_PID 2>/dev/null; do
    if [ -f "$RKHUNTER_TEMP" ]; then
        CURRENT_LINE=$(tail -1 "$RKHUNTER_TEMP" 2>/dev/null)
        if [ "$CURRENT_LINE" != "$LAST_LINE" ] && [ -n "$CURRENT_LINE" ]; then
            # Önemli satırları renklendir
            if echo "$CURRENT_LINE" | grep -qi "warning\|suspicious\|vulnerable\|possible\|found"; then
                echo -e "  ${RED}⚠️  $CURRENT_LINE${NC}"
            elif echo "$CURRENT_LINE" | grep -qi "checking\|starting\|performing\|scanning"; then
                echo -e "  ${CYAN}🔍 $CURRENT_LINE${NC}"
            elif echo "$CURRENT_LINE" | grep -qi "ok\|clean\|not found\|none"; then
                echo -e "  ${GREEN}✅ $CURRENT_LINE${NC}"
            elif echo "$CURRENT_LINE" | grep -qi "skipped\|by design\|false positive"; then
                echo -e "  ${YELLOW}⏭️  $CURRENT_LINE${NC}"
            else
                echo -e "  ${WHITE}   $CURRENT_LINE${NC}"
            fi
            LAST_LINE="$CURRENT_LINE"
        fi
    fi
    sleep 0.3
done
wait $RKHUNTER_PID
RKHUNTER_EXIT=$?

# Tam logu kaydet
cp "$RKHUNTER_TEMP" "$RKHUNTER_LOG"
rm -f "$RKHUNTER_TEMP"

echo -e "\n${WHITE}$SEPARATOR${NC}"

# Sonuç analizi
echo -e "\n${WHITE}📊 RKHUNTER SONUÇ ANALİZİ:${NC}"
echo -e "${CYAN}$SEPARATOR${NC}"

WARNING_COUNT=$(grep -c "Warning" "$RKHUNTER_LOG" 2>/dev/null || echo "0")
SUSPICIOUS_COUNT=$(grep -ci "suspicious\|possible rootkit\|vulnerable" "$RKHUNTER_LOG" 2>/dev/null || echo "0")
ROOTKIT_COUNT=$(grep -ci "rootkit found" "$RKHUNTER_LOG" 2>/dev/null || echo "0")

echo -e "  📊 Toplam uyarı: ${YELLOW}$WARNING_COUNT${NC}"
echo -e "  📊 Şüpheli dosya: ${YELLOW}$SUSPICIOUS_COUNT${NC}"
echo -e "  📊 Rootkit tespiti: ${RED}$ROOTKIT_COUNT${NC}"

# Önemli bulguları göster
if [ "$WARNING_COUNT" -gt 0 ]; then
    echo -e "\n${YELLOW}⚠️ ÖNEMLİ UYARILAR:${NC}"
    grep -A 2 "Warning" "$RKHUNTER_LOG" 2>/dev/null | head -30 | while read line; do
        echo -e "  ${YELLOW}$line${NC}"
    done
fi

if [ "$SUSPICIOUS_COUNT" -gt 0 ]; then
    echo -e "\n${RED}🚨 ŞÜPHELİ BULGULAR:${NC}"
    grep -i -A 5 "suspicious\|possible rootkit" "$RKHUNTER_LOG" 2>/dev/null | head -20 | while read line; do
        echo -e "  ${RED}$line${NC}"
    done
fi

# Genel değerlendirme
if [ "$ROOTKIT_COUNT" -gt 0 ]; then
    echo -e "\n${RED}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║ 🚨 ROOTKIT BULUNDU! DETAYLI İNCELEME GEREKİYOR!      ║${NC}"
    echo -e "${RED}║ Log: $RKHUNTER_LOG                                   ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════╝${NC}"
elif [ "$SUSPICIOUS_COUNT" -gt 0 ]; then
    echo -e "\n${YELLOW}⚠️ Şüpheli dosyalar var, incelenmeli${NC}"
else
    echo -e "\n${GREEN}✅ Rkhunter: Sistem temiz, rootkit bulunamadı!${NC}"
fi

echo ""
echo -e "${CYAN}$SEPARATOR${NC}"
sleep 2

# =============================================
# 🦠 AŞAMA 4: CLAMAV DERİN VİRÜS TARAMASI
# =============================================
echo -e "\n${BOLD}${RED}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${RED}║  AŞAMA 4/4: CLAMAV DERİN VİRÜS TARAMASI 🦠           ║${NC}"
echo -e "${BOLD}${RED}╚══════════════════════════════════════════════════════╝${NC}"

echo -e "\n${YELLOW}🦠 Tam sistem virüs taraması başlatılıyor...${NC}"
echo -e "${YELLOW}   Bu işlem uzun sürebilir (disk boyutuna bağlı 10-60 dk)${NC}"

# Tarama hedeflerini göster
echo -e "\n${WHITE}📂 TARAMA HEDEFLERİ:${NC}"
echo -e "  🔍 /home - Kullanıcı dosyaları"
echo -e "  🔍 /tmp  - Geçici dosyalar"
echo -e "  🔍 /var/tmp - Sistem geçici dosyaları"

# Toplam taranacak dosya sayısını tahmin et
echo -e "\n${CYAN}📏 Taranacak veri boyutu hesaplanıyor...${NC}"
TOTAL_SIZE=$(du -sh /home /tmp /var/tmp 2>/dev/null | awk '{sum+=$1} END {print sum}' || echo "hesaplanamadı")
echo -e "  📏 Yaklaşık boyut: ${WHITE}$TOTAL_SIZE${NC}"

echo -e "\n${WHITE}$SEPARATOR${NC}"
echo -e "${RED}🦠 TARAMA BAŞLIYOR... (virüslü dosyalar OTOMATİK SİLİNECEK)${NC}"
echo -e "${WHITE}$SEPARATOR${NC}"

# ClamAV taramasını başlat ve canlı izle
CLAMAV_TEMP="/tmp/clamav_live_$$.log"

clamscan -r /home /tmp /var/tmp \
    --remove=yes \
    --max-filesize=2000M \
    --max-scansize=2000M \
    --exclude-dir="^/sys" \
    --exclude-dir="^/dev" \
    --exclude-dir="^/proc" \
    --infected \
    --bell \
    2>&1 | tee "$CLAMAV_TEMP" | while IFS= read -r line; do
    
    # Her satırı önemine göre renklendir
    if echo "$line" | grep -qi "FOUND\|INFECTED\|VIRUS"; then
        echo -e "  ${RED}🚨 VİRÜS BULUNDU: $line${NC}" | tee -a "$AV_LOG"
        # Alarm sesi için ekstra uyarı
        echo -e "\a"
    elif echo "$line" | grep -qi "scanning\|\.\.\."; then
        # Dosya adını kısalt
        SHORT_LINE=$(echo "$line" | sed 's/\(.\{70\}\).*/\1.../')
        printf "\r  ${CYAN}🔍 %s${NC}" "$SHORT_LINE"
    elif echo "$line" | grep -qi "error\|cannot\|permission denied"; then
        echo -e "  ${YELLOW}⚠️ $line${NC}"
    elif echo "$line" | grep -qi "summary\|scanned\|infected\|known"; then
        echo -e "  ${WHITE}📊 $line${NC}"
    elif echo "$line" | grep -qi "removed\|deleted"; then
        echo -e "  ${RED}🗑️  $line${NC}"
    fi
done

# Son satırı yeni satıra al
echo ""

# Tam logu kaydet
cp "$CLAMAV_TEMP" "$CLAMAV_LOG"
rm -f "$CLAMAV_TEMP"

# =============================================
# 📊 CLAMAV SONUÇ ANALİZİ
# =============================================
echo -e "\n${WHITE}📊 CLAMAV SONUÇ ANALİZİ:${NC}"
echo -e "${CYAN}$SEPARATOR${NC}"

if [ -f "$CLAMAV_LOG" ]; then
    SCANNED=$(grep "Scanned files:" "$CLAMAV_LOG" | awk '{print $NF}' | tail -1)
    INFECTED=$(grep "Infected files:" "$CLAMAV_LOG" | awk '{print $NF}' | tail -1)
    REMOVED=$(grep -c "Removed" "$CLAMAV_LOG" 2>/dev/null || echo "0")
    SCAN_TIME=$(grep "Time:" "$CLAMAV_LOG" | awk '{print $2, $3}' | tail -1)
    DATA_SCANNED=$(grep "Data scanned:" "$CLAMAV_LOG" | awk '{print $3, $4}' | tail -1)
    
    echo -e "  📂 Dosya tarandı:   ${WHITE}${SCANNED:-N/A}${NC}"
    echo -e "  💾 Veri tarandı:    ${WHITE}${DATA_SCANNED:-N/A}${NC}"
    echo -e "  ⏱️  Tarama süresi:   ${WHITE}${SCAN_TIME:-N/A}${NC}"
    echo -e "  🦠 Virüs bulunan:   ${RED}${INFECTED:-0}${NC}"
    echo -e "  🗑️  Silinen dosya:   ${RED}${REMOVED:-0}${NC}"
    
    # Virüs detayları
    if [ "${INFECTED:-0}" -gt 0 ]; then
        echo -e "\n${RED}╔══════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║ 🚨 VİRÜS BULUNDU VE TEMİZLENDİ!                       ║${NC}"
        echo -e "${RED}╚══════════════════════════════════════════════════════╝${NC}"
        
        echo -e "\n${RED}Bulunan virüsler:${NC}"
        grep "FOUND" "$CLAMAV_LOG" 2>/dev/null | while read line; do
            VIRUS_NAME=$(echo "$line" | awk -F': ' '{print $NF}')
            FILE_NAME=$(echo "$line" | awk -F': ' '{print $1}')
            echo -e "  ${RED}🦠 $VIRUS_NAME${NC}"
            echo -e "     ${WHITE}Dosya: $FILE_NAME${NC}"
        done
    elif [ "${INFECTED:-0}" -eq 0 ] && [ -n "$SCANNED" ]; then
        echo -e "\n${GREEN}✅ ClamAV: Sistem temiz, virüs bulunamadı!${NC}"
    fi
fi

echo ""
echo -e "${CYAN}$SEPARATOR${NC}"

# =============================================
# 🏆 NİHAİ ÖZET
# =============================================
END_TIME=$(date +%s)
SURECE=$(($END_TIME - $START_TIME))
DAKIKA=$((SURECE / 60))
SANIYE=$((SURECE % 60))

echo -e "\n${BOLD}${GREEN}$BOX_TOP${NC}"
echo -e "${BOLD}${GREEN}$BOX_MID 🏆 ANTİVİRÜS TARAMASI TAMAMLANDI${NC}"
echo -e "${BOLD}${GREEN}$BOX_BOT${NC}"

echo -e "\n${WHITE}⏱️  TOPLAM SÜRE: ${DAKIKA} dakika ${SANIYE} saniye${NC}"
echo -e "${CYAN}$SEPARATOR${NC}"

echo -e "\n${WHITE}📊 GENEL ÖZET:${NC}"

# ClamAV özet
if [ -f "$CLAMAV_LOG" ]; then
    INFECTED=$(grep "Infected files:" "$CLAMAV_LOG" | awk '{print $NF}' | tail -1)
    if [ "${INFECTED:-0}" -eq 0 ]; then
        echo -e "  ${GREEN}✅ ClamAV: Temiz${NC}"
    else
        echo -e "  ${RED}🚨 ClamAV: $INFECTED virüs bulundu ve silindi${NC}"
    fi
fi

# Rkhunter özet
if [ -f "$RKHUNTER_LOG" ]; then
    ROOTKIT_COUNT=$(grep -ci "rootkit found" "$RKHUNTER_LOG" 2>/dev/null || echo "0")
    WARNING_COUNT=$(grep -c "Warning" "$RKHUNTER_LOG" 2>/dev/null || echo "0")
    
    if [ "$ROOTKIT_COUNT" -eq 0 ] && [ "$WARNING_COUNT" -eq 0 ]; then
        echo -e "  ${GREEN}✅ Rkhunter: Temiz${NC}"
    elif [ "$ROOTKIT_COUNT" -gt 0 ]; then
        echo -e "  ${RED}🚨 Rkhunter: ROOTKIT BULUNDU!${NC}"
    else
        echo -e "  ${YELLOW}⚠️ Rkhunter: $WARNING_COUNT uyarı (normal olabilir)${NC}"
    fi
fi

echo -e "\n${WHITE}📂 RAPOR DOSYALARI:${NC}"
echo -e "  📄 Genel log:     ${CYAN}$AV_LOG${NC}"
echo -e "  📄 Rkhunter log:  ${CYAN}$RKHUNTER_LOG${NC}"
echo -e "  📄 ClamAV log:    ${CYAN}$CLAMAV_LOG${NC}"

# Eski log temizliği
echo -e "\n${YELLOW}🗑️  30 günden eski loglar temizleniyor...${NC}"
DELETED=$(find "$LOG_DIR" -name "antivirus_*.log" -o -name "rkhunter_*.log" -o -name "clamav_*.log" -mtime +30 -delete -print 2>/dev/null | wc -l)
echo -e "${GREEN}✅ $DELETED eski log silindi${NC}"

echo -e "\n${GREEN}🏁 ANTİVİRÜS TARAMASI BAŞARIYLA TAMAMLANDI!${NC}"
echo -e "${GREEN}   Sistem güvende, Kale nöbette! 🛡️${NC}"
echo ""
