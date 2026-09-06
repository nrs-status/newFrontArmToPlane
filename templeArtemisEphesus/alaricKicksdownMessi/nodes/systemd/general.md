title: create a directory with a `tmpfiles` rule
creationDate: 2026-09-05 21:23
body:
```
   d        /var/log/journal   2755        root  systemd-journal    -   -                                                                
   type     path               mode        user  group              age arg
```
                                                                                                                                         
 - d — create the directory if it doesn't exist; if it does, fix owner/mode; never touch contents. (Siblings: D also empties on cleanup, 
   e prunes contents by age, Z/a apply recursive perms/ACLs, h sets file attributes — you can see other rule types in this very system's 
   config, like h … +C for no-COW and A+ … for ACLs.)                                                                                    
 - /var/log/journal — the crux: journald in its default Storage=auto mode does persistent logging if and only if this directory exists;  
   otherwise logs live only in /run/log/journal (tmpfs) and vanish at reboot. This single line is what flips journald into persistent    
   mode. Per-machine logs go in a machine-id subdirectory (67b12c51… above).                                                             
 - 2755 — rwxr-sr-x: full access for the owner, read+execute for group/others, and the leading 2 = setgid bit on the directory, so       
   anything created inside inherits the systemd-journal group automatically.                                                             
 - root / systemd-journal — owner and group. The group matters for access control: membership in systemd-journal is what lets a user     
   read all journal files (journalctl without restrictions). NixOS grants it to users in wheel/adm; note the journal files themselves    
   come up as -rw-r-----+ root systemd-journal — the trailing + being ACLs that the separate A+ rules in the journald config add for     
   adm/wheel.                                                                                                                            
 - "-" Age: never age-delete contents during cleanup (journal retention is governed separately by journald's SystemMaxUse/vacuum         
   settings).                                                                                                                            
    - "-" Argument: unused for type d (it's where you'd put a symlink target, source for copies, or ACL entries for other types).
--
