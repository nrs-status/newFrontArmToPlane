#!/usr/bin/env python3
"""Drive the tmux-battery VM:

* boot it with the serial console on stdio and a QMP unix socket
* wait for the autologin root shell on the serial console
* verify over serial that the fake battery (BAT0) exists and that
  status-stats.sh prints the BAT segment
* take QMP screendump #1 of the VGA console: "BAT 87%" (Discharging)
* flip BAT0 to Charging from the serial console, wait for the tmux
  status-interval to re-evaluate the widget
* take QMP screendump #2: "BAT +87%" (Charging) -- proves the widget is
  live and covers the "+" branch
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

SERIAL_LOG = "/tmp/vm-battery-serial.log"
QMP_SOCK = "/tmp/tmux-battery-vm-qmp.sock"
VM = os.path.join(REPO, "result-battery-vm/bin/run-tmux-vm-vm")

# path of the status-stats script inside the tmux package (host == guest
# store path); taken from the built package's main.conf
TMUX_PKG = os.path.realpath(os.path.join(REPO, "result-tmux"))
with open(os.path.join(TMUX_PKG, "config", "main.conf")) as f:
    m = re.search(r"interval=5 (/\S+-tmux-status-stats\.sh)", f.read())
if not m:
    sys.exit("status-stats script not found in main.conf")
STATS = m.group(1)


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

    send("ls /sys/class/power_supply/")
    wait_for_log(r"BAT0", 60)
    send("cat /sys/class/power_supply/BAT0/capacity /sys/class/power_supply/BAT0/status")
    wait_for_log(r"^87$", 60)
    wait_for_log(r"^Discharging$", 60)
    log("fake battery BAT0 present (87%, Discharging)")

    send(f"interval=0 {STATS}")
    wait_for_log(r"BAT 87%", 60)
    log("status-stats.sh prints the BAT segment in the guest")

    send("tmux display -p 'SESSID=#{session_name} STATUS=#{status}'")
    wait_for_log("SESSID=work", 60)
    log("tmux session work attached to the console")

    time.sleep(15)  # let the console + status bar (status-interval 5) redraw
    qmp_screendump("/tmp/vm-battery-1.ppm")

    # --------------------------------------------- flip to Charging & shot 2
    send("echo Charging > /sys/class/power_supply/BAT0/status")
    send("cat /sys/class/power_supply/BAT0/status")
    wait_for_log(r"^Charging$", 60)
    log("battery flipped to Charging")
    time.sleep(15)  # >= 2x status-interval so the #(...) job re-runs
    qmp_screendump("/tmp/vm-battery-2.ppm")

    # -------------------------------------------------------------- shutdown
    send("poweroff")
    proc.wait(timeout=180)
    log("VM powered off")
finally:
    if proc.poll() is None:
        proc.kill()

# --------------------------------------------------------------- to PNG
for name in ("vm-battery-1", "vm-battery-2"):
    subprocess.run(
        ["magick", f"/tmp/{name}.ppm", os.path.join(REPO, f"{name}.png")],
        check=True,
    )
    log(f"{name}.png written to repo root")

log("DONE")