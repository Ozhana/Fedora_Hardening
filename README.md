# ENGLISH ------ TURKCE
| English | Türkçe |
| :--- | :--- |
| Terminolojiyi (Defensive Scripting, Human-in-the-loop, Idempotent, False Positives) tamamen küresel siber güvenlik standartlarına uygun bir İngilizceye çevirdim. Al ve bu başyapıtı dünyayla paylaş! <br>🛡️ Fedora 44 Universal Enterprise Armor (The Terminus Protocol)<br><br>This project is an Exemplary Hardening and Educational Script designed to transform a standard Fedora 44 installation into an Enterprise-Grade, ironclad workstation built strictly on Zero-Trust and Zero-Defect principles.<br><br>It is the result of rigorous "Red Team" analysis, hardware optimization tests, and cryptographic verification processes. It has been open-sourced to benefit the cybersecurity community and Linux enthusiasts who refuse to settle for standard security baselines.<br>📖 Our Philosophy: Why is this script different?<br><br>Most "post-install" scripts you find online fall into the Statistical Average trap. They use dirty hacks like || true to sweep errors under the rug, assume all hardware configurations are identical, and blindly modify system states without verifying them first.<br><br>Our core philosophy is "Don't Assume, Verify"...<br><br> Defensive Scripting: This script explicitly checks if a package or service actually exists before attempting to remove or mask it. It does not swallow errors; if there is a critical failure (like a network drop or a broken RPM database), it halts gracefully and reports the exact point of failure.<br><br>    Human-in-the-Loop: For irreversible or highly restrictive seals (e.g., generating USBGuard policies), the script pauses and explicitly demands physical user confirmation. No automation blindness.<br><br>    Idempotent Architecture: You can execute this script 1000 times, and it will never bloat your configuration files or cause race conditions. It uses atomic locks (flock) and strict state checking.<br><br>✨ Enterprise-Grade Features<br><br>    🔐 Cryptographic LUKS2 / TPM 2.0 Verification: It doesn't just check if a TPM chip exists; it explicitly probes the hardware to ensure your LUKS disk encryption keys are actively bound to PCR 0, 7, and 11 (SecureBoot & Kernel parameters).<br><br>    🛑 Strict Error Management & Omni-Logger: Written under the unforgiving set -Eeuo pipefail rule. Every standard output and error is synchronously multiplexed into a locked log file (/var/log/fedora_terminus_...).<br><br>    🛡️ Fapolicyd & OSTree Trust Backend: Enforces extreme application whitelisting. Only trusted RPM and Flatpak (via native OSTree backend) binaries are allowed to execute. Ransomware or rogue scripts downloaded to your home directory will be instantly blocked at the kernel level.<br><br>    🔌 USBGuard Shield: Mitigates BadUSB (Rubber Ducky) attacks. Unapproved USB devices are blocked at the kernel/electrical level.<br><br>    👁️ Network Ghost Mode: MAC address randomization, strict IPv6 leak prevention, DNS-over-TLS (via Quad9 DNSSEC), and ICMP dropping.<br><br>    💤 Dynamic Sleep Seal (Hardware Agnostic): Instead of using hardcoded device names, it scans your specific ACPI tree using Regex. It preserves essential wake triggers (Power Button, Lid Switch) while blinding all other parasitic hardware interrupts that drain battery during suspend.<br><br>    🕵️ Cyber Auditors & Baselining: Installs Rkhunter (with unhide), ClamAV, and AIDE. Automatically captures the pristine cryptographic fingerprint (Baseline) of your system. (Achieves a Lynis Audit Score of 81+).<br><br>⚙️ Requirements<br>    A clean, updated installation of Fedora 44.<br><br>    Active Internet connection.<br>    A user with sudo (root) privileges.<br>    Disks encrypted with LUKS (Highly Recommended for passing the TPM checks).<br>🚀 Installation & Usage<br><br>    ⚠️ CRITICAL WARNING: Before running this script, ensure ALL your trusted, everyday USB devices (Keyboard, Mouse, Dock, Type Cover) are physically plugged in. Otherwise, USBGuard will treat them as rogue devices upon reboot.<br><br>    Open your terminal and create the script file:
```Bash

nano fedora_universal_armor.sh
```
# Paste the code, then save and exit (CTRL+O, Enter, CTRL+X)

    Make the script executable:

