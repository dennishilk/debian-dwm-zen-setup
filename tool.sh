#!/bin/bash
# =============================================================
# 🧰 Dennis Hilk's Debian 13 DWM Tool Installer v2
#  - Grouped Menus (System, Creator, Gaming, Network, Fun, Utils)
# =============================================================
set -e
LOGFILE="$HOME/tool_install.log"

# --- prerequisites -----------------------------------------------------------
sudo apt update -y >/dev/null
sudo apt install -y dialog curl wget flatpak ca-certificates gpg >/dev/null
sudo apt install -y software-properties-common >/dev/null 2>&1 || \
sudo apt install -y python3-software-properties >/dev/null 2>&1 || \
echo "⚠️ software-properties-common not available (skipped)"


# --- helper ------------------------------------------------------------------
install_pkg() {
  local pkg="$1"
  echo "📦 Installing: $pkg" | tee -a "$LOGFILE"
  if sudo apt install -y "$pkg" >>"$LOGFILE" 2>&1; then
    echo "✅ Installed: $pkg" | tee -a "$LOGFILE"
  else
    echo "❌ Failed: $pkg" | tee -a "$LOGFILE"
  fi
}
flatpak_pkg() {
  local id="$1"
  echo "📦 Flatpak: $id" | tee -a "$LOGFILE"
  flatpak install -y flathub "$id" >>"$LOGFILE" 2>&1 || echo "⚠️ Flatpak $id failed" | tee -a "$LOGFILE"
}

# --- menu loop ---------------------------------------------------------------
while true; do
  cmd=(dialog --clear --title "Dennis Hilk – Tool Installer" --menu "Choose category:" 18 70 10)
  options=(
    1 "🧩  System & Info"
    2 "💻  Creator / Media Tools"
    3 "🎮  Gaming / Emulation"
    4 "📡  Network & Security"
    5 "🧰  Utilities / Desktop Tools"
    6 "😎  Fun / Nerd Stuff"
    7 "🚪  Exit"
  )
  choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty) || clear && exit 0
  clear

  case $choice in
  # --- SYSTEM & INFO ---------------------------------------------------------
  1)
    dialog --checklist "Select System Tools:" 20 70 10 \
      1 "fastfetch" off \
      2 "btop" off \
      3 "htop" off \
      4 "nvtop" off \
      5 "inxi" off \
      6 "cpufetch" off 2>temp_choice
    clear
    for i in $(cat temp_choice); do
      case $i in
        1) install_pkg fastfetch ;;
        2) install_pkg btop ;;
        3) install_pkg htop ;;
        4) install_pkg nvtop ;;
        5) install_pkg inxi ;;
        6) install_pkg cpufetch ;;
      esac
    done
    ;;
  # --- CREATOR / MEDIA -------------------------------------------------------
  2)
    dialog --checklist "Select Creator Tools:" 20 70 10 \
      1 "obs-studio" off \
      2 "kdenlive" off \
      3 "audacity" off \
      4 "gimp" off \
      5 "inkscape" off \
      6 "ffmpeg" off \
      7 "handbrake" off \
      8 "olive-editor (Flatpak)" off \
      9 "screenkey" off 2>temp_choice
    clear
    for i in $(cat temp_choice); do
      case $i in
        1) install_pkg obs-studio ;;
        2) install_pkg kdenlive ;;
        3) install_pkg audacity ;;
        4) install_pkg gimp ;;
        5) install_pkg inkscape ;;
        6) install_pkg ffmpeg ;;
        7) install_pkg handbrake ;;
        8) flatpak_pkg org.olivevideoeditor.Olive ;;
        9) install_pkg screenkey ;;
      esac
    done
    ;;
  # --- GAMING ---------------------------------------------------------------
  3)
    dialog --checklist "Select Gaming Tools:" 20 70 10 \
      1 "steam" off \
      2 "lutris (Flatpak)" off \
      3 "heroic-games-launcher (Flatpak)" off \
      4 "protonup-qt (Flatpak)" off \
      5 "retroarch" off 2>temp_choice
    clear
    for i in $(cat temp_choice); do
      case $i in
        1) sudo dpkg --add-architecture i386 && sudo apt update && install_pkg steam ;;
        2) flatpak_pkg net.lutris.Lutris ;;
        3) flatpak_pkg com.heroicgameslauncher.hgl ;;
        4) flatpak_pkg net.davidotek.pupgui2 ;;
        5) install_pkg retroarch ;;
      esac
    done
    ;;
  # --- NETWORK & SECURITY ---------------------------------------------------
  4)
    dialog --checklist "Select Network/Security Tools:" 20 70 10 \
      1 "firefox-esr" off \
      2 "google-chrome" off \
      3 "brave-browser (Flatpak)" off \
      4 "telegram-desktop" off \
      5 "signal-desktop (Flatpak)" off \
      6 "filezilla" off \
      7 "qbittorrent" off \
      8 "ufw + gufw" off \
      9 "wireshark" off \
      10 "nmap" off 2>temp_choice
    clear
    for i in $(cat temp_choice); do
      case $i in
        1) install_pkg firefox-esr ;;
        2) wget -q -O /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && sudo apt install -y /tmp/google-chrome.deb ;;
        3) flatpak_pkg com.brave.Browser ;;
        4) install_pkg telegram-desktop ;;
        5) flatpak_pkg org.signal.Signal ;;
        6) install_pkg filezilla ;;
        7) install_pkg qbittorrent ;;
        8) install_pkg ufw && install_pkg gufw ;;
        9) install_pkg wireshark ;;
        10) install_pkg nmap ;;
      esac
    done
    ;;
  # --- UTILITIES ------------------------------------------------------------
  5)
    dialog --checklist "Select Utilities:" 20 70 10 \
      1 "pavucontrol (audio mixer)" off \
      2 "blueman (bluetooth)" off \
      3 "flameshot (screenshots)" off \
      4 "timeshift" off \
      5 "filelight" off \
      6 "grub-customizer" off \
      7 "gnome-system-monitor" off \
      8 "baobab (disk usage)" off 2>temp_choice
    clear
    for i in $(cat temp_choice); do
      case $i in
        1) install_pkg pavucontrol ;;
        2) install_pkg blueman ;;
        3) install_pkg flameshot ;;
        4) install_pkg timeshift ;;
        5) install_pkg filelight ;;
        6) install_pkg grub-customizer ;;
        7) install_pkg gnome-system-monitor ;;
        8) install_pkg baobab ;;
      esac
    done
    ;;
  # --- FUN / NERD -----------------------------------------------------------
  6)
    dialog --checklist "Select Nerd/Fun Tools:" 20 70 10 \
      1 "cmatrix" off \
      2 "pipes.sh" off \
      3 "toilet" off \
      4 "figlet" off \
      5 "lolcat" off \
      6 "cava" off \
      7 "tty-clock" off \
      8 "asciiquarium" off 2>temp_choice
    clear
    for i in $(cat temp_choice); do
      case $i in
        1) install_pkg cmatrix ;;
        2) install_pkg pipes.sh ;;
        3) install_pkg toilet ;;
        4) install_pkg figlet ;;
        5) install_pkg lolcat ;;
        6) install_pkg cava ;;
        7) install_pkg tty-clock ;;
        8) install_pkg asciiquarium ;;
      esac
    done
    ;;
  # --- EXIT -----------------------------------------------------------------
  7)
    clear
    echo "🎉 Installation complete!"
    echo "📝 Logfile saved at: $LOGFILE"
    exit 0
    ;;
  esac
done
