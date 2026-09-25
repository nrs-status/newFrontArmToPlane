#!/usr/bin/env python3
"""Drive the tmux taskmux-done-indicator VM:

* boot it with the serial console on stdio and a QMP unix socket
* wait for the autologin root shell on the serial console
* the tmux-console service created the session "work" and marked it
  "underway" with `taskmux start'
* verify over serial that the indicator script prints nothing while the
  task is only underway, and that `taskmux list' shows "underway"
* take QMP screendump #1 of the VGA console: no DONE marker left of the
  CPU/RAM/temperature stats
* flip the state with `taskmux done work' from the serial console
* verify over serial that the indicator now prints " DONE" and that
  `taskmux list' shows "work: done - ..."
* take QMP screendump #2: the green DONE marker is visible left of the
  CPU/RAM/temperature stats
* clear the task state with `taskmux clear work' and take screendump #3:
  the marker is gone again (proves the indicator is driven by the task
  state, not just stuck on)
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

SERIAL_LOG = "/tmp/vm-done-serial.log"
QMP_SOCK = "/tmp/tmux-done-vm-qmp.sock"
VM = os.path.join(REPO, "result-done-vm/bin/run-tmux-vm-vm")

# paths of the raw tmux client and the indicator script inside the tmux
# package (host == guest store path); taken from the built package's
# main.conf
TMUX_PKG = os.path.realpath(os.path.join(REPO, "result-tmux"))
with open(os.path.join(TMUX_PKG, "config", "main.conf")) as f:
    m = re.search(
        r"tmux=(\S+) (\S+tmux-status-taskmux-done\.sh)\)", f.read()
    )
if not m:
    sys.exit("taskmux-done indicator script not found in main.conf")
RAW_TMUX, DONE_SCRIPT = m.group(1), m.group(2)


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
    time.sleep(20)  # let tmux-console / attach / first status draw settle

    send("tmux display -p 'SESSID=#{session_name} STATUS=#{status}'")
    wait_for_log("SESSID=work", 60)
    log("tmux session work attached to the console")

    # indicator script prints nothing while the task is only underway
    send(f"tmux={RAW_TMUX} {DONE_SCRIPT}; echo RC=$?")
    wait_for_log(r"^RC=0$", 60)
    log("indicator silent while the task is underway")

    # taskmux list confirms the underway state
    send("timeout 2 taskmux list </dev/null")
    wait_for_log(r"work: underway - vm console task", 60)
    log("taskmux list shows: work: underway - vm console task")

    time.sleep(15)  # let the console + status bar (status-interval 5) redraw
    qmp_screendump("/tmp/vm-done-1.ppm")

    # ------------------------------------------------- mark done & shot 2
    send("taskmux done work")
    send("timeout 2 taskmux list </dev/null")
    wait_for_log(r"work: done - vm console task", 60)
    log("taskmux list shows: work: done - vm console task")

    send(f"tmux={RAW_TMUX} {DONE_SCRIPT}; echo RC=$?")
    wait_for_log(r"^DONE", 60)
    log('indicator prints DONE after taskmux done')

    time.sleep(15)  # >= 2x status-interval so the #(...) fragment re-runs
    qmp_screendump("/tmp/vm-done-2.ppm")

    # ---------------------------------------------------- clear & shot 3
    send("taskmux clear work")
    send(f"tmux={RAW_TMUX} {DONE_SCRIPT}; echo RC=$?")
    wait_for_log(r"^RC=0$", 60)
    log("indicator silent again after taskmux clear")
    time.sleep(15)
    qmp_screendump("/tmp/vm-done-3.ppm")

    # -------------------------------------------------------------- shutdown
    send("poweroff")
    proc.wait(timeout=180)
    log("VM powered off")
finally:
    if proc.poll() is None:
        proc.kill()

# --------------------------------------------------------------- to PNG
for name in ("vm-done-1", "vm-done-2", "vm-done-3"):
    subprocess.run(
        ["magick", f"/tmp/{name}.ppm", os.path.join(REPO, f"{name}.png")],
        check=True,
    )
    log(f"{name}.png written to repo root")

log("DONE")