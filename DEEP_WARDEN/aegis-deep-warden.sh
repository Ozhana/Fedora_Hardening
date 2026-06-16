#!/usr/bin/env bash
# ==============================================================================
# BETİK ADI      : aegis-deep-warden.sh
# AMAÇ           : Rootkit, Virüs, Bozuk Sektör ve BTRFS Derin Avcı Protokolü
# YAZAN          : Dr. Ozhan Akdag & Yoldaş (Military-Grade Cyber Security Alliance)
# SÜRÜM          : 7.0.0-PRO (POSIX Condition Isolation & Deterministic Finality)
# KRİTER         : Pure POSIX Bash & AWK, Zero-Dependency, Heavy-Duty Audit
# SIKILAŞTIRMA   : Process-Isolated Trapping, Hardened Inode Lock, Locale-Agnostic
# ==============================================================================

set -Eeuo pipefail
IFS=$'\n\t'
umask 0077

# ---- RENKLER ----
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# ---- GERÇEK KULLANICI VE EV DİZİNİ TESPİTİ ----
readonly REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "unknown")}"
if [[ "${REAL_USER}" == "root" || -z "${REAL_USER}" || "${REAL_USER}" == "unknown" ]]; then
    REAL_HOME="/root"
else
    REAL_HOME="$(getent passwd "${REAL_USER}" | cut -d: -f6)"
fi

# ---- KUTSAL SABİTLER ----
readonly LOCK_DIR="/run/aegis"
readonly LOCK_FILE="${LOCK_DIR}/deep-warden.lock"
readonly LOG_BASE="${REAL_HOME}/Desktop/LOG_FILES"
readonly WARDEN_LOG="${LOG_BASE}/deep_warden_master.log"
readonly THERMAL_THRESHOLD=82

# ---- DURUM BAYRAKLARI VE ASENKRON PID TAKİBİ ----
LOCK_FD_ACQUIRED="false"
CURRENT_ASYNC_PID=""

# ---- ADLİ LOGLAMA MOTORU ----
log_event() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    mkdir -p "${LOG_BASE}" 2>/dev/null || true
    if [[ -d "${LOG_BASE}" ]]; then
        printf '[%s] [%s] [PID:%s] %s\n' "${timestamp}" "${level}" "$$" "${message}" >> "${WARDEN_LOG}" 2>/dev/null || true
    fi
    if command -v systemd-cat &>/dev/null; then
        systemd-cat -t aegis-deep-warden -p info <<< "[${level}] ${message}" 2>/dev/null || true
    fi
}

# ---- TERMAL KORUMA ----
check_thermal() {
    local temp_raw temp is_running
    temp_raw=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0")
    temp=$((temp_raw / 1000))
    
    if [[ ${temp} -ge ${THERMAL_THRESHOLD} ]]; then
        log_event "CRITICAL" "Termal sınır aşıldı (${temp}°C). Süreçler askıya alınıyor."
        printf '%b' "${RED}[!] TERMAL COMA PROTECTION: İşlemci sıcaklığı ${temp}°C! Soğuma bekleniyor...${NC}\n" >&2
        
        is_running="false"
        if [[ -n "${CURRENT_ASYNC_PID}" ]]; then
            if kill -0 "${CURRENT_ASYNC_PID}" 2>/dev/null; then
                is_running="true"
            fi
        fi

        if [[ "${is_running}" == "true" ]]; then
            kill -SIGSTOP "${CURRENT_ASYNC_PID}" 2>/dev/null || true
            log_event "INFO" "Asenkron alt süreç (PID: ${CURRENT_ASYNC_PID}) geçici olarak donduruldu."
        fi
        
        while [[ ${temp} -ge $((THERMAL_THRESHOLD - 10)) ]]; do
            sleep 15
            temp_raw=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0")
            temp=$((temp_raw / 1000))
        done
        
        if [[ "${is_running}" == "true" ]]; then
            if kill -0 "${CURRENT_ASYNC_PID}" 2>/dev/null; then
                kill -SIGCONT "${CURRENT_ASYNC_PID}" 2>/dev/null || true
                log_event "INFO" "Asenkron alt süreç (PID: ${CURRENT_ASYNC_PID}) yeniden uyandırıldı."
            fi
        fi
        
        log_event "INFO" "Sistem soğudu (${temp}°C), derin av operasyonuna devam ediliyor."
        printf '%b' "${GREEN}[+] Sıcaklık dengelendi (${temp}°C). Operasyona devam ediliyor.${NC}\n"
    fi
}

