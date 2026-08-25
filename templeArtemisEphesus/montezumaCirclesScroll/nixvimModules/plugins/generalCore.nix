{
  plugins = {

    #colored brackets, parentheses, etc.
    rainbow-delimiters.enable = true;

    #automatic nix indentation, filetype detection for .nix files, syntax highlighting for nix
    nix.enable = true;

    #automatically set expandtab (enables spaces instead of tabs) and shiftwidth (amount of whitespace to add or remove when an indentation command is called)
    sleuth.enable = true;

    #commands to add/remove/replace brackets, parenthesis, etc. in combination with motion commands
    vim-surround.enable = false;

    #commented while debugging harpoon
    #auto-save.enable = true;


    # git integrations
    gitsigns.enable = true;

    #add indentation guides
    indent-blankline = {
      enable = true;
      settings = {
        scope = {
          show_end = false;
          show_exact_scope = true;
          show_start = true;
        };
      };
    };

    #status line
    lualine.enable = true;

    treesitter = {
      enable = true;
      indent.enable = true;
    };

    #add context at the top of the window, wherever you are
    treesitter-context = {
      enable = false;
      settings = { max_lines = 5; };
    };


    #lsp improvements and prettification
    lspsaga.enable = true;


  };
}
