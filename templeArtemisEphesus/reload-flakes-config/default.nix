{ pkgs, ... }:
pkgs.writeText "reload-flakes-config.toml" (builtins.readFile ./config.toml)

