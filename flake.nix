{
  inputs = {
    nixvimFlake.url = "github:nix-community/nixvim";
    nixpkgs.url = "github:NixOs/nixpkgs/nixos-unstable";
    peachRampSkateboard.url = "github:nrs-status/newPeachRampSkateboard";
  };

  outputs =
    inputs:
    let
      pkgs = import inputs.nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      pkgsLib = pkgs.lib; # pkgsLib is distinguished from pkgs because logically they are independent: pkgsLib is used to provide glue code to make the repository work, pkgs provides actual build components
      baseLib = inputs.peachRampSkateboard.baseLib;
      localLib = import ./sandyFireworksBus {
        nixvimFlake = inputs.nixvimFlake;
        inherit baseLib pkgsLib pkgs;
      };
      modulesPath = "${inputs.nixpkgs}/nixos/modules";
      localPkgsArgs = { # abstracting this out is useful for debugging sessions
        inherit
          localLib
          baseLib
          pkgs
          pkgsLib
          modulesPath
          ;
      };       localPkgs = pkgs.lib.fix (
        self: import ./templeArtemisEphesus (localPkgsArgs // { localPkgs = self; })
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
