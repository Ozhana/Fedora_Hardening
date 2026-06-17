cat << 'POTATO' > aliases.md
# Fedora Security & Performance Aliases Suite – Enterprise Hardening Companion

| **ENGLISH** | **TÜRKÇE** |
|-------------|-------------|
| **Project Name:** Fedora Security & Performance Aliases Suite | **Proje Adı:** Fedora Güvenlik & Performans Alias Paketi |
| **Version:** V1.0 | **Sürüm:** V1.0 |
| **Core Problem Solved:** Default shell aliases lack atomicity, leave residues, and cannot prevent race conditions or SSD wear. System updates, cache cleaning, and security audits are often performed without logging or rollback capabilities. | **Çözülen Temel Sorun:** Varsayılan shell alias’ları atomiklik sağlamaz, kalıntı bırakır, yarış durumlarını veya SSD aşınmasını engelleyemez. Sistem güncellemeleri, önbellek temizliği ve güvenlik denetimleri çoğu zaman loglama veya geri alma yeteneği olmadan yapılır. |
| **Applied Solution:** Independent, strictly‑written Bash scripts placed in `/usr/local/bin/` with kernel‑level `flock` locks, `trap` cleanup, idempotent operations, and mandatory logging to `~/Desktop/LOG_FILES/`. Aliases in `~/.bashrc` provide ergonomic access. | **Uygulanan Çözüm:** `/usr/local/bin/` altında bağımsız, katı yazım kurallarına sahip, çekirdek seviyesinde `flock` kilitleri, `trap` temizliği, yinelenebilir işlemler ve `~/Desktop/LOG_FILES/` dizinine zorunlu loglama içeren Bash betikleri. `~/.bashrc`’deki alias’lar ergonomik erişim sağlar. |
| **Scope:** Surface Pro 9, Fedora 44, single‑user, dual‑boot disabled, Librewolf browser, Docker (not Podman) ready. | **Kapsam:** Surface Pro 9, Fedora 44, tek kullanıcı, çift önyükleme kapalı, Librewolf tarayıcı, Docker (Podman değil) uyumlu. |
| **Author:** Dr. Ozhan Akdag & Senior Cyber Security Agent (Collaborative design) | **Yazar:** Dr. Ozhan Akdag & Kıdemli Siber Güvenlik Ajanı (İşbirlikçi tasarım) |

---

## 1. Introduction / Giriş

| **ENGLISH** | **TÜRKÇE** |
|-------------|-------------|
| This suite replaces fragile, one‑liner aliases with enterprise‑grade tools. Every operation is **atomic**, **logged**, **idempotent**, and **thermally aware**. Whether you update the system, audit the firewall, scan for rootkits, or wipe sensitive files, you will have full traceability and zero residue. | Bu paket, kırılgan tek satırlık alias’ları kurumsal düzey araçlarla değiştirir. Her işlem **atomik**, **loglanmış**, **yinelenebilir** ve **ısıl farkındalığa sahiptir**. Sistemi güncelleme, güvenlik duvarını denetleme, rootkit taraması veya hassas dosyaları silme fark etmeksizin tam izlenebilirlik ve sıfır kalıntı elde edersiniz. |

---

## 2. Workspace Preparation / Çalışma Alanı Hazırlığı

| **ENGLISH** | **TÜRKÇE** |
|-------------|-------------|
| Before installing the scripts, ensure the log directory exists. This command is idempotent: <code>mkdir -p ~/Desktop/LOG_FILES ~/.local/run/locks</code> | Betikleri kurmadan önce log dizininin var olduğundan emin olun. Bu komut yinelenebilirdir: <code>mkdir -p ~/Desktop/LOG_FILES ~/.local/run/locks</code> |
| Make sure you have **sudo** privileges. All scripts that modify the system will ask for a password when required. | **sudo** yetkinizin olduğundan emin olun. Sistemi değiştiren tüm betikler gerektiğinde parola soracaktır. |

---

## 3. Fetch the Script Package / Betik Paketini İndirme

| **ENGLISH** | **TÜRKÇE** |
|-------------|-------------|
| You can obtain the entire collection from the official repository. The `setup.sh` will copy each script to `/usr/local/bin/` and append aliases to your `~/.bashrc`. <br> <code>curl -sSL https://raw.githubusercontent.com/ozhantr/Fedora_Hardening/main/ALIASES/setup.sh -o setup.sh</code> | Tüm koleksiyonu resmi depodan edinebilirsiniz. `setup.sh`, her betiği `/usr/local/bin/` dizinine kopyalayacak ve `~/.bashrc` dosyanıza alias’ları ekleyecektir. <br> <code>curl -sSL https://raw.githubusercontent.com/ozhantr/Fedora_Hardening/main/ALIASES/setup.sh -o setup.sh</code> |
| **Manual installation** is also possible: place the provided scripts into `/usr/local/bin/` and add the alias block (see Section 5) to your `~/.bashrc`. | **Manuel kurulum** da mümkündür: sağlanan betikleri `/usr/local/bin/` altına yerleştirin ve alias bloğunu (Bkz. Bölüm 5) `~/.bashrc` dosyanıza ekleyin. |

