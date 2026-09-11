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

      # The shared ~/.pi/agent/auth.json resolves its openrouter key through
      # `! cat /run/secrets/OPENROUTER_API_KEY`; provision it from fw_cfg if
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

      # Stream pi's JSON event output into the virtserialport; qemu forwards
      # it to the host unix socket. qemu discards chardev writes while no
      # client is attached to the host socket: the host must connect promptly.
      exec ${localPkgs.pi}/bin/pi --mode json -p --no-session "$prompt" > ${vportDev}
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

      systemd.services.pi-json = {
        description = "pi-json: stream `pi --mode json` output to a unix socket the host can read";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        path = with pkgs; [
          bash
          coreutils
        ];
        environment.HOME = "/root";
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pi-json}/bin/pi-json";
          # pi stderr (prompt size, key provisioning, pi errors) stays visible
          # in the journal; pi stdout is streamed to the host unix socket.
          Restart = "no";
        };
      };
    };
in
(import ./bare.nix {
  inherit nixosSystem modulesPath pkgs localPkgs;
} { inherit mountHostNixStore; }).extendModules {
  modules = [ wserviceModule ];
}
