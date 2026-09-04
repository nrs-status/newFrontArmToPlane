#does not currently work
{
  pkgs,
  localLib,
  ...
}:
localLib.mkWrapperScript {
  name = "weechat";
  pkgToWrap = pkgs.weechat.override {
    configure =
      { availablePlugins, ... }:
      {
        plugins =
          builtins.attrValues (removeAttrs availablePlugins [ "php" ]) # copy/pasted from usual nixpkgs `configure` idiom
          ++ [
            { pluginFile = "${pkgs.weechat-matrix-rs}/lib/weechat/plugins/matrix.so"; }
          ];
      };
  };
  src = ./.;
  preExecCommands = [
    "rm -rf ~/.config/weechat"
    "mkdir -p ~/.config/weechat"
    "cp $src/irc.conf $src/matrix.conf ~/.config/weechat"
  ];
}
