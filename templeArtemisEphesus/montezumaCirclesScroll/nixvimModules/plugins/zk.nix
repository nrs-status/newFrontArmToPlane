# zk: note-taking support via zk-nvim (https://github.com/zk-org/zk-nvim).
# The `zk` CLI binary is installed automatically: nixvim's zk plugin module
# declares it as a dependency, so it is added to the wrapped neovim's PATH
# (this also provides the `zk lsp` language server used for auto-attach).
{
  plugins.zk = {
    enable = true;
    settings = {
      # `select` (the default) uses vim.ui.select, so it works in every profile,
      # regardless of which picker plugins happen to be enabled in it.
      picker = "select";
      lsp = {
        # Attach the zk LSP automatically to buffers inside a zk notebook.
        auto_attach = {
          enabled = true;
          filetypes = [ "markdown" ];
        };
      };
    };
  };

  keymaps = [
    # new note, prompting for a title
    {
      action = "<Cmd>ZkNew { title = vim.fn.input('Title: ') }<CR>";
      key = "<leader>zn";
      mode = [ "n" ];
    }
    # new daily note (in the "daily" subdirectory, if present)
    {
      action = "<Cmd>ZkNew { dir = 'daily' }<CR>";
      key = "<leader>zN";
      mode = [ "n" ];
    }
    # browse existing notes, most recently modified first
    {
      action = "<Cmd>ZkNotes { sort = { 'modified', 'desc' } }<CR>";
      key = "<leader>zo";
      mode = [ "n" ];
    }
    # list notes linked from the current one
    {
      action = "<Cmd>ZkLinks<CR>";
      key = "<leader>zl";
      mode = [ "n" ];
    }
    # list notes linking to the current one
    {
      action = "<Cmd>ZkBacklinks<CR>";
      key = "<leader>zb";
      mode = [ "n" ];
    }
    # insert a link to another note at the cursor
    {
      action = "<Cmd>ZkInsertLink<CR>";
      key = "<leader>zi";
      mode = [ "n" ];
    }
    # find notes matching the visually selected text
    {
      action = ":'<,'>ZkMatch<CR>";
      key = "<leader>zm";
      mode = [ "v" ];
    }
  ];
}