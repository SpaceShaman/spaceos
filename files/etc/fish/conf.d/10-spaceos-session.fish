if status is-login
    and test (tty) = /dev/tty1
    and not set -q WAYLAND_DISPLAY

    exec /usr/bin/sway --config /etc/sway/config
end
