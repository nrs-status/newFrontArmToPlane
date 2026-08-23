{ baseLib, pkgsLib, nixvimFlake, ... }: 
{ modulesPath, moduleSetsPath }:
baseLib.withDebug rec { 
  importPairs = baseLib.importPairsOfDirPath {
    pred = filePath: baseNameOf filePath != "README.md";
    dirPath = moduleSetsPath;
  };
  withCorrectRootAux = _: modulePathList: map (modulePath: pkgsLib.path.append modulesPath modulePath) modulePathList;
  withCorrectRoot = builtins.mapAttrs withCorrectRootAux importPairs;
  nixvimEvalsAux = _: modulePathList: nixvimFlake.lib.evalNixvim {
    system = "x86_64-linux";
    modules = modulePathList;
  };
  nixvimEvals = builtins.mapAttrs nixvimEvalsAux withCorrectRoot;
  __output = builtins.mapAttrs (_: eval: eval.config.build.package) nixvimEvals;
  __activateDebug = false;
}
