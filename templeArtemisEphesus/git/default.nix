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
    "rm -f ~/.gitconfig"
    "cp $src/.gitconfig ~/.gitconfig"
  ];
}