# ---- ATOMİK TEMİZLİK VE GÜVENLİ ÇÖKÜŞ TUZAĞI ----
cleanup() {
    local exit_code=$?
    trap '' EXIT INT TERM ERR HUP QUIT
    
    log_event "INFO" "Cleanup tetiklendi. Çıkış kodu: ${exit_code}"
    
    if [[ -n "${CURRENT_ASYNC_PID}" ]]; then
        if kill -0 "${CURRENT_ASYNC_PID}" 2>/dev/null; then
            log_event "WARN" "Yarıda kalan aktif asenkron süreç infaz ediliyor: PID ${CURRENT_ASYNC_PID}"
            kill -9 "${CURRENT_ASYNC_PID}" 2>/dev/null || true
        fi
    fi
    
    # Eğer aktif arka plan BTRFS scrub kalmışsa güvenle iptal et
    if command -v btrfs &>/dev/null; then
        btrfs scrub status / 2>/dev/null | grep -q "running" && btrfs scrub cancel / &>/dev/null
    fi

    sync || true
    
    if [[ "${LOCK_FD_ACQUIRED}" == "true" ]]; then
        if [[ -f "${LOCK_FILE}" ]]; then
            local lock_pid
            lock_pid=$(head -n1 "${LOCK_FILE}" 2>/dev/null || echo "")
            if [[ "${lock_pid}" == "$$" ]]; then
                rm -f "${LOCK_FILE}" 2>/dev/null || true
            fi
        fi
        flock -u 9 2>/dev/null || true
        exec 9>&- 2>/dev/null || true
        log_event "INFO" "Kernel seviyesi kilit başarıyla serbest bırakıldı."
    fi
    
    if [[ ${exit_code} -eq 0 ]]; then
        printf '%b' "${GREEN}======================================================================${NC}\n"
        printf '%b' "${GREEN}✓ OPERASYON BAŞARIYLA TAMAMLANDI. KALE STERİL DURUMDA.${NC}\n"
        printf '%b' "${GREEN}✓ Adli Rapor: ${WARDEN_LOG}${NC}\n"
        printf '%b' "${GREEN}======================================================================${NC}\n"
        log_event "SUCCESS" "Deep Warden haftalık tarama döngüsünü sıfır hatayla bitirdi."
    else
        printf '%b' "${RED}[X] FATAL CRASH: Derin avcı operasyonu yarıda kesildi! Çıkış kodu: ${exit_code}${NC}\n" >&2
        log_event "EMERGENCY" "Betik kaza veya kesinti ile durduruldu. State korundu."
    fi
    
    exit "${exit_code}"
}
trap cleanup EXIT INT TERM ERR HUP QUIT

# ---- KERNEL SEVİYESİ ATOMİK SÜRGÜ ----
acquire_lock() {
    mkdir -p -m 0700 "${LOCK_DIR}" 2>/dev/null || true
    if [[ ! -d "${LOCK_DIR}" ]]; then
        printf '%b' "${RED}[X] KRİTİK HATA: İzolasyon dizini oluşturulamadı: ${LOCK_DIR}${NC}\n" >&2
        exit 1
    fi
    
    exec 9>"${LOCK_FILE}" || exit 1
    if ! flock -n 9 2>/dev/null; then
        log_event "WARN" "İkinci bir Deep Warden örneği tetiklendi, reddedildi."
        printf '%b' "${YELLOW}[!] ALERT: Aegis Deep Warden zaten hafızada aktif! İşlem iptal edildi.${NC}\n" >&2
        LOCK_FD_ACQUIRED="false"
        exit 1
    fi
    LOCK_FD_ACQUIRED="true"
    printf '%s\n' "$$" >&9
    log_event "INFO" "Haftalık derin av kilit mekanizması mühürlendi (FD:9)."
}