---

## 4. Permissions & Execute / Yetkilendirme ve Çalıştırma

| **ENGLISH** | **TÜRKÇE** |
|-------------|-------------|
| <code>chmod 755 setup.sh</code> <br> <code>./setup.sh</code> | <code>chmod 755 setup.sh</code> <br> <code>./setup.sh</code> |
| After the script finishes, reload your shell environment: <br> <code>source ~/.bashrc</code> | Betik tamamlandıktan sonra kabuk ortamınızı yeniden yükleyin: <br> <code>source ~/.bashrc</code> |
| All tools are now available as simple aliases (e.g., `sysupdate`, `fw audit`, `sysclean`). | Artık tüm araçlar basit alias’lar (ör. `sysupdate`, `fwaudit`, `sysclean`) olarak kullanılabilir. |

---

## 5. Complete Alias Reference / Eksiksiz Alias Referansı

| **ALIAS / FUNCTION** | **ENGLISH DESCRIPTION** | **TÜRKÇE AÇIKLAMA** |
|----------------------|-------------------------|---------------------|
| `rm` | <code>rm -I --preserve-root</code> – prompts before deleting >3 files, forbids root removal | <code>rm -I --preserve-root</code> – 3’ten fazla dosya silmeden önce sorar, kök dizini silmeyi engeller |
| `cp` | <code>cp -ia</code> – interactive, preserves attributes | <code>cp -ia</code> – etkileşimli, öznitelikleri korur |
| `mv` | <code>mv -iv</code> – verbose, interactive | <code>mv -iv</code> – ayrıntılı, etkileşimli |
| `mkdir` | <code>mkdir -pv</code> – creates parents, verbose | <code>mkdir -pv</code> – üst dizinleri oluşturur, ayrıntılı |
| `chown` | <code>chown --preserve-root</code> – prevents accidental root ownership change | <code>chown --preserve-root</code> – yanlışlıkla kök sahiplik değişimini önler |
| `ports` | Shows listening TCP/UDP ports with process info | TCP/UDP dinleyen portları süreç bilgisi ile gösterir |
| `memstat` | Displays RAM usage percentage | RAM kullanım yüzdesini gösterir |
| `diskstat` | Shows root filesystem usage | Kök dosya sistemi doluluk oranını gösterir |
| `loadavg` | Prints 1, 5, 15‑minute load averages | 1, 5, 15 dakikalık yük ortalamalarını yazdırır |
| `zombies` | Lists zombie processes | Zombi süreçleri listeler |
| `sysupdate` | Locked, logged `dnf upgrade --refresh` | Kilitli, loglu `dnf upgrade --refresh` |
| `fwaudit` | Firewall rules summary via `firewall-cmd` | `firewall-cmd` ile güvenlik duvarı kurallarını özetler |
| `svc-check <svc>` | Checks if a service is active | Bir servisin aktif olup olmadığını denetler |
| `sysclean` | Locked DNF cache clear + vacuum journald (7 days) | Kilitli DNF önbellek temizliği + journald’de 7 günlük vakum |
| `netif` | Lists IPv4 addresses per interface (requires `jq`) | Arayüz başına IPv4 adreslerini listeler (`jq` gerektirir) |
| `usb-ac` | Loads USB storage modules (`usb-storage`, `uas`) | USB depolama modüllerini yükler |
| `usb-kapat` | Unloads USB storage modules, warns if devices mounted | USB depolama modüllerini kaldırır, bağlı aygıt varsa uyarır |
| `secure-wipe <file>` | Shred (3 passes + zero) with SSD caveat warning | SSD uyarısı ile shred (3 geçiş + sıfırlama) |
| `kilit-vur <file>` | `chattr +i` – makes file immutable | Dosyayı değişmez yapar (`chattr +i`) |
| `kilit-ac <file>` | `chattr -i` – makes file mutable | Dosyayı değişebilir yapar (`chattr -i`) |
| `kilit-kontrol <file>` | `lsattr` – shows file attributes | Dosya özniteliklerini gösterir (`lsattr`) |
| `rk-denetim` | Updates rkhunter signatures, scans, asks before updating baseline | Rkhunter imzalarını günceller, tarar, baseline güncellemeden önce onay sorar |
| `net-audit` | Lists all listening sockets (`ss -tulpn \| grep LISTEN`) | Tüm dinleyen soketleri listeler |
| `ram-radar` | Top 10 processes by RSS with total memory usage | RSS’e göre ilk 10 süreç ve toplam bellek kullanımı |
| `kernel-radar` | `dmesg` filtered for errors, warnings, kills, segfaults, USB | Hatalar, uyarılar, sonlandırmalar, segfault’lar, USB için filtrelenmiş `dmesg` |
| `git-rontgen` | Shows `git status -s -b` and diff stats | `git status -s -b` ve diff istatistiklerini gösterir |
| `termal` | Reads thermal sensors (requires `lm_sensors`) | Isıl sensörleri okur (`lm_sensors` gerektirir) |
| `needs-restart` | Lists services that require restart after updates | Güncelleme sonrası yeniden başlatma gerektiren servisleri listeler |
| `aide-denetim` | AIDE file integrity check with baseline update prompt | AIDE dosya bütünlük denetimi, baseline güncelleme onayı ile |
| `perm-check` | Checks permissions of `~`, `~/.ssh`, `~/.bashrc`, `~/.bash_profile` | Ev dizini ve kritik dosyaların izinlerini denetler |
| `suid-tarama` | Searches SUID/SGID binaries in key system directories | Ana sistem dizinlerinde SUID/SGID ikili dosyalarını arar |
| `data-sandbox()` | Creates a Python virtual environment and activates it | Python sanal ortamı oluşturur ve etkinleştirir |

