# test harness for the wservice vm (same pattern as ./provideScript.nix but
# importing ./wservice.nix instead of ./bare.nix)
rec {
  fatp = builtins.getFlake "path:/home/sieyes/baghdad_plane/flakes/newFrontArmToPlane.wservice-key-to-fw_cfg-file-arg";
  nixos = import ../../irc-phoneFan/pi-vm/basic/wservice.nix (
    fatp.outputs.localPkgsArgs // { localPkgs = fatp.outputs.packages.x86_64-linux; }
  ) { mountHostNixStore = true; };
  vm-script = nixos.config.system.build.vm;
}