# SUMMARY: Adding the Bitwarden extension to the Firefox package

Branch: `vaultwarden-firefox`

## Goal
Extend the existing Firefox package configuration (which force-installs
uBlock Origin and Vimium via `extraPolicies.ExtensionSettings`) with the
Bitwarden Password Manager extension.

## Steps

1. **Read `instructions.txt`** — task: extend the Firefox package config with
   Bitwarden, test that it works, write this summary, and send a
   `notify-send` notification including the git branch.

2. **Explored the repo** (`flake.nix`, `templeArtemisEphesus/`, `pyramidGiza/`):
   - Firefox is packaged in `templeArtemisEphesus/firefox/default.nix`.
   - Extensions are pinned as `pkgs.fetchurl` of AMO `.xpi` files and
     force-installed via the `ExtensionSettings` enterprise policy, with
     everything else blocked by the `"*"` wildcard entry.

3. **Looked up the Bitwarden extension metadata** from the
   addons.mozilla.org API (`/api/v5/addons/addon/bitwarden-password-manager/`):
   - Add-on GUID: `{446900e4-71c2-419f-a6a7-df9c091e268b}`
   - Version: 2026.8.0
   - xpi URL: `https://addons.mozilla.org/firefox/downloads/file/4970633/bitwarden_password_manager-2026.8.0.xpi`
   - SHA256 (SRI format, as reported by AMO):
     `sha256:989ee33f19329af1fc155dcebb7f90a517a7259cea4bfbdd660923d25a7d465a`

4. **Edited `templeArtemisEphesus/firefox/default.nix`**:
   - Added a `bitwarden = pkgs.fetchurl { ... }` pinned fetch (same pattern
     as the existing uBlock Origin / Vimium entries).
   - Added an `ExtensionSettings` entry for the Bitwarden GUID with
     `installation_mode = "force_installed"` and
     `install_url = "file://${bitwarden}"`.

5. **Built the package**:
   ```
   nix build .#firefox --out-link result-firefox
   ```
   Build succeeded; verified the generated
   `.../lib/firefox/distribution/policies.json` now contains the Bitwarden
   `force_installed` entry alongside uBlock Origin and Vimium.

6. **Tested that it works properly**:
   - Launched the built Firefox headless with a fresh throwaway profile:
     ```
     firefox --headless --no-remote --profile /tmp/ff-test-profile2 about:blank
     ```
     (First attempt with `--screenshot` quit before the ~19 MB Bitwarden
     xpi finished async-installing; running the browser persistently for
     ~60 s let the policy-driven install complete.)
   - Parsed the profile's `extensions.json`: all three policy extensions
     present and `active: True`, including
     `{446900e4-71c2-419f-a6a7-df9c091e268b}` → **Bitwarden Password
     Manager**.
   - Took a headless `--screenshot` of `about:addons` on the same profile:
     the "Enabled" list shows **Bitwarden Password Manager**, **uBlock
     Origin**, and **Vimium**. ✅

7. **Cleanup & wrap-up**:
   - Removed the `result-firefox` build symlink.
   - Wrote this `SUMMARY.md`.
   - Sent a `notify-send` desktop notification mentioning the
     `vaultwarden-firefox` branch.
