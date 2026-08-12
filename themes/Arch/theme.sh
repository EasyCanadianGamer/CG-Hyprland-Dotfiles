#!/bin/bash


# Modify Hyprland borders directly (optional live reload if you want)
sed -i -E 's/(active_border = \{ colors = \{ )"[^"]+", "[^"]+"/\1"rgba(6677ccbd)", "rgba(99aaddff)"/' ~/.config/hypr/hyprland.lua
# Restart Hyprland to apply border changes if needed (optional):
hyprctl reload

# Replace Waybar style.css with themed version
cp ~/.local/share/themes/Arch/style.css ~/.config/waybar/style.css

# Reload Waybar
pkill waybar
waybar &
