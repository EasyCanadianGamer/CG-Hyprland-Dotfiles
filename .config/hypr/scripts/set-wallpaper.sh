#!/usr/bin/env bash
# Restore last used wallpaper on login
CACHE=~/.cache/current-wallpaper
[ -f "$CACHE" ] && wall=$(cat "$CACHE") || wall="$HOME/.local/share/themes/Arch/wallpaper.png"
awww img "$wall" --transition-type any --transition-fps 60 --transition-duration 1
