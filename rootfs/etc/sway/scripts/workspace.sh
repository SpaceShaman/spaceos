#!/bin/sh
set -eu

action=${1:?expected normalize, focus or move}
case "$action" in
    normalize) direction= ;;
    focus|move) direction=${2:?expected prev or next} ;;
    *) exit 2 ;;
esac
[ "$action" = normalize ] || case "$direction" in prev|next) ;; *) exit 2 ;; esac

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

shift_workspaces_up() {
    names_for_output "$1" | sort -t: -k2,2nr | while IFS= read -r old; do
        [ -n "$old" ] || continue
        number=${old#*:}
        new="$(( $2 + number + 1 )):$((number + 1))"
        swaymsg -- "rename workspace $old to $new" >/dev/null
    done
}

switch_to() {
    if [ "$action" = move ]; then
        swaymsg -- "move container to workspace $1; workspace $1" >/dev/null
    else
        swaymsg -- "workspace $1" >/dev/null
    fi
    normalize
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
    shift_workspaces_up "$output" "$base"
    switch_to "$((base + 1)):1"
    exit 0
fi

case "$direction" in
    next) local_number=$((local_number + 1)) ;;
    prev) local_number=$((local_number - 1)) ;;
esac
target="$((base + local_number)):$local_number"
target_exists=$(swaymsg -t get_workspaces -r | jq -r --arg target "$target" --arg output "$output" \
    'any(.[]; .name == $target and .output == $output)')

minimum_windows=0
[ "$action" = move ] && minimum_windows=1
[ "$windows" -gt "$minimum_windows" ] || [ "$target_exists" = true ] || exit 0
switch_to "$target"
