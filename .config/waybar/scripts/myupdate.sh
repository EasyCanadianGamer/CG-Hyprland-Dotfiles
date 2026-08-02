#!/bin/bash

pacman_updates=$(checkupdates 2>/dev/null | wc -l)
aur_updates=$(yay -Qum 2>/dev/null | wc -l)
total_updates=$((pacman_updates + aur_updates))

# Determine notification message
#if [ "$total_updates" -gt 0 ]; then
#    notify-send -u normal -i system-software-update "System Updates Available" \
#        "Pacman: $pacman_updates\nAUR: $aur_updates\nClick the update icon to update."
#fi

# Set Waybar class based on update count
if [ "$total_updates" -eq 0 ]; then
  class="no-updates"
elif [ "$total_updates" -le 10 ]; then
  class="some-updates"
else
  class="many-updates"
fi

# Output for Waybar
echo "{\"text\":\"$total_updates\", \"tooltip\":\"Pacman: $pacman_updates\\nAUR: $aur_updates\", \"class\":\"$class\"}"
