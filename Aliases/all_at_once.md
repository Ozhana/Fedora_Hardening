just copy past the followings at the end of ~/.bashrc file

```bash
alias rm='rm -I --preserve-root'
alias cp='cp -ia'
alias mv='mv -iv'
alias mkdir='mkdir -pv'
alias chown='chown --preserve-root'
alias ports='ss -tulpn | awk '\''NR>1 {printf "%-10s %-25s %s\n", $1, $5, $7}'\'''
alias memstat='free -b | awk '\''NR==2 {printf "RAM Tüketimi: %.2f%%\n", $3*100/$2}'\'''
alias diskstat='df -B1 / | awk '\''NR==2 {printf "Root FS Tüketimi: %.2f%%\n", $3*100/$2}'\'''
alias loadavg='cat /proc/loadavg | awk '\''{printf "Yük (1/5/15dk): %s | %s | %s\n", $1, $2, $3}'\'''
alias zombies='ps axo stat,ppid,pid,comm | awk '\''$1=="Z" {printf "ZOMBIE PID: %s (Parent: %s) -> %s\n", $3, $2, $4}'\'''

_secure_sysupdate() (
    set -Eeuo pipefail
    IFS=$'\n\t'
    if ! command -v dnf >/dev/null 2>&1; then echo >&2 "[FATAL] 'dnf' bulunamadı."; exit 1; fi
    local lock_fd=9; local lock_file="/tmp/secure_sysupdate.lock"
    eval "exec $lock_fd> \"$lock_file\""
    if ! flock -n $lock_fd; then echo >&2 "[WARN] Güncelleme kilitli."; exit 1; fi
    trap 'eval "exec $lock_fd>&-"' EXIT INT TERM
    sudo dnf upgrade --refresh -y
)
alias sysupdate='_secure_sysupdate'

_secure_fw_audit() (
    set -Eeuo pipefail
    IFS=$'\n\t'
    if ! command -v firewall-cmd >/dev/null 2>&1; then echo >&2 "[FATAL] 'firewall-cmd' bulunamadı."; exit 1; fi
    sudo firewall-cmd --list-all | awk -F': ' 'NF==2 {printf "%-20s : %s\n", $1, $2}'
)
alias fwaudit='_secure_fw_audit'

_secure_service_check() (
    set -Eeuo pipefail
    IFS=$'\n\t'
    local svc="${1:-}"
    if [[ -z "$svc" ]]; then echo >&2 "[FATAL] Hedef servis belirtilmedi."; exit 1; fi
    systemctl is-active "$svc" >/dev/null 2>&1 && echo "[OK] $svc UP" || { echo >&2 "[ERROR] $svc DOWN"; exit 1; }
)
alias svc-check='_secure_service_check'

_secure_clean_cache() (
    set -Eeuo pipefail
    IFS=$'\n\t'
    local lock_fd=8; local lock_file="/tmp/secure_cleancache.lock"
    eval "exec $lock_fd> \"$lock_file\""
    if ! flock -n $lock_fd; then echo >&2 "[WARN] Temizlik işlemi çalışıyor."; exit 1; fi
    trap 'eval "exec $lock_fd>&-"' EXIT INT TERM
    sudo dnf clean all >/dev/null && sudo journalctl --vacuum-time=7d >/dev/null
)
alias sysclean='_secure_clean_cache'

_secure_network_interfaces() (
    set -Eeuo pipefail
    IFS=$'\n\t'
    if ! command -v jq >/dev/null 2>&1; then echo >&2 "[FATAL] 'jq' kurulu değil."; exit 1; fi
    ip -json addr show | jq -r '.[].ifname + " " + (.[].addr_info[]? | select(.family=="inet") | .local)' | awk 'NF==2 {printf "Interface: %-10s IPv4: %s\n", $1, $2}'
)
alias netif='_secure_network_interfaces'

alias usb-ac='sudo modprobe usb-storage && sudo modprobe uas && echo "🔓 [SİSTEM] USB Depolama Modülleri Yüklendi. Veri akışı aktif."'
alias usb-kapat='sudo modprobe -r usb-storage uas 2>/dev/null && echo "🔒 [SİSTEM] USB Depolama Kilitlendi. Sürücüler hafızadan güvenle kazındı!" || echo "[!] Kapatılamadı: Cihaz şu an kullanımda olabilir."'

secure-wipe() {
    if [ -z "${1:-}" ]; then 
        echo "[HATA] Yok edilecek dosyayı belirtmelisin! Kullanım: secure-wipe <dosya_adi>" >&2
        return 1
    fi
    echo "🔥 [GÜVENLİK] '$1' kriptografik olarak atomlarına ayrılıyor..."
    shred -u -z -n 3 "$1" && echo "[✔] İşlem başarılı. Veri kurtarma ihtimali: %0"
}

alias kilit-vur='sudo chattr +i'
alias kilit-ac='sudo chattr -i'
alias kilit-kontrol='lsattr'

rk-denetim() {
    echo "🛡️ [RKHUNTER] Adım 1: Rootkit imza veritabanı güncelleniyor (--update)..."
    sudo rkhunter --update

    echo -e "\n🔍 [RKHUNTER] Adım 2: Sistem taraması başlatılıyor..."
    sudo rkhunter --check --skip-keypress --rwo || true

    echo -e "\n======================================================================"
    echo "⚠️ DİKKAT: Yukarıdaki tarama sonuçlarını (Warnings) dikkatlice inceleyin."
    echo "Eğer bu uyarılar meşru bir sistem güncellemesinden kaynaklanıyorsa,"
    echo "sistemin bu yeni halini güvenli (Baseline) kabul edebiliriz."
    echo "======================================================================"
    
    read -r -p "Herhangi bir anomali YOKSA veritabanı mühürlensin mi? (--propupd) (yes/no): " ONAY

    if [[ "$ONAY" =~ ^(yes|y|Y|YES)$ ]]; then
        echo -e "\n⚙️ [RKHUNTER] Dosya özellikleri veritabanı güncelleniyor..."
        sudo rkhunter --propupd
        echo "✅ [BAŞARILI] Sistem dosyalarının yeni durumu 'Güvenli (Baseline)' olarak mühürlendi."
    else
        echo -e "\n🔒 [GÜVENLİK] İşlem iptal edildi. Baseline dondurulmuş durumda bırakıldı."
    fi
}

alias net-audit='echo "🔍 [SİSTEM] Açık portlar ve dinleyen süreçler taranıyor..." && sudo ss -tulpn | grep LISTEN'

data-sandbox() {
    echo "🧪 [SİSTEM] İzole Python Veri Laboratuvarı inşa ediliyor..."
    python3 -m venv venv --clear
    source venv/bin/activate
    echo "🔒 [GÜVENLİK] Global sistemden koptunuz. Paketler sadece bu dizine kurulacak."
}

alias ram-radar='echo "📊 [TELEMETRİ] En çok RAM tüketen ilk 10 süreç:" && ps axo rss,comm,pid | awk '\''{ sum+=$1; print $0 } END { printf "\nToplam Tüketim: %.2f GB\n", sum/1024/1024 }'\'' | sort -n | tail -n 11'
alias kernel-radar='echo "☢️ [KERNEL] Kritik donanım hataları taranıyor..." && sudo dmesg -T | grep --color=always -iE "error|warn|fail|killed|segfault|usb"'
alias git-rontgen='echo "🔍 [GİT] Değiştirilen satırların atomik röntgeni:" && git status -s -b && echo "---------------------------" && git diff --stat'
```