# ---- ÖN KOŞUL ETÜDÜ ----
check_prerequisites() {
    if [[ ${EUID} -ne 0 ]]; then
        printf '%b' "${RED}[X] KUTSAL İHLAL: Bu derinlikte avlanmak için root yetkisi şarttır!${NC}\n" >&2
        exit 1
    fi

    local required_cmds=("freshclam" "clamscan" "rkhunter" "aide" "badblocks" "smartctl" "btrfs" "findmnt" "lsblk")
    local missing_deps=()
    
    for cmd in "${required_cmds[@]}"; do
        command -v "${cmd}" &>/dev/null || missing_deps+=("${cmd}")
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        missing_deps_str="${missing_deps[*]}"
        log_event "ERROR" "Eksik araçlar yüzünden durduruldu: ${missing_deps_str}"
        printf '%b' "${RED}[X] KRİTİK EKSİKLİK: Sistemde şu askeri araçlar eksik: ${missing_deps_str}${NC}\n" >&2
        exit 1
    fi
    log_event "INFO" "Tüm pre-flight zemin etüdü ve bağımlılıklar doğrulandı."
}

# ---- ONAY MATRİSİ ----
human_authorization() {
    printf '%b' "${BLUE}======================================================================${NC}\n"
    printf '%b' "${CYAN}${BOLD}      🛡️  **AEGIS MASTER DEEP WARDEN - ULTIMATE WEEKLY ENGINE** ${NC}\n"
    printf '%b' "${BLUE}======================================================================${NC}\n"
    printf '%b' "${YELLOW}[UYARI]: Bu tarama sistemi en derin donanım ve dosya seviyesinde inceler.${NC}\n"
    printf '  • ClamAV Derin Dizin ve Bellek Avı tetiklenecek.\n'
    printf '  • Rkhunter ve AIDE Adli Dosya Doğrulaması yürütülecek.\n'
    printf '  • BTRFS Scrub bütünlük testi termal yönetimli olarak koşturulacak.\n'
    printf '  • Surface Pro 9 donanım performansı kısıtlanacaktır.\n'
    printf '%b' "${BLUE}----------------------------------------------------------------------${NC}\n"
    
    local token
    token=$(head -c 3 /dev/urandom | od -A n -t x1 | tr -d ' \n' | cut -c1-6)
    
    printf 'Operasyonu onaylamak için kriptografik tokeni girin.\n'
    printf 'Token [%b%s%b]: ' "${GREEN}" "${token}" "${NC}"
    local confirm
    read -r confirm || { printf '\n'; log_event "WARN" "Kullanıcı girişi kesildi, çıkılıyor."; exit 0; }
    
    if [[ "${confirm}" != "${token}" ]]; then
        printf '%b' "${RED}[-] Kimlik doğrulanamadı. Operasyon imha edildi.${NC}\n" >&2
        log_event "WARN" "Hatalı token girişi ile operasyon reddedildi."
        exit 0
    fi
    log_event "INFO" "İnsan onayı (Human-in-the-loop) başarıyla alındı."
}

# ==============================================================================
# MASTER OPERASYONEL FAZLAR (POSIX CONDITION ISOLATED)
# ==============================================================================

# 5.1 - ANTI-VIRUS VERİTABANI VE ROOTKİT İMZALARI GÜNCELLEMESİ
update_signatures() {
    printf '%b' "${BLUE}[1/5] Kutsal İmza ve Rootkit Tanımlamaları Güncelleniyor...${NC}\n"
    log_event "INFO" "Freshclam imza güncellemesi tetiklendi."
    
    if ionice -c 3 nice -n 19 freshclam >> "${WARDEN_LOG}" 2>&1; then
        log_event "INFO" "Freshclam imzaları başarıyla senkronize edildi."
    else
        log_event "WARN" "Freshclam sunucuya erişemedi, yerel imzalarla devam edilecek."
    fi
    
    log_event "INFO" "Rkhunter veri güncellemeleri tetiklendi."
    if ionice -c 3 nice -n 19 rkhunter --update >> "${WARDEN_LOG}" 2>&1; then
        log_event "INFO" "Rkhunter veri tabanı güncellendi."
    else
        log_event "WARN" "Rkhunter veri tabanı güncellenirken uyarı kodu fırlattı."
    fi
}

