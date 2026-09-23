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

    if [ "$height" -gt "$width" ]; then
        base=vertical
        other=horizontal
    else
        base=horizontal
        other=vertical
    fi

    if [ "$windows" -le 1 ] || [ "$((windows % 2))" -eq 1 ]; then
        direction=$base
    else
        direction=$other
    fi

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
