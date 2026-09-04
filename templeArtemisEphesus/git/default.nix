{
  pkgs,
  localLib,
  ...
}:
let
  gitConfig = pkgs.writeText "git-config" (import ./config.nix { inherit pkgs; });
in
localLib.mkWrapperScript
  {
    name = "git";
    pkgToWrap = pkgs.git;
    preExecCommands = [
      "mkdir -p ~/.config/git/"
      "rm -rf ~/.config/git/config"
      "install -m 600 ${gitConfig} ~/.config/git/config"
    ];
  }
