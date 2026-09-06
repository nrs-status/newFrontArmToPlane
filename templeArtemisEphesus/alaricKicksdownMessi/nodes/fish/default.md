title: remove alias/function
creationDate: 2026-09-03 23:40
fuzzyAux: delete
body: `functions -e <alias/function name>`
--
title: create an alias/function to a bash script in the current directory
creationDate: 2026-09-03 23:47
body: `alias <name> "$PWD/<script filename>"`. Note: the path argument must be in double quotes, otherwise it will get expanded at call time instead of at definition time
--
title: export a variable
creationDate: 2026-09-06 03:34
body: `set -x <var name> <var val>`
you need to do this notably so that the `nix` command inherits these variables as environment variables
--
title: fuzzy search over history
creationDate: 2026-09-06 04:17
body: `Ctrl+R`
--
title: command to list keymappings
creationDate: 2026-09-06 04:48
body: `bind`
--
title: open $EDITOR to edit command. execute on save, discard on no save
creationDate: 2026-09-06 04:51
body: `Alt+E`
--
title: debug key presses
creationDate: 2026-09-06 04:52
body: run the command `fish_key_reader`
