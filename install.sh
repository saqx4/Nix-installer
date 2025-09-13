#!/usr/bin/env bash
set -euo pipefail

# ===========================================
# NixOS Desktop Setup Script
# - Works from TTY after "No Desktop" install
# - Lets you pick i3, dwm, or Hyprland
# - Installs dependencies automatically
# - Detects GPU automatically
# - Adds chosen display manager (GDM, SDDM, LightDM, Ly)
# - Backs up configuration.nix
# - Runs nixos-rebuild switch automatically
# ===========================================

CONFIG_PATH="/etc/nixos/configuration.nix"
BACKUP_PATH="/etc/nixos/configuration.nix.backup-$(date +%Y%m%d%H%M%S)"

echo "=== NixOS Desktop Setup ==="
echo "This will set up i3, dwm, or Hyprland with needed dependencies."
echo "Your current configuration.nix will be backed up."

# -------------------------------
# Step 1: Choose WM
# -------------------------------
PS3="Choose your window manager/compositor: "
options=("i3" "dwm" "hyprland")
select WM in "${options[@]}"; do
  case "$WM" in
    i3|dwm|hyprland) break ;;
    *) echo "Invalid choice." ;;
  esac
done
echo "-> Selected $WM"

# -------------------------------
# Step 2: Choose Display Manager
# -------------------------------
PS3="Choose your display manager (login screen) or none: "
dms=("gdm" "sddm" "lightdm" "ly" "none")
select DM in "${dms[@]}"; do
  case "$DM" in
    gdm|sddm|lightdm|ly|none) break ;;
    *) echo "Invalid choice." ;;
  esac
done
echo "-> Selected $DM"

# -------------------------------
# Step 3: Detect GPU vendor
# -------------------------------
GPU="none"
if lspci | grep -iq nvidia; then
  GPU="nvidia"
elif lspci | grep -iq intel; then
  GPU="intel"
elif lspci | grep -iq amd; then
  GPU="amd"
fi
echo "-> Detected GPU: $GPU"

# -------------------------------
# Step 4: Backup config
# -------------------------------
cp "$CONFIG_PATH" "$BACKUP_PATH"
echo "-> Backed up $CONFIG_PATH to $BACKUP_PATH"

# -------------------------------
# Step 5: Write config additions
# -------------------------------
{
  echo ""
  echo "### Added by nixos-desktop-setup.sh ###"

  # GPU setup
  case "$GPU" in
    nvidia)
      echo 'services.xserver.videoDrivers = [ "nvidia" ];'
      ;;
    intel|amd)
      echo 'hardware.opengl.enable = true;'
      ;;
  esac

  # Always enable X11 when needed
  echo 'services.xserver.enable = true;'

  # Display manager
  case "$DM" in
    gdm) echo 'services.xserver.displayManager.gdm.enable = true;' ;;
    sddm) echo 'services.xserver.displayManager.sddm.enable = true;' ;;
    lightdm) echo 'services.xserver.displayManager.lightdm.enable = true;' ;;
    ly)
      echo 'services.displayManager.ly.enable = true;'
      ;;
  esac

  # Enable NetworkManager
  echo 'networking.networkmanager.enable = true;'

  # WM/Compositor with dependencies
  case "$WM" in
    i3)
      echo 'services.xserver.windowManager.i3.enable = true;'
      echo 'environment.systemPackages = with pkgs; [ alacritty rofi firefox dmenu ];'
      ;;
    dwm)
      echo 'services.xserver.windowManager.dwm.enable = true;'
      echo 'environment.systemPackages = with pkgs; [ st dmenu slstatus firefox ];'
      ;;
    hyprland)
      echo 'programs.hyprland.enable = true;'
      echo 'environment.systemPackages = with pkgs; [ alacritty waybar rofi firefox xdg-desktop-portal-hyprland ];'
      ;;
  esac

  echo "### End nixos-desktop-setup.sh ###"
  echo ""
} >> "$CONFIG_PATH"

echo "-> Updated $CONFIG_PATH"

# -------------------------------
# Step 6: Rebuild system
# -------------------------------
echo "-> Running nixos-rebuild switch (this may take a while)..."
nixos-rebuild switch

echo "=== Done! ==="
echo "Reboot your system: sudo reboot"
echo "Then log in with $WM ($DM if you chose one)."
