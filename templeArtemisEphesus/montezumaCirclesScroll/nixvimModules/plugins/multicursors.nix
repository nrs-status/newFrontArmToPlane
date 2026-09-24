# multi cursors plugin (multicursors.nvim)
#
# The plugin is already enabled here; this module gives it sane settings
# (hint window styling, sensible timeouts, generated hydra hints) and
# exposes the plugin's user commands (:MCstart, :MCvisual, :MCpattern,
# :MCvisualPattern, :MCunderCursor, :MCclear) through leader keybindings.
#
# Once a selection is active, multicursors enters its own hydra-based
# normal/insert/extend modes which already come with the plugin's sane
# default keymaps (create up/down with j/k, skip with J/K, find
# next/prev with n/N, skip with q/Q, find-all with <C-a>, align with
# z/Z, clear others with `,`, etc.), so we only need to bind the entry
# points here.
{
  plugins.multicursors = {
    enable = true;
    settings = {
      # keep the user commands (:MCstart etc.) created, they are handy
      create_commands = true;
      # selections in insert mode get updated after this many idle ms
      updatetime = 50;
      # see :help :map-nowait; avoids delays on plugin-created mappings
      nowait = true;
      DEBUG_MODE = false;
      # hint window styling: plugin default is a borderless float;
      # a rounded border is easier to tell apart from the buffer
      hint_config = {
        float_opts = {
          border = "rounded";
        };
        position = "bottom";
      };
      # generate the hydra hints for all three modes so the available
      # keys are always visible while editing with multiple cursors
      generate_hints = {
        normal = true;
        insert = true;
        extend = true;
        config = {
          # leave column_count nil so it follows the window size
          column_count = null;
          max_hint_length = 25;
        };
      };
    };
  };

  keymaps = [
    {
      # start a multi-cursor session on the word under the cursor
      # (or on the visual selection, when invoked from visual mode)
      action = ":MCstart<cr>";
      key = "<leader>ms";
      options.silent = true;
      options.desc = "Multicursor: start on word/selection";
    }
    {
      # start from the visual selection only
      action = ":MCvisual<cr>";
      key = "<leader>mv";
      mode = [ "n" "v" ];
      options.silent = true;
      options.desc = "Multicursor: start from visual selection";
    }
    {
      # create selections by matching a pattern
      action = ":MCpattern<cr>";
      key = "<leader>mp";
      mode = [ "n" ];
      options.silent = true;
      options.desc = "Multicursor: select by pattern";
    }
    {
      # pattern match restricted to the visual selection
      # (deliberately shares the <leader>mp key with MCpattern, since
      # the two make sense in disjoint modes and a shared key avoids
      # making <leader>mv wait for a possible longer mapping)
      action = ":MCvisualPattern<cr>";
      key = "<leader>mp";
      mode = [ "v" ];
      options.silent = true;
      options.desc = "Multicursor: pattern within visual selection";
    }
    {
      # create a single extra selection under the cursor
      action = ":MCunderCursor<cr>";
      key = "<leader>mu";
      options.silent = true;
      options.desc = "Multicursor: selection under cursor";
    }
    {
      # abort/clear all selections
      action = ":MCclear<cr>";
      key = "<leader>mx";
      options.silent = true;
      options.desc = "Multicursor: clear selections";
    }
  ];
}