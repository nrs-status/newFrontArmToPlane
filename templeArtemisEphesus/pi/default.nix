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
