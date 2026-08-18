#!/usr/bin/env bash
# Найти корень WoW 3.3.5a на Bazzite (Lutris / Steam Proton / Bottles).
set -euo pipefail

roots=(
  "$HOME"
  "$HOME/.local/share/lutris"
  "$HOME/.local/share/Steam"
  "$HOME/.steam/steam"
  "$HOME/.var/app"
  "$HOME/.local/share/bottles"
  "$HOME/Games"
  "$HOME/.wine"
)

declare -A seen=()
matches=()

for root in "${roots[@]}"; do
  [[ -d "$root" ]] || continue
  while IFS= read -r f; do
    dir="$(dirname "$f")"
    [[ -d "$dir/Data" ]] || continue
    [[ -z "${seen[$dir]:-}" ]] || continue
    seen[$dir]=1
    matches+=("$dir")
  done < <(find "$root" -xdev -iname 'Wow.exe' 2>/dev/null | head -n 30)
done

if [[ ${#matches[@]} -eq 0 ]]; then
  echo "Wow.exe не найден. Укажите путь: desktop/push-client-to-vm.sh --wow-dir /path --server user@vm" >&2
  exit 1
fi

printf 'Найденные клиенты:\n'
printf '  %s\n' "${matches[@]}"
echo
echo "Пример:"
echo "  desktop/push-client-to-vm.sh --wow-dir '${matches[0]}' --server user@VM_IP"
