{ config, ... }:
{
  plugins = {

    #colored brackets, parentheses, etc.
    rainbow-delimiters.enable = true;

    #automatic nix indentation, filetype detection for .nix files, syntax highlighting for nix
    nix.enable = true;

    #automatically set expandtab (enables spaces instead of tabs) and shiftwidth (amount of whitespace to add or remove when an indentation command is called)
    sleuth.enable = true;

    #commands to add/remove/replace brackets, parenthesis, etc. in combination with motion commands
    #testing mini.surround replacement
    #vim-surround.enable = false;

    
    auto-save = {
      enable = true;
      settings = {
        condition = ''
          function(buf)
            if vim.bo[buf].filetype == "harpoon" then
              return false
            end
          end
        '';
      };
    };

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
      highlight.enable = true; # needed for `otter`

      #testing whether this fixes bash within nix strings
      grammarPackages = with config.plugins.treesitter.package.builtGrammars; [
        lua
        bash
        vim
        nix
        nu
      ];
    };

    #add context at the top of the window, wherever you are
    treesitter-context = {
      enable = true;
      settings = {
        max_lines = 5;
      };
    };

    #lsp improvements and prettification
    lspsaga.enable = true;




    # various small utilities
    mini = {
      enable = true;
      modules = {
        ai = {
          n_lines = 50;
          search_method = "cover_or_next";
        };
        #functions to go forwards/backwards to certain target
        bracketed = {};
        surround = {
          mappings = {
            add = "gsa";
            delete = "gsd";
            find = "gsf";
            find_left = "gsF";
            highlight = "gsh";
            replace = "gsr";
            update_n_lines = "gsn";
          };
        };
      };
    };
  };
}
