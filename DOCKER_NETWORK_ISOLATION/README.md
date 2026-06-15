mkdir -p ~/aegis-docker-installer && cd ~/aegis-docker-installer && cat << 'EOF' > README.md
# 🛡️ Aegis Docker Network Isolation – Enterprise Hardening

| ENGLISH | TÜRKÇE |
|---------|--------|
| **Version:** 6.0<br>**Problem:** Docker silently bypasses firewalld via DNAT and iptables manipulation, exposing containers to the external network.<br>**Solution:** Lock published ports to localhost and seal the DOCKER-USER chain with strict private‑subnet‑only rules. | **Versiyon:** 6.0<br>**Sorun:** Docker, DNAT ve iptables müdahalesi ile firewalld’ı sessizce baypas ederek konteynırları dış ağa açar.<br>**Çözüm:** Yayınlanan portları localhost’a kilitlemek ve DOCKER-USER zincirini özel alt ağ trafiğiyle sınırlandırarak mühürlemek. |
| **Affected files:**<br><code>/etc/docker/daemon.json</code><br><code>/etc/firewalld/direct.xml</code> | **Etkilenen dosyalar:**<br><code>/etc/docker/daemon.json</code><br><code>/etc/firewalld/direct.xml</code> |
| **Repository:**<br><code>https://github.com/Ozhana/Fedora_Hardening/tree/main/DOCKER_NETWORK_ISOLATION</code> | **Depo:**<br><code>https://github.com/Ozhana/Fedora_Hardening/tree/main/DOCKER_NETWORK_ISOLATION</code> |

---

## 📥 1. Fetch the script / Betiği İndir

| ENGLISH | TÜRKÇE |
|---------|--------|
| <code>curl -sSL https://raw.githubusercontent.com/Ozhana/Fedora_Hardening/main/DOCKER_NETWORK_ISOLATION/aegis-docker-fw.sh -o /tmp/aegis.sh</code> | <code>curl -sSL https://raw.githubusercontent.com/Ozhana/Fedora_Hardening/main/DOCKER_NETWORK_ISOLATION/aegis-docker-fw.sh -o /tmp/aegis.sh</code> |

---

## 🔐 2. Permissions / Yetkilendirme

| ENGLISH | TÜRKÇE |
|---------|--------|
| <code>chmod +x /tmp/aegis.sh</code> | <code>chmod +x /tmp/aegis.sh</code> |

---

## 🚀 3. Execute / Çalıştır

| ENGLISH | TÜRKÇE |
|---------|--------|
| <code>sudo /tmp/aegis.sh</code> | <code>sudo /tmp/aegis.sh</code> |
| *The script is idempotent – running it again changes nothing.* | *Betik idempotenttir – tekrar çalıştırmak hiçbir şeyi değiştirmez.* |

---

## 🔍 4. What to Expect / Ne Beklemeli

| ENGLISH | TÜRKÇE |
|---------|--------|
| After successful execution:<br><br>✅ Published ports (e.g. <code>-p 8080:80</code>) listen **only on 127.0.0.1**<br>✅ External access to containers is **impossible**<br>✅ Container‑to‑container traffic is allowed **only inside private subnets** (<code>172.16/12</code>, <code>192.168/16</code>, <code>10/8</code>, <code>fc00::/7</code>)<br>✅ Containers can still reach the internet (egress allowed)<br>✅ Docker can no longer manipulate firewalld rules | Başarılı çalıştırmadan sonra:<br><br>✅ Yayınlanan portlar (ör. <code>-p 8080:80</code>) **sadece 127.0.0.1** üzerinde dinler<br>✅ Konteynırlara dışarıdan erişim **imkansızdır**<br>✅ Konteynırlar arası trafiğe **yalnızca özel alt ağlar** içinde izin verilir (<code>172.16/12</code>, <code>192.168/16</code>, <code>10/8</code>, <code>fc00::/7</code>)<br>✅ Konteynırlar internete çıkabilir (egress izni vardır)<br>✅ Docker artık firewalld kurallarını manipüle edemez |

### Verification commands / Doğrulama komutları

| ENGLISH | TÜRKÇE |
|---------|--------|
| <code>ss -tulpn \| grep docker-proxy</code><br><br>Should show only <code>127.0.0.1:xxxx</code> listeners.<br><br><code>iptables -v -L DOCKER-USER -n</code><br><br>Must contain the REJECT rule at the end.<br><br><code>ip6tables -v -L DOCKER-USER -n</code><br><br>(only if IPv6 is enabled) must show <code>icmp6-adm-prohibited</code>. | <code>ss -tulpn | grep docker-proxy</code><br><br>Sadece <code>127.0.0.1:xxxx</code> dinleyicilerini göstermeli.<br><br><code>iptables -v -L DOCKER-USER -n</code><br><br>Sonda REJECT kuralını içermeli.<br><br><code>ip6tables -v -L DOCKER-USER -n</code><br><br>(sadece IPv6 aktifse) <code>icmp6-adm-prohibited</code> göstermeli. |

---

## 🔄 5. Recovery & Rollback / Kurtarma ve Geri Alma

| ENGLISH | TÜRKÇE |
|---------|--------|
| The script automatically creates timestamped backups before changes:<br><br><code>/etc/docker/daemon.json.aegis_bak_YYYYMMDD_HHMMSS</code><br><code>/etc/firewalld/direct.xml.aegis_bak_YYYYMMDD_HHMMSS</code><br><br>**Manual rollback:**<br><br><code>sudo cp /etc/docker/daemon.json.aegis_bak_* /etc/docker/daemon.json</code><br><code>sudo systemctl restart docker</code><br><code>sudo cp /etc/firewalld/direct.xml.aegis_bak_* /etc/firewalld/direct.xml</code><br><code>sudo firewall-cmd --reload</code> | Betik, değişiklik öncesinde zaman damgalı yedekler oluşturur:<br><br><code>/etc/docker/daemon.json.aegis_bak_YYYYMMDD_HHMMSS</code><br><code>/etc/firewalld/direct.xml.aegis_bak_YYYYMMDD_HHMMSS</code><br><br>**Manuel geri dönüş:**<br><br><code>sudo cp /etc/docker/daemon.json.aegis_bak_* /etc/docker/daemon.json</code><br><code>sudo systemctl restart docker</code><br><code>sudo cp /etc/firewalld/direct.xml.aegis_bak_* /etc/firewalld/direct.xml</code><br><code>sudo firewall-cmd --reload</code> |

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
EOF
