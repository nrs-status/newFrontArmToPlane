{
  plugins = {
    #adds pictograms to lsp
    lspkind.enable = true;


    telescope = {
      enable = true;
      extensions.fzf-native.enable = true;
    };

    #pre-existing snippets collection
    friendly-snippets.enable = true;

    #folding
    #commented out for the moment. figure out how to make it work properly
    # nvim-ufo = {
    #   enable = true;
    #   openFoldHlTimeout = 0;
    #   providerSelector = ''
    #     function()
    #       return { "lsp", "indent" }
    #     end
    #   '';
    # };

  };
}
