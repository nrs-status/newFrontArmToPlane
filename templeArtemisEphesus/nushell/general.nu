# ─────────────────────────────────────────────────────────────
# base settings
# ─────────────────────────────────────────────────────────────

$env.config.show_banner = false
$env.config.edit_mode = "emacs"
$env.config.history.file_format = "sqlite"
$env.config.history.isolation = true

# ─────────────────────────────────────────────────────────────
# git aliases (nushell has no abbreviations — plain aliases are
# the direct analog of fish's `abbr -a` entries)
# ─────────────────────────────────────────────────────────────

$env.config.abbreviations = {
    g: git
    ga: git add
    gb: git branch
    gc: git commit
    gcm: git commit --message
}
alias gd = git diff
alias gl = git log
alias glo = git log --oneline
alias glg = git log --graph --oneline --decorate --all
alias gpu = git push --set-upstream origin
alias grst = git restore --staged
alias gss = git status --short
alias gssb = git status --short --branch
alias gsw = git switch
alias gswc = git switch --create

# wt aliases: nushell type-checks flags at parse time, so aliases forwarding
# worktrunk flags (e.g. `wtsc = wt switch --create`) cannot be defined against
# the `wt` custom command. Use `wt switch --create` directly instead.

# zoxide
alias zq = zoxide query

# eza
alias ezlsm = eza -ls modified
alias ezlsc = eza -ls created
alias ezlsa = eza -ls accessed

# nix
alias sunrsf = sudo nixos-rebuild switch --flake
alias nrsf = nixos-rebuild switch --flake
alias sunfu = sudo nix flake update
alias nfu = nix flake update

alias nr = nix run
alias nd = nix develop
alias ns = nix shell
alias nb = nix build
alias nbnp = nix build --no-link --print-out-paths
alias nbpn = nix build --no-link --print-out-paths
alias nreg = nix registry

# neovim
alias nR = nvim -R

# pi
alias pir = pi "Read and execute ./instructions.txt"

# ─────────────────────────────────────────────────────────────
# git aliases (custom commands — the analog of fish functions,
# they survive "abbreviation expansion issues")
# ─────────────────────────────────────────────────────────────

# Compact status
alias gs = git status -sb

# Pretty one-line log with graph
alias gl2 = git log --graph --oneline --decorate --all

# Last commit
alias glast = git log -1 --stat

# Diff helpers
alias gds = git diff --staged
alias gdw = git diff --word-diff

# Undo last commit, keeping changes staged
def gundo [] {
    git reset --soft HEAD~1
}

# Push current branch, setting upstream if needed
def gps [] {
    git push -u origin (git branch --show-current)
}

# Show files changed in a commit
alias gshow = git show --stat --oneline

# List local branches with last commit date, newest first
def gbl [] {
    git for-each-ref --sort=-committerdate refs/heads/ --format='%(committerdate:short) %(refname:short) %(subject)'
}

# Quick amend without editing the message
alias gamend = git commit --amend --no-edit
