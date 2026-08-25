inputs:
inputs.baseLib.importPairsOfDirPath {
  dirPath = ./.;
  pred = x: (builtins.elem (baseNameOf x) [ "default.nix" "INFO"]) == false;
  inputsForImportPairs = inputs;
}

