{ pkgs, ... }:
# tell: a CLI tool (Haskell) to add entries to the `nodes' table of the `doc'
# PostgreSQL database. Internalized from the former `tell' flake; built with
# the repository's nixpkgs instead of the flake's own pin so all Haskell
# dependencies are shared with the rest of the repository.
pkgs.haskellPackages.callCabal2nix "tell" ./. { }
