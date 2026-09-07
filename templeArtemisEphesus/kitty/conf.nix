gruvboxDarkConfig:
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
''
