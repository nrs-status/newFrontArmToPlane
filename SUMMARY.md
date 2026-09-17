# Summary: completing the `separate-config-packages` refactoring

Branch: `separate-config-packages`

## Goal of the refactoring

The two WIP commits (`12b0125`, `2b74f3e`) were splitting the formerly
monolithic package tree into two groups:

- **config packagings** — wrappers that package an existing tool together with
  configuration (`templeArtemisEphesus/`): `fish`, `git`, `nixvim`
  (`montezumaCirclesScroll`), `pi`, `nushell`, `tmux`, `weechat`, …;
- **new packages** — software that does not exist upstream
  (`irc-phoneFan/`): `arunman`, `tell`, `tiles`, `voice-input`,
  `pi-vm`, `pi-container`, `scripts`, `iphone-dev-service`, ….

The file moves were done, but `flake.nix` was left in a state that broke the
package set.

## Steps taken

1. **Reconnaissance**
   - Inspected the working tree, the last three commits, and the two flake
     inputs (`peachRampSkateboard.baseLib`, `nixvimFlake`) to understand how
     `importPairsOfDirPath` turns every direct child directory of a package
     directory into an attribute of the package set.
   - Read every consumer of the packages (`pyramidGiza/*`, `irc-phoneFan/pi-container/test.sh`,
     `hangingGardensBabylon/pi-vm/*`, `templeArtemisEphesus/fish`) to determine
     the required shape of the package set.
   - Established that the package set must be **flat**: internal code refers to
     `localPkgs.<name>` on both sides of the split (e.g.
     `templeArtemisEphesus/fish` uses `localPkgs.scripts.fishScripts`, while
     `irc-phoneFan/scripts/llm-gcm` uses `localPkgs.pi`/`localPkgs.git`/
     `localPkgs.nushell`), and external tooling addresses
     `packages.x86_64-linux.<name>` (e.g. `pi-container/test.sh` builds
     `.#packages.x86_64-linux.pi-container.container`).

2. **Fixed `flake.nix`**
   - Replaced the broken fixpoint
     `localPkgs = fix (self: { configPackagings = …; newPkgs = …; })`, which
     made `localPkgs.<pkg>` undefined, with a fixpoint that:
     - imports both groups separately (`configPackagings` from
       `./templeArtemisEphesus`, `newPkgs` from `./irc-phoneFan`), passing the
       fixpoint itself as `localPkgs` so both groups can reference each other;
     - exposes the two groups under their own names (`packages.x86_64-linux.configPackagings`
       and `packages.x86_64-linux.newPkgs`), keeping the separation that the
       commits introduce visible in the flake output;
     - merges the two groups into the same attribute set so every existing flat
       name (`.#fish`, `.#pi`, `.#scripts.scan-lan`, `.#pi-vm.run-pi-vm`, …)
       keeps working.
   - Left `packages."x86_64-linux" = localPkgs;` and the devShells wiring
     unchanged.

3. **Updated stale paths left by the file moves**
   - `hangingGardensBabylon/pi-vm/provideScript.nix`:
     `../../templeArtemisEphesus/pi-vm/bare.nix` →
     `../../irc-phoneFan/pi-vm/bare.nix`.
   - `hangingGardensBabylon/pi-vm/wserviceProvideScript.nix`:
     `../../templeArtemisEphesus/pi-vm/wservice.nix` →
     `../../irc-phoneFan/pi-vm/basic/wservice.nix` (the real location).
   - Docstrings in `irc-phoneFan/pi-vm/basic/runWserviceVm.py` and
     `irc-phoneFan/pi-vm/microvm/runWserviceMicrovm.py` now point at
     `irc-phoneFan/...`.
   - Verified no other references to moved directories remain (the remaining
     `templeArtemisEphesus/...` references are for `firefox`, which did not
     move, or live in `hangingGardensBabylon/oldTests/`, which is intentionally
     historical).

4. **Testing**
   - `nix eval .#packages.x86_64-linux --apply builtins.attrNames` — evaluates and
     lists the flat names plus the `configPackagings` and `newPkgs` groups.
   - `nix eval .#devShells.x86_64-linux.{headless,sieyes}.drvPath` — both shells
     evaluate.
   - Enumerated every derivation reachable in `packages.x86_64-linux`
     (recursively descending into the package groups) and built **all 36** of
     them in one `nix build --no-link --keep-going` invocation; all succeeded.
   - Rebuilt both devShells; both built successfully.
   - Spot-checked group-addressed attributes
     (`.#configPackagings.fish`, `.#configPackagings.firefox`,
     `.#configPackagings.montezumaCirclesScroll.full`, `.#newPkgs.tiles`,
     `.#newPkgs.tell`, `.#newPkgs.scripts.prompt-to-bash`,
     `.#newPkgs.pi-vm.run-pi-vm`, `.#newPkgs.scripts.scan-lan`); all built.

   The 36 built derivations:
   `arunman`, `broot`, `firefox`, `fish`, `git`, `himalaya`, `img-builder`,
   `iphone-dev-service`, `kitty`, `montezumaCirclesScroll.base`,
   `montezumaCirclesScroll.full`, `newsboat`, `nushell`, `pi`,
   `pi-container.pi-container`, `pi-container.run-pi-container`,
   `pi-json-span-processor`, `pi-vm.run-pi-microvm`, `pi-vm.run-pi-vm`,
   `scripts.bwrap-wpath`, `scripts.compare-flake-pins`, `scripts.fishScripts`,
   `scripts.llm-gcm`, `scripts.pi-json-span-ingest`, `scripts.prompt-to-bash`,
   `scripts.scan-lan`, `scripts.update-twc-fatp-input`, `secrets`, `sesh`,
   `television`, `tell`, `tiles`, `tmux`, `voice-input`, `voice-transcribe`,
   `weechat`.

## Pre-existing issues deliberately left untouched

These are broken on the branch's base commit already and are unrelated to the
config-packaging/new-package split, so they were not modified:

- `templeArtemisEphesus/alaricKicksdownMessi/` is raw documentation data
  (`README.md` + `nodes/`), has no `default.nix`, and is picked up by the
  directory glob (`import` of it fails). It is not a package.
- `irc-phoneFan/scripts/bwrap-pi.nix` references
  `localPkgs.scripts.bwrap-path`, which never existed (the package is
  `bwrap-wpath`); it has always been an unused example and does not evaluate.

Both entries are excluded from the "build every package" run above; everything
else builds.

## Constraints observed

- No commits were made.
- `SUMMARY.md` (this file) was added.