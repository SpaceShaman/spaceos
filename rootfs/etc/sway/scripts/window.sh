#!/bin/sh

action=${1:?expected focus or swap}
direction=${2:?expected prev or next}
case "$action:$direction" in
    focus:prev|focus:next|swap:prev|swap:next) ;;
    *) exit 2 ;;
esac

workspace=$(swaymsg -t get_outputs -r | jq -r \
    '.[] | select(.focused) | .current_workspace')
[ -n "$workspace" ] && [ "$workspace" != null ] || exit 0

[ "$direction" = next ] && step=1 || step=-1

pair=$(swaymsg -t get_tree -r | jq -r \
    --arg workspace "$workspace" --argjson step "$step" '
    [.. | objects |
     select(.type == "workspace" and .name == $workspace) |
     .nodes[]? | .. | objects |
     select(.app_id != null or .window != null)] as $windows |
    ($windows | map(.focused) | index(true)) as $current |
    if ($windows | length) < 2 or $current == null then empty
    else [$windows[$current].id,
          $windows[(($current + $step) % ($windows | length))].id] | @tsv
    end')

[ -n "$pair" ] || exit 0
IFS="$(printf '\t')" read -r current target <<EOF
$pair
EOF

if [ "$action" = focus ]; then
    exec swaymsg -q -- "[con_id=$target] focus"
else
    exec swaymsg -q -- "[con_id=$current] swap container with con_id $target"
fi
