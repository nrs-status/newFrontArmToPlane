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
        name: value: ''${name}=${value}
        export ${name}''
      ) envVars
    )}
    exec ${pkgsLib.getExe packageToWrap} "$@"
  '';
}
