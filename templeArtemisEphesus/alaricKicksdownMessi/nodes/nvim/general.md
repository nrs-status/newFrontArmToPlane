
--
title: how to print nixvim's lua config
creationDate: Tue Aug 25 03:35:27 AM GMT 2026
fuzzyAux:
    - init.lua
    - nixvim compiled lua config
    - print init lua 
    - neovim nvim nixvim 
body: nixvim's storepath contains, in the bin directory, a command to print the compiled lua config
--
title: output the result of a lua command to a buffer
creationDate: Sat Aug 29 11:35:38 PM GMT 2026
body: open a buffer with `:new`, wrap the command `x` with `put =execute('lua =x')`, then run the command with `:%so` (double quotes must be escape)
--
