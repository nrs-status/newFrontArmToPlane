{
  inputs = {
    nixvimFlake.url = "github:nix-community/nixvim";
    nixpkgs.url = "github:NixOs/nixpkgs/nixos-unstable";
    peachRampSkateboard.url = "github:nrs-status/newPeachRampSkateboard";
  };

  outputs = inputs:
    let
      pkgs = import inputs.nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      pkgsLib = pkgs.lib; #pkgsLib is distinguished from pkgs because logically they are independent: pkgsLib is used to provide glue code to make the repository work, pkgs provides actual build components
      baseLib = inputs.peachRampSkateboard.baseLib;
      localLib = import ./sandyFireworksBus {
        nixvimFlake = inputs.nixvimFlake;
        inherit baseLib pkgsLib pkgs;
      };
      localPkgs = pkgs.lib.fix (self: import ./templeArtemisEphesus {
        inherit localLib baseLib pkgs pkgsLib;
        localPkgs = self;
      });
    in {
      packages."x86_64-linux" = localPkgs;
      devShells."x86_64-linux" = import ./pyramidGiza {
        localPkgs = inputs.self.packages."x86_64-linux";
        inherit baseLib pkgs pkgsLib;
      };
    };
}
