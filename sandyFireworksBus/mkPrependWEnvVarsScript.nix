{ pkgs, pkgsLib, ... }:
{
  scriptName,
  packageToWrap,
  envVars,
  runtimeInputs ? [ ],
}:
pkgs.writeShellApplication {
  name = scriptName;
  inherit runtimeInputs;
  text = ''
    ${pkgsLib.concatStringsSep "\n" (
      pkgsLib.mapAttrsToList (
        name: value: "export ${name}=${value}"
      ) envVars
    )}
    exec ${pkgsLib.getExe packageToWrap} "$@"
  '';
}
