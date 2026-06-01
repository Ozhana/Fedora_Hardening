# ENTERPRISE-GRADE .BASHRC HARDENING & TELEMETRY SUITE
## AUTHOR: Dr. Ozhan Akdag



1. Fail-Safe rm <br>
[TR] 3'ten fazla dosyayı veya kök dizini silerken etkileşimli onay isteyerek kazaları önler.<br>
[EN] Prevents accidents by requesting interactive confirmation when deleting more than 3 files or the root directory.<br><br>
```bash
alias rm='rm -I --preserve-root'
```

<br><br>
2. Fail-Safe cp<br>
[TR] Kopyalama sırasında metadata (izin, zaman damgası) verisini korur ve üzerine yazarken teyit ister.<br>
[EN] Preserves metadata (permissions, timestamps) during copying and requests confirmation before overwriting.2. Fail-Safe cp<br><br>
```bash
alias cp='cp -ia'
```
<br><br>
3. Fail-Safe mv<br>
[TR] Dosya taşırken üzerine yazma durumlarında etkileşimli teyit ister ve süreci ekrana basar.<br>
[EN] Requests interactive confirmation when overwriting during file moves and prints the process to the screen.<br><br>
```bash
alias mv='mv -iv'
```

<br><br>
4. Fail-Safe mkdir<br>
[TR] Eksik üst dizinleri otomatik oluşturur ve dizin halihazırda varsa hata üretmeyen idempotent bir yapı kurar.<br>
[EN] Automatically creates missing parent directories and establishes an idempotent structure that avoids errors if the directory exists.<br><br>
```bash
alias mkdir='mkdir -pv'
```
<br><br>
5. Fail-Safe chown<br>
[TR] Kök dizin (/) üzerinde kazara sahiplik değiştirme işlemlerini kernel seviyesinde engeller.<br>
[EN] Blocks accidental ownership modification operations on the root (/) directory at the kernel level.<br><br>
```bash
alias chown='chown --preserve-root'
```
<br><br>
6. Deterministik ports<br>
[TR] Sistemde dinlenen portları, körü körüne grep kullanmak yerine AWK ile kesin bir matris formatında ayrıştırır.<br>
[EN] Parses listening ports strictly into a matrix format using AWK instead of using blind grep.<br><br>
```bash
alias ports='ss -tulpn | awk '\''NR>1 {printf "%-10s %-25s %s\n", $1, $5, $7}'\'''
```

<br><br>
7. Deterministik memstat<br>
[TR] Bellek kullanımını byte seviyesinde okuyarak ondalıklı ve kesin bir tüketim yüzdesi hesaplar.<br>
EN] Reads memory usage at the byte level to calculate a precise decimal percentage of consumption.<br><br>
```bash
alias memstat='free -b | awk '\''NR==2 {printf "RAM Tüketimi: %.2f%%\n", $3*100/$2}'\'''
```
<br><br>
8. Deterministik diskstat<br>
[TR] Kök dizin kapasite tüketimini blok seviyesinde matematiksel bir yüzdeye dönüştürür.<br>
[EN] Converts the root directory capacity consumption into a mathematical percentage at the block level.<br><br>
```bash
alias diskstat='df -B1 / | awk '\''NR==2 {printf "Root FS Tüketimi: %.2f%%\n", $3*100/$2}'\'''
```
<br><br>

9. Deterministik loadavg<br>
[TR] CPU I/O bekleme kuyruğunun ham değerlerini doğrudan çekirdeğin (/proc) içinden okuyarak formatlar.<br>
[EN] Formats raw CPU I/O wait queue values by reading directly from the kernel space (/proc).<br><br>
```bash
alias loadavg='cat /proc/loadavg | awk '\''{printf "Yük (1/5/15dk): %s | %s | %s\n", $1, $2, $3}'\'''
```
<br><br>
10. Deterministik zombies<br>
[TR] Sistemde durum kodu (Z) olan askıda kalmış işlemleri üst-süreç (parent) kimlikleriyle birlikte avlar.<br>
[EN] Hunts down suspended processes with a state code of (Z) along with their parent process IDs.<br><br>
```bash
alias zombies='ps axo stat,ppid,pid,comm | awk '\''$1=="Z" {printf "ZOMBIE PID: %s (Parent: %s) -> %s\n", $3, $2, $4}'\'''
```

