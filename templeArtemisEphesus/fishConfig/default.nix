{ pkgs, ... }:
pkgs.stdenv.mkDerivation {
    name = "fishConfig";
    src = ./resources;
    installPhase = ''
      runHook preInstall

      mkdir $out
      mkdir $out/functions
      mkdir $out/completions

      cp -r $src/* $out

      runHook postInstall
    '';
}
