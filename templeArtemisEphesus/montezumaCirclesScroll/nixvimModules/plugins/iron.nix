# iron.nvim: interactive REPLs over neovim.
# https://github.com/Vigemus/iron.nvim
# https://nix-community.github.io/nixvim/plugins/iron/index.html
#
# Configured so that `.nu' (nushell) buffers can send snippets to a nushell
# REPL. All keybindings live under the single `<leader>r' prefix:
#   REPL management
#     `<leader>rt`  toggle the REPL window open/closed
#     `<leader>rr`  restart the REPL
#     `<leader>ri`  interrupt (Ctrl-C) the running REPL
#     `<leader>rq`  exit the REPL
#     `<leader>rw`  clear the REPL text
#   Sending snippets
#     `<leader>rl`  send the current line
#     `<leader>rs`  send a motion
#     `<leader>rv`  send the visual selection
#     `<leader>rf`  send the whole file
#     `<leader>rp`  send the paragraph
#     `<leader>ru`  send text until the cursor
#     `<leader>rm`  send the marked chunk
#   Marks (re-sendable chunks)
#     `<leader>rc`  mark a motion / visual selection
#     `<leader>rd`  remove the mark
#     `<leader>r<cr>` send a carriage return
#
# iron.nvim does not bundle a nushell filetype adapter, so the `nu' filetype
# is registered explicitly in `repl_definition'. Snippets are sent with
# bracketed paste (`iron.fts.common.bracketed_paste'), which makes nushell's
# line editor receive the whole snippet as one paste: nushell then waits for
# an incomplete expression to be finished before evaluating, so multi-line
# snippets are evaluated as a unit instead of line-by-line.
{ pkgs, lib, ... }:
{
  plugins.iron = {
    enable = true;
    settings = {
      config = {
        scratch_repl = true;
        repl_definition = {
          nu = {
            command = [ (lib.getExe pkgs.nushell) ];
            format.__raw = "require('iron.fts.common').bracketed_paste";
          };
        };
        repl_open_cmd.__raw = ''require('iron.view').split.vertical.botright(60)'';
        # close the REPL window when the shell process exits
        close_window_on_exit = true;
      };
      keymaps = {
        toggle_repl = "<leader>rt";
        restart_repl = "<leader>rr";
        send_motion = "<leader>rs";
        visual_send = "<leader>rv";
        send_file = "<leader>rf";
        send_line = "<leader>rl";
        send_paragraph = "<leader>rp";
        send_until_cursor = "<leader>ru";
        send_mark = "<leader>rm";
        mark_motion = "<leader>rc";
        mark_visual = "<leader>rc";
        remove_mark = "<leader>rd";
        cr = "<leader>r<cr>";
        interrupt = "<leader>ri";
        exit = "<leader>rq";
        clear = "<leader>rw";
      };
      highlight = {
        italic = true;
      };
      ignore_blank_lines = true;
    };
  };
}
