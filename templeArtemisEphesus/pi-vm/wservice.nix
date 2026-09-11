# Creates a new VM from ./bare.nix (`import` + `extendModules`), adding exactly
# one single new service: `pi-json` (see the `wserviceModule` below).
#
# The service reads the contents of a string located in the vm's
# /sys/firmware/qemu_fw_cfg tree and calls `pi --mode json` with it, streaming
# pi's JSON event output to a unix socket the host can read.
#
# The fw_cfg string's contents are left undetermined here; they become
# available due to options passed to the qemu command line later, e.g.
#   -fw_cfg name=opt/pi/json-prompt,string=<contents>
#
# Because AF_UNIX sockets are kernel-local, the output stream crosses the VM
# boundary through a virtio-serial port, which the host's later qemu command
# line bridges to a host unix socket:
#   -chardev socket,id=pi-json,path=<host-socket>,server=on,wait=off
#   -device virtio-serial-pci
#   -device virtserialport,chardev=pi-json,name=pi-json
# The host then reads the stream by connecting a client to <host-socket>, e.g.
#   socat - UNIX-CONNECT:<host-socket>
# Note: qemu discards chardev writes made while no client is attached, so the
# host must connect promptly.
#
# The shared ~/.pi/agent/auth.json resolves the openrouter key through
# `! cat /run/secrets/OPENROUTER_API_KEY`; the service provisions it (mode
# 0600) from the optional fw_cfg file `opt/pi/api-key` if the host passed
# e.g. -fw_cfg name=opt/pi/api-key,file=<path-to-key-file>
#
# Host directories can be shared with the VM over 9p (the packaged runner
# `runWserviceVm' in ./default.nix, from ./runWserviceVm.py, wires all of
# this up): the host's qemu command line
# passes a tab-separated mounts manifest as the fw_cfg file opt/pi/mounts,
#
#   -fw_cfg name=opt/pi/mounts,file=<manifest>
#
# with one line per share: <workdir|rw|ro> <TAB> <mount tag> <TAB> <guest
# mountpoint>, and exposes each tag as a 9p share, e.g.
#
#   -fsdev local,id=pi-fs0,path=<host path>,security_model=none,readonly=off
#   -device virtio-9p-pci,fsdev=pi-fs0,mount_tag=pi-workdir
#
# The service below mounts each share (read-only ones with ro) and runs pi
# from the workdir share's guest mountpoint. When the pi-json service ends
# (pi finished, or it failed to start), the vm powers itself off, so a host
# runner reading the stream socket sees the stream end cleanly.
{
  nixosSystem,
  modulesPath,
  pkgs,
  localPkgs,
  ...
}:
{ mountHostNixStore }:
let
  # fw_cfg entries (contents decided by the host's later qemu command line):
  # - name=opt/pi/json-prompt,string=<contents>: prompt fed to `pi --mode json`
  # - name=opt/pi/api-key,file=<path-to-key-file>: (optional) provisions the
  #   guest's /run/secrets/OPENROUTER_API_KEY from a host file. A `file=`
  #   entry stores the file's exact bytes (no NUL terminator), unlike a
  #   `string=` entry; passing the key as a file also keeps it off the
  #   qemu command line, where it would be visible in `ps` output.
  fwCfgPromptRaw = "/sys/firmware/qemu_fw_cfg/by_name/opt/pi/json-prompt/raw";
  fwCfgKeyRaw = "/sys/firmware/qemu_fw_cfg/by_name/opt/pi/api-key/raw";

  # The virtserialport the service streams pi's JSON output into. The host's
  # later qemu command line must bridge it to a host unix socket (see header).
  vportName = "pi-json";
  vportDev = "/dev/virtio-ports/${vportName}";

  pi-json = pkgs.writeShellApplication {
    name = "pi-json";
    runtimeInputs = with pkgs; [ coreutils ];
    text = ''
      # Read the prompt from the qemu fw_cfg string the host passed later, e.g.
      #   -fw_cfg name=opt/pi/json-prompt,string=<contents>
      # (fw_cfg "string" entries are NUL-terminated; bash command substitution
      # strips the trailing NUL.)
      if ! prompt="$(cat ${fwCfgPromptRaw})"; then
        echo "pi-json: could not read the fw_cfg string at ${fwCfgPromptRaw}" >&2
        echo "pi-json: does the host qemu command line pass -fw_cfg name=opt/pi/json-prompt,string=<contents>?" >&2
        exit 1
      fi
      echo "pi-json: read prompt (''${#prompt} bytes) from ${fwCfgPromptRaw}" >&2

      # localPkgs.pi provisions it key with `! cat /run/secrets/OPENROUTER_API_KEY`; provision it from fw_cfg if
      # the host provided the key, e.g.
      #   -fw_cfg name=opt/pi/api-key,file=<path-to-key-file>
      # (a fw_cfg `file=` entry holds the file's exact bytes; strip any NULs
      # for good measure and drop a trailing newline with xargs)
      if [ ! -e /run/secrets/OPENROUTER_API_KEY ]; then
        mkdir -p /run/secrets
        if cat ${fwCfgKeyRaw} | tr -d '\0' | xargs printf '%s' > /run/secrets/OPENROUTER_API_KEY 2>/dev/null && [ -s /run/secrets/OPENROUTER_API_KEY ]; then
          chmod 600 /run/secrets/OPENROUTER_API_KEY
          echo "pi-json: provisioned /run/secrets/OPENROUTER_API_KEY from the opt/pi/api-key fw_cfg file" >&2
        else
          echo "pi-json: no openrouter key: /run/secrets/OPENROUTER_API_KEY is missing and no -fw_cfg name=opt/pi/api-key,file=<path-to-key-file> was given" >&2
        fi
      fi

      # The host's later qemu command line must bridge the `${vportName}`
      # virtserialport to a host unix socket:
      #   -chardev socket,id=${vportName},path=<host-socket>,server=on,wait=off
      #   -device virtio-serial-pci
      #   -device virtserialport,chardev=${vportName},name=${vportName}
      if [ ! -e ${vportDev} ]; then
        echo "pi-json: ${vportDev} is missing" >&2
        echo "pi-json: the host qemu command line must pass -chardev socket,id=${vportName},path=<host-socket>,server=on,wait=off -device virtio-serial-pci -device virtserialport,chardev=${vportName},name=${vportName}" >&2
        exit 1
      fi

      # Mount the host 9p shares named in the opt/pi/mounts manifest, if the
      # host provided one (see the header). Manifest lines are
      #   <workdir|rw|ro> <TAB> <mount tag> <TAB> <guest mountpoint>
      # with the host's qemu command line exposing each tag, e.g.
      #   -fsdev local,id=pi-fs0,path=<host path>,security_model=none,readonly=off
      #   -device virtio-9p-pci,fsdev=pi-fs0,mount_tag=pi-workdir
      manifest=/sys/firmware/qemu_fw_cfg/by_name/opt/pi/mounts/raw
      workdir=""
      if [ -e "$manifest" ]; then
        modprobe 9pnet_virtio >/dev/null 2>&1 || true
        modprobe 9p >/dev/null 2>&1 || true
        while IFS=$'\t' read -r mode tag mnt; do
          [ -n "$tag" ] || continue
          mkdir -p "$mnt"
          opts="trans=virtio,version=9p2000.L,msize=131072"
          if [ "$mode" = ro ]; then
            opts="''${opts},ro"
          fi
          if mount -t 9p -o "$opts" "$tag" "$mnt"; then
            echo "pi-json: mounted 9p share $tag (mode $mode) at $mnt" >&2
          else
            echo "pi-json: failed to mount 9p share $tag at $mnt" >&2
          fi
          if [ "$mode" = workdir ]; then
            workdir="$mnt"
          fi
        done < "$manifest"
      else
        echo "pi-json: no opt/pi/mounts fw_cfg entry: no host shares mounted" >&2
      fi

      # pi uses its current working directory as its working directory.
      if [ -n "$workdir" ]; then
        echo "pi-json: running pi from the workdir $workdir" >&2
        cd "$workdir"
      fi

      # Stream pi's JSON event output into the virtserialport; qemu forwards
      # it to the host unix socket. qemu discards chardev writes while no
      # client is attached to the host socket: the host must connect promptly.
      ${localPkgs.pi}/bin/pi --mode json -p --no-session "$prompt" > ${vportDev}
      rc=$?
      echo "pi-json: pi exited with status $rc; powering the VM off" >&2
      # This vm exists only to run pi on the fw_cfg prompt and stream its
      # output: once pi is done there is nothing left to do, so power off.
      # ( qemu then closes the stream socket and the host's runner sees EOF.)
      systemctl poweroff --no-block
      exit "$rc"
    '';
  };

  # The one single new service of this vm.
  wserviceModule =
    { lib, ... }:
    {
      # /sys/firmware/qemu_fw_cfg is exported by CONFIG_FW_CFG_SYSFS
      # (drivers/firmware/qemu_fw_cfg.c). Upstream Kconfig defaults it to `n`
      # and none of the NixOS kernel configs enable it either, so extend the
      # kernel packages with it.
      boot.kernelPackages = pkgs.linuxPackages.extend (
        _: super: {
          kernel = super.kernel.override {
            structuredExtraConfig = with lib.kernel; {
              FW_CFG_SYSFS = module;
              FW_CFG_SYSFS_CMDLINE = yes;
            };
          };
        }
      );

      boot.kernelModules = [ "qemu_fw_cfg" ];

      # qemu user networking (slirp) is IPv4-only, so AAAA answers are
      # unusable in the guest and pi's API calls fail with connection errors
      # when DNS prefers them; disable IPv6 in the guest.
      boot.kernel.sysctl."net.ipv6.conf.all.disable_ipv6" = true;
      boot.kernel.sysctl."net.ipv6.conf.default.disable_ipv6" = true;

      systemd.services.pi-json = {
        description = "pi-json: stream `pi --mode json` output to a unix socket the host can read";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        path = with pkgs; [
          bash
          coreutils
          kmod # modprobe 9p/9pnet_virtio for the 9p host shares
          systemd # systemctl poweroff when pi is done
          util-linux # mount for the 9p host shares
        ];
        environment.HOME = "/root";
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pi-json}/bin/pi-json";
          # pi stderr (prompt size, key provisioning, pi errors) stays visible
          # in the journal; pi stdout is streamed to the host unix socket.
          Restart = "no";
          # Whatever way this service ends (pi finished, fw_cfg missing, ...),
          # the vm has no reason to keep running: power it off so the host's
          # runner sees the end of the JSON stream (qemu closing the socket).
          ExecStopPost = "${pkgs.systemd}/bin/systemctl poweroff --no-block";
        };
      };
    };
in
(import ./bare.nix {
  inherit nixosSystem modulesPath pkgs localPkgs;
} { inherit mountHostNixStore; }).extendModules {
  modules = [ wserviceModule ];
}
