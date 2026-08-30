{ pkgs, ... }:
pkgs.stdenv.mkDerivation {
    name = "fishConfig";
    src = ./resources;
    installPhase = ''
      runHook preInstall

      mkdir -p $out/fish
      mkdir $out/fish/functions
      mkdir $out/fish/completions

      cp -r $src/* $out/fish

      runHook postInstall
    '';
}
