# builds the VM system used to visually check the gruvbox-consistent tmux
# status bar (stats / DONE / REC / PREFIX) on the Linux console.
#
# usage: nix build --impure -f ./provideScript.nix vm-script -o result-consistency-vm
rec {
  fatp = builtins.getFlake "path:/home/sieyes/baghdadPlane/flakes/newFrontArmToPlane.gruvbox-consistency";
  taskmuxFlake = builtins.getFlake "path:/home/sieyes/baghdadPlane/flakes/nasExitGiScorp";
  taskmuxPkg = taskmuxFlake.packages.x86_64-linux.scripts.taskmux;
  nixos = import ./vm.nix (
    fatp.outputs.localPkgsArgs
    // {
      localPkgs = fatp.outputs.packages.x86_64-linux;
      inherit taskmuxPkg;
    }
  );
  vm-script = nixos.config.system.build.vm;
}
