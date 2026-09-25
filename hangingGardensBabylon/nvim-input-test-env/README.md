# nvim-input-test-env

A debugging environment for answering one question:

> When I press a key (or a key binding) in Neovim, what did Neovim actually
> receive, and how did it interpret it?

It runs the repository's `full` nixvim profile
(`templeArtemisEphesus/montezumaCirclesScroll`) underneath a pseudo-terminal
tap, and writes two kinds of records into a single log file:

| tag    | produced by                  | meaning                                                  |
| ------ | ---------------------------- | -------------------------------------------------------- |
| `USER` | `input-tap.py`               | raw bytes that arrived on the input stream               |
| `NVIM` | `vim.on_key` (`nvim-key-log.lua`) | each key Neovim processed, in which mode, after/before mappings |

`tail -f`ing that file therefore shows the raw stream the terminal delivered
next to the keypresses Neovim "registered".

## How it works

* `flake.nix` takes the parent repository (`path:/...`, see the note inside
  `flake.nix`) as an input and reuses
  `packages.x86_64-linux.montezumaCirclesScroll.full`. The environment
  therefore loads *exactly* the same `full` config as the rest of the repo.
* The generated `nvim-input-test` wrapper runs that `full` binary under
  `input-tap.py`.
* `input-tap.py` allocates a fresh pty, runs Neovim on the slave side, pumps
  bytes between the caller's tty and Neovim, and appends every chunk read
  from the caller's tty to the log as a `[USER ...]` line.
* The wrapper also passes
  `--cmd "lua dofile([[<...>-nvim-key-log.lua]])"`. `--cmd` runs *before*
  nixvim sources `VIMINIT`/`init.lua`, so `vim.on_key` is installed before the
  `full` profile loads and sees every key afterwards. Each key becomes a
  `[NVIM ...]` line (same log file, `O_APPEND`).

## Usage

From this directory:

```bash
# build (optional; `nix run`/`nix develop` build on demand)
nix build

# in one pane: follow the log
tail -f "${NVIM_INPUT_LOG:-/tmp/nvim-input-test-env/nvim-input.log}"

# in another pane: start the instrumented Neovim
nix run                       # or: nix develop, then `nvim-input-test`
nvim-input-test some/file     # forwards arguments to Neovim
```

Override the log location with `NVIM_INPUT_LOG=/some/path nvim-input-test`.
The wrapper creates the parent directory automatically.

## Log format

```
[USER 21:21:28] iHELLO
[NVIM 21:21:28] mode=n     key=i                  typed=i
[NVIM 21:21:28] mode=i     key=H                  typed=
...
[NVIM 21:21:28] mode=n     key=:                  typed=<Space>ww           maparg(<Space>ww)=:  [mapping <Space>ww -> :]
```

* `mode` is the mode reported by `nvim_get_mode()` when the key was seen.
* `key` is the key **after** mappings have been applied - i.e. what Neovim
  actually registered.
* `typed` is the key(s) **before** mappings - i.e. what Neovim thinks was
  typed. When it differs from `key`, a `[mapping typed -> key]` note is added,
  and `maparg(...)` shows the resolved right-hand side.
* Non-printable bytes are rendered as `<Esc>`, `<CR>`, `<Tab>`, `<BS>`,
  `<Space>` or `<0xNN>`.

## Caveats

* `typed` can be polluted by plugins that call `nvim_feedkeys`/`nvim_input`
  with the "typed" flag (the `full` profile has several, e.g. `tabKeyFunc.lua`).
  `key` is the authoritative record of what Neovim registered; a `typed` value
  that contains characters you never pressed is itself a useful signal that
  something is injecting input. Compare against a bare
  `nvim -u NONE` run (see the `SUMMARY.md` notes) to confirm the logger is
  transparent.
* The terminal emulator answers Neovim's startup queries (synchronized output,
  cursor style, DA1, ...). Those response bytes travel over the same input
  stream and are logged too. They are what the `[USER ...]` lines with
  `<Esc>[?...` sequences are.
* The log grows without bound; it is meant to be `tail`ed, not archived.
* `git add -N` is used on the files in this directory so that Nix (which only
  copies git-visible files out of a repository) can see them. Nothing is
  committed.
