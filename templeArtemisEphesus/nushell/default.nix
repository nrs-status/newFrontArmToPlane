{
  pkgs,
  localLib,
  ...
}:
let
  # Git completions from nushell's official script collection, pinned to a
  # rev of https://github.com/nushell/nu_scripts (main as of 2026-08-25).
  # Provides `extern "git ..."` definitions so tab-completion works for
  # git subcommands, flags, remotes and branches.
  gitCompletions = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/nushell/nu_scripts/cee236cf46a597b43f36b56ccee5881fc0483c56/custom-completions/git/git-completions.nu";
    hash = "sha256-iXOvtQZCNLWfF+wGi+sL/VN5Ht3JFC5MtQNOtCrMW34=";
  };

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
    nativeBuildInputs = [ pkgs.zoxide ];
    installPhase = ''
      runHook preInstall

      mkdir -p $out

      # zoxide shell integration, generated at build time (analog of the
      # fish zoxideConfig.fish file)
      ${pkgs.zoxide}/bin/zoxide init nushell > $out/zoxideConfig.nu

      install -Dm644 general.nu $out/general.nu
      install -Dm644 workTrunkConfig.nu $out/workTrunkConfig.nu

      cat > $out/config.nu <<EOF
      # nushell entry point, generated at build time.
      # Note that nushell variables must be escaped (\$) for them to
      # survive bash's expansion of `$` in this unquoted heredoc at build time.

      \$env.config.show_banner = false

      source $out/general.nu
      source $out/workTrunkConfig.nu
      source $out/zoxideConfig.nu
      source ${nuScriptsDir}/start-llm-session.nu
<<<<<<< HEAD
      source ${gitCompletions}
||||||| parent of cb52e6f (adding various aliases and completions to `nu`)
=======

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
>>>>>>> cb52e6f (adding various aliases and completions to `nu`)
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
