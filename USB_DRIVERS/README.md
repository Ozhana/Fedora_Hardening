# USBGuard Safe Authorizer

## Zero-Trust USB Device Authorization Framework

| ENGLISH | TÜRKÇE |
| :--- | :--- |
| **Project Purpose:** This toolkit provides a robust, zero-trust approach to managing USB ports on Linux systems, specifically designed for Fedora. It moves beyond standard software-level blocking to implement kernel-level control, mitigating risks from malicious hardware (BadUSB/Rubber Ducky). | **Proje Amacı:** Bu araç seti, Linux sistemlerinde (özellikle Fedora) USB portlarını yönetmek için sıfır güven (zero-trust) prensibiyle çalışan sağlam bir yaklaşım sunar. Standart yazılım seviyesindeki engellemenin ötesine geçerek, çekirdek seviyesinde kontrol sağlar ve kötü niyetli donanımlardan (BadUSB/Rubber Ducky) kaynaklanan riskleri azaltır. |
| **Components:** <ul><li>`usb-ac.sh`: Safely enables USB storage/UAS modules.</li><li>`usb-kapat.sh`: Executes a forced, kernel-level unbind and unloads modules to secure the system.</li></ul> | **Bileşenler:** <ul><li>`usb-ac.sh`: USB depolama/UAS modüllerini güvenli bir şekilde etkinleştirir.</li><li>`usb-kapat.sh`: Sistemi güvenceye almak için zorunlu, çekirdek seviyesinde bağlantı koparma (unbind) yapar ve modülleri kaldırır.</li></ul> |
| **Installation:** Copy both files into `~/.local/bin/` (create the directory if it does not exist) and ensure they are executable: `chmod +x ~/.local/bin/usb-*.sh`. Add `export PATH="$PATH:$HOME/.local/bin"` to your `~/.bashrc`. | **Kurulum:** Her iki dosyayı da `~/.local/bin/` dizinine kopyalayın (yoksa oluşturun) ve çalıştırılabilir olduklarından emin olun: `chmod +x ~/.local/bin/usb-*.sh`. `~/.bashrc` dosyanıza `export PATH="$PATH:$HOME/.local/bin"` satırını ekleyin. |
| **Usage:** Run `usb-ac` to open ports, and `usb-kapat` when you need to lock them down. | **Kullanım:** Portları açmak için `usb-ac`, kilitlemek istediğinizde `usb-kapat` komutlarını çalıştırın. |
