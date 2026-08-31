{
  pkgs,
  localLib,
  pkgsLib,
  localPkgs,
  ...
}:
let
  keyReader = localLib.mkKeyReader {
    envVarName = "SOPS_AGE_KEY";
    keyPath = "/etc/keys.yaml";
  };
  configDirDrv = pkgs.stdenv.mkDerivation {
    name = "piConfigDir";
    phases = [ "installPhase" ]; # otherwise fails on unpackPhase
    src = ./staticConfigFiles;
    installPhase = ''
      runHook preInstall

      mkdir -p $out 
      cp $src/* $out

      runHook postInstall
    '';
  };
in
localLib.mkOptsAndEnvWrapperScript {
  name = "pi";
  pkgToWrap = pkgs.pi-coding-agent;
  runtimeInputs = [ keyReader configDirDrv localPkgs.scripts.decryptSecret localPkgs.secrets ];
  envVars = [
    {
      key = "PI_CODING_AGENT_DIR";
      value = configDirDrv;
    }
    {
      key = "PI_CODING_AGENT_SESSION_DIR";
      value = "~/.declaredDataDir/pi/sessions";
    }
  ];
  opts = [
    {
      dash = "--";
      optName = "provider";
      val = "openrouter";
    }
    {
      dash = "--";
      optName = "api-key";
      val = "$(SOPS_AGE_KEY=$(${pkgsLib.getExe keyReader}) ${pkgsLib.getExe localPkgs.scripts.decryptSecret} ${localPkgs.secrets}/secrets.yaml OPENROUTER_API_KEY)";
    }
    {
      dash = "--";
      optName = "model";
      val = "z-ai/glm-5.3-flash";
    }
  ];

}
