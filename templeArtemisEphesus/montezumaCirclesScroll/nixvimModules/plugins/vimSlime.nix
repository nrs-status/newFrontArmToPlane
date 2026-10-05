# vim-slime: send text from nvim buffers to a tmux pane (REPL, shell, ...).
# https://github.com/jpalardy/vim-slime
# https://nix-community.github.io/nixvim/plugins/vim-slime/index.html
#
# Complements iron.nvim: instead of spawning an in-nvim REPL, snippets are
# pasted into an already running tmux pane. Default bindings are kept:
#   `<C-c><C-c>`  send a motion / visual selection to the target pane
#   `<C-c><C-v>`  (re)configure the target
#
# Defaults target the tmux "last active" pane (`{last}`), so a two-pane layout
# with nvim on one side and a shell/REPL on the other works out of the box.
{
  plugins.vim-slime = {
    enable = true;
    settings = {
      target = "tmux";
      default_config = {
        socket_name = "default";
        target_pane = "{last}";
      };
      # always paste into the target pane without asking for confirmation
      dont_ask_default = 1;
      # do not move the cursor when sending a visual selection
      preserve_curpos = 1;
    };
  };
}
