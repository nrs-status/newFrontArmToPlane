{ pkgs, pkgsLib, localPkgs, ... }:
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

  # sesh starts a tmux server (`tmux new-session`) when the requested session
  # does not exist yet. It must therefore resolve `tmux` to the *wrapped*
  # `localPkgs.tmux` and not to the bare `pkgs.tmux`: only the wrapper passes
  # `-f main.conf`, which is what loads `basic.conf` (`extended-keys on`,
  # `extended-keys-format csi-u`). With the unwrapped tmux on PATH the server
  # starts without that config, so `Shift+Enter` collapses to plain `Enter`
  # inside `pi` (see templeArtemisEphesus/tmux/basic.conf).
  makeWrapper ${pkgsLib.getExe pkgs.sesh} $out/bin/sesh \
  --prefix PATH : ${pkgsLib.makeBinPath [ localPkgs.tmux ]} \
  --add-flags "--config $out/config/main.toml"

  runHook postInstall'';
}
