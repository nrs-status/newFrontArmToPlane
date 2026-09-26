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
#
# NOTE: the `IS_NVIM` pass-throughs below only work when nvim runs directly in
# kitty: that is the only case in which smart-splits.nvim sets the `IS_NVIM`
# window var (its kitty integration sends the OSC 1337 `SetUserVar` escape).
# When nvim runs inside a tmux client hosted by this window, smart-splits
# auto-detects the tmux multiplexer instead (`TERM_PROGRAM=tmux`), never sets
# `IS_NVIM`, and tmux would swallow the escape anyway. Without compensation,
# the unconditional `neighboring_window` mappings below then consumed
# ctrl+j/k (etc.) before tmux ever saw them, so they could never reach nvim --
# which broke nvim-cmp completion-menu navigation with ctrl+j/ctrl+k (see
# templeArtemisEphesus/montezumaCirclesScroll/nixvimModules/luaSnip/default.nix).
# tmux therefore announces itself by setting the `IS_TMUX` window var on the
# kitty window it is attached in (the tmux package's client wrapper in
# templeArtemisEphesus/tmux/default.nix; see also the comment in
# templeArtemisEphesus/tmux/inheritedConf.nix), and the conditional pass-
# throughs further below hand the same keys to tmux, whose `@pane-is-vim`
# bindings route them per pane (nvim when a nvim pane is focused, tmux pane
# selection/resizing otherwise). Kitty-window navigation keeps working in
# windows that host no tmux client.

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

# pass the same keys through to tmux when this window hosts a tmux client
# (tmux decides per pane: forward into nvim or navigate/resize its own panes)
map --when-focus-on var:IS_TMUX ctrl+j
map --when-focus-on var:IS_TMUX ctrl+k
map --when-focus-on var:IS_TMUX ctrl+h
map --when-focus-on var:IS_TMUX ctrl+l
map --when-focus-on var:IS_TMUX alt+j
map --when-focus-on var:IS_TMUX alt+k
map --when-focus-on var:IS_TMUX alt+h
map --when-focus-on var:IS_TMUX alt+l

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


#-------------- Shift+Enter pass-through for tmux
# tmux's extended-keys support cannot make kitty report Shift+Enter as a
# distinct key: kitty ignores xterm's modifyOtherKeys request, and pushing
# kitty's "disambiguate" keyboard mode makes tmux emit sequences that its
# input parser cannot understand (see templeArtemisEphesus/tmux/basic.conf).
# Send the CSI-u sequence for Shift+Enter instead; tmux and pi both understand
# it, so Shift+Enter inserts a newline inside tmux.  This is harmless outside
# tmux too, because pi parses the same sequence in kitty-protocol mode.
map shift+enter send_text all \x1b[13;2u
''
