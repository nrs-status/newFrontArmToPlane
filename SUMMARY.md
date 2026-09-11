# SUMMARY — Repackage `tiles` with `mkDerivation`

Branch: `repackage-tiles`

## Context

`templeArtemisEphesus/tiles/default.nix` packaged the tiles TUI (a Python
curses launcher driven by a TOML config) via `pkgs.writeShellApplication`.
Its sources (`tiles.py`, `exampleConfig.toml`) were absent from the working
tree — only the packaging expression was committed. The goal was to repackage
it using `pkgs.stdenv.mkDerivation` instead.

## Steps

1. **Read `instructions.txt`** and inspected the flake, the
   `templeArtemisEphesus` tree and `templeArtemisEphesus/tiles/default.nix`
   (the old `writeShellApplication` packaging referencing the missing
   `./tiles.py` and `./exampleConfig.toml`).

2. **Recovered `tiles.py`**: found an older built derivation of `tiles` in
   the Nix store whose build content embedded the full Python source;
   extracted it from the derivation JSON
   (`nix derivation show /nix/store/...-tiles.drv`) and validated it
   (`ast.parse`) before saving it as
   `templeArtemisEphesus/tiles/tiles.py`.

3. **Recreated `templeArtemisEphesus/tiles/exampleConfig.toml`**: no copy
   existed anywhere (never built), so authored one exercising all config
   forms documented in `tiles.py` (string shorthand `date = "date"` and full
   `[tiles.<id>]` tables with `key`/`name`/`command`).

4. **Wrote `templeArtemisEphesus/tiles/launcher.sh`**: the former
   `writeShellApplication` shell logic (usage/`-h|--help`/unknown-flag
   handling, defaulting to the packaged example config, exec'ing
   `python3 tiles.py -c CONFIG`), now parameterised by env vars
   `TILES_PY` and `TILES_EXAMPLE_CONFIG` instead of Nix interpolations.

5. **Rewrote `templeArtemisEphesus/tiles/default.nix`** as a
   `pkgs.stdenv.mkDerivation`:
   - `nativeBuildInputs = [ pkgs.makeWrapper ]`, `dontConfigure`/`dontBuild`
   - installs `tiles.py` + `exampleConfig.toml` into `$out/share/tiles/`,
     the launcher as `$out/bin/tiles`
   - `wrapProgram` puts `python3` on PATH and sets `TILES_PY` /
     `TILES_EXAMPLE_CONFIG`
   - added `meta` (`mainProgram`, description, license, platforms)

6. **Fixed two build issues**: dropped the `lib` lambda argument (not
   provided by `importPairsOfDirPath`; used `pkgs.lib`), and `git add`-ed
   the new files (flake sources only include tracked files).

7. **Built**: `nix build .#tiles` → succeeded.

8. **Tested**:
   - `./result/bin/tiles --help` → prints usage, exit 0
   - TUI in a pty (`script -qec`): draws "example tiles — 3 commands" with
     tile borders, exits cleanly (exit 0) on ESC
   - Tile keypress: pressed `d` → ran `df -h`, showed
     "[exit 0] press any key to return to tiles"
   - Custom config argument → launches and exits cleanly
   - Unknown flag (`--badflag`) → usage on stderr, exit 1
   - Missing config file → usage on stderr, exit 1

## Result

`templeArtemisEphesus/tiles` is now a `mkDerivation` package exposing the
`tiles` binary with identical CLI semantics to the previous
`writeShellApplication` packaging.
