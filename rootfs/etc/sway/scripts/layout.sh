#!/bin/sh
apply_layout() {
    info=$(swaymsg -t get_outputs -r | jq -r \
        '.[] | select(.focused) | [.current_workspace, .rect.width, .rect.height] | @tsv')
    [ -n "$info" ] || return
    IFS="$(printf '\t')" read -r workspace width height <<EOF
$info
EOF

    windows=$(swaymsg -t get_tree -r | jq -r --arg workspace "$workspace" '
        [.. | objects |
         select(.type == "workspace" and .name == $workspace) |
         .nodes[]? | .. | objects |
         select(.app_id != null or .window != null)] | length')

    case "$((height > width)):$((windows > 1))" in
        1:0|0:1)
            direction=vertical
            ;;
        *)
            direction=horizontal
            ;;
    esac

    swaymsg -q split "$direction"
}

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/spaceos-layout.lock"
flock -n 9 || exit 0

apply_layout
swaymsg -m -t subscribe '["window"]' |
    jq -c --unbuffered 'select(.change == "new" or .change == "close")' |
while IFS= read -r _; do
    sleep 0.05
    apply_layout
done
