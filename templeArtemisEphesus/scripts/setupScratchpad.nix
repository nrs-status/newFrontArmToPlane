{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "setupScratchpad";
  text = builtins.readFile ./setupScratchpad.sh;
}

