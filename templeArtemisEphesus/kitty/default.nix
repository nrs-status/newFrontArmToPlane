{ pkgs, localLib, ... }:
localLib.mkWrapperScript {
  name = "kitty";
  pkgToWrap = pkgs.kitty;
  src = ./.;
  opts = [
    {
      dash = "--";
      optName = "config";
      val = "$src/kitty.conf";
    }
  ];
}
