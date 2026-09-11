#!/usr/bin/env python3
"""Run the pi `wservice' VM (templeArtemisEphesus/pi-vm/basic/wservice.nix) and
stream its `pi --mode json' JSON event output to stdout or to a file.

The prompt fed to `pi' is read from stdin: pipe it in, or type it in a
terminal and finish with Ctrl-D.

Host directories are shared with the VM through qemu 9p shares:

  --workdir/-w        mounted read-write, used as pi's working directory
                      (default: a fresh /tmp/run-wservice-vm-<timestamp>-XXXX
                      directory whose name records when the program ran)
  --read-write/-rw    mounted read-write (repeatable)
  --read-only/-ro     mounted read-only (repeatable)

The 9p shares and the mount manifest (fw_cfg file `opt/pi/mounts') that the
guest service reads to mount them are set up here; see wservice.nix.

The JSON event stream crosses the VM boundary through a virtio-serial port
that qemu bridges to a host unix socket (-chardev socket,server=on,wait=off);
this program connects to that socket as soon as qemu starts listening and
forwards everything it receives to stdout or to --output/-o. qemu discards
chardev writes made while no client is attached, so the connect must happen
promptly (the guest's pi-json service only starts writing after boot, so
connecting within a second or two is safe).

The VM's serial console (kernel messages, getty) is non-interactive here: it
cannot take over the terminal the program is run from (the subprocess's stdin
is /dev/null, so there is no way to type into the VM's console shell); all of
its output is sent to this program's stderr. When the program finishes, it
also reports on stderr the host locations of all the paths that were passed
to it (via --workdir/-w, --read-write/-rw and --read-only/-ro) and shared
with the VM.

The host's /run/secrets/OPENROUTER_API_KEY, if it exists and is readable, is
passed to the VM through the fw_cfg file `opt/pi/api-key' (see wservice.nix).
"""

import argparse
import os
import socket
import subprocess
import sys
import tempfile
import time
from datetime import datetime

# Substituted at build time (see runWserviceVm.nix): the NixOS vm script of
# the wservice configuration, e.g. .../bin/run-pi-vm-vm. It execs qemu with
# extra options taken from the QEMU_OPTS environment variable.
VM_SCRIPT = "@vmScript@"

# fw_cfg names expected by the guest's pi-json service (see wservice.nix).
FW_CFG_PROMPT = "opt/pi/json-prompt"
FW_CFG_MOUNTS = "opt/pi/mounts"
FW_CFG_API_KEY = "opt/pi/api-key"
HOST_API_KEY_PATH = "/run/secrets/OPENROUTER_API_KEY"

# 9p mount tags and the guest mount points the pi-json service mounts them at.
TAG_WORKDIR = "pi-workdir"
GUEST_WORKDIR = "/mnt/workdir"
TAG_RW_FMT = "pi-rw-{0}"
GUEST_RW_FMT = "/mnt/rw-{0}"
TAG_RO_FMT = "pi-ro-{0}"
GUEST_RO_FMT = "/mnt/ro-{0}"

# How long to wait for qemu to start listening on the JSON stream socket.
SOCKET_CONNECT_TIMEOUT = 300


def fail(message):
    print(f"run-wservice-vm: {message}", file=sys.stderr)
    sys.exit(1)


def share_path(path, flag):
    """Validate and normalize a host path to be shared with the VM."""
    real = os.path.realpath(path)
    if not os.path.isdir(real):
        fail(f"{flag}: not a directory: {path}")
    # QEMU_OPTS is word-split by the VM's shell script, so paths with
    # whitespace would produce broken qemu command lines.
    if any(c.isspace() for c in real):
        fail(f"{flag}: path contains whitespace, which the VM start script "
             f"would split on: {path!r}")
    return real


