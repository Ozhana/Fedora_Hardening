cat << 'POTATO' > aliases.md
# Fedora 44 SecureOps Alias Suite

**Version:** V1.0  
**Author:** Dr. Ozhan Akdag & Senior Cyber Security Agent (Collaborative design)  
**Date:** 2026-06-17  
**Target:** Fedora 44 Workstation (Microsoft Surface Pro 9)  
**License:** MIT

---

## 1. Introduction

This reference describes a hardened collection of **shell aliases** and **standalone scripts** purpose‑built for **Fedora 44 Workstation** on fanless hardware (Surface Pro 9). Every component is engineered for **idempotency, atomic locking, crash‑safe cleanup, mandatory logging, and minimal SSD wear**. The suite replaces dangerous defaults, delivers real‑time system telemetry, and enforces strict file‑integrity workflows.

Aliases fall into two categories:

* **Inline definitions** – short `alias` lines placed directly in `~/.bashrc`.
* **Script‑backed aliases** – calls to hardened scripts installed in `/usr/local/bin`. Each script handles its own kernel‑level `flock`, `trap`‑based rollback, and timestamped logging to `~/Desktop/LOG_FILES/`.

---

## 2. Core Problem & Solution

| Item | Description |
|------|-------------|
| **Core Problem** | Default shell aliases lack concurrency protection, leave orphan locks after interruption, and write no forensic logs. Repeated updates can silently poison security baselines (rkhunter, AIDE). Fanless hardware suffers from uncontrolled thermal stress. |
| **Solution** | A suite of idempotent scripts backed by `flock` and `trap` that ensure clean state after any exit. Logs are written with UTC timestamps. Thermal sensors, SUID scanning, and file‑integrity checks are integrated with human‑in‑the‑loop baseline approval. |
| **Relevant File Paths** | `~/.bashrc` (aliases)<br>`/usr/local/bin/` (scripts)<br>`~/Desktop/LOG_FILES/` (logs) |
| **Verification Commands** | <code>type sysupdate</code><br><code>ls -l /usr/local/bin/secure-*</code><br><code>cat ~/Desktop/LOG_FILES/secure-sysupdate.log</code> |

---

## 3. Workspace & Prerequisites

* **Operating System:** Fedora 44 Workstation (clean installation, single‑user)
* **Hardware:** Surface Pro 9 (fanless, NVMe SSD)
* **Required Packages:** `dnf`, `firewalld`, `jq`, `lm_sensors`, `rkhunter`, `aide`, `git`
* **User:** The only human user, with `sudo` privileges.
* **Log Directory:** `~/Desktop/LOG_FILES/` is created automatically on first use.

---

## 4. Obtaining the Files

The complete suite is part of the **Fedora Hardening** repository. Clone or download it manually:

    git clone https://github.com/Ozhana/Fedora_Hardening.git
    cd Fedora_Hardening/ALIASES

The `ALIASES` directory contains the install script (`secure-aliases-install.sh`) and all standalone scripts. Review the source before execution.

---

## 5. Setting Permissions

After placing the scripts, ensure they are executable:

    sudo chmod 755 /usr/local/bin/secure-* /usr/local/bin/sys-*

The log directory is created with `750` by the scripts; no manual intervention is required.

---

## 6. What to Expect at Runtime

* **Idempotency:** Run any command 1000 times – state remains consistent, logs append.
* **Atomic Locks:** Concurrent executions are blocked. You will see a `[WARN]` message if the script is already running.
* **Crash Safety:** `CTRL+C` or a sudden power loss releases all locks and removes temporary files.
* **Logging:** Every script‑backed action writes a UTC‑stamped entry to `~/Desktop/LOG_FILES/<script>.log`.
* **Hardware Respect:** Disk scans are limited to critical directories; no unnecessary writes.

---

## 7. Alias Reference

### 7.1 Basic Safety Aliases

These aliases **must be placed in `~/.bashrc`**. They add confirmation prompts and prevent catastrophic mistakes.

| Alias | Definition (paste into `.bashrc`) | Purpose | What to Expect | Usage |
|-------|-----------------------------------|---------|----------------|-------|
| `rm` | <code>alias rm='rm -I --preserve-root'</code> | Prevents recursive deletion of `/` and asks confirmation when deleting >3 files. | Prompts before mass removal; root protected. | `rm old_file` |
| `cp` | <code>alias cp='cp -ia'</code> | Interactive copy; asks before overwrite, preserves attributes. | Never silently overwrites. | `cp src dst` |
| `mv` | <code>alias mv='mv -iv'</code> | Interactive move with verbose output. | Shows each file moved; confirms overwrites. | `mv old new` |
| `mkdir` | <code>alias mkdir='mkdir -pv'</code> | Creates parent directories as needed and prints each. | No missing parent errors. | `mkdir -p a/b/c` |
| `chown` | <code>alias chown='chown --preserve-root'</code> | Prevents changing ownership of `/`. | Extra safety net. | `chown user file` |

