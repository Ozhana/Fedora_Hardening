# 🛡️ Aegis Docker Network Isolation – Enterprise Hardening

| ENGLISH | TÜRKÇE |
|---------|--------|
| **Version:** 6.0<br>**Problem:** Docker silently bypasses firewalld via DNAT and iptables manipulation, exposing containers to the external network.<br>**Solution:** Lock published ports to localhost and seal the DOCKER-USER chain with strict private‑subnet‑only rules. | **Versiyon:** 6.0<br>**Sorun:** Docker, DNAT ve iptables müdahalesi ile firewalld’ı sessizce baypas ederek konteynırları dış ağa açar.<br>**Çözüm:** Yayınlanan portları localhost’a kilitlemek ve DOCKER-USER zincirini özel alt ağ trafiğiyle sınırlandırarak mühürlemek. |
| **Affected files:**<br><code>/etc/docker/daemon.json</code><br><code>/etc/firewalld/direct.xml</code> | **Etkilenen dosyalar:**<br><code>/etc/docker/daemon.json</code><br><code>/etc/firewalld/direct.xml</code> |
| **Repository Directory:**<br><code>https://github.com/Ozhana/Fedora_Hardening/tree/main/DOCKER_NETWORK_ISOLATION</code> | **Depo Dizini:**<br><code>https://github.com/Ozhana/Fedora_Hardening/tree/main/DOCKER_NETWORK_ISOLATION</code> |

---

## 📥 1. Fetch the script / Betiği İndir

| ENGLISH | TÜRKÇE |
|---------|--------|
| Download the secure script directly to the local execution workspace:<br><br><code>curl -sSL https://raw.githubusercontent.com/Ozhana/Fedora_Hardening/main/DOCKER_NETWORK_ISOLATION/aegis-docker-fw.sh -o ~/aegis-docker-installer/aegis-docker-fw.sh</code> | Güvenli betiği doğrudan yerel çalışma alanına indirin:<br><br><code>curl -sSL https://raw.githubusercontent.com/Ozhana/Fedora_Hardening/main/DOCKER_NETWORK_ISOLATION/aegis-docker-fw.sh -o ~/aegis-docker-installer/aegis-docker-fw.sh</code> |

---

## 🔐 2. Permissions / Yetkilendirme

| ENGLISH | TÜRKÇE |
|---------|--------|
| Relocate the script to the trusted path and restrict write permissions to root only:<br><br><code>sudo cp aegis-docker-fw.sh /usr/local/bin/aegis-docker-fw.sh</code><br><code>sudo chown root:root /usr/local/bin/aegis-docker-fw.sh</code><br><code>sudo chmod 700 /usr/local/bin/aegis-docker-fw.sh</code> | Betiği güvenilir yola taşıyın ve yazma yetkilerini yalnızca root kullanıcısı ile sınırlandırın:<br><br><code>sudo cp aegis-docker-fw.sh /usr/local/bin/aegis-docker-fw.sh</code><br><code>sudo chown root:root /usr/local/bin/aegis-docker-fw.sh</code><br><code>sudo chmod 700 /usr/local/bin/aegis-docker-fw.sh</code> |

---

## 🚀 3. Execute / Çalıştır

| ENGLISH | TÜRKÇE |
|---------|--------|
| Run the hardening script with administrative privileges:<br><br><code>sudo /usr/local/bin/aegis-docker-fw.sh</code><br><br>*The script is idempotent – running it again changes nothing.* | Sıkılaştırma betiğini yönetici yetkileriyle çalıştırın:<br><br><code>sudo /usr/local/bin/aegis-docker-fw.sh</code><br><br>*Betik idempotenttir – tekrar çalıştırmak hiçbir şeyi değiştirmez.* |

---

## 🔍 4. What to Expect / Ne Beklemeli

| ENGLISH | TÜRKÇE |
|---------|--------|
| After successful execution:<br><br>✅ Published ports (e.g. <code>-p 8080:80</code>) listen **only on 127.0.0.1**<br>✅ External access to containers is **impossible**<br>✅ Container‑to‑container traffic is allowed **only inside private subnets** (<code>172.16/12</code>, <code>192.168/16</code>, <code>10/8</code>, <code>fc00::/7</code>)<br>✅ Containers can still reach the internet (egress allowed)<br>✅ Docker can no longer manipulate firewalld rules | Başarılı çalıştırmadan sonra:<br><br>✅ Yayınlanan portlar (ör. <code>-p 8080:80</code>) **sadece 127.0.0.1** üzerinde dinler<br>✅ Konteynırlara dışarıdan erişim **imkansızdır**<br>✅ Konteynırlar arası trafiğe **yalnızca özel alt ağlar** içinde izin verilir (<code>172.16/12</code>, <code>192.168/16</code>, <code>10/8</code>, <code>fc00::/7</code>)<br>✅ Konteynırlar internete çıkabilir (egress izni vardır)<br>✅ Docker artık firewalld kurallarını manipüle edemez |

