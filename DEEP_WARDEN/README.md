cat << 'EOF' > README.md
# Aegis Deep Warden - Weekly Security Audit & Hardening Framework

| **ENGLISH** | **TÜRKÇE** |
|-------------|------------|
| **Version:** 5.0.0-ELITE | **Sürüm:** 5.0.0-ELITE |
| **Author:** Dr. Ozhan Akdag & Senior Cyber Security Agent (Collaborative design) | **Yazar:** Dr. Ozhan Akdag & Kıdemli Siber Güvenlik Ajanı (Ortak tasarım) |
| **Target System:** Fedora 44 on Surface Pro 9 (Single user, no dual-boot) | **Hedef Sistem:** Surface Pro 9 üzerinde Fedora 44 (Tek kullanıcı, çift önyükleme yok) |
| **License:** MIT | **Lisans:** MIT |

---

## 1. Introduction

| **ENGLISH** | **TÜRKÇE** |
|-------------|------------|
| This project delivers a **military-grade, weekly deep‑scanning framework** that performs comprehensive security audits and hardware health checks. It integrates ClamAV, Rkhunter, AIDE, BTRFS scrub, SMART, and badblocks into a single idempotent, self‑hardening script. | Bu proje, kapsamlı güvenlik denetimleri ve donanım sağlığı kontrolleri yapan **askeri düzeyde, haftalık derin tarama çerçevesi** sunar. ClamAV, Rkhunter, AIDE, BTRFS scrub, SMART ve badblocks'u tek bir idempotent, kendi kendini sıkılaştıran betikte birleştirir. |
| **Primary goal:** Detect rootkits, viruses, filesystem corruption, bad sectors, and thermal anomalies without compromising system performance or SSD longevity. | **Birincil amaç:** Sistem performansından veya SSD ömründen ödün vermeden rootkit'leri, virüsleri, dosya sistemi bozulmalarını, bozuk sektörleri ve termal anomalileri tespit etmek. |
| The script is designed for **single‑user, production‑grade workstations** and follows zero‑tolerance for false positives. All operations are atomic, lock‑protected, and fully recoverable. | Betik **tek kullanıcılı, üretim kalitesindeki iş istasyonları** için tasarlanmıştır ve yanlış pozitif sonuçlara sıfır tolerans gösterir. Tüm işlemler atomik, kilit korumalı ve tamamen kurtarılabilirdir. |

---

## 2. Workspace & Dependencies

| **ENGLISH** | **TÜRKÇE** |
|-------------|------------|
| The script expects the following tools to be pre‑installed (they are checked at startup): | Betik, aşağıdaki araçların önceden kurulu olmasını bekler (başlangıçta kontrol edilir): |
| <code>freshclam</code>, <code>clamscan</code>, <code>rkhunter</code>, <code>aide</code>, <code>badblocks</code>, <code>smartctl</code>, <code>btrfs</code>, <code>findmnt</code>, <code>lsblk</code>. | <code>freshclam</code>, <code>clamscan</code>, <code>rkhunter</code>, <code>aide</code>, <code>badblocks</code>, <code>smartctl</code>, <code>btrfs</code>, <code>findmnt</code>, <code>lsblk</code>. |
| All heavy I/O is run with <code>ionice -c 3</code> and <code>nice -n 19</code> to minimise system impact. | Tüm ağır G/Ç işlemleri <code>ionice -c 3</code> ve <code>nice -n 19</code> ile çalıştırılarak sistem etkisi en aza indirilir. |
| **Runtime directories:** | **Çalışma zamanı dizinleri:** |
| - Lock directory: <code>/run/aegis/</code> | - Kilit dizini: <code>/run/aegis/</code> |
| - Log directory: <code>~/Desktop/LOG_FILES/</code> (created automatically) | - Log dizini: <code>~/Desktop/LOG_FILES/</code> (otomatik oluşturulur) |
| - Main log file: <code>deep_warden_master.log</code> | - Ana log dosyası: <code>deep_warden_master.log</code> |

---

## 3. Fetch the Script

| **ENGLISH** | **TÜRKÇE** |
|-------------|------------|
| Download the script directly from the repository: | Betiği doğrudan depodan indirin: |
| <code>curl -O https://raw.githubusercontent.com/Ozhana/Fedora_Hardening/main/AEGIS_DEEP_WARDEN/aegis-deep-warden.sh</code> | <code>curl -O https://raw.githubusercontent.com/Ozhana/Fedora_Hardening/main/AEGIS_DEEP_WARDEN/aegis-deep-warden.sh</code> |
| *If you have the script locally, copy it to your preferred directory.* | *Betik yerel olarak mevcutsa, tercih ettiğiniz dizine kopyalayın.* |

---

## 4. Permissions & Preparation

| **ENGLISH** | **TÜRKÇE** |
|-------------|------------|
| **Important:** The script must be run as <code>root</code> because it accesses low‑level devices and system files. | **Önemli:** Betik, düşük seviye aygıtlara ve sistem dosyalarına eriştiği için <code>root</code> olarak çalıştırılmalıdır. |
| Set executable permission: | Çalıştırma iznini ayarlayın: |
| <code>chmod +x aegis-deep-warden.sh</code> | <code>chmod +x aegis-deep-warden.sh</code> |
| (Optional) Verify the integrity using SHA‑256: | (İsteğe bağlı) SHA‑256 ile bütünlüğü doğrulayın: |
| <code>sha256sum aegis-deep-warden.sh</code> | <code>sha256sum aegis-deep-warden.sh</code> |

---

## 5. Execution & Usage Guide

