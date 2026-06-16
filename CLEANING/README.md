# Aegis Docker Network Isolation - V6.0

| **ENGLISH** | **TÜRKÇE** |
|:---|:---|
| **Introduction** | **Giriş** |
| This project provides a **hardened network isolation layer** for Docker containers on Fedora systems. It prevents Docker from bypassing firewalld rules via its implicit DNAT rules, ensuring that all container traffic is subject to the host firewall policies. | Bu proje, Fedora sistemlerinde Docker konteynerleri için **sıkılaştırılmış bir ağ izolasyon katmanı** sağlar. Docker'ın örtük DNAT kurallarıyla firewalld'yi baypas etmesini engeller ve tüm konteyner trafiğinin ana bilgisayar güvenlik duvarı politikalarına tabi olmasını garanti eder. |
| **The Problem** | **Sorun** |
| Docker’s default bridge network uses <code>iptables</code> DNAT rules that redirect incoming traffic directly to containers, effectively bypassing firewalld’s zone-based filtering. This creates a security gap where exposed container ports are accessible even if firewalld denies them. | Docker'ın varsayılan köprü ağı, gelen trafiği doğrudan konteynerlere yönlendiren <code>iptables</code> DNAT kuralları kullanır ve böylece firewalld'nin bölge tabanlı filtrelemesini etkili bir şekilde baypas eder. Bu, firewalld izin vermese bile konteyner bağlantı noktalarına erişilebilir olduğu için bir güvenlik açığı oluşturur. |
| **The Solution** | **Çözüm** |
| 1. Bind Docker daemon to <code>127.0.0.1</code> so that published ports are only reachable from localhost.<br>2. Use a dedicated <code>DOCKER-USER</code> chain in firewalld’s direct rules to drop any forwarded traffic not originating from allowed sources.<br>3. Apply these settings persistently across reboots. | 1. Docker daemon'unu <code>127.0.0.1</code>'e bağlayarak yayınlanan bağlantı noktalarına yalnızca localhost'tan erişilebilir hale getirir.<br>2. Firewalld'nin doğrudan kurallarında özel bir <code>DOCKER-USER</code> zinciri kullanarak izin verilen kaynaklardan gelmeyen yönlendirilmiş trafiği düşürür.<br>3. Bu ayarları yeniden başlatmalar arasında kalıcı olarak uygular. |
| **Workspace** | **Çalışma Alanı** |
| - OS: Fedora 44 (or any RHEL-based distribution)<br>- Docker Engine (latest stable)<br>- Firewalld (active and running)<br>- Root or sudo access | - İşletim Sistemi: Fedora 44 (veya herhangi bir RHEL tabanlı dağıtım)<br>- Docker Motoru (en son kararlı sürüm)<br>- Firewalld (etkin ve çalışır durumda)<br>- Root veya sudo erişimi |
| **Fetch the Script** | **Betiği İndirme** |
| The official script is hosted on GitHub. Use the following command to download it directly to <code>/usr/local/bin</code>: | Resmi betik GitHub'da barındırılmaktadır. Doğrudan <code>/usr/local/bin</code> dizinine indirmek için aşağıdaki komutu kullanın: |
| <code>sudo curl -o /usr/local/bin/aegis-docker-fw.sh https://raw.githubusercontent.com/Ozhana/Fedora_Hardening/main/DOCKER_NETWORK_ISOLATION/aegis-docker-fw.sh</code> | <code>sudo curl -o /usr/local/bin/aegis-docker-fw.sh https://raw.githubusercontent.com/Ozhana/Fedora_Hardening/main/DOCKER_NETWORK_ISOLATION/aegis-docker-fw.sh</code> |
| **Permissions** | **Yetkilendirme** |
| Make the script executable and ensure it is owned by root: | Betiği çalıştırılabilir yapın ve root sahipliğinde olduğundan emin olun: |
| <code>sudo chmod 700 /usr/local/bin/aegis-docker-fw.sh</code><br><code>sudo chown root:root /usr/local/bin/aegis-docker-fw.sh</code> | <code>sudo chmod 700 /usr/local/bin/aegis-docker-fw.sh</code><br><code>sudo chown root:root /usr/local/bin/aegis-docker-fw.sh</code> |
| **Execution** | **Çalıştırma** |
| Run the script with root privileges. It will apply the hardening rules and verify the changes. | Betiği root yetkileriyle çalıştırın. Sıkılaştırma kurallarını uygulayacak ve değişiklikleri doğrulayacaktır. |
| <code>sudo /usr/local/bin/aegis-docker-fw.sh</code> | <code>sudo /usr/local/bin/aegis-docker-fw.sh</code> |
| **What to Expect** | **Ne Beklemeli** |
| After execution, the script will:<br>- Modify <code>/etc/docker/daemon.json</code> to set <code>"hosts": ["tcp://127.0.0.1:2376", "unix:///var/run/docker.sock"]</code><br>- Add firewall direct rules to <code>/etc/firewalld/direct.xml</code> that secure the <code>DOCKER-USER</code> chain.<br>- Restart Docker and firewalld services.<br>- Display a summary of the applied rules and verification commands. | Betik çalıştırıldıktan sonra:<br>- <code>/etc/docker/daemon.json</code> dosyasını <code>"hosts": ["tcp://127.0.0.1:2376", "unix:///var/run/docker.sock"]</code> olarak değiştirir.<br>- <code>/etc/firewalld/direct.xml</code> dosyasına <code>DOCKER-USER</code> zincirini güvence altına alan doğrudan kurallar ekler.<br>- Docker ve firewalld servislerini yeniden başlatır.<br>- Uygulanan kuralların ve doğrulama komutlarının bir özetini gösterir. |
| **Verification** | **Doğrulama** |
| After the script finishes, you can verify the hardening with these commands: | Betik bittikten sonra, sıkılaştırmayı aşağıdaki komutlarla doğrulayabilirsiniz: |
| <code>ss -tulpn \| grep docker</code> – shows that Docker is only listening on localhost.<br><code>iptables -v -L DOCKER-USER -n</code> – shows the drop rules for forwarded traffic. | <code>ss -tulpn \| grep docker</code> – Docker'ın yalnızca localhost'ta dinlediğini gösterir.<br><code>iptables -v -L DOCKER-USER -n</code> – yönlendirilen trafik için düşürme kurallarını gösterir. |
| **Recovery & Rollback** | **Kurtarma ve Geri Alma** |
| If you need to revert to the default Docker network behaviour, simply restore the original configuration files: | Varsayılan Docker ağ davranışına dönmeniz gerekirse, orijinal yapılandırma dosyalarını geri yükleyin: |
| <code>sudo cp /etc/docker/daemon.json.bak /etc/docker/daemon.json 2>/dev/null \|\| sudo rm /etc/docker/daemon.json</code><br><code>sudo cp /etc/firewalld/direct.xml.bak /etc/firewalld/direct.xml</code><br><code>sudo systemctl restart docker firewalld</code> | <code>sudo cp /etc/docker/daemon.json.bak /etc/docker/daemon.json 2>/dev/null \|\| sudo rm /etc/docker/daemon.json</code><br><code>sudo cp /etc/firewalld/direct.xml.bak /etc/firewalld/direct.xml</code><br><code>sudo systemctl restart docker firewalld</code> |
| **Persistence** | **Kalıcılık** |
| The script automatically enables the firewall rules permanently via <code>firewall-cmd --reload</code> and modifies the Docker service drop-in directory to ensure the <code>hosts</code> setting survives Docker upgrades. | Betik, <code>firewall-cmd --reload</code> ile güvenlik duvarı kurallarını otomatik olarak kalıcı hale getirir ve Docker'ın <code>hosts</code> ayarının yükseltmelerde korunması için Docker servis drop-in dizinini düzenler. |
| **Author** | **Yazar** |
| Dr. Ozhan Akdag & Senior Cyber Security Agent (Collaborative design) | Dr. Özhan Akdağ & Kıdemli Siber Güvenlik Ajanı (İş birliği tasarımı) |

---

## Technical Hardening Matrix / Teknik Sıkılaştırma Matrisi

| **Component** | **Change** | **Purpose** | **Risk if not applied** |
|:---|:---|:---|:---|
| Docker daemon | Bind to 127.0.0.1 | Prevent external exposure of published ports | Containers exposed to entire network |
| Firewalld direct rules | Drop all forwarded traffic from non‑allowed sources | Enforce host‑level firewall policies | Docker bypasses firewalld completely |
| DOCKER-USER chain | Explicit REJECT rule | Block any unexpected inbound container traffic | Unauthorised access to container services |
| Configuration backups | Automatic .bak files | Enable quick rollback | Manual recovery harder |

---

**End of README**
