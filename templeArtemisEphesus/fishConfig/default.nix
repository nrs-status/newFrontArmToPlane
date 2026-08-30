{ pkgs, ... }:
pkgs.stdenv.mkDerivation {
    name = "fishConfig";
    src = ./fishDefaultConfigFiles;
    installPhase = ''
      runHook preInstall

      mkdir -p $out/fish
      mkdir $out/fish/functions
      mkdir $out/fish/completions

      cp -r $src/* $out/fish

      install -Dm644 ${pkgs.writeText "workTrunkConfig.fish" (import ./workTrunkConfig.fish)} $out/fish/workTrunkConfig.fish
      install -Dm644 ${pkgs.writeText "zoxideConfig.fish" (import ./zoxideConfig.fish)} $out/fish/zoxideConfig.fish

      cat > $out/fish/config.fish <<EOF
      if status is-interactive
        source $out/fish/workTrunkConfig.fish
        source $out/fish/zoxideConfig.fish
      end
      EOF

      runHook postInstall
    '';
}
