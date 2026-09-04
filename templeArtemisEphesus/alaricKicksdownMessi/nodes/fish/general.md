title: remove alias/function
creationDate: 2026-09-03 23:40
fuzzyAux: delete
body: `functions -e <alias/function name>`
--
title: create an alias/function to a bash script in the current directory
creationDate: 2026-09-03 23:47
body: `alias <name> "$PWD/<script filename>"`. Note: the path argument must be in double quotes, otherwise it will get expanded at call time instead of at definition time
