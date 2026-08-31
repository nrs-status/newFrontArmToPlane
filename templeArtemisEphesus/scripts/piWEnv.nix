{
  pkgs,
  pkgsLib,
  localLib,
  localPkgs,
  ...
}:
let
  keyReader = localLib.mkKeyReader {
    envVarName = "SOPS_AGE_KEY";
    keyPath = "/etc/keys.yaml";
  };
in
localLib.mkPrependWEnvVarsScript {
  scriptName = "pi";
  packageToWrap = pkgs.pi-coding-agent;
  runtimeInputs = [
    keyReader
    localPkgs.secrets
    localPkgs.scripts.decryptSecret
  ];
  envVars = [
    {
      key = "OPENROUTER_API_KEY";
      value = "$(SOPS_AGE_KEY=${pkgsLib.getExe keyReader} ${pkgsLib.getExe localPkgs.scripts.decryptSecret} ${localPkgs.secrets}/secrets.yaml OPENROUTER_API_KEY)";
    }
  ];

}
