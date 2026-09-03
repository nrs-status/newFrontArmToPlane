{
  pkgs,
  localLib,
  ...
}:
# pkgs.stdenv.mkDerivation {
#   name = "pi";
#   src = ./.;
#   phases = [ "installPhase" ];
#   nativBuildInputs = [ pkgs.makeWrapper ];
#   installPhase = "runHook preInstall
#   runHook postInstall";
# }
localLib.mkWrapperScript {
  name = "pi";
  pkgToWrap = pkgs.pi-coding-agent;
  src = ./.;
  preExecCommands = [
    "rm -f ~/.pi/agent/auth.json"
    "cp $src/auth.json ~/.pi/agent/auth.json"
  ];
  opts = [
    {
      dash = "--";
      optName = "model";
      val = "openrouter/z-ai/glm-5.3-flash";
    }
  ];

}
