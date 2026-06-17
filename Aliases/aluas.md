# ENTERPRISE-GRADE ALIAS & FUNCTION USAGE GUIDE
## Detailed Operation Manual for the `.bashrc` Hardening Suite
### Author: Dr. Ozhan Akdag & Senior Cyber Security Agent (Collaborative design)

---

> **How to use this guide**  
> Each tool is presented with a bilingual description (Turkish / English), the exact syntax, practical examples, expected output, and critical security or performance notes.  
> All scripts that perform system modifications write timestamped logs to `~/Desktop/LOG_FILES/<tool>.log`.  
> Before running any command, verify that the required dependencies are installed (see the **Dependencies** note at the end of each section).

---

## 🔹 1. `rm` – Safe Removal (Güvenli Silme)

| 🇹🇷 TÜRKÇE | 🇬🇧 ENGLISH |
|-----------|------------|
| 3’ten fazla dosya silinirken veya kök dizin hedeflendiğinde etkileşimli onay ister. Yanlışlıkla `rm -rf /` gibi komutların önüne geçer. | Requests interactive confirmation when deleting more than 3 files or when the root directory is the target, preventing accidental `rm -rf /` mistakes. |

**Syntax / Kullanım:**  
`rm [options] <file...>`

**Examples / Örnekler:**
```bash
rm *.log           # 3'ten fazla log varsa "Remove all arguments?" diye sorar
rm -rf /some/dir   # Kök dizin koruması sayesinde engellenir


Expected Output / Beklenen Çıktı:
[TR] rm: remove all arguments? sorusu görüntülenir, y/n ile cevaplanmalıdır.
[EN] Prompts rm: remove all arguments? – answer y/n.

Security Note / Güvenlik Notu:
The --preserve-root flag is a kernel‑level guard; even with sudo the root filesystem cannot be recursively deleted.

Dependencies / Bağımlılıklar: None (coreutils)
🔹 2. cp – Safe Copy (Güvenli Kopyalama)
🇹🇷 TÜRKÇE	🇬🇧 ENGLISH
Dosyaları kopyalarken tüm meta veriyi (izinler, zaman damgaları) korur ve hedef dosya mevcutsa üzerine yazmadan önce onay ister.	Preserves all metadata (permissions, timestamps) during copy and asks for confirmation before overwriting an existing target file.

Syntax / Kullanım:
cp [options] <source> <destination>

Examples / Örnekler:
bash

cp -ia /etc/important.conf ~/backups/
# Eğer ~/backups/important.conf mevcutsa "overwrite?" diye sorar.

Expected Output / Beklenen Çıktı:
[TR] cp: overwrite '/home/user/backups/important.conf'?
[EN] Same prompt in English locale.

Security Note / Güvenlik Notu:
The -i flag makes overwriting a deliberate action, protecting against data loss during bulk operations.

Dependencies / Bağımlılıklar: None (coreutils)
🔹 3. mv – Safe Move (Güvenli Taşıma)
🇹🇷 TÜRKÇE	🇬🇧 ENGLISH
Dosya/dizin taşırken hedefte aynı isimde bir öğe varsa üzerine yazmadan önce onay ister ve gerçekleşen her işlemi ayrıntılı olarak ekrana yazdırır.	When moving files/directories, asks for confirmation before overwriting an existing item at the destination and prints every operation in detail.

Syntax / Kullanım:
mv [options] <source...> <destination>

Examples / Örnekler:
bash

mv -iv *.txt ~/Documents/
# Her taşınan dosya için `renamed 'file.txt' -> '/home/user/Documents/file.txt'` çıktısı verir.

Expected Output / Beklenen Çıktı:
[TR] renamed '...' -> '...' satırları; üzerine yazma varsa mv: overwrite '...'?
[EN] Same pattern.

Security Note / Güvenlik Notu:
Verbose output creates an audit trail in your terminal; combined with the suite’s logging you have a full history.

Dependencies / Bağımlılıklar: None (coreutils)
🔹 4. mkdir – Smart Directory Creation (Akıllı Dizin Oluşturma)
🇹🇷 TÜRKÇE	🇬🇧 ENGLISH
Eksik olan tüm üst dizinleri otomatik oluşturur (-p) ve dizin zaten varsa hata üretmez; idempotent bir yapı sunar.	Automatically creates missing parent directories (-p) and does not throw an error if the directory already exists, providing an idempotent structure.

Syntax / Kullanım:
mkdir [options] <directory...>

Examples / Örnekler:
bash

mkdir -pv ~/Projects/MyApp/{src,bin,logs}
# Tüm ağaç tek seferde oluşturulur ve her adım ekrana yazdırılır.

Expected Output / Beklenen Çıktı:
[TR] mkdir: created directory '/home/user/Projects/MyApp/src' vb.
[EN] Same as above.

Security Note / Güvenlik Notu:
Idempotency guarantees that scripts can be run repeatedly without side effects.

Dependencies / Bağımlılıklar: None (coreutils)
🔹 5. chown – Protected Ownership Change (Korumalı Sahiplik Değişimi)
🇹🇷 TÜRKÇE	🇬🇧 ENGLISH
Kök dizin (/) üzerinde yanlışlıkla yapılabilecek sahiplik değişikliklerini çekirdek seviyesinde engeller.	Blocks accidental ownership changes on the root directory (/) at the kernel level.

Syntax / Kullanım:
chown [options] <owner>[:<group>] <file...>

Examples / Örnekler:
bash

sudo chown --preserve-root user:group /  # engellenir
sudo chown user:group /home/user/file    # çalışır

Security Note / Güvenlik Notu:
A recursive chown on / can render a system unbootable. This alias is a life‑saver.

Dependencies / Bağımlılıklar: None (coreutils)
🔹 6. ports – Deterministic Port Listing (Deterministik Port Listeleme)
🇹🇷 TÜRKÇE	🇬🇧 ENGLISH
Sistemde dinlenen tüm TCP/UDP portlarını ham ss çıktısını AWK ile işleyerek düzenli bir tablo halinde sunar.	Parses raw ss output with AWK and presents all listening TCP/UDP ports in a clean table.

Syntax / Kullanım:
ports (no arguments)

Examples / Örnekler:
bash

ports

Sample Output:
text

tcp       0.0.0.0:22              sshd
tcp       127.0.0.1:631           cupsd
udp       0.0.0.0:5353            avahi-daemon

Security Note / Güvenlik Notu:
Avoids noisy grep; the AWK matrix is immune to false positives from port numbers appearing in unrelated fields.

Dependencies / Bağımlılıklar: ss (iproute2), awk (gawk)
🔹 7. memstat – Precise Memory Usage (Hassas Bellek Kullanımı)
🇹🇷 TÜRKÇE	🇬🇧 ENGLISH
Bellek kullanımını byte seviyesinde okuyarak yüzde cinsinden ondalıklı ve tam doğru bir oran hesaplar.	Reads memory usage at the byte level and calculates a precise decimal percentage.

Syntax / Kullanım:
memstat

Sample Output:
RAM Tüketimi: 68.34%

Performance Note:
Using bytes avoids rounding errors that occur with free -m when memory is near boundaries.

Dependencies / Bağımlılıklar: free (procps-ng), awk
🔹 8. diskstat – Root Filesystem Usage (Kök Dizin Kullanımı)
🇹🇷 TÜRKÇE	🇬🇧 ENGLISH
Kök dosya sisteminin doluluk oranını blok seviyesinde hesaplayarak kesin bir yüzde verir.	Calculates the root filesystem usage percentage at the block level for exactitude.

Syntax / Kullanım:
diskstat

Sample Output:
Root FS Tüketimi: 72.15%

Security Note / Güvenlik Notu:
Disk full situations are a common DoS vector; monitor this value regularly.

Dependencies / Bağımlılıklar: df (coreutils), awk
🔹 9. loadavg – CPU Load Averages (İşlemci Yük Ortalaması)
🇹🇷 TÜRKÇE	🇬🇧 ENGLISH
/proc/loadavg dosyasındaki 1, 5 ve 15 dakikalık yük ortalamalarını ham değerlerden okuyup formatlar.	Reads 1, 5, and 15‑minute load averages directly from the kernel’s /proc/loadavg and formats them.

Syntax / Kullanım:
loadavg

Sample Output:
Yük (1/5/15dk): 1.23 | 0.89 | 0.65

Technical Note:
Load average is not just CPU; it includes processes waiting for I/O. A high number may indicate disk or network bottlenecks.

Dependencies / Bağımlılıklar: /proc filesystem, awk
🔹 10. zombies – Zombie Process Detection (Zombi Süreç Tespiti)
🇹🇷 TÜRKÇE	🇬🇧 ENGLISH
Durumu Z olan (zombi) süreçleri, ait oldukları üst sürecin PID’i ile birlikte listeler.	Lists processes in state Z (zombies) together with their parent PID.

Syntax / Kullanım:
zombies

Sample Output:
ZOMBIE PID: 12345 (Parent: 1234) -> defunct-process

Security Note / Güvenlik Notu:
A large number of zombies can exhaust the process table; this alias helps spot misbehaving parent processes.

Dependencies / Bağımlılıklar: ps (procps-ng), awk
🔹 11. sysupdate – Secure System Update (Güvenli Sistem Güncellemesi)
🇹🇷 TÜRKÇE	🇬🇧 ENGLISH
DNF paket yöneticisini flock tabanlı atomik kilit ve trap temizliği ile koruyarak çift çalışmayı engeller. Tüm paketleri en son sürümlere yükseltir.	Protects the DNF package manager with a flock‑based atomic lock and trap cleanup, preventing duplicate executions. Upgrades all packages to the latest versions.

Syntax / Kullanım:
sysupdate (sudo privileges required)

Process:

    A lock file is created at ~/.local/run/locks/sysupdate.lock.

    If another instance is already running, the command aborts with a warning.

    On successful completion, the lock is released automatically; even CTRL+C or SIGTERM triggers the cleanup.

Log File: ~/Desktop/LOG_FILES/secure-sysupdate.log

Dependencies / Bağımlılıklar: dnf, flock (util‑linux)
🔹 12. fwaudit – Firewalld Audit (Güvenlik Duvarı Denetimi)
🇹🇷 TÜRKÇE	🇬🇧 ENGLISH
Firewalld aktif kurallarını, anahtar‑değer formatında temiz bir tablo olarak ekrana basar.	Prints the active Firewalld rules in a clean key‑value table.

Syntax / Kullanım:
fwaudit

Sample Output:
text

trusted            : (all)
interfaces         : eth0 wlan0
services           : ssh cockpit dhcpv6-client
ports              : 8080/tcp 8443/tcp

Security Note / Güvenlik Notu:
This is a read‑only operation; no firewall changes are made.

Dependencies / Bağımlılıklar: firewall-cmd (firewalld), awk
🔹 13. svc-check – Service Health Check (Servis Sağlık Kontrolü)
🇹🇷 TÜRKÇE	🇬🇧 ENGLISH
Verilen systemd servisinin aktif olup olmadığını sıkı argüman doğrulaması ile kontrol eder ve kısa bir durum özeti sunar.	Checks whether a given systemd service is active with strict argument validation and prints a brief status summary.

Syntax / Kullanım:
svc-check <service-name>

Examples / Örnekler:
svc-check sshd → [OK] sshd UP
svc-check docker → [ERROR] docker DOWN (exit code 1)

Log File: ~/Desktop/LOG_FILES/secure-svccheck.log

Dependencies / Bağımlılıklar: systemctl (systemd)
🔹 14. sysclean – System Cache & Log Rotation (Sistem Önbellek ve Log Rotasyonu)
🇹🇷 TÜRKÇE	🇬🇧 ENGLISH
DNF paket önbelleğini temizler ve 7 günden eski journal log’larını güvenli şekilde siler. Aynı anda sadece bir temizlik işlemi çalışabilir.	Clears the DNF package cache and safely removes journal logs older than 7 days. Only one cleaning process can run at a time.

Syntax / Kullanım:
sysclean

Locking: Uses flock to prevent concurrent runs.

Log File: ~/Desktop/LOG_FILES/secure-cleancache.log

Dependencies / Bağımlılıklar: dnf, journalctl (systemd), flock
🔹 15. netif – Network Interface Info (Ağ Arayüz Bilgisi)
🇹🇷 TÜRKÇE	🇬🇧 ENGLISH
Tüm ağ arayüzlerini ve üzerlerindeki IPv4 adreslerini ip komutunun JSON çıktısını jq ve awk ile ayrıştırarak gösterir.	Shows all network interfaces with their IPv4 addresses by parsing the JSON output of ip with jq and awk.

Syntax / Kullanım:
netif

Sample Output:
text

Interface: eth0       IPv4: 192.168.1.100
Interface: wlan0      IPv4: 10.0.0.5

Prerequisite: jq must be installed (sudo dnf install jq).
Log File: ~/Desktop/LOG_FILES/secure-netif.log

Dependencies / Bağımlılıklar: ip (iproute2), jq, awk
🔹 16. usb-ac / usb-kapat – USB Storage Control (USB Depolama Kontrolü)
🇹🇷 TÜRKÇE	🇬🇧 ENGLISH
USB depolama sürücülerini (usb-storage, uas) çekirdeğe yükler veya çekirdekten zorla kaldırır. Kaldırma sırasında bağlı cihazlar varsa interaktif uyarı verir.	Loads or forcibly unloads the USB storage kernel modules (usb-storage, uas). When unloading, if any USB drives are still mounted, an interactive warning is shown.

Syntax / Kullanım:
usb-ac → enable USB storage
usb-kapat → disable USB storage

Process (usb-kapat):

    Scans for USB block devices with lsblk.

    If found, lists them and asks for confirmation.

    Attempts to remove the modules with modprobe -r.
    Even if removal fails because the device is busy, the system remains safe.

Security Note / Güvenlik Notu:
This is a powerful anti‑malware measure; BadUSB attacks cannot mount filesystems if the drivers are absent.

Dependencies / Bağımlılıklar: lsblk, modprobe, sudo
🔹 17. secure-wipe – Cryptographic File Destruction (Kriptografik Dosya İmhası)
🇹🇷 TÜRKÇE	🇬🇧 ENGLISH
Hedef dosyayı 3 geçişli rastgele veri ve son bir sıfır yazma turu ile adli bilişim araçlarının dahi kurtaramayacağı şekilde yok eder. SSD’ler için uyarı sunar.	Destroys a file with 3 passes of random data followed by a final zero‑fill, making recovery impossible even with forensic tools. Displays an SSD warning before proceeding.

Syntax / Kullanım:
secure-wipe <file>

Example / Örnek:
secure-wipe ~/secret.doc

Important: Because of wear‑leveling on SSDs, physical destruction is not guaranteed; the tool informs the user of this limitation and requires confirmation.

Dependencies / Bağımlılıklar: shred (coreutils)
🔹 18. kilit-vur, kilit-ac, kilit-kontrol – Immutable Architecture (Değiştirilemez Mimari)
🇹🇷 TÜRKÇE	🇬🇧 ENGLISH
Kritik dosyaları kernel seviyesinde değiştirilemez (immutable) yapar. Kilit kalkana kadar root dahi dosyayı silemez veya değiştiremez.	Makes critical files immutable at the kernel level. Until the lock is removed, even root cannot delete or modify the file.

Syntax / Kullanım:
kilit-vur <file...> → apply immutable (chattr +i)
kilit-ac <file...> → remove immutable (chattr -i)
kilit-kontrol <file...> → show attributes (lsattr)

Examples / Örnekler:
kilit-vur /etc/ssh/sshd_config
kilit-ac /etc/ssh/sshd_config
kilit-kontrol /etc/ssh/sshd_config

Security Note / Güvenlik Notu:
Even ransomware running as root cannot encrypt a file protected by chattr +i. This is a strong defense‑in‑depth layer.

Dependencies / Bağımlılıklar: chattr, lsattr (e2fsprogs)
🔹 19. rk-denetim – Rkhunter Human‑in‑the‑Loop (İnsan Onaylı Rootkit Taraması)
🇹🇷 TÜRKÇE	🇬🇧 ENGLISH
Rkhunter imza veritabanını günceller, tam sistem taraması yapar ve sonuçları kullanıcıya sunar. Yalnızca kullanıcı açıkça onay verirse yeni dosya durumunu güvenli kabul edip baseline’ı mühürler.	Updates the Rkhunter signature database, runs a full system scan, and presents the results. Only if the user explicitly approves does it seal the new file baseline, preventing automatic poisoning.

Syntax / Kullanım:
rk-denetim

Interactive Flow:

    rkhunter --update → signature update

    rkhunter --check --rwo → scan with warnings only

    User is asked: Veritabanı mühürlensin mi? (yes/no)

    If yes → rkhunter --propupd seals the new baseline.

Log File: ~/Desktop/LOG_FILES/secure-rkhunter.log

Dependencies / Bağımlılıklar: rkhunter, sudo
🔹 20. net-audit – Listening Ports & Process Audit (Ağ Dinleme Denetimi)
🇹🇷 TÜRKÇE	🇬🇧 ENGLISH
Sistemde dış bağlantı bekleyen tüm portları ve onları dinleyen süreçleri PID’leriyle birlikte listeler.	Lists all ports waiting for external connections together with the PID and name of the listening process.

Syntax / Kullanım:
net-audit

Sample Output:
text

LISTEN   0.0.0.0:22              sshd (PID 1234)
LISTEN   127.0.0.1:631           cupsd (PID 567)

Log File: ~/Desktop/LOG_FILES/secure-netaudit.log

Dependencies / Bağımlılıklar: ss, grep, sudo
🔹 21. data-sandbox – Isolated Python Environment (İzole Python Çalışma Alanı)
🇹🇷 TÜRKÇE	🇬🇧 ENGLISH
Bulunulan dizinde steril bir Python sanal ortamı (venv) oluşturur ve onu aktifleştirir. Global sistem Python’undan tamamen koparır.	Creates a sterile Python virtual environment (venv) in the current directory and activates it, completely isolating it from the system Python.

Syntax / Kullanım:
data-sandbox

What it does:

    Runs python3 -m venv venv --clear

    Sources venv/bin/activate

    All subsequent pip install commands affect only this directory.

Note: The --clear flag ensures a fresh environment even if the directory existed.

Dependencies / Bağımlılıklar: python3, venv (usually included with Python)
🔹 22. ram-radar – Memory Top‑10 (Bellek Sıralaması)
🇹🇷 TÜRKÇE	🇬🇧 ENGLISH
En çok RAM tüketen ilk 10 süreci RSS değeriyle sıralar ve toplam sistem RAM kullanımını GB cinsinden gösterir.	Sorts the top‑10 processes by RSS (Resident Set Size) and displays total system RAM usage in GB.

Syntax / Kullanım:
ram-radar

Sample Output:
text

📊 En çok RAM tüketen ilk 10 süreç:
RSS(KB)  COMMAND              PID
2048576  firefox              1234
 524288  gnome-shell          567
...
Toplam RAM Tüketimi: 7.86 GB

Log File: ~/Desktop/LOG_FILES/sys-ramradar.log

Dependencies / Bağımlılıklar: ps (procps-ng), awk
🔹 23. kernel-radar – Kernel Error Scanner (Çekirdek Hatası Tarayıcı)
🇹🇷 TÜRKÇE	🇬🇧 ENGLISH
dmesg çıktısında error, warn, fail, killed, segfault, usb gibi kritik anahtar kelimeleri arar ve renkli olarak vurgular.	Searches the kernel ring buffer for critical keywords like error, warn, fail, killed, segfault, usb and highlights them in colour.

Syntax / Kullanım:
kernel-radar

Sample Output:
text

[Mon Jun 15 10:23:45] usb 1-1: device descriptor read/64, error -71

Log File: ~/Desktop/LOG_FILES/sys-kernelradar.log

Dependencies / Bağımlılıklar: dmesg, grep (with --color), sudo (often required)
🔹 24. git-rontgen – Git Change Preview (Git Değişiklik Önizlemesi)
🇹🇷 TÜRKÇE	🇬🇧 ENGLISH
Kör commit yapmayı önlemek için mevcut dal durumunu ve değişen dosyaların satır istatistiklerini atomik bir şekilde gösterir.	Prevents blind commits by showing the current branch status and line statistics of changed files in one atomic view.

Syntax / Kullanım:
git-rontgen (must be run inside a Git repository)

Sample Output:
text

🔍 [GİT] Değiştirilen satırların atomik röntgeni:
## main...origin/main
 M README.md
---------------------------
 README.md | 15 +++++++++------
 1 file changed, 9 insertions(+), 6 deletions(-)

Note: Uses git status -s -b and git diff --stat – purely informative, no modifications.

Dependencies / Bağımlılıklar: git
🔹 25. termal – Thermal Sensors (Sıcaklık Sensörleri)
🇹🇷 TÜRKÇE	🇬🇧 ENGLISH
Sistemdeki tüm sıcaklık sensörlerini lm_sensors aracılığıyla okur ve anlık değerleri gösterir. Surface Pro 9 gibi pasif soğutmalı cihazlarda aşırı ısınmayı önlemek için kritiktir.	Reads all temperature sensors via lm_sensors and displays the current values. Essential for preventing overheating on passively‑cooled devices like the Surface Pro 9.

Syntax / Kullanım:
termal

Prerequisite: Install lm_sensors and run sudo sensors-detect once.

Sample Output:
text

coretemp-isa-0000
Adapter: ISA adapter
Package id 0:  +52.0°C
Core 0:        +50.0°C
Core 1:        +51.0°C

Log File: ~/Desktop/LOG_FILES/sys-thermal.log

Dependencies / Bağımlılıklar: sensors (lm_sensors package)
🔹 26. needs-restart – Post‑Update Restart Check (Güncelleme Sonrası Yeniden Başlatma Kontrolü)
🇹🇷 TÜRKÇE	🇬🇧 ENGLISH
Son sistem güncellemesinden sonra hâlâ eski kütüphaneleri kullanan servisleri listeler. Bu servisler manuel olarak yeniden başlatılmazsa güncelleme tam anlamıyla etkinleşmez.	Lists services that are still using old libraries after a system update. If these services are not restarted, the update is not fully effective.

Syntax / Kullanım:
needs-restart

Sample Output:
text

Process 1234 (sshd) uses old libraries
Process 5678 (NetworkManager) uses old libraries
No core libraries or services have been updated.

Log File: ~/Desktop/LOG_FILES/secure-needsrestart.log

Dependencies / Bağımlılıklar: dnf (provides dnf needs-restarting)
🔹 27. aide-denetim – AIDE File Integrity Check (AIDE Dosya Bütünlüğü Denetimi)
🇹🇷 TÜRKÇE	🇬🇧 ENGLISH
AIDE (Advanced Intrusion Detection Environment) veritabanını kullanarak dosya sistemindeki bütünlük ihlallerini tespit eder. Sonuçları insan onayına sunar; yalnızca kullanıcı isterse yeni baseline mühürlenir.	Uses the AIDE (Advanced Intrusion Detection Environment) database to detect file integrity violations. Results are presented for human review; the new baseline is sealed only after explicit user approval.

Syntax / Kullanım:
aide-denetim

Interactive Flow:

    If no initial database exists, runs aide --init and moves the database.

    Otherwise runs aide --check.

    Asks user whether to update the baseline (yes/no).

    If yes, executes aide --update.

Log File: ~/Desktop/LOG_FILES/secure-aide.log

Security Note / Güvenlik Notu:
Baseline poisoning is prevented by the same human‑in‑the‑loop mechanism used in rk-denetim.

Dependencies / Bağımlılıklar: aide, sudo
🔹 28. perm-check – Permission Hygiene Audit (İzin Hijyeni Denetimi)
🇹🇷 TÜRKÇE	🇬🇧 ENGLISH
Kullanıcı ev dizini ($HOME), ~/.ssh, ~/.bashrc, ~/.bash_profile gibi kritik konumların izinlerini denetler ve olması gereken değerlerle karşılaştırır.	Audits the permissions of critical locations like the home directory, ~/.ssh, ~/.bashrc, ~/.bash_profile and compares them against the expected secure defaults.

Syntax / Kullanım:
perm-check

Expected Output:
text

[OK] Home dizini (/home/user) – 700
[OK] ~/.ssh dizini (/home/user/.ssh) – 700
[ZAYIF] ~/.bashrc (/home/user/.bashrc) izni 644, beklenen 600

Security Note / Güvenlik Notu:
Incorrect permissions (e.g. world‑readable ~/.ssh/id_rsa) are a trivial privilege escalation vector.

Log File: ~/Desktop/LOG_FILES/secure-permcheck.log

Dependencies / Bağımlılıklar: stat (coreutils)
🔹 29. suid-tarama – SUID/SGID Binary Scan (SUID/SGID Binary Taraması)
🇹🇷 TÜRKÇE	🇬🇧 ENGLISH
Kritik sistem dizinlerinde (/usr, /bin, /sbin, /lib, /lib64, /opt) SUID veya SGID bit’ine sahip binary’leri tarar ve listeler. Yetki yükseltme yüzeyini sürekli gözlem altında tutar.	Scans critical system directories for binaries with the SUID or SGID bit set and lists them. Keeps the privilege escalation surface under constant observation.

Syntax / Kullanım:
suid-tarama

Sample Output:
text

🔎 SUID/SGID DOSYA RAPORU
12345    -rwsr-xr-x   root root   /usr/bin/sudo
67890    -rwsr-xr-x   root root   /usr/bin/passwd
...

Note: The scan is limited to the listed directories to avoid excessive SSD wear.

Log File: ~/Desktop/LOG_FILES/sys-suidscan.log

Dependencies / Bağımlılıklar: find, sudo (to read all directories)
🔹 General Notes (Genel Notlar)

    Logging: All scripts that modify the system or perform security checks write timestamped logs to ~/Desktop/LOG_FILES/. The log filename matches the script name (e.g., secure-sysupdate.log). These logs are invaluable for forensic analysis and troubleshooting.

    Idempotency: Every script can be executed multiple times without side effects. Lock files prevent concurrent execution, and the trap mechanism ensures locks are always released, even after CTRL+C.

    Privileges: Most scripts require sudo. Ensure your user has the necessary sudo privileges. The suite does not modify /etc/sudoers.

    Dependencies: Before using the suite, install the required packages:
    bash

    sudo dnf install -y firewalld jq rkhunter aide lm_sensors util-linux

    Security Philosophy: This suite is built on the principles of Zero Trust, Human‑in‑the‑loop, and Defence in Depth. Every change is verified, every baseline update requires manual approval, and kernel‑level protections are employed wherever possible.

    Yazar / Author: Dr. Ozhan Akdag & Senior Cyber Security Agent (Collaborative design)
    Proje Sayfası / Project Page: Fedora Hardening Suite

