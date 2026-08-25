{
  plugins.harpoon.enable = true;
  keymaps = [
    {
      key = "<Leader>a";
      mode = [ "n" ];
      action.__raw = ''
        function()
          harpoon:list():select(1)
        end
      '';
    }
  ];
}
