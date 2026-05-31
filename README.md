# ENGLISH ------ TURKCE

| :--- | :--- |
| | #🛡️ Fedora 44 Universal Enterprise Armor (The Terminus Protocol)

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
