#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== 1. Aggiornamento sistema e strumenti base ==="
sudo pacman -Syu --needed --noconfirm base-devel git stow

echo "=== 2. Rilevamento CPU & Microcode ==="
if grep -qi "intel" /proc/cpuinfo; then
    sudo pacman -S --needed --noconfirm intel-ucode
elif grep -qi "amd" /proc/cpuinfo; then
    sudo pacman -S --needed --noconfirm amd-ucode
fi

echo "=== 3. Rilevamento e configurazione GPU ==="
if lspci | grep -qi "nvidia"; then
    echo "Rilevata GPU NVIDIA..."
    sudo pacman -S --needed --noconfirm nvidia-dkms nvidia-utils lib32-nvidia-utils egl-wayland
elif lspci | grep -qi "amd"; then
    echo "Rilevata GPU AMD..."
    sudo pacman -S --needed --noconfirm mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon
elif lspci | grep -qi "intel"; then
    echo "Rilevata GPU Intel..."
    sudo pacman -S --needed --noconfirm mesa lib32-mesa vulkan-intel lib32-vulkan-intel intel-media-driver
fi

echo "=== 4. Installazione AUR Helper (Paru) se assente ==="
if ! command -v paru &>/dev/null; then
    git clone https://aur.archlinux.org/paru-bin.git /tmp/paru-bin
    (cd /tmp/paru-bin && makepkg -si --noconfirm)
    rm -rf /tmp/paru-bin
fi

echo "=== 5. Installazione Pacchetti Ufficiali ==="
if [ -f "$SCRIPT_DIR/native-pkgs.txt" ]; then
    sudo pacman -S --needed --noconfirm - < "$SCRIPT_DIR/native-pkgs.txt" || echo "Alcuni pacchetti ufficiali potrebbero essere stati saltati."
fi

echo "=== 6. Installazione Pacchetti AUR ==="
if [ -f "$SCRIPT_DIR/aur-pkgs.txt" ]; then
    paru -S --needed --noconfirm - < "$SCRIPT_DIR/aur-pkgs.txt" || echo "Alcuni pacchetti AUR potrebbero essere stati saltati."
fi

echo "=== 7. Deploy Dotfiles con GNU Stow ==="
cd "$SCRIPT_DIR/dotfiles"
for app in */; do
    app_name="${app%/}"
    echo "Applicando configurazione per: $app_name"
    stow -R -t "$HOME" "$app_name"
done

echo "=== 8. Abilitazione Servizi Systemd di Sistema ==="
if [ -f "$SCRIPT_DIR/system-services.txt" ]; then
    while read -r svc; do
        if [ -n "$svc" ] && systemctl list-unit-files "$svc" &>/dev/null; then
            sudo systemctl enable "$svc" || true
        fi
    done < "$SCRIPT_DIR/system-services.txt"
fi

echo "=== 9. Abilitazione Servizi Systemd Utente ==="
if [ -f "$SCRIPT_DIR/user-services.txt" ]; then
    while read -r usvc; do
        if [ -n "$usvc" ] && systemctl --user list-unit-files "$usvc" &>/dev/null; then
            systemctl --user enable "$usvc" || true
        fi
    done < "$SCRIPT_DIR/user-services.txt"
fi

echo ""
echo "=== Installazione e configurazione completate con successo! Riavvia la macchina. ==="
