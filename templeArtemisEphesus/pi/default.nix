{
  pkgs,
  localLib,
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
  ];
  opts = [
    {
      dash = "--";
      optName = "model";
      val = "openrouter/z-ai/glm-5.3-flash";
    }
  ];

}
