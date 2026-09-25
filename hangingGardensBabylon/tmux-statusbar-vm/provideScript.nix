# builds the VM system for testing the tmux status bar change (bottom-most
# status bar without the session name).
#
# Mirrors hangingGardensBabylon/tmux-console-vm/provideScript.nix but points
# at *this* worktree's flake (so the locally modified tmux package is used).
# The vm.nix of tmux-console-vm is reused unchanged: it already mounts the
# host store, brings up the modified tmux on the VGA console (tty1) and
# keeps a root shell on the serial console.
#
# usage: nix build --impure -f ./provideScript.nix vm-script -o result-vm
rec {
  fatp = builtins.getFlake "git+file:///home/sieyes/baghdadPlane/flakes/newFrontArmToPlane.tmux-add-user-to-statusbar";
  nixos = import ../tmux-console-vm/vm.nix (
    fatp.outputs.localPkgsArgs // { localPkgs = fatp.outputs.packages.x86_64-linux; }
  );
  vm-script = nixos.config.system.build.vm;
}
