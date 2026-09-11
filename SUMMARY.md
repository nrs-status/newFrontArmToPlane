# SUMMARY — `img-builder`

Task: create a program that takes a WiFi network (SSID + password) and a
password, and builds a minimal non-graphical NixOS installer image that is a
very simple extension of the official minimal installer, tries to connect to
the given WiFi network at boot, and sets root's password to the given
password. Packaged at `./templeArtemisEphesus/img-builder`.

## Steps

1. **Explored the repository**
   - Read `instructions.txt` and the root `flake.nix`.
   - Learned the repo layout: `templeArtemisEphesus/` auto-imports every
     top-level subdirectory as a package (`default.nix` uses
     `baseLib.importPairsOfDirPath`), with inputs
     `{ localLib, baseLib, pkgs, pkgsLib, modulesPath, nixosSystem, microvmFlake }`.
   - Studied an existing package (`templeArtemisEphesus/tiles/`) for style.

2. **Studied the official minimal installer in the pinned nixpkgs**
   (`/nix/store/...-source/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix`
   and friends) and confirmed:
   - the installer profile enables NetworkManager (interactive WiFi via
     `nmtui`) and sets `users.users.root.initialHashedPassword = ""`;
   - `users.users.root.hashedPassword` overrides `initialHashedPassword`
     (checked precedence order in `config/users-groups.nix`);
   - `networking.wireless.networks.<ssid>.pskRaw` + `wpa_supplicant` gives
     boot-time auto-connection (checked `services/networking/wpa_supplicant.nix`).

3. **Created `templeArtemisEphesus/img-builder/`** with three files:
   - `iso.nix` — a function
     `{ nixpkgsPath, wifiJson } -> config.system.build.isoImage` that
     evaluates `import (nixpkgsPath + "/nixos")` with a configuration that
     imports the official minimal installer and adds exactly:
     - `networking.networkmanager.enable = mkImageMediaOverride false`
       (so wpa_supplicant is the wifi manager instead);
     - `networking.wireless.enable = true` and
       `networking.wireless.networks."${ssid}".pskRaw = psk` (wpa_supplicant
       tries to connect to the SSID at boot);
     - `users.users.root.hashedPassword = <hash>` (root password on the ISO).
   - `img-builder.sh` — the CLI. Takes
     `--ssid/-s SSID` plus either `--password/-p PASSWORD` (shorthand used as
     both passwords) or `--wifi-password/-w PW` + `--root-password/-r PW`,
     optionally `-o/--out-link OUT` and `--dry-run`. Positional
     `SSID PASSWORD` also works (with flags allowed before, between and
     after positionals). It:
     - hashes the password with `mkpasswd -m yescrypt --stdin`;
     - derives the WPA pre-shared key with `wpa_passphrase` (so the raw WiFi
       password is stored as `pskRaw`, not plaintext);
     - writes `{ssid, psk, hashedPassword}` as JSON via `jq` into a temp file;
     - runs `nix build -f <iso.nix> --argstr nixpkgsPath <baked nixpkgs store
       path> --argstr wifiJson <tmp json> -L --out-link <out>` (the nixpkgs
       path is pinned to this repo's nixpkgs at package build time, so no
       network fetch is needed);
     - prints the resulting ISO path. `--dry-run` evaluates the derivation
       without building.
   - `default.nix` — package definition (`runCommand`) installing the script
     to `bin/img-builder` (with `substitute` for the baked
     `nixpkgsPath`/`isoNix` paths and `wrapProgram` to add `mkpasswd`,
     `wpa_supplicant`, `jq`, `nix` to `PATH`) and `iso.nix` to
     `share/img-builder/iso.nix`. It is picked up automatically as
     `packages.x86_64-linux.img-builder` by `templeArtemisEphesus/default.nix`.

4. **Build issues found and fixed**
   - The flake only sees git-tracked files → `git add`-ed the new directory.
   - The script's baked-in path placeholders (`@nixpkgsPath@`, `@isoNix@`)
     had no assignment line in the script → added
     `nixpkgsPath="@nixpkgsPath@"` / `isoNix="@isoNix@"` and rebuilt.
   - Pre-existing, unrelated issue: `templeArtemisEphesus/alaricKicksdownMessi/`
     has no `default.nix`, so evaluating that sibling package fails.

5. **Verified the tool**
   - `nix build .#img-builder` — package builds; `--help`, argument
     validation, and error paths work.
   - `img-builder --ssid MyHomeWiFi --password s3cret-pw --dry-run` —
     full NixOS ISO derivation evaluates cleanly.
   - `img-builder --ssid MyHomeWiFi --password s3cret-pw` — real end-to-end
     build succeeded, producing
     `nixos-minimal-26.11pre-git-x86_64-linux.iso`.
   - Inspected the ISO (`xorriso` + `unsquashfs`):
     - `etc/wpa_supplicant/nixos.conf` contains `ssid="MyHomeWiFi"` with the
       `pskRaw` hex key, and `wpa_supplicant.service` is enabled in
       `multi-user.target.wants` (so it tries to connect at boot);
     - NetworkManager is not in the ISO's systemd units;
     - `users-groups.json` in the ISO has root's `hashedPassword`, verified
       with libxcrypt's `crypt()` to match `s3cret-pw`.

## Usage

```bash
nix build .#img-builder
./result/bin/img-builder --ssid 'MyHomeWiFi' --password 's3cret-pw'
# or, with separate WiFi and root passwords:
./result/bin/img-builder --ssid 'MyHomeWiFi' \
  --wifi-password 'wifi-pass' --root-password 'root-pw'
# positional shorthand (same value for both passwords):
./result/bin/img-builder 'MyHomeWiFi' 's3cret-pw' -o my-installer-iso
# add --dry-run to evaluate without building
```

The symlink `./nixos-wifi-installer-iso` (or `-o OUT`) points to the ISO;
write it to a USB stick with e.g. `dd` and boot it: it connects to the WiFi
automatically and root's password is the one you passed.

## Follow-up: separate WiFi / root passwords

After review, the single-password interface was clarified (also recorded as a
clarification in `instructions.txt`): `--wifi-password/-w` and
`--root-password/-r` now set the two passwords independently, while
`--password/-p` (or the positional `PASSWORD`) remains as shorthand applying
the same value to both. The argument parser was also made tolerant of flags
placed after positional arguments (and of too many positionals, now an
error). Behavior re-verified with `--dry-run` for: combined shorthand,
separate passwords, mixed flag/positional order, and argument-validation
errors. Missing passwords now produce specific errors (`no WiFi password
given…` / `no root password given…`).