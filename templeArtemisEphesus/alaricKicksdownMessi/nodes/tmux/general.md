title: new named session
creationDate: 2026-08-30 03:43
body: `tmux new -s <session name>` 
--
title: rename current window
creationDate: 2026-08-31 20:26
body: `tmux rename-window <new name>`
--
title: detach from current session
creationDate: 2026-08-31 20:32
body: `tmux detach`
--
title: exit copy mode
creationDate: 2026-08-31 21:04
fuzzyAux: jump to window bottom
body: keybinding: `q`
--
title: jump to bottom of copy mode
creationDate: 2026-08-31 21:05
body: keybinding: `G`. behaves like `q` except that it doesn't exit copy mode
--
title: create a command alias for setting a session variable; command to display a session variable set in this manner
creationDate: 2026-08-31 23:42
body:
command alias:
```
tmux set -s command-alias[40] "setdesc=set-environment SESSION_DESC"
```
display the environment variable
```
tmux show-environment -t <session name> SESSION_DESC

```
--
title: create a new window with a given name
creationDate: 2026-09-01 01:10
body:
create a new window, name it, and run a command on it
```
tmux new-window -n <window name> <command>
```
--
title: create a new window with a given name but don't switch to it
creationDate: 2026-09-01 01:11
body:
```
tmux new-window -n <window name> -d
```

