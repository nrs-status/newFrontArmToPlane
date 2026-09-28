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
    # The updated extension is a package-style directory (package.json with a
    # "pi" manifest plus runtime node_modules), so the whole directory is
    # copied. Like the other files above, `cp -a -T` overwrites in place on
    # every run, so repeated invocations are idempotent. The single-file
    # layout of the previous extension version is removed to prevent the
    # extension from being loaded twice.
    "mkdir -p ~/.pi/agent/extensions"
    "rm -f ~/.pi/agent/extensions/openrouter-provider.ts"
    "rm -rf ~/.pi/agent/extensions/pi-openrouter-provider-plugin"
    "cp -a -T ${newPkgs.pi-openrouter-provider-plugin}/share/pi/extensions/pi-openrouter-provider-plugin ~/.pi/agent/extensions/pi-openrouter-provider-plugin"
    # the store copy is read-only; make the installed copy writable so the
    # `rm -rf` above can clean it up on the next (idempotent) invocation
    "chmod -R u+w ~/.pi/agent/extensions/pi-openrouter-provider-plugin"
  ];
  opts = [
    {
      dash = "--";
      optName = "model";
      val = "openrouter/z-ai/glm-5.3-flash";
    }
  ];

}