def parse_args():
    parser = argparse.ArgumentParser(
        prog="run-wservice-vm",
        description="Run the pi wservice VM and stream its `pi --mode json' "
                    "JSON event output to stdout (or to a file with -o). "
                    "The prompt for pi is read from stdin.",
        epilog="Host directories are shared with the VM over 9p: --workdir "
               "read-write (pi's working directory), --read-write read-write, "
               "--read-only read-only.",
    )
    parser.add_argument(
        "-o", "--output", metavar="FILE",
        help="file the JSON stream is written to (default: stdout)",
    )
    parser.add_argument(
        "-w", "--workdir", metavar="DIR",
        default=None,
        help="host directory mounted read-write to the VM and used as pi's "
             "working directory (default: a fresh timestamped directory "
             "under /tmp, named after the time the program was run)",
    )
    parser.add_argument(
        "-rw", "--read-write", dest="read_write", metavar="PATH",
        action="append", default=[],
        help="host path mounted read-write to the VM (repeatable)",
    )
    parser.add_argument(
        "-ro", "--read-only", dest="read_only", metavar="PATH",
        action="append", default=[],
        help="host path mounted read-only to the VM (repeatable)",
    )
    return parser.parse_args()


def add_9p_share(qemu_opts, index, host_path, tag, read_only):
    qemu_opts += [
        "-fsdev",
        "local,id=pi-fs{0},path={1},security_model=none,readonly={2}".format(
            index, host_path, "on" if read_only else "off"),
        "-device",
        "virtio-9p-pci,fsdev=pi-fs{0},mount_tag={1}".format(index, tag),
    ]


def write_mounts_manifest(path, workdir, read_write, read_only):
    """One line per share: <workdir|rw|ro> <TAB> <mount tag> <TAB> <guest
    mountpoint>; parsed by the guest's pi-json service (see wservice.nix)."""
    lines = ["workdir\t{0}\t{1}".format(TAG_WORKDIR, GUEST_WORKDIR)]
    for i, _ in enumerate(read_write):
        lines.append("rw\t{0}\t{1}".format(TAG_RW_FMT.format(i),
                                           GUEST_RW_FMT.format(i)))
    for i, _ in enumerate(read_only):
        lines.append("ro\t{0}\t{1}".format(TAG_RO_FMT.format(i),
                                           GUEST_RO_FMT.format(i)))
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")


def connect_to_stream_socket(sock_path, vm_process, timeout):
    """Repeatedly try to connect to the chardev unix socket qemu listens on.
    Returns the connected socket, or None if qemu exited or the deadline
    passed."""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            sock.connect(sock_path)
            return sock
        except OSError:
            sock.close()
            if vm_process.poll() is not None:
                return None
            time.sleep(0.2)
    return None


