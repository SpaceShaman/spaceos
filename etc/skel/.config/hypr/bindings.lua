local mod = 'SUPER'

-- Applications and basic window actions.
hl.bind(mod .. ' + RETURN', hl.dsp.exec_cmd 'alacritty')
hl.bind(mod .. ' + Q', hl.dsp.window.close())
hl.bind(mod .. ' + CONTROL + SPACE', hl.dsp.window.float { action = 'toggle' })
hl.bind(mod .. ' + TAB', hl.dsp.focus { last = true })
hl.bind(mod .. ' + ESCAPE', hl.dsp.exec_cmd 'pkill -SIGUSR1 waybar')

-- Change workspace, or move the active window and follow it.
hl.bind(mod .. ' + S', hl.dsp.focus { workspace = 'r-1' })
hl.bind(mod .. ' + D', hl.dsp.focus { workspace = 'r+1' })
hl.bind(mod .. ' + SHIFT + S', hl.dsp.window.move { workspace = 'r-1', follow = true })
hl.bind(mod .. ' + SHIFT + D', hl.dsp.window.move { workspace = 'r+1', follow = true })

-- Navigate windows spatially, using the directional layout from AwesomeWM.
local directions = {
  J = 'l',
  semicolon = 'r',
  L = 'u',
  K = 'd',
}

for key, direction in pairs(directions) do
  hl.bind(mod .. ' + ' .. key, hl.dsp.focus { direction = direction })
  hl.bind(mod .. ' + SHIFT + ' .. key, hl.dsp.window.move { direction = direction })

  hl.bind(mod .. ' + CONTROL + ' .. key, hl.dsp.focus { monitor = direction })
  hl.bind(mod .. ' + CONTROL + SHIFT + ' .. key, hl.dsp.window.move { monitor = direction, follow = true })
end

-- Workspaces 1-9.
for workspace = 1, 9 do
  hl.bind(mod .. ' + ' .. workspace, hl.dsp.focus { workspace = workspace })
  hl.bind(mod .. ' + SHIFT + ' .. workspace, hl.dsp.window.move { workspace = workspace })
end

-- Move and resize floating windows with the mouse.
hl.bind(mod .. ' + mouse:272', hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. ' + mouse:273', hl.dsp.window.resize(), { mouse = true })
