#!/bin/sh
set -eu

action=${1:?expected normalize, focus or move}
case "$action" in
    normalize) ;;
    focus|move) case "${2:-}" in prev|next) ;; *) exit 2 ;; esac ;;
    *) exit 2 ;;
esac

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/spaceos-workspaces.lock"
flock 9

workspaces() {
    swaymsg -t get_workspaces -r | jq -r --arg output "$1" \
        '[.[] | select(.output == $output and (.name | test("^[0-9]+:[0-9]+$")))] | sort_by(.num) | .[].name'
}

# The difference between the Sway number and the number after : identifies
# this output's workspace range (for example 1001:1 has base 1000).
base_of() {
    number=${1%%:*}
    index=${1#*:}
    case "$number$index" in *[!0-9]*|'') return 1 ;; esac
    [ "$number" -ge "$index" ] || return 1
    printf '%s\n' "$((number - index))"
}

normalize() {
    output=$1
    base=$2
    index=1
    names=$(workspaces "$output")
    [ -n "$names" ] || return 0
    while IFS= read -r old; do
        new="$((base + index)):$index"
        [ "$old" = "$new" ] || swaymsg -- "rename workspace $old to $new" >/dev/null
        index=$((index + 1))
    done <<EOF
$names
EOF
}

outputs=$(swaymsg -t get_outputs -r)
if [ "$action" = normalize ]; then
    printf '%s\n' "$outputs" | jq -r '.[] | [.name, .current_workspace] | @tsv' |
        while IFS="$(printf '\t')" read -r output current; do
            base=$(base_of "$current") || continue
            normalize "$output" "$base"
        done
    exit 0
fi

output=$(printf '%s\n' "$outputs" | jq -r '.[] | select(.focused) | .name')
current=$(printf '%s\n' "$outputs" | jq -r '.[] | select(.focused) | .current_workspace')
base=$(base_of "$current")
normalize "$output" "$base"
current=$(swaymsg -t get_outputs -r | jq -r '.[] | select(.focused) | .current_workspace')
index=${current#*:}

windows=$(swaymsg -t get_tree -r | jq -r --arg workspace "$current" \
    '[.. | objects | select(.type == "workspace" and .name == $workspace) | .. | objects | select(.app_id != null or .window != null)] | length')

if [ "$2" = prev ] && [ "$index" -eq 1 ]; then
    [ "$windows" -gt 0 ] || exit 0
    [ "$action" = focus ] || [ "$windows" -gt 1 ] || exit 0
    workspaces "$output" | sort -t: -k2,2nr | while IFS= read -r old; do
        number=${old#*:}
        swaymsg -- "rename workspace $old to $((base + number + 1)):$((number + 1))" >/dev/null
    done
    target="$((base + 1)):1"
else
    if [ "$2" = next ]; then index=$((index + 1)); else index=$((index - 1)); fi
    target="$((base + index)):$index"
    exists=$(swaymsg -t get_workspaces -r | jq -r --arg target "$target" \
        'any(.[]; .name == $target)')
    minimum=0
    [ "$action" = move ] && minimum=1
    [ "$windows" -gt "$minimum" ] || [ "$exists" = true ] || exit 0
fi

if [ "$action" = move ]; then
    swaymsg -- "move container to workspace $target; workspace $target" >/dev/null
else
    swaymsg -- "workspace $target" >/dev/null
fi
normalize "$output" "$base"
