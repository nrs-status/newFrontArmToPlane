{
  plugins.luasnip = {
    enable = true;
    fromLua = [
      {
        paths = ./.;
      }
    ];
  };

  keymaps = [
    {
      mode = "i";
      key = "<C-k>";
      action = "<cmd>lua require('luasnip').expand_or_jump()<cr>";
      options.desc = "LuaSnip: expand snippet or jump to next node";
    }
    {
      mode = [
        "i"
        "s"
      ];
      key = "<C-j>";
      action = "<cmd>lua require('luasnip').jump(-1)<cr>";
      options.desc = "LuaSnip: jump to previous node";
    }
  ];
}
