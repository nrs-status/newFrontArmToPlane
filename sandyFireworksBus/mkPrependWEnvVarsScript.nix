{ pkgs, pkgsLib, ... }:
{ scriptName, packageToWrap, envVars }:
pkgs.writeShellApplication {
  name = scriptName;
  text = ''
  ${pkgsLib.concatStringsSep "\n" (
    pkgsLib.mapAttrsToList (name: value: "export ${name}=${pkgsLib.escapeShellArg (toString value)}") envVars
  )}
  exec ${pkgsLib.getExe packageToWrap} "$@"
  '';
}
