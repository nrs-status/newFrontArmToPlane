# builds the VM system for testing the tmux taskmux-done indicator.
#
# Mirrors ../tmux-console-vm/provideScript.nix but imports
# ./vm-taskmux-done.nix, and additionally evaluates the *taskmux* flake
# (the nasExitGiScorp.taskmux-for-tmux work tree) so the guest can create
# and flip task states with the real `taskmux' commands.  The flakerefs
# use path: so the *dirty work trees* (uncommitted changes) are used,
# matching what is being tested.
#
# usage: nix build --impure -f ./provideScript.nix vm-script -o result-done-vm
rec {
  fatp = builtins.getFlake "path:/home/sieyes/baghdadPlane/flakes/newFrontArmToPlane.tmux-taskmux-done-indicator";
  taskmuxFlake = builtins.getFlake "path:/home/sieyes/baghdadPlane/flakes/nasExitGiScorp.taskmux-for-tmux";
  taskmuxPkg = taskmuxFlake.packages.x86_64-linux.scripts.taskmux;
  nixos = import ./vm-taskmux-done.nix (
    fatp.outputs.localPkgsArgs
    // {
      localPkgs = fatp.outputs.packages.x86_64-linux;
      inherit taskmuxPkg;
    }
  );
  vm-script = nixos.config.system.build.vm;
}