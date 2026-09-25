#!/usr/bin/env python3
"""Drive the tmux-console VM:

* boot it with the serial console on stdio and a QMP unix socket
* wait for the autologin root shell on the serial console
* verify (over serial) that tmux runs with a two-line status bar
* take QMP screendumps of the VGA console (where tmux is attached on tty1)
* exercise the session (rename a window to something long, add a 4th window)
* take a second screendump, then power the VM off
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
VM = os.path.join(REPO, "result-vm/bin/run-tmux-vm-vm")


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

    send("tmux show -gv status")
    wait_for_log("^2$", 120)
    log("status = 2 (two-line status bar) confirmed in the VM")

    send("tmux list-windows -t work -F '#{session_name}: #{window_name}'")
    wait_for_log("work: bash", 120)
    log("session work with windows confirmed in the VM")

    time.sleep(10)  # let the console redraw
    qmp_screendump("/tmp/vm-shot1.ppm")

    # ------------------------------------------ exercise the session & shot 2
    send('tmux rename-window -t work:1 "a much longer window name"')
    send("tmux new-window -d -t work -n fourth")
    send("tmux select-window -t work:2")
    send("tmux send-keys -t work:2 'echo hello from the two-line status bar VM' Enter")
    send("tmux list-windows -t work -F '#{session_name}: #{window_name}'")
    wait_for_log("work: fourth", 120)
    time.sleep(10)
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
        ["magick", f"/tmp/{name}.ppm", os.path.join(REPO, f"{name}.png")],
        check=True,
    )
    log(f"{name}.png written to repo root")

log("DONE")
