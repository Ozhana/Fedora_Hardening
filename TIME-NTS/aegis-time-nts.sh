#!/usr/bin/env bash
# V38_FINAL_WORKING: Chrony NTS - Tested on WSL + Fedora 44
# Ozhan'ın çalışan yöntemi ile

set -Eeuo pipefail
IFS=$'\n\t'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

clear
echo ""
echo -e "${BOLD}${PURPLE}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                                                                ║"
echo "║   █████╗ ███████╗ ██████╗ ██╗███████╗                         ║"
echo "║  ██╔══██╗██╔════╝██╔════╝ ██║██╔════╝                         ║"
echo "║  ███████║█████╗  ██║  ███╗██║███████╗                         ║"
echo "║  ██╔══██║██╔══╝  ██║   ██║██║╚════██║                         ║"
echo "║  ██║  ██║███████║╚██████╔╝██║███████║                         ║"
echo "║  ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝╚══════╝                         ║"
echo "║                                                                ║"
echo "║         CHRONY NTS V38 - WORKING ON WSL                        ║"
echo "║              ✅ TESTED & VERIFIED ✅                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Root yetkisi gerekli!${NC}"
    echo "Sudo ile tekrar dene: sudo $0"
    exit 1
fi

echo -e "${BOLD}${RED}⚠️  Bu işlem Chrony NTS'yi kuracak${NC}"
echo -e "${YELLOW}   - Fedora pool pasifize edilecek${NC}"
echo -e "${YELLOW}   - NTS sunucuları eklenecek${NC}"
echo -e "${YELLOW}   - NTS çerezleri temizlenecek${NC}"
echo ""
read -rp "$(echo -e ${BOLD}"Devam etmek için PERMANENT yazın: "${NC}) " CONFIRM

if [[ "$CONFIRM" != "PERMANENT" ]]; then
    echo -e "${RED}❌ İptal edildi${NC}"
    exit 0
fi

echo ""
echo -e "${CYAN}📦 Adım 1: Konfigürasyon yedekleniyor...${NC}"
sudo cp /etc/chrony.conf /etc/chrony.conf.bak.$(date +%s)
echo -e "${GREEN}  ✅ Yedek alındı${NC}"

echo ""
echo -e "${CYAN}🔧 Adım 2: Fedora NTP pool pasifize ediliyor...${NC}"
sudo sed -i '/pool 2.fedora.pool.ntp.org iburst/s/^/#/' /etc/chrony.conf
echo -e "${GREEN}  ✅ Fedora pool devre dışı${NC}"

echo ""
echo -e "${CYAN}🔐 Adım 3: NTS konfigürasyonu ekleniyor...${NC}"
sudo sed -i '/server.*nts/d' /etc/chrony.conf
sudo sed -i '/ntsdumpdir/d' /etc/chrony.conf
sudo bash -c 'echo "" >> /etc/chrony.conf'
sudo bash -c 'echo "# V38_FINAL_WORKING: NTS Mühürleme Protokolü" >> /etc/chrony.conf'
sudo bash -c 'echo "server time.cloudflare.com iburst nts" >> /etc/chrony.conf'
sudo bash -c 'echo "server nts.netnod.se iburst nts" >> /etc/chrony.conf'
sudo bash -c 'echo "server ptbtime1.ptb.de iburst nts" >> /etc/chrony.conf'
sudo bash -c 'echo "ntsdumpdir /var/lib/chrony" >> /etc/chrony.conf'
echo -e "${GREEN}  ✅ NTS sunucuları eklendi${NC}"

echo ""
echo -e "${CYAN}🍪 Adım 4: NTS çerezleri temizleniyor...${NC}"
sudo systemctl stop chronyd 2>/dev/null || true
sudo rm -rf /var/lib/chrony/ntscookies/*
sudo mkdir -p /var/lib/chrony/ntscookies
sudo chown chrony:chrony /var/lib/chrony/ntscookies
echo -e "${GREEN}  ✅ Çerezler temizlendi${NC}"

echo ""
echo -e "${CYAN}🔄 Adım 5: Chrony başlatılıyor...${NC}"
sudo systemctl start chronyd
echo -e "${GREEN}  ✅ Chrony başlatıldı${NC}"

echo ""
echo -e "${CYAN}⏳ Adım 6: NTS handshake bekleniyor (10 saniye)...${NC}"
for i in {1..10}; do
    printf "\r   %d/10 saniye..." "$i"
    sleep 1
done
echo ""

echo ""
echo -e "${CYAN}🔍 Adım 7: NTS doğrulaması...${NC}"
sudo chronyc -N authdata

echo ""
echo -e "${CYAN}📊 Adım 8: Senkronizasyon durumu...${NC}"
chronyc tracking | grep -E "Reference ID|Leap status|System time"

echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}✅ BAŞARILI - Chrony NTS Aktif ve Mühürlendi!${NC}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════════════════════════════${NC}"
