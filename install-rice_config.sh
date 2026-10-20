#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
archive="$repo_dir/Assets/rice-configs.tar.gz"

if [[ ! -r "$archive" ]]; then
	printf 'Arquivo do rice não encontrado: %s\n' "$archive" >&2
	exit 1
fi

if [[ "$(id -u)" -eq 0 ]]; then
	printf 'Execute este script como usuário normal, sem sudo.\n' >&2
	exit 1
fi

for command in tar find readlink systemctl sudo; do
	if ! command -v "$command" >/dev/null 2>&1; then
		printf 'Comando necessário não encontrado: %s\n' "$command" >&2
		exit 1
	fi
done

stage="$(mktemp -d "${TMPDIR:-/tmp}/hypr_karol.XXXXXX")"
trap 'rm -rf -- "$stage"' EXIT

if ! tar -tzf "$archive" > "$stage/archive.list"; then
	printf 'Não foi possível ler o arquivo: %s\n' "$archive" >&2
	exit 1
fi

while IFS= read -r member || [[ -n "$member" ]]; do
	if [[ "$member" == /* || "/$member/" == *"/../"* ]]; then
		printf 'Caminho inseguro no arquivo: %s\n' "$member" >&2
		exit 1
	fi
done < "$stage/archive.list"

tar --extract --gzip --file "$archive" --directory "$stage" --no-same-owner

# O archive veio de /home/rice; adapte os links GTK para a home atual.
while IFS= read -r -d '' link; do
	target="$(readlink -- "$link")"
	case "$target" in
		/home/rice/*)
			relative_target="${target#/home/rice/}"
			ln -sfn -- "$HOME/$relative_target" "$link"
			;;
	esac
done < <(find "$stage" -type l -print0)

install_paths=(
	.config/elephant
	.config/foot
	.config/gtk-3.0
	.config/gtk-4.0
	.config/hypr
	.config/nwg-look
	.config/qt5ct
	.config/qt6ct
	.config/quickshell/karol
	.config/systemd/user/elephant.service
	.config/systemd/user/quickshell-icon-theme.service
	.gtkrc-2.0
	.icons/default
	.local/share/fonts
	.local/share/icons/Bibata-Modern-Ice
	.local/share/icons/MacTahoe-dark
	.themes/WhiteSur-Dark-solid
)

for relative_path in "${install_paths[@]}"; do
	if [[ ! -e "$stage/$relative_path" && ! -L "$stage/$relative_path" ]]; then
		printf 'O arquivo esperado não está no archive: %s\n' "$relative_path" >&2
		exit 1
	fi
done

backup_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hypr_karol/backups/$(date +%Y%m%d-%H%M%S)-$$"
backup_created=false

for relative_path in "${install_paths[@]}"; do
	source_path="$HOME/$relative_path"
	if [[ -e "$source_path" || -L "$source_path" ]]; then
		backup_path="$backup_dir/$relative_path"
		mkdir -p -- "$(dirname -- "$backup_path")"
		mv -- "$source_path" "$backup_path"
		backup_created=true
	fi
done

for relative_path in "${install_paths[@]}"; do
	destination="$HOME/$relative_path"
	mkdir -p -- "$(dirname -- "$destination")"
	mv -- "$stage/$relative_path" "$destination"
done

if command -v fc-cache >/dev/null 2>&1; then
	fc-cache -f "$HOME/.local/share/fonts"
fi

systemctl --user daemon-reload
systemctl --user enable elephant.service
systemctl --user try-restart elephant.service
systemctl --user start elephant.service
systemctl --user try-restart quickshell-icon-theme.service
systemctl --user start quickshell-icon-theme.service
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service
sudo systemctl enable --now NetworkManager.service bluetooth.service

if [[ "$backup_created" == true ]]; then
	printf 'Backup das configurações anteriores: %s\n' "$backup_dir"
else
	printf 'Nenhuma configuração anterior do rice foi encontrada para backup.\n'
fi
printf 'Rice instalado em %s. O Quickshell será iniciado pelo Hyprland na próxima sessão.\n' "$HOME"

