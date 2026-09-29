#!/usr/bin/bash
set -euo pipefail

# One instance per Sway session. Helpers do not inherit this lock.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/spaceos-layout-$UID-${SWAYSOCK##*/}.lock"
flock -n 9 || exit 0

# Keep both the parser and its previous snapshot alive between events.
coproc PLANNER { exec jq -nr --unbuffered --arg mark "_spaceos_layout_$$" '
    def snapshot:
        [.. | objects | select(.type == "workspace" and .name != "__i3_scratch") |
         {id, portrait: (.rect.height > .rect.width), windows:
          [.nodes[]? | .. | objects |
           select(.app_id != null or .window != null or .pid != null) | {id, focused}]}];
    def arrange($previous):
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
         ) | .commands[]] | join("; ");

    foreach inputs as $tree ({previous: null};
        ($tree | snapshot) as $current |
        .commands = (if .previous == null then ""
                     else .previous as $old | $current | arrange($old) end) |
        .previous = $current;
        .commands)
' 9>&-; }
planner=$PLANNER_PID
exec {planner_in}>&"${PLANNER[1]}" {planner_out}<&"${PLANNER[0]}"
subscriber=
trap 'kill "$planner" ${subscriber:+"$subscriber"} 2>/dev/null || :; wait "$planner" ${subscriber:+"$subscriber"} 2>/dev/null || :' EXIT
trap 'exit 0' TERM INT

update() {
    swaymsg -t get_tree -r >&"$planner_in"
    IFS= read -r commands <&"$planner_out"
    if [[ -n "$commands" ]]; then
        swaymsg -q -- "$commands" || printf 'layout: failed to place an arriving window\n' >&2
    fi
}

update
exec {events}< <(exec swaymsg -m -r -t subscribe '["window"]' 9>&-)
subscriber=$!
# Filtering notifications in Bash avoids starting jq for focus, title and mark events.
relevant='"change"[[:space:]]*:[[:space:]]*"(new|move|close|floating)"|"success"[[:space:]]*:[[:space:]]*true'
while IFS= read -r event <&"$events"; do
    [[ $event =~ $relevant ]] || continue
    update
done
