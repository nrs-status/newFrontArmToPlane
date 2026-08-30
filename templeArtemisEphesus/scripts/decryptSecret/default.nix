{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "decryptSecret";
  text = builtins.readFile ./decryptSecret.sh;
}
