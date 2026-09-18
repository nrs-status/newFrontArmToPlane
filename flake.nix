{
  inputs = {
    nixvimFlake.url = "github:nix-community/nixvim";
    mcEatBurg.url = "github:nrs-status/mcEatBurg";
    peachRampSkateboard.url = "github:nrs-status/newPeachRampSkateboard";
    # microvm.nix: modules to run NixOS configurations as micro-VMs
    microvm = {
      url = "github:microvm-nix/microvm.nix";
    };
  };

  outputs =
    inputs:
    let
      pkgs = inputs.mcEatBurg.pkgs;
      pkgsLib = inputs.peachRampSkateboard.pkgsLib; # pkgsLib is distinguished from pkgs because logically they are independent: pkgsLib is used to provide glue code to make the repository work, pkgs provides actual build components
      baseLib = inputs.peachRampSkateboard.baseLib;
      localLib = import ./sandyFireworksBus {
        nixvimFlake = inputs.nixvimFlake;
        inherit baseLib pkgsLib pkgs;
      };
      modulesPath = "${inputs.nixpkgs}/nixos/modules";
      microvmFlake = inputs.microvm;
      nixosSystem = inputs.nixpkgs.lib.nixosSystem;
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
          ;
      };
      localPkgs = pkgs.lib.fix (
        self:
        let
          wrappers = import ./templeArtemisEphesus (localPkgsArgs // { localPkgs = self; });
          newPkgs = import ./lighthouseAlexandria (localPkgsArgs // { localPkgs = self; });
        in
        wrappers // newPkgs
      );
    in
    {
      inherit localPkgsArgs;
      packages."x86_64-linux" = localPkgs;
      devShells."x86_64-linux" = import ./pyramidGiza {
        inherit
          baseLib
          pkgs
          localPkgs
          pkgsLib
          ;
      };
    };
}
