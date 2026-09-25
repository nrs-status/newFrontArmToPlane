#!/usr/bin/env python3
"""Drive the tmux-statusbar VM to verify the two-digit-year date change:

* boot it with the serial console on stdio and a QMP unix socket
* wait for the autologin root shell on the serial console
* verify (over serial) that the gruvbox -x segment now uses the strftime
  two-digit year (%y) instead of the four-digit one (%Y)
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

    # The gruvbox -x segment (the date piece of the TOP status bar) must
    # now use the two-digit year (%y) instead of the four-digit one (%Y).
    # Grep for both specifiers so the check is independent of everything
    # else in the fragment (taskmux-done / stats / #[default] bits).
    send("echo X4=$(tmux show -gqv @tmux-gruvbox-right-status-x | grep -c '%Y-%m-%d')")
    wait_for_log(r"X4=0", 120)
    log("four-digit year %Y-%m-%d is gone from the date segment")

    send("echo X2=$(tmux show -gqv @tmux-gruvbox-right-status-x | grep -c '%y-%m-%d')")
    wait_for_log(r"X2=1", 120)
    log("two-digit year %y-%m-%d is in the date segment")

    # The rendered status bar must show the date with a two-digit year:
    # tmux expands the format with strftime, so
    #   tmux display-message -p '#{T:status-right}'  (via -p to stdout)
    # contains e.g. "25-09-25"; check the expanded status-right contains
    # a two-digit-year date and NOT a four-digit one.
    send('echo EXP=$(tmux display-message -p -F "#{T;=/200:status-right}" | grep -oE "[0-9]{2}-[0-9]{2}-[0-9]{2}|[0-9]{4}-[0-9]{2}-[0-9]{2}")')
    wait_for_log(r"EXP=[0-9]{2}-[0-9]{2}-[0-9]{2}$", 120)
    log("rendered status bar shows a two-digit-year date")

    send("tmux list-windows -t work -F '#{session_name}: #{window_name}'")
    wait_for_log("work: bash", 120)
    log("session work with windows confirmed in the VM")

    time.sleep(10)  # let the console redraw
    qmp_screendump("/tmp/vm-shot1.ppm")

    # shot 2: nothing changed, just a second dump after more settle time
    # (the status bar refreshes every 5s; take the second dump after one
    # refresh so the date segment is confirmed stable in both shots)
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
        [MAGICK, f"/tmp/{name}.ppm", os.path.join(OUTDIR, f"{name}-2digityear.png")],
        check=True,
    )
    log(f"{name}-2digityear.png written to {OUTDIR}")

log("DONE")
