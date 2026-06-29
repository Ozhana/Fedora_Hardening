# AEGIS FAPOLICYD ENTERPRISE DEPLOYMENT V10.1

| **ENGLISH** | **TÜRKÇE** |
|-------------|------------|
| **Project Name:** Aegis Fapolicyd Enterprise Deployment | **Proje Adı:** Aegis Fapolicyd Kurumsal Dağıtımı |
| **Version:** V10.1 | **Sürüm:** V10.1 |
| **Author:** Dr. Ozhan Akdag & Senior Cyber Security Agent (Collaborative design) | **Yazar:** Dr. Özhan Akdağ & Kıdemli Siber Güvenlik Ajanı (Ortak tasarım) |
| **Date:** 2026-06-29 | **Tarih:** 2026-06-29 |
| **Target OS:** Fedora 44 (Fresh Installation) | **Hedef İşletim Sistemi:** Fedora 44 (Temiz Kurulum) |
| | |

---

## INTRODUCTION / GİRİŞ

| **ENGLISH** | **TÜRKÇE** |
|-------------|------------|
| This project provides an enterprise-grade, zero-fork deployment pipeline for Fapolicyd (File Access Policy Daemon) on Fedora 44. The solution addresses the critical issue where Fapolicyd's RPM and OSTREE backends are not supported on Fedora 44, causing the service to fail immediately after installation. | Bu proje, Fedora 44 üzerinde Fapolicyd (Dosya Erişim Politikası Hizmeti) için kurumsal düzeyde, sıfır-dallanma (zero-fork) bir dağıtım hattı sunar. Çözüm, Fapolicyd'nin RPM ve OSTREE arka uçlarının Fedora 44'te desteklenmemesi nedeniyle kurulumdan hemen sonra servisin başarısız olmasına yol açan kritik sorunu ele alır. |
| **Root Cause Analysis:** Fapolicyd V1.5 on Fedora 44 attempts to initialize RPM and OSTREE backends by default. However, these backends are either not compiled or incompatible with the kernel ABI, resulting in <code>rpm backend not supported, aborting!</code> or <code>ostree backend not supported, aborting!</code> errors. | **Kök Neden Analizi:** Fedora 44 üzerindeki Fapolicyd V1.5, varsayılan olarak RPM ve OSTREE arka uçlarını başlatmayı dener. Ancak bu arka uçlar ya derlenmemiştir ya da çekirdek ABI'sı ile uyumsuzdur, bu da <code>rpm backend not supported, aborting!</code> veya <code>ostree backend not supported, aborting!</code> hatalarına yol açar. |
| **Applied Solution:** The deployment forces <code>trust = file</code> backend, configures SELinux policies, initializes a clean trust database, and implements a robust rollback mechanism with 11 verified simulation scenarios. | **Uygulanan Çözüm:** Dağıtım, <code>trust = file</code> arka ucunu zorlar, SELinux politikalarını yapılandırır, temiz bir güven veritabanı başlatır ve 11 doğrulanmış simülasyon senaryosu ile sağlam bir geri alma mekanizması uygular. |
| | |

---

## WORKSPACE PREPARATION / ÇALIŞMA ALANI HAZIRLIĞI

| **ENGLISH** | **TÜRKÇE** |
|-------------|------------|
| **Prerequisites:** | **Ön Koşullar:** |
| - Fedora 44 clean installation | - Fedora 44 temiz kurulum |
| - Root or sudo access | - Root veya sudo erişimi |
| - Internet connection for package download | - Paket indirmesi için internet bağlantısı |
| | |
| **Create Workspace:** | **Çalışma Alanı Oluştur:** |
| <code>mkdir -p ~/aegis</code> | <code>mkdir -p ~/aegis</code> |
| <code>cd ~/aegis</code> | <code>cd ~/aegis</code> |
| | |

---

## FETCH SCRIPTS / BETİKLERİ İNDİR

