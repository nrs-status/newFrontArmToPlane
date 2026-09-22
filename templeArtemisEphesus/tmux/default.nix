{ pkgs, pkgsLib, ... }:
let
  mkTmux =
    { defaultShell }:
    pkgs.stdenv.mkDerivation {
      name = "tmux";
      src = ./.;
      nativeBuildInputs = [ pkgs.makeWrapper ];
      buildInputs = [ pkgs.tmux ];
      installPhase = ''
        runHook preInstall

        mkdir -p $out/bin $out/config

        install -Dm644 inheritedConf.conf $out/config
        install -Dm644 basic.conf $out/config


        cat > $out/config/main.conf <<EOF
          set -g default-shell ${defaultShell}
          source-file $out/config/basic.conf
          source-file $out/config/inheritedConf.conf
        EOF

        makeWrapper ${pkgsLib.getExe pkgs.tmux} $out/bin/tmux \
        --add-flags "-f $out/config/main.conf"

        runHook postInstall'';
    };
in
pkgsLib.makeOverridable mkTmux { defaultShell = pkgsLib.getExe pkgs.bash; }
