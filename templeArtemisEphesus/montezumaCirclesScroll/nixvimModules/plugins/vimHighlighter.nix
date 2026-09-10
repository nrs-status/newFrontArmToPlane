# https://github.com/azabiong/vim-highlighter
# `vim-highlighter` has no first-class nixvim module, so the plugin is built
# from source and injected through `extraPlugins`. Key mappings (HiSet,
# HiErase, HiClear, HiFind, HiSetSL) are set below via the plugin's
# `let Hi...` variables; they must be defined before the plugin's `plugin/`
# scripts run, which is why they live in `extraConfigVim` (nixvim's generated
# config is sourced before plugin scripts).
{ pkgs, ... }:
{
  extraPlugins = [
    {
      plugin = (
        pkgs.vimUtils.buildVimPlugin {
          pname = "vim-highlighter";
          version = "1.64.1";
          src = pkgs.fetchFromGitHub {
            owner = "azabiong";
            repo = "vim-highlighter";
            rev = "48a18eea513f651359457845e20b4c6202f6a84a";
            hash = "sha256-ie73po2C99jp8Q0fL3sklNu76xn5GkanQKFxCWTQicM=";
          };
        }
      );
    }
  ];
  extraConfigVim = ''
    " settings for vim-highlighter (based on upstream defaults, made explicit
    " here for tweakability)
    let HiSet   = '<Leader>h<CR>'
    let HiErase = '<Leader>h<BS>'
    let HiClear = '<Leader>h<C-L>'
    let HiFind  = '<Leader>h<Tab>'
    let HiSetSL = '<Leader>ht<CR>'
  '';
}
