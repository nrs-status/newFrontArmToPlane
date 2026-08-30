#!/usr/bin/env bash
# Launch a kitty terminal, resize it to 1366x765, and move it to the sway scratchpad.
set -euo pipefail

WIDTH=1366
HEIGHT=765

# Launch kitty
swaymsg exec kitty

# Wait for the new window to appear and gain focus
sleep 0.5

# Resize the focused (newly created) kitty window
swaymsg resize set width "$WIDTH" height "$HEIGHT"

# Small delay to let the resize apply before moving off-screen
sleep 0.2

# Move the window to the scratchpad
swaymsg move scratchpad
