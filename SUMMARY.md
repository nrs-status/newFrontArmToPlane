# Summary: packaging `prompt-to-bash`

Branch: `prompt-to-bash`

1. **Read the task** (`./instructions.txt`): package the new script in the script
   directory, test the packaging, write this summary, and send a `notify-send`
   notification including the git branch.

2. **Explored the repository layout**:
   - Top-level `flake.nix` builds `packages.x86_64-linux` from
     `templeArtemisEphesus/` (auto-imported via `baseLib.importPairsOfDirPath`)
     and dev shells from `pyramidGiza/`.
   - Inspected how sibling scripts are packaged
     (`scripts/scan-and-connect`, `scripts/pi-json-span-ingest`,
     `scripts/compare-flake-pins`) to follow the existing conventions
     (`pkgs.runCommand` + `makeWrapper`, `meta` with `mainProgram`).

3. **Read the new script** `templeArtemisEphesus/scripts/prompt-to-bash/prompt-to-bash.py`:
   a Python 3 program that pipes a voice-command transcript through the `pi`
   coding agent, lets the user review the resulting bash commands with `vipe`,
   and executes them. Runtime dependencies: `python3`, `pi`, `vipe` (moreutils).

4. **Wrote the package**
   `templeArtemisEphesus/scripts/prompt-to-bash/default.nix`:
   - `pkgs.runCommand "prompt-to-bash-1.0.0"` with `makeWrapper`.
   - Installs the script to `share/prompt-to-bash.py` and creates
     `bin/prompt-to-bash` wrapping `python3`.
   - Wraps `PATH` with `pkgs.lib.makeBinPath [ localPkgs.pi pkgs.moreutils ]`
     so the script's default `pi` / `vipe` lookups resolve in the store env.
   - Added `meta` (description, `mainProgram = "prompt-to-bash"`, MIT, linux).

5. **Registered the script** — it was automatically picked up by
   `templeArtemisEphesus/scripts/default.nix` once the directory was
   `git add`-ed (flakes only see tracked files; before adding, the attribute
   `scripts.prompt-to-bash` did not exist).

6. **Built the package**:
   `nix build .#scripts.prompt-to-bash` → success
   (`result/bin/prompt-to-bash`, `result/share/prompt-to-bash.py`).

7. **Tested the packaging**:
   - `result/bin/prompt-to-bash --version` → `prompt-to-bash 1.0.0` ✔
   - `--help` output correct ✔
   - Error handling: empty stdin → exit 2 with clear message ✔;
     missing `pi` → exit 2 ✔; missing `vipe` → exit 2 ✔;
     `pi` exiting non-zero → exit 2 ✔;
     bad config file key via `PTB_CONFIG` → exit 2 ✔.
   - End-to-end pipeline with stub `pi` / `vipe` executables (via the
     supported `PTB_PI` / `PTB_VIPE` overrides): dry-run prints the reviewed
     commands without executing ✔; real run executes the reviewed commands
     (`mkdir -p scratch-dir`, `touch scratch-dir/scratch-file`) ✔;
     vipe failure path prints "Discarded" and exits 0 ✔.
   - Wrapper check: the installed wrapper's `PATH` contains the store
     `pi` and `moreutils` (vipe) paths; the binary works even with an empty
     parent environment (`env -i`) ✔.

8. **Added the package to the dev shell**
   `pyramidGiza/sieyes.nix` (`scripts.prompt-to-bash` in `buildInputs`) and
   rebuilt `.#devShells.x86_64-linux.sieyes` successfully ✔.

9. **Wrote this `SUMMARY.md`**, git-added the new files, and (as the final
   step) sent a `notify-send` notification describing task completion with the
   branch name.
