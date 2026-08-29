{
  opts = {
    number = true; # show line numbers
    relativenumber = false; # show relative line numbers

    mouse = "a"; # enable mouse control -- disable eventually!

    mousemodel = "extend"; # mouse right-click extends the current selection

    shiftwidth = 4;
    tabstop = 4;
    swapfile = false; # disable the swap file
    modeline = true;
    modelines = 100; # sets the type of modelines
    undofile = true; # automatically save and resto undo history
    incsearch =
      true; # incremental search: show matches for partly typed search command
    inccommand = "split"; # search and replace: preview changes in quickfix list
    ignorecase =
      true; # when the search query is lower-case, match both lower and upper-case
    smartcase =
      true; # override the 'ignorecase' option if the search pattern contains upper case characters
    scrolloff = 8; # number of screen lines to show around the cursor
    cursorline = true; # highlight the screen line of the cursor
    cursorcolumn = true; # highlight the screen column of the cursor

    #the following are config'd according to the nvim-ufo recommendations
    foldcolumn = "0";
    foldlevel = 99;
    foldlevelstart = 99;
    foldenable = true;

  };
}
