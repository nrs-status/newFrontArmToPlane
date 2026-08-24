{
  inputs = {
    nixvimFlake.url = "github:nix-community/nixvim";
    nixpkgs2605.url = "github:NixOs/nixpkgs/nixos-26.05";
    peachRampSkateboard.url = "github:nrs-status/newPeachRampSkateboard";
  };

  outputs = inputs:
    let
      pkgs = import inputs.nixpkgs2605 {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      baseLib = inputs.peachRampSkateboard.baseLib;
      localLib = import ./sandyFireworksBus {
        nixvimFlake = inputs.nixvimFlake;
        pkgsLib = pkgs.lib;
        inherit baseLib;
      };
    in {
      packages."x86_64-linux" =
        import ./templeArtemisEphesus { inherit localLib baseLib pkgs; };
      devShells."x86_64-linux" = import ./pyramidGiza {
        localPkgs = inputs.self.packages."x86_64-linux";
        inherit baseLib pkgs;
      };
    };
}
