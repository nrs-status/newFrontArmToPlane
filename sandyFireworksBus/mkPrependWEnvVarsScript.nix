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
      pkgsLib.concatMap (
        entry: [
          ''${entry.key}=${entry.value}''
          "export ${entry.key}"
        ]
      ) envVars
    )}
    exec ${pkgsLib.getExe packageToWrap} "$@"
  '';
}
