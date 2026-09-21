{
  inputs = {
    mcEatBurg.url = "github:nrs-status/mcEatBurg";
    peachRampSkateboard.url = "github:nrs-status/newPeachRampSkateboard";
  };

  outputs =
    inputs:
    let
      nixpkgs = inputs.mcEatBurg.nixpkgs;
      pkgs = inputs.mcEatBurg.pkgs;
      pkgsLib = inputs.peachRampSkateboard.pkgsLib;
      baseLib = inputs.peachRampSkateboard.baseLib;
    in
    {
      packages."x86_64-linux" = { };
    };
}
