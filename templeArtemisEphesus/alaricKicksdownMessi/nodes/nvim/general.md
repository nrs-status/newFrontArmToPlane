
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
title: open a file in read-only mode
creationDate: 2026-09-01 02:35
body: `nvim -R <path>`
--
title: send visual selection to command line without overwriting selection
creationDate: 2026-09-06 21:37
body: visual selection with `w !` e.g.:
`:'<,'>w !md5sum > /tmp/out && cat /tmp/out `
--
title: Record a macro and apply it on all lines matching a certain string.
creationDate: 2026-09-25 10:30
body: 

1. Start recording into register a:
    ```
      qa
    ```
2. Do the actions on the current line. For example, to delete the line and replace it with foo:
    ```
      ddifoo<Esc>
    ```
    or equivalently, use cc (change line) which deletes and enters insert mode in one step:
    ```
      ccfoo<Esc>
    ```
3. Stop recording:
    ```
      q
    ```
4. `:g/hello/normal @a`
--
