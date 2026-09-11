# Summary: Convert the pi-json service script from bash to Python

Goal: move the service logic defined inline in `templeArtemisEphesus/pi-vm/wservice.nix`
into a separate Python program, and verify that `run-pi-vm` still works.

## Steps

1. **Read the instructions** (`./instructions.txt`) and the existing code:
   - `templeArtemisEphesus/pi-vm/wservice.nix` (NixOS module defining the
     `pi-json` service as an inline `pkgs.writeShellApplication` bash script)
   - `templeArtemisEphesus/pi-vm/runWserviceVm.py` (host-side runner)
   - `templeArtemisEphesus/pi-vm/default.nix` and the top-level `flake.nix`

2. **Wrote the new Python program**
   `templeArtemisEphesus/pi-vm/wservicePiJson.py`, a faithful port of the bash
   script:
   - reads the prompt from the fw_cfg string `opt/pi/json-prompt` (stripping
     the trailing NUL/newlines like bash command substitution did)
   - provisions `/run/secrets/OPENROUTER_API_KEY` from the fw_cfg file
     `opt/pi/api-key` (NUL-stripped, whitespace-trimmed, mode 0600)
   - checks that the `pi-json` virtserialport exists, with the same
     diagnostics as before
   - parses the `opt/pi/mounts` manifest and mounts each 9p share (read-only
     ones with `ro`), tracking the `workdir` share, after `modprobe`ing
     `9pnet_virtio`/`9p`
   - `chdir`s into the workdir, runs `pi --mode json -p --no-session <prompt>`
     with stdout streamed into the virtserialport, then powers the VM off
     with `systemctl poweroff --no-block` and exits with pi's status

3. **Modified `templeArtemisEphesus/pi-vm/wservice.nix`**:
   - replaced the inline `writeShellApplication` with a small
     `pkgs.runCommand` that `substituteAll`s the Python file, injecting only
     the store paths of the binaries used (`pi`, `mount`, `modprobe`,
     `systemctl`) and the Python interpreter for the shebang
   - removed the now-unused `let` bindings (`fwCfgPromptRaw`, `fwCfgKeyRaw`,
     `vportName`, `vportDev`) since those paths now live in the Python file
   - trimmed the service `path`, keeping `bash`/`coreutils` (see step 5)

4. **Built the flake**: `nix build .#pi-vm.run-pi-vm` (after `git add`ing the
   new file so the flake source filter could see it). Verified the built
   `pi-json` script: all placeholders substituted, valid Python syntax.

5. **First end-to-end test failed**: the stream was empty. Temporarily added
   `journal+console` forwarding to the service config to see the guest journal
   on the host console. Diagnosis: `env: 'bash': No such file or directory` —
   the `pi` wrapper script is `#!/usr/bin/env bash`, and the original service
   `path` (which provided bash) had been removed. Fix: restored
   `bash`/`coreutils` to the service `path`, then removed the debug
   forwarding.

6. **Final verification runs** of `result/bin/run-pi-vm`:
   - Prompt `Reply with exactly: PI_JSON_SERVICE_OK`: the VM booted, the
     `pi-json` service read the prompt, provisioned the API key, mounted the
     9p workdir share, ran pi, and streamed the JSON events; the assistant's
     final message was exactly `PI_JSON_SERVICE_OK`; the VM powered off and
     the runner exited 0.
   - A second run with `-rw` and `-ro` shares also completed cleanly
     (exit 0, full JSON event stream).

7. **Wrote this `SUMMARY.md`** and sent a `notify-send` notification
   (including the git branch `pi-vm-run-script-iteration`).

## Result

- `templeArtemisEphesus/pi-vm/wservicePiJson.py` — new Python service program
- `templeArtemisEphesus/pi-vm/wservice.nix` — now imports that file instead of
  defining an inline bash script
- `run-pi-vm` verified working end-to-end after the change.