---

## 6. What to Expect – Verification / Ne Beklemeli – Doğrulama

| **ENGLISH** | **TÜRKÇE** |
|-------------|-------------|
| After installation, run these checks to confirm everything is in place: | Kurulumdan sonra her şeyin yerinde olduğunu doğrulamak için aşağıdakileri çalıştırın: |
| <code>ls -l /usr/local/bin/secure-* /usr/local/bin/sys-*</code> – all scripts present | <code>ls -l /usr/local/bin/secure-* /usr/local/bin/sys-*</code> – tüm betikler mevcut |
| <code>grep "alias sysupdate" ~/.bashrc</code> – alias loaded | <code>grep "alias sysupdate" ~/.bashrc</code> – alias yüklenmiş |
| <code>ls ~/Desktop/LOG_FILES/</code> – log directory exists | <code>ls ~/Desktop/LOG_FILES/</code> – log dizini var |
| <code>type sysupdate</code> – should point to the script | <code>type sysupdate</code> – betiği göstermeli |
| Run a sample tool: <code>sysclean</code> – check for lock and log file | Örnek bir araç çalıştırın: <code>sysclean</code> – kilit ve log dosyasını kontrol edin |

---

## 7. Recovery & Rollback / Kurtarma ve Geri Alma

| **ENGLISH** | **TÜRKÇE** |
|-------------|-------------|
| The suite does **not** alter system‑critical files automatically. To revert, simply remove the scripts and the alias block from `~/.bashrc`: | Bu paket sistem kritik dosyalarını otomatik değiştirmez. Geri almak için betikleri ve `~/.bashrc` içindeki alias bloğunu kaldırmanız yeterlidir: |
| <code>sudo rm -f /usr/local/bin/secure-* /usr/local/bin/sys-*</code> | <code>sudo rm -f /usr/local/bin/secure-* /usr/local/bin/sys-*</code> |
| <code>sed -i '/# === \[GÜVENLİ TEMEL İŞLEMLER\] ===/,/data-sandbox()/d' ~/.bashrc</code> (adjust pattern as needed) | <code>sed -i '/# === \[GÜVENLİ TEMEL İŞLEMLER\] ===/,/data-sandbox()/d' ~/.bashrc</code> (deseni gerektiği gibi ayarlayın) |
| Logs remain in `~/Desktop/LOG_FILES/` for forensic review; delete them if no longer needed: <code>rm -rf ~/Desktop/LOG_FILES/</code> | Loglar adli inceleme için `~/Desktop/LOG_FILES/` dizininde kalır; gerekmiyorsa silin: <code>rm -rf ~/Desktop/LOG_FILES/</code> |

---

## 8. Usage Guide for Beginners / Yeni Başlayanlar İçin Kullanım Kılavuzu