```Bash

chmod +x fedora_universal_armor.sh
```

    Ignite the armor protocol:

```Bash

sudo ./fedora_universal_armor.sh
```

📝 Post-Flight Red Team Notes

    Fapolicyd is Active: Any standalone binary, AppImage, or Python script you download manually will be blocked by default. To trust a specific file, you must explicitly whitelist it: sudo fapolicyd-cli --file add /path/to/file --trust-file allowed_apps followed by sudo fapolicyd-cli --update.

    Zero Blind Spots: Useless background daemon autonomy has been revoked. The infamous cups-browsed (source of recent RCE vulnerabilities) is completely masked.

    Firmware Autonomy Revoked: The fwupd background polling timer has been disabled to eliminate zero-value CPU wakeups. To update your BIOS/TPM firmware, you must now do it manually by executing sudo fwupdmgr refresh and update.

⚖️ Disclaimer

This project is provided for educational purposes to demonstrate hardcore Linux hardening, Zero-Trust architectures, and Defensive Scripting methodologies. Please READ AND UNDERSTAND the code before executing it on your personal or corporate machines. The author assumes no liability for data loss, system lockouts, or broken configurations. Don't assume, verify. | #🛡️ Fedora 44 Universal Enterprise Armor (The Terminus Protocol)

Bu proje, Fedora 44 işletim sistemini standart bir ev kullanıcısı profilinden çıkarıp, "Sıfır Güven" (Zero-Trust) ve "Sıfır Hata" (Zero-Defect) prensipleriyle çalışan, kurumsal düzeyde (Enterprise-Grade) zırhlanmış bir iş istasyonuna dönüştürmek için hazırlanmış bir Örnek Kurulum ve Eğitim Betiğidir.

Siber güvenlik topluluğuna ve Linux sevdalılarına faydalı olması amacıyla, aylar süren "Kırmızı Takım" (Red Team) analizleri, donanım optimizasyon testleri ve kriptografik doğrulama süreçleri sonucunda açık kaynak olarak paylaşılmıştır.
📖 Felsefemiz: Neden Bu Betik Farklı?

İnternette bulabileceğiniz standart "Kurulum Sonrası (Post-Install)" betiklerinin çoğu İstatistiksel Ortalama tuzağına düşer; yani hataları halı altına süpürür (\|\| true kullanarak), her bilgisayarı aynı sanır ve sistemin çalışma mantığına körü körüne müdahale eder.

