#!/usr/bin/env python3
"""scan-and-connect.py — locate the lanchamarcou NixOS machine on the LAN and
connect to it over SSH.

Steps:
  1. detect the local /24 subnet (from the default route)
  2. parallel ping sweep to find live hosts
  3. identify the target by MAC address, or by probing for an SSH banner
  4. connect over SSH: key auth (installed system: plat2548) or password auth
     via SSH_ASKPASS (live ISO: nixos)

Usage:
  ./scan_and_connect.py                  # interactive SSH session
  ./scan_and_connect.py <command...>     # run a command on the target
  ./scan_and_connect.py -k <keyfile>     # force SSH-key auth with given key
  ./scan_and_connect.py -p <password>    # override password
  ./scan_and_connect.py -u <user>        # override user for password auth
  ./scan_and_connect.py -m <MAC>         # match a different MAC
  ./scan_and_connect.py -n <CIDR>        # scan a different subnet (e.g. 192.168.1.0/24)

Environment overrides: TARGET_MAC, DEFAULT_USER, DEFAULT_PASS, KEY_USER,
ISO_KEY (extra key to try for the installed system).
"""

import argparse
import os
import socket
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

TARGET_MAC = os.environ.get("TARGET_MAC", "48:d2:24:7d:66:c2")  # lanchamarcou WiFi MAC
DEFAULT_USER = os.environ.get("DEFAULT_USER", "nixos")          # live-ISO user
DEFAULT_PASS = os.environ.get("DEFAULT_PASS", "tmprootpass")
KEY_USER = os.environ.get("KEY_USER", "plat2548")               # installed-system user
ISO_KEY = os.environ.get("ISO_KEY", "/tmp/iso_host_ed25519_key")
SSH_PORT = 22

SSH_OPTS = ["-o", "StrictHostKeyChecking=no",
            "-o", "UserKnownHostsFile=/dev/null",
            "-o", "ConnectTimeout=15",
            "-o", "ServerAliveInterval=15"]


def die(msg):
    sys.exit(f"error: {msg}")


def log(msg):
    print(f"[scan] {msg}", file=sys.stderr)


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def detect_cidr(cidr_arg):
    """Local subnet from the default route, e.g. '192.168.4.0/24'."""
    if cidr_arg:
        return cidr_arg
    dev = run(["ip", "-4", "route", "show", "default"]).stdout.split()
    if not dev:
        die("no default route; specify subnet with -n")
    addr = run(["ip", "-4", "addr", "show", "dev", dev[4], "scope", "global"]).stdout
    for line in addr.splitlines():
        if "inet " in line:
            return line.split()[1]
    die("no IPv4 address on default interface; specify subnet with -n")


def own_ip():
    """First global IPv4 address on the machine."""
    out = run(["ip", "-4", "addr", "show", "scope", "global"]).stdout
    for line in out.splitlines():
        if "inet " in line:
            return line.split()[1].split("/")[0]
    return None


def ping_sweep(cidr):
    """Ping 1..254 in parallel; return the list of live IPs."""
    base = cidr.rsplit(".", 1)[0]

    def ping(i):
        ip = f"{base}.{i}"
        if subprocess.run(["ping", "-c1", "-W1", ip], capture_output=True).returncode == 0:
            return ip
        return None

    with ThreadPoolExecutor(254) as ex:
        return [ip for ip in ex.map(ping, range(1, 255)) if ip]


def mac_of(ip):
    """MAC address of ip from the neighbour (ARP) table, lowercase."""
    out = run(["ip", "neigh", "show", ip]).stdout.split()
    return out[4].lower() if len(out) >= 5 else ""


def ssh_banner(ip, timeout=6):
    """Read the first line a host sends on port 22, or None."""
    try:
        with socket.create_connection((ip, SSH_PORT), timeout=timeout) as s:
            s.settimeout(timeout)
            return s.recv(64).decode(errors="replace").strip()
    except OSError:
        return None


def find_target(alive, target_mac, my_ip):
    # preferred: match by MAC address in the ARP/neighbour table
    if target_mac:
        mac = target_mac.lower()
        for ip in alive:
            if mac_of(ip) == mac:
                log(f"matched target MAC {target_mac} at {ip}")
                return ip
    # fallback: probe port 22 and pick the first host that speaks SSH
    log("probing port 22 for SSH banners...")
    for ip in alive:
        if ip == my_ip:
            continue
        banner = ssh_banner(ip)
        if banner and banner.startswith("SSH-"):
            log(f"  {ip}: {banner}")
            return ip
    return None


