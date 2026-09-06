#used as an environment to make it easier to write and test bash scripts for setting up the `pi` vm
{ modulesPath, pkgs, localPkgs, pkgsLib, ... }:
pkgsLib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    "${modulesPath}/virtualisation/qemu-vm.nix"
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

      environment.systemPackages = with pkgs; [
        pi-coding-agent
        git
        vim
        xxd
      ];

      systemd.services.main = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        environment = {
          HOME = "/root";
        };
        serviceConfig = {
          remainAfterExit = false;
          WorkingDirectory = "/root/project";
          script = ''
                           
                                     raw=/sys/firmware/qemu_fw_cfg/by_name/opt/null.org/pi.openrouter_api_key/raw
                         if [[ ! -f $raw ]]; then
                           echo "no fw_cfg secret present TODO: FIGURE OUT HOW TO EXIT EARLY HERE"
                           exit 0
                           fi
                       OPENROUTER_API_KEY="$(tr -d '\0\n' < "$raw")"

            exec ${pkgsLib.getExe localPkgs.pi} -p -- "$(tr -d '\0\n' < /sys/firmware/qemu_fw_cfg/by_name/opt/com.example/pi.prompt/raw)"       
          '';
        };
      };
    }
  ];
}
