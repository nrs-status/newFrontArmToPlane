{ pkgs, pkgsLib, ... }:
let
  fishConfig = pkgs.stdenv.mkDerivation {
    name = "fishConfig";
    src = ./.;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    installPhase = ''
      runHook preInstall

      mkdir -p $out/fish
      mkdir $out/fish/functions
      mkdir $out/fish/completions

      cp -r fishDefaultConfigFiles $out/fish

      install -Dm644 workTrunkConfig.fish $out/fish/workTrunkConfig.fish
      install -Dm644 zoxideConfig.fish $out/fish/zoxideConfig.fish
      install -Dm644 general.fish $out/fish/general.fish

      cat > $out/fish/config.fish <<EOF
      if status is-interactive
        source $out/fish/general.fish
        source $out/fish/workTrunkConfig.fish
        source $out/fish/zoxideConfig.fish
      end
      EOF

      runHook postInstall
    '';
  };
in
pkgs.writeShellApplication {
  name = "fish";
  text = "XDG_CONFIG_HOME=${fishConfig} ${pkgsLib.getExe pkgs.fish}";
}