<br><br>
11. Kurumsal sysupdate<br>
[TR] DNF paket yöneticisini File Descriptor kilitleri ve alt-kabuk tuzaklarıyla (trap) koruyarak çifte çalışmayı engeller.<br>
[EN] Protects the DNF package manager with File Descriptor locks and subshell traps to prevent dual execution.<br><br>
```bash
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
```
<br><br>
12. Kurumsal fwaudit<br>
[TR] Firewalld kurallarını fail-fast prensibiyle kontrol eder ve temiz bir matris olarak raporlar.<br>
[EN] Checks Firewalld rules with a fail-fast principle and reports them as a clean matrix.<br><br>
```bash
_secure_fw_audit() (
    set -Eeuo pipefail
    IFS=$'\n\t'
    if ! command -v firewall-cmd >/dev/null 2>&1; then echo >&2 "[FATAL] 'firewall-cmd' bulunamadı."; exit 1; fi
    sudo firewall-cmd --list-all | awk -F': ' 'NF==2 {printf "%-20s : %s\n", $1, $2}'
)
alias fwaudit='_secure_fw_audit'
```
<br><br>
13. Kurumsal svc-check<br>
[TR] Belirtilen systemd servisinin ayakta olup olmadığını sıkı argüman doğrulama ile test eder.<br>
[EN] Tests whether the specified systemd service is active using strict argument validation.<br><br>
```bash
_secure_service_check() (
    set -Eeuo pipefail
    IFS=$'\n\t'
    local svc="${1:-}"
    if [[ -z "$svc" ]]; then echo >&2 "[FATAL] Hedef servis belirtilmedi."; exit 1; fi
    systemctl is-active "$svc" >/dev/null 2>&1 && echo "[OK] $svc UP" || { echo >&2 "[ERROR] $svc DOWN"; exit 1; }
)
alias svc-check='_secure_service_check'
```

<br><br>
14. Kurumsal sysclean<br>
[TR] DNF önbelleğini ve eski logları atomik kilit (flock) koruması altında güvenle rotasyona sokar.<br>
[EN] Safely rotates the DNF cache and old logs under atomic lock (flock) protection.<br><br>
```bash
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
```
<br><br>

15. Kurumsal netif<br>
[TR] Ağ arayüzlerinden gelen JSON çıktısını jq ve awk zinciriyle kesin ve hatasız bir şekilde okur.<br>
[EN] Reads the JSON output from network interfaces accurately and flawlessly using a jq and awk chain.<br><br>
```bash
_secure_network_interfaces() (
    set -Eeuo pipefail
    IFS=$'\n\t'
    if ! command -v jq >/dev/null 2>&1; then echo >&2 "[FATAL] 'jq' kurulu değil."; exit 1; fi
    ip -json addr show | jq -r '.[].ifname + " " + (.[].addr_info[]? | select(.family=="inet") | .local)' | awk 'NF==2 {printf "Interface: %-10s IPv4: %s\n", $1, $2}'
)
alias netif='_secure_network_interfaces'
```
<br><br>
16. KERNEL & DONANIM İZOLASYONU (USB Dosya Sistemi Kilitleri)<br>
[TR] USB depolama modüllerini çekirdeğe yükleyerek harici disklerin veri akışını açar.<br>
[EN] Loads USB storage modules into the kernel to enable external drive data transfer<br><br>

```bash
alias usb-ac='sudo modprobe usb-storage && sudo modprobe uas && echo "🔓 [SİSTEM] USB Depolama Modülleri Yüklendi. Veri akışı aktif."'
```

<br><br>
[TR] USB depolama sürücülerini çekirdekten kazır; böylece fiziksel cihaz takılsa bile veri okunamaz.<br>
[EN] Removes USB storage drivers from the kernel; preventing data access even if a physical device is connected.<br>

```bash
alias usb-kapat='sudo modprobe -r usb-storage uas 2>/dev/null && echo "🔒 [SİSTEM] USB Depolama Kilitlendi. Sürücüler hafızadan güvenle kazındı!" || echo "[!] Kapatılamadı: Cihaz şu an kullanımda olabilir."'
```

<br><br>
17. KRİPTOGRAFİK VERİ İMHASI (DoD Standardı)<br>
[TR] Dosya sektörlerini 3 kez rastgele veriyle ezip sıfırlayarak adli bilişimle bile kurtarılamayacak şekilde imha eder.<br>
[EN] Overwrites file sectors 3 times with random data and zero-fills them, ensuring recovery is impossible even with forensic tools.<br><br>

```bash
secure-wipe() {
    if [ -z "${1:-}" ]; then 
        echo "[HATA] Yok edilecek dosyayı belirtmelisin! Kullanım: secure-wipe <dosya_adi>" >&2
        return 1
    fi
    echo "🔥 [GÜVENLİK] '$1' kriptografik olarak atomlarına ayrılıyor..."
    shred -u -z -n 3 "$1" && echo "[✔] İşlem başarılı. Veri kurtarma ihtimali: %0"
}
```
<br><br>

18. IMMUTABLE ARCHITECTURE (Mutlak Çekirdek Kilidi)<br>
[TR] Dosyayı kernel seviyesinde "Değiştirilemez" yapar; kilit kalkana kadar root dahil hiç kimse silemez veya değiştiremez.<br>
[EN] Makes the file "Immutable" at the kernel level; nobody, including root, can delete or modify it until unlocked.<br><br>
```bash
alias kilit-vur='sudo chattr +i'
```
<br><br>

[TR] Dosya üzerindeki kernel seviyesindeki değiştirilemezlik (Immutable) mühürünü kaldırarak düzenlemeye açar.<br>
[EN] Removes the kernel-level immutability seal from the file, making it editable again.<br>
```bash
alias kilit-ac='sudo chattr -i'
```
<br><br>
[TR] Bulunulan dizindeki dosyaların kernel seviyesindeki özel kilit ve öznitelik durumlarını listeler.<br>
[EN] Lists the kernel-level special locks and attribute statuses of the files in the current directory.<br>
```bash
alias kilit-kontrol='lsattr'
```

<br><br>
19. SİBER GÜVENLİK (Rkhunter Human-in-the-Loop Mimarisi)<br>
[TR] Rootkit imza veritabanını günceller, tarama yapar ve güvenli referans (Baseline) mühürlemesini insan onayına bırakır.<br>
[EN] Updates the rootkit signature database, runs a scan, and leaves the secure reference (Baseline) sealing to human verification.<br><br>
```bash
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
```
<br><br>

[TR] Ağda dış bağlantı bekleyen (LISTEN) tüm aktif portları ve bu portları açan gizli süreçleri (PID) listeler.<br>
[EN] Lists all active ports waiting for external connections (LISTEN) and the hidden processes (PID) that opened them.<br><br>
```bash
alias net-audit='echo "🔍 [SİSTEM] Açık portlar ve dinleyen süreçler taranıyor..." && sudo ss -tulpn | grep LISTEN'
```
<br><br>

20. İZOLASYON & TELEMETRİ (Veri Analitiği ve Çekirdek Röntgeni)<br>
[TR] Bulunulan dizinde steril bir Python sanal ortamı (venv) kurarak işletim sisteminin paket yapısını çakışmalardan korur.<br>
[EN] Creates a sterile Python virtual environment (venv) in the current directory, protecting the OS package structure from conflicts.<br><br>
```bash
data-sandbox() {
    echo "🧪 [SİSTEM] İzole Python Veri Laboratuvarı inşa ediliyor..."
    python3 -m venv venv --clear
    source venv/bin/activate
    echo "🔒 [GÜVENLİK] Global sistemden koptunuz. Paketler sadece bu dizine kurulacak."
}
```
<br><br>
[TR] Çekirdekten ham bellek verilerini çeker, AWK matrisiyle Gigabyte cinsinden hesaplar ve en ağır 10 süreci listeler.<br>
[EN] Fetches raw memory data from the kernel, calculates it in Gigabytes using an AWK matrix, and lists the top 10 heaviest processes.<br><br>
```bash
alias ram-radar='echo "📊 [TELEMETRİ] En çok RAM tüketen ilk 10 süreç:" && ps axo rss,comm,pid | awk '\''{ sum+=$1; print $0 } END { printf "\nToplam Tüketim: %.2f GB\n", sum/1024/1024 }'\'' | sort -n | tail -n 11'
```
<br><br>
[TR] Çekirdek günlükleri (dmesg) içindeki donanım çökmelerini, hafıza hatalarını ve kritik USB anomalilerini süzüp kırmızıya boyar.<br>
[EN] Filters kernel logs (dmesg) for hardware crashes, memory errors, and critical USB anomalies, highlighting them in red.<br>

```bash
alias kernel-radar='echo "☢️ [KERNEL] Kritik donanım hataları taranıyor..." && sudo dmesg -T | grep --color=always -iE "error|warn|fail|killed|segfault|usb"'
```
<br><br>
[TR] Kör commit yapmayı engellemek için, mevcut dal durumunu ve değiştirilen satır sayılarını atomik bir istatistik olarak sunar.<br>
[EN] Prevents blind commits by presenting the current branch status and modified line counts as an atomic statistic.<br>
```bash
alias git-rontgen='echo "🔍 [GİT] Değiştirilen satırların atomik röntgeni:" && git status -s -b && echo "---------------------------" && git diff --stat'
```
