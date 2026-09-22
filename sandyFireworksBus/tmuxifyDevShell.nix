inputs@{ pkgsLib, ... }:
{
  localPkgs,
  name,
  devShell,
  shell,
  shellArgs ? [ ], #extra args passed to `shell` (e.g. [ "-l" ])
  extraEnv ? { }, #extra env vars to export
}:
let
  shellAsScript = import ./shellScriptOfDevshell.nix inputs {
    inherit name shellArgs extraEnv;
    devshell = devShell;
    shell = shell;
  };
  tmux = localPkgs.tmux.override { defaultShell = pkgsLib.getExe shellAsScript; };
  sesh = localPkgs.sesh.override { inherit tmux; };
in
devShell.overrideAttrs (old: {
  buildInputs = old.buildInputs ++ [
    tmux
    sesh
  ];
  passthru = (old.passthru or { }) // {
    tmuxless = devShell;
  };
})
