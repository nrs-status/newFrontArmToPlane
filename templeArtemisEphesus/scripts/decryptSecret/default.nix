{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "decryptSecret";
  runtimeInputs = [ pkgs.yq ];
  text = builtins.readFile ./decryptSecret.sh;
}
