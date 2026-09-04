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