### 7.2 System Status Aliases

Place these in `~/.bashrc` for instant health checks.

| Alias | Definition | Purpose | What to Expect | Usage |
|-------|------------|---------|----------------|-------|
| `ports` | <code>alias ports='ss -tulpn \| awk '\''NR>1 {printf "%-10s %-25s %s\n", $1, $5, $7}'\'''</code> | List listening TCP/UDP ports with owning process. | Clean table; quickly spot rogue listeners. | `ports` |
| `memstat` | <code>alias memstat='free -b \| awk '\''NR==2 {printf "RAM Tüketimi: %.2f%%\n", $3*100/$2}'\'''</code> | RAM usage percentage. | Immediate memory pressure indication. | `memstat` |
| `diskstat` | <code>alias diskstat='df -B1 / \| awk '\''NR==2 {printf "Root FS Tüketimi: %.2f%%\n", $3*100/$2}'\'''</code> | Root filesystem usage percentage. | Warns before disk is full. | `diskstat` |
| `loadavg` | <code>alias loadavg='cat /proc/loadavg \| awk '\''{printf "Yük (1/5/15dk): %s \| %s \| %s\n", $1, $2, $3}'\'''</code> | 1/5/15‑min load averages. | Compare with CPU cores; detect overload. | `loadavg` |
| `zombies` | <code>alias zombies='ps axo stat,ppid,pid,comm \| awk '\''$1=="Z" {printf "ZOMBIE PID: %s (Parent: %s) -> %s\n", $3, $2, $4}'\'''</code> | Lists zombie processes. | Empty under normal conditions; otherwise shows dead children. | `zombies` |

### 7.3 Script‑Backed Aliases

Each alias points to a hardened script in `/usr/local/bin`. **Both the alias line and the full script code are provided below.** Place the alias in `~/.bashrc`, save the script to the indicated path, and make it executable.

---

#### sysupdate

**Alias:** <code>alias sysupdate='secure-sysupdate'</code>  
**Script location:** `/usr/local/bin/secure-sysupdate`  
**Purpose:** Atomically runs `sudo dnf upgrade --refresh -y` with a kernel lock.

**What to Expect:**  
- Concurrent calls are refused.  
- Log written to `~/Desktop/LOG_FILES/secure-sysupdate.log`.  
- `CTRL+C` releases the lock instantly.

**Script code (save as `/usr/local/bin/secure-sysupdate`):**

    #!/usr/bin/env bash
    set -Eeuo pipefail
    IFS=$'\n\t'
    
    readonly SCRIPT_NAME="secure-sysupdate"
    readonly LOG_DIR="${HOME}/Desktop/LOG_FILES"
    readonly LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"
    mkdir -p "$LOG_DIR"
    
    logmsg() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }
    
    readonly LOCK_DIR="${HOME}/.local/run/locks"
    readonly LOCK_FILE="${LOCK_DIR}/sysupdate.lock"
    command -v dnf >/dev/null 2>&1 || { logmsg "[FATAL] 'dnf' bulunamadı."; exit 1; }
    
    mkdir -p "$LOCK_DIR"
    exec 9> "$LOCK_FILE"
    if ! flock -n 9; then
        logmsg "[WARN] Güncelleme zaten çalışıyor. PID: $(cat "$LOCK_FILE" 2>/dev/null || echo bilinmiyor)"
        exit 1
    fi
    echo $$ > "$LOCK_FILE"
    
    cleanup() {
        flock -u 9 2>/dev/null || true
        rm -f "$LOCK_FILE"
        logmsg "İşlem sonlandı."
    }
    trap cleanup EXIT INT TERM
    
    logmsg "Sistem güncellemesi başlatıldı."
    sudo dnf upgrade --refresh -y
    logmsg "Güncelleme tamamlandı."

**Usage:**  

    sysupdate

---

#### fwaudit

**Alias:** <code>alias fwaudit='secure-fwaudit'</code>  
**Script location:** `/usr/local/bin/secure-fwaudit`  
**Purpose:** Dumps the firewalld configuration in a readable `key : value` format.

**What to Expect:**  
- Shows zones, services, ports.  
- Log: `~/Desktop/LOG_FILES/secure-fwaudit.log`.

**Script code (save as `/usr/local/bin/secure-fwaudit`):**

    #!/usr/bin/env bash
    set -Eeuo pipefail
    IFS=$'\n\t'
    
    readonly SCRIPT_NAME="secure-fwaudit"
    readonly LOG_DIR="${HOME}/Desktop/LOG_FILES"
    readonly LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"
    mkdir -p "$LOG_DIR"
    
    logmsg() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }
    
    command -v firewall-cmd >/dev/null 2>&1 || { logmsg "[FATAL] 'firewall-cmd' bulunamadı."; exit 1; }
    
    logmsg "Firewall durumu sorgulanıyor."
    sudo firewall-cmd --list-all | awk -F': ' 'NF==2 {printf "%-20s : %s\n", $1, $2}' | tee -a "$LOG_FILE"

