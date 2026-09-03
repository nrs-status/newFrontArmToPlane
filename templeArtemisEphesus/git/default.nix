{
  pkgs,
  localLib,
  ...
}:
localLib.mkWrapperScript {
  name = "git";
  pkgToWrap = pkgs.git;
  src = ./.;
  preExecCommands = [
    "rm -f ~/.gitconfig"
    "cp $src/gitconfig ~/.gitconfig"
  ];
}
