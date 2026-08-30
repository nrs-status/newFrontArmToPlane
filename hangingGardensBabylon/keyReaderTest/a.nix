with builtins;
let
  total = rec {
    nixvimFlake = getFlake "github:nix-community/nixvim";
    libs = (getFlake "github:nrs-status/newPeachRampSkateboard").outputs;
    nixpkgs = getFlake "github:NixOS/nixpkgs/nixos-unstable";
    pkgs = import nixpkgs { system = "x86_64-linux"; };
    pkgsLib = pkgs.lib;
    baseLib = libs.baseLib;
    localLib = import ./sandyFireworksBus {
      nixvimFlake = inputs.nixvimFlake;
      pkgsLib = pkgs.lib;
      inherit baseLib;
    };
    x = import ../../sandyFireworksBus/mkKeyReader.nix { inherit pkgs; } { envVarName = "age"; keyPath = "/etc/keys.yaml"; };
  };
in
total
