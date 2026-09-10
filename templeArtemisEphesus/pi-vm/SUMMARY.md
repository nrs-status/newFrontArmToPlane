# SUMMARY: testing the `wservice.nix` VM (`pi-json` service)

Goal: verify that the VM declared at `./wservice.nix` (derived from `./bare.nix`
via `extendModules`) works. It must contain exactly one new service, `pi-json`,
which reads a string from the guest's `/sys/firmware/qemu_fw_cfg/` tree, feeds
it to `pi --mode json`, and streams the JSON event output to a unix socket the
host can read.

## Steps undertaken

1. **Explored the repo layout.** `pi-vm/default.nix` exposes `bare` and
   `wservice` (both take `{ mountHostNixStore }`). The existing test harness
   pattern lives in `hangingGardensBabylon/pi-vm/` (`provideScript.nix`,
   `run.sh`): it imports `wservice.nix` with the flake's `localPkgsArgs` and
   provides `vm-script = nixos.config.system.build.vm`, run via
   `nix run -f ./wserviceProvideScript.nix vm-script` with `QEMU_OPTS`.

2. **Created the test harness**
   `hangingGardensBabylon/pi-vm/wserviceProvideScript.nix` (same pattern as
   `provideScript.nix`, but importing `./wservice.nix` and pointing
   `builtins.getFlake "path:..."` at this worktree so uncommitted changes are
   used).

3. **Built the VM**: `nix build --impure -f ./wserviceProvideScript.nix
   vm-script --print-out-paths`. The build succeeded on the first try; the
   extra kernel config (`CONFIG_FW_CFG_SYSFS=m`,
   `CONFIG_FW_CFG_SYSFS_CMDLINE=y`) triggered a kernel rebuild that completed
   fine. Verified `CONFIG_VIRTIO_CONSOLE=m` is present in the guest kernel.

4. **Ran the VM** with the qemu options that supply the (previously
   undetermined) fw_cfg strings and bridge the virtserialport to a host unix
   socket:

   ```
   SHARED_DIR=$PWD/workspace/ \
   QEMU_OPTS="-fw_cfg name=opt/pi/json-prompt,file=/tmp/pi-prompt.txt \
              -fw_cfg name=opt/pi/api-key,file=/run/secrets/OPENROUTER_API_KEY \
              -chardev socket,id=pi-json,path=/tmp/pi-json-test.sock,server=on,wait=off \
              -device virtio-serial-pci \
              -device virtserialport,chardev=pi-json,name=pi-json" \
   nix run -f ./wserviceProvideScript.nix vm-script
   ```

   where `/tmp/pi-prompt.txt` contains
   `Reply with exactly this text and nothing else: IT WORKS`.

5. **Connected a client to the host unix socket** from the host
   (`/tmp/pi-json-test.sock`; `socat` was unavailable, so a small python
   `socket.AF_UNIX` client was used) and captured the stream to
   `/tmp/pi-out.json`.

6. **Verified the results** — everything worked without needing any change to
   `./wservice.nix`:
   - the `pi-json` service started on boot,
   - it read the prompt from
     `/sys/firmware/qemu_fw_cfg/by_name/opt/pi/json-prompt/raw`,
   - it provisioned `/run/secrets/OPENROUTER_API_KEY` (mode 0600) from the
     `opt/pi/api-key` fw_cfg entry, which made the shared
     `/root/.pi/agent/auth.json` (`! cat /run/secrets/OPENROUTER_API_KEY`)
     resolve,
   - `pi --mode json -p --no-session` ran with the fw_cfg prompt and its JSON
     event stream (`session`, `agent_start`, `turn_start`, `message_start`,
     `message_end`, `turn_end`, `agent_end`, `agent_settled`, ...) arrived on
     the host unix socket,
   - the assistant's reply captured on the host was exactly `IT WORKS`.

7. **Cleaned up**: killed the test qemu process.

## Conclusion

`./wservice.nix` satisfies the required constraint as-is (one single new
service, `pi-json`, calling `pi --mode json` with a fw_cfg string and streaming
the output to a unix socket the host can read, bridged over a virtserialport).
No configuration changes were necessary; only the test harness file above was
added.