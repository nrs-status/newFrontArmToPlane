{
  pkgs,
  localLib,
  pkgsLib,
  localPkgs,
  ...
}:
let
  bashInterpolationToGetAPIKey = "\"$(SOPS_AGE_KEY=$(${pkgsLib.getExe keyReader}) ${pkgsLib.getExe localPkgs.scripts.decryptSecret} ${localPkgs.secrets}/secrets.yaml OPENROUTER_API_KEY)\"";
  keyReader = localLib.mkKeyReader {
    envVarName = "SOPS_AGE_KEY";
    keyPath = "/etc/keys.yaml";
  };
in
localLib.mkWrapperScript {
  name = "pi";
  pkgToWrap = pkgs.pi-coding-agent;
  runtimeInputs = [
    keyReader
    localPkgs.scripts.decryptSecret
    localPkgs.secrets
  ];
  envVars = [];
  opts = [
    {
      dash = "--";
      optName = "provider";
      val = "openrouter";
    }
    {
      dash = "--";
      optName = "api-key";
      val = bashInterpolationToGetAPIKey;
    }
    {
      dash = "--";
      optName = "model";
      val = "z-ai/glm-5.3-flash";
    }
  ];

}
