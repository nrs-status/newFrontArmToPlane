with builtins;
let
  total = rec {
    nixvimFlake = getFlake "github:nix-community/nixvim";
    libs = (getFlake "github:nrs-status/newPeachRampSkateboard").outputs;
    nixpkgs = getFlake "github:NixOS/nixpkgs/nixos-unstable";
    pkgs = import nixpkgs { system = "x86_64-linux"; };
    pkgsLib = pkgs.lib;

    inputsForImportPairs = {
      pkgsLib = pkgs.lib;
      baseLib = libs.baseLib;
      inherit nixvimFlake;
    };

    localLib = import ../../sandyFireWorksBus inputsForImportPairs;

    pred = x: (builtins.elem (baseNameOf x) [ "default.nix" "INFO "]) == false;
    filesList = libs.baseLib.listPathsSatisfyingPred {
      dir = ../../pyramidGiza;
      inherit pred;
    };
    fileListing = pkgsLib.filesystem.listFilesRecursive ../../pyramidGiza;
    filtering = builtins.filter pred fileListing;
  };
in
total

