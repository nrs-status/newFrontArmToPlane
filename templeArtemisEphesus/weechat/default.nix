{
  pkgs,
  localLib,
  ...
}:
localLib.mkWrapperScript {
  name = "weechat";
  pkgToWrap = pkgs.weechat;
  src = ./.;
  preExecCommands = [
    "rm -f ~/.config/weechat"
    "cp $src/matrix.config $src/irc.config ~/.config/weechat"
  ];
}
