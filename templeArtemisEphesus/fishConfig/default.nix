{ baseLib, pkgs, ... }:
baseLib.withDebug rec {
  fishConfigProper = pkgs.writeText "fishConfigMainFile" (import ./fishConfig.nix);
  __activateDebug = false;
  __output = pkgs.stdenv.mkDerivation {
    name = "fishConfig";
    src = ./fishDefaultConfigFiles;
    installPhase = ''
      runHook preInstall

      cp -r $src/* $out

      install -Dm644 ${fishConfigProper} $out

      runHook postInstall
    '';
  };
}
