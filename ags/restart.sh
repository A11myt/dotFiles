#!/usr/bin/env bash
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"

pkill -f "gjs.*ags.js" 2>/dev/null
sleep 0.8
exec ags run /home/jason/.config/ags/app.ts >> /home/jason/.logs/ags.log 2>&1
