# https://github.com/stevearc/quicker.nvim
# `quicker` improves the Neovim quickfix/location list: better rendering,
# inline editing of quickfix entries, buffer context expansion and per-buffer
# highlights. It has a first-class nixvim module (`plugins.quicker`). The
# quickfix-window-local keymaps below are defined through `settings.keys`
# (buffer-local to quickfix windows only), while the global toggles live in the
# top-level `keymaps` list. `<Leader>qq` is already taken (`:q`), so the
# toggles are placed under the `<Leader>c` prefix (`cq` = quickfix, `cl` =
# location list).
{
  plugins.quicker = {
    enable = true;
    settings = {
      keys = [
        {
          __unkeyed-1 = ">";
          __unkeyed-2.__raw = ''
            function()
              require("quicker").expand({ before = 2, after = 2, add_to_existing = true })
            end
          '';
          desc = "Expand quickfix context";
        }
        {
          __unkeyed-1 = "<";
          __unkeyed-2.__raw = ''
            function()
              require("quicker").collapse()
            end
          '';
          desc = "Collapse quickfix context";
        }
        {
          __unkeyed-1 = "q";
          __unkeyed-2.__raw = ''
            function()
              require("quicker").close()
            end
          '';
          desc = "Close quickfix window";
        }
      ];
      highlight = {
        # load the source buffers to highlight each quickfix line
        load_buffers = true;
      };
      edit = {
        # enable editing the quickfix like a normal buffer, and write the
        # buffers to disk after applying the edits
        enabled = true;
        autosave = true;
      };
    };
  };

  keymaps = [
    {
      key = "<Leader>cq";
      mode = [ "n" ];
      action.__raw = ''
        function()
          require("quicker").toggle()
        end
      '';
      options.silent = true;
      options.desc = "Toggle quickfix list";
    }
    {
      key = "<Leader>cl";
      mode = [ "n" ];
      action.__raw = ''
        function()
          require("quicker").toggle({ loclist = true })
        end
      '';
      options.silent = true;
      options.desc = "Toggle location list";
    }
  ];
}