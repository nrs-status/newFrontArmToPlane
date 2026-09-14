# SUMMARY: Packaging the himalaya email client

Branch: `add-himalaya`

## Goal
Package the `himalaya` email client in the repo's package tree
(`templeArtemisEphesus/`), bundled with an example configuration, and test
that it works.

## Steps

1. **Read `instructions.txt`** — task: package himalaya with an example
   config at `./templeArtemisEphesus/himalaya`, test it, write this summary,
   and send a `notify-send` notification including the git branch.

2. **Explored the repo** (`flake.nix`, `templeArtemisEphesus/`,
   `sandyFireworksBus/`):
   - `templeArtemisEphesus/default.nix` auto-imports every subdirectory as a
     package via `baseLib.importPairsOfDirPath`, so a new
     `templeArtemisEphesus/himalaya/` directory with a `default.nix`
     automatically becomes `.#himalaya`.
   - Existing wrapper patterns reviewed: `newsboat`/`sesh` (mkDerivation +
     makeWrapper) and `television` (`localLib.mkWrapperScript` from
     `sandyFireworksBus/mkWrapperScript.nix`).

3. **Checked himalaya in nixpkgs** — `nixpkgs#himalaya` is v2.0.0; verified
   it supports the global `--config <PATH>` flag.

4. **Determined the example config format** by trial against the v2.0.0
   binary: TOML with an `[accounts.<name>]` table (imap backend +
   password auth via `pass`) and a `message.send.backend.*` SMTP section.

5. **Created `templeArtemisEphesus/himalaya/`**:
   - `config.toml` — example config with a placeholder `personal` account;
     no secrets stored (passwords fetched at runtime through `pass`).
   - `default.nix` — installs the config into a `runCommand` output and
     wraps `pkgs.himalaya` with `localLib.mkWrapperScript`:
     - `--config <store-path>/config.toml` baked in (per-invocation
       `--config` still wins, as it is passed last).
     - `pkgs.pass` added to `runtimeInputs` so the example config's
       `backend.auth.cmd` can resolve.

6. **Built the package**:
   ```
   nix build .#himalaya --out-link result-himalaya
   ```
   (First needed `git add templeArtemisEphesus/himalaya` — untracked files
   are invisible to the flake's git-tree source.) Build succeeded.

7. **Tested that it works** (with an isolated `HOME=/tmp/hima-home`):
   - `result-himalaya/bin/himalaya account list` → uses the bundled example
     config and lists the `personal` account as default. ✅
   - `result-himalaya/bin/himalaya --config /tmp/hima-test/config.toml
     account list` → per-invocation `--config` override works. ✅
   - `himalaya --version` → himalaya v2.0.0. ✅

8. **Cleanup & wrap-up**:
   - Removed the `result-himalaya` build symlink.
   - Wrote this `SUMMARY.md`.
   - Sent a `notify-send` desktop notification mentioning the
     `add-himalaya` branch.
