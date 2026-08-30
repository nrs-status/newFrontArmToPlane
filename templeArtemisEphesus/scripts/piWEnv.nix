{ pkgs, pkgsLib, localLib, localPkgs, ... }:
localLib.mkPrependWEnvVarsScript {
  scriptName = "pi";
  packageToWrap = [ pkgs.pi-coding-agent ];
  envVars = {
    AGE_SOPS_KEY = "$(${pkgsLib.getExe (localLib.mkKeyReader { envVarName = "AGE_SOPS_KEY"; keyPath = "/etc/keys.yaml";})})";  
    OPENROUTER_API_KEY = "$(${pkgsLib.getExe localPkgs.scripts.decryptSecret} ${localPkgs.secrets} OPENROUTER_API_KEY)";
  };

}
