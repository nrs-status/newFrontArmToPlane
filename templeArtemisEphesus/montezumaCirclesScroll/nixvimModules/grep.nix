# ripgrep as the engine behind vim's `:grep` / `:vim` (quickfix) commands.
#
# nixvim (as of the locked revision) has no top-level `grepProgram` option, so
# `grepprg`/`grepformat` are set directly:
#   * `grepprg` replaces the default `grep -n` invocation with rg
#     (`--vimgrep` emits per-match lines that the quickfix list can parse;
#     `--smart-case` mirrors the `smartcase` option in ./opts.nix)
#   * `grepformat` tells vim how to parse rg's `file:line:col:text` output
#
# rg is also added to `extraPackages` so it is on the PATH of the wrapped
# neovim. This guarantees `grepprg` resolves even if the outer environment
# has no ripgrep (e.g. devshells), and incidentally makes telescope's
# `live_grep` / fzf-lua's grep work too.
{ pkgs, ... }:
{
  config = {
    extraPackages = [ pkgs.ripgrep ];

    opts = {
      grepprg = "${pkgs.ripgrep}/bin/rg --vimgrep --smart-case";
      grepformat = "%f:%l:%c:%m,%f:%l:%m";
    };
  };
}
