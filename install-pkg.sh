#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$(id -u)" -eq 0 ]]; then
	printf 'Execute este script como usuário normal, sem sudo.\n' >&2
	exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
	printf 'Este instalador é destinado a Arch Linux e derivados (pacman).\n' >&2
	exit 1
fi

if ! command -v yay >/dev/null 2>&1; then
	for command in sudo git makepkg; do
		if ! command -v "$command" >/dev/null 2>&1; then
			printf 'Comando necessário para instalar yay-bin não encontrado: %s\n' "$command" >&2
			exit 1
		fi
	done

	sudo pacman -S --needed base-devel git
	build_dir="$(mktemp -d "${TMPDIR:-/tmp}/yay-bin.XXXXXX")"
	trap 'rm -rf -- "$build_dir"' EXIT
	git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$build_dir/yay-bin"
	(
		cd -- "$build_dir/yay-bin"
		makepkg --syncdeps --install --needed
	)
fi

packages=(
	awww
	bluez
	bluez-utils
	brightnessctl
	cava
	ddcutil
	elephant
	elephant-calc
	elephant-clipboard
	elephant-desktopapplications
	elephant-files
	elephant-runner
	elephant-websearch
	elephant-windows
	firefox
	foot
	fontconfig
	grim
	gsettings-desktop-schemas
	gtk3
	gtk4
	hyprland
	hyprsunset
	libqalculate
	lm_sensors
	networkmanager
	neovim
	nwg-look
	pipewire
	pipewire-pulse
	playerctl
	quickshell
	qt5ct
	qt6-imageformats
	qt6-multimedia
	qt6-svg
	qt6-wayland
	qt6ct
	rofi
	swappy
	thunar
	ttf-jetbrains-mono-nerd
	ttf-nerd-fonts-symbols-mono
	upower
	wireplumber
	xdg-desktop-portal-gtk
	xdg-desktop-portal-hyprland
	xorg-xwayland
)

yay -S --needed "${packages[@]}"

