with builtins;
let
  total = rec {
    nixvimFlake = getFlake "github:nix-community/nixvim";
    libs = (getFlake "github:nrs-status/newPeachRampSkateboard").outputs;
    nixpkgs = getFlake "github:NixOS/nixpkgs/nixos-unstable";
    pkgs = import nixpkgs { system = "x86_64-linux"; };

    inputsForImportPairs = {
      pkgsLib = pkgs.lib;
      baseLib = libs.baseLib;
      inherit nixvimFlake;
    };

    localLib = import ../../sandyFireWorksBus inputsForImportPairs;
    # nixvims = localLib.mkNixvim {
    #   modulesPath = ../../templeArtemisEphesus/montezumaCirclesScrolls/nixvimModules;
    #   moduleSetsPath = ../../templeArtemisEphesus/montezumaCirclesScrolls/nixvimModuleSets;
    # };

# inputs: inputs.baseLib.importPairsOfDirPath {
#   pred = filePath: (builtins.elem (baseNameOf filePath) [ "default.nix" "INFO" ]) == false;
#   dirPath = ./.; 
#   inputsForImportPairs = inputs ;
# }

  filesList = libs.baseLib.listPathsSatisfyingPred {
    dir = ../../templeArtemisEphesus;
    pred = x: (dirOf x == ../../templeArtemisEphesus) && baseNameOf x != "default.nix";
  };
  x = import ../../templeArtemisEphesus (inputsForImportPairs // { inherit localLib; });

  };
in total

# (import ./withDebug.nix) rec {
#   filesList = (import ./listDirsSatisfyingPred.nix { inherit pkgsLib; }) {
#     dir = dirPath;
#     inherit pred;
#   };

