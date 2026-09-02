title: print current directory name, omitting parents
creationDate: 2026-09-01 01:13
body: `basename "$PWD"`
--
title: delete everything in a directory except a particular file
creationDate: 2026-09-02 03:19
body: `find <directory path> -maxdepth 1 ! -name '<filename>' -delete`
