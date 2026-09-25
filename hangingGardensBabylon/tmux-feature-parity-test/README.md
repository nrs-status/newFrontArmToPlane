# tmux feature-parity test

Compares two *built* tmux packages — a pre-refactor **baseline** and the
**refactored** package — and asserts they behave identically. It was written
to validate the refactor that moved the generated tmux configuration out of
`templeArtemisEphesus/tmux/default.nix` into
`templeArtemisEphesus/tmux/main.conf.in`.

## Safety

Every tmux invocation runs under `env -i` (so the caller's `$TMUX` is gone)
against either an explicit `-L` socket or the default socket inside a private
`$TMUX_TMPDIR`. **The user's real tmux server is never contacted.** All test
servers live under `/tmp/tmux-parity` and are killed at the end of each phase.

## Requirements

- Nix with the repository flake evaluable (impure is fine).
- Two built packages. By default the script uses
  `/tmp/tmux-baseline` and `/tmp/tmux-refactor`; override with the
  `BASE` / `NEW` environment variables.
- `script` (util-linux) and `pgrep` (procps) on `$PATH` — the rendered-status
  test attaches a real pty client, and the REC fragment uses `pgrep`.

Build them like:

```sh
# baseline: the tree before the refactor (e.g. the parent commit/worktree)
nix build --impure --expr \
  '(builtins.getFlake "path:/path/to/baseline/worktree").packages.x86_64-linux.tmux' \
  -o /tmp/tmux-baseline

# refactored: this tree
nix build --impure --expr \
  '(builtins.getFlake "path:/path/to/this/worktree").packages.x86_64-linux.tmux' \
  -o /tmp/tmux-refactor

BASE=/tmp/tmux-baseline NEW=/tmp/tmux-refactor \
  bash hangingGardensBabylon/tmux-feature-parity-test/run.sh
```

## What is compared

Per side, against two isolated servers (graphical/`DISPLAY` set and
console/`DISPLAY` unset):

- `show-options -g`, `-gw`, `-gs`; `show-hooks -g`
- `list-keys` and every individual key table
- `show-environment -g`, and the set of sessions created at startup
- the **rendered status line** read from an attached pty client, both with a
  live recording pid + `@task-status done` (DONE/REC/stats must appear) and
  without (they must not)
- direct probes of `status-stats.sh` and `status-taskmux-done.sh` against the
  test server
- the installed tree: `basic.conf`, `inheritedConf.conf`, the two status
  scripts, the gruvbox / tmux-grimoire / tmux-palette plugin trees, the
  `main.conf` (functional lines), and the `bin/tmux` wrapper

Everything is normalised before diffing: the two package store paths, the
volatile `@continuum-save-last-timestamp` / `@sysstat_cpu_tmp_dir` values,
digits (dates/times/CPU%), and the battery charging prefix.

## Result

`66 passed, 0 failed`. The only raw-file differences between the two
generated `main.conf` files are the new template header, the expected
store-path changes, and comments the old unquoted heredoc had mangled by
executing their backticks at build time — comments only, no configuration
change.
