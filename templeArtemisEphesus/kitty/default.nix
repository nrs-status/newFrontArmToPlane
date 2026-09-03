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
  # kitty only recognizes its `+command` mode (e.g. `+runpy`) when it is the
  # first CLI argument, so options must be appended after "$@" instead of
  # prepended. Otherwise `kitty +runpy ...` silently launches a GUI instead.
  optsAfterArgs = true;
}
