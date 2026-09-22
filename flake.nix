{
  inputs = {
    nixvimFlake.url = "github:nix-community/nixvim";
    mcEatBurg.url = "github:nrs-status/mcEatBurg";
    nasExitGiScorp.url = "github:nrs-status/nasExitGiScorp";
    peachRampSkateboard.url = "github:nrs-status/newPeachRampSkateboard";
    microvm = {
      url = "github:microvm-nix/microvm.nix";
    };
  };

  outputs =
    inputs:
    let
      pkgs = inputs.mcEatBurg.pkgs;
      nixpkgs = inputs.mcEatBurg.nixpkgs;
      pkgsLib = inputs.peachRampSkateboard.pkgsLib; # pkgsLib is distinguished from pkgs because logically they are independent: pkgsLib is used to provide glue code to make the repository work, pkgs provides actual build components
      baseLib = inputs.peachRampSkateboard.baseLib;
      localLib = import ./sandyFireworksBus {
        nixvimFlake = inputs.nixvimFlake;
        inherit baseLib pkgsLib pkgs;
      };
      modulesPath = "${nixpkgs}/nixos/modules";
      microvmFlake = inputs.microvm;
      nixosSystem = nixpkgs.lib.nixosSystem;
      newPkgs = inputs.nasExitGiScorp.packages."x86_64-linux";
      localPkgsArgs = {
        # abstracting this out is useful for debugging sessions
        inherit
          localLib
          baseLib
          pkgs
          pkgsLib
          modulesPath
          nixosSystem
          microvmFlake
          newPkgs
          ;
      };
      localPkgs = pkgs.lib.fix (
        self:
        let
          wrappers = import ./templeArtemisEphesus (localPkgsArgs // { localPkgs = self; });
        in
        wrappers
      );
    in
    {
      inherit localPkgsArgs;
      packages."x86_64-linux" = localPkgs;
      devShells."x86_64-linux" = import ./pyramidGiza {
        inherit
          newPkgs
          baseLib
          pkgs
          localPkgs
          pkgsLib
          ;
      };
      templates = {
        init = {
          path = ./colossusRhodes/init;
          description = "init";
        };
      };
    };
}
