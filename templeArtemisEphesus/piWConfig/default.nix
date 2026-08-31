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
  authJsonFileContents = builtins.toJSON {
    openrouter = {
      type = "api_key";
      key = "!$(SOPS_AGE_KEY=$(${pkgsLib.getExe keyReader}) ${pkgsLib.getExe localPkgs.scripts.decryptSecret} ${localPkgs.secrets}/secrets.yaml OPENROUTER_API_KEY)";
    };
  };
  configDirDrv = pkgs.stdenv.mkDerivation {
    name = "piConfigDir";
    nativeBuildInputs = [
      keyReader
      localPkgs.scripts.decryptSecret
      localPkgs.secrets
    ];
    phases = [ "installPhase" ]; # otherwise fails on unpackPhase
    src = ./staticConfigFiles;
    installPhase = ''
      runHook preInstall

      mkdir -p $out 
      cp $src/* $out

      install -Dm644 ${pkgs.writeText "pi-harness-auth-json" authJsonFileContents} $out/auth.json

      runHook postInstall
    '';
  };
in
localLib.mkPrependWEnvVarsScript {
  name = "pi";
  pkgToWrap = pkgs.pi-coding-agent;
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

}