### Verification commands / Doğrulama komutları

| ENGLISH | TÜRKÇE |
|---------|--------|
| Verify Docker only listens on localhost:<br><code>ss -tulpn \| grep dockerd</code><br><br>Verify IPv4 rules are active in the kernel structure:<br><code>sudo iptables -v -L DOCKER-USER -n</code><br><br>Verify IPv6 rules (if IPv6 is globally active):<br><code>sudo ip6tables -v -L DOCKER-USER -n</code> | Docker'ın yalnızca localhost üzerinde dinlediğini doğrulayın:<br><code>ss -tulpn \| grep dockerd</code><br><br>IPv4 kurallarının çekirdek yapısında aktif olduğunu doğrulayın:<br><code>sudo iptables -v -L DOCKER-USER -n</code><br><br>IPv6 kurallarını doğrulayın (eğer IPv6 küresel olarak aktifse):<br><code>sudo ip6tables -v -L DOCKER-USER -n</code> |

---

## 🔄 5. Recovery & Rollback / Kurtarma ve Geri Alma

| ENGLISH | TÜRKÇE |
|---------|--------|
| The script automatically creates timestamped backups before changes:<br><br><code>/etc/docker/daemon.json.aegis_bak_YYYYMMDD_HHMMSS</code><br><code>/etc/firewalld/direct.xml.aegis_bak_YYYYMMDD_HHMMSS</code><br><br>**Manual rollback:**<br>*(Replace YY... with your exact backup timestamp)*<br><br><code>sudo cp /etc/docker/daemon.json.aegis_bak_YYYYMMDD_HHMMSS /etc/docker/daemon.json</code><br><code>sudo systemctl restart docker</code><br><code>sudo cp /etc/firewalld/direct.xml.aegis_bak_YYYYMMDD_HHMMSS /etc/firewalld/direct.xml</code><br><code>sudo firewall-cmd --reload</code> | Betik, değişiklik öncesinde zaman damgalı yedekler oluşturur:<br><br><code>/etc/docker/daemon.json.aegis_bak_YYYYMMDD_HHMMSS</code><br><code>/etc/firewalld/direct.xml.aegis_bak_YYYYMMDD_HHMMSS</code><br><br>**Manuel geri dönüş:**<br>*(YY... kısmını kendi yedek zaman damganızla değiştirin)*<br><br><code>sudo cp /etc/docker/daemon.json.aegis_bak_YYYYMMDD_HHMMSS /etc/docker/daemon.json</code><br><code>sudo systemctl restart docker</code><br><code>sudo cp /etc/firewalld/direct.xml.aegis_bak_YYYYMMDD_HHMMSS /etc/firewalld/direct.xml</code><br><code>sudo firewall-cmd --reload</code> |

---

## 📊 Technical Hardening Matrix / Teknik Sıkılaştırma Matrisi

| Katman (Layer) | Hedef (Target) | Yöntem (Method) | Sonuç (Result) |
|----------------|----------------|------------------|----------------|
| **Docker daemon** | Port publishing (`-p`) | `daemon.json` → `"ip": "127.0.0.1"`, `"userland-proxy": false` | Portlar sadece localhost’a bağlanır, dış ağdan erişilemez |
| **Netfilter (IPv4)** | Container‑to‑container & inbound forwarding | `DOCKER-USER` zincirine private subnet izinleri ve `REJECT` kuralı | Yalnızca özel alt ağlar içindeki trafiğe izin verilir; harici giriş tamamen engellenir |
| **Netfilter (IPv6)** | Aynı, IPv6 için | `ip6tables` üzerinde aynı kurallar (ULA `fc00::/7` izni) | IPv6 kullanılıyorsa aynı koruma sağlanır |
| **Idempotency** | Tekrarlı çalıştırma | `iptables-save` / `ip6tables-save` ile tam kural seti kontrolü | Betik ikinci kez çalıştığında hiçbir değişiklik yapmaz, log şişmez |
| **Atomicity & Lock** | Yarış koşulları (race condition) | `flock` + ayrılmış dosya tanımlayıcı (FD 9) | İki betik aynı anda çalışamaz; kilit dosyası asla silinmez (symlink saldırısı önlenir) |

---

## 🤝 Author / Yazar

**Dr. Ozhan Akdag & Senior Cyber Security Agent (Collaborative design)** *Enterprise-grade hardening for Fedora Workstation – Surface Pro 9 & similar*

---

## 📜 License / Lisans

MIT – free to use, share, and modify with credit.
