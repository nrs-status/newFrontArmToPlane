{
  pkgs,
  localLib,
  ...
}:
let
  # weechat-matrix is not exposed via weechatScripts anymore in a form that
  # builds on python3.14: it depends on `future`, which is disabled for
  # python >= 3.13 in nixpkgs (PythonCharmers/python-future#640), even though
  # it imports fine. We build it against python3.14, overriding `future`'s
  # `pythonAtLeast` check so that it is allowed on 3.14.
  weechatMatrix = pkgs.python314Packages.callPackage (
    pkgs.path + "/pkgs/applications/networking/irc/weechat/scripts/weechat-matrix"
  ) {
    future = (pkgs.python314Packages.future.override {
      pythonAtLeast = _: false;
    }).overrideAttrs (_: {
      # future's `past.translation` module imports `lib2to3`, which was
      # removed from the stdlib in python 3.13+, so the default
      # pythonImportsCheck fails. weechat-matrix only uses `future.utils`
      # and `future.moves.itertools`, which import fine, so skip the check.
      pythonImportsCheck = [ ];
    });
  };
in
localLib.mkWrapperScript {
  name = "weechat";
  pkgToWrap = pkgs.weechat.override {
    # The python plugin is configured with the matrix
    # script's dependencies so that PYTHONHOME points to an interpreter
    # that can `import matrix` (and nio, logbook, future, ...).
    configure =
      { availablePlugins, ... }:
      {
        plugins = builtins.attrValues (removeAttrs availablePlugins [ "php" ]); # this is just a copy/paste of nixpkgs' `configure` code
        scripts = [ weechatMatrix ];
        init = "";
      };
  };
  src = ./.;
  preExecCommands = [
    "rm -rf ~/.config/weechat"
    "mkdir -p ~/.config/weechat"
    "cp $src/irc.conf $src/matrix.conf ~/.config/weechat"
  ];
}
