# USBGuard Safe Authorizer
## Zero-Trust USB Device Authorization Framework

### ENGLISH -------------------------------------------------- TÜRKÇE
| ing | Tur |
| :--- | :--- |
| # 🛡️ USBGuard Zero-Trust Manager (Enterprise-Grade)<br><br>Can a simple USB flash drive, mouse, or keyboard compromise your system? Absolutely. Physical intrusion methods like BadUSB and Rubber Ducky disguise malicious payloads within seemingly innocent hardware to gain direct access to your machine.<br><br>**USBGuard** is the ultimate shield against physical intrusions on Linux systems. However, its standard usage is complex, and "auto-allow" processes can lead to severe cybersecurity vulnerabilities known as **TOCTOU (Time-of-Check to Time-of-Use) Race Conditions**.<br><br>This bash script simplifies USBGuard management for standard users through a **Zero-Trust** philosophy, while running an enterprise-grade architectural defense mechanism in the background.<br><br>## ✨ Why Use This Script? (Our Technical Difference)<br><br>Why should you use this script instead of the standard `usbguard allow-device` command?<br><br>* **Hardware 2FA (Dual-Factor Authentication):** It does not blindly trust the temporary Device ID. It verifies the cryptographic fingerprint (**Hash**) and the physical connection point on the motherboard (**Topological Via-Port**).<br>* **Isolated Testing (Sandbox Phase):** It never grants permanent permission immediately. It first grants "Temporary Permission". You test if your device works normally. If it passes, you lock it in.<br>* **Race Condition Protection:** The script utilizes kernel-level atomic locks (`flock`). Even if executed multiple times accidentally, it prevents system file corruption and inode split-brain issues.<br>* **Deterministic Data Analysis:** It doesn't rely on fragile text-scraping. It structures USBGuard outputs using mathematical matrices (**AWK**), ensuring 100% immunity against output format changes and false blockings.| |
| ## 🚀 Installation | |
| We will install the script in the secure directory reserved for persistent system administrator tools (`/usr/local/bin`). Open your terminal and paste the following commands:| |

**1. Download the script and move it to the secure directory:**
```bash
sudo curl -o /usr/local/bin/usb-authorize.sh [https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/usb-authorize.sh](https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/usb-authorize.sh) |  |
