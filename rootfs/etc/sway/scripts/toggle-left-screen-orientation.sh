#!/usr/bin/env bash
set -euo pipefail

output='DVI-I-2'
transform="$(
  swaymsg -t get_outputs -r |
    jq -r --arg output "$output" \
      '.[] | select(.name == $output) | .transform'
)"

case "$transform" in
  270)
    swaymsg "output \"$output\" pos -1120 0 transform normal mode 2560x1440@119.998Hz"
    ;;
  normal)
    swaymsg "output '$output' pos 0 0 transform 270 mode 2560x1440@119.998Hz"
    ;;
esac
