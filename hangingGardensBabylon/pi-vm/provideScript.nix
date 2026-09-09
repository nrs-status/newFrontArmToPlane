rec {
  fatp = builtins.getFlake "github:nrs-status/newFrontArmToPlane";
  nixos = import ../../templeArtemisEphesus/pi-vm/bare.nix (
    fatp.outputs.localPkgsArgs // { localPkgs = fatp.outputs.packages.x86_64-linux; }
  ) { mountHostNixStore = true; };
  vm-script = nixos.config.system.build.vm;
}
