{
  plugins.luasnip = {
    enable = true;
    fromLua = [
      {
        paths = ./.;
      }
    ];
  };

  # These keys are shared with nvim-cmp (see ../plugins/cmp.nix): cmp binds
  # <C-j>/<C-k> to select_next_item/select_prev_item. nixvim installs the
  # top-level `keymaps` below *after* cmp.setup, and cmp only (re)installs its
  # own insert-mode bindings lazily on InsertEnter. That leaves a window where
  # the LuaSnip mapping is the effective one, so Ctrl+j/Ctrl+k jump around
  # snippets instead of moving through the completion menu (and the snippet
  # directions are opposite to the menu directions). Route to cmp whenever its
  # menu is visible so the completion menu always wins; fall back to LuaSnip
  # only when there is no menu to navigate.
  keymaps = [
    {
      mode = "i";
      key = "<C-k>";
      action.__raw = ''
        function()
          if require("cmp").visible() then
            require("cmp").select_prev_item()
          else
            require("luasnip").expand_or_jump()
          end
        end
      '';
      options.desc = "Menu: previous entry; LuaSnip: expand snippet or jump to next node";
    }
    {
      mode = [
        "i"
        "s"
      ];
      key = "<C-j>";
      action.__raw = ''
        function()
          if require("cmp").visible() then
            require("cmp").select_next_item()
          else
            require("luasnip").jump(-1)
          end
        end
      '';
      options.desc = "Menu: next entry; LuaSnip: jump to previous node";
    }
  ];
}
