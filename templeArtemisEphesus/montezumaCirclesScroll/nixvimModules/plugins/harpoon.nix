{
  plugins.harpoon.enable = true;
  keymaps = [
    {
      key = "<Leader>a";
      mode = [ "n" ];
      action.__raw = ''
        function()
          require("harpoon"):list():select(1)
        end
      '';
    }

    {
      key = "<C-e>";
      mode = [ "n" ];
      action.__raw = ''
        function()
          require("harpoon").ui:toggle_quick_menu(harpoon:list())
        end
      '';
    }
  ];
}