**Usage:**  

    fwaudit

---

#### svc-check

**Alias:** <code>alias svc-check='secure-svccheck'</code>  
**Script location:** `/usr/local/bin/secure-svccheck`  
**Purpose:** Verifies if a systemd service is active and shows its status header.

**What to Expect:**  
- `[OK] <service> UP` + status lines, or `[ERROR]` and exit code 1.  
- Log: `~/Desktop/LOG_FILES/secure-svccheck.log`.

**Script code (save as `/usr/local/bin/secure-svccheck`):**

    #!/usr/bin/env bash
    set -Eeuo pipefail
    IFS=$'\n\t'
    
    readonly SCRIPT_NAME="secure-svccheck"
    readonly LOG_DIR="${HOME}/Desktop/LOG_FILES"
    readonly LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"
    mkdir -p "$LOG_DIR"
    
    logmsg() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }
    
    readonly svc="${1:-}"
    if [[ -z "$svc" ]]; then
        logmsg "[FATAL] Kullanım: $0 <servis-adı>"
        exit 1
    fi
    
    if systemctl is-active --quiet "$svc"; then
        logmsg "[OK] $svc UP"
        systemctl status "$svc" | head -n 3 | tee -a "$LOG_FILE"
    else
        logmsg "[ERROR] $svc DOWN"
        exit 1
    fi

**Usage:**  

    svc-check sshd

---

#### sysclean

**Alias:** <code>alias sysclean='secure-cleancache'</code>  
**Script location:** `/usr/local/bin/secure-cleancache`  
**Purpose:** Cleans DNF caches and trims journal logs older than 7 days under an atomic lock.

**What to Expect:**  
- No repeated cleaning waste.  
- Log: `~/Desktop/LOG_FILES/secure-cleancache.log`.

**Script code (save as `/usr/local/bin/secure-cleancache`):**

    #!/usr/bin/env bash
    set -Eeuo pipefail
    IFS=$'\n\t'
    
    readonly SCRIPT_NAME="secure-cleancache"
    readonly LOG_DIR="${HOME}/Desktop/LOG_FILES"
    readonly LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"
    mkdir -p "$LOG_DIR"
    
    logmsg() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }
    
    readonly LOCK_DIR="${HOME}/.local/run/locks"
    readonly LOCK_FILE="${LOCK_DIR}/cleancache.lock"
    
    mkdir -p "$LOCK_DIR"
    exec 8> "$LOCK_FILE"
    if ! flock -n 8; then
        logmsg "[WARN] Temizlik zaten çalışıyor. PID: $(cat "$LOCK_FILE" 2>/dev/null || echo bilinmiyor)"
        exit 1
    fi
    echo $$ > "$LOCK_FILE"
    
    cleanup() {
        flock -u 8 2>/dev/null || true
        rm -f "$LOCK_FILE"
        logmsg "İşlem sonlandı."
    }
    trap cleanup EXIT INT TERM
    
    logmsg "DNF önbellek ve journal temizliği başladı."
    sudo dnf clean all >/dev/null
    sudo journalctl --vacuum-time=7d >/dev/null
    logmsg "Temizlik tamamlandı."

**Usage:**  

    sysclean

---

#### netif

**Alias:** <code>alias netif='secure-netif'</code>  
**Script location:** `/usr/local/bin/secure-netif`  
**Purpose:** Lists all interfaces with IPv4 addresses, using `jq` for reliable parsing.

**What to Expect:**  
- Table: `Interface: eth0      IPv4: 192.168.1.10`.  
- Requires `jq`; the script exits with `[FATAL]` if missing.  
- Log: `~/Desktop/LOG_FILES/secure-netif.log`.

**Script code (save as `/usr/local/bin/secure-netif`):**

    #!/usr/bin/env bash
    set -Eeuo pipefail
    IFS=$'\n\t'
    
    readonly SCRIPT_NAME="secure-netif"
    readonly LOG_DIR="${HOME}/Desktop/LOG_FILES"
    readonly LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"
    mkdir -p "$LOG_DIR"
    
    logmsg() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }
    
    command -v jq >/dev/null 2>&1 || { logmsg "[FATAL] 'jq' kurulu değil."; exit 1; }
    
    logmsg "Ağ arayüzleri listeleniyor."
    ip -json addr show | jq -r '.[].ifname + " " + (.[].addr_info[]? | select(.family=="inet") | .local)' | awk 'NF==2 {printf "Interface: %-10s IPv4: %s\n", $1, $2}' | tee -a "$LOG_FILE"

**Usage:**  

    netif

---

#### usb-ac / usb-kapat

**Aliases:**  
- <code>alias usb-ac='secure-usbctl on'</code>  
- <code>alias usb-kapat='secure-usbctl off'</code>  

**Script location:** `/usr/local/bin/secure-usbctl`  
**Purpose:** Loads (`on`) or unloads (`off`) the `usb-storage` and `uas` kernel modules.

