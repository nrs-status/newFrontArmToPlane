title: some display options
creationDate: 2026-09-06 01:39
fuzzyAux: only commit hashes, short, long
body:
 │ git log            │ full hashes only                               │ 
 │ --format=%H        │                                                │ 
 ├────────────────────┼────────────────────────────────────────────────┤ 
 │ git log            │ short hashes only                              │ 
 │ --format=%h        │                                                │ 
 ├────────────────────┼────────────────────────────────────────────────┤ 
 │ git log            │ hash + subject (pragmatic middle ground)       │ 
 │ --format="%h %s"   │                         
--
title: display commits in one line
creationDate: 2026-09-06 01:40
body: `git log --oneline`

