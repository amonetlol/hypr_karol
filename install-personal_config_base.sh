#!/usr/bin/env bash
set -Eeuo pipefail

RAW_BASE="https://raw.githubusercontent.com/amonetlol/sh/main/modules"

if [[ "$(id -u)" -eq 0 ]]; then
	printf 'Execute este script como usuário normal, sem sudo.\n' >&2
	exit 1
fi

for command in bash curl; do
	if ! command -v "$command" >/dev/null 2>&1; then
		printf 'Comando necessário não encontrado: %s\n' "$command" >&2
		exit 1
	fi
done

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/personal-config-base.XXXXXX")"
trap 'rm -rf -- "$WORK_DIR"' EXIT

is_arch_based() {
	[[ -f /etc/arch-release ]] && return 0
	if [[ -r /etc/os-release ]]; then
		local ID="" ID_LIKE=""
		# shellcheck disable=SC1091
		. /etc/os-release
		case "${ID:-}:${ID_LIKE:-}" in
			arch*|*:arch*|cachyos*|manjaro*|endeavouros*|garuda*) return 0 ;;
		esac
	fi
	return 1
}

install_pacotes_arch() {
	if ! is_arch_based; then
		printf 'O módulo pacotes_arch requer Arch Linux ou derivada.\n' >&2
		return 1
	fi
	if ! command -v pacman >/dev/null 2>&1; then
		printf 'pacman não encontrado.\n' >&2
		return 1
	fi

	local helper=""
	if command -v yay >/dev/null 2>&1; then
		helper="yay"
	elif command -v paru >/dev/null 2>&1; then
		helper="paru"
	else
		for command in sudo git; do
			if ! command -v "$command" >/dev/null 2>&1; then
				printf 'Comando necessário para instalar yay-bin não encontrado: %s\n' "$command" >&2
				return 1
			fi
		done

		sudo pacman -S --needed base-devel git
		git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$WORK_DIR/yay-bin"
		(
			cd -- "$WORK_DIR/yay-bin"
			makepkg --syncdeps --install --needed --noconfirm
		)
		if ! command -v yay >/dev/null 2>&1; then
			printf 'yay-bin terminou, mas o comando yay não foi encontrado.\n' >&2
			return 1
		fi
		helper="yay"
	fi

	# Lista local e declarativa baseada em modules/pacotes_arch.sh.
	# blackbox-terminal e ulauncher foram excluídos conforme solicitado.
	local packages=(
		base-devel git wget curl unzip zip p7zip tar rsync nano vim neovim
		bash-completion procs less wl-clipboard xclip
		starship zoxide eza fd ripgrep fzf duf fastfetch btop htop tree tldr lazygit bat
		gcc make cmake pkgconf jq bc findutils coreutils intel-ucode snap-pac
		nodejs npm lua51 luarocks python python-pip python-pynvim python-pipenv
		tree-sitter-cli python-virtualenv prettier
		fontconfig noto-fonts noto-fonts-emoji inetutils mesa ttf-geist ttf-geist-mono
		otf-geist-mono-nerd ttf-0xproto-nerd ttf-terminus-nerd
		herdr-bin loupe papers xed
	)

	printf '\n==> pacotes_arch: instalando com %s --needed\n' "$helper"
	"$helper" -S --needed --noconfirm "${packages[@]}"
}

install_remote_module() {
	local module="$1"
	local url="$2"
	local script="$WORK_DIR/$module.sh"

	printf '\n==> %s: baixando %s\n' "$module" "$url"
	curl -fsSL "$url" -o "$script"
	bash "$script"
}

run_module() {
	local module="$1"
	case "$module" in
		pacotes_arch)
			install_pacotes_arch
			;;
		bash)
			install_remote_module "$module" "$RAW_BASE/bash.sh"
			;;
		bin)
			install_remote_module "$module" "$RAW_BASE/bin.sh"
			;;
		starship)
			install_remote_module "$module" "$RAW_BASE/starship.sh"
			;;
		fonts)
			install_remote_module "$module" "$RAW_BASE/fonts.sh"
			;;
		alacritty)
			install_remote_module "$module" "$RAW_BASE/alacritty.sh"
			;;
		kitty)
			install_remote_module "$module" "$RAW_BASE/kitty.sh"
			;;
		foot)
			install_remote_module "$module" "$RAW_BASE/foot.sh"
			;;
		btop)
			install_remote_module "$module" "$RAW_BASE/btop.sh"
			;;
		fastfetch)
			install_remote_module "$module" "$RAW_BASE/fastfetch.sh"
			;;
		setup-nvim)
			install_remote_module "$module" "$RAW_BASE/setup-nvim.sh"
			;;
		wallpapers)
			install_remote_module "$module" "$RAW_BASE/wallpapers.sh"
			;;
		hide-shortcuts)
			install_remote_module "$module" "$RAW_BASE/hide-shortcuts.sh"
			;;
		recovery-shortcuts)
			install_remote_module "$module" "$RAW_BASE/recovery-shortcuts.sh"
			;;
		snapper)
			install_remote_module "$module" "$RAW_BASE/Sistema/snapper.sh"
			;;
		sddm-catppuccin-Frappe-theme)
			install_remote_module "$module" "$RAW_BASE/Rice/sddm-catppuccin-Frappe-theme.sh"
			;;
		*)
			printf 'Módulo desconhecido: %s\n' "$module" >&2
			return 1
			;;
	esac
}

# Lista de execução: comente uma linha para pular aquele módulo.
MODULES=(
	pacotes_arch
	bash
	bin
	starship
	fonts
	alacritty
	kitty
	foot
	btop
	fastfetch
	setup-nvim
	wallpapers
	hide-shortcuts
	recovery-shortcuts
	snapper
	sddm-catppuccin-Frappe-theme
)

for module in "${MODULES[@]}"; do
	run_module "$module"
done

printf '\nConfig base pessoal instalada.\n'
