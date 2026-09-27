# builds the VM system for testing the M+ scratchpad popup.
#
# Same shape as ../tmux-console-vm/provideScript.nix, but points at *this*
# checkout of the flake (the tmux-scratchpad branch) so the VM runs the
# locally-built tmux package with the scratchpad binding.
#
# usage: nix build --impure -f ./provideScript.nix vm-script -o result-vm
rec {
  fatp = builtins.getFlake "git+file:///home/sieyes/baghdadPlane/flakes/newFrontArmToPlane.tmux-scratchpad";
  nixos = import ./vm.nix (
    fatp.outputs.localPkgsArgs // { localPkgs = fatp.outputs.packages.x86_64-linux; }
  );
  vm-script = nixos.config.system.build.vm;
}
