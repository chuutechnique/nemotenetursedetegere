#!/bin/sh
export GTK_THEME=Adwaita:dark
[ ! -r "$HOME/.Xresources" ] || xrdb -merge "$HOME/.Xresources"
exec dbus-run-session -- openbox-session