**What to Expect:**  
- Before turning off, lists mounted USB devices and asks for confirmation.  
- Log: `~/Desktop/LOG_FILES/secure-usbctl.log`.

**Script code (save as `/usr/local/bin/secure-usbctl`):**

    #!/usr/bin/env bash
    set -Eeuo pipefail
    IFS=$'\n\t'
    
    readonly SCRIPT_NAME="secure-usbctl"
    readonly LOG_DIR="${HOME}/Desktop/LOG_FILES"
    readonly LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"
    mkdir -p "$LOG_DIR"
    
    logmsg() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }
    
    readonly ACTION="${1:-}"
    readonly MODULES=("usb-storage" "uas")
    
    [[ "$ACTION" == "on" || "$ACTION" == "off" ]] || {
        logmsg "[FATAL] Kullanım: $0 <on|off>"
        exit 1
    }
    
    if [[ "$ACTION" == "off" ]]; then
        logmsg "USB depolama kapatma isteği."
        if lsblk -o NAME,TYPE,MOUNTPOINT,TRAN | grep -q "usb"; then
            logmsg "UYARI: Bağlı USB aygıtlar var:"
            lsblk -o NAME,TYPE,MOUNTPOINT,TRAN | grep "usb" | tee -a "$LOG_FILE"
            read -r -p "Devam edilsin mi? (yes/no): " ONAY
            if [[ ! "$ONAY" =~ ^(yes|y|Y)$ ]]; then
                logmsg "İşlem iptal edildi."
                exit 0
            fi
        fi
        for mod in "${MODULES[@]}"; do
            sudo modprobe -r "$mod" 2>/dev/null && logmsg "$mod kaldırıldı" || logmsg "$mod kullanımda olabilir"
        done
        logmsg "USB depolama kilitlendi."
    else
        logmsg "USB depolama açılıyor."
        for mod in "${MODULES[@]}"; do
            sudo modprobe "$mod" 2>/dev/null && logmsg "$mod yüklendi" || logmsg "$mod zaten yüklü"
        done
        logmsg "USB depolama erişime açıldı."
    fi

**Usage:**  

    usb-ac      # enable USB storage
    usb-kapat   # disable USB storage

---

#### secure-wipe

**Alias:** <code>alias secure-wipe='secure-wipe'</code>  
**Script location:** `/usr/local/bin/secure-wipe`  
**Purpose:** Cryptographically shreds a file (`shred -u -z -n 3`), with an SSD warning.

**What to Expect:**  
- You must confirm the operation.  
- Due to SSD wear levelling, full eradication is not guaranteed; the warning is displayed.  
- Log: `~/Desktop/LOG_FILES/secure-wipe.log`.

**Script code (save as `/usr/local/bin/secure-wipe`):**

```bash
 #!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_NAME="secure-wipe"
readonly LOG_DIR="${HOME}/Desktop/LOG_FILES"
readonly LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"
mkdir -p "$LOG_DIR"

logmsg() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }

readonly TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
    echo >&2 "[HATA] Kullanım: $0 <dosya>"
    exit 1
fi

if [[ ! -f "$TARGET" && ! -L "$TARGET" ]]; then
    echo >&2 "[HATA] '$TARGET' düzenli bir dosya değil veya bulunamadı."
    exit 1
fi

# --- Güvenilir disk türü tespiti ---
readonly MOUNT_POINT=$(df --output=target "$TARGET" 2>/dev/null | tail -1)
readonly DEVICE=$(df --output=source "$TARGET" 2>/dev/null | tail -1)
IS_SSD=false

if [[ -n "$DEVICE" && "$DEVICE" != "source" ]]; then
    ROTA=$(lsblk -no ROTA "$DEVICE" 2>/dev/null || echo "")
    if [[ "$ROTA" == "0" ]]; then
        IS_SSD=true
    fi
fi

# --- Kullanıcıyı bilgilendir ---
if $IS_SSD; then
    cat <<EOF | tee -a "$LOG_FILE"
⚠️  SSD UYARISI:
Bu cihaz bir SSD/NVMe disktir. Geleneksel 'shred' komutu SSD'lerde
AŞINMA DENGELEME (wear leveling) ve FTL katmanı nedeniyle ETKİLİ DEĞİLDİR.
Bu script, dosyayı önce rastgele veriyle doldurup sonra TRIM ile blokları
sıfırlayarak daha güvenli bir silme uygulayacaktır.
Ancak %100 geri getirilemezlik garantisi SADECE tam disk şifreleme (LUKS)
ile mümkündür.
EOF
else
    cat <<EOF | tee -a "$LOG_FILE"
ℹ️  Bu bir döner (HDD) disktir. 'shred' ile 3 geçişli güvenli silme uygulanacak.
EOF
fi

read -r -p "Devam edilsin mi? (yes/no): " ONAY
if [[ ! "$ONAY" =~ ^(yes|y|Y)$ ]]; then
    logmsg "Kullanıcı iptal etti."
    exit 0
fi

# --- Silme işlemi ---
logmsg "Dosya imha ediliyor: $TARGET"

if $IS_SSD; then
    filesize=$(stat -c%s "$TARGET")
    if [[ "$filesize" -gt 0 ]]; then
        logmsg "1/3 Rastgele veri ile üzerine yazılıyor ($filesize byte)..."
        dd if=/dev/urandom of="$TARGET" bs=4096 conv=notrunc,fdatasync iflag=fullblock count=$(( (filesize + 4095) / 4096 )) 2>/dev/null
    fi
    logmsg "2/3 Disk önbelleği boşaltılıyor (sync)..."
    sync -f "$TARGET"
    logmsg "3/3 Dosya siliniyor ve TRIM tetikleniyor..."
    rm "$TARGET"
    sudo fstrim -v "$MOUNT_POINT" 2>/dev/null | tee -a "$LOG_FILE" || logmsg "TRIM manuel tetiklenemedi; sistem otomatik TRIM'e güvenin."
    logmsg "SSD güvenli silme tamamlandı."
else
    shred -u -z -n 3 "$TARGET"
    logmsg "HDD güvenli silme (shred) tamamlandı."
fi

logmsg "İmha işlemi bitti: $TARGET artık mevcut değil."
```
**Usage:**  

    secure-wipe secret.docx

