# builds the VM system for testing the tmux battery widget.
#
# Mirrors ../tmux-console-vm/provideScript.nix but imports ./vm-battery.nix.
#
# usage: nix build --impure -f ./provideScript.nix vm-script -o result-battery-vm
rec {
  fatp = builtins.getFlake "git+file:///home/sieyes/baghdadPlane/flakes/newFrontArmToPlane.test-tmux-battery";
  nixos = import ./vm-battery.nix (
    fatp.outputs.localPkgsArgs // { localPkgs = fatp.outputs.packages.x86_64-linux; }
  );
  vm-script = nixos.config.system.build.vm;
}