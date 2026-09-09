{
  pkgs,
  localLib,
  ...
}:
let
  # Analog of `localPkgs.scripts.fishScripts`: a derivation holding the
  # nushell scripts sourced at runtime by the config.
  nuScriptsDir = pkgs.stdenv.mkDerivation {
    name = "nuScripts";
    src = ./nuScripts;
    phases = [ "installPhase" ];
    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp -r $src/*.nu $out

      runHook postInstall
    '';
  };

  nuConfig = pkgs.stdenv.mkDerivation {
    name = "nuConfig";
    src = ./.;
    nativeBuildInputs = [
      pkgs.zoxide
      pkgs.starship
    ];
    installPhase = ''
      runHook preInstall

      mkdir -p $out

      # zoxide shell integration, generated at build time (analog of the
      # fish zoxideConfig.fish file)
      ${pkgs.zoxide}/bin/zoxide init nushell > $out/zoxideConfig.nu

      # starship prompt integration, generated at build time
      ${pkgs.starship}/bin/starship init nu > $out/starshipInit.nu

      install -Dm644 general.nu $out/general.nu
      install -Dm644 workTrunkConfig.nu $out/workTrunkConfig.nu
      install -Dm644 starship.toml $out/starship.toml

      # nu modules `use`d by general.nu (relative paths must sit next to it)
      install -Dm644 nuScripts/jc.nu $out/jc.nu
      install -Dm644 nuScripts/result.nu $out/result.nu

      cat > $out/config.nu <<EOF
      # nushell entry point, generated at build time.
      # Note that nushell variables must be escaped (\$) for them to
      # survive bash's expansion of `$` in this unquoted heredoc at build time.

      \$env.config.show_banner = false

      source $out/general.nu
      source $out/workTrunkConfig.nu
      source $out/zoxideConfig.nu

      # starship prompt (config location set explicitly, since starship's
      # default would be ~/.config/starship.toml, outside this tree)
      \$env.STARSHIP_CONFIG = '$out/starship.toml'
      source $out/starshipInit.nu

      source ${nuScriptsDir}/start-llm-session.nu

      # aliases (vendored from github:nushell/nu_scripts)
      source ${nuScriptsDir}/eza-aliases.nu
      source ${nuScriptsDir}/bat-aliases.nu

      # custom completions (vendored from github:nushell/nu_scripts)
      source ${nuScriptsDir}/curl-completions.nu
      source ${nuScriptsDir}/podman-completions.nu
      source ${nuScriptsDir}/eza-completions.nu
      source ${nuScriptsDir}/nix-completions.nu
      source ${nuScriptsDir}/ssh-completions.nu
      source ${nuScriptsDir}/rg-completions.nu
      source ${nuScriptsDir}/tar-completions.nu
      source ${nuScriptsDir}/television-completions.nu
      source ${nuScriptsDir}/git-completions.nu

      EOF

      runHook postInstall
    '';
  };
in
  localLib.mkWrapperScript {
    name = "nushell";
    pkgToWrap = pkgs.nushell;
    preExecCommands = [
      "rm -rf ~/.config/nushell"
      "mkdir -p ~/.config/nushell"
      "cp -r ${nuConfig}/. ~/.config/nushell/"
      "chmod -R u+w ~/.config/nushell"
    ];
  }
