# USBGuard Safe Authorizer

## Zero-Trust USB Device Authorization Framework

| ENGLISH | TÜRKÇE |
| :--- | :--- |
| **Project Overview** | **Proje Özeti** |
| This repository provides a hardened, zero-trust approach to managing USB connectivity on Linux systems, specifically tailored for Fedora. By leveraging `USBGuard` and kernel-level unbind protocols, it ensures that unauthorized USB devices cannot communicate with your system. | Bu depo, Linux sistemlerinde (özellikle Fedora için optimize edilmiş) USB bağlantılarını yönetmek için güçlendirilmiş, sıfır güven (zero-trust) odaklı bir yaklaşım sunar. `USBGuard` ve çekirdek seviyesindeki bağlantı koparma (unbind) protokollerini kullanarak, yetkisiz USB cihazlarının sisteminize sızmasını engeller. |
| **Why This Matters** | **Neden Önemli?** |
| Standard USB management often fails to handle modern high-speed controllers (UAS) or block devices properly while they are in use. Our scripts provide an atomic, failure-proof method to safely unbind and re-enable USB ports without risking kernel panics or data corruption. | Standart USB yönetimi, modern yüksek hızlı denetleyicileri (UAS) veya kullanım halindeki blok cihazları düzgün bir şekilde engellemekte genellikle yetersiz kalır. Betiklerimiz, çekirdek paniklerine veya veri bozulmalarına yol açmadan, USB portlarını güvenli bir şekilde devreden çıkarma ve yeniden etkinleştirme konusunda atomik, hataya dayanıklı bir yöntem sunar. |
| **Key Features** | **Temel Özellikler** |
| 1. **Kernel-Level Unbind**: Forces disconnection of devices even when standard `modprobe` commands report "in use". | 1. **Çekirdek Seviyesi Bağlantı Koparma**: Standart `modprobe` komutları "kullanımda" hatası verse bile cihazların bağlantısını zorla koparır. |
| 2. **Atomic Execution**: Prevents partial configuration states and ensures system stability. | 2. **Atomik Yürütme**: Kısmi yapılandırma durumlarını engeller ve sistem kararlılığını garanti eder. |
| 3. **Enterprise-Grade Security**: Designed for privacy-focused setups and zero-trust environments. | 3. **Kurumsal Düzey Güvenlik**: Gizlilik odaklı kurulumlar ve sıfır güven ortamları için tasarlanmıştır. |
| **How to Install** | **Nasıl Kurulur** |
| 1. Clone the repository to your local machine. 2. Move the provided scripts to `/usr/local/bin/`. 3. Grant execute permissions (`chmod +x`). 4. Ensure `usbguard` daemon is active and configured correctly. | 1. Depoyu yerel makinenize kopyalayın. 2. Sağlanan betikleri `/usr/local/bin/` dizinine taşıyın. 3. Çalıştırma izinlerini verin (`chmod +x`). 4. `usbguard` daemon'ının aktif olduğundan ve doğru yapılandırıldığından emin olun. |
