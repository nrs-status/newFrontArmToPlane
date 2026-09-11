inputs: rec {
  bare = import ./bare.nix inputs;

  # new vm derived from `bare` via `extendModules`, adding one single new
  # service that calls `pi --mode json` with a string found in the vm's
  # /sys/firmware/qemu_fw_cfg and streams the output to a unix socket the
  # host can read
  wservice = import ./basic/wservice.nix inputs;

  # micro-VM variant of `wservice', built with the modules of the
  # github.com/microvm-nix/microvm.nix repository (see ./microvm/): same
  # purpose, same shared pi-json guest service (../wservicePiJson.py), same
  # fw_cfg/9p/virtio-serial protocol
  microvm-wservice = import ./microvm/wservice-microvm.nix inputs;

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
        substitute ${./basic/runWserviceVm.py} $out/bin/run-pi-vm \
          --subst-var-by vmScript ${vmScript}
        chmod +x $out/bin/run-pi-vm
        patchShebangs $out/bin/run-pi-vm
      '';

  # executable twin of `run-pi-vm' with the exact same capabilities and
  # behavior (JSON stream to stdout/-o, 9p shares, fw_cfg prompt and api
  # key, non-interactive serial console on stderr), except it runs the
  # micro-VM built by `microvm-wservice' via the microvm.nix runner
  # `microvm-run' (which picks up extra qemu options through the QEMU_OPTS
  # environment variable, see `microvm.extraArgsScript' in
  # ./microvm/wservice-microvm.nix)
  run-pi-microvm =
    let
      vmScript = "${(microvm-wservice { mountHostNixStore = true; }).config.microvm.declaredRunner}/bin/microvm-run";
    in
    inputs.pkgs.runCommand "run-pi-microvm"
      {
        nativeBuildInputs = [ inputs.pkgs.python3 ];
        meta.mainProgram = "run-pi-microvm";
      }
      ''
        mkdir -p $out/bin
        substitute ${./microvm/runWserviceMicrovm.py} $out/bin/run-pi-microvm \
          --subst-var-by vmScript ${vmScript}
        chmod +x $out/bin/run-pi-microvm
        patchShebangs $out/bin/run-pi-microvm
      '';
}
