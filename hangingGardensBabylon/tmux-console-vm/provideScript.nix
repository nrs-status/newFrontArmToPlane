# builds the VM system for testing the two-line tmux status bar.
#
# Mirrors hangingGardensBabylon/pi-vm/provideScript.nix but points at the
# *local* flake (so the local, modified tmux package is used) and imports
# ./vm.nix instead of the pi-vm bare.nix.
#
# usage: nix build --impure -f ./provideScript.nix vm-script -o result-vm
rec {
  fatp = builtins.getFlake "git+file:///home/sieyes/baghdadPlane/flakes/newFrontArmToPlane.two-line-statusbar";
  nixos = import ./vm.nix (
    fatp.outputs.localPkgsArgs // { localPkgs = fatp.outputs.packages.x86_64-linux; }
  );
  vm-script = nixos.config.system.build.vm;
}
