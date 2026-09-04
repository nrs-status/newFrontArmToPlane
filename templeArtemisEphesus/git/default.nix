{
  pkgs,
  localLib,
  ...
}:
let 
  gitConfig = pkgs.writeTextFile "git-config" (import ./config.nix { inherit pkgs; });
in
localLib.mkWrapperScript {
  name = "git";
  pkgToWrap = pkgs.git;
  preExecCommands = [
    "rm -f ~/.gitconfig"
    "cp ${gitConfig} ~/.config/git/config"
  ];
}
