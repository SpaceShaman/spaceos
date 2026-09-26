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
    swaymsg "output \"$output\" transform normal"
    ;;
  normal)
    swaymsg "output \"$output\" transform 270"
    ;;
esac
