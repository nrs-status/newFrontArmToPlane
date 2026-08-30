{ pkgs, ... }:
pkgs.linkFarm "secrets" [
  { name = ".sops.yaml"; path = pkgs.writeText "sops-yaml-file" (builtins.readFile ./.sops.yaml); }
  { name = "secrets.yaml"; path = pkgs.writeText "secrets-yaml-file" (builtins.readFile ./secrets.yaml); }
]
# pkgs.symlinkJoin {
#   name = "secrets";
#   paths = [
#     (pkgs.writeText ".sops.yaml" (builtins.readFile ./.sops.yaml))
#     (pkgs.writeText "secrets.yaml" (builtins.readFile ./secrets.yaml))
#   ];
# }
