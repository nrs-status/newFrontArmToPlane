{ pkgs, localPkgs, ... }:
pkgs.writeShellApplication {
  name = "fishWConfig";
  text = "XDG_CONFIG_HOME=${localPkgs.fishConfig} fish";
}

