{ pkgs, pkgsLib, ... }:
pkgs.stdenv.mkDerivation {
  name = "newsboat";
  src = ./.;
  nativeBuildInputs = [ pkgs.mkWrapper ];
  installPhase = ''runHook preInstall

  mkdir -p $out/bin
  cp ./urls $out/urls
  cp ./newsboat.config $out/newsboat.config

  makeWrapper ${pkgsLib.getExe pkgs.newsboat} $out/bin/newsboat \
    --add-flags "--url-file=$out/urls"
    --add-flags "--config-file=$out/newsboat.config"

  runHook postInstall'';
}
