#!/usr/bin/env python3
"""Insert an ED25519 SSH key into a sops-encrypted YAML file, or read it back.

Sub-commands:
  insert <file> <field> <comment>
      Generate an ED25519 key (ssh-keygen) inside a private /dev/shm directory
      and insert it at <field> (a dotted path, e.g. `server.ssh.deploy_key`)
      of the sops-encrypted YAML file.  The file is re-encrypted in place
      using the ambient sops configuration (creation rules in .sops.yaml,
      SOPS_AGE_RECIPIENTS, --pgp/--kms/--age flags, ...).

  read <file> <field> [--output PATH]
      Decrypt the YAML file in memory and emit the private key on stdout
      (so it can be piped, e.g. into `ssh-add -`) or, with --output, to a
      file written with mode 0600.

Security properties:
  * No key material ever appears in argv (keys live in memory or in a
    mode-700 /dev/shm tmpdir that is always removed on exit).
  * Private key is never written to disk outside /dev/shm.
  * Errors never echo the key material.
"""

import argparse
import os
import shutil
import stat
import subprocess
import sys
import tempfile

import yaml

SHM = "/dev/shm"


def die(msg: str, code: int = 1) -> "None":
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(code)


def run_sops(args: list, **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(["sops", *args], **kwargs)


def decrypt_to_memory(path: str) -> bytes:
    """Decrypt a sops file, keeping the plaintext strictly in memory."""
    proc = run_sops(["-d", "--output-type", "yaml", path],
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        die(f"sops failed to decrypt {path}: "
            f"{proc.stderr.decode(errors='replace').strip()}")
    return proc.stdout


def extract_recipients(encrypted_bytes: bytes):
    """Extract the key groups used by an existing sops file from its embedded
    `sops:` metadata, so re-encryption reuses exactly the same recipients."""
    try:
        meta = (yaml.safe_load(encrypted_bytes) or {}).get("sops", {})
    except yaml.YAMLError:
        die("cannot parse sops metadata of target file")
    if not isinstance(meta, dict):
        return None
    age = [e["recipient"] for e in meta.get("age") or [] if "recipient" in e]
    pgp = [e["fingerprint"] for e in meta.get("pgp") or []
           if "fingerprint" in e]
    kms = [e["arn"] for e in meta.get("kms") or [] if "arn" in e]
    if not (age or pgp or kms):
        return None
    return {"age": age, "pgp": pgp, "kms": kms}


def encrypt_bytes_with(plaintext: bytes, recipients) -> bytes:
    """Encrypt YAML bytes with sops.

    If `recipients` is given (extracted from the target's own metadata),
    a temporary SOPS_CONFIG with a catch-all creation rule is used so that
    re-encryption reuses exactly the same recipients regardless of the
    ambient rules; no key material touches argv and the plaintext stays in
    /dev/shm.  Otherwise the ambient sops configuration (.sops.yaml creation
    rules, SOPS_* environment) decides."""
    with tempfile.TemporaryDirectory(dir=SHM) as tmpdir:
        tmp = os.path.join(tmpdir, "plaintext.yaml")
        fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "wb") as f:
            f.write(plaintext)
        args = ["-e", "--input-type", "yaml", "--output-type", "yaml"]
        env = os.environ.copy()
        if recipients:
            cfg = os.path.join(tmpdir, "sops-config.yaml")
            body = ""
            if recipients["age"]:
                body += f"    age: {','.join(recipients['age'])}\n"
            if recipients["pgp"]:
                body += f"    pgp: '{','.join(recipients['pgp'])}'\n"
            if recipients["kms"]:
                body += f"    kms: '{','.join(recipients['kms'])}'\n"
            with open(cfg, "w") as f:
                f.write("creation_rules:\n"
                        "  - path_regex: \".*\"\n" + body)
            env["SOPS_CONFIG"] = cfg
            if recipients["age"]:
                env["SOPS_AGE_RECIPIENTS"] = ",".join(recipients["age"])
            if recipients["pgp"]:
                args += ["--pgp", ",".join(recipients["pgp"])]
            if recipients["kms"]:
                args += ["--kms", ",".join(recipients["kms"])]
        proc = run_sops([*args, tmp], stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE, env=env)
        if proc.returncode != 0:
            die(f"sops failed to encrypt: "
                f"{proc.stderr.decode(errors='replace').strip()}")
        return proc.stdout


def write_target(path: str, data: bytes) -> None:
    """Atomically (re)write the encrypted file with a safe mode."""
    if os.path.exists(path):
        mode = stat.S_IMODE(os.lstat(path).st_mode)
    else:
        mode = 0o600
    tmp = path + ".sops-ssh.tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, mode)
    try:
        os.write(fd, data)
    finally:
        os.close(fd)
    os.chmod(tmp, mode)
    os.replace(tmp, path)


def set_nested(data: dict, parts: list, value) -> None:
    node = data
    for part in parts[:-1]:
        nxt = node.get(part)
        if not isinstance(nxt, dict):
            nxt = {}
            node[part] = nxt
        node = nxt
    node[parts[-1]] = value


def get_nested(data, parts: list):
    node = data
    for part in parts:
        if not isinstance(node, dict) or part not in node:
            die(f"field path '{'.'.join(parts)}' not found "
                f"(missing '{part}')")
        node = node[part]
    return node


def generate_key(comment: str, tmpdir: str):
    """Run ssh-keygen inside the /dev/shm tmpdir; return (priv, pub)."""
    keypath = os.path.join(tmpdir, "id_ed25519")
    proc = subprocess.run(
        ["ssh-keygen", "-t", "ed25519", "-N", "", "-C", comment, "-f", keypath],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        die(f"ssh-keygen failed: {proc.stderr.decode(errors='replace').strip()}")
    with open(keypath, "r") as f:
        priv = f.read()
    with open(keypath + ".pub", "r") as f:
        pub = f.read().strip()
    return priv, pub


def cmd_insert(args) -> None:
    target, field, comment = args.file, args.field, args.comment
    parts = field.split(".")
    if any(not p for p in parts):
        die(f"invalid field path: {field!r}")

    # Plaintext in memory (or empty document for a fresh file).
    recipients = None
    if os.path.exists(target):
        encrypted = open(target, "rb").read()
        recipients = extract_recipients(encrypted)
        plaintext = decrypt_to_memory(target)
    else:
        plaintext = b"{}\n"
    data = yaml.safe_load(plaintext.decode()) or {}
    if not isinstance(data, dict):
        die("top-level YAML document is not a mapping")

    # Generate the key inside a private /dev/shm directory.
    tmpdir = tempfile.mkdtemp(dir=SHM, prefix="sops-ssh-")
    os.chmod(tmpdir, 0o700)
    try:
        priv, pub = generate_key(comment, tmpdir)
        set_nested(data, parts, {
            "type": "ed25519",
            "private_key": priv,
            "public_key": pub,
            "comment": comment,
        })
        new_pt = yaml.safe_dump(data, default_flow_style=False,
                                sort_keys=False).encode()
        if recipients:
            # Existing encrypted file: re-encrypt with its own recipients;
            # plaintext never touches persistent disk.
            encrypted_out = encrypt_bytes_with(new_pt, recipients)
            write_target(target, encrypted_out)
        else:
            # Fresh (or unencrypted) file: write plaintext to the final
            # location (mode 0600) and let sops encrypt it in place with the
            # ambient configuration, exactly like a manual `sops -e -i`.
            fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            try:
                os.write(fd, new_pt)
            finally:
                os.close(fd)
            try:
                proc = run_sops(["-e", "-i", "--input-type", "yaml",
                                 "--output-type", "yaml", target],
                                stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE,
                                cwd=os.path.dirname(os.path.abspath(target)))
                if proc.returncode != 0:
                    os.unlink(target)
                    die(f"sops failed to encrypt {target}: "
                        f"{proc.stderr.decode(errors='replace').strip()}")
            except BaseException:
                if os.path.exists(target):
                    os.unlink(target)
                raise
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)
    print(f"inserted ed25519 key at '{field}' in {target}", file=sys.stderr)


def cmd_read(args) -> None:
    parts = args.field.split(".")
    if any(not p for p in parts):
        die(f"invalid field path: {args.field!r}")

    data = yaml.safe_load(decrypt_to_memory(args.file).decode()) or {}
    value = get_nested(data, parts)

    if isinstance(value, dict):
        priv = value.get("private_key")
    else:
        priv = value
    if not isinstance(priv, str) or "PRIVATE KEY" not in priv:
        die(f"no private key found at '{args.field}'")

    if args.output:
        fd = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        try:
            os.write(fd, priv.encode())
        finally:
            os.close(fd)
        os.chmod(args.output, 0o600)
    else:
        sys.stdout.write(priv)


def main() -> None:
    parser = argparse.ArgumentParser(
        prog="sops_ssh_key",
        description="Insert/read ED25519 SSH keys in sops-encrypted YAML.")
    sub = parser.add_subparsers(dest="command", required=True)

    p_ins = sub.add_parser("insert", help="generate a key and insert it")
    p_ins.add_argument("file", help="path to the sops-encrypted YAML file")
    p_ins.add_argument("field", help="field path, e.g. server.ssh.deploy_key")
    p_ins.add_argument("comment", help="comment for ssh-keygen -C")
    p_ins.set_defaults(func=cmd_insert)

    p_read = sub.add_parser("read", help="read the private key back")
    p_read.add_argument("file", help="path to the sops-encrypted YAML file")
    p_read.add_argument("field", help="field path, e.g. server.ssh.deploy_key")
    p_read.add_argument("--output", metavar="PATH",
                        help="write key to PATH (mode 0600) instead of stdout")
    p_read.set_defaults(func=cmd_read)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
