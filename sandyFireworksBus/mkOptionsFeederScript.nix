{ pkgs, pkgsLib, ... }:
{
  name,
  pkgToWrap,
  opts,
  runtimeInputs,
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
  renderedOpts = pkgsLib.concatMapStringSep " " renderOpt opts;
in
pkgs.writeShellApplication {
  inherit name runtimeInputs;
  text = ''exec ${pkgsLib.getExe pkgToWrap} ${renderedOpts} "$@"'';
}
