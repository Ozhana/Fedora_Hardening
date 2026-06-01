# ENTERPRISE-GRADE .BASHRC HARDENING & TELEMETRY SUITE
## AUTHOR: Dr. Ozhan Akdag

## 1. KERNEL & DONANIM İZOLASYONU (USB Dosya Sistemi Kilitleri)
[TR] USB depolama modüllerini çekirdeğe yükleyerek harici disklerin veri akışını açar.
[EN] Loads USB storage modules into the kernel to enable external drive data transfer.
```bash
alias usb-ac='sudo modprobe usb-storage && sudo modprobe uas && echo "🔓 [SİSTEM] USB Depolama Modülleri Yüklendi. Veri akışı aktif."'
```
[TR] USB depolama sürücülerini çekirdekten kazır; böylece fiziksel cihaz takılsa bile veri okunamaz.
[EN] Removes USB storage drivers from the kernel; preventing data access even if a physical device is connected.
```bash
alias usb-kapat='sudo modprobe -r usb-storage uas 2>/dev/null && echo "🔒 [SİSTEM] USB Depolama Kilitlendi. Sürücüler hafızadan güvenle kazındı!" || echo "[!] Kapatılamadı: Cihaz şu an kullanımda olabilir."'
```

## 2. KRİPTOGRAFİK VERİ İMHASI (DoD Standardı)
[TR] Dosya sektörlerini 3 kez rastgele veriyle ezip sıfırlayarak adli bilişimle bile kurtarılamayacak şekilde imha eder.
[EN] Overwrites file sectors 3 times with random data and zero-fills them, ensuring recovery is impossible even with forensic tools.
```bash
secure-wipe() {
    if [ -z "${1:-}" ]; then 
        echo "[HATA] Yok edilecek dosyayı belirtmelisin! Kullanım: secure-wipe <dosya_adi>" >&2
        return 1
    fi
    echo "🔥 [GÜVENLİK] '$1' kriptografik olarak atomlarına ayrılıyor..."
    shred -u -z -n 3 "$1" && echo "[✔] İşlem başarılı. Veri kurtarma ihtimali: %0"
}
```


## 3. IMMUTABLE ARCHITECTURE (Mutlak Çekirdek Kilidi)
[TR] Dosyayı kernel seviyesinde "Değiştirilemez" yapar; kilit kalkana kadar root dahil hiç kimse silemez veya değiştiremez.
[EN] Makes the file "Immutable" at the kernel level; nobody, including root, can delete or modify it until unlocked.
```bash
alias kilit-vur='sudo chattr +i'
```
[TR] Dosya üzerindeki kernel seviyesindeki değiştirilemezlik (Immutable) mühürünü kaldırarak düzenlemeye açar.
[EN] Removes the kernel-level immutability seal from the file, making it editable again.
```bash
alias kilit-ac='sudo chattr -i'
```
[TR] Bulunulan dizindeki dosyaların kernel seviyesindeki özel kilit ve öznitelik durumlarını listeler.
[EN] Lists the kernel-level special locks and attribute statuses of the files in the current directory.
```bash
alias kilit-kontrol='lsattr'
```


## 4. SİBER GÜVENLİK (Rkhunter Human-in-the-Loop Mimarisi)
[TR] Rootkit imza veritabanını günceller, tarama yapar ve güvenli referans (Baseline) mühürlemesini insan onayına bırakır.
[EN] Updates the rootkit signature database, runs a scan, and leaves the secure reference (Baseline) sealing to human verification.
```bash
rk-denetim() {
    echo "🛡️ [RKHUNTER] Adım 1: Rootkit imza veritabanı güncelleniyor (--update)..."
    sudo rkhunter --update

    echo -e "\n🔍 [RKHUNTER] Adım 2: Sistem taraması başlatılıyor..."
    sudo rkhunter --check --skip-keypress --rwo || true

    echo -e "\n======================================================================"
    echo "⚠️ DİKKAT: Yukarıdaki tarama sonuçlarını (Warnings) dikkatlice inceleyin."
    echo "Eğer bu uyarılar meşru bir sistem güncellemesinden kaynaklanıyorsa,"
    echo "sistemin bu yeni halini güvenli (Baseline) kabul edebiliriz."
    echo "======================================================================"
    
    read -r -p "Herhangi bir anomali YOKSA veritabanı mühürlensin mi? (--propupd) (yes/no): " ONAY

    if [[ "$ONAY" =~ ^(yes|y|Y|YES)$ ]]; then
        echo -e "\n⚙️ [RKHUNTER] Dosya özellikleri veritabanı güncelleniyor..."
        sudo rkhunter --propupd
        echo "✅ [BAŞARILI] Sistem dosyalarının yeni durumu 'Güvenli (Baseline)' olarak mühürlendi."
    else
        echo -e "\n🔒 [GÜVENLİK] İşlem iptal edildi. Baseline dondurulmuş durumda bırakıldı."
    fi
}
```

[TR] Ağda dış bağlantı bekleyen (LISTEN) tüm aktif portları ve bu portları açan gizli süreçleri (PID) listeler.
[EN] Lists all active ports waiting for external connections (LISTEN) and the hidden processes (PID) that opened them.
```bash
alias net-audit='echo "🔍 [SİSTEM] Açık portlar ve dinleyen süreçler taranıyor..." && sudo ss -tulpn | grep LISTEN'
```


## 5. İZOLASYON & TELEMETRİ (Veri Analitiği ve Çekirdek Röntgeni)
[TR] Bulunulan dizinde steril bir Python sanal ortamı (venv) kurarak işletim sisteminin paket yapısını çakışmalardan korur.
[EN] Creates a sterile Python virtual environment (venv) in the current directory, protecting the OS package structure from conflicts.
```bash
data-sandbox() {
    echo "🧪 [SİSTEM] İzole Python Veri Laboratuvarı inşa ediliyor..."
    python3 -m venv venv --clear
    source venv/bin/activate
    echo "🔒 [GÜVENLİK] Global sistemden koptunuz. Paketler sadece bu dizine kurulacak."
}
```

[TR] Çekirdekten ham bellek verilerini çeker, AWK matrisiyle Gigabyte cinsinden hesaplar ve en ağır 10 süreci listeler.
[EN] Fetches raw memory data from the kernel, calculates it in Gigabytes using an AWK matrix, and lists the top 10 heaviest processes.
```bash
alias ram-radar='echo "📊 [TELEMETRİ] En çok RAM tüketen ilk 10 süreç:" && ps axo rss,comm,pid | awk '\''{ sum+=$1; print $0 } END { printf "\nToplam Tüketim: %.2f GB\n", sum/1024/1024 }'\'' | sort -n | tail -n 11'
```

[TR] Çekirdek günlükleri (dmesg) içindeki donanım çökmelerini, hafıza hatalarını ve kritik USB anomalilerini süzüp kırmızıya boyar.
[EN] Filters kernel logs (dmesg) for hardware crashes, memory errors, and critical USB anomalies, highlighting them in red.

```bash
alias kernel-radar='echo "☢️ [KERNEL] Kritik donanım hataları taranıyor..." && sudo dmesg -T | grep --color=always -iE "error|warn|fail|killed|segfault|usb"'
```
[TR] Kör commit yapmayı engellemek için, mevcut dal durumunu ve değiştirilen satır sayılarını atomik bir istatistik olarak sunar.
[EN] Prevents blind commits by presenting the current branch status and modified line counts as an atomic statistic.
```bash
alias git-rontgen='echo "🔍 [GİT] Değiştirilen satırların atomik röntgeni:" && git status -s -b && echo "---------------------------" && git diff --stat'
```
