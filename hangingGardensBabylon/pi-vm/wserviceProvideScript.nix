# test harness for the wservice vm (same pattern as ./provideScript.nix but
# importing ./wservice.nix instead of ./bare.nix)
rec {
  fatp = builtins.getFlake "path:/home/sieyes/baghdad_plane/flakes/newFrontArmToPlane.add-pi-service-to-pi-vm";
  nixos = import ../../templeArtemisEphesus/pi-vm/wservice.nix (
    fatp.outputs.localPkgsArgs // { localPkgs = fatp.outputs.packages.x86_64-linux; }
  ) { mountHostNixStore = true; };
  vm-script = nixos.config.system.build.vm;
}