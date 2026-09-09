{
  pkgs,
  localLib,
  ...
}:
# Packages broot wrapped with a basic configuration passed via `--conf`.
# broot normally reads its configuration from XDG_CONFIG_HOME/broot/conf.toml;
# pointing it at the bundled file keeps the user's real config dir untouched.
localLib.mkWrapperScript {
  name = "broot";
  pkgToWrap = pkgs.broot;
  runtimeInputs = [ ];
  opts = [
    {
      dash = "--";
      optName = "conf";
      val = "${./conf.toml}";
    }
  ];
}
