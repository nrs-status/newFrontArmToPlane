# SUMMARY: Alt+Q — send nushell command buffer to neovim

## Goal
Add an Alt+Q keybinding to the nushell configuration that sends the entire
command buffer (including multiline commands) to neovim, and test that it works.

## Steps

1. **Explored the repository layout** (`./instructions.txt` sent me here):
   - `flake.nix` wires up `templeArtemisEphesus` (application configs) via
     `sandyFireworksBus` helpers and `pyramidGiza` devshells.
   - The nushell config lives in `templeArtemisEphesus/nushell/`
     (`default.nix` builds a `nuConfig` derivation and wraps the `nushell`
     binary with `mkWrapperScript`; `general.nu` holds the main config,
     including existing keybindings and menus).

2. **Implemented the feature** in `templeArtemisEphesus/nushell/general.nu`:
   - Added a `def edit-buffer-in-nvim []` that:
     - captures the current reedline buffer with `commandline` (multiline
       included),
     - writes it to a temp file (`mktemp --tmpdir nu-buffer-XXXXXXXXXX.nu`),
     - opens neovim on it (`^nvim $tmp`),
     - reads the file back with `open --raw` (`--raw` so a `.nu` file is not
       parsed as nushell data) and puts it back with
       `commandline edit --replace`,
     - removes the temp file.
   - Added the keybinding:
     ```nu
     $env.config.keybindings ++= [{
         name: edit_buffer_in_nvim
         modifier: alt
         keycode: char_q
         mode: [emacs, vi_normal, vi_insert]
         event: {send: ExecuteHostCommand cmd: "edit-buffer-in-nvim"}
     }]
     ```
     `ExecuteHostCommand` runs the helper as a regular command, so the
     interactive nvim session works outside of reedline, and the edited text
     lands back on the command line when nvim exits.

3. **Built the config**: `nix build .#packages.x86_64-linux.nushell`
   (plus `.#packages.x86_64-linux.montezumaCirclesScroll.full` for the nvim
   binary and nixpkgs `atuin`/`zoxide`/`starship`/`bash`/`coreutils` for the
   runtime PATH of the test shell).

4. **Tested** in a detached tmux session (`testaltq`) running the built
   nushell wrapper with nvim on PATH:
   - Typed a multiline command (`echo "line1` + Enter continuation +
     `line2"`).
   - Pressed Alt+Q → nvim opened showing the *entire* multiline buffer
     (`echo "line1` / `line2"`). (Unrelated nixvim plugin warnings about
     `image.nvim`/`smart-splits.nvim` appeared because the test env lacks
     tmux/graphics on PATH; they do not affect the feature.)
   - Edited the buffer in nvim (`:s/line1/LINE1/`) and `:wq` → the edited
     command `echo "LINE1` / `line2"` reappeared on the nushell command line.
   - Pressed Enter → the command executed correctly, printing `LINE1`/`line2`.
   - Edge case: pressing Alt+Q with an empty buffer and quitting nvim
     (`:q!`) returns cleanly to an empty prompt.

5. **Cleanup**: killed the test tmux session. Changes left uncommitted.

## Result
Alt+Q in nushell now round-trips the full command buffer (multiline included)
through neovim: buffer → temp file → nvim → back onto the command line.