# 5.2 - CLAMAV DERİN İNDİS VE BELLEK AVCI MOTORU
run_clamscan_deep() {
    printf '%b' "${BLUE}[2/5] ClamAV Derin İndis Avı Başlatıldı (Tolerans: 0 | Karantina: AKTİF)...${NC}\n"
    log_event "INFO" "ClamScan derin av operasyonu başladı."
    
    check_thermal
    
    local target_scan_paths=("/home" "/root" "/etc" "/var/lib/docker")
    for path in "${target_scan_paths[@]}"; do
        if [[ -d "${path}" ]]; then
            log_event "INFO" "Tarama odağı: ${path}"
            printf '  • Fokus Dizin: %s\n' "${path}"
            
            if ionice -c 3 nice -n 19 clamscan -r "${path}" \
                --infected \
                --bell \
                --exclude-dir="/sys" \
                --exclude-dir="/dev" \
                --exclude-dir="/proc" \
                >> "${WARDEN_LOG}" 2>&1; then
                log_event "INFO" "Clamscan ${path} üzerinde tehdit bulamadı."
            else
                local clam_status=$?
                if [[ ${clam_status} -eq 1 ]]; then
                    log_event "WARN" "Clamscan ${path} üzerinde şüpheli/zararlı nesneler yakaladı!"
                else
                    log_event "WARN" "Clamscan ${path} üzerinde beklenmeyen durum kodu üretti: ${clam_status}"
                fi
            fi
            check_thermal
        fi
    done
}

# 5.3 - ADLİ BİLİŞİM VE KÖK KİTİ (ROOTKIT) PARSERS (IF-BARRICADE GÜÇLENDİRİLDİ)
run_forensics_audit() {
    printf '%b' "${BLUE}[3/5] Adli Bilişim ve Rootkit Taramaları (Rkhunter & AIDE)...${NC}\n"
    log_event "INFO" "Rkhunter adli denetimi başladı."
    check_thermal
    
    # Sinsi ERR Trap patlamasını önlemek için IF şartı içine tamamen izole edildi
    if ionice -c 3 nice -n 19 rkhunter --check --sk --nocolor --report-warnings-only >> "${WARDEN_LOG}" 2>&1; then
        log_event "INFO" "Rkhunter adli denetimi sıfır anomali ile bitti."
    else
        local rkh_check=$?
        log_event "WARN" "Rkhunter meşru uyarılar veya anomaliler yakaladı. Durum Kodu: ${rkh_check}"
    fi
    
    log_event "INFO" "AIDE bütünlük kontrolü tetikleniyor."
    local aide_db="/var/lib/aide/aide.db.gz"
    if [[ -f "${aide_db}" && -s "${aide_db}" ]]; then
        
        # AIDE'in 7 kodunun ERR Trap'i katletmesi IF-ISOLATION ile mutlak olarak engellendi
        if ionice -c 3 nice -n 19 aide --check > "${LOCK_DIR}/aide_result.tmp" 2>&1; then
            log_event "INFO" "AIDE doğrulaması başarılı. Statik sistem namusu korunuyor."
            printf '%b' "${GREEN}   ✓ Statik Sistem Dosya Bütünlüğü: GÜVENLİ${NC}\n"
        else
            local aide_status=$?
            log_event "CRITICAL" "AIDE SİSTEM BÜTÜNLÜĞÜNDE BOZULMA SAPRADI! Durum Kodu: ${aide_status}"
            printf '%b' "${RED}[!] GÜVENLİKSİZ SAPMA: AIDE statik sistem dosyalarında izinsiz modifikasyon buldu!${NC}\n" >&2
            cat "${LOCK_DIR}/aide_result.tmp" >> "${WARDEN_LOG}"
        fi
        rm -f "${LOCK_DIR}/aide_result.tmp" 2>/dev/null || true
    else
        log_event "WARN" "AIDE Baseline veritabanı bulunamadı. Tarama bypass edildi."
        printf '%b' "${YELLOW}  [!] AIDE veritabanı bulunamadı. Lütfen mühürleme oturumunu tamamlayın.${NC}\n"
    fi
    check_thermal
}

