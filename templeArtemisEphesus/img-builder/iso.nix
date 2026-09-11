# Builds a minimal, non-graphical NixOS installer ISO that:
#
#   - tries to connect to the given WiFi network at boot (wpa_supplicant
#     with the given ssid/psk), and
#   - sets the root password on the installer to the given password
#     (already hashed by the caller).
#
# It is a very simple extension of the official minimal installer
# (modules/installer/cd-dvd/installation-cd-minimal.nix) with exactly those
# two settings on top.
#
# Called by ./img-builder.sh as:
#
#   nix build -f iso.nix --argstr nixpkgsPath <path> --argstr wifiJson <path>
#
# where wifiJson is a JSON file of shape:
#
#   { "ssid": "...", "psk": "<hex pskRaw>", "hashedPassword": "..." }
#
{
  nixpkgsPath,
  wifiJson,
}: let
  wifi = builtins.fromJSON (builtins.readFile wifiJson);
  nixos = import (nixpkgsPath + "/nixos");
in
(nixos {
  configuration = {
    lib,
    modulesPath,
    ...
  }: {
    imports = ["${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"];

    # The stock installer uses NetworkManager for interactive WiFi setup
    # (nmtui).  We replace it with wpa_supplicant, which reads
    # networking.wireless.networks and automatically tries to connect to the
    # configured network at boot.
    networking.networkmanager.enable = lib.mkImageMediaOverride false;

    networking.wireless.enable = true;
    networking.wireless.networks = {
      "${wifi.ssid}" = {
        pskRaw = wifi.psk;
      };
    };

    # Set root's password on the installer (takes precedence over the empty
    # initialHashedPassword set by the installation-device profile).
    users.users.root.hashedPassword = wifi.hashedPassword;
  };
  system = "x86_64-linux";
})
.config.system.build.isoImage