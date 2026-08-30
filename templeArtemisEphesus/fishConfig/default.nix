{ pkgs, ... }:
pkgs.stdenv.mkDerivation {
    name = "fishConfig";
    src = ./fishDefaultConfigFiles;
    installPhase = ''
      runHook preInstall

      cp -r $src/* $out

      install -Dm644 ${pkgs.writeText "config.fish" (import ./fishConfig.nix)} $out

      runHook postInstall
      '';
  }


