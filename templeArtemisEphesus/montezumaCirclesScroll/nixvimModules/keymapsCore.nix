# named keymapsCore because there are other places defining keymaps, e.g. the 'hop' plugin file
{
  keymaps = [
    #use system clipboard as default keyboard
    {
      action = ''"+y'';
      key = "y";
      mode = [ "n" ];
    }
    {
      action = ''"+yy'';
      key = "yy";
      mode = [ "n" ];
    }
    {
      action = ":noh<CR><Esc>"; # unselect search match
      key = "<Esc>";
    }
    {
      action = ":q<cr>";
      key = "<Leader>qq";
    }
    {
      action = "<Esc>ja";
      key = "jj";
      mode = [ "i" ];
    }
    {
      action = "<Esc>ka";
      key = "kk";
      mode = [ "i" ];
    }
    {
      action = "<Esc>:q<cr>";
      key = "<leader>qq";
      mode = [ "i" ];
    }
    {
      action = ":wq<cr>";
      key = "<Leader>wq";
    }
    {
      action = ":q!<cr>";
      key = "<leader>q!";
    }
    {
      action = ":w<cr>";
      key = "<leader>ww";
    }
    {
      action = ":Telescope live_grep<cr>";
      key = "<leader>lg";
    }
    {
      action = "<Esc>l";
      key = "jk";
      mode = [ "i" ];
    }
    {
      action = "<Esc>";
      key = "kj";
      mode = [ "i" ];
    }
    {
      action = ''<Cmd>lua require("conform").format()<cr>'';
      key = "<leader>m";
      mode = [ "n" ];
    }
    {
      action = "<Cmd>lua vim.lsp.buf.hover()<cr>";
      key = "<leader>gk";
      mode = [ "n" ];
      options.remap = true;
    }
    {
      # show the LSP's signature information for the function under the cursor
      action = "<Cmd>lua vim.lsp.buf.signature_help()<cr>";
      key = "<leader>gs";
      mode = [ "n" ];
    }
    {
      action = "<Cmd>lua vim.lsp.buf.definition()<cr>";
      key = "<leader>gd";
      mode = [ "n" ];
    }
    {
      action = "<Cmd>lua vim.lsp.buf.type_definition()<cr>";
      key = "<leader>gy";
      mode = [ "n" ];
    }
    {
      action = "<Cmd>lua vim.lsp.buf.implementation()<cr>";
      key = "<leader>gi";
      mode = [ "n" ];
    }
    {
      action = "<Cmd>lua vim.lsp.buf.code_action()<cr>";
      key = "<leader>ca";
      mode = [ "n" ];
    }
    {
      action = "<Cmd>lua vim.diagnostic.jump({count=1, float=true})<cr>";
      key = "<leader>j";
      mode = [ "n" ];
    }
    {
      action = "<Cmd>lua vim.diagnostic.jump({count=-1, float=true})<cr>";
      key = "<leader>k";
      mode = [ "n" ];
    }
    {
      action = "$";
      key = "<leader>ll";
      mode = [ "n" "i" ];
    }
    {
      action = "0";
      key = "<leader>hh";
      mode = [ "n" "i" ];
    }
  ];
}

