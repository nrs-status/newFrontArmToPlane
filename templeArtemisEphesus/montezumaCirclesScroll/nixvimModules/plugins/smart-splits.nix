# smart-splits.nvim: smarter split navigation/resizing/swapping, with seamless
# multiplexer integration.
#
# Multiplexer integrations (see
# https://github.com/smart-splits-nvim/smart-splits.nvim#multiplexer-integrations):
#
#   * tmux: auto-detected via `$TMUX`. The tmux-side bindings (routing
#     C-h/j/k/l / M-h/j/k/l either into nvim or to tmux pane
#     selection/resizing, based on the `@pane-is-vim` pane flag that this
#     plugin sets on load) live in `templeArtemisEphesus/tmux/basic.conf`.
#
#   * kitty: auto-detected via `$KITTY_LISTEN_ON`. Requires kitty to listen on
#     a socket for remote control (`allow_remote_control` + `listen_on`, which
#     `templeArtemisEphesus/kitty/conf.nix` already provides) plus the
#     kitty-side conditional keymaps (`IS_NVIM` user-var pass-through) defined
#     in the same file.
#     NOTE: `settings.at_edge = "wrap"` is unsupported under the kitty
#     multiplexer (kitty cannot report its pane layout over the CLI).
{
  plugins.smart-splits = {
    enable = true;
    # `multiplexer_integration` is deliberately left unset (nil): the plugin
    # then auto-detects the active multiplexer (tmux, kitty, ...) at runtime
    # from `$TERM_PROGRAM` / `$TMUX` / `$KITTY_LISTEN_ON` instead of
    # hard-coding one, so the same binary works inside tmux, kitty and bare
    # terminal sessions alike.
    settings = {
      # don't cross into multiplexer navigation while a pane is zoomed
      disable_multiplexer_nav_when_zoomed = true;
    };
  };

  keymaps = [
    # --- cursor movement (crosses into tmux/kitty panes at nvim split edges)
    {
      mode = "n";
      key = "<C-h>";
      action.__raw = "require('smart-splits').move_cursor_left";
      options.desc = "Move cursor to the left split (multiplexer-aware)";
    }
    {
      mode = "n";
      key = "<C-j>";
      action.__raw = "require('smart-splits').move_cursor_down";
      options.desc = "Move cursor to the split below (multiplexer-aware)";
    }
    {
      mode = "n";
      key = "<C-k>";
      action.__raw = "require('smart-splits').move_cursor_up";
      options.desc = "Move cursor to the split above (multiplexer-aware)";
    }
    {
      mode = "n";
      key = "<C-l>";
      action.__raw = "require('smart-splits').move_cursor_right";
      options.desc = "Move cursor to the right split (multiplexer-aware)";
    }

    # --- resizing (crosses into tmux/kitty panes at nvim split edges)
    {
      mode = "n";
      key = "<A-h>";
      action.__raw = "require('smart-splits').resize_left";
      options.desc = "Resize split left (multiplexer-aware)";
    }
    {
      mode = "n";
      key = "<A-j>";
      action.__raw = "require('smart-splits').resize_down";
      options.desc = "Resize split down (multiplexer-aware)";
    }
    {
      mode = "n";
      key = "<A-k>";
      action.__raw = "require('smart-splits').resize_up";
      options.desc = "Resize split up (multiplexer-aware)";
    }
    {
      mode = "n";
      key = "<A-l>";
      action.__raw = "require('smart-splits').resize_right";
      options.desc = "Resize split right (multiplexer-aware)";
    }

    # --- buffer swapping (purely nvim-side)
    {
      mode = "n";
      key = "<leader><C-h>";
      action.__raw = "require('smart-splits').swap_buf_left";
      options.desc = "Swap buffer with the left split";
    }
    {
      mode = "n";
      key = "<leader><C-j>";
      action.__raw = "require('smart-splits').swap_buf_down";
      options.desc = "Swap buffer with the split below";
    }
    {
      mode = "n";
      key = "<leader><C-k>";
      action.__raw = "require('smart-splits').swap_buf_up";
      options.desc = "Swap buffer with the split above";
    }
    {
      mode = "n";
      key = "<leader><C-l>";
      action.__raw = "require('smart-splits').swap_buf_right";
      options.desc = "Swap buffer with the right split";
    }
  ];
}