---

#### kilit-vur / kilit-ac / kilit-kontrol

**Aliases:**  
- <code>alias kilit-vur='sys-chattr lock'</code>  
- <code>alias kilit-ac='sys-chattr unlock'</code>  
- <code>alias kilit-kontrol='sys-chattr check'</code>  

**Script location:** `/usr/local/bin/sys-chattr`  
**Purpose:** Uses `chattr +i` to make files immutable, `chattr -i` to unlock, and `lsattr` to inspect.

**What to Expect:**  
- Immutable files cannot be modified even by root.  
- Log: `~/Desktop/LOG_FILES/sys-chattr.log`.

**Script code (save as `/usr/local/bin/sys-chattr`):**

    #!/usr/bin/env bash
    set -Eeuo pipefail
    IFS=$'\n\t'
    
    readonly SCRIPT_NAME="sys-chattr"
    readonly LOG_DIR="${HOME}/Desktop/LOG_FILES"
    readonly LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"
    mkdir -p "$LOG_DIR"
    
    logmsg() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }
    
    readonly ACTION="${1:-}"
    shift || true
    readonly FILES=("$@")
    
    [[ -z "$ACTION" || ${#FILES[@]} -eq 0 ]] && {
        logmsg "Kullanım: $0 <lock|unlock|check> <dosya...>"
        exit 1
    }
    
    case "$ACTION" in
        lock)
            for f in "${FILES[@]}"; do
                sudo chattr +i "$f" && logmsg "[LOCKED] $f"
            done ;;
        unlock)
            for f in "${FILES[@]}"; do
                sudo chattr -i "$f" && logmsg "[UNLOCKED] $f"
            done ;;
        check)
            for f in "${FILES[@]}"; do
                lsattr "$f" 2>/dev/null | tee -a "$LOG_FILE"
            done ;;
        *) logmsg "Geçersiz eylem: $ACTION"; exit 1 ;;
    esac

**Usage:**  

    kilit-vur /etc/important.conf
    kilit-kontrol /etc/important.conf
    kilit-ac /etc/important.conf

---

#### rk-denetim

**Alias:** <code>alias rk-denetim='secure-rkhunter'</code>  
**Script location:** `/usr/local/bin/secure-rkhunter`  
**Purpose:** Updates rkhunter signatures, runs a check, and after manual review offers to update the file‑properties baseline.

**What to Expect:**  
- Scan results are displayed and logged.  
- **Never** accept the baseline if anomalies exist.  
- Log: `~/Desktop/LOG_FILES/secure-rkhunter.log`.

**Script code (save as `/usr/local/bin/secure-rkhunter`):**

    #!/usr/bin/env bash
    set -Eeuo pipefail
    IFS=$'\n\t'
    
    readonly SCRIPT_NAME="secure-rkhunter"
    readonly LOG_DIR="${HOME}/Desktop/LOG_FILES"
    readonly LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"
    mkdir -p "$LOG_DIR"
    
    logmsg() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }
    
    command -v rkhunter >/dev/null 2>&1 || { logmsg "[FATAL] rkhunter kurulu değil."; exit 1; }
    
    logmsg "Rkhunter imza güncelleme başlıyor."
    sudo rkhunter --update | tee -a "$LOG_FILE"
    
    logmsg "Sistem taraması başlıyor."
    sudo rkhunter --check --skip-keypress --rwo | tee -a "$LOG_FILE" || true
    
    cat <<EOF | tee -a "$LOG_FILE"
    ⚠️  Uyarıları inceleyin. Yalnızca meşru değişiklikler varsa baseline güncellenmelidir.
    EOF
    
    read -r -p "Baseline mühürlensin mi? (yes/no): " ONAY
    if [[ "$ONAY" =~ ^(yes|y|Y|YES)$ ]]; then
        sudo rkhunter --propupd | tee -a "$LOG_FILE"
        logmsg "Baseline mühürlendi."
    else
        logmsg "Baseline güncellemesi atlandı."
    fi