Bizim felsefemiz ise "Varsayımda Bulunma, Doğrula" (Don't Assume, Verify) ilkesidir:

    Defensive Scripting (Savunmacı Yazılım): Bu kod, bir servisi kapatmadan veya bir paketi silmeden önce sistemde gerçekten var olup olmadığını kontrol eder. Hataları yutmaz; bir sorun varsa mertçe işlemi durdurur ve size rapor verir.

    Human-in-the-Loop (İnsan Onayı): Sisteme kalıcı olarak mühür vuracak (USBGuard gibi) uygulamalar kurulurken işlem duraklatılır ve kullanıcının fiziksel onayı istenir.

    Idempotent Mimari: Bu betiği 1000 kere de çalıştırsanız sistem dosyalarınız şişmez, ayarlarınız bozulmaz.

✨ Öne Çıkan Kurumsal Özellikler

    🔐 Kriptografik LUKS2 / TPM 2.0 Doğrulaması: Sisteminizin sadece TPM'e sahip olup olmadığını değil, diskinizin şifreleme anahtarlarının doğrudan PCR 0, 7 ve 11 bankalarına kilitli (Binding) olup olmadığını donanım seviyesinde test eder.

    🛑 Katı Hata Yönetimi ve Omni-Logger: Bash'in en acımasız kuralı olan set -Eeuo pipefail ile yazılmıştır. Her işlem nanosaniyesine kadar izole edilmiş bir log dosyasına (/var/log/fedora_terminus_...) kaydedilir.

    🛡️ Fapolicyd & OSTree Trust Backend: Sisteminize sadece güvendiğiniz RPM ve Flatpak (OSTree) uygulamalarının çalışmasına izin verir. Dışarıdan indirilen hiçbir fidye yazılımı (Ransomware) veya zararlı betik RAM'e ulaşamaz.

    🔌 USBGuard Kalkanı: BadUSB (Rubber Ducky) saldırılarına karşı, onaylamadığınız hiçbir USB aygıtı (klavye ve fare gibi görünse bile) sisteme elektrik seviyesinde erişemez.

    👁️ Ağ Hayalet Modu: MAC adresi rastgeleleştirme, IPv6 veri sızıntı koruması, DNS-over-TLS (Quad9 DNSSEC) ve ICMP (Ping) kalkanı.

    💤 Dinamik Uyku Mühürü (Donanım Bağımsız): Surface, Lenovo, Dell fark etmeksizin sistemin ACPI ağacını tarar; sadece Güç Tuşu ve Kapak sensörü gibi hayati donanımları uyanık bırakıp, çantada bilgisayarı uyandırarak pili sömüren tüm hayalet donanımları kör eder.

    🕵️ Siber Denetçiler: Rkhunter, Unhide, ClamAV ve AIDE kurularak, sistemin o anki en saf, en temiz halinin kriptografik parmak izi (Baseline) alınır. (Lynis Skoru: 81+)

⚙️ Gereksinimler

    Temiz kurulmuş, güncel bir Fedora 44 İşletim Sistemi.

    İnternet bağlantısı.

    sudo (root) yetkilerine sahip bir kullanıcı.

🚀 Kurulum ve Kullanım

    ⚠️ UYARI: Bu betiği çalıştırmadan önce lütfen bilgisayarınıza kullandığınız tüm güvenilir USB cihazlarını (Klavye, Fare, Hub, Type Cover vb.) taktığınızdan emin olun. Aksi takdirde USBGuard bunları yabancı cihaz sanıp engelleyecektir.

    Terminali açın ve betiği indirin (veya kopyalayıp fedora_armor.sh olarak kaydedin):

```Bash

nano fedora_armor.sh
```
# Kodları içine yapıştırıp CTRL+O, Enter, CTRL+X ile çıkın.

    Betiğe çalışma izni verin:

```Bash

chmod +x fedora_armor.sh
```

    Kurşungeçirmez zırhı başlatın:

```Bash

sudo ./fedora_armor.sh
```

📝 Kurulum Sonrası Notlar (Kırmızı Takım'dan Uyarılar)

    Fapolicyd Çalışıyor: Artık internetten rastgele indirdiğiniz bir Python betiği veya .AppImage dosyası tıklasanız da çalışmayacaktır. Bir yazılıma güveniyorsanız manuel olarak beyaz listeye almalısınız: sudo fapolicyd-cli --file add /dosya/yolu --trust-file izinli_dosya ve ardından sudo fapolicyd-cli --update.

    Kör Nokta Bırakılmadı: Kapanış süresini uzatan zombi servisler kapatıldı. CUPS RCE zafiyetlerine yol açan cups-browsed tamamen maskelendi.

    Firmware Güncellemeleri: fwupd servisinin arka planda pili sömüren otonomisi iptal edildi. Artık BIOS/TPM güncellemeleri için terminalden sudo fwupdmgr refresh ve update yazmanız gerekmektedir.

⚖️ Sorumluluk Reddi (Disclaimer)

Bu proje eğitim (educational) amacıyla ve siber güvenlik konseptlerini (Hardening, Zero-Trust, Defensive Scripting) Linux meraklılarına uygulamalı olarak göstermek için hazırlanmıştır. Kurumsal ağlarda veya kişisel cihazlarınızda kullanmadan önce kodları okumanız ve ne işe yaradıklarını anlamanız tavsiye edilir. Meydana gelebilecek veri kayıpları veya sistem erişim sorunlarında tüm sorumluluk kullanıcıya aittir. Varsayımda bulunmayın, doğrulayın. |
