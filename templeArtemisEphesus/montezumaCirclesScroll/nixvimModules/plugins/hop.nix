{
  plugins = {
    #find-next-character motion
    hop = { enable = true; };
  };
  keymaps = [
    {
      key = "f"; # used to activate the hop plugin
      action.__raw = ''
        function()
          require'hop'.hint_char1({
            direction = require'hop.hint'.HintDirection.AFTER_CURSOR,
            current_line_only = false
          })
        end
      '';
      options.remap = true;
    }
    {
      key = "F";
      action.__raw = ''
        function()
          require'hop'.hint_char1({
            direction = require'hop.hint'.HintDirection.BEFORE_CURSOR,
            current_line_only = false
          })
        end
      '';
      options.remap = true;
    }
  ];
}

