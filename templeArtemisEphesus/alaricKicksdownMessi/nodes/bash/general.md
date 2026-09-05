title: print current directory name, omitting parents
creationDate: 2026-09-01 01:13
body: `basename "$PWD"`
--
title: delete everything in a directory except a particular file
creationDate: 2026-09-02 03:19
body: `find <directory path> -maxdepth 1 ! -name '<filename>' -delete`
--
title: conditions and their meaning
creationDate: 2026-09-05 02:34
body:
 ┌──────────────┬────────────────────────────────────────┐                                                                               
 │ Test         │ True when                              │                                                                               
 ├──────────────┼────────────────────────────────────────┤                                                                               
 │ -f           │ regular file (not dir/symlink-to-dir)  │                                                                               
 ├──────────────┼────────────────────────────────────────┤                                                                               
 │ -L           │ is a symlink                           │                                                                               
 ├──────────────┼────────────────────────────────────────┤                                                                               
 │ -r / -w / -x │ readable / writable / executable       │                                                                               
 ├──────────────┼────────────────────────────────────────┤                                                                               
 │ -s           │ exists and size > 0 (non-empty)        │                                                                               
 ├──────────────┼────────────────────────────────────────┤                                                                               
 │ -p           │ named pipe (fifo)                      │                                                                               
 ├──────────────┼────────────────────────────────────────┤                                                                               
 │ -S           │ socket                                 │                                                                               
 ├──────────────┼────────────────────────────────────────┤                                                                               
 │ -b / -c      │ block / character device               │                                                                               
 ├──────────────┼────────────────────────────────────────┤                                                                               
 │ -N           │ modified since last read               │                                                                               
 ├──────────────┼────────────────────────────────────────┤                                                                               
 │ -t fd        │ fd is a terminal ([ -t 1 ] in scripts) │                                                                               
 └──────────────┴────────────────────────────────────────┘
-e: true when path exists
-d: true when path exists and is a directory
--
