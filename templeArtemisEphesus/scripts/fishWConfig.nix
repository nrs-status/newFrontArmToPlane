{ pkgs, localPkgs, ... }:
pkgs.writeShellApplication {
  name = "fish-w";
  text = "XDG_CONFIG_HOME=${localPkgs.fishConfig} fish";
}

