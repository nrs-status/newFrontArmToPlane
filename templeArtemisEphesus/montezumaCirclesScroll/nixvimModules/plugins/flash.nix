{
  plugins.flash = {
    enable = true;
  };
  keymaps = [
    {
      key = "f"; # used to activate the hop plugin
      action.__raw = ''
                function()
        require("flash").jump({
          search = { forward = true, wrap = false, multi_window = false },
        })
                end
      '';
      options.remap = true;
    }

    {
      key = "F"; # used to activate the hop plugin
      action.__raw = ''
                function()
        require("flash").jump({
          search = { forward = false, wrap = false, multi_window = false },
        })
                end
      '';
      options.remap = true;
    }
  ];
}
