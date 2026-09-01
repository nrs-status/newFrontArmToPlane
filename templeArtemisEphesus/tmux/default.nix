{ pkgs, pkgsLib, ... }:
pkgs.stdenv.mkDerivation {
  name = "tmux";
  src = ./.;
  nativeBuildInputs = [ pkgs.makeWrapper ];
  buildInputs = [ pkgs.tmux ];
  installPhase = ''
  runHook preInstall

  mkdir -p $out/bin $out/config

  install -Dm644 inheritedConf.conf $out/config

  cat > $out/config/main.conf <<EOF
    source-file $out/config/inheritedConf.conf
  EOF

  makeWrapper ${pkgsLib.getExe pkgs.tmux} $out/bin/tmux \
  --add-flags "-f $out/config/main.conf"
  
  runHook postInstall'';
}
