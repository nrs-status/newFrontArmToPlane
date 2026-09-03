{
  plugins.cmp = {
    enable = true;
    autoEnableSources = true;
    settings = {
      mapping = {
        __raw = ''
          cmp.mapping.preset.insert({
          ['<C-j>'] = cmp.mapping.select_next_item(), 
          ['<C-k>'] = cmp.mapping.select_prev_item(),
          ['<C-c>'] = cmp.mapping.abort(),

          ['<C-b>'] = cmp.mapping.scroll_docs(-4),

           ['<C-w>'] = cmp.mapping.scroll_docs(4),

           ['<C-Space>'] = cmp.mapping.complete(), --invokes completion


           ['<C-CR>'] = cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true }),
          })
        '';
      };
      sources = [
        { name = "nvim_lsp"; } # LSP completion (nix, lean4, js/ts, clojure, scheme, python, haskell, ocaml, lua, C, ...)
        { name = "luasnip"; } # snippets from LuaSnip / friendly-snippets
        { name = "buffer"; } # words from open buffers
        { name = "path"; }
        { name = "cmdline"; }
        { name = "kitty"; }
      ];
      # show a completion menu even when it's the only candidate,
      # so the <Tab> confirm function in tabKeyFunc.lua can trigger
      completion.completeopt = "menu,menuone,noselect";
    };
  };
}
