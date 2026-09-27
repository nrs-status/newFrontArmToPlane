#!/usr/bin/env python3
"""Drive the tmux-scratchpad VM:

* boot it with the serial console on stdio and a QMP unix socket
* wait for the autologin root shell on the serial console
* verify over serial that tmux has the console-only M+ binding
* press M+ with QMP send-key (real console keypresses: alt+shift+equal)
* take QMP screendumps of the VGA console (where tmux is attached on tty1)
* exercise the full scratchpad workflow: open, type, close, reopen, state
  persistence, escape-close, exit-respawn
* verify server-side state over serial after every step
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
VM = os.path.join(REPO, "result-vm/bin/run-tmux-vm-vm")

RESULTS = []


def log(msg):
    print(f"[drive] {msg}", flush=True)


def check(name, cond, detail=""):
    RESULTS.append((name, bool(cond)))
    log(("PASS: " if cond else "FAIL: ") + name + (f" ({detail})" if detail and not cond else ""))


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
        time.sleep(1)
    raise TimeoutError(f"pattern {pattern!r} not in serial log after {timeout}s")


def send(cmd):
    proc.stdin.write((cmd + "\n").encode())
    proc.stdin.flush()


def qmp(cmdline):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(QMP_SOCK)
    f = s.makefile("rw")
    json.loads(f.readline())  # greeting
    f.write(json.dumps({"execute": "qmp_capabilities"}) + "\n")
    f.flush()
    json.loads(f.readline())
    resp = None
    f.write(cmdline + "\n")
    f.flush()
    while True:
        r = json.loads(f.readline())
        if "return" in r or "error" in r:
            resp = r
            break
    f.close()
    s.close()
    return resp


def qmp_screendump(fname):
    r = qmp(json.dumps({"execute": "screendump", "arguments": {"filename": fname}}))
    if "error" in r:
        raise RuntimeError(f"screendump failed: {r}")
    log(f"screendump {fname}")


def press_mplus():
    """real console keypress: Alt+Shift+Equal (Meta plus)"""
    r = qmp(json.dumps({"execute": "send-key", "arguments": {"keys": [
        {"type": "qcode", "data": "alt"},
        {"type": "qcode", "data": "shift"},
        {"type": "qcode", "data": "equal"},
    ]}}))
    if "error" in r:
        raise RuntimeError(f"send-key failed: {r}")


def type_text(text):
    """type literal characters + Enter as individual console keypresses"""
    keymap = {
        " ": "spc", "-": "minus", ".": "dot", "/": "slash", ">": "shift, dot",
        "=": "equal", "_": "shift, minus", "\n": "ret", "$": "shift, dot",
        "'": "apostrophe", '"': "shift, apostrophe", "*": "shift, minus",
        "!": "shift, minus", "|": "shift, backslash", ";": "semicolon",
        ":": "shift, semicolon", "(": "shift, 9", ")": "shift, 0",
        "&": "shift, 7", "%": "shift, 5", "#": "shift, 3", "@": "shift, 2",
        "~": "shift, grave_accent", "`": "grave_accent", "\\": "backslash",
        "+": "shift, equal", ",": "comma", "<": "shift, comma", "?": "shift, slash",
    }
    for ch in text:
        if ch.isupper():
            name = "shift, " + ch.lower()
        elif ch.isalpha() or ch.isdigit():
            name = ch
        elif ch in keymap:
            name = keymap[ch]
        else:
            raise RuntimeError(f"no key mapping for char {ch!r}")
        keys = [{"type": "qcode", "data": n.strip()} for n in name.split(",")]
        qmp(json.dumps({"execute": "send-key", "arguments": {"keys": keys}}))
        time.sleep(0.02)


def serial_check(marker, cmd, expect, timeout=60):
    """run a command over serial and check its output contains expect"""
    log(f"serial: {cmd}")
    send(f"echo {marker}-START; {cmd}; echo {marker}-END")
    try:
        wait_for_log(f"{marker}-END", timeout)
        with open(SERIAL_LOG, "r", errors="replace") as f:
            chunk = f.read()
        m = re.search(re.escape(f"{marker}-START") + r"\n(.*?)" + re.escape(f"{marker}-END"),
                      chunk, re.DOTALL)
        out = m.group(1) if m else ""
        check(marker, expect in out, f"expected {expect!r} got {out[-300:]!r}")
    except TimeoutError as e:
        check(marker, False, str(e))


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
    time.sleep(12)  # let tmux-console / attach settle

    serial_check("S1", "tmux list-sessions -F '#{session_name}'", "work")
    serial_check("S2", "tmux list-keys | grep -F 'M-+'", "M-+")

    time.sleep(3)
    qmp_screendump("/tmp/vm-shot0.ppm")

    # ------------------------------------------------- open the scratchpad
    log("pressing M+ (open)")
    press_mplus()
    time.sleep(4)
    qmp_screendump("/tmp/vm-shot1.ppm")
    serial_check("S4", "tmux list-clients -t scratchpad -F '#{client_name}'", "/dev/")
    serial_check("S6", "tmux show -t scratchpad status", "status off")

    # ------------------------------------------------- type into the popup
    log("typing into the popup")
    type_text("echo SCRATCH-OK > /tmp/scratch-marker && cd /tmp\n")
    time.sleep(2)
    qmp_screendump("/tmp/vm-shot2.ppm")
    serial_check("S7", "cat /tmp/scratch-marker", "SCRATCH-OK")

    # ------------------------------------------------- close the scratchpad
    log("pressing M+ (close)")
    press_mplus()
    time.sleep(3)
    qmp_screendump("/tmp/vm-shot3.ppm")
    serial_check("S8", "tmux list-clients -t scratchpad 2>/dev/null | wc -l", "0")
    serial_check("S9", "tmux has-session -t scratchpad && echo alive", "alive")

    # ------------------------------------------------- focus returns: work pane
    type_text("echo BACK-OK > /tmp/back-marker\n")
    time.sleep(2)
    serial_check("S11", "cat /tmp/back-marker", "BACK-OK")

    # ------------------------------------------------- reopen: state persists
    log("pressing M+ (reopen)")
    press_mplus()
    time.sleep(4)
    type_text("pwd > /tmp/pwd-marker && echo HIST-OK >> /tmp/scratch-marker\n")
    time.sleep(2)
    qmp_screendump("/tmp/vm-shot4.ppm")
    serial_check("S12", "cat /tmp/pwd-marker", "/tmp")
    serial_check("S13", "cat /tmp/scratch-marker", "SCRATCH-OK\nHIST-OK")

    # ------------------------------------------------- escape goes to the shell
    # NB: with an attach popup, Escape is delivered to the scratchpad
    # shell (so it works inside programs run there, e.g. vim) and does
    # NOT close the popup; the toggle key is the close mechanism.
    log("pressing Escape (goes to the shell, popup stays)")
    qmp(json.dumps({"execute": "send-key", "arguments": {"keys": [
        {"type": "qcode", "data": "esc"}]}}))
    time.sleep(3)
    qmp_screendump("/tmp/vm-shot5.ppm")
    serial_check("S14", "tmux list-clients -t scratchpad 2>/dev/null | wc -l", "1")
    serial_check("S15", "tmux has-session -t scratchpad && echo alive", "alive")

    # ------------------------------------------------- M+ closes it again
    log("pressing M+ (close after escape)")
    press_mplus()
    time.sleep(3)
    serial_check("S15b", "tmux list-clients -t scratchpad 2>/dev/null | wc -l", "0")

    # ------------------------------------------------- single press reopens
    log("pressing M+ (reopen after escape)")
    press_mplus()
    time.sleep(4)
    serial_check("S16", "tmux list-clients -t scratchpad -F '#{client_name}'", "/dev/")

    # ------------------------------------------------- exit respawns fresh
    log("typing exit in the popup")
    time.sleep(2)  # let the fresh attach settle (first keypress can be eaten)
    type_text("\n")
    time.sleep(0.5)
    type_text("exit\n")
    time.sleep(3)
    serial_check("S17", "tmux has-session -t scratchpad 2>/dev/null && echo alive || echo gone", "gone")
    serial_check("S17b", "tmux list-clients -t scratchpad 2>/dev/null | wc -l", "0")
    qmp_screendump("/tmp/vm-shot6.ppm")

    log("pressing M+ (fresh session after exit)")
    press_mplus()
    time.sleep(4)
    qmp_screendump("/tmp/vm-shot7.ppm")
    serial_check("S18", "tmux has-session -t scratchpad && echo alive", "alive")
    serial_check("S19", "cat /tmp/pwd-marker", "/tmp")  # old marker untouched

    # -------------------------------------------------------------- shutdown
    send("poweroff")
    proc.wait(timeout=180)
    log("VM powered off")
finally:
    if proc.poll() is None:
        proc.kill()

# --------------------------------------------------------------- results
npass = sum(1 for _, ok in RESULTS if ok)
print(f"[drive] RESULT: {npass}/{len(RESULTS)} checks passed", flush=True)
for name, ok in RESULTS:
    print(f"[drive]   {'PASS' if ok else 'FAIL'} {name}", flush=True)

# --------------------------------------------------------------- to PNG
for name in ("vm-shot0", "vm-shot1", "vm-shot2", "vm-shot3", "vm-shot4",
             "vm-shot5", "vm-shot6", "vm-shot7"):
    subprocess.run(
        ["convert", f"/tmp/{name}.ppm", f"/tmp/{name}.png"],
        check=False,
    )

sys.exit(0 if npass == len(RESULTS) else 1)
