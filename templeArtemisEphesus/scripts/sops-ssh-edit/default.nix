{ localPkgs, pkgs, ... }:
# sops-ssh-edit: insert an ED25519 SSH key into a sops-encrypted YAML file
# (or read it back) without ever exposing key material in argv or on
# persistent disk: keys are generated inside a mode-700 /dev/shm tmpdir
# which is always removed on exit, decryption/encryption stay in memory,
# and re-encryption reuses the recipients embedded in the target's own
# `sops:' metadata.  Runtime dependencies: sops, openssh (ssh-keygen) and
# python3 with pyyaml.
pkgs.runCommand "sops-ssh-edit-1.0.0"
  {
    nativeBuildInputs = [ pkgs.makeWrapper ];
    meta = with pkgs.lib; {
      description =
        "Insert/read ED25519 SSH keys in sops-encrypted YAML files, keeping key material out of argv and persistent disk";
      mainProgram = "sops-ssh-edit";
      license = licenses.mit;
      platforms = platforms.linux;
    };
    pythonEnv = pkgs.python3.withPackages (ps: [
      ps.pyyaml # YAML parsing/serialisation
    ]);
  }
  ''
    install -Dm555 ${./sops_ssh_key.py} $out/share/sops_ssh_key.py

    mkdir -p $out/bin
    makeWrapper $pythonEnv/bin/python3 $out/bin/sops-ssh-edit \
      --add-flags "$out/share/sops_ssh_key.py" \
      --prefix PATH : ${
        pkgs.lib.makeBinPath [
          pkgs.sops # decrypt/encrypt the target YAML
          pkgs.openssh # provides `ssh-keygen' (key generation)
        ]
      }
  ''
