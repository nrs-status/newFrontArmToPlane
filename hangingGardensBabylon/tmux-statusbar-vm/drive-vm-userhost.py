#!/usr/bin/env python3
"""Drive the tmux-statusbar VM to verify the user@hostname status change:

* boot it with the serial console on stdio and a QMP unix socket
* wait for the autologin root shell on the serial console
* verify (over serial) that the gruvbox -z segment now shows "#(id -un)@#h"
  (i.e. the top bar's rightmost segment is user@hostname, not bare hostname)
* take QMP screendumps of the VGA console (where tmux is attached on tty1)
* power the VM off
"""
import json
import os
import re
import socket
import subprocess
import sys
import time

BASE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(BASE))  # repo root
os.chdir(BASE)

SERIAL_LOG = "/tmp/vm-serial.log"
QMP_SOCK = "/tmp/tmux-vm-qmp.sock"
VM = os.path.join(BASE, "result-vm/bin/run-tmux-vm-vm")
MAGICK = "/nix/store/1fj0wg21ba24hv612yg4kqwzxbnyappm-imagemagick-7.1.2-29/bin/magick"
OUTDIR = os.path.join(BASE, "screenshots")
os.makedirs(OUTDIR, exist_ok=True)


def log(msg):
    print(f"[drive] {msg}", flush=True)


def wait_for_log(pattern, timeout=300):
    rx = re.compile(pattern, re.MULTILINE)
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with open(SERIAL_LOG, "r", errors="replace") as f:
                if rx.search(f.read()):
                    return
        except FileNotFoundError:
            pass
        time.sleep(2)
    raise TimeoutError(f"pattern {pattern!r} not in serial log after {timeout}s")


def send(cmd):
    proc.stdin.write((cmd + "\n").encode())
    proc.stdin.flush()


def qmp_screendump(fname):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(QMP_SOCK)
    f = s.makefile("rw")
    json.loads(f.readline())  # greeting
    f.write(json.dumps({"execute": "qmp_capabilities"}) + "\n")
    f.flush()
    json.loads(f.readline())
    f.write(json.dumps({"execute": "screendump", "arguments": {"filename": fname}}) + "\n")
    f.flush()
    while True:
        resp = json.loads(f.readline())
        if "return" in resp or "error" in resp:
            if "error" in resp:
                raise RuntimeError(f"screendump failed: {resp}")
            break
    f.close()
    s.close()
    log(f"screendump {fname}")


# ---------------------------------------------------------------- start VM
log("starting VM")
os.environ["QEMU_OPTS"] = f"-qmp unix:{QMP_SOCK},server,nowait"
serial_log_file = open(SERIAL_LOG, "wb")
proc = subprocess.Popen(
    [VM],
    stdin=subprocess.PIPE,
    stdout=serial_log_file,
    stderr=subprocess.STDOUT,
)

try:
    # ------------------------------------------------- wait for boot & verify
    wait_for_log("root@tmux-vm")
    log("serial root shell is up")
    time.sleep(10)  # let tmux-console / attach settle

    # The gruvbox -z segment (rightmost piece of the TOP status bar) must
    # now be the user@hostname fragment, not the bare hostname default.
    send("echo ZOPT=$(tmux show -gqv @tmux-gruvbox-right-status-z)")
    wait_for_log(r"ZOPT=#\(id -un\)@#h", 120)
    log("gruvbox right-status-z = '#(id -un)@#h' confirmed in the VM")

    # The assembled status-right (rendered in the TOP bar, line 0) must
    # contain the fragment exactly once, and the bare '#h' default must be
    # gone from the -z position.
    send('echo SR=$(tmux show -gqv status-right | grep -c "id -un")')
    wait_for_log(r"SR=1", 120)
    log("assembled status-right contains the user@hostname fragment once")

    send("tmux list-windows -t work -F '#{session_name}: #{window_name}'")
    wait_for_log("work: bash", 120)
    log("session work with windows confirmed in the VM")

    time.sleep(10)  # let the console redraw
    qmp_screendump("/tmp/vm-shot1.ppm")

    # shot 2: nothing changed, just a second dump after more settle time
    time.sleep(5)
    qmp_screendump("/tmp/vm-shot2.ppm")

    # -------------------------------------------------------------- shutdown
    send("poweroff")
    proc.wait(timeout=180)
    log("VM powered off")
finally:
    if proc.poll() is None:
        proc.kill()

# --------------------------------------------------------------- to PNG
for name in ("vm-shot1", "vm-shot2"):
    subprocess.run(
        [MAGICK, f"/tmp/{name}.ppm", os.path.join(OUTDIR, f"{name}-userhost.png")],
        check=True,
    )
    log(f"{name}-userhost.png written to {OUTDIR}")

log("DONE")
