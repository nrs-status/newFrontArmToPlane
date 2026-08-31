{
  pkgs,
  localLib,
  pkgsLib,
  localPkgs,
  ...
}:
let
  bashInterpolationToGetAPIKey = "\"! $(SOPS_AGE_KEY=$(${pkgsLib.getExe keyReader}) ${pkgsLib.getExe localPkgs.scripts.decryptSecret} ${localPkgs.secrets}/secrets.yaml OPENROUTER_API_KEY)\"";
  keyReader = localLib.mkKeyReader {
    envVarName = "SOPS_AGE_KEY";
    keyPath = "/etc/keys.yaml";
  };
  jsonAuthFileContent = builtins.toJSON {
    openrouter = {
      type = "api_key";
      key = bashInterpolationToGetAPIKey;
    };
  };
  jsonFile = pkgs.writeText "json-auth-file" jsonAuthFileContent;
in
  pkgs.stdenv.mkDerivation {
    name = "pi";
    phases = [ "installPhase" ];
    nativeBuildInputs = [ jsonFile pkgs.makeWrapper ];
    installPhase = ''
      runHook preInstall

      makeWrapper ${pkgsLib.getExe pkgs.pi-coding-agent} $out/bin/pi \
        --run 'mkdir -p ~/.config/pi/agent' \
        --run 'cat ${jsonFile} > ~/.config/pi/agent/auth.json'

      runHook postInstall
      '';
  }
# localLib.mkOptsAndEnvWrapperScript {
#   name = "pi";
#   pkgToWrap = pkgs.pi-coding-agent;
#   runtimeInputs = [
#     keyReader
#     localPkgs.scripts.decryptSecret
#     localPkgs.secrets
#   ];
#   envVars = [];
#   opts = [
#     # {
#     #   dash = "--";
#     #   optName = "provider";
#     #   val = "openrouter";
#     # }
#     # {
#     #   dash = "--";
#     #   optName = "api-key";
#     #   val = bashInterpolationToGetAPIKey;
#     # }
#     # {
#     #   dash = "--";
#     #   optName = "model";
#     #   val = "z-ai/glm-5.3-flash";
#     # }
#   ];
#
# }
