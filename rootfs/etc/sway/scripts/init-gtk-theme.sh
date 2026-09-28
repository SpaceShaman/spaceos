#!/bin/sh

set -eu

case "$(readlink /etc/alacritty/themes/current.toml || :)" in
    light.toml) gtk_theme=Ayu-Light ;;
    *) gtk_theme=Ayu-Dark ;;
esac

GTK_THEME=$gtk_theme dbus-update-activation-environment --systemd GTK_THEME
