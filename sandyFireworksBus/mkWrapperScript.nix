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
    installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    cat > $out/bin/${name} <<'EOF'
    #!/usr/bin/env bash
    ${renderedEnvVarDecls}
    ${renderedPreExecCommands}
    exec ${pkgsLib.getExe pkgToWrap} ${renderedOpts} "$@"
    EOF

    chmod +x $out/bin/${name}

    # The heredoc above uses a quoted delimiter (<<'EOF'), so bash does NOT
    # expand `$src` while the wrapper is generated. As a result the literal
    # string `$src` would end up in the wrapper script and be unset at
    # runtime. It is expanded here to prevent this
    ${pkgsLib.optionalString (src != null) ''
      substituteInPlace $out/bin/${name} --replace-fail '$src' "$src"
    ''}

    runHook postInstall'';
  }
# pkgs.writeShellApplication {
#   inherit name runtimeInputs;
#   text = ''
#     ${renderedEnvVarDecls}
#     ${renderedPreExecCommands}
#     exec ${pkgsLib.getExe pkgToWrap} ${renderedOpts} "$@"'';
# }
