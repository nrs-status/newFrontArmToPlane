inputs:
inputs.baseLib.importPairsOfDirPath {
  dirPath = ./.;
  pred = x:
    (dirOf x == ./.) && baseNameOf x != "default.nix" && baseNameOf x != "INFO";
  inputsForImportPairs = inputs;
  excludeDirectories = false;
}
