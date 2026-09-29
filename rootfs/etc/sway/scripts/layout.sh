#!/bin/sh
apply_layout() {
    id=${1:-}
    if [ -n "$id" ]; then
        info=$(swaymsg -t get_tree -r | jq -r --argjson id "$id" '
            .. | objects | select(.type == "workspace") |
            select([.nodes[]? | .. | objects | .id] | index($id)) |
            [.name, .rect.width, .rect.height] | @tsv')
    else
        info=$(swaymsg -t get_outputs -r | jq -r \
            '.[] | select(.focused) | [.current_workspace, .rect.width, .rect.height] | @tsv')
    fi
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

    if [ -n "$id" ]; then
        swaymsg -q -- "[con_id=$id] split $direction"
    else
        swaymsg -q split "$direction"
    fi
}

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/spaceos-layout.lock"
flock -n 9 || exit 0

apply_layout
swaymsg -m -t subscribe '["window", "workspace"]' |
  jq -r --unbuffered '
      if .container? then
          select(.change == "new" or .change == "close" or .change == "move") |
          [.change, .container.id] | @tsv
      else
          select(.change == "focus") | "focus"
      end' |
while IFS="$(printf '\t')" read -r change id; do
    sleep 0.05
    if [ "$change" = new ] || [ "$change" = move ]; then
        apply_layout "$id"
    else
        apply_layout
    fi
done
