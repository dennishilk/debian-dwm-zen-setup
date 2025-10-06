IN WORK <->

# 🧠 Debian DWM Zen Setup

![Debian](https://img.shields.io/badge/Debian-13%20Trixie-A81D33?logo=debian&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue)
![WindowManager](https://img.shields.io/badge/WM-DWM-blue)
![Kernel](https://img.shields.io/badge/Kernel-Zen%20(Liquorix)-brightgreen)
![GPU](https://img.shields.io/badge/GPU-NVIDIA%20%7C%20AMD-orange)

> ⚡️ Automated **Debian 13 (Trixie)** setup with **DWM**, **Zen Kernel (Liquorix)**, **Picom**, **Feh**, and **optional NVIDIA or AMD GPU drivers**.  
> A minimalist, high-performance Linux desktop for developers, creators, and open-source enthusiasts.

---

## 🚀 Features

- 🧱 **Fully automated setup** – just run one script  
- 💻 **DWM desktop** with autostart, transparency (Picom), and wallpaper  
- ⚙️ **Zen Kernel (Liquorix)** for better desktop and gaming performance
- 🧠 **ZRAM integration** for better memory efficiency    
- 🎮 **Optional GPU installation**
  - NVIDIA (CUDA + NVENC)
  - AMD (VAAPI + Vulkan)
- 🖼️ Wallpaper support (`coding-2.png`)
- 🧠 Lightweight, fast, and ideal for Proxmox VMs or bare-metal setups

---

## 🧩 Installation

Clone this repository and run the setup script:

```bash
git clone https://github.com/dennishilk/debian-dwm-zen-setup.git
cd debian-dwm-zen-setup
chmod +x setup_debian_dwm_zen_gpu.sh
sudo ./setup_debian_dwm_zen_gpu.sh


Place your wallpaper (coding-2.png) in the same directory before running the script.

After reboot, you can verify your GPU:

NVIDIA
nvidia-smi

AMD
vainfo | grep Driver

🖥️ Running inside Proxmox / NoVNC

If you’re using Proxmox’s NoVNC console,
you might not be able to press Shift (so Mod + Shift + Enter won’t open a terminal).

To fix this automatically, the setup script detects if it’s running in a virtual environment (VM)
and launches a terminal (stterm) automatically when DWM starts.

✅ Works out of the box — no keypress needed.
💡 On bare-metal systems, you can still open a terminal with:

Alt + Shift + Enter
or
Super + Shift + Enter
If you want to change this behavior, edit:
~/.dwm/autostart.sh
and comment out:
stterm &


💡 Tips

🐧 Perfect base for custom rices or dotfiles

💾 Great for Proxmox VM templates (16 GB disk works fine)

⚙️ Works on both UEFI and BIOS setups

🎨 Replace coding-2.png with your own wallpaper to personalize the look

🧑‍💻 Author

By Dennis Hilk
🔗 github.com/dennishilk

🐧 Linux enthusiast • open-source developer • DWM / Debian power user


🌐 Social & YouTube

🎥 Linux   YouTube.com/dennishilk

💻 GitHub: Github.com/dennishilk

🐧 Hashtags: #Linux, #Debian, #DWM, #ZenKernel, #DennisHilk
