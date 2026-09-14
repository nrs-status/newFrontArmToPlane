{
  pkgs,
  pkgsLib,
  localLib,
  ...
}:
let
  # Wrap `himalaya` so it always uses the bundled example configuration,
  # overridable per-invocation by passing `--config` again (last flag wins).
  configDir = pkgs.runCommand "himalaya-config" { } ''
    mkdir -p $out
    install -Dm644 ${./config.toml} $out/config.toml
  '';
in
localLib.mkWrapperScript {
  name = "himalaya";
  pkgToWrap = pkgs.himalaya;
  runtimeInputs = [
    pkgs.pass # used by the example config's `backend.auth.cmd`
  ];
  opts = [
    {
      dash = "--";
      optName = "config";
      val = "${configDir}/config.toml";
    }
  ];
}
