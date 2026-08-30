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

      cat > $out/fish/config.fish <<EOF
      if status is-interactive
        source $out/fish/workTrunkConfig.fish
        source $out/fish/zoxideConfig.fish
      end
      EOF

      runHook postInstall
    '';
}
