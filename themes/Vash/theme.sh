#!/bin/bash


# Modify Hyprland borders directly (optional live reload if you want)
sed -i -E 's/(active_border = \{ colors = \{ )"[^"]+", "[^"]+"/\1"rgba(ff3213bd)", "rgba(ff3838d9)"/' ~/.config/hypr/hyprland.lua
# Restart Hyprland to apply border changes if needed (optional):
hyprctl reload

# Replace Waybar style.css with themed version
cp ~/.local/share/themes/Vash/style.css ~/.config/waybar/style.css

# Reload Waybar
pkill waybar
waybar &
