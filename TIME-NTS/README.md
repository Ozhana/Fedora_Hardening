# Chrony NTS (Network Time Security) Armor

**Enterprise-Grade Time Integrity Framework**

| ENGLISH | TÜRKÇE |
| :--- | :--- |
| **Why NTS?** Standard NTP is unauthenticated and cleartext. Attackers can manipulate your system time to expire TLS certificates, break DNSSEC (Quad9), or alter security log timestamps. | **Neden NTS?** Standart NTP şifresiz ve imzasızdır. Saldırganlar sistem saatini manipüle ederek TLS sertifikalarını geçersiz kılabilir, DNSSEC korumasını kırabilir veya güvenlik loglarını değiştirebilir. |
| **How It Works:** This script secures time synchronization using TLS 1.3 via NTS, ensuring that your system time cannot be altered by Man-in-the-Middle (MitM) attacks. | **Nasıl Çalışır:** Bu betik, zaman senkronizasyonunu NTS (TLS 1.3) üzerinden güvenli hale getirerek, Ortadaki Adam (MitM) saldırılarına karşı sistem saatinin manipüle edilmesini fiziksel olarak imkansız kılar. |

---

## 🚀 Deployment & Verification / Dağıtım ve Doğrulama

| ENGLISH | TÜRKÇE |
| :--- | :--- |
| **1. Installation Path:** Place the script in the secure administrative directory. | **1. Kurulum Dizini:** Betiği yönetici araçları için ayrılmış güvenli dizine yerleştirin: |
| `sudo cp aegis-time-nts /usr/local/bin/aegis-time-nts` | `sudo cp aegis-time-nts /usr/local/bin/aegis-time-nts` |
| `sudo chmod 700 /usr/local/bin/aegis-time-nts` | `sudo chmod 700 /usr/local/bin/aegis-time-nts` |
| **2. Execution & Mühürleme:** Execute with root privileges. It will automatically backup, validate, and seal your time configuration. | **2. Çalıştırma:** Root yetkisiyle çalıştırın. Betik otomatik olarak yedekleme yapar, doğrular ve yapılandırmanızı mühürler. |
| `sudo aegis-time-nts` | `sudo aegis-time-nts` |
| **3. Verification:** Check if NTS is active and sync is normal. | **3. Doğrulama:** NTS'nin aktif olduğunu ve senkronizasyonun normal çalıştığını kontrol edin: |
| `chronyc -N authdata` | `chronyc -N authdata` |
| `chronyc tracking` | `chronyc tracking` |

---

## ⚠️ Security Notice / Güvenlik Uyarısı

| ENGLISH | TÜRKÇE |
| :--- | :--- |
| **Zero-Assumptions Policy:** This script performs atomic backups (`.bak`) and utilizes kernel-level time validation. If any configuration test fails, it performs an automatic rollback to the original state to ensure system stability. | **Sıfır Varsayım Politikası:** Bu betik atomik yedekleme (`.bak`) yapar ve çekirdek seviyesinde doğrulama kullanır. Herhangi bir test başarısız olursa, sistem kararlılığını korumak için otomatik olarak orijinal duruma geri döner (Rollback). |

---

## 📋 Features / Özellikler

- **Atomic Integrity:** Automatic atomic rollback (`cp` -> `sync` -> `mv`) guarantees no partial config corruption.
- **Hardware-Aware:** Validates kernel-level time synchronization status via `chronyc tracking`.
- **Zero-Entropy:** Cleans up all temporary files and handles signal interruptions (`trap`) gracefully.
- **Fail-Safe:** Does not trust generic configuration; verifies each NTS-KE handshake path.

- **Atomik Bütünlük:** Otomatik geri alma garantisi ile hiçbir kısmi (partial) bozulmaya izin vermez.
- **Donanım Odaklı:** `chronyc tracking` aracılığıyla zaman senkronizasyonunun fiziksel sağlığını denetler.
- **Sıfır Entropi:** Geçici dosyaları temizler ve sinyal kesilmelerini (`trap`) profesyonelce yönetir.
- **Fail-Safe:** Varsayımlara güvenmez; her NTS el sıkışma yolunu (handshake) doğrular.
