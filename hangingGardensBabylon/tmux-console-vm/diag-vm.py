#!/usr/bin/env python3
"""Boot the tmux-console VM and dump tmux status diagnostics over serial."""
import os
import subprocess
import sys
import time

BASE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(BASE))
os.chdir(BASE)

SERIAL_LOG = "/tmp/vm-serial.log"
QMP_SOCK = "/tmp/tmux-vm-qmp.sock"
VM = os.path.join(REPO, "result-vm/bin/run-tmux-vm-vm")

os.environ["QEMU_OPTS"] = f"-qmp unix:{QMP_SOCK},server,nowait"
serial_log_file = open(SERIAL_LOG, "wb")
proc = subprocess.Popen([VM], stdin=subprocess.PIPE, stdout=serial_log_file,
                        stderr=subprocess.STDOUT)

def send(cmd):
    proc.stdin.write((cmd + "\n").encode())
    proc.stdin.flush()

def wait_log(pattern, timeout=300):
    import re
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
    raise TimeoutError(pattern)

try:
    wait_log("root@tmux-vm")
    time.sleep(10)
    for cmd in [
        "tmux show -gv status-right",
        "tmux show -gv @tmux-gruvbox-right-status-x",
        "echo PATH=$PATH",
        "tmux display -p 'EXPANDED:#{T:status-right}'",
        "interval=1 /nix/store/g10kav2fjzfhakkjhagi49qm1q0c4msd-tmux-status-stats.sh; echo stats_exit=$?",
        "poweroff",
    ]:
        send(cmd)
        time.sleep(4)
    proc.wait(timeout=180)
finally:
    if proc.poll() is None:
        proc.kill()

with open(SERIAL_LOG, "r", errors="replace") as f:
    data = f.read()
import re
# strip ANSI escapes for readability
clean = re.sub(r"\x1b\[[0-9;?]*[a-zA-Z]|\x1b\][^\x07]*\x07|\x1b[()][0-9A-B]|\x1b[=>]|\r", "", data)
idx = clean.find("root@tmux-vm")
print(clean[idx:])
