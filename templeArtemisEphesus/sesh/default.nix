{
  pkgs,
  pkgsLib,
  ...
}:
let
  mkSesh =
    { tmux }:
    pkgs.stdenv.mkDerivation {
      name = "sesh";
      nativeBuildInputs = [ pkgs.makeWrapper ];
      src = ./.;
      installPhase = ''
        runHook preInstall

        mkdir -p $out/bin $out/config

        install -Dm644 basic.toml $out/config

        cat > $out/config/main.toml <<EOF
        import = [
          "$out/config/basic.toml",
        ]
        EOF

        makeWrapper ${pkgsLib.getExe pkgs.sesh} $out/bin/sesh \
        --prefix PATH : ${pkgsLib.makeBinPath [ tmux ]} \
        --add-flags "--config $out/config/main.toml"

        runHook postInstall'';
    };
in
pkgsLib.makeOverridable mkSesh { tmux = pkgs.tmux; }
