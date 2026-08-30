{ pkgs, ... }:
pkgs.symlinkJoin {
  name = "secrets";
  paths = [
    (pkgs.writeTextFile ".sops.yaml" (builtins.readFile ./.sops.yaml))
    (pkgs.writeTextFile "secrets.yaml" (builtins.readFile ./secrets.yaml))
  ];
}
