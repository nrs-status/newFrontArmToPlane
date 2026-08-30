{ pkgs, ... }:
let fishConfigProper = pkgs.writeText {
  name = "fishConfigMainFile";
  text = import ./fishConfig.nix {};
}; in pkgs.stdenv.mkDerivation {
    name = "fishConfig";
    src = ./fishDefaultConfigFiles;
    installPhase = ''
      runHook preInstall

      cp -r $src/* $out

      install -Dm644 ${fishConfigProper} $out

      runHook postInstall
      '';
  }


