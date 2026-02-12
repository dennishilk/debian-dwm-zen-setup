# Debian 13 dwm setup (ThinkPad T480 focused)

This repository provides a reproducible **Debian 13 (Trixie) + dwm** setup that boots to a console and starts X with `startx` from `~/.xinitrc`.

It builds **dwm from source** so your custom keybindings/layouts are guaranteed to be applied. Debian packages often install stock binaries; for dwm that means your edits in `config.h` are ignored unless you compile and install your own build.

## What is included

- `configs/dwm/config.h`
  - `Mod4` (Super) as `MODKEY`
  - tiling, floating, monocle layouts
  - workspace/tag switching (1-9)
  - launcher bindings for `dmenu` and `rofi`
  - `Super+Return` for `kitty`
  - screenshot keys via `scrot`
  - volume/brightness XF86 keys via `pactl`/`amixer` and `brightnessctl`
  - dwm status integration with a dwmblocks-style updater
- `configs/xinit/xinitrc`
  - starts status bar updater
  - sets wallpaper from `~/.local/share/wallpapers/`
  - launches `dwm`
- `configs/dwmblocks/dwmblocks.conf`
  - battery, CPU, memory, volume, and date/time blocks
- `scripts/dwmblocks.sh`
  - lightweight dwmblocks-compatible status loop using `xsetroot`
- `install.sh`
  - installs all required packages
  - clones/builds dwm source inside this repo (`src/dwm`)
  - applies config automatically
  - installs ThinkPad T480 power/input tweaks
  - installs wallpaper(s) and `~/.xinitrc`

## Installation

```bash
chmod +x install.sh
./install.sh
reboot
# login on tty
startx
```

## How to recompile dwm after config changes

After editing `configs/dwm/config.h`:

```bash
cp configs/dwm/config.h src/dwm/config.h
make -C src/dwm clean
make -C src/dwm
sudo make -C src/dwm install
```

Then restart X (`exit` from dwm and run `startx` again) or reboot.

## Keybinding cheat sheet

- `Super + Return` → open `kitty`
- `Super + p` → `dmenu_run`
- `Super + Shift + p` → `rofi -show drun` (falls back to dmenu)
- `Super + j / k` → focus next/previous window
- `Super + h / l` → shrink/grow master area
- `Super + t` → tile layout
- `Super + f` → floating layout
- `Super + m` → monocle layout
- `Super + Shift + f` → toggle floating for current window
- `Super + q` → close focused client
- `Super + Shift + q` → quit dwm
- `Super + 1..9` → switch workspace/tag
- `Super + Shift + 1..9` → send window to workspace/tag
- `Print` → full screenshot
- `Shift + Print` → area screenshot
- `XF86AudioRaise/Lower/Mute` → volume
- `XF86MonBrightnessUp/Down` → brightness

## ThinkPad T480 optimizations

`install.sh` configures:

- **TLP** enabled and started for laptop power management.
- X11 libinput tuning in `/etc/X11/xorg.conf.d/30-thinkpad-input.conf`:
  - touchpad tapping + natural scrolling + typing-disable
  - trackpoint acceleration/middle button behavior
- backlight udev permissions in `/etc/udev/rules.d/90-backlight.rules` so brightness keys work consistently.

## Troubleshooting

### Missing development headers / compile failures

Run the installer again to ensure required packages are present:

```bash
./install.sh
```

If build fails, inspect:

```bash
make -C src/dwm clean
make -C src/dwm
```

Common causes:
- incomplete `apt update`
- missing X11 development libraries
- local manual edits introducing invalid C syntax in `config.h`

### `startx` fails

- Ensure X packages are installed (`xorg`, `xinit`)
- Confirm `~/.xinitrc` exists and is executable
- Launch from a tty login shell (no display manager)

### Status bar is blank

- Verify `~/.local/bin/dwmblocks` exists and is executable
- Verify `~/.config/dwmblocks/dwmblocks.conf` exists
- Start manually for debugging:

```bash
~/.local/bin/dwmblocks
```

### Brightness keys do nothing

- Confirm user is in `video` group
- Reboot after udev rule changes
- Verify backlight path exists under `/sys/class/backlight/`
