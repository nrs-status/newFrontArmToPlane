{ pkgs, gruvboxDarkConfig }:
let
  # smart-splits.nvim kitty integration needs the `relative_resize.py` kitten
  # shipped by the plugin (normally installed by its `kitty/install-kittens.bash`
  # post-install hook); referencing the plugin source directly means kitty
  # loads it straight from the nix store.
  smartSplits = pkgs.vimPlugins.smart-splits-nvim;
in
''
font_family Iosevka

shell_integration no-rc

bold_font Iosevka Semibold
bold_italic_font Iosevka Semibold Italic
cursor_blink_interval 0.5
cursor_stop_blinking_after 15
disable_ligatures always
enable_audio_bell no
input_delay 1
italic_font Iosevka Light Italic
mouse_hide_wait 0
remember_window_size no
repaint_delay 8
scrollback_fill_enlarged_window yes
scrollback_lines 5000
symbol_map U+e000-U+e00a,U+ea60-U+ebeb,U+e0a0-U+e0c8,U+e0ca,U+e0cc-U+e0d4,U+e200-U+e2a9,U+e300-U+e3e3,U+e5fa-U+e6b1,U+e700-U+e7c5,U+f000-U+f2e0,U+f300-U+f372,U+f400-U+f532,U+f0001-U+f1af0 Symbols Nerd Font Mono
touch_scroll_multiplier 3

include ${gruvboxDarkConfig}


#-------------- kitty-scrollback.nvim
allow_remote_control yes
listen_on unix:/tmp/kitty 
shell_integration

# kitty-scrollback.nvim Kitten alias
action_alias kitty_scrollback_nvim kitten '/nix/store/lvfjsjqa9hcyca4mk63j7sgw72xri0i3-vim-pack-dir/pack/myNeovimPackages/start/kitty-scrollback.nvim/python/kitty_scrollback_nvim.py'
# Browse scrollback buffer in nvim
map kitty_mod+h kitty_scrollback_nvim
# Browse output of the last shell command in nvim
map kitty_mod+g kitty_scrollback_nvim --config ksb_builtin_last_cmd_output
# Show clicked command output in nvim
mouse_map ctrl+shift+right press ungrabbed combine : mouse_select_command_output : kitty_scrollback_nvim --config ksb_builtin_last_visited_cmd_output


#-------------- smart-splits.nvim (kitty multiplexer integration)
# The nvim-side smart-splits.nvim plugin (see
# templeArtemisEphesus/montezumaCirclesScroll/nixvimModules/plugins/smart-splits.nvim)
# sets the `IS_NVIM` kitty user-var when it loads, so with kitty's
# conditional mappings the same keys below navigate kitty OS windows when a
# shell/TUI is focused and are passed through to nvim (where smart-splits
# handles them, crossing the terminal boundary at nvim split edges) when a
# nvim window is focused.
#
# Requires the socket-based remote control setup above
# (`allow_remote_control yes` + `listen_on unix:/tmp/kitty`).
#
# NOTE: smart-splits' `at_edge = "wrap"` is unsupported under kitty.

# navigation between kitty OS windows
map ctrl+j neighboring_window down
map ctrl+k neighboring_window up
map ctrl+h neighboring_window left
map ctrl+l neighboring_window right

# pass navigation keys through to nvim when it is focused
map --when-focus-on var:IS_NVIM ctrl+j
map --when-focus-on var:IS_NVIM ctrl+k
map --when-focus-on var:IS_NVIM ctrl+h
map --when-focus-on var:IS_NVIM ctrl+l

# resize kitty OS windows via the plugin's relative_resize.py kitten (3 =
# resize amount, matching smart-splits' default step size)
map alt+j kitten ${smartSplits}/kitty/relative_resize.py down 3
map alt+k kitten ${smartSplits}/kitty/relative_resize.py up 3
map alt+h kitten ${smartSplits}/kitty/relative_resize.py left 3
map alt+l kitten ${smartSplits}/kitty/relative_resize.py right 3

# pass resize keys through to nvim when it is focused
map --when-focus-on var:IS_NVIM alt+j
map --when-focus-on var:IS_NVIM alt+k
map --when-focus-on var:IS_NVIM alt+h
map --when-focus-on var:IS_NVIM alt+l
''