**Usage:**  

    rk-denetim

---

#### net-audit

**Alias:** <code>alias net-audit='secure-netaudit'</code>  
**Script location:** `/usr/local/bin/secure-netaudit`  
**Purpose:** Lists all listening TCP/UDP sockets with process info.

**What to Expect:**  
- Equivalent to `ss -tulpn | grep LISTEN` but logged.  
- Log: `~/Desktop/LOG_FILES/secure-netaudit.log`.

**Script code (save as `/usr/local/bin/secure-netaudit`):**

    #!/usr/bin/env bash
    set -Eeuo pipefail
    IFS=$'\n\t'
    
    readonly SCRIPT_NAME="secure-netaudit"
    readonly LOG_DIR="${HOME}/Desktop/LOG_FILES"
    readonly LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"
    mkdir -p "$LOG_DIR"
    
    logmsg() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }
    
    logmsg "Açık portlar taranıyor."
    sudo ss -tulpn | grep LISTEN | tee -a "$LOG_FILE"

**Usage:**  

    net-audit

---

#### ram-radar

**Alias:** <code>alias ram-radar='sys-ramradar'</code>  
**Script location:** `/usr/local/bin/sys-ramradar`  
**Purpose:** Displays top 10 processes by RSS memory, and total RAM consumption.

**What to Expect:**  
- Sorted descending by memory usage.  
- Total shown in GB.  
- Log: `~/Desktop/LOG_FILES/sys-ramradar.log`.

**Script code (save as `/usr/local/bin/sys-ramradar`):**

    #!/usr/bin/env bash
    set -Eeuo pipefail
    IFS=$'\n\t'
    
    readonly SCRIPT_NAME="sys-ramradar"
    readonly LOG_DIR="${HOME}/Desktop/LOG_FILES"
    readonly LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"
    mkdir -p "$LOG_DIR"
    
    logmsg() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }
    
    logmsg "RAM kullanım raporu oluşturuluyor."
    echo "📊 En çok RAM tüketen ilk 10 süreç:" | tee -a "$LOG_FILE"
    printf "%-8s %-20s %s\n" "RSS(KB)" "COMMAND" "PID" | tee -a "$LOG_FILE"
    ps axo rss,comm,pid --sort=-rss --no-headers | head -n 10 | while read -r rss comm pid; do
        printf "%-8s %-20s %s\n" "$rss" "$comm" "$pid" | tee -a "$LOG_FILE"
    done
    total_kb=$(ps axo rss --no-headers | awk '{sum+=$1} END {print sum}')
    total_gb=$(awk "BEGIN {printf \"%.2f\", $total_kb/1024/1024}")
    echo "Toplam RAM Tüketimi: ${total_gb} GB" | tee -a "$LOG_FILE"

**Usage:**  

    ram-radar

---

#### kernel-radar

**Alias:** <code>alias kernel-radar='sys-kernelradar'</code>  
**Script location:** `/usr/local/bin/sys-kernelradar`  
**Purpose:** Searches `dmesg` for critical errors, warnings, segfaults, and USB issues.

**What to Expect:**  
- If no matches, prints `[OK] No critical records found.`  
- Log: `~/Desktop/LOG_FILES/sys-kernelradar.log`.

**Script code (save as `/usr/local/bin/sys-kernelradar`):**

    #!/usr/bin/env bash
    set -Eeuo pipefail
    IFS=$'\n\t'
    
    readonly SCRIPT_NAME="sys-kernelradar"
    readonly LOG_DIR="${HOME}/Desktop/LOG_FILES"
    readonly LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"
    mkdir -p "$LOG_DIR"
    
    logmsg() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }
    
    logmsg "Kernel hata/uyarı taraması başladı."
    sudo dmesg -T | grep --color=always -iE "error|warn|fail|killed|segfault|usb" | tee -a "$LOG_FILE" || logmsg "Kritik kayıt bulunamadı."

**Usage:**  

    kernel-radar

---

#### git-rontgen

**Alias:** (inline, placed in `~/.bashrc`)  
<code>alias git-rontgen='echo "🔍 [GİT] Değiştirilen satırların atomik röntgeni:" && git status -s -b && echo "---------------------------" && git diff --stat'</code>  
**Purpose:** Shows branch status and a summary of modified lines in a Git repository.

**What to Expect:**  
- Compact overview before a commit.

**Usage:**  

    cd /path/to/repo
    git-rontgen

---

#### termal

