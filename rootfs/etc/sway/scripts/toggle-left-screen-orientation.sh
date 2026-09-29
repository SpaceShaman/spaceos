#!/usr/bin/env bash
set -euo pipefail

output='DVI-I-2'
outputs="$(swaymsg -t get_outputs -r)"
transform="$(jq -r --arg output "$output" '.[] | select(.name == $output) | .transform' <<< "$outputs")"

case "$transform" in
  270) offset=1120; next=normal ;;
  normal) offset=-1120; next=270 ;;
  *) printf 'Unknown transform for %s: %s\n' "$output" "$transform" >&2; exit 1 ;;
esac

jq -r --arg output "$output" --argjson offset "$offset" \
  '.[] | select(.active and .name != $output) | "output \"\(.name)\" pos \(.rect.x + $offset) \(.rect.y)"' \
  <<< "$outputs" |
while IFS= read -r command; do swaymsg "$command"; done

swaymsg "output \"$output\" pos 0 0 transform $next mode 2560x1440@119.998Hz"