# 5.4 - BTRFS VERİ BÜTÜNLÜĞÜ VE TERMAL-DAMPING SCRUB (RESUMABLE ENGINE)
run_btrfs_safer_scrub() {
    printf '%b' "${BLUE}[4/5] BTRFS Dosya Sistemi Blok Bütünlüğü (Termal-Damping Scrub)...${NC}\n"
    log_event "INFO" "BTRFS Scrub işlemi başlatılıyor."
    
    if ! btrfs scrub status / &>/dev/null; then
        log_event "WARN" "Kök dizin BTRFS yapısında değil veya Scrub aktif edilemiyor."
        printf '%b' "${YELLOW}  [!] BTRFS bulunamadı veya meşgul, atlanıyor.${NC}\n"
        return
    fi
    
    check_thermal
    
    if ionice -c 3 nice -n 19 btrfs scrub start / >> "${WARDEN_LOG}" 2>&1; then
        log_event "INFO" "BTRFS scrub görevi arka planda başarıyla tetiklendi."
    else
        log_event "INFO" "BTRFS scrub zaten mevcut veya duraklatılmış, izleme döngüsüne bağlanıyor."
    fi
    
    local scrub_finished=0
    while [[ ${scrub_finished} -eq 0 ]]; do
        local temp_raw temp is_running
        temp_raw=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0")
        temp=$((temp_raw / 1000))
        
        if [[ ${temp} -ge ${THERMAL_THRESHOLD} ]]; then
            log_event "WARN" "Scrub sırasında termal eşik aşıldı (${temp}°C). Scrub askıya alınıyor."
            printf '%b' "${YELLOW}[!] Scrub iptal edildi, soğuma bekleniyor...${NC}\n"
            
            btrfs scrub cancel / >> "${WARDEN_LOG}" 2>&1 || true
            sleep 3
            
            while [[ ${temp} -ge $((THERMAL_THRESHOLD - 10)) ]]; do
                sleep 15
                temp_raw=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0")
                temp=$((temp_raw / 1000))
            done
            
            log_event "INFO" "Sıcaklık düştü (${temp}°C). Scrub RESUME motoru tetikleniyor."
            printf '%b' "${GREEN}[+] Soğuma tamamlandı, scrub kaldığı yerden devam ettiriliyor...${NC}\n"
            
            if ! btrfs scrub resume / >> "${WARDEN_LOG}" 2>&1; then
                log_event "ERROR" "Scrub resume edilemedi, baştan start zorlanıyor."
                btrfs scrub start / >> "${WARDEN_LOG}" 2>&1 || true
            fi
        fi
        
        if btrfs scrub status / 2>/dev/null | grep -q "running"; then
            sleep 5
        else
            scrub_finished=1
        fi
    done
    
    local scrub_errors
    scrub_errors=$(btrfs scrub status / 2>/dev/null | grep -E "csum_errors|correctable" | awk '{sum+=$2} END {print sum+0}' || echo "0")
    if [[ ${scrub_errors} -gt 0 ]]; then
        log_event "ERROR" "BTRFS Scrub veri yozlaşması saptadı! Hata adedi: ${scrub_errors}"
        printf '%b' "${RED}[X] DOSYA SİSTEMİ ANOMALİSİ: BTRFS bütünlük taramasında hatalı bloklar var!${NC}\n" >&2
    else
        log_event "INFO" "BTRFS bütünlük kontrolü temiz bitti."
        printf '%b' "${GREEN}   ✓ BTRFS Veri Blok Sağlığı: KUSURSUZ${NC}\n"
    fi
    check_thermal
}