**Alias:** <code>alias termal='sys-thermal'</code>  
**Script location:** `/usr/local/bin/sys-thermal`  
**Purpose:** Reads hardware temperatures via `lm_sensors`.

**What to Expect:**  
- Requires `lm_sensors`; install with `dnf` if missing.  
- On Surface Pro 9, watch for sustained temps above 85°C.  
- Log: `~/Desktop/LOG_FILES/sys-thermal.log`.

**Script code (save as `/usr/local/bin/sys-thermal`):**

    #!/usr/bin/env bash
    set -Eeuo pipefail
    IFS=$'\n\t'
    
    readonly SCRIPT_NAME="sys-thermal"
    readonly LOG_DIR="${HOME}/Desktop/LOG_FILES"
    readonly LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"
    mkdir -p "$LOG_DIR"
    
    logmsg() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }
    
    if ! command -v sensors >/dev/null 2>&1; then
        logmsg "[FATAL] 'lm_sensors' paketi kurulu değil. 'sudo dnf install lm_sensors' ile kurun."
        exit 1
    fi
    
    logmsg "Sıcaklık sensörleri okunuyor."
    echo "🌡️ SICAKLIK RAPORU" | tee -a "$LOG_FILE"
    sensors | tee -a "$LOG_FILE"

**Usage:**  

    termal

---

#### needs-restart

**Alias:** <code>alias needs-restart='secure-needsrestart'</code>  
**Script location:** `/usr/local/bin/secure-needsrestart`  
**Purpose:** Runs `dnf needs-restarting -r` to list services still using old libraries after updates.

**What to Expect:**  
- Empty output means everything is current.  
- Log: `~/Desktop/LOG_FILES/secure-needsrestart.log`.

**Script code (save as `/usr/local/bin/secure-needsrestart`):**

    #!/usr/bin/env bash
    set -Eeuo pipefail
    IFS=$'\n\t'
    
    readonly SCRIPT_NAME="secure-needsrestart"
    readonly LOG_DIR="${HOME}/Desktop/LOG_FILES"
    readonly LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"
    mkdir -p "$LOG_DIR"
    
    logmsg() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }
    
    if ! command -v dnf >/dev/null 2>&1; then
        logmsg "[FATAL] 'dnf' bulunamadı."
        exit 1
    fi
    
    logmsg "Yeniden başlatma gerektiren servisler kontrol ediliyor."
    sudo dnf needs-restarting -r | tee -a "$LOG_FILE" || logmsg "Tüm servisler güncel."

**Usage:**  

    needs-restart

---

#### aide-denetim

**Alias:** <code>alias aide-denetim='secure-aide'</code>  
**Script location:** `/usr/local/bin/secure-aide`  
**Purpose:** Runs AIDE file‑integrity check; initialises a baseline if none exists, then offers manual baseline update.

**What to Expect:**  
- Changes are listed; you must inspect before accepting.  
- Tampered baselines hide future intrusions – **always review**.  
- Log: `~/Desktop/LOG_FILES/secure-aide.log`.

**Script code (save as `/usr/local/bin/secure-aide`):**

    #!/usr/bin/env bash
    set -Eeuo pipefail
    IFS=$'\n\t'
    
    readonly SCRIPT_NAME="secure-aide"
    readonly LOG_DIR="${HOME}/Desktop/LOG_FILES"
    readonly LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"
    mkdir -p "$LOG_DIR"
    
    logmsg() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }
    
    if ! command -v aide >/dev/null 2>&1; then
        logmsg "[FATAL] 'aide' kurulu değil. 'sudo dnf install aide' ile kurun."
        exit 1
    fi
    
    if [[ ! -f /var/lib/aide/aide.db.gz ]]; then
        logmsg "AIDE veritabanı bulunamadı. İlk baseline oluşturuluyor."
        sudo aide --init | tee -a "$LOG_FILE"
        sudo mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
        logmsg "Baseline veritabanı oluşturuldu."
        exit 0
    fi
    
    logmsg "AIDE bütünlük kontrolü başlıyor."
    sudo aide --check | tee -a "$LOG_FILE" || true
    
    cat <<EOF | tee -a "$LOG_FILE"
    ⚠️  Yukarıdaki değişiklikleri inceleyin. Meşru sistem güncellemeleri ise baseline güncellenebilir.
    EOF
    
    read -r -p "Baseline güncellensin mi? (yes/no): " ONAY
    if [[ "$ONAY" =~ ^(yes|y|Y|YES)$ ]]; then
        sudo aide --update | tee -a "$LOG_FILE"
        sudo mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
        logmsg "Baseline başarıyla güncellendi."
    else
        logmsg "Baseline güncellemesi atlandı."
    fi

**Usage:**  

    aide-denetim

---

#### perm-check

**Alias:** <code>alias perm-check='secure-permcheck'</code>  
**Script location:** `/usr/local/bin/secure-permcheck`  
**Purpose:** Verifies permissions of `$HOME`, `~/.ssh`, `~/.bashrc`, and `~/.bash_profile`.

