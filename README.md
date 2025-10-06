IN WORK <->



![Debian](https://img.shields.io/badge/Debian-13%20Trixie-A81D33?logo=debian&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue)
![WindowManager](https://img.shields.io/badge/WM-DWM-blue)
![Kernel](https://img.shields.io/badge/Kernel-Zen%20(Liquorix)-brightgreen)
![GPU](https://img.shields.io/badge/GPU-NVIDIA%20%7C%20AMD-orange)

### 🧩 Core System
- ✅ Builds a **minimal Debian 13 + DWM setup** from scratch  
- ✅ Installs and compiles:
  - [dwm](https://dwm.suckless.org)
  - [dmenu](https://tools.suckless.org/dmenu)
  - [slstatus](https://tools.suckless.org/slstatus)
- ✅ All Suckless tools stored in `~/.config/` instead of `/usr/src/` (non-root builds)
- ✅ Auto-compiles and patches `config.h` with default keybinds

### 🎛️ Desktop Environment
- 🪟 **Picom** compositor with automatic backend detection  
  (`glx` on real GPU hardware, `xrender` inside Proxmox/VMs)
- 🧱 **Transparent Alacritty terminal**
- 🖼️ Wallpaper support (custom or auto-generated fallback)
- ⚙️ Autostart with `.xinitrc` and `.dwm/autostart.sh`

### 🎮 GPU Support
- Interactive driver selection during install:
  - 🟩 NVIDIA (proprietary)
  - 🟥 AMD (open-source)
  - ⚪ Skip (for VMs)
- Auto-installs headers + Vulkan packages

### 🧠 Smart Modifier Key System
- Prompts you to choose your **ModKey**:
  - 🪟 **Super / Windows key** → for real hardware
  - ⌥ **Alt key** → safe for Proxmox / noVNC users  
- Automatically patches all DWM shortcuts based on your choice  
  → works flawlessly in VMs **and** on physical PCs

### 🧰 Productivity Tools
- File manager: **Thunar**
- Shell: **Fish**
- Compositor: **Picom**
- Fonts: **JetBrainsMono Nerd Font**
- Screenshot tool: `maim + xclip`
- Quick control scripts (in `~/.local/bin`):
  - `dwm-control.sh` → System updater / reboot / backup menu  
  - `quick-settings.sh` → Volume, brightness, network toggles  
  - `screen-fade.sh` → Lockscreen-like fade (no i3lock required)  
  - `screenshot.sh` → Area screenshots with clipboard copy  
  - `maintenance.sh` → Cleans logs, cache, old kernels

### 💾 System Enhancements
- ZRAM swap setup (zstd, 50% RAM, high priority)
- Nerd fonts installed in user directory (`~/.local/share/fonts`)
- Fish shell auto-starts DWM on TTY1 login
- Fully logged installation at `~/install.log`

---

## 🧑‍💻 Installation

Clone or download the repository and run the installer:

```bash
git clone https://github.com/dennishilk/debian-dwm-zen-setup.git
cd debian-dwm-zen-setup.git
chmod +x install.sh
./install.sh

🧑‍💻 Author

By Dennis Hilk
🔗 github.com/dennishilk

🐧 Linux enthusiast • open-source developer • DWM / Debian power user


🌐 Social & YouTube

🎥 Linux   YouTube.com/dennishilk

💻 GitHub: Github.com/dennishilk

🐧 Hashtags: #Linux, #Debian, #DWM, #ZenKernel, #DennisHilk
