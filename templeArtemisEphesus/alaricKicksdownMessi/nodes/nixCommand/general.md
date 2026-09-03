
--
title: `nix shell` description
creationDate: Tue Aug 25 03:41:21 AM GMT 2026
fuzzyAux: nix command shell examples
body: `nix shell` starts a shell with the specified package on a flake. examples:
```
nix shell nixpkgs#grex 
```
--
title: build a flake package, no result symlink, print out dir
creationDate: 2026-08-31 01:47
body: `nix build --no-link --print-out-paths <flake>#<package>`
--
title: build a vm from a flake containing a nixos config
creationDate: 2026-09-03 07:38
body: `nixos-rebuild build-vm <flake path>#<host name>`
