{ pkgs, localLib, ... }:
let
  kittyConf = pkgs.writeText "kitty-conf" (import ./conf.nix "${pkgs.kitty-themes}/share/kitty-themes/themes/gruvbox-dark.conf");
in
localLib.mkWrapperScript {
  name = "kitty";
  pkgToWrap = pkgs.kitty;
  opts = [
    {
      dash = "--";
      optName = "config";
      val = "${kittyConf}";
    }
  ];
}
