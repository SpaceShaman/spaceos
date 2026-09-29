#!/bin/sh
apply_layout() {
    workspace=$(swaymsg -t get_workspaces -r | jq -r '
        .[] | select(.focused) |
        [.name, (.rect.height > .rect.width)] | @tsv')
    [ -n "$workspace" ] || return

    IFS="$(printf '\t')" read -r name portrait <<EOF
$workspace
EOF

    layout=$(swaymsg -t get_tree -r | jq -r --arg name "$name" --argjson portrait "$portrait" '
        .. | objects | select(.type == "workspace" and .name == $name) |
        ([.nodes[]? | .. | objects | select(.app_id != null or .window != null)] | length) as $count |
        (first(paths(.focused == true) | select(.[0] == "nodes")) // null) as $path |
        ([.floating_nodes[]? | .. | objects | select(.focused == true)] | length > 0) as $floating_focus |
        if $path == null and ($count > 0 or $floating_focus) then empty else
            ($count > 1 and ($count % 2) == 0) as $even |
            (if $portrait != $even then "vertical" else "horizontal" end) as $direction |
            (if $path == null then . else getpath($path[0:-2]) end) as $parent |
            select($parent.layout != (if $direction == "vertical" then "splitv" else "splith" end)) |
            [$direction, (if $path == null then "" else getpath($path).id end)] | @tsv
        end')
    [ -n "$layout" ] || return

    IFS="$(printf '\t')" read -r direction id <<EOF
$layout
EOF
    if [ -n "$id" ]; then
        swaymsg -q -- "[con_id=$id] split $direction"
    else
        swaymsg -q split "$direction"
    fi
}

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/spaceos-layout.lock"
flock -n 9 || exit 0

apply_layout
swaymsg -m -t subscribe '["window", "workspace", "output"]' |
    jq -r --unbuffered '
        select(.change == "new" or .change == "close" or .change == "move" or
               .change == "focus" or .change == "floating" or
               .change == "unspecified") | .change' |
    while IFS= read -r _; do
        apply_layout
    done
