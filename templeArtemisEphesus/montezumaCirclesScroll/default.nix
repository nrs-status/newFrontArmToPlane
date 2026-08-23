{ localLib, ... }: localLib.mkNixvim {
  modulesPath = ./nixvimModules;
  moduleSetsPath = ./nixvimModuleSets;
}
