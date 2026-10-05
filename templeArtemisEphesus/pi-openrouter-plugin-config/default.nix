{ pkgs, ... }:
pkgs.writeText "pi-openrouter-extension-config.toml" (builtins.readFile ./config.toml)

