inputs: rec {
  bare = import ./bare.nix inputs;

  # new vm derived from `bare` via `extendModules`, adding one single new
  # service that calls `pi --mode json` with a string found in the vm's
  # /sys/firmware/qemu_fw_cfg and streams the output to a unix socket the
  # host can read
  wservice = import ./wservice.nix inputs;

  # executable that runs the `wservice' VM and streams its `pi --mode json'
  # JSON event output to stdout (or to a file with -o/-o FILE); shares host
  # directories with the VM over 9p (--workdir/-w, --read-write/-rw,
  # --read-only/-ro) and takes pi's prompt from stdin
  run-pi-vm =
    let
      vmScript = "${(wservice { mountHostNixStore = true; }).config.system.build.vm}/bin/run-pi-vm-vm";
    in
    inputs.pkgs.runCommand "run-pi-vm"
      {
        nativeBuildInputs = [ inputs.pkgs.python3 ];
        meta.mainProgram = "run-pi-vm";
      }
      ''
        mkdir -p $out/bin
        substitute ${./runWserviceVm.py} $out/bin/run-pi-vm \
          --subst-var-by vmScript ${vmScript}
        chmod +x $out/bin/run-pi-vm
        patchShebangs $out/bin/run-pi-vm
      '';
}
