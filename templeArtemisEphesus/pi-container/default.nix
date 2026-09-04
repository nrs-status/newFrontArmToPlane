{ pkgs, localPkgs, pkgsLib, ... }:
pkgs.dockerTools.buildLayeredImage {
  name = "simple-pi-container";
  tag = "nixos";
  maxLayers = 120; # for specificity
  contents = [
    pkgs.nodejs_24
    pkgs.bashInteractive
    pkgs.coreutils
    pkgs.git
    pkgs.ripgrep
    pkgs.cacert
    pkgs.gnugrep
    pkgs.gnused
    pkgs.findutils
    pkgs.which
    pkgs.glibcLocales # needed for `git` and more generally rendering/sorting filenames and terminal output
    localPkgs.pi
  ];


  #llm-generated; the docs suggest the build process may fail due to permissions?
  fakeRootCommands = ''
    mkdir -p tmp root workspace usr
    chmod 1777 tmp
    chmod 700 root
    ln -sfn ../bin usr/bin
    # `pi` resolves the `"! <command>"` api-key entries in auth.json via Node's
    # child_process.execSync, which spawns `/bin/sh -c <command>`. Without this
    # symlink the key cannot be read from /run/secrets inside the container.
    ln -sfn bash bin/sh
  '';

  config = {
    Env = [
      "PATH=/bin:/usr/bin"
      "HOME=/root" # emulating behaviour of `node:24-bookworm-slim` container
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt" 
      "LOCALE_ARCHIVE=${pkgs.glibcLocales}/lib/locale/locale-archive"
    ];
    WorkingDir = "/workspace";
    Entrypoint = [ "${pkgsLib.getExe localPkgs.pi}" ];
  };
}
