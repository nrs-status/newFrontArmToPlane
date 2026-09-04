{ pkgs, localPkgs, ... }:
pkgs.dockerTools.buildImage {
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

  runAsRoot = "mkdir -p /workspace";

  #llm-generated; the docs suggest the build process may fail due to permissions?
  fakeRootCommands = ''
    mkdir -p tmp root workspace usr
    chmod 1777 tmp
    chmod 700 root
    ln -sfn ../bin usr/bin
  '';

  config = {
    Env = [
      "PATH=/bin:/usr/bin"
      "HOME=/root" # emulating behaviour of `node:24-bookworm-slim` container
      "SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"
      "LOCALE_ARCHIVE=${pkgs.glibcLocales}/lib/locale/locale-archive"
    ];
    WorkingDir = "/workspace";
    Entrypoint = [ "${localPkgs.pi}" ];
  };
}
