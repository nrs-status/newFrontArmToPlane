title: list files recursively
creationDate: 2026-09-04 09:25
body: `eza -R`
--
title: list files recursively in a tree view
creationDate: 2026-09-04 09:26
body: `eza --tree` or `eza -T`
you can also limit the depth with
`eza --tree --level=2`
--
title: list showing last modified timestamp
creationDate: 2026-09-04 09:33
body: `eza -l --modified`
--
title: list showing last accessed timestamp
creationDate: 2026-09-04 09:34
body: `eza -l --accessed`
--
title: list showing creation timestamp
creationDate: 2026-09-04 09:34
body: `eza -l --created`
--
title: explanation of `eza -l` output
creationDate: 2026-09-06 02:38
fuzzyAux: file permissions
body:
   .rwxr-xr-x 0 sieyes users   6 Sep 02:35   a                                                                                             
   └───┬────┘ └┘ └──┬──┘ └─┬─┘ └───┬──────┘  └┬┘                                                                                         
   permissions size user  group  date modified name
