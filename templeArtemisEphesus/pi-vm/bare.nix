#used as an environment to make it easier to write and test bash scripts for setting up the `pi` vm
{
  modulesPath,
  pkgs,
  localPkgs,
  pkgsLib,
  ...
}:
{ mountHostNixStore }:
pkgsLib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    "${modulesPath}/virtualisation/qemu-vm.nix"
    (
      if mountHostNixStore then
        {
          virtualisation.mountHostNixStore = true;
        }
      else
        { }
    )
    {
      networking.hostName = "pi-vm";
      system.stateVersion = "26.11";

      services.getty.autologinUser = "root";

      virtualisation.graphics = false;

      virtualisation = {
        memorySize = 2048;
        cores = 4;
        diskSize = 8192;
      };

      virtualisation.sharedDirectories.pi-config = {
        source = "/home/sieyes/.pi";
        target = "/root/.pi";
      };
      virtualisation.sharedDirectories.pi-project = {
        source = "\${PI_PROJECT_DIR}";
        target = "/root/project";
      };

      environment.systemPackages =
        with pkgs;
        [
          git
          vim
          xxd
        ]
        ++ [ localPkgs.pi ];

    }
  ];
}
