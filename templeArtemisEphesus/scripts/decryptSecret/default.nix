{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "decryptSecret";
  text = import ./decryptSecret.sh;
}
