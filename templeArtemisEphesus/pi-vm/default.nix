{
  nixosSystem,
  modulesPath,
  pkgs,
  localPkgs,
  ...
  }@inputs:
{
  bare = import ./bare.nix inputs;
}
