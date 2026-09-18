#!/bin/sh
set -eu

action=${1:?expected normalize, focus or move}
case "$action" in
    normalize) ;;
    focus|move)
        direction=${2:?expected prev or next}
        case "$direction" in prev|next) ;; *) exit 2 ;; esac
        ;;
    *) exit 2 ;;
esac

# Waybar runs normalize on each workspace update, possibly once per monitor.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/spaceos-workspaces.lock"
flock 9

normalize() {
    workspaces=$(swaymsg -t get_workspaces -r)
    for output in DVI-I-2 DVI-I-1 eDP-1; do
        case "$output" in
            DVI-I-2) base=0 ;;
            DVI-I-1) base=10 ;;
            eDP-1) base=20 ;;
        esac
        index=1
        names=$(printf '%s\n' "$workspaces" | jq -r --arg output "$output" \
            '[.[] | select(.output == $output and (.name | test("^[0-9]+(:[0-9]+)?$")))] | sort_by(.num, .name) | .[].name')
        [ -n "$names" ] || continue
        while IFS= read -r old; do
            new="$((base + index)):$index"
            if [ "$old" != "$new" ]; then
                swaymsg -- "rename workspace $old to $new" >/dev/null
            fi
            index=$((index + 1))
        done <<EOF
$names
EOF
    done
}

normalize
[ "$action" = normalize ] && exit 0

outputs=$(swaymsg -t get_outputs -r)
output=$(printf '%s\n' "$outputs" | jq -r '.[] | select(.focused == true) | .name')
current=$(printf '%s\n' "$outputs" | jq -r '.[] | select(.focused == true) | .current_workspace')

case "$output" in
    DVI-I-2) base=0 ;;
    DVI-I-1) base=10 ;;
    eDP-1) base=20 ;;
    *) exit 1 ;;
esac

local_number=${current#*:}
case "$local_number" in
    1|2|3|4|5|6|7|8|9|10) ;;
    *) exit 1 ;;
esac
[ "$current" = "$((base + local_number)):$local_number" ] || exit 1

if [ "$direction" = next ]; then
    [ "$local_number" -lt 10 ] || exit 0
    local_number=$((local_number + 1))
else
    [ "$local_number" -gt 1 ] || exit 0
    local_number=$((local_number - 1))
fi
target="$((base + local_number)):$local_number"

windows=$(swaymsg -t get_tree -r | jq -r --arg workspace "$current" \
    '[.. | objects | select(.type == "workspace" and .name == $workspace) | .. | objects | select(.app_id != null or .window != null)] | length')
if swaymsg -t get_workspaces -r | jq -e --arg target "$target" \
    --arg output "$output" 'any(.[]; .name == $target and .output == $output)' >/dev/null; then
    target_exists=1
else
    target_exists=0
fi

if [ "$action" = move ]; then
    # The last window may leave its workspace when the destination already exists.
    if [ "$windows" -le 1 ] && [ "$target_exists" -eq 0 ]; then
        exit 0
    fi
    swaymsg -- "move container to workspace $target; workspace $target; move workspace to output $output" >/dev/null
else
    # Returning to an existing workspace is allowed from an empty one.
    if [ "$windows" -eq 0 ] && [ "$target_exists" -eq 0 ]; then
        exit 0
    fi
    swaymsg -- "workspace $target; move workspace to output $output" >/dev/null
fi
