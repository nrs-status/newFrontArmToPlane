{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "update-twc-fatp-input";
  text = ''
    #!/usr/bin/env bash

    set -euo pipefail

    initial_path="$PWD"

    cd "''${THATWATERCHARMANDER_PATH:-}"

    sudo nix flake update frontArmToPlane
    sudo git add ./flake.lock
    sudo git commit -m "updating lockfile's frontArmToPlane input" ./flake.lock

    if [[ "''${"1:-"}" == "--rebuild" ]]; then
      sudo nixos-rebuild switch --flake .#wranHearst
    fi



    cd "$initial_path"
  '';
}
