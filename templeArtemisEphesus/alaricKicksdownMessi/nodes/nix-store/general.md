title: obtain the runtime closure of a store path
creationDate: 2026-09-05 02:47
body:
`nix-store -qR <path>`, where `q` is the flag for querying, and `R` is the flag for recursion. So `-qR` means, query recursively. Therefore, `nix-store -qR <path>` will print all paths that `<path>`'s runtime depends on.
