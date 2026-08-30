
--
title: read
creationDate: Tue Aug 25 03:46:51 AM GMT 2026
body: the :read command allows you to insert the result of evaluating a bash command at the position of the cursor
--
title: redir
creationDate: Sat Aug 29 11:00:32 PM GMT 2026
fuzzyAux: output message to file, redirect buffer output, redirect output of lua command
body: allows you to redirect the some output to a register. for instance, to redirect the output of a `:lua =` command you can do:
```
   :redir! > /tmp/out.txt                                                                  
   :lua =vim.inspect(vim.tbl_keys(vim.g))                                                  
   :redir END  
```
(the exclamation mark allows overwriting the target)
--
title: source
creationDate: Sat Aug 29 11:14:58 PM GMT 2026
fuzzyAux: run buffer as command
body: allows running a range as a command to neovim. `so` is a shorthand version. for instance, the following runs the entire buffer as a neovim command:
```
:%so
```
--


