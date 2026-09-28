# builds the VM system for testing the tmux-palette key-binding names.
#
# Same as ./provideScript.nix (the two-line-statusbar test VM) but points at
# *this* worktree's flake, so the VM runs the tmux package with the
# tmux-palette default-commands renamed to include their key bindings.
#
# usage: nix build --impure -f ./provideScript-palette.nix vm-script -o result-vm-palette
rec {
  fatp = builtins.getFlake "git+file:///home/sieyes/baghdadPlane/flakes/newFrontArmToPlane.tmux-palette-name-keybindings";
  nixos = import ./vm.nix (
    fatp.outputs.localPkgsArgs // { localPkgs = fatp.outputs.packages.x86_64-linux; }
  );
  vm-script = nixos.config.system.build.vm;
}
