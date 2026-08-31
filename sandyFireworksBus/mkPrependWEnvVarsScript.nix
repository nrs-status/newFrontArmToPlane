{ pkgs, pkgsLib, ... }:
{
  pkgToWrap,
  envVars, # is a list in order to have a predictable ordering of the variable declarations in the outputted script
  runtimeInputs ? [ ],
}:
let
  renderedEnvVarDecls = pkgsLib.concatStringsSep "\n" (
    pkgsLib.concatMap (entry: [
      "${entry.key}=${entry.value}"
      "export ${entry.key}"
    ]) envVars
  );
in
pkgs.writeShellApplication {
  name = pkgToWrap.pname or (builtins.parseDrvName pkgToWrap.name).name;
  inherit runtimeInputs;
  text = ''
    ${renderedEnvVarDecls}
    exec ${pkgsLib.getExe pkgToWrap} "$@"
  '';
}