| **ENGLISH** | **TÜRKÇE** |
|-------------|-------------|
| 1. After every login, your aliases are active. Open a terminal and type the alias name (e.g., `diskstat`). | 1. Her oturum açışınızda alias’larınız aktiftir. Bir terminal açın ve alias adını yazın (ör. `diskstat`). |
| 2. Commands that modify the system will ask for your password (sudo). | 2. Sistemi değiştiren komutlar parolanızı soracaktır (sudo). |
| 3. To update your system safely: `sysupdate`. The lock prevents double‑runs. | 3. Sisteminizi güvenle güncellemek için: `sysupdate`. Kilit, çift çalıştırmayı engeller. |
| 4. To check firewall: `fwaudit`. No password needed. | 4. Güvenlik duvarını denetlemek için: `fwaudit`. Parola gerektirmez. |
| 5. All actions are logged in `~/Desktop/LOG_FILES/`. Open any `.log` file to see timestamps and results. | 5. Tüm eylemler `~/Desktop/LOG_FILES/` içinde loglanır. Zaman damgalarını ve sonuçları görmek için herhangi bir `.log` dosyasını açın. |
| 6. If a tool reports “kilitli” (locked), wait or remove the stale lock file from `~/.local/run/locks/`. | 6. Bir araç “kilitli” bildirirse bekleyin veya `~/.local/run/locks/` altındaki eski kilit dosyasını elle silin. |
| 7. For sensitive file deletion, `secure-wipe` warns about SSD limitations before shredding. | 7. Hassas dosya silme için `secure-wipe`, shred öncesi SSD sınırlamaları hakkında uyarır. |

---

## 9. Technical Hardening Matrix / Teknik Sıkılaştırma Matrisi

| **Hardening Dimension** | **Implementation Detail** | **Sıkılaştırma Boyutu** | **Uygulama Detayı** |
|-------------------------|---------------------------|-------------------------|---------------------|
| **Strict Mode** | Every script enforces `set -Eeuo pipefail`, `IFS=$'\n\t'` to trap errors and prevent word splitting. | **Katı Mod** | Her betik hataları yakalamak ve kelime bölünmesini önlemek için `set -Eeuo pipefail`, `IFS=$'\n\t'` dayatır. |
| **Atomic Locking** | Kernel‑backed `flock` on a per‑tool lock file under `~/.local/run/locks/`, PID recorded for stale lock detection. | **Atomik Kilitleme** | Araç başına `~/.local/run/locks/` altında çekirdek destekli `flock`, bayat kilit tespiti için PID kaydedilir. |
| **Trap & Cleanup** | `trap cleanup EXIT INT TERM` guarantees lock release and temp file deletion even on Ctrl+C. | **Trap ve Temizlik** | `trap cleanup EXIT INT TERM`, Ctrl+C yapılsa dahi kilit salınımı ve geçici dosya silinmesini garantiler. |
| **Idempotence** | All scripts are safe to run 1000×; they check current state (e.g., module loaded, cache empty) before acting. | **Yinelenebilirlik** | Tüm betikler 1000 kez çalıştırılsa bile güvenlidir; işlem öncesi mevcut durumu kontrol eder (örn. modül yüklü mü, önbellek boş mu). |
| **Baseline Poisoning Prevention** | `rkhunter --propupd` and `aide --update` require explicit interactive confirmation. | **Temel Hattı Zehirlenmesi Engeli** | `rkhunter --propupd` ve `aide --update` açık etkileşimli onay gerektirir. |
| **Thermal Awareness** | `sys-thermal` reads hardware sensors; no script runs prolonged I/O loops that would overheat the Surface Pro 9. | **Isıl Farkındalık** | `sys-thermal` donanım sensörlerini okur; hiçbir betik Surface Pro 9’u aşırı ısıtacak uzun I/O döngüleri çalıştırmaz. |
| **SSD Wear Protection** | Wipe script warns about SSD FTL; `sys-suidscan` limits `find` to essential partitions (`/usr`, `/bin`, …), not full disk. | **SSD Aşınma Koruması** | Silme betiği SSD FTL hakkında uyarır; `sys-suidscan`, `find` taramasını tüm disk yerine temel bölümlerle sınırlar. |
| **Privilege Escalation Surface Reduction** | `perm-check` audits home directory permissions; `suid-tarama` lists SUID/SGID binaries. | **Yetki Yükseltme Yüzeyini Azaltma** | `perm-check` ev dizini izinlerini denetler; `suid-tarama` SUID/SGID ikili dosyalarını listeler. |
| **Log Integrity** | Every tool appends structured, timestamped logs to `~/Desktop/LOG_FILES/` for forensic audit. | **Log Bütünlüğü** | Her araç, adli denetim için `~/Desktop/LOG_FILES/` altına yapılandırılmış, zaman damgalı log ekler. |

---

*This suite is designed to meet the “Zero Error, High Speed, Maximum Security” mandate on a Fedora 44 / Surface Pro 9 single‑user workstation. Run `sysupdate` weekly, `rk-denetim` after major changes, and always check logs.*
*Bu paket, Fedora 44 / Surface Pro 9 tek kullanıcılı iş istasyonunda “Sıfır Hata, Yüksek Hız, Maksimum Güvenlik” ilkesini karşılamak üzere tasarlanmıştır. Haftalık `sysupdate` çalıştırın, büyük değişikliklerden sonra `rk-denetim` yapın ve her zaman logları kontrol edin.*
POTATO
