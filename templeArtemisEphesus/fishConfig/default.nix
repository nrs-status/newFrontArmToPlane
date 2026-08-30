{ pkgs, ... }:
let fishConfigProper = pkgs.writeTextFile {
  name = "fishConfigMainFile";
  text = import ./fishConfig.nix;
}; in pkgs.stdenv.mkDerivation {
    name = "fishConfig";
    src = ./fishDefaultConfigFiles;
    installPhase = ''
      runHook preInstall

      cp -r $src/* $out

      install -Dm644 ${pkgs.writeText "config.fish" fishConfigProper} $out

      runHook postInstall
      '';
  }


