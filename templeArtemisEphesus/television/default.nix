{
  pkgs,
  pkgsLib,
  localLib,
  ...
}:
let
  configDir = pkgs.runCommand "television-config" { } ''
    mkdir -p $out/config $out/cable
    install -Dm644 ${./config.toml} $out/config/config.toml
    # bundle the upstream cable channels so tv can find them
    cp -r ${pkgs.television.src}/cable/* $out/cable/
  '';
in
localLib.mkWrapperScript {
  name = "television";
  pkgToWrap = pkgs.television;
  runtimeInputs = [ ];
  opts = [
    {
      dash = "--";
      optName = "config-file";
      val = "${configDir}/config/config.toml";
    }
    {
      dash = "--";
      optName = "cable-dir";
      val = "${configDir}/cable";
    }
  ];
}
