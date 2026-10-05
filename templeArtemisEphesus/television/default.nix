{
  pkgs,
  pkgsLib,
  localLib,
  ...
}:
let
  # the cable channels to keep; every other upstream cable channel is removed
  # (television's compiled-in channels such as files, text, git-*, dirs are
  # unaffected by this and remain available)
  keptChannels = [
    "channels"
    "podman-containers"
    "podman-images"
    "podman-networks"
    "podman-volumes"
    "env"
    "journal"
    "procs"
    "ports"
    "recent-files"
    "ssh-hosts"
    "systemd-units"
    "tmux-sessions"
    "tmux-windows"
    "wifi"
  ];

  configDir = pkgs.runCommand "television-config" { } ''
    mkdir -p $out/config $out/cable
    install -Dm644 ${./config.toml} $out/config/config.toml
    # bundle the upstream cable channels so tv can find them
    cp -r ${pkgs.television.src}/cable/* $out/cable/
    # store paths are read-only; make writable so the removal below works
    chmod -R u+w $out/cable
    # keep only the whitelisted cable channels (all platform variants); removing
    # a channel's toml removes it from `tv list-channels`, the built-in
    # "channels" channel, and makes `tv <name>` fail with "Channel not found"
    find $out/cable -name '*.toml' ${pkgsLib.concatMapStringsSep " " (c: ''! -name "${c}.toml"'') keptChannels} -delete
  '';
in
localLib.mkWrapperScript {
  name = "tv";
  pkgToWrap = pkgs.television;
  runtimeInputs = [ ];
  opts = [
    {
      dash = "--";
      optName = "config-file";
      val = "${configDir}/config/config.toml";
    }
    {
      dash = "--";
      optName = "cable-dir";
      val = "${configDir}/cable";
    }
  ];
}