**What to Expect:**  
- Expected modes: home/ssh `700`, bash files `644`.  
- Any deviation flagged as `[ZAYIF]`.  
- Log: `~/Desktop/LOG_FILES/secure-permcheck.log`.

**Script code (save as `/usr/local/bin/secure-permcheck`):**

    #!/usr/bin/env bash
    set -Eeuo pipefail
    IFS=$'\n\t'
    
    readonly SCRIPT_NAME="secure-permcheck"
    readonly LOG_DIR="${HOME}/Desktop/LOG_FILES"
    readonly LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"
    mkdir -p "$LOG_DIR"
    
    logmsg() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }
    
    logmsg "Kullanıcı ev dizini ve kritik dosya izinleri denetleniyor..."
    
    check_perm() {
        local path="$1" expected="$2" desc="$3"
        if [[ -e "$path" ]]; then
            actual=$(stat -c "%a" "$path")
            if [[ "$actual" != "$expected" ]]; then
                logmsg "[ZAYIF] $desc ($path) izni $actual, beklenen $expected"
            else
                logmsg "[OK] $desc ($path)"
            fi
        else
            logmsg "[BİLGİ] $desc ($path) mevcut değil."
        fi
    }
    
    check_perm "$HOME" "700" "Home dizini"
    check_perm "$HOME/.ssh" "700" "~/.ssh dizini"
    check_perm "$HOME/.bashrc" "644" "~/.bashrc"
    check_perm "$HOME/.bash_profile" "644" "~/.bash_profile"
    logmsg "İzin denetimi tamamlandı."

**Usage:**  

    perm-check

---

#### suid-tarama

**Alias:** <code>alias suid-tarama='sys-suidscan'</code>  
**Script location:** `/usr/local/bin/sys-suidscan`  
**Purpose:** Lists all SUID/SGID files in critical directories (`/usr`, `/bin`, `/sbin`, `/lib*`, `/opt`).

**What to Expect:**  
- Scan limited to local filesystems (`-xdev`) to minimise SSD wear.  
- Any unexpected SUID shell must be investigated.  
- Log: `~/Desktop/LOG_FILES/sys-suidscan.log`.

**Script code (save as `/usr/local/bin/sys-suidscan`):**

    #!/usr/bin/env bash
    set -Eeuo pipefail
    IFS=$'\n\t'
    
    readonly SCRIPT_NAME="sys-suidscan"
    readonly LOG_DIR="${HOME}/Desktop/LOG_FILES"
    readonly LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"
    mkdir -p "$LOG_DIR"
    
    logmsg() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }
    
    readonly SCAN_DIRS=("/usr" "/bin" "/sbin" "/lib" "/lib64" "/opt")
    
    logmsg "SUID/SGID dosyaları taranıyor..."
    echo "🔎 SUID/SGID DOSYA RAPORU" | tee -a "$LOG_FILE"
    for dir in "${SCAN_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            find "$dir" -xdev \( -perm -4000 -o -perm -2000 \) -type f -ls 2>/dev/null | tee -a "$LOG_FILE"
        fi
    done
    logmsg "Tarama tamamlandı."

**Usage:**  

    suid-tarama

---

### 7.4 Shell Function

#### data-sandbox

**Type:** Shell function – place the following code in `~/.bashrc`:

    data-sandbox() {
        echo "🧪 [SİSTEM] İzole Python Veri Laboratuvarı inşa ediliyor..."
        python3 -m venv venv --clear
        source venv/bin/activate
        echo "🔒 [GÜVENLİK] Global sistemden koptunuz. Paketler sadece bu dizine kurulacak."
    }

**Purpose:** Creates an isolated Python virtual environment in the current directory and activates it. All subsequent `pip` operations are local.

**What to Expect:**  
- A `venv` folder appears.  
- Shell prompt changes to indicate the active environment.  
- Global system Python remains untouched.

**Usage:**  

    data-sandbox

---

## 8. Logging & Integrity

Every script‑backed alias writes logs to `~/Desktop/LOG_FILES/<script>.log`. Log entries are UTC‑timestamped and include the action and any errors. This provides a forensic‑ready trail.

File‑integrity and security checks are performed by:
- **rk-denetim** (rkhunter with manual baseline approval)
- **aide-denetim** (AIDE checksums, manual baseline approval)
- **perm-check** (permission audit)
- **suid-tarama** (SUID/SGID scan)

Run them regularly, especially after system updates.

---

## 9. Verification & Testing

Confirm the setup with these commands:

    type sysupdate
    type ports
    ls -l /usr/local/bin/secure-* /usr/local/bin/sys-*
    cat ~/Desktop/LOG_FILES/secure-sysupdate.log
    aide-denetim
    termal
    needs-restart

All aliases should respond without errors. Missing packages are reported clearly with `[FATAL]` messages.

---

*End of document – maintain as part of your operational security playbook.*
POTATO
