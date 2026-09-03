{ pkgs, pkgsLib, ... }:
{
  name,
  pkgToWrap,
  src ? null,
  opts ? [],
  envVars ? [],
  preExecCommands ? [],
  runtimeInputs ? [],
}:
let
  renderOpt =
    {
      dash,
      optName,
      val ? null,
    }:
    let
      flag = "${dash}${optName}";
    in
    assert pkgsLib.assertMsg (
      dash == "-" || dash == "--"
    ) "mkOptionsFeederScript: the argument `dash` must be either \"-\" or \"--\"";
    if val == null then flag else flag + " " + val;
  renderedOpts = pkgsLib.concatMapStringsSep " " renderOpt opts;
  renderedEnvVarDecls = pkgsLib.concatStringsSep "\n" (
    pkgsLib.concatMap (entry: [
      "${entry.key}=${entry.value}"
      "export ${entry.key}"
    ]) envVars
  );
  renderedPreExecCommands = pkgsLib.concatStringsSep "\n" preExecCommands;
in
  pkgs.stdenv.mkDerivation {
    inherit name runtimeInputs src;
    phases = [ "installPhase" ];
    installPhase = ''runHook preInstall

    cat $out/bin/${name} <<EOF
     ${renderedEnvVarDecls}
     ${renderedPreExecCommands}
     exec ${pkgsLib.getExe pkgToWrap} ${renderedOpts} "$@"
    EOF

    runHook postInstall'';
  }
# pkgs.writeShellApplication {
#   inherit name runtimeInputs;
#   text = ''
#     ${renderedEnvVarDecls}
#     ${renderedPreExecCommands}
#     exec ${pkgsLib.getExe pkgToWrap} ${renderedOpts} "$@"'';
# }
