#!/usr/bin/bash
set -euo pipefail

# One instance per Sway session. The subscription does not inherit this lock.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/spaceos-layout-$UID-${SWAYSOCK##*/}.lock"
flock -n 9 || exit 0

snapshot() {
    swaymsg -t get_tree -r | jq -c '
        [.. | objects | select(.type == "workspace" and .name != "__i3_scratch") |
         {id, portrait: (.rect.height > .rect.width), windows:
          [.nodes[]? | .. | objects |
           select(.app_id != null or .window != null or .pid != null) | {id, focused}]}]'
}

previous=$(snapshot)
exec {events}< <(exec swaymsg -m -r -t subscribe '["window"]' 9>&-)
subscriber=$!
trap 'kill "$subscriber" 2>/dev/null || :; wait "$subscriber" 2>/dev/null || :' EXIT
trap 'exit 0' TERM INT

while IFS= read -r event <&"$events"; do
    jq -e '.success == true or
           (.change == "new" or .change == "move" or
            .change == "close" or .change == "floating")' <<<"$event" >/dev/null || continue

    current=$(snapshot)
    commands=$(jq -r --argjson previous "$previous" --arg mark "_spaceos_layout_$$" '
        ($previous | map(. as $ws | .windows[] |
            {key: (.id | tostring), value: $ws.id}) | from_entries) as $known |
        [.[] | . as $ws |
         (.windows | map(select($known[.id | tostring] == $ws.id))) as $old |
         (.windows | map(select($known[.id | tostring] != $ws.id)) | sort_by(.id)) as $new |
         reduce $new[] as $window (
             {last: $old[-1].id, count: ($old | length), commands: []};
             if .last != null then
                 (if $ws.portrait == (.count % 2 == 1)
                  then "vertical" else "horizontal" end) as $direction |
                 ($mark + "_" + ($window.id | tostring)) as $target |
                 .commands += [
                     "[con_id=\(.last)] split \($direction)",
                     "[con_id=\(.last)] mark --add \($target)",
                     "[con_id=\($window.id)] move container to mark \($target)",
                     "[con_id=\(.last)] unmark \($target)"] |
                 if $window.focused then
                     .commands += ["[con_id=\($window.id)] focus"]
                 else . end
             else . end |
             .last = $window.id | .count += 1
         ) | .commands[]] | join("; ")' <<<"$current")

    # Membership, not move events, distinguishes arrivals from our own commands.
    # Keep this snapshot so windows arriving during the commands are handled next.
    previous=$current
    if [[ -n "$commands" ]]; then
        swaymsg -q -- "$commands" || printf 'layout: failed to place an arriving window\n' >&2
    fi
done
