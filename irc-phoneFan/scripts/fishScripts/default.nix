{ pkgs, ... }:
pkgs.stdenv.mkDerivation {
  name = "fishScripts";
  src = ./.;
  phases = [ "installPhase" ];
  installPhase = ''
    runHook preInstall

      mkdir -p $out
      cp -r $src/*.fish $out

        runHook postInstall'';
}
