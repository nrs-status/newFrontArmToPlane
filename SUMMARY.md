# SUMMARY — Fix pi container not connecting to OpenRouter (run 1)

Branch: `fix-pi-container-not-connecting-run1`

## Problem

The container packaged at `templeArtemisEphesus/pi-container/` runs `pi`, but on
initialization the `pi` process inside it did not manage to connect to
OpenRouter. The API key must be obtained at runtime by reading
`/run/secrets/OPENROUTER_API_KEY`, and at no point may the key be passed as a
command-line argument (cmdline vulnerability).

## Investigation

1. Read `instructions.txt` and inspected the packaging:
   - `templeArtemisEphesus/pi-container/default.nix` — `dockerTools.buildLayeredImage`
     whose `Entrypoint` is the wrapped `pi`.
   - `templeArtemisEphesus/pi/default.nix` — wrapper script built with
     `localLib.mkWrapperScript` (`sandyFireworksBus/mkWrapperScript.nix`) that
     prepares `~/.pi/agent/` and defaults to `--model openrouter/z-ai/glm-5.3-flash`.
   - `templeArtemisEphesus/pi/auth.json` — resolves the key at runtime via the
     command value `"! cat /run/secrets/OPENROUTER_API_KEY"` (never in argv).
2. Consulted pi docs (`providers.md`, `models.md`):
   - `auth.json` `key` values starting with `!` are executed as shell commands
     (via Node's `child_process.execSync`, which spawns `/bin/sh -c …`).
   - `models.json` and `models-store.json` belong in `~/.pi/agent/`.
3. Rebuilt the image from the flake (`nix build
   .#packages.x86_64-linux.pi-container`) and reproduced/tested the failure
   modes with docker and podman (dir-mounted secret, file-mounted secret, no
   secret, rpc mode, interactive mode).

## Findings

1. **Model catalog missing in the container.** The wrapper copied only
   `auth.json` into `~/.pi/agent/`. The user-maintained `models.json`
   (provider overrides) and `models-store.json` (the model catalog containing
   the configured default model `z-ai/glm-5.3-flash`) were never installed, so
   pi fell back to a stale bundled catalog: every run printed
   `Warning: Model "z-ai/glm-5.3-flash" not found for provider "openrouter"`
   and ran on a synthetic fallback model instead of the configured one.
2. **`/bin/sh` is a silent prerequisite.** pi resolves the `"! cat …"` key in
   `auth.json` via Node's `execSync`, which requires `/bin/sh` inside the
   image. This is now guaranteed explicitly by a symlink in
   `fakeRootCommands` (it also documents why the key cannot be read without it).
3. **`auth.json` was copied read-only.** Store paths are mode `444`; pi expects
   a private `0600` auth file it can rewrite (e.g. after `/login`).

## Changes

- `templeArtemisEphesus/pi/default.nix`
  - Install `auth.json`, `models.json` and `models-store.json` into
    `~/.pi/agent/` with `install -m 600` (writable at runtime, private).
  - `auth.json` still reads the key at runtime from
    `/run/secrets/OPENROUTER_API_KEY`; the key never enters an image layer or a
    process argv.
- `templeArtemisEphesus/pi-container/default.nix`
  - `fakeRootCommands` now explicitly creates `/bin/sh → bash` (required by
    Node's `execSync` when resolving the `!`-command key), with a comment.
- `templeArtemisEphesus/pi-container/test.sh` (new)
  - Reproducible verification script (see below).

## Verification (`templeArtemisEphesus/pi-container/test.sh`)

The script builds the image from the flake, loads it into docker and asserts:

1. **Directory-mounted secret** (`-v /run/secrets:/run/secrets:ro`): pi
   completes a real OpenRouter request and replies `CONNECTED`; no
   "model not found" warning; no "No API key" error.
2. **File-mounted secret** (`-v /run/secrets/OPENROUTER_API_KEY:…`): same.
3. **Negative control** (no secret mounted): pi correctly reports
   `No API key found for openrouter.` — proving the connection truly uses the
   secret file.
4. **cmdline security**: while pi runs, every `/proc/<pid>/cmdline` in the
   container is sampled; the API key never appears as a command argument.

Also verified manually: rootless `podman run` (matches the user's workflow
notes in `templeArtemisEphesus/alaricKicksdownMessi/nodes/podman/general.md`)
and `--mode rpc` initialization both connect successfully.

Result: **ALL TESTS PASSED**.
