{
  plugins.flash = {
    enable = true;
  };
  keymaps = [
    {
      key = "f"; # used to activate the hop plugin
      action.__raw = ''
        function()
          require'flash'.jump()
        end
      '';
      options.remap = true;
    }
  ];
}
