#!/bin/bash
# Debian 13 Minimal DWM Setup by Dennis Hilk

set -e

echo "🐧 Starte erweitertes DWM Setup für Debian 13..."

sudo apt update && sudo apt upgrade -y

# X11, Build Tools, Core Tools
sudo apt install -y xorg xserver-xorg xinit make gcc git pkg-config \
  libx11-dev libxft-dev libxinerama-dev curl wget neofetch fastfetch htop feh unzip

# Zen Kernel via Liquorix
echo "⚙️ Installiere Liquorix (Zen Kernel)..."
echo "deb http://liquorix.net/debian sid main" | sudo tee /etc/apt/sources.list.d/liquorix.list
sudo apt install -y curl
curl -fsSL https://liquorix.net/liquorix-keyring.gpg | sudo tee /usr/share/keyrings/liquorix-keyring.gpg > /dev/null
sudo apt update
sudo apt install -y linux-image-liquorix-amd64 linux-headers-liquorix-amd64

# Terminal, Shell, Rofi, Multimedia
sudo apt install -y kitty fish rofi picom

# Audio Stack: PipeWire
sudo apt install -y pipewire pipewire-audio pipewire-pulse pavucontrol sox playerctl

# NVIDIA (falls erkannt)
if lspci | grep -i nvidia >/dev/null; then
  echo "🟢 NVIDIA erkannt – installiere Treiber..."
  sudo apt install -y nvidia-driver firmware-misc-nonfree nvidia-settings \
    mesa-vulkan-drivers vulkan-tools libvulkan1 libvulkan1:i386
fi

# Gaming (Steam, Proton, MangoHUD)
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install -y steam mangohud gamemode vulkan-tools

# OBS Studio für Aufnahme/Streaming
sudo apt install -y obs-studio v4l2loopback-dkms

# Google Chrome Stable
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt install -y ./google-chrome-stable_current_amd64.deb

# Install sxhkd for custom hotkeys
sudo apt install -y sxhkd

# Clone and build DWM (mit Patches und Autostart)
cd ~
git clone https://github.com/dennishilk/dwm-setup.git ~/.config/dwm
cd ~/.config/dwm
sudo make clean install

# Copy config files
mkdir -p ~/.config/{kitty,fish,picom,sxhkd,fastfetch}
cp -r ../configs/* ~/.config/

# zswap aktivieren für bessere RAM/NVMe Performance
echo 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash zswap.enabled=1 zswap.compressor=lz4 zswap.max_pool_percent=20"' | sudo tee -a /etc/default/grub
sudo update-grub

# Xinit setup
echo "exec dwm" > ~/.xinitrc

# Autostart Script
chmod +x ~/.config/dwm/autostart.sh

echo "✅ Installation abgeschlossen. Bitte Neustarten und 'startx' eingeben."
