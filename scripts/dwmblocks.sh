#!/bin/sh
set -eu

conf_file="${1:-$HOME/.config/dwmblocks/dwmblocks.conf}"
[ -f "$conf_file" ] || exit 1

run_once() {
  out=""
  while IFS='|' read -r icon cmd interval; do
    [ -n "${icon:-}" ] || continue
    case "$icon" in \#*) continue;; esac
    val=$(sh -c "$cmd" 2>/dev/null || printf 'n/a')
    block="$icon $val"
    if [ -z "$out" ]; then
      out="$block"
    else
      out="$out | $block"
    fi
  done < "$conf_file"
  xsetroot -name "$out"
}

while :; do
  run_once
  sleep 2
done
