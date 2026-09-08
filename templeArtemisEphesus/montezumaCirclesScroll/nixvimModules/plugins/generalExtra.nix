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
    #TODO: config to make the toggle that can be seen at 8:03 in
    #https://www.youtube.com/watch?v=xdXE1tOT-qg 
    #(am not sure whether it's this plugin or just a simple wrapper around vim.diagnostic.enable()/disable())
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

    #regex pattern viewer
    patterns.enable = true;

    fzf-lua.enable = true;

    #needs configuration, works in principle
    # otter = {
    #   enable = true;
    #   settings = {
    #     extensions = {
    #       nix = "nix";
    #     };
    #   };
    # };

    kitty-scrollback.enable = true;

    #structural editing
    treesj.enable = true;

    #improved quickfix list
    #does this overlap with trouble.nvim? worth checking quicker.nvim also
    nvim-bqf.enable = true;

    #show at top of screen e.g. which function we are in
    treesitter-context.enable = true;
  };
}
