#!/usr/bin/env bash

# Creates symlinks from ~ and ~/bin into this bash_scripts repo.
# Run from any location — the script resolves its own repo path.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p ~/bin

# Home directory symlinks
declare -A HOME_LINKS=(
  [.bash_aliases]="RCs/dot.bash_aliases"
  [.vimrc]="RCs/dot.vimrc"
  [user-interface]="user-interface/"
)

# ~/bin symlinks
declare -A BIN_LINKS=(
  [check-cert.sh]="misc/check-cert.sh"
  [extract_image_layers.sh]="cloud/extract_image_layers.sh"
  [flac2mp3.sh]="media/flac2mp3.sh"
  [get-x-resource-users.sh]="sys/get-x-resource-users.sh"
  [hdd-keyboard-led.sh]="user-interface/hdd-keyboard-led.sh"
  [lg-monitor-control.sh]="display/lg-monitor-control.sh"
  [solve.sh]="calc/solve.sh"
  [taglist_docker.sh]="cloud/taglist_docker.sh"
  [usb_reset.sh]="sys/usb_reset.sh"
  [wait-for-it.sh]="network/wait-for-it.sh"
  [ytdl-wrapper.sh]="media/ytdl-wrapper.sh"
)

link_file() {
  local link_path="$1"
  local target="$2"

  if [ -L "$link_path" ]; then
    echo "  EXISTS (symlink): $link_path"
  elif [ -e "$link_path" ]; then
    echo "  SKIPPED (real file exists): $link_path"
  else
    ln -s "$target" "$link_path"
    echo "  CREATED: $link_path -> $target"
  fi
}

echo "Setting up home directory symlinks..."
for name in "${!HOME_LINKS[@]}"; do
  link_file "$HOME/$name" "$SCRIPT_DIR/${HOME_LINKS[$name]}"
done

echo "Setting up ~/bin symlinks..."
for name in "${!BIN_LINKS[@]}"; do
  link_file "$HOME/bin/$name" "$SCRIPT_DIR/${BIN_LINKS[$name]}"
done

echo "Done."