| **ENGLISH** | **TÜRKÇE** |
|-------------|------------|
| **Primary Deployment Script (aegis-fapolicyd.sh):** | **Ana Dağıtım Betiği (aegis-fapolicyd.sh):** |
| This script performs the complete Fapolicyd installation, configuration, SELinux policy generation, and service activation. | Bu betik, Fapolicyd kurulumunu, yapılandırmasını, SELinux politikası oluşturmayı ve servis aktivasyonunu tam olarak gerçekleştirir. |
| | |
| <code>wget -O aegis-fapolicyd.sh https://raw.githubusercontent.com/Ozhana/Fedora_Hardening/main/FAPOLICYD/aegis-fapolicyd.sh</code> | <code>wget -O aegis-fapolicyd.sh https://raw.githubusercontent.com/Ozhana/Fedora_Hardening/main/FAPOLICYD/aegis-fapolicyd.sh</code> |
| | |
| **Telemetry Script (aegis-telemetry.sh):** | **Telemetri Betiği (aegis-telemetry.sh):** |
| This script installs a Systemd timer that generates daily audit reports, tracking all Fapolicyd denials and providing risk scoring. | Bu betik, günlük denetim raporları oluşturan, tüm Fapolicyd engellemelerini izleyen ve risk puanlaması sağlayan bir Systemd zamanlayıcısı kurar. |
| | |
| <code>wget -O aegis-telemetry.sh https://raw.githubusercontent.com/Ozhana/Fedora_Hardening/main/FAPOLICYD/aegis-telemetry.sh</code> | <code>wget -O aegis-telemetry.sh https://raw.githubusercontent.com/Ozhana/Fedora_Hardening/main/FAPOLICYD/aegis-telemetry.sh</code> |
| | |

---

## PERMISSIONS / YETKİLENDİRME

| **ENGLISH** | **TÜRKÇE** |
|-------------|------------|
| **Apply Execution Permissions:** | **Çalıştırma İzni Ver:** |
| <code>chmod +x aegis-fapolicyd.sh aegis-telemetry.sh</code> | <code>chmod +x aegis-fapolicyd.sh aegis-telemetry.sh</code> |
| | |

---

## EXECUTE / ÇALIŞTIR

