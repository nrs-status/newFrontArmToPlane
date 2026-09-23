{ pkgs, localLib, ... }:
let
  kittyConf = pkgs.writeText "kitty-conf" (import ./conf.nix {
    gruvboxDarkConfig = "${pkgs.kitty-themes}/share/kitty-themes/themes/gruvbox-dark.conf";
    inherit pkgs;
  });
in
pkgs.lib.makeOverridable
  (
    { optsAfterArgs ? true }:
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
      # first CLI argument, so by default options are appended after "$@" instead
      # of prepended. Otherwise `kitty +runpy ...` silently launches a GUI instead.
      #
      # Note the trade-off: appending also means that any positional argument
      # (e.g. `kitty bash`) receives the trailing `--config <conf>` as *its own*
      # argument, since kitty's parser stops at the first positional and passes
      # the rest to the child program. Callers that launch programs this way can
      # override the wrapper with `.override { optsAfterArgs = false; }`, which
      # prepends the options so they reach kitty itself.
      inherit optsAfterArgs;
    }
  )
  { }
