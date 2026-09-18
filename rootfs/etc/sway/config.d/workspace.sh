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

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/spaceos-workspaces.lock"
flock 9
outputs=$(swaymsg -t get_outputs -r)

base_for_output() {
    printf '%s\n' "$outputs" | jq -r --arg output "$1" 'map(.name) | index($output) * 1000'
}

names_for_output() {
    swaymsg -t get_workspaces -r | jq -r --arg output "$1" \
        '[.[] | select(.output == $output and (.name | test("^[0-9]+:[0-9]+$")))] | sort_by(.num, .name) | .[].name'
}

normalize() {
    printf '%s\n' "$outputs" | jq -r '.[].name' | while IFS= read -r output; do
        base=$(base_for_output "$output")
        index=1
        names=$(names_for_output "$output")
        [ -n "$names" ] || continue
        while IFS= read -r old; do
            new="$((base + index)):$index"
            [ "$old" = "$new" ] || swaymsg -- "rename workspace $old to $new" >/dev/null
            index=$((index + 1))
        done <<EOF
$names
EOF
    done
}

shift_up() {
    output=$1
    base=$2
    names=$(names_for_output "$output")
    printf '%s\n' "$names" | sort -t: -k2,2nr | while IFS= read -r old; do
        [ -n "$old" ] || continue
        number=${old#*:}
        new="$((base + number + 1)):$((number + 1))"
        swaymsg -- "rename workspace $old to $new" >/dev/null
    done
}

normalize
[ "$action" = normalize ] && exit 0

output=$(printf '%s\n' "$outputs" | jq -r '.[] | select(.focused == true) | .name')
current=$(printf '%s\n' "$outputs" | jq -r '.[] | select(.focused == true) | .current_workspace')
base=$(base_for_output "$output")
local_number=${current#*:}
case "$local_number" in *[!0-9]*|'') exit 1 ;; esac
[ "$current" = "$((base + local_number)):$local_number" ] || exit 1

windows=$(swaymsg -t get_tree -r | jq -r --arg workspace "$current" \
    '[.. | objects | select(.type == "workspace" and .name == $workspace) | .. | objects | select(.app_id != null or .window != null)] | length')

if [ "$direction" = prev ] && [ "$local_number" -eq 1 ]; then
    # Do not create an empty workspace from an empty current one. Moving the
    # last window to a new workspace is also blocked, like the forward case.
    [ "$windows" -gt 0 ] || exit 0
    if [ "$action" = move ] && [ "$windows" -le 1 ]; then
        exit 0
    fi
    shift_up "$output" "$base"
    target="$((base + 1)):1"
    if [ "$action" = move ]; then
        swaymsg -- "move container to workspace $target; workspace $target" >/dev/null
    else
        swaymsg -- "workspace $target" >/dev/null
    fi
    exit 0
fi

if [ "$direction" = next ]; then
    local_number=$((local_number + 1))
else
    local_number=$((local_number - 1))
fi
target="$((base + local_number)):$local_number"
target_exists=$(swaymsg -t get_workspaces -r | jq -r --arg target "$target" --arg output "$output" \
    'any(.[]; .name == $target and .output == $output)')

if [ "$action" = move ]; then
    [ "$windows" -gt 1 ] || [ "$target_exists" = true ] || exit 0
    swaymsg -- "move container to workspace $target; workspace $target" >/dev/null
else
    [ "$windows" -gt 0 ] || [ "$target_exists" = true ] || exit 0
    swaymsg -- "workspace $target" >/dev/null
fi
