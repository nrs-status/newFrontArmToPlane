# https://github.com/AckslD/nvim-neoclip.lua
# `neoclip` records yank/delete history so it can be browsed and re-pasted
# later. It has a first-class nixvim module (`plugins.neoclip`); the records
# are displayed through a picker, here `telescope` (neoclip's default
# provider, enabled in `generalExtra.nix`). The telescope keymaps in
# `settings.keys.telescope` follow the plugin's defaults, made explicit here
# for tweakability.
{
  plugins.neoclip = {
    enable = true;
    settings = {
      # store yank AND delete history
      history = 1000;
      keys = {
        telescope = {
          i = {
            paste = "<c-l>";
            paste_behind = "<c-h>";
            custom = { };
          };
          n = {
            paste = "p";
            paste_behind = "P";
            custom = { };
          };
        };
      };
    };
  };

  keymaps = [
    {
      key = "<Leader>y";
      mode = [ "n" ];
      action = ":Telescope neoclip<CR>";
      options.silent = true;
    }
  ];
}