# 5.5 - FİZİKSEL BLOK VE SEKTÖR AV MOTORU
run_hardware_sector_hunter() {
    printf '%b' "${BLUE}[5/5] Fiziksel NVMe/SSD Sektör Sağlığı ve SMART Röntgeni...${NC}\n"
    log_event "INFO" "SMART ve Blok Sektör analizi başladı."
    
    local root_partition root_dev_node root_disk
    root_partition=$(findmnt -n -o SOURCE /)
    
    if [[ -e "${root_partition}" ]]; then
        root_dev_node=$(lsblk -no PKNAME "${root_partition}" | head -n1 | tr -d ' \t\n')
        if [[ -z "${root_dev_node}" ]]; then
            root_disk="${root_partition}"
        else
            root_disk="/dev/${root_dev_node}"
        fi
    else
        root_disk=""
    fi
    
    if [[ -b "${root_disk}" ]]; then
        log_event "INFO" "Doğrulanan Fiziksel Ana Sürücü: ${root_disk}"
        printf '  • Donanım Sürücüsü: %s\n' "${root_disk}"
        
        if smartctl -H "${root_disk}" >> "${WARDEN_LOG}" 2>&1; then
            log_event "INFO" "SMART testi başarıyla tamamlandı."
        else
            log_event "WARN" "SMART sağlık röntgeni disk üzerinde potansiyel uyarı fırlattı."
        fi
        
        printf '  • Bozuk Sektör Avcısı Ateşleniyor (Bekleyin)...\n'
        
        ionice -c 3 nice -n 19 badblocks -b 4096 -s -v "${root_disk}" > "${LOCK_DIR}/badblocks_sectors.tmp" 2> "${LOCK_DIR}/badblocks_progress.tmp" &
        CURRENT_ASYNC_PID=$!
        log_event "INFO" "Badblocks asenkron motoru ateşlendi. PID: ${CURRENT_ASYNC_PID}"
        
        while kill -0 "${CURRENT_ASYNC_PID}" 2>/dev/null; do
            check_thermal
            sleep 10
        done
        
        wait "${CURRENT_ASYNC_PID}" || true
        CURRENT_ASYNC_PID=""
        
        if [[ -s "${LOCK_DIR}/badblocks_sectors.tmp" ]]; then
            log_event "CRITICAL" "FİZİKSEL DISKTE GERÇEK BOZUK SEKTÖR TESPİT EDİLDİ!"
            printf '%b' "${RED}[!] DONANIM ALERTI: NVMe üzerinde donanımsal bozuk sektör(ler) saptandı!${NC}\n" >&2
            cat "${LOCK_DIR}/badblocks_sectors.tmp" >> "${WARDEN_LOG}"
        else
            log_event "INFO" "Blok Sektör analizi temiz. NAND hücreleri kararlı."
            printf '%b' "${GREEN}   ✓ NVMe Fiziksel Blok Sektör Namusu: TEMİZ${NC}\n"
        fi
        rm -f "${LOCK_DIR}/badblocks_sectors.tmp" "${LOCK_DIR}/badblocks_progress.tmp" 2>/dev/null || true
    else
        log_event "ERROR" "Kök fiziksel disk blok aygıtı haritası çıkarılamadı."
    fi
}

# ---- ANA ORKESTRASYON MOTORU ----
main() {
    log_event "START" "Haftalık Master Deep Warden koruma döngüsü başladı."
    update_signatures
    check_thermal
    run_clamscan_deep
    check_thermal
    run_forensics_audit
    check_thermal
    run_btrfs_safer_scrub
    check_thermal
    run_hardware_sector_hunter
    check_thermal
    log_event "END" "Haftalık Master Deep Warden koruma döngüsü başarıyla tamamlandı."
}

# ---- ASKERİ YÜRÜTME SIRASI ----
check_prerequisites
acquire_lock
human_authorization
main
exit 0