def main():
    args = parse_args()

    if args.workdir is None:
        # Create the default workdir: a fresh directory under /tmp whose name
        # records the time at which this program was run.
        args.workdir = tempfile.mkdtemp(
            prefix="run-wservice-vm-{0}-".format(
                datetime.now().strftime("%Y%m%dT%H%M%S")),
            dir="/tmp",
        )
        print("run-wservice-vm: no --workdir given, using {0}".format(
            args.workdir), file=sys.stderr)

    workdir = share_path(args.workdir, "--workdir")
    read_write = [share_path(p, "--read-write") for p in args.read_write]
    read_only = [share_path(p, "--read-only") for p in args.read_only]

    with tempfile.TemporaryDirectory(prefix="run-wservice-vm-") as tmp:
        # qemu runs with cwd=tmp so its default ./pi-vm.qcow2 disk image and
        # other VM temp data stay out of the caller's directory.
        sock_path = os.path.join(tmp, "pi-json.sock")
        prompt_path = os.path.join(tmp, "prompt")
        manifest_path = os.path.join(tmp, "mounts-manifest")

        prompt = sys.stdin.buffer.read()
        if not prompt and sys.stdin.isatty():
            print("run-wservice-vm: type the prompt for pi and finish with "
                  "Ctrl-D", file=sys.stderr)
            prompt = sys.stdin.buffer.read()
        with open(prompt_path, "wb") as f:
            f.write(prompt)

        write_mounts_manifest(manifest_path, workdir, read_write, read_only)

        qemu_opts = []
        add_9p_share(qemu_opts, 0, workdir, TAG_WORKDIR, read_only=False)
        for i, host_path in enumerate(read_write):
            add_9p_share(qemu_opts, 1 + i, host_path, TAG_RW_FMT.format(i),
                         read_only=False)
        base = 1 + len(read_write)
        for i, host_path in enumerate(read_only):
            add_9p_share(qemu_opts, base + i, host_path, TAG_RO_FMT.format(i),
                         read_only=True)

        # Bridge the guest's pi-json virtserialport to a host unix socket
        # this program reads the JSON stream from (see wservice.nix).
        qemu_opts += [
            "-chardev",
            "socket,id=pi-json,path={0},server=on,wait=off".format(sock_path),
            "-device", "virtio-serial-pci",
            "-device", "virtserialport,chardev=pi-json,name=pi-json",
        ]

        # The prompt and the mounts manifest, read by the guest's pi-json
        # service from /sys/firmware/qemu_fw_cfg/by_name/<name>/raw.
        qemu_opts += [
            "-fw_cfg", "name={0},file={1}".format(FW_CFG_PROMPT, prompt_path),
            "-fw_cfg", "name={0},file={1}".format(FW_CFG_MOUNTS, manifest_path),
        ]

        # Openrouter key for the guest's /run/secrets/OPENROUTER_API_KEY.
        if os.path.isfile(HOST_API_KEY_PATH) and os.access(HOST_API_KEY_PATH,
                                                           os.R_OK):
            qemu_opts += [
                "-fw_cfg", "name={0},file={1}".format(FW_CFG_API_KEY,
                                                      HOST_API_KEY_PATH),
            ]
        else:
            print("run-wservice-vm: {0} not found or not readable: the VM "
                  "will run without an openrouter key".format(
                      HOST_API_KEY_PATH), file=sys.stderr)

        env = dict(os.environ, QEMU_OPTS=" ".join(qemu_opts))
        # The VM's serial console (kernel messages, getty) is sent entirely to
        # our stderr, and the console is non-interactive: the subprocess's
        # stdin is /dev/null, so running this program never drops the shell it
        # is run from into a shell inside the VM.
        vm_process = subprocess.Popen([VM_SCRIPT], cwd=tmp, env=env,
                                      stdin=subprocess.DEVNULL,
                                      stdout=sys.stderr, stderr=sys.stderr)

        exit_code = 0
        try:
            sock = connect_to_stream_socket(sock_path, vm_process,
                                            SOCKET_CONNECT_TIMEOUT)
            if sock is None:
                fail("could not connect to the VM's JSON stream socket at "
                     "{0}".format(sock_path))
            output = open(args.output, "wb") if args.output else \
                sys.stdout.buffer
            try:
                with sock, output:
                    while True:
                        chunk = sock.recv(65536)
                        if not chunk:
                            break
                        output.write(chunk)
                        output.flush()
            except BrokenPipeError:
                # e.g. the JSON output file's writer closed early (| head)
                pass
            exit_code = vm_process.wait()
        except KeyboardInterrupt:
            exit_code = 130
        finally:
            if vm_process.poll() is None:
                vm_process.terminate()
                try:
                    vm_process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    vm_process.kill()
                    vm_process.wait()
            # The program has finished executing: report on stderr the host
            # locations of the paths it was given and shared with the VM.
            print_host_paths(workdir, read_write, read_only)


def print_host_paths(workdir, read_write, read_only):
    """Report on stderr the host locations of the paths this program was
    given (options --workdir/-w, --read-write/-rw, --read-only/-ro) and
    shared with the VM."""
    print("run-wservice-vm: host locations of the paths passed to this "
          "program:", file=sys.stderr)
    print("run-wservice-vm:   workdir (read-write): {0}".format(workdir),
          file=sys.stderr)
    for path in read_write:
        print("run-wservice-vm:   read-write: {0}".format(path),
              file=sys.stderr)
    for path in read_only:
        print("run-wservice-vm:   read-only: {0}".format(path),
              file=sys.stderr)


if __name__ == "__main__":
    sys.exit(main())
