# comment.nvim: smart and powerful comment plugin.
# https://github.com/numtostr/comment.nvim
# https://nix-community.github.io/nixvim/plugins/comment/index.html
#
# Out of the box it provides the usual comment toggles:
#   * NORMAL mode:    `gcc` (line), `gbc` (block)
#   * VISUAL mode:    `gc`  (line), `gb`  (block)
#   * extra mappings: `gcO` (above), `gco` (below), `gcA` (end of line)
#
# The plugin ships treesitter-aware commentstrings for many filetypes via
# `Comment.api`. No extra dependency is required.
{
  plugins.comment = {
    enable = true;
    settings = {
      # keep the cursor where it is after (un)commenting instead of moving it
      # to the first non-blank character
      sticky = true;

      # insert a space between the comment leader and the commented text,
      # i.e. `// foo` instead of `//foo`
      padding = true;

      # enable all of the subscription-based mappings (defaults, made explicit)
      mappings = {
        basic = true;
        extra = true;
      };
    };
  };
}
