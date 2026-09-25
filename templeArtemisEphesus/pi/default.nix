{
  pkgs,
  localLib,
  newPkgs, # packages from the nasExitGiScorp flake input
  ...
}:
localLib.mkWrapperScript {
  name = "pi";
  pkgToWrap = pkgs.pi-coding-agent;
  src = ./.;
  preExecCommands = [
    "mkdir -p ~/.pi/agent"
    "rm -f ~/.pi/agent/auth.json"
    "install -m 600 $src/auth.json ~/.pi/agent/auth.json"
    "install -m 600 $src/models.json ~/.pi/agent/models.json"
    "install -m 600 $src/models-store.json ~/.pi/agent/models-store.json"
    # pi-openrouter-provider-plugin (from the nasExitGiScorp flake input):
    # install the extension into pi's global extension discovery directory.
    # Like the other files above, `install` overwrites in place on every run,
    # so repeated invocations are idempotent.
    "mkdir -p ~/.pi/agent/extensions"
    "install -m 644 ${newPkgs.pi-openrouter-provider-plugin}/share/pi/extensions/openrouter-provider.ts ~/.pi/agent/extensions/openrouter-provider.ts"
  ];
  opts = [
    {
      dash = "--";
      optName = "model";
      val = "openrouter/z-ai/glm-5.3-flash";
    }
  ];

}
