{ localPkgs, pkgsLib, ... }:
pkgsLib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    {
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