def try_key_auth(keyfile, user, ip):
    if not os.path.isfile(keyfile):
        return False
    cmd = ["ssh", "-i", keyfile, "-o", "IdentitiesOnly=yes", "-o", "BatchMode=yes",
           *SSH_OPTS, f"{user}@{ip}", "true"]
    return run(cmd, stdin=subprocess.DEVNULL).returncode == 0


def try_password_auth(user, password, ip):
    """Password auth via SSH_ASKPASS (works without a TTY)."""
    with tempfile.NamedTemporaryFile("w", suffix=".sh", delete=False) as f:
        f.write(f"#!/bin/sh\necho '{password}'\n")
        askpass = f.name
    os.chmod(askpass, 0o700)
    env = {**os.environ, "SSH_ASKPASS": askpass, "SSH_ASKPASS_REQUIRE": "force",
           "DISPLAY": ":0"}
    cmd = ["ssh", "-o", "PreferredAuthentications=password", "-o",
           "PubkeyAuthentication=no", *SSH_OPTS, f"{user}@{ip}", "true"]
    rc = run(cmd, env=env, stdin=subprocess.DEVNULL).returncode
    os.unlink(askpass)
    return rc == 0


def connect(user, ip, remote_cmd, keyfile=None, password=None):
    if keyfile:
        cmd = ["ssh", "-i", keyfile, "-o", "IdentitiesOnly=yes", *SSH_OPTS, f"{user}@{ip}"]
    else:
        # askpass file must outlive this function, so no tempfile auto-delete
        fd, askpass = tempfile.mkstemp(suffix=".sh")
        os.write(fd, f"#!/bin/sh\necho '{password}'\n".encode())
        os.close(fd)
        os.chmod(askpass, 0o700)
        try:
            env = {**os.environ, "SSH_ASKPASS": askpass,
                   "SSH_ASKPASS_REQUIRE": "force", "DISPLAY": ":0"}
            cmd = ["ssh", "-o", "PreferredAuthentications=password",
                   "-o", "PubkeyAuthentication=no", *SSH_OPTS, f"{user}@{ip}"]
            os.execvpe("ssh", cmd, env)  # exec: askpass cleanup not needed anymore
        finally:
            os.unlink(askpass)
    if remote_cmd:
        cmd += remote_cmd
    os.execvp("ssh", cmd)


def main():
    ap = argparse.ArgumentParser(add_help=True, description=__doc__.splitlines()[0])
    ap.add_argument("-k", metavar="KEYFILE", default="")
    ap.add_argument("-p", metavar="PASSWORD", default=DEFAULT_PASS)
    ap.add_argument("-u", metavar="USER", default=DEFAULT_USER)
    ap.add_argument("-m", metavar="MAC", default=TARGET_MAC)
    ap.add_argument("-n", metavar="CIDR", default="")
    ap.add_argument("remote_cmd", nargs="*")
    # everything not consumed by the flags is passed through as the remote command
    args, rest = ap.parse_known_args()
    args.remote_cmd += rest

    # security notice: host-key checking is disabled because the target is a
    # freshly installed / live-ISO machine with no pinned host key.
    log("warning: StrictHostKeyChecking=no + UserKnownHostsFile=/dev/null are used "
        "because the target is a NEWLY INSTALLED machine: its host key cannot be "
        "pinned in known_hosts and may change on every reinstall. This disables "
        "man-in-the-middle protection and is NOT suitable for regular machines.")

    cidr = detect_cidr(args.n)
    if not cidr.endswith("/24"):
        log("warning: non-/24 subnet handling is limited to 254 hosts")
    me = own_ip()
    log(f"scanning {cidr.rsplit('.', 1)[0]}.1-254 (own IP: {me or 'unknown'}) ...")

    alive = ping_sweep(cidr)
    log(f"live hosts: {' '.join(alive) or 'none'}")

    target = find_target(alive, args.m, me)
    if not target:
        die(f"no SSH-capable host found on {cidr}")
    log(f"target: {target}")

    # authenticate: explicit key -> ISO key for installed system -> ISO password
    if args.k:
        if not try_key_auth(args.k, args.u, target):
            die(f"key auth with {args.k} as {args.u} failed")
        log(f"authenticated as {args.u}@{target} (key auth)")
        connect(args.u, target, args.remote_cmd, keyfile=args.k)

    for cand in (ISO_KEY,):
        if try_key_auth(cand, KEY_USER, target):
            log(f"authenticated as {KEY_USER}@{target} (key auth via {cand})")
            connect(KEY_USER, target, args.remote_cmd, keyfile=cand)

    if try_password_auth(args.u, args.p, target):
        log(f"authenticated as {args.u}@{target} (password auth)")
        connect(args.u, target, args.remote_cmd, password=args.p)

    die(f"could not authenticate to {target} (tried key + password)")


if __name__ == "__main__":
    main()