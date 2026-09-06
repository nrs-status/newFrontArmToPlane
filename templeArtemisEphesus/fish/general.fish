# ─────────────────────────────────────────────────────────────
# git abbreviations (expanded before execution)
# ─────────────────────────────────────────────────────────────

abbr -a g git
abbr -a ga git add
abbr -a gb git branch
abbr -a gc git commit
abbr -a gcm git commit --message
abbr -a gd git diff
abbr -a gl git log
abbr -a glo git log --oneline
abbr -a glg git log --graph --oneline --decorate --all
abbr -a gpu git push --set-upstream origin (git branch --show-current 2>/dev/null)
abbr -a grst git restore --staged
abbr -a gs git status
abbr -a gsw git switch
abbr -a gswc git switch --create

# ─────────────────────────────────────────────────────────────
# git aliases (functions — survive abbreviation expansion issues)
# ─────────────────────────────────────────────────────────────

# Compact status
alias gs='git status -sb'

# Pretty one-line log with graph
alias gl='git log --graph --oneline --decorate --all'

# Last commit
alias glast='git log -1 --stat'

# Diff helpers
alias gd='git diff'
alias gds='git diff --staged'
alias gdw='git diff --word-diff'

# Undo last commit, keeping changes staged
alias gundo='git reset --soft HEAD~1'

# Push current branch, setting upstream if needed
alias gps='git push -u origin (git branch --show-current)'

# Show files changed in a commit
alias gshow='git show --stat --oneline'

# List local branches with last commit date, newest first
alias gbl='git for-each-ref --sort=-committerdate refs/heads/ --format=\'%(committerdate:short) %(refname:short) %(subject)\''

# Quick amend without editing the message
alias gamend='git commit --amend --no-edit'

