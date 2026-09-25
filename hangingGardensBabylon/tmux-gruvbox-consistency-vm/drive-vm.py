#!/usr/bin/env python3
"""Drive the gruvbox-consistency VM and capture console screenshots.

Boots the VM headless with a QMP socket, waits for the autologin root shell
on the serial console, then captures QMP screendumps of the VGA console
(where tmux is attached on tty1) in every state of the reworked status bar:

  1. plain                      -> stats + date/time only
  2. taskmux done               -> bright-green DONE
  3. recording + done           -> red REC chip + DONE
  4. prefix armed (QMP C-a)     -> yellow PREFIX chip (+ REC + DONE)

The prefix is triggered through QEMU's emulated keyboard (QMP send-key), so
the `client_prefix' condition is exercised for real rather than faked.
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

SERIAL_LOG = "/tmp/vm-consistency-serial.log"
QMP_SOCK = "/tmp/tmux-consistency-vm-qmp.sock"
VM = os.path.join(BASE, "result-consistency-vm/bin/run-tmux-vm-vm")
OUTDIR = os.path.join(BASE, "screenshots")
os.makedirs(OUTDIR, exist_ok=True)

MAGICK = "/nix/store/1fj0wg21ba24hv612yg4kqwzxbnyappm-imagemagick-7.1.2-29/bin/magick"

# raw tmux client path from the built package's main.conf
TMUX_PKG = os.path.realpath(os.path.join(REPO, "result-tmux"))
with open(os.path.join(TMUX_PKG, "config", "main.conf")) as f:
    m = re.search(r"tmux=(\S+) (\S+tmux-status-taskmux-done\.sh)\)", f.read())
if not m:
    sys.exit("taskmux-done indicator script not found in main.conf")
RAW_TMUX = m.group(1)


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


def qmp(execute, arguments=None, sock=None):
    """Run one QMP command; a fresh connection is used when sock is None."""
    own = sock is None
    if own:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.connect(QMP_SOCK)
        f = sock.makefile("rw")
        json.loads(f.readline())  # greeting
        f.write(json.dumps({"execute": "qmp_capabilities"}) + "\n")
        f.flush()
        json.loads(f.readline())
    else:
        f = sock.makefile("rw")
    f.write(json.dumps({"execute": execute, "arguments": arguments or {}}) + "\n")
    f.flush()
    while True:
        resp = json.loads(f.readline())
        if "return" in resp or "error" in resp:
            if "error" in resp:
                raise RuntimeError(f"{execute} failed: {resp}")
            return resp


def qmp_screendump(fname):
    qmp("screendump", {"filename": fname})
    log(f"screendump {fname}")


def qmp_send_key(keys):
    qmp("send-key", {"keys": [{"type": "qcode", "data": k} for k in keys]})
    log(f"send-key {keys}")


# ---------------------------------------------------------------- start VM
log("starting VM")
os.environ["QEMU_OPTS"] = f"-qmp unix:{QMP_SOCK},server,nowait"
serial_log_file = open(SERIAL_LOG, "wb")
proc = subprocess.Popen([VM], stdin=subprocess.PIPE,
                        stdout=serial_log_file, stderr=subprocess.STDOUT)

shots = []
try:
    wait_for_log("root@tmux-vm")
    log("serial root shell is up")
    time.sleep(20)  # let tmux-console / attach / first status draw settle

    send("tmux display -p 'SESSID=#{session_name} STATUS=#{status}'")
    wait_for_log("SESSID=work", 60)
    log("tmux session work attached to the console")

    send("timeout 2 taskmux list </dev/null")
    wait_for_log(r"work: underway", 60)
    log("taskmux list shows the task underway")

    # ---------------------------------------------------- 1: plain status bar
    time.sleep(15)
    qmp_screendump("/tmp/vm-consistency-1.ppm")
    shots.append(("vm-consistency-1-plain", "/tmp/vm-consistency-1.ppm"))

    # ---------------------------------------------------- 2: DONE marker
    send("taskmux done work")
    send("timeout 2 taskmux list </dev/null")
    wait_for_log(r"work: done", 60)
    log("taskmux done work")
    time.sleep(15)
    qmp_screendump("/tmp/vm-consistency-2.ppm")
    shots.append(("vm-consistency-2-done", "/tmp/vm-consistency-2.ppm"))

    # ---------------------------------------------------- 3: + REC marker
    send("sleep 600 & echo $! > /tmp/voice-input-recording.pid")
    send("cat /tmp/voice-input-recording.pid")
    time.sleep(2)
    time.sleep(15)
    qmp_screendump("/tmp/vm-consistency-3.ppm")
    shots.append(("vm-consistency-3-done-rec", "/tmp/vm-consistency-3.ppm"))

    # --------------------------------------------- 4: + PREFIX marker (QMP)
    # focus the console VT first so the emulated keyboard reaches tmux
    qmp_send_key(["ctrl", "a"])
    time.sleep(2)
    qmp_screendump("/tmp/vm-consistency-4.ppm")
    shots.append(("vm-consistency-4-done-rec-prefix", "/tmp/vm-consistency-4.ppm"))

    # leave prefix mode
    qmp_send_key(["esc"])
    time.sleep(1)

    # -------------------------------------------------------------- shutdown
    send("poweroff")
    proc.wait(timeout=180)
    log("VM powered off")
finally:
    if proc.poll() is None:
        proc.kill()

# --------------------------------------------------------------- to PNG
for name, ppm in shots:
    subprocess.run([MAGICK, ppm, os.path.join(OUTDIR, f"{name}.png")], check=True)
    log(f"{name}.png written to {OUTDIR}")

log("DONE")