| **ENGLISH** | **TÜRKÇE** |
|-------------|------------|
| Run the script with <code>sudo</code> (or as root): | Betiği <code>sudo</code> ile (veya root olarak) çalıştırın: |
| <code>sudo ./aegis-deep-warden.sh</code> | <code>sudo ./aegis-deep-warden.sh</code> |
| **Interactive Token:** The script will display a random token. You must type it exactly to proceed – this prevents accidental execution and adds a cognitive friction layer. | **Etkileşimli Token:** Betik rastgele bir token gösterecektir. Devam etmek için bunu aynen yazmalısınız – bu, kazara çalıştırmayı önler ve bilişsel sürtünme katmanı ekler. |
| **Cancellation:** Press <code>Ctrl+C</code> at any time; the script will safely unlock, terminate background processes, and clean up. | **İptal:** İstediğiniz zaman <code>Ctrl+C</code> tuşlayın; betik güvenli bir şekilde kilidi serbest bırakır, arka plan süreçlerini sonlandırır ve temizlik yapar. |
| **Typical duration:** 2–6 hours depending on disk size and speed (badblocks is the longest). | **Tipik süre:** Disk boyutuna ve hızına bağlı olarak 2–6 saat (badblocks en uzun olanıdır). |

---

## 6. What to Expect – Verification Commands

| **ENGLISH** | **TÜRKÇE** |
|-------------|------------|
| After a successful run, the script logs all findings in <code>~/Desktop/LOG_FILES/deep_warden_master.log</code>. | Başarılı bir çalıştırmadan sonra, betik tüm bulguları <code>~/Desktop/LOG_FILES/deep_warden_master.log</code> dosyasına kaydeder. |
| **Manual verification examples:** | **Manuel doğrulama örnekleri:** |
| - Check BTRFS scrub status:<br><code>btrfs scrub status /</code> | - BTRFS scrub durumunu kontrol edin:<br><code>btrfs scrub status /</code> |
| - View SMART health report:<br><code>smartctl -H /dev/nvme0n1</code> (adjust device name) | - SMART sağlık raporunu görüntüleyin:<br><code>smartctl -H /dev/nvme0n1</code> (cihaz adını ayarlayın) |
| - Review recent log entries:<br><code>tail -n 50 ~/Desktop/LOG_FILES/deep_warden_master.log</code> | - Son log girişlerini inceleyin:<br><code>tail -n 50 ~/Desktop/LOG_FILES/deep_warden_master.log</code> |
| - Check AIDE database integrity:<br><code>aide --check</code> | - AIDE veritabanı bütünlüğünü kontrol edin:<br><code>aide --check</code> |
| - List active locks:<br><code>ls -la /run/aegis/</code> | - Aktif kilitleri listeleyin:<br><code>ls -la /run/aegis/</code> |

---

## 7. Recovery & Rollback

| **ENGLISH** | **TÜRKÇE** |
|-------------|------------|
| The script is **read‑only** and does **not** modify system files or configuration. It only creates temporary lock files and log entries. | Betik **salt okunurdur** ve sistem dosyalarını veya yapılandırmasını **değiştirmez**. Sadece geçici kilit dosyaları ve log girişleri oluşturur. |
| Therefore, **no rollback is needed**. However, if you wish to manually clean up any leftovers: | Bu nedenle **geri alma gerekmez**. Ancak, manuel olarak artıkları temizlemek isterseniz: |
| - Remove lock file: <code>rm -f /run/aegis/deep-warden.lock</code> | - Kilit dosyasını silin: <code>rm -f /run/aegis/deep-warden.lock</code> |
| - Remove temporary scan results (if any): <code>rm -f /run/aegis/badblocks_*.tmp</code> | - Geçici tarama sonuçlarını silin (varsa): <code>rm -f /run/aegis/badblocks_*.tmp</code> |
| - Delete log directory if no longer needed: <code>rm -rf ~/Desktop/LOG_FILES</code> | - Log dizinini artık gerekmiyorsa silin: <code>rm -rf ~/Desktop/LOG_FILES</code> |
| **Important:** Never delete the lock file while the script is running – it is protected by PID verification. | **Önemli:** Betik çalışırken kilit dosyasını asla silmeyin – PID doğrulaması ile korunur. |

---

## 8. Technical Hardening Matrix

| **Area / Alan** | **Implementation / Uygulama** | **Benefit / Fayda** |
|-----------------|-------------------------------|----------------------|
| **Process Isolation** | Atomic <code>flock</code> on <code>/run/aegis/deep-warden.lock</code> | Prevents concurrent runs, eliminates race conditions |
| **Crash Recovery** | Full <code>trap</code> suite (EXIT, INT, TERM, ERR, HUP, QUIT) with <code>sync</code> and PID‑based lock release | Leaves no zombie processes or stale locks |
| **Thermal Damping** | Dynamic thermal monitoring; SIGSTOP/SIGCONT for background tasks; BTRFS scrub cancels/resumes on threshold breach | Protects Surface Pro 9 from overheating (threshold 82°C) |
| **False‑Positive Immunity** | Separate stdout/stderr for badblocks; exact regex anchors for ClamAV excludes | Zero false alerts; only real issues logged |
| **Idempotency** | All operations are stateless; repeated runs produce identical results without altering system state | Safe for cron or manual re‑execution |
| **Audit Trail** | Unified logging to <code>~/Desktop/LOG_FILES/</code> and systemd‑cat | Full forensic traceability |
| **Disk Resolution** | Uses <code>lsblk -no PKNAME</code> with fallback to raw partition | Works on NVMe, SATA, MMC, and unpartitioned disks |
| **Resource Throttling** | <code>ionice -c 3</code> + <code>nice -n 19</code> for every heavy sub‑process | Minimal interference with user workloads |

---

**End of README** – For support or contributions, please open an issue on the [GitHub repository](https://github.com/Ozhana/Fedora_Hardening).
EOF
