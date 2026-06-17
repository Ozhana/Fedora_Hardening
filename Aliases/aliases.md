cat << 'POTATO' > aliases.md
# Fedora 44 Secure Alias Suite

| **Property** | **Value** |
|--------------|-----------|
| **Project Name** | Fedora 44 Secure Alias Suite |
| **Version** | V1.0 |
| **Core Problem Solved** | Scattered, non‑atomic alias definitions lacking proper locking, logging, and idempotency; privilege escalation risks via temporary file races; thermal and SSD wear unawareness on Surface Pro 9 hardware. |
| **Applied Solution** | Strict‑mode, kernel‑level `flock`‑based atomic scripts with unified logging to `~/Desktop/LOG_FILES/`, absolute cleanup traps, baseline poisoning prevention, and hardware‑conscious design. |
| **Affected File Paths** | `/usr/local/bin/secure-*`, `/usr/local/bin/sys-*`, `~/.bashrc`, `~/Desktop/LOG_FILES/` |
| **Official GitHub Script Link** | [https://raw.githubusercontent.com/Ozhana/Fedora_Hardening/main/aliases/install.sh](https://raw.githubusercontent.com/Ozhana/Fedora_Hardening/main/aliases/install.sh) |
| **Verification Commands** | <code>type sysupdate</code>, <code>alias</code>, <code>ls -l /usr/local/bin/secure-*</code>, <code>cat ~/Desktop/LOG_FILES/secure-sysupdate.log</code> |
| **Author** | Dr. Ozhan Akdag & Senior Cyber Security Agent (Collaborative design) |

---

## Introduction / Giriş

| ENGLISH | TÜRKÇE |
|---------|--------|
| This suite delivers a hardened, production‑grade set of shell aliases and independent scripts for Fedora 44 running on a Surface Pro 9. Every command follows strict error handling, uses atomic file locks to prevent race conditions, writes timestamped logs for forensic traceability, and guards against SSD write amplification and thermal stress. The design adheres to a "zero‑trust" philosophy: no automatic baseline updates, every critical change requires explicit human confirmation. | Bu paket, Surface Pro 9 üzerinde çalışan Fedora 44 için kurumsal düzeyde sertleştirilmiş bir dizi kabuk alias’ı ve bağımsız betik sunar. Her komut katı hata yönetimi uygular, yarış koşullarını önlemek için atomik dosya kilitleri kullanır, adli izlenebilirlik için zaman damgalı loglar yazar ve SSD yazma amplifikasyonu ile termal strese karşı koruma sağlar. Tasarım “sıfır güven” ilkesine bağlıdır: hiçbir temel referans (baseline) güncellemesi otomatik yapılmaz; her kritik değişiklik açık insan onayı gerektirir. |

---

## Workspace Preparation / Çalışma Alanı Hazırlığı

| ENGLISH | TÜRKÇE |
|---------|--------|
| <code>mkdir -p ~/Desktop/LOG_FILES</code><br>Creates the central logging directory on the desktop. All scripts automatically write their logs here. | <code>mkdir -p ~/Desktop/LOG_FILES</code><br>Masaüstünde merkezî log dizinini oluşturur. Tüm betikler loglarını otomatik olarak buraya yazar. |

---

## Fetch the Installation Script / Kurulum Betiğini İndirme

| ENGLISH | TÜRKÇE |
|---------|--------|
| <code>curl -fsSL https://raw.githubusercontent.com/Ozhana/Fedora_Hardening/main/aliases/install.sh -o /tmp/secure-aliases-install.sh</code><br>Downloads the master installer that creates all `/usr/local/bin` scripts and appends aliases to `~/.bashrc`. | <code>curl -fsSL https://raw.githubusercontent.com/Ozhana/Fedora_Hardening/main/aliases/install.sh -o /tmp/secure-aliases-install.sh</code><br>Tüm `/usr/local/bin` betiklerini oluşturan ve alias’ları `~/.bashrc` dosyasına ekleyen ana kurulum betiğini indirir. |

---

## Set Permissions & Execute / Yetkilendir ve Çalıştır

| ENGLISH | TÜRKÇE |
|---------|--------|
| <code>chmod 755 /tmp/secure-aliases-install.sh</code><br>Grants execution rights.<br><br><code>bash /tmp/secure-aliases-install.sh</code><br>Runs the installer. After completion, restart your shell or execute <code>source ~/.bashrc</code>. | <code>chmod 755 /tmp/secure-aliases-install.sh</code><br>Çalıştırma hakkı verir.<br><br><code>bash /tmp/secure-aliases-install.sh</code><br>Kurulumu çalıştırır. Tamamlandıktan sonra kabuğu yeniden başlatın veya <code>source ~/.bashrc</code> komutunu verin. |

---

## Alias & Script Reference / Alias ve Betik Referansı

### 1. Safe File Operations – `rm`, `cp`, `mv`, `mkdir`, `chown`

| ENGLISH | TÜRKÇE |
|---------|--------|
| **Command:** <code>alias rm='rm -I --preserve-root'</code><br>**Description:** Prompts before deleting more than 3 files or recursive; refuses to delete `/`.<br>**What to Expect:** Interactive confirmation, protection against catastrophic root removal.<br>**Usage:** <code>rm file1 dir/</code> | **Komut:** <code>alias rm='rm -I --preserve-root'</code><br>**Açıklama:** 3’ten fazla dosya veya recursive silmede onay ister; `/` silinmesini reddeder.<br>**Ne Beklemeli:** Etkileşimli onay, felaket kök dizin silinmesine karşı koruma.<br>**Kullanım:** <code>rm dosya1 dizin/</code> |
| **Command:** <code>alias cp='cp -ia'</code><br>**Description:** Interactive, preserves attributes; asks before overwrite.<br>**What to Expect:** Prompt on overwrite, metadata kept.<br>**Usage:** <code>cp source dest</code> | **Komut:** <code>alias cp='cp -ia'</code><br>**Açıklama:** Etkileşimli, öznitelikleri korur; üzerine yazmadan önce sorar.<br>**Ne Beklemeli:** Üzerine yazma onayı, meta veriler korunur.<br>**Kullanım:** <code>cp kaynak hedef</code> |
| **Command:** <code>alias mv='mv -iv'</code><br>**Description:** Verbose, interactive move; explains what is being moved.<br>**What to Expect:** Clear output, overwrite safety.<br>**Usage:** <code>mv old new</code> | **Komut:** <code>alias mv='mv -iv'</code><br>**Açıklama:** Ayrıntılı, etkileşimli taşıma; neyin taşındığını açıklar.<br>**Ne Beklemeli:** Net çıktı, üzerine yazma güvenliği.<br>**Kullanım:** <code>mv eski yeni</code> |
| **Command:** <code>alias mkdir='mkdir -pv'</code><br>**Description:** Creates parent directories, verbose output.<br>**What to Expect:** Full path created automatically, each step shown.<br>**Usage:** <code>mkdir -p a/b/c</code> (alias makes `-p` default) | **Komut:** <code>alias mkdir='mkdir -pv'</code><br>**Açıklama:** Üst dizinleri oluşturur, ayrıntılı çıktı verir.<br>**Ne Beklemeli:** Tam yol otomatik oluşturulur, her adım gösterilir.<br>**Kullanım:** <code>mkdir a/b/c</code> (alias `-p`’yi varsayılan yapar) |
| **Command:** <code>alias chown='chown --preserve-root'</code><br>**Description:** Refuses to operate on `/` recursively.<br>**What to Expect:** Accidental `chown -R /` blocked.<br>**Usage:** <code>chown user:group file</code> | **Komut:** <code>alias chown='chown --preserve-root'</code><br>**Açıklama:** `/` üzerinde özyineli çalışmayı reddeder.<br>**Ne Beklemeli:** Yanlışlıkla `chown -R /` engellenir.<br>**Kullanım:** <code>chown kullanıcı:grup dosya</code> |

### 2. System Status – `ports`, `memstat`, `diskstat`, `loadavg`, `zombies`

| ENGLISH | TÜRKÇE |
|---------|--------|
| **Command:** <code>alias ports='ss -tulpn \| awk ...'</code><br>**Description:** Lists listening TCP/UDP ports with process info.<br>**What to Expect:** Formatted table: protocol, address, process.<br>**Usage:** <code>ports</code> | **Komut:** <code>alias ports='ss -tulpn \| awk ...'</code><br>**Açıklama:** Dinleyen TCP/UDP portlarını süreç bilgisiyle listeler.<br>**Ne Beklemeli:** Biçimli tablo: protokol, adres, süreç.<br>**Kullanım:** <code>ports</code> |
| **Command:** <code>alias memstat='free -b \| awk ...'</code><br>**Description:** Shows RAM usage as a percentage.<br>**What to Expect:** Single line: “RAM Tüketimi: %XX.XX”.<br>**Usage:** <code>memstat</code> | **Komut:** <code>alias memstat='free -b \| awk ...'</code><br>**Açıklama:** RAM kullanımını yüzde olarak gösterir.<br>**Ne Beklemeli:** Tek satır: “RAM Tüketimi: %XX.XX”.<br>**Kullanım:** <code>memstat</code> |
| **Command:** <code>alias diskstat='df -B1 / \| awk ...'</code><br>**Description:** Root filesystem usage percentage.<br>**What to Expect:** “Root FS Tüketimi: %XX.XX”.<br>**Usage:** <code>diskstat</code> | **Komut:** <code>alias diskstat='df -B1 / \| awk ...'</code><br>**Açıklama:** Kök dosya sistemi kullanım yüzdesi.<br>**Ne Beklemeli:** “Root FS Tüketimi: %XX.XX”.<br>**Kullanım:** <code>diskstat</code> |
| **Command:** <code>alias loadavg='cat /proc/loadavg \| awk ...'</code><br>**Description:** 1/5/15 min load averages.<br>**What to Expect:** “Yük (1/5/15dk): 0.15 \| 0.10 \| 0.05”.<br>**Usage:** <code>loadavg</code> | **Komut:** <code>alias loadavg='cat /proc/loadavg \| awk ...'</code><br>**Açıklama:** 1/5/15 dk yük ortalamaları.<br>**Ne Beklemeli:** “Yük (1/5/15dk): 0.15 \| 0.10 \| 0.05”.<br>**Kullanım:** <code>loadavg</code> |
| **Command:** <code>alias zombies='ps axo stat,ppid,pid,comm \| awk ...'</code><br>**Description:** Lists zombie processes with parent PID.<br>**What to Expect:** Any defunct processes shown; usually empty.<br>**Usage:** <code>zombies</code> | **Komut:** <code>alias zombies='ps axo stat,ppid,pid,comm \| awk ...'</code><br>**Açıklama:** Zombi süreçleri ebeveyn PID ile listeler.<br>**Ne Beklemeli:** Varsa askıdaki süreçler gösterilir; genellikle boş.<br>**Kullanım:** <code>zombies</code> |

### 3. System Update & Maintenance – `sysupdate`, `sysclean`, `needs-restart`

| ENGLISH | TÜRKÇE |
|---------|--------|
| **Command:** <code>alias sysupdate='secure-sysupdate'</code><br>**Description:** Atomic, logged system upgrade via `dnf`. Uses `flock` to prevent concurrent runs.<br>**What to Expect:** Lock file in `~/.local/run/locks`, log in `~/Desktop/LOG_FILES/secure-sysupdate.log`. No interference if already running.<br>**Usage:** <code>sysupdate</code> | **Komut:** <code>alias sysupdate='secure-sysupdate'</code><br>**Açıklama:** Atomik, loglu sistem güncellemesi (`dnf`). Eşzamanlı çalışmayı `flock` ile engeller.<br>**Ne Beklemeli:** Kilit dosyası `~/.local/run/locks` altında, log `~/Desktop/LOG_FILES/secure-sysupdate.log`. Zaten çalışıyorsa müdahale etmez.<br>**Kullanım:** <code>sysupdate</code> |
| **Command:** <code>alias sysclean='secure-cleancache'</code><br>**Description:** Cleans DNF cache and journals older than 7 days, with atomic lock.<br>**What to Expect:** Disk space freed; log written.<br>**Usage:** <code>sysclean</code> | **Komut:** <code>alias sysclean='secure-cleancache'</code><br>**Açıklama:** DNF önbelleğini ve 7 günden eski journal kayıtlarını atomik kilit ile temizler.<br>**Ne Beklemeli:** Disk alanı boşalır; log yazılır.<br>**Kullanım:** <code>sysclean</code> |
| **Command:** <code>alias needs-restart='secure-needsrestart'</code><br>**Description:** Lists services and processes still using old libraries after an update.<br>**What to Expect:** Output from `dnf needs-restarting -r`; possibly none.<br>**Usage:** <code>needs-restart</code> | **Komut:** <code>alias needs-restart='secure-needsrestart'</code><br>**Açıklama:** Güncelleme sonrası hâlâ eski kütüphaneleri kullanan servis ve süreçleri listeler.<br>**Ne Beklemeli:** `dnf needs-restarting -r` çıktısı; genellikle boş.<br>**Kullanım:** <code>needs-restart</code> |

### 4. Firewall & Network – `fwaudit`, `netif`, `net-audit`, `secure-netaudit`

| ENGLISH | TÜRKÇE |
|---------|--------|
| **Command:** <code>alias fwaudit='secure-fwaudit'</code><br>**Description:** Displays active firewalld configuration in a readable format.<br>**What to Expect:** Key‑value pairs of firewall settings.<br>**Usage:** <code>fwaudit</code> | **Komut:** <code>alias fwaudit='secure-fwaudit'</code><br>**Açıklama:** Aktif firewalld yapılandırmasını okunabilir biçimde gösterir.<br>**Ne Beklemeli:** Güvenlik duvarı ayarları anahtar‑değer çiftleri hâlinde.<br>**Kullanım:** <code>fwaudit</code> |
| **Command:** <code>alias netif='secure-netif'</code><br>**Description:** Lists interfaces and their IPv4 addresses using `jq`.<br>**What to Expect:** Nicely formatted interface: IP pairs.<br>**Usage:** <code>netif</code> | **Komut:** <code>alias netif='secure-netif'</code><br>**Açıklama:** `jq` ile arayüzleri ve IPv4 adreslerini listeler.<br>**Ne Beklemeli:** Düzgün biçimli arayüz: IP çiftleri.<br>**Kullanım:** <code>netif</code> |
| **Command:** <code>alias net-audit='secure-netaudit'</code><br>**Description:** Shows all listening TCP/UDP sockets (alias calls dedicated script).<br>**What to Expect:** `ss` output filtered for LISTEN, logged.<br>**Usage:** <code>net-audit</code> | **Komut:** <code>alias net-audit='secure-netaudit'</code><br>**Açıklama:** Dinleyen tüm TCP/UDP soketlerini gösterir (özel betiği çağırır).<br>**Ne Beklemeli:** LISTEN durumundaki `ss` çıktısı, loglanır.<br>**Kullanım:** <code>net-audit</code> |

### 5. USB Storage Control – `usb-ac`, `usb-kapat`

| ENGLISH | TÜRKÇE |
|---------|--------|
| **Command:** <code>alias usb-ac='secure-usbctl on'</code><br>**Description:** Loads `usb-storage` and `uas` kernel modules to enable USB mass storage.<br>**What to Expect:** Modules inserted; log confirms.<br>**Usage:** <code>usb-ac</code> | **Komut:** <code>alias usb-ac='secure-usbctl on'</code><br>**Açıklama:** USB yığın depolama için `usb-storage` ve `uas` çekirdek modüllerini yükler.<br>**Ne Beklemeli:** Modüller yüklenir; log onaylar.<br>**Kullanım:** <code>usb-ac</code> |
| **Command:** <code>alias usb-kapat='secure-usbctl off'</code><br>**Description:** Removes USB storage modules after warning if devices are mounted.<br>**What to Expect:** Interactive prompt if USB drives are active; then modules removed.<br>**Usage:** <code>usb-kapat</code> | **Komut:** <code>alias usb-kapat='secure-usbctl off'</code><br>**Açıklama:** Bağlı aygıt varsa uyarı sonrası USB depolama modüllerini kaldırır.<br>**Ne Beklemeli:** Aktif USB sürücü varsa etkileşimli onay; ardından modüller kaldırılır.<br>**Kullanım:** <code>usb-kapat</code> |

### 6. Secure File Wipe – `secure-wipe`

| ENGLISH | TÜRKÇE |
|---------|--------|
| **Command:** <code>alias secure-wipe='secure-wipe'</code> (function wrapper)<br>**Description:** Overwrites a file 3 times with zeros, then removes it. Warns about SSD limitations.<br>**What to Expect:** SSD warning, confirmation prompt, then `shred -u -z -n 3`.<br>**Usage:** <code>secure-wipe secret.txt</code> | **Komut:** <code>alias secure-wipe='secure-wipe'</code> (fonksiyon sarmalayıcı)<br>**Açıklama:** Dosyayı 3 kez sıfırlarla üzerine yazar, sonra siler. SSD sınırlamaları hakkında uyarır.<br>**Ne Beklemeli:** SSD uyarısı, onay sorusu, ardından `shred -u -z -n 3`.<br>**Kullanım:** <code>secure-wipe gizli.txt</code> |

### 7. File Immutability – `kilit-vur`, `kilit-ac`, `kilit-kontrol`

| ENGLISH | TÜRKÇE |
|---------|--------|
| **Command:** <code>alias kilit-vur='sys-chattr lock'</code><br>**Description:** Makes a file immutable (`chattr +i`). Even root cannot modify or delete it until unlocked.<br>**What to Expect:** File becomes read‑only; locked.<br>**Usage:** <code>kilit-vur /etc/important.conf</code> | **Komut:** <code>alias kilit-vur='sys-chattr lock'</code><br>**Açıklama:** Dosyayı değişmez yapar (`chattr +i`). Kilit açılmadıkça root dahi dosyayı değiştiremez veya silemez.<br>**Ne Beklemeli:** Dosya salt okunur hâle gelir; kilitli.<br>**Kullanım:** <code>kilit-vur /etc/onemli.conf</code> |
| **Command:** <code>alias kilit-ac='sys-chattr unlock'</code><br>**Description:** Removes immutable flag (`chattr -i`).<br>**What to Expect:** File becomes writable again.<br>**Usage:** <code>kilit-ac /etc/important.conf</code> | **Komut:** <code>alias kilit-ac='sys-chattr unlock'</code><br>**Açıklama:** Değişmezlik bayrağını kaldırır (`chattr -i`).<br>**Ne Beklemeli:** Dosya tekrar yazılabilir olur.<br>**Kullanım:** <code>kilit-ac /etc/onemli.conf</code> |
| **Command:** <code>alias kilit-kontrol='sys-chattr check'</code><br>**Description:** Shows file attributes (`lsattr`).<br>**What to Expect:** Output like `----i--------e-- file`.<br>**Usage:** <code>kilit-kontrol /etc/important.conf</code> | **Komut:** <code>alias kilit-kontrol='sys-chattr check'</code><br>**Açıklama:** Dosya özniteliklerini gösterir (`lsattr`).<br>**Ne Beklemeli:** `----i--------e-- dosya` benzeri çıktı.<br>**Kullanım:** <code>kilit-kontrol /etc/onemli.conf</code> |

### 8. Rootkit & Integrity – `rk-denetim`, `aide-denetim`, `perm-check`, `suid-tarama`

| ENGLISH | TÜRKÇE |
|---------|--------|
| **Command:** <code>alias rk-denetim='secure-rkhunter'</code><br>**Description:** Updates rkhunter signatures, scans system, asks before updating baseline (`--propupd`).<br>**What to Expect:** Scan report; interactive baseline update.<br>**Usage:** <code>rk-denetim</code> | **Komut:** <code>alias rk-denetim='secure-rkhunter'</code><br>**Açıklama:** rkhunter imzalarını günceller, sistemi tarar, referans güncellemesi (`--propupd`) öncesi onay sorar.<br>**Ne Beklemeli:** Tarama raporu; etkileşimli referans güncellemesi.<br>**Kullanım:** <code>rk-denetim</code> |
| **Command:** <code>alias aide-denetim='secure-aide'</code><br>**Description:** Runs AIDE integrity check; interactive baseline update if necessary.<br>**What to Expect:** File change report; confirmation to update database.<br>**Usage:** <code>aide-denetim</code> | **Komut:** <code>alias aide-denetim='secure-aide'</code><br>**Açıklama:** AIDE bütünlük denetimi yapar; gerekirse etkileşimli referans güncellemesi.<br>**Ne Beklemeli:** Dosya değişiklik raporu; veritabanı güncelleme onayı.<br>**Kullanım:** <code>aide-denetim</code> |
| **Command:** <code>alias perm-check='secure-permcheck'</code><br>**Description:** Audits permissions of `$HOME`, `~/.ssh`, `~/.bashrc` etc. Warns if they deviate from secure defaults.<br>**What to Expect:** List of OK or ZAYIF (weak) findings.<br>**Usage:** <code>perm-check</code> | **Komut:** <code>alias perm-check='secure-permcheck'</code><br>**Açıklama:** `$HOME`, `~/.ssh`, `~/.bashrc` vb. izinlerini denetler. Güvenli varsayılanlardan sapma varsa uyarır.<br>**Ne Beklemeli:** OK veya ZAYIF bulguları listesi.<br>**Kullanım:** <code>perm-check</code> |
| **Command:** <code>alias suid-tarama='sys-suidscan'</code><br>**Description:** Scans critical system directories for SUID/SGID binaries (potential privilege escalation paths).<br>**What to Expect:** List of files with setuid/setgid bits.<br>**Usage:** <code>suid-tarama</code> | **Komut:** <code>alias suid-tarama='sys-suidscan'</code><br>**Açıklama:** Kritik sistem dizinlerinde SUID/SGID bit’li dosyaları tarar (yetki yükseltme yolları).<br>**Ne Beklemeli:** SUID/SGID bit’ine sahip dosyaların listesi.<br>**Kullanım:** <code>suid-tarama</code> |

### 9. Telemetry – `ram-radar`, `kernel-radar`, `termal`

| ENGLISH | TÜRKÇE |
|---------|--------|
| **Command:** <code>alias ram-radar='sys-ramradar'</code><br>**Description:** Top 10 memory‑consuming processes with total RAM usage.<br>**What to Expect:** Sorted RSS table, total GB used.<br>**Usage:** <code>ram-radar</code> | **Komut:** <code>alias ram-radar='sys-ramradar'</code><br>**Açıklama:** En çok bellek tüketen 10 süreç ve toplam RAM kullanımı.<br>**Ne Beklemeli:** RSS’e göre sıralı tablo, toplam GB kullanımı.<br>**Kullanım:** <code>ram-radar</code> |
| **Command:** <code>alias kernel-radar='sys-kernelradar'</code><br>**Description:** Scans `dmesg` for errors, warnings, failures, USB events.<br>**What to Expect:** Highlighted kernel messages; may be empty.<br>**Usage:** <code>kernel-radar</code> | **Komut:** <code>alias kernel-radar='sys-kernelradar'</code><br>**Açıklama:** `dmesg` çıktısında hata, uyarı, başarısızlık, USB olaylarını tarar.<br>**Ne Beklemeli:** Renkli çekirdek iletileri; boş olabilir.<br>**Kullanım:** <code>kernel-radar</code> |
| **Command:** <code>alias termal='sys-thermal'</code><br>**Description:** Displays CPU and system temperatures via `lm_sensors`.<br>**What to Expect:** Current temperature readings; helps monitor Surface Pro 9 thermal budget.<br>**Usage:** <code>termal</code> | **Komut:** <code>alias termal='sys-thermal'</code><br>**Açıklama:** `lm_sensors` ile CPU ve sistem sıcaklıklarını gösterir.<br>**Ne Beklemeli:** Anlık sıcaklık değerleri; Surface Pro 9 termal bütçesini izlemeye yardımcı olur.<br>**Kullanım:** <code>termal</code> |

### 10. Service Check – `svc-check`

| ENGLISH | TÜRKÇE |
|---------|--------|
| **Command:** <code>alias svc-check='secure-svccheck'</code><br>**Description:** Checks if a given systemd service is active, shows short status.<br>**What to Expect:** [OK] `<service>` UP or [ERROR] DOWN.<br>**Usage:** <code>svc-check sshd</code> | **Komut:** <code>alias svc-check='secure-svccheck'</code><br>**Açıklama:** Belirtilen systemd servisinin aktif olup olmadığını denetler, kısa durum gösterir.<br>**Ne Beklemeli:** [OK] `<servis>` UP veya [ERROR] DOWN.<br>**Kullanım:** <code>svc-check sshd</code> |

### 11. Git Röntgen – `git-rontgen`

| ENGLISH | TÜRKÇE |
|---------|--------|
| **Command:** <code>alias git-rontgen='echo ... && git status -s -b && echo ... && git diff --stat'</code><br>**Description:** Shows short status and diff stat of a Git repository.<br>**What to Expect:** Branch info, changed files, and line statistics.<br>**Usage:** <code>git-rontgen</code> | **Komut:** <code>alias git-rontgen='echo ... && git status -s -b && echo ... && git diff --stat'</code><br>**Açıklama:** Git deposunun kısa durumunu ve diff istatistiğini gösterir.<br>**Ne Beklemeli:** Dal bilgisi, değişen dosyalar ve satır istatistikleri.<br>**Kullanım:** <code>git-rontgen</code> |

### 12. Python Sandbox – `data-sandbox`

| ENGLISH | TÜRKÇE |
|---------|--------|
| **Command:** <code>data-sandbox</code> (shell function)<br>**Description:** Creates an isolated Python virtual environment in the current directory and activates it.<br>**What to Expect:** New `venv/` folder, prompt changes to show `(venv)`.<br>**Usage:** <code>data-sandbox</code> | **Komut:** <code>data-sandbox</code> (kabuk fonksiyonu)<br>**Açıklama:** Bulunulan dizinde yalıtılmış bir Python sanal ortamı oluşturur ve etkinleştirir.<br>**Ne Beklemeli:** Yeni `venv/` dizini, komut istemi `(venv)` olarak değişir.<br>**Kullanım:** <code>data-sandbox</code> |

---

## Logging & Forensics / Loglama ve Adli Bilişim

| ENGLISH | TÜRKÇE |
|---------|--------|
| All scripts write timestamped logs to `~/Desktop/LOG_FILES/<script_name>.log`. The directory is created automatically. Logs are append‑only; they never overwrite previous entries. This allows full audit trail of every action taken on the system. | Tüm betikler, zaman damgalı logları `~/Desktop/LOG_FILES/<betik_adı>.log` dosyasına yazar. Dizin otomatik oluşturulur. Loglar yalnızca ekleme yapar; önceki kayıtları asla silmez. Bu sayede sistem üzerinde yapılan her eylemin tam denetim izi tutulur. |

---

## Important Notes / Önemli Notlar

| ENGLISH | TÜRKÇE |
|---------|--------|
| • The suite is **idempotent** – it can be executed 1000 times without side‑effects or log flooding.<br>• **Baseline poisoning is prevented**: `rkhunter --propupd` and `aide --update` always require explicit user confirmation.<br>• All scripts honour **strict mode** (`set -Eeuo pipefail`, `IFS=$'\n\t'`) and clean up locks with `trap` even on CTRL+C.<br>• Lock files reside under `~/.local/run/locks/` (user‑only writable) to avoid symlink attacks.<br>• Designed for single‑user, single‑machine Fedora 44 on Surface Pro 9; not intended for multi‑user servers. | • Paket **idempotent**’tir – 1000 kez çalıştırılsa dahi yan etki veya log şişmesi yapmaz.<br>• **Referans zehirlenmesi önlenir**: `rkhunter --propupd` ve `aide --update` her zaman açık kullanıcı onayı gerektirir.<br>• Tüm betikler **katı mod** (`set -Eeuo pipefail`, `IFS=$'\n\t'`) kurallarına uyar ve CTRL+C’de dahi `trap` ile kilitleri temizler.<br>• Kilit dosyaları symlink saldırılarını önlemek için yalnızca kullanıcının yazabildiği `~/.local/run/locks/` altındadır.<br>• Surface Pro 9 üzerinde tek kullanıcılı, tek makineli Fedora 44 için tasarlanmıştır; çok kullanıcılı sunucular için uygun değildir. |

---

*End of Document / Belge Sonu*
POTATO
