# ─────────────────────────────────────────────────────────────
# base settings
# ─────────────────────────────────────────────────────────────

$env.config.show_banner = false
$env.config.edit_mode = "vi"
$env.config.history.file_format = "sqlite"
$env.config.history.isolation = true

# ─────────────────────────────────────────────────────────────
# abbreviations (the analog of fish's `abbr -a` entries)
# ─────────────────────────────────────────────────────────────

$env.config.abbreviations = {
    g: git
    ga: "git add"
    gb: "git branch"
    gc: "git commit"
    gcm: "git commit --message"
    gd: "git diff"
    gl: "git log"
    glo: "git log --oneline"
    glg: "git log --graph --oneline --decorate --all"
    gpu: "git push --set-upstream origin"
    grst: "git restore --staged"
    gss: "git status --short"
    gssb: "git status --short --branch"
    gsw: "git switch"
    gswc: "git switch --create"
    gs: "git status -sb"
    gl2: "git log --graph --oneline --decorate --all"
    glast: "git log -1 --stat"
    gds: "git diff --staged"
    gdw: "git diff --word-diff"
    gshow: "git show --stat --oneline"
    gamend: "git commit --amend --no-edit"

    # wt: nushell type-checks flags at parse time, so aliases forwarding
    # worktrunk flags (e.g. `wtsc = wt switch --create`) cannot be defined
    # against the `wt` custom command. Use `wt switch --create` directly instead.

    # zoxide
    zq: "zoxide query"

    # eza
    ezlsm: "eza -ls modified"
    ezlsc: "eza -ls created"
    ezlsa: "eza -ls accessed"

    # nix
    sunrsf: "sudo nixos-rebuild switch --flake"
    nrsf: "nixos-rebuild switch --flake"
    sunfu: "sudo nix flake update"
    nfu: "nix flake update"
    nr: "nix run"
    nd: "nix develop"
    ns: "nix shell"
    nb: "nix build"
    nbnp: "nix build --no-link --print-out-paths"
    nbpn: "nix build --no-link --print-out-paths"
    nreg: "nix registry"

    # neovim
    nR: "nvim -R"

    # pi
    pir: 'pi "Read and execute ./instructions.txt"'
}

# ─────────────────────────────────────────────────────────────
# git custom commands (the analog of fish functions,
# they survive "abbreviation expansion issues")
# ─────────────────────────────────────────────────────────────

# Undo last commit, keeping changes staged
def gundo [] {
    git reset --soft HEAD~1
}

# Push current branch, setting upstream if needed
def gps [] {
    git push -u origin (git branch --show-current)
}

# List local branches with last commit date, newest first
def gbl [] {
    git for-each-ref --sort=-committerdate refs/heads/ --format='%(committerdate:short) %(refname:short) %(subject)'
}
