# SUMMARY: tmux scratchpad shell toggled with M+ (Meta+Shift+Equal)

Goal: extend the tmux configuration of this flake with a scratchpad shell
(dropdown-terminal style) toggled on/off with Meta+Shift+Equal (`M+`),
enabled only when running on the console (no window manager), and test the
behaviour a user would expect through real end-to-end workflows.

## Steps undertaken

1.  **Explored the repo.** The tmux configuration lives in
    `templeArtemisEphesus/tmux/` (`main.conf.in` template + `default.nix`
    build + status scripts). An existing "console only" pattern (the F13
    voice-input binding guarded by an `if-shell` on
    `$WAYLAND_DISPLAY`/`$DISPLAY`) provided the convention to follow.

2.  **Probed tmux semantics empirically** (scratch tmux servers on a
    separate socket, `tmux 3.7c`):
    * `M-+` is the correct key name for Meta+Shift+Equal (`M+` does not
      parse); the Linux console delivers that key as `ESC +`, which tmux
      maps to `M-+`.
    * `display-popup` supports `-E` (close when the command exits) and
      `-C` (close a popup); there is *no* popup-open format variable.
    * A popup can run `tmux attach` (stateful scratchpad), but TMUX must
      be unset and the server socket passed explicitly with `-S`,
      otherwise the inner client talks to the wrong server.
    * Key finding: while a popup is open, the summoning client's key
      bindings do **not** fire - keypresses go into the popup pane. This
      shaped the whole toggle design (see below).

3.  **Implemented the scratchpad** (three files):
    * `templeArtemisEphesus/tmux/scratchpad-toggle.sh` (new): the toggle
      logic. Takes the target client (`#{client_name}`) and the tmux
      binary (both store paths, substituted at build time) plus the
      socket from `$TMUX`:
      * invoked from a normal client (its session is not `scratchpad`):
        create the persistent `scratchpad` session if needed (with
        `status off`, so the popup shows only a shell) and open a
        centred 90%x90% `display-popup -E` running
        `env -u TMUX tmux -S <socket> attach -t scratchpad`;
      * invoked from *inside* the popup (the popup's attach client is
        attached to the `scratchpad` session): detach that client. The
        attach exits, and because the popup was opened with `-E` the
        popup closes with it - while the session stays alive on the
        server, detached, so cwd/history/scrollback/running programs
        survive. No state files or options needed; every client can
        toggle its own popup independently, all sharing the one session.
    * `templeArtemisEphesus/tmux/default.nix`: install the script into
      the package (`runCommand` + `patchShebangs`, like the status
      scripts) and substitute `@scratchpadToggleScript@` in main.conf.
    * `templeArtemisEphesus/tmux/main.conf.in`: new documented block
      binding
      `bind-key -n M-+ run-shell -b "@scratchpadToggleScript@ #{client_name} @rawTmuxBin@"`
      guarded by
      `if-shell '[ -z "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ]'`
      (console only, mirroring the voice-input binding); the graphical
      else-branch sets a harmless `@scratchpad-disabled` user option.

4.  **Built** the package: `nix build --impure
    .#packages.x86_64-linux.tmux -o result-tmux` (had to `git add` the
    new script first - flakes ignore untracked files).

5.  **Built a test harness**: a small python pty harness that attaches a
    real tmux client under a pty (with a proper 120x40 winsize) and
    injects actual keystrokes (`ESC +`) into it, so root key bindings are
    exercised end-to-end. (Earlier flakiness turned out to be harness
    bugs: a 0x0 pty winsize, a hardcoded socket name and a timing bug -
    not feature bugs.)

6.  **Local (synthetic console) tests**, all against scratch servers:
    * console-like server (`env -u DISPLAY -u WAYLAND_DISPLAY`): the
      `M-+` binding is installed. Pressing `ESC +` opens the popup, the
      `scratchpad` session is created with `status off` and the attach
      client connects.
    * graphical server (`DISPLAY=:0 WAYLAND_DISPLAY=...`): the `M-+`
      binding is **not** installed and `@scratchpad-disabled` is set
      (the voice-input User0 binding is likewise absent).
    * rapid double-toggle (two presses 150 ms apart) plus further
      presses: ends in a sane state every time (popup closed, session
      alive), never any leftover/nested popups.
    * multi-client: two attached clients each open their own popup onto
      the shared `scratchpad` session; one client closing its popup
      leaves the other intact and the session alive.
    * `taskmux list` unaffected by the scratchpad session.

7.  **End-to-end test on a real console**: added a dedicated NixOS test
    VM `hangingGardensBabylon/tmux-scratchpad-vm/` (`vm.nix`,
    `provideScript.nix`, `drive-vm.py`), mirroring the existing
    `tmux-console-vm` pattern: tmux runs on the VGA console (tty1), the
    serial console drives/verifies, and QMP is used both for
    `screendump`s and for **real console keypresses** (`send-key` with
    alt+shift+equal for M+). The drive script checks 18 conditions and
    takes a screendump at every workflow step, each of which was then
    inspected visually:
    * shot0 baseline: no popup, normal console
    * shot1 after M+: centred bordered popup, shell only (no inner
      status bar), scratchpad absent from the window list
    * shot2 after typing: keystrokes reach the popup shell, command
      executed, prompt cwd changed to /tmp
    * shot3 after M+: popup gone, work pane restored cleanly
    * shot4 after reopen: SAME shell -- previous scrollback visible,
      still in /tmp, new command continued in it (state persisted)
    * shot5 after Escape: popup still open, shell unharmed (Escape is
      delivered to the scratchpad shell by design, so it works inside
      programs run there; the toggle key is the close mechanism)
    * shot6 after typing `exit`: popup closed, back on the work pane
    * shot7 after M+: fresh empty shell at ~ (session respawned)
    The checks cover: binding present (S1/S2); session created with
    attach client and status off (S3/S4/S6); keystrokes create markers
    in the popup shell (S7); M+ closes -> detached but session alive
    (S8/S9); focus/input back on the work pane (S11); reopen -> cwd and
    shell history persisted (S12/S13); Escape behaviour (S14/S15); close
    and reopen again (S15b/S16); exit destroys session and closes popup
    (S17/S17b); next M+ creates a fresh session (S18).
    **Result: 18/18 checks pass**, plus the per-step screendumps
    (`/tmp/vm-shot*.png`).  (An earlier screenshot from the first
    prototype run is what visually exposed the nested-popup bug that led
    to the detach-based close design.)  The workflows that cannot be
    photographed on a one-console VM -- multi-client popups, rapid
    double-toggle, and the graphical-session negative case (binding
    absent) -- were verified through server-state checks on scratch
    servers and, for the negative case, by the absence of the binding
    plus `@scratchpad-disabled` being set.

8.  **Cleanup**: killed all scratch test servers, removed stray test
    artifacts from the repo root; unstaged the VM disk image. No commits
    were made.

## Result

* `M+` (Meta+Shift+Equal) toggles a Guake/Yakuake-style scratchpad popup
  on the console only; state persists across toggles; focus and input
  return to the underlying pane when it closes; exiting the scratchpad
  shell respawns a fresh one on next summon.
* Files touched:
  `templeArtemisEphesus/tmux/scratchpad-toggle.sh` (new),
  `templeArtemisEphesus/tmux/default.nix`,
  `templeArtemisEphesus/tmux/main.conf.in`,
  plus the new test VM `hangingGardensBabylon/tmux-scratchpad-vm/`.
* Nothing was committed.
