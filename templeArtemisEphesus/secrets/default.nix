{ pkgs, ... }:
pkgs.symlinkJoin {
  name = "secrets";
  paths = [
    (pkgs.writeText ".sops.yaml" (builtins.readFile ./.sops.yaml))
    (pkgs.writeText "secrets.yaml" (builtins.readFile ./secrets.yaml))
  ];
}
