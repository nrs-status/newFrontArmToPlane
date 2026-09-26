# todo-comments.nvim: highlight, list and search TODO/FIXME/... comments.
# https://github.com/folke/todo-comments.nvim
# https://nix-community.github.io/nixvim/plugins/todo-comments/index.html
#
# nixvim declares `ripgrep` as a runtime dependency of the plugin and puts it
# on the wrapped neovim's PATH, so the search-based commands (quickfix, loclist,
# telescope, ...) work without any extra wiring.
#
# Only integration-free keymaps are configured here so that this fragment can
# live in the `base` module set as well as the `full` one:
#   * `todoQuickFix` / `todoLocList` only rely on neovim itself.
#   * The telescope/trouble integrations are intentionally left unset because
#     those plugins are only present in the `full` profile.
{
  plugins.todo-comments = {
    enable = true;
    settings = {
      # show an icon in the sign column for every matched keyword
      signs = true;

      # highlight multi-line todo comments (the text following the keyword)
      highlight = {
        multiline = true;
        # only match keywords inside treesitter comments, not in string literals
        comments_only = true;
      };
    };

    keymaps = {
      # `:TodoQuickFix` populates the quickfix list with every match, which the
      # `quicker` fragment renders nicely.
      todoQuickFix.key = "<leader>tq";
      # `:TodoLocList` is the buffer/window-local variant.
      todoLocList.key = "<leader>tl";
    };
  };
}
