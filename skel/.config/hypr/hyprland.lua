hl.on("hyprland.start", function()
	hl.exec_cmd("waybar")
end)

hl.bind("SUPER + RETURN", hl.dsp.exec_cmd("alacritty"))
