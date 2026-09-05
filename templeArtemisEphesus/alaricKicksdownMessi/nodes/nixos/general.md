title: possible containerization choices
creationDate: 2026-09-04 03:39
body:
there are two options for packaging containers in NixOS: `nixos-container` and `dockerTools`. To export packages from a flake with `nixos-container`, you write nixos modules and then specify a `nixosConfigurations` output:
```
{
  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: {

    nixosConfigurations.container = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules =
        [ ({ pkgs, ... }: {
            boot.isContainer = true;

            networking.firewall.allowedTCPPorts = [ 80 ];

            services.httpd = {
              enable = true;
              adminAddr = "morty@example.org";
            };
          })
        ];
    };

  };
}
```
but for current immediate usecase, `pi` agents, the problem with this method is that the interface to run short-lived containers is a bit clumsy. Since there's no `ENTRYPOINT` analogue, you have to produce an analogous idiom using `systemd` services, and then pass the `pi` commands with `nixos-container run`. The `dockerTools` namespace allows you to use a declaring style similar to the one for dockerfiles, and I don't know exactly what the default base image is but it seems to be either NixOS or a barebones Linux equipped with `nix`.

One approach to make `nixos-container` work with a similar workflow is to parametrize `nixos-container create` by wrapping it in a script that generated a config file, which is then passed to `nixos-container create` with the `--config-file` flag.
--
title: short report about installing `lanchamarcou`
creationDate: 2026-09-05 00:31
body: In order to install NixOS on `lanchamarcou`, I took the following steps:
1. I prepared a nixos usb install.
1. I got access to a powershell by `Win+R`, ran powershell and pressed `Ctrl+Shift+Enter` to run it as admin. There I used the command `shutdown /fw /r` to reboot into the firmware config
2. In the firmware config, I disabled secure boot and put USB as the top priority for the boot sequence
3. After this the computer boots into a NixOS install (not sure if I needed to press F12 to get there). First, I connected to wifi with `nmtui`.
4. Then, I ran `lsblk -p` to modify the `disko` config on the thatWaterCharmander repo (attribute `disko.device.disk.main.device`) with the name of the main disk.
5. Ran `nix build github:nrs-status/newThatWaterCharmander#nixosConfigurations.lanchamarcou.config.system.build.destroyFormatMount` to obtain the script necessary to format the system. Ran it, then did `sudo nixos-rebuild --flake github:nrs-status/newThatWaterCharmander#lanchamarcou` to finalize the install.
