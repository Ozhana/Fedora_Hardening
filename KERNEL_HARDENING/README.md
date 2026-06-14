# 🛡️ Aegis Kernel Hardening & Runtime Memory Isolation

[![Layer](https://img.shields.io/badge/Aegis--Shield-Layer%200-red?style=for-the-badge)](https://github.com/Ozhana/Fedora_Hardening)
[![Target](https://img.shields.io/badge/Target-Fedora%2044%2F45%20Workstation-blue?style=for-the-badge)](https://getfedora.org)
[![Platform](https://img.shields.io/badge/Hardware-Surface%20Pro%209%20%2F%20Generic%20x86__64-orange?style=for-the-badge)](https://github.com/Ozhana/Fedora_Hardening)
[![Audit](https://img.shields.io/badge/Audit-Military--Grade%20Red%2FBlue-brightgreen?style=for-the-badge)](#)
[![Bash](https://img.shields.io/badge/Bash-5.2%2B-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)](#)
[![Version](https://img.shields.io/badge/Version-12.0--FINAL-gold?style=for-the-badge)](#)

---

## 🎯 Bu Betik Ne İşe Yarar?

Linux çekirdeği varsayılan olarak **esnek** davranır. Bu esneklik, bir saldırganın:

- Çekirdek bellek adreslerini okuyup exploit planlamasını,
- Çalışan süreçlerin hafızasını izleyip şifre/token çalmasını,
- Sembolik link manipülasyonlarıyla yetki yükseltmesini,
- Sistem çökmeye yakınken exploit zincirini tamamlamasını

mümkün kılar. **Aegis Kernel Hardening**, bu açık kapıları teker teker kapatarak çekirdeği bir **kalkan** haline getirir.

> 💡 **Basitçe:** Bu betik, bilgisayarınızın "beynini" (kernel) kurşun geçirmez bir zırha sokar. Çalıştırdıktan sonra, bir saldırganın sisteminize sızsa bile hafızayı okuması, süreçleri izlemesi veya yetki yükseltmesi katlanarak zorlaşır.

---

## 📋 Neleri Değiştirir? (Ne Beklemeli?)

| Parametre | Ne Yapar? | Günlük Kullanıma Etkisi |
|:---|:---|:---|
| `kernel.kptr_restrict=2` | Kernel bellek adreslerini **root dahil** herkesten gizler | Yok |
| `kernel.dmesg_restrict=1` | Sistem loglarını sadece root okuyabilir | `dmesg` komutu sadece `sudo` ile çalışır |
| `fs.protected_symlinks=1` | Sembolik link saldırılarını engeller | Yok |
| `fs.protected_hardlinks=1` | Hardlink manipülasyonunu engeller | Yok |
| `kernel.yama.ptrace_scope=2` | Süreç izlemeyi sadece root yapabilir | `strace`, `gdb` sadece `sudo` ile |
| `net.core.bpf_jit_harden=2` | eBPF JIT derleyicisini sertleştirir | Yok |
| `kernel.randomize_va_space=2` | ASLR'yi maksimuma çıkarır | Yok |
| `kernel.panic_on_oops=1` | Kernel hatasında sistem **hemen çöker** | ⚠️ Nadir kernel oops'larında ani restart |

> ⚠️ **Önemli:** `kernel.panic_on_oops=1` ayarı, ufak bir kernel hatasında bile sistemin aniden yeniden başlamasına neden olur. Bu, saldırganın yarı-çökmüş bir sistemi sömürmesini engeller, ama beklenmedik restart'lara hazır olun.

---

## 🧠 Standart vs Agresif Mod

Betik çalışırken size iki seçenek sunar:

### 🟢 Standart Mod (Önerilen)
- Günlük kullanıma uygun
- Docker, systemd, geliştirme araçları çalışmaya devam eder
- Temel kernel korumalarını etkinleştirir

### 🔴 Agresif Mod (Maksimum Güvenlik)
- **Geri alınamaz** sürgüler içerir:
  - `modules_disabled=1`: Sisteme yeni kernel modülü yüklenemez
  - `kexec_load_disabled=1`: Canlı kernel değiştirilemez
  - `unprivileged_userns_clone=0`: Rootless konteyner çalışmaz
- Yüksek güvenlikli sunucular için uygun
- Surface Pro 9'da bazı donanım sürücüleri etkilenebilir

---

## 🚀 Nasıl Kullanılır?

### 1. Önkoşul: Yama LSM'i Etkinleştirme

`ptrace_scope` koruması için Yama LSM aktif olmalıdır. Aşağıdaki komutu çalıştırıp sistemi **yeniden başlatın**:

```bash
sudo grubby --update-kernel=ALL --args="security=yama"
sudo reboot
```

2. Betik İndirme ve Çalıştırma
bash

# Ham betiği indir
wget https://raw.githubusercontent.com/Ozhana/Fedora_Hardening/main/KERNEL_HARDENING/aegis-kernel-hardening.sh

# Veya curl ile
curl -O https://raw.githubusercontent.com/Ozhana/Fedora_Hardening/main/KERNEL_HARDENING/aegis-kernel-hardening.sh

# Çalıştırılabilir yap
chmod +x aegis-kernel-hardening.sh

# Root olarak çalıştır
sudo ./aegis-kernel-hardening.sh

3. Etkileşimli Soruları Yanıtlayın
```text

🛡️  AEGIS KERNEL HARDENING & MEMORY ISOLATION (V12-FINAL)

[SORU 1/3]: AGRESİF MOD etkinleştirilsin mi?
  GERİ ALINAMAZ SÜRGÜLER İÇERİR: modules_disabled, kexec_load_disabled
  [E/e] Evet, [H/h] Hayır: h   ← Günlük kullanım için "h"

[SORU 2/3]: BPF lockdown (unprivileged_bpf_disabled=1) uygulansın mı?
  [E/e] Evet, [H/h] Hayır: e   ← Önerilen: "e"

[SORU 3/3]: Operasyonu nihai olarak onaylayın.
  Token [a1b2c3d4]: a1b2c3d4   ← Ekrandaki tokeni aynen yazın
```

4. Başarılı Çıktı
```text

✅ [BAŞARILI] Çekirdek bellek zırhı ve süreç hiyerarşisi mühürlendi.
```

🔒 Güvenlik Mimarisi (Teknik Detaylar)
Özellik	Açıklama
Atomik Kilit	/run/aegis/ altında kernel seviyesi flock, çifte çalıştırmayı engeller, PID doğrulaması yapar
Pre-flight Test	Parametreler canlı kernel'e yazılmadan önce /proc/sys üzerinde yazılabilirlik kontrolü
Latch Sıralaması	Geri alınamaz parametreler (modules_disabled vb.) en son uygulanır
Idempotent	1000 kez çalıştırılsa da sistemi bozmaz, zaten uygulanmışsa hemen çıkar
Crash-Consistent	mv (rename syscall) ile atomik disk yazımı, BTRFS journal güvencesi
Token Doğrulama	/dev/urandom tabanlı kriptografik token, otomasyonu engeller
Adli Loglama	/var/log/aegis/kernel_hardening.log + journald çift log
📁 Log Dosyaları
Konum	İçerik
/var/log/aegis/kernel_hardening.log	Yapılandırılmış operasyon logu
/etc/sysctl.d/99-aegis-kernel-hardening.conf	Kalıcı kernel parametreleri
/run/aegis/	Geçici kilit ve çalışma dosyaları (reboot'ta silinir)
❓ Sık Sorulan Sorular

S: Betiği tekrar çalıştırırsam ne olur?<br>C: Hiçbir şey. Betik idempotent'tir, mevcut durumu kontrol eder ve "zaten mühürlü" diyerek çıkar.
S: Agresif modu sonradan kapatabilir miyim?<br>C: Hayır. modules_disabled=1 ve kexec_load_disabled=1 geri alınamaz. Sadece reboot ile temizlenebilir, ama bu parametreler sysctl.conf dosyasına yazıldığı için her boot'ta tekrar uygulanır. Manuel olarak /etc/sysctl.d/99-aegis-kernel-hardening.conf dosyasını silip reboot etmeniz gerekir.

S: Docker/Podman çalışmaya devam eder mi?<br>C: Standart modda: Evet. Agresif modda: Rootless Docker/Podman çalışmaz, rootful Docker çalışır.

S: Surface Pro 9'a özel bir ayar var mı?<br>C: Hayır, betik tamamen donanımdan bağımsızdır. Surface Pro 9, Fedora 44 ile tam uyumludur. Sadece kernel.panic_on_oops=1 ayarı, Surface'ın Wi-Fi/dokunmatik sürücülerinde nadir oops durumunda sistemi restart edebilir.

S: Neden sync komutu kullanılmıyor?<br>C: BTRFS dosya sistemi, rename (mv) işlemini journal ile korur. Fazladan sync çağrısı tüm sistemi etkileyen gereksiz bir I/O fırtınası yaratır ve SSD ömrünü kısaltır.
🗺️ Fedora Hardening Yol Haritası

Bu betik, Layer 0 (Kernel Hardening) katmanıdır. Tam sistem sıkılaştırması için:
```text

Layer 0: Kernel Hardening        ← BU BETİK
Layer 1: Network Hardening       ← Sıradaki
Layer 2: SELinux & User Space
Layer 3: Filesystem & Permissions
Layer 4: Boot & Physical Security
Layer 5: Monitoring & IDS
```

📜 Lisans

Bu proje MIT License altında lisanslanmıştır.

🛡️ Yoldaş Düsturu: "Tahmin etme, doğrula. Esnekliği kapat, zırhı kuşan."
text


---

Bu README.md, **teknik bilgisi olmayan bir kullanıcının bile** betiğin ne yaptığını anlamasını, nasıl çalıştıracağını bilmesini ve ne bekleyeceğini öğrenmesini sağlayacak şekilde yazıldı. 🛡️
