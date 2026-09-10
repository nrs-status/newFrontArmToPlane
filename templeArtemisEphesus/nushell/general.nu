
$env.config.show_banner = false
$env.config.edit_mode = "vi"
$env.config.history.file_format = "sqlite"
$env.config.history.isolation = true

$env.config.completions.algorithm = "Fuzzy" #allows incomplete paths, e.g. /a/b/c will match the completion /axaxax/bxbxbx/cxcxcxc

# ─────────────────────────────────────────────────────────────
# fish-style ghost completion, sourced from atuin history
# ─────────────────────────────────────────────────────────────

# While typing, the most recent entry in atuin's sqlite history that
# extends the current line (preferably one from this directory) is shown
# as dim "ghost" text after the cursor. Accept the whole hint with → or
# Ctrl+f, word-by-word with Alt+f — built-in reedline defaults.
#
# Why a custom hinter: nushell's built-in hinter (reedline's
# `CwdAwareHinter`, the default when `hinter.closure` is null) only reads
# nushell's own history file ($nu.history-path) — and with
# `$env.config.history.isolation = true` that shrinks to the commands
# typed in this very session. All shell history is recorded to atuin by
# the `atuin init nu` hooks (sourced in config.nu as atuinConfig.nu), so
# the ghost completion is wired to atuin's database instead, via
# nushell's external hinter closure (`$env.config.hinter.closure`,
# supported since nu 0.104; see crates/nu-cli/src/hints/external_hinter.rs
# in the nushell repo). The closure receives `{line, pos, cwd}` and must
# return the hint (the suffix that would complete the line) as a string,
# a `{hint: string}` record, or null for "no suggestion".
$env.config.show_hints = true

# the ghost text itself: dim + italic, the fish autosuggestion look
# (the `hints` color_config entry is applied to the external hinter too,
# see `style_computer.compute("hints", ...)` in crates/nu-cli/src/repl.rs)
$env.config.color_config.hints = { fg: "dark_gray", attr: "i" }

# sqlite db atuin records commands into; ATUIN_DB_PATH mirrors atuin's
# own env override of its data dir
def atuin-history-db [] {
    $env.ATUIN_DB_PATH? | default ($nu.home-dir | path join ".local/share/atuin/history.db")
}

$env.config.hinter.closure = {|ctx|
    # text up to the cursor is what the suggestion must extend
    let prefix = ($ctx.line | str substring 0..<$ctx.pos)

    # nothing typed yet → nothing to suggest
    if ($prefix | str trim | is-empty) { return null }

    # exact-prefix match (`substr(command, 1, length(?1)) = ?1` instead of
    # LIKE, so `%`/`_` in the input don't act as wildcards), cwd-aware like
    # the built-in CwdAwareHinter: entries from the current directory beat
    # older ones from elsewhere; newest first otherwise. `command != ?1`
    # keeps atuin from suggesting the line itself.
    open (atuin-history-db)
    | query db "SELECT command FROM history
                WHERE deleted_at IS NULL
                  AND substr(command, 1, length(?1)) = ?1
                  AND command != ?1
                ORDER BY (cwd = ?2) DESC, timestamp DESC
                LIMIT 1" --params [$prefix, $ctx.cwd]
    | get command.0? | default null
    # only the suffix after the cursor is shown as ghost text
    | if $in == null { null } else { $in | str substring ($prefix | str length).. }
}

# modules (vendored from github:nushell/nu_scripts)
use jc.nu
use result.nu
use std/dirs

# activate the `result` module (see result.nu header comment):
# every displayed output is stored and retrievable via `result`, `result ls`, `result select`
$env.config.hooks.display_output = {
    result hook | if (term size).columns >= 100 { table -e } else { table }
}

$env.config.abbreviations = {
    g: git
    ga: "git add"
    gb: "git branch"
    gbd: "git branch -d"
    gbD: "git branch -D"
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
    glast: "git log -1 --stat"
    gds: "git diff --staged"
    gdw: "git diff --word-diff"
    gsh: "git show --stat --oneline"
    gamend: "git commit --amend --no-edit"

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
    nre: "nix registry"
    nrel: "nix registry list"
    nrer: "nix registry remove"
    nrea: "nix registry add"

    # neovim
    nR: "nvim -R"

    # pi
    pir: 'pi "Read and execute ./instructions.txt"'

    #wt
    wts: "wt switch"
    wtsc: "wt switch --create"
    wtr: "wt remove"
    wtrDf: "wt remove -D --force"
    wtm: "wt merge"
    wtmm: "wt merge main"
    wtl: "wt list"

    #broot
    br: "broot"

    #nushell
    f: "first"
    l: "lines"
    w: "where"
    o: "open"
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

# ------------------- other

#menu of previous dirs and keybinding

$env.config.menus ++= [
    {
        # List all unique successful commands
        name: "working_dirs_menu"
        only_buffer_difference: true
        marker: "? "
        type: {
            layout: list
            page_size: 23
        }
        style: {
            text: green
            selected_text: green_reverse
        }
        source: {|buffer, position|
            open $nu.history-path
            | query db "SELECT DISTINCT(cwd) FROM history ORDER BY id DESC"
            | get CWD
            | into string
            | where $it =~ $buffer
            | compact --empty
            | each {
                if ($in has ' ') { $'"($in)"' } else {}
                | {value: $in}
            }
        }
    }
]
$env.config.keybindings ++= [{
    name: "working_dirs_cd_menu"
    modifier: "alt_shift"
    keycode: "char_r"
    mode: [emacs, vi_normal, vi_insert]
    event: {send: menu name: working_dirs_cd_menu}
}]

# Shadows `nix registry list` so it returns a table with columns: owner, flakeref, ui.
def "nix registry list" [...args: string] {
    ^nix registry list ...$args
    | detect columns --no-headers
    | rename owner flakeref uri
}


# add broot path paster
#  `broot-source` command enables syntax highlighting in edit mode.
def broot-source [] {
    let $broot_closure = {
        let $cl = commandline
        let $pos = commandline get-cursor

        #find token under cursor
        let $element = ast --flatten $cl
            | flatten
            | where start <= $pos and end >= $pos
            | get content.0 -o
            | default ''

        #if cursor is on a path, open broot there, else open in current dir
        let $path_exp = $element
            | str trim -c '"'
            | str trim -c "'"
            | str trim -c '`'
            | if $in =~ '^~' { path expand } else {}
            | if ($in | path exists) {} else {'.'}

        #run broot and quote result
        let $broot_path = ^broot $path_exp
            | if ' ' in $in { $"`($in)`" } else {}

        #put result on command line
        if $path_exp == '.' {
            commandline edit --insert $broot_path
        } else {
            $cl | str replace $element $broot_path | commandline edit -r $in
        }
    }

    view source $broot_closure | lines | skip | drop | to text
}

$env.config.keybindings ++= [
    {
         name: broot_path_completion
         modifier: control
         keycode: char_t
         mode: [emacs, vi_normal, vi_insert]
         event: [
            {
                send: ExecuteHostCommand
                cmd: (broot-source)
            }
        ]
    }
]
