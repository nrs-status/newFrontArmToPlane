
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
--
title: force the `nix` command to forget fetch-level caches
creationDate: 2026-09-05 19:43
body: use the `--refresh` option. Note that this does not rewrite the lock.
--
title: using the `nix run` command to execute nix expression as if they were commands
creationDate: 2026-09-06 03:13
body:
Consider for instance:
```
#hello.nix
{ pkgs ? import <nixpkgs> {} }:

{
  hello-greet = pkgs.runCommand "hello-greet" {} ''
    mkdir -p $out/bin
    cat > $out/bin/hello-greet <<EOF
    #!/bin/sh
    echo "Hello from 'nix run -f'! Built at: $out"
    EOF
    chmod +x $out/bin/hello-greet
  '';
}
```
It can be ran with the command
`nix run -f <hello.nix path> hello-greet`

Some other examples of `nix run`:
`nix run -f '<nixpkgs>' python3Packages.black -- --version `
 `nix run --impure --expr '(import <nixpkgs> {}).hello'`
Running the VM script in a NixOS config:
`nix run -f hangingGardensBabylon/pi-vm/testEnv.nix vms.bare.config.system.build.vm `
