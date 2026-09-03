{
  pkgs,
  localPkgs,
  localLib,
  ...
}:
let
  fishConfig = pkgs.stdenv.mkDerivation {
    name = "fishConfig";
    src = ./.;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    fishScriptsDir = "${localPkgs.scripts.fishScripts}";
    installPhase = ''
      runHook preInstall

      mkdir -p $out
      mkdir $out/functions
      mkdir $out/completions

      cp -r fishDefaultConfigFiles $out

      install -Dm644 workTrunkConfig.fish $out/workTrunkConfig.fish
      install -Dm644 zoxideConfig.fish $out/zoxideConfig.fish
      install -Dm644 general.fish $out/general.fish

      cat > $out/config.fish <<EOF
      if status is-interactive
        source $out/general.fish
        source $out/workTrunkConfig.fish
        source $out/zoxideConfig.fish

        #note that local variables must be escaped for them to survive nix's expansion of `$` at build time
        for f in (ls "$fishScriptsDir" | sort)
          set -l path "$fishScriptsDir/\$f"
          if test -f "\$path"; and test -r "\$path"
            echo "Sourcing \$path"
            source "\$path"
          end
        end

      end
      EOF

      runHook postInstall
    '';
  };
in
  localLib.mkWrapperScript {
    name = "fish";
    pkgToWrap = pkgs.fish;
    preExecCommands = [
      "rm -rf ~/.config/fish"
      "cp -r ${fishConfig} ~/.config/fish/"
    ];
  }
