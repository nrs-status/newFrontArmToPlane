{ pkgs, ... }:
#currently, everything except `./fishConfig.nix` and its imports are part of the default fish config
pkgs.writeTextFile {
  name = "fish config";
  text = import ./fishConfig.nix;
}


