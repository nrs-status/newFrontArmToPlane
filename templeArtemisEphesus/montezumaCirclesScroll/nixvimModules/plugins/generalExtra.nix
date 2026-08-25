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

    #helps avoiding repeated keypresses
    hardtime.enable = true;

    #enabled but I need to take the time to actually figure out how to use it properly
    multicursors.enable = true;

    #markdown, Typst, latex, etc. previewer
    markview.enable = true;

    #vscode-like code diff
    codediff.enable = true;

    #help remember key bindings
    which-key.enable = true;

    #renders lsp responses as lines on top of code
    lsp-lines.enable = true;

    #simple navigation popup
    navbuddy.enable = true;

    #adds a tiny visual indicator to yank operators
    tiny-glimmer.enable = true;

    #diagnostics interface
    trouble.enable = true;

    #session manage
    auto-session.enable = true;

    #run code in-editor
    sniprun.enable = true;

    #FAILS
    #llm integration
    #parrot.enable = true;

    #llm integration, test after parrot
    #codecompanion.enable = true;

    #llm integration emulating cursor
    avante.enable = true;

    #regex pattern viewer
    patterns.enable = true;

    fzf-lua.enable = true;

  };
}
