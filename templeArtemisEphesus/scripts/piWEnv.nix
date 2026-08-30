{
  pkgs,
  pkgsLib,
  localLib,
  localPkgs,
  ...
}:
let
  keyReader = localLib.mkKeyReader {
    envVarName = "AGE_SOPS_KEY";
    keyPath = "/etc/keys.yaml";
  };
in
localLib.mkPrependWEnvVarsScript {
  scriptName = "pi";
  packageToWrap = pkgs.pi-coding-agent;
  runtimeInputs = [ keyReader localPkgs.scripts.decryptSecret ];
  envVars = {
    AGE_SOPS_KEY = "$(${pkgsLib.getExe keyReader})";
    OPENROUTER_API_KEY = "$(${pkgsLib.getExe localPkgs.scripts.decryptSecret} ${localPkgs.secrets} OPENROUTER_API_KEY)";
  };

}
