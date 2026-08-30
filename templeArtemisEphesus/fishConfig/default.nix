{ pkgs, ... }:
pkgs.writeTextFile {
  name = "fish config";
  text = import ./fishConfig.nix;
}