| **ENGLISH** | **TÜRKÇE** |
|-------------|------------|
| **Step 1: Deploy Fapolicyd** | **Adım 1: Fapolicyd'yi Dağıt** |
| <code>sudo ./aegis-fapolicyd.sh</code> | <code>sudo ./aegis-fapolicyd.sh</code> |
| | |
| **What happens during execution:** | **Çalıştırma sırasında olanlar:** |
| - Installs fapolicyd package (plugin is skipped on Fedora 44)<br>- Creates directory structure with proper ownership<br>- Generates optimized configuration with <code>trust = file</code><br>- Cleans and initializes the trust database<br>- Builds SELinux policy from AVC logs<br>- Starts and enables the fapolicyd service<br>- Verifies Fanotify kernel hook | - fapolicyd paketini kurar (Fedora 44'te plugin atlanır)<br>- Doğru sahiplikle dizin yapısını oluşturur<br>- <code>trust = file</code> ile optimize edilmiş yapılandırma oluşturur<br>- Güven veritabanını temizler ve başlatır<br>- AVC loglarından SELinux politikası oluşturur<br>- fapolicyd servisini başlatır ve etkinleştirir<br>- Fanotify çekirdek kancasını doğrular |
| | |
| **Step 2: Deploy Telemetry** | **Adım 2: Telemetri'yi Dağıt** |
| <code>sudo ./aegis-telemetry.sh</code> | <code>sudo ./aegis-telemetry.sh</code> |
| | |
| **What happens during execution:** | **Çalıştırma sırasında olanlar:** |
| - Creates parser script at <code>/usr/local/bin/aegis-telemetry-parser.sh</code><br>- Installs Systemd service and timer<br>- Timer runs daily at 23:59<br>- Reports are saved to <code>/var/log/aegis/telemetry_YYYYMMDD.report</code> | - Ayrıştırıcı betiği <code>/usr/local/bin/aegis-telemetry-parser.sh</code> konumunda oluşturur<br>- Systemd servisi ve zamanlayıcısını kurar<br>- Zamanlayıcı her gün 23:59'da çalışır<br>- Raporlar <code>/var/log/aegis/telemetry_YYYYMMDD.report</code> konumuna kaydedilir |
| | |

---

## WHAT TO EXPECT / NE BEKLENMELİ

| **ENGLISH** | **TÜRKÇE** |
|-------------|------------|
| **After successful deployment, verify with:** | **Başarılı dağıtım sonrası şunlarla doğrulayın:** |
| | |
| <code>systemctl status fapolicyd</code> | <code>systemctl status fapolicyd</code> |
| <code>systemctl status aegis-telemetry.timer</code> | <code>systemctl status aegis-telemetry.timer</code> |
| <code>sudo fapolicyd-cli --check-status</code> | <code>sudo fapolicyd-cli --check-status</code> |
| | |
| **Expected Outputs:** | **Beklenen Çıktılar:** |
| - Fapolicyd: <code>Active: active (running)</code> | - Fapolicyd: <code>Active: active (running)</code> |
| - Telemetry: <code>Active: active (waiting)</code> with trigger time | - Telemetry: <code>Active: active (waiting)</code> tetikleme zamanı ile |
| - Trust Backend: <code>file</code> | - Güven Arka Ucu: <code>file</code> |
| - Permissive Mode: <code>1</code> (Telemetry phase) | - Permissive Mod: <code>1</code> (Telemetri aşaması) |
| | |
| **Generate First Telemetry Report:** | **İlk Telemetri Raporunu Oluştur:** |
| <code>sudo /usr/local/bin/aegis-telemetry-parser.sh</code> | <code>sudo /usr/local/bin/aegis-telemetry-parser.sh</code> |
| <code>sudo cat /var/log/aegis/telemetry_$(date +%Y%m%d).report</code> | <code>sudo cat /var/log/aegis/telemetry_$(date +%Y%m%d).report</code> |
| | |
| **Monitor Fapolicyd Logs:** | **Fapolicyd Loglarını İzle:** |
| <code>sudo journalctl -u fapolicyd -f</code> | <code>sudo journalctl -u fapolicyd -f</code> |
| <code>sudo journalctl -u fapolicyd -n 50 --no-pager</code> | <code>sudo journalctl -u fapolicyd -n 50 --no-pager</code> |
| | |

---

## TELEMETRY PHASE / TELEMETRİ AŞAMASI

| **ENGLISH** | **TÜRKÇE** |
|-------------|------------|
| **Duration:** 7-14 days | **Süre:** 7-14 gün |
| | |
| **Purpose:** The system operates in <code>permissive = 1</code> mode during this phase. Fapolicyd monitors all file access attempts and logs denials but does NOT block them. This allows you to: | **Amaç:** Sistem bu aşamada <code>permissive = 1</code> modunda çalışır. Fapolicyd tüm dosya erişim denemelerini izler ve engellemeleri loglar ancak BUNLARI ENGELLE MEZ. Bu size şunları yapma olanağı sağlar: |
| | |
| 1. Identify legitimate applications that might be incorrectly flagged | 1. Hatalı işaretlenebilecek meşru uygulamaları belirlemek |
| 2. Understand the application behavior pattern | 2. Uygulama davranış modelini anlamak |
| 3. Build trust rules before enforcing | 3. Engelleme öncesi güven kuralları oluşturmak |
| | |
| **Transition to Enforcing Mode:** | **Enforcing Moda Geçiş:** |
| After 7-14 days with no critical denials, switch to enforcing mode: | 7-14 gün boyunca kritik engelleme yoksa, enforcing moda geçin: |
| | |
| <code>sudo sed -i 's/permissive = 1/permissive = 0/' /etc/fapolicyd/fapolicyd.conf</code> | <code>sudo sed -i 's/permissive = 1/permissive = 0/' /etc/fapolicyd/fapolicyd.conf</code> |
| <code>sudo systemctl restart fapolicyd</code> | <code>sudo systemctl restart fapolicyd</code> |
| | |

---

## RECOVERY & ROLLBACK / KURTARMA VE GERİ ALMA

| **ENGLISH** | **TÜRKÇE** |
|-------------|------------|
| **If the system becomes unstable or applications are blocked incorrectly:** | **Sistem kararsız hale gelir veya uygulamalar hatalı engellenirse:** |
| | |
| **Option 1: Return to Permissive Mode** | **Seçenek 1: Permissif Moda Dön** |
| <code>sudo sed -i 's/permissive = 0/permissive = 1/' /etc/fapolicyd/fapolicyd.conf</code> | <code>sudo sed -i 's/permissive = 0/permissive = 1/' /etc/fapolicyd/fapolicyd.conf</code> |
| <code>sudo systemctl restart fapolicyd</code> | <code>sudo systemctl restart fapolicyd</code> |
| | |
| **Option 2: Stop Fapolicyd** | **Seçenek 2: Fapolicyd'yi Durdur** |
| <code>sudo systemctl stop fapolicyd</code> | <code>sudo systemctl stop fapolicyd</code> |
| <code>sudo systemctl disable fapolicyd</code> | <code>sudo systemctl disable fapolicyd</code> |
| | |
| **Option 3: Remove Fapolicyd** | **Seçenek 3: Fapolicyd'yi Kaldır** |
| <code>sudo systemctl stop fapolicyd</code> | <code>sudo systemctl stop fapolicyd</code> |
| <code>sudo systemctl disable fapolicyd</code> | <code>sudo systemctl disable fapolicyd</code> |
| <code>sudo dnf remove fapolicyd</code> | <code>sudo dnf remove fapolicyd</code> |
| <code>sudo rm -rf /var/lib/fapolicyd /etc/fapolicyd</code> | <code>sudo rm -rf /var/lib/fapolicyd /etc/fapolicyd</code> |
| | |
| **Option 4: Restore from Backup** | **Seçenek 4: Yedekten Geri Yükle** |
| If the deployment script created a backup: | Dağıtım betiği bir yedek oluşturduysa: |
| <code>sudo systemctl stop fapolicyd</code> | <code>sudo systemctl stop fapolicyd</code> |
| <code>sudo rm -rf /etc/fapolicyd</code> | <code>sudo rm -rf /etc/fapolicyd</code> |
| <code>sudo cp -a /etc/fapolicyd_bak_* /etc/fapolicyd</code> | <code>sudo cp -a /etc/fapolicyd_bak_* /etc/fapolicyd</code> |
| <code>sudo systemctl start fapolicyd</code> | <code>sudo systemctl start fapolicyd</code> |
| | |
| **For SELinux Issues:** | **SELinux Sorunları İçin:** |
| <code>sudo setenforce 0</code> | <code>sudo setenforce 0</code> |
| <code>sudo ausearch -m avc -ts recent \| audit2allow -M fapolicyd-fix</code> | <code>sudo ausearch -m avc -ts recent \| audit2allow -M fapolicyd-fix</code> |
| <code>sudo semodule -i fapolicyd-fix.pp</code> | <code>sudo semodule -i fapolicyd-fix.pp</code> |
| <code>sudo setenforce 1</code> | <code>sudo setenforce 1</code> |

---

## FILES AND PATHS / DOSYALAR VE YOLLAR

| **ENGLISH** | **TÜRKÇE** |
|-------------|------------|
| **Configuration:** <code>/etc/fapolicyd/fapolicyd.conf</code> | **Yapılandırma:** <code>/etc/fapolicyd/fapolicyd.conf</code> |
| **Rules Directory:** <code>/etc/fapolicyd/rules.d/</code> | **Kurallar Dizini:** <code>/etc/fapolicyd/rules.d/</code> |
| **Trust Database:** <code>/var/lib/fapolicyd/trust.db</code> | **Güven Veritabanı:** <code>/var/lib/fapolicyd/trust.db</code> |
| **Telemetry Reports:** <code>/var/log/aegis/telemetry_*.report</code> | **Telemetri Raporları:** <code>/var/log/aegis/telemetry_*.report</code> |
| **Parser Script:** <code>/usr/local/bin/aegis-telemetry-parser.sh</code> | **Ayrıştırıcı Betiği:** <code>/usr/local/bin/aegis-telemetry-parser.sh</code> |
| **Systemd Service:** <code>/etc/systemd/system/aegis-telemetry.service</code> | **Systemd Servisi:** <code>/etc/systemd/system/aegis-telemetry.service</code> |
| **Systemd Timer:** <code>/etc/systemd/system/aegis-telemetry.timer</code> | **Systemd Zamanlayıcı:** <code>/etc/systemd/system/aegis-telemetry.timer</code> |
| | |

---

## TECHNICAL HARDENING MATRIX / TEKNİK SIKILAŞTIRMA MATRİSİ

### ENGLISH

| **Component** | **Configuration** | **Security Impact** |
|---------------|-------------------|---------------------|
| **Trust Backend** | <code>trust = file</code> | Forces file-based trust instead of unsupported RPM/OSTREE backends. Prevents service failure on Fedora 44. |
| **Permissive Mode** | <code>permissive = 1</code> | Initial telemetry phase. Logs all denials without blocking. Allows safe rule building. |
| **Integrity** | <code>integrity = sha256</code> | Cryptographic verification of trusted files. Ensures file integrity. |
| **q_size** | <code>q_size = 8192</code> | Queue size optimized for Fedora 44. Prevents memory exhaustion. |
| **detailed_report** | <code>detailed_report = 0</code> | Disables verbose reporting. Improves performance. |
| **SELinux** | Custom policy module | Resolves AVC denials for GNOME Display Manager socket access. |
| **Fanotify** | Kernel-level hook | Provides real-time file access monitoring with minimal overhead. |
| **Systemd Timer** | Daily at 23:59 | Automated auditing with persistent scheduling. |

### TÜRKÇE

| **Bileşen** | **Yapılandırma** | **Güvenlik Etkisi** |
|-------------|------------------|----------------------|
| **Güven Arka Ucu** | <code>trust = file</code> | Desteklenmeyen RPM/OSTREE arka uçları yerine dosya tabanlı güveni zorlar. Fedora 44'te servis hatasını önler. |
| **Permissif Mod** | <code>permissive = 1</code> | Başlangıç telemetri aşaması. Tüm engellemeleri engellemeden loglar. Güvenli kural oluşturmaya olanak tanır. |
| **Bütünlük** | <code>integrity = sha256</code> | Güvenilir dosyaların kriptografik doğrulaması. Dosya bütünlüğünü garanti eder. |
| **q_size** | <code>q_size = 8192</code> | Fedora 44 için optimize edilmiş kuyruk boyutu. Bellek tükenmesini önler. |
| **detailed_report** | <code>detailed_report = 0</code> | Ayrıntılı raporlamayı devre dışı bırakır. Performansı artırır. |
| **SELinux** | Özel politika modülü | GNOME Display Manager soket erişimi için AVC engellemelerini çözer. |
| **Fanotify** | Çekirdek seviyesi kancası | Düşük ek yük ile gerçek zamanlı dosya erişim izleme sağlar. |
| **Systemd Zamanlayıcı** | Her gün 23:59'da | Kalıcı zamanlama ile otomatik denetim. |

---

## VALIDATION COMMANDS / DOĞRULAMA KOMUTLARI

| **ENGLISH** | **TÜRKÇE** |
|-------------|------------|
| <code>systemctl status fapolicyd</code> | <code>systemctl status fapolicyd</code> |
| <code>systemctl status aegis-telemetry.timer</code> | <code>systemctl status aegis-telemetry.timer</code> |
| <code>sudo fapolicyd-cli --check-status</code> | <code>sudo fapolicyd-cli --check-status</code> |
| <code>sudo fapolicyd-cli --check-config</code> | <code>sudo fapolicyd-cli --check-config</code> |
| <code>sudo fapolicyd-cli --dump-db \| head -20</code> | <code>sudo fapolicyd-cli --dump-db \| head -20</code> |
| <code>sudo journalctl -u fapolicyd -n 20 --no-pager</code> | <code>sudo journalctl -u fapolicyd -n 20 --no-pager</code> |
| <code>getenforce</code> | <code>getenforce</code> |
| <code>sudo ausearch -m avc -ts recent</code> | <code>sudo ausearch -m avc -ts recent</code> |
| <code>sudo /usr/local/bin/aegis-telemetry-parser.sh</code> | <code>sudo /usr/local/bin/aegis-telemetry-parser.sh</code> |
| <code>sudo cat /var/log/aegis/telemetry_$(date +%Y%m%d).report</code> | <code>sudo cat /var/log/aegis/telemetry_$(date +%Y%m%d).report</code> |

---

## TROUBLESHOOTING / SORUN GİDERME

| **ENGLISH** | **TÜRKÇE** |
|-------------|------------|
| **Issue: "rpm backend not supported"** | **Sorun: "rpm backend not supported"** |
| **Solution:** Ensure <code>trust = file</code> is set in <code>/etc/fapolicyd/fapolicyd.conf</code> | **Çözüm:** <code>/etc/fapolicyd/fapolicyd.conf</code> dosyasında <code>trust = file</code> ayarlandığından emin olun |
| | |
| **Issue: "Permission denied" on socket** | **Sorun: Sokette "Permission denied"** |
| **Solution:** Generate SELinux policy with <code>ausearch -m avc -ts recent \| audit2allow -M fapolicyd-fix</code> | **Çözüm:** <code>ausearch -m avc -ts recent \| audit2allow -M fapolicyd-fix</code> ile SELinux politikası oluşturun |
| | |
| **Issue: Service fails to start** | **Sorun: Servis başlamıyor** |
| **Solution:** Check logs with <code>sudo journalctl -u fapolicyd -n 50 --no-pager</code> and verify <code>trust = file</code> | **Çözüm:** <code>sudo journalctl -u fapolicyd -n 50 --no-pager</code> ile logları kontrol edin ve <code>trust = file</code> doğrulayın |
| | |
| **Issue: Telemetry not generating reports** | **Sorun: Telemetri rapor oluşturmuyor** |
| **Solution:** <code>sudo systemctl restart aegis-telemetry.timer</code> and <code>sudo /usr/local/bin/aegis-telemetry-parser.sh</code> | **Çözüm:** <code>sudo systemctl restart aegis-telemetry.timer</code> ve <code>sudo /usr/local/bin/aegis-telemetry-parser.sh</code> |

---

## LICENSE / LİSANS

| **ENGLISH** | **TÜRKÇE** |
|-------------|------------|
| This project is provided under the MIT License. See the LICENSE file for details. | Bu proje MIT Lisansı altında sunulmaktadır. Ayrıntılar için LICENSE dosyasına bakın. |
| | |
| **Disclaimer:** This software is provided "as is", without warranty of any kind. Use at your own risk. Always test in a non-production environment first. | **Sorumluluk Reddi:** Bu yazılım "olduğu gibi" sağlanır, herhangi bir garanti verilmez. Kendi sorumluluğunuzda kullanın. Her zaman önce üretim dışı ortamda test edin. |
| | |

---

## CONTRIBUTING / KATKI SAĞLAMA

| **ENGLISH** | **TÜRKÇE** |
|-------------|------------|
| Contributions are welcome! Please submit issues and pull requests on GitHub. | Katkılar memnuniyetle karşılanır! Lütfen GitHub üzerinden sorun bildirin ve çekme istekleri gönderin. |
| | |
| **Contact:** Dr. Ozhan Akdag & Senior Cyber Security Agent | **İletişim:** Dr. Özhan Akdağ & Kıdemli Siber Güvenlik Ajanı |
| | |

---

**END OF DOCUMENT / BELGE SONU**
