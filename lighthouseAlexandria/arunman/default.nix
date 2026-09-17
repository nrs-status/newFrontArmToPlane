{
  pkgs,
  pkgsLib,
  localPkgs,
  ...
}:
# arunman: a CLI tool (Haskell) that runs pi microvm jobs configured in a
# nix flake's `runConfigs' attribute set and tracks every run in a
# postgresql `run' table (see ./SPEC.md). Internalized from the
# `run-manager.2' worktree; built with the repository's nixpkgs and wrapped
# so that it uses this flake's own `pi-vm.run-pi-microvm' runner and always
# has `nix' on PATH.
let
  arunmanHaskell = pkgs.haskellPackages.callCabal2nix "arunman" ./. { };
in
pkgs.runCommand "arunman"
  {
    nativeBuildInputs = [ pkgs.makeWrapper ];
    meta.mainProgram = "arunman";
  }
  ''
    mkdir -p $out/bin
    makeWrapper ${arunmanHaskell}/bin/arunman $out/bin/arunman \
      --set ARUNMAN_RUN_PI_MICROVM ${localPkgs.pi-vm.run-pi-microvm}/bin/run-pi-microvm \
      --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.nix ]}
  ''
