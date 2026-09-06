# worktrunk shell integration for nushell
#
# This is the nushell analog of the fish `wt` function: it overrides the `wt`
# command with split directive passing. It creates two temp files: one for cd
# (raw path) and one for exec (shell). WORKTRUNK_BIN can override the binary
# path (for testing dev builds).
#
# Note: the exec directive cannot be `eval`uated inside the running nushell
# process (nushell has no eval), so it is executed via a nested `nu -c`.

def wt [
    ...rest: string  # arguments passed to worktrunk (`--source` is intercepted)
] {
    let use_source = ("--source" in $rest)
    let args = ($rest | where $it != "--source")

    # only look at external binaries — `which` also sees this very `wt`
    # custom command, so use --all and filter
    let ext = (which --all wt | where type == "external")

    # resolve binary or bail out (return only works at def top level)
    if ($env.WORKTRUNK_BIN? | is-empty) and ($ext | is-empty) {
        print -e "wt: command not found"
        return 127
    }
    let worktrunk_bin = if ($env.WORKTRUNK_BIN? | is-empty) {
        $ext | get 0.path
    } else {
        $env.WORKTRUNK_BIN
    }

    let cd_file = (mktemp)
    let exec_file = (mktemp)

    let exit_code = if $use_source {
        # --source: use cargo run (builds from source)
        do {
            with-env {
                WORKTRUNK_DIRECTIVE_CD_FILE: $cd_file
                WORKTRUNK_DIRECTIVE_EXEC_FILE: $exec_file
            } {
                cargo run --bin wt --quiet ...$args
                $env.LAST_EXIT_CODE
            }
        }
    } else {
        do {
            with-env {
                WORKTRUNK_DIRECTIVE_CD_FILE: $cd_file
                WORKTRUNK_DIRECTIVE_EXEC_FILE: $exec_file
            } {
                ^$worktrunk_bin ...$args
                $env.LAST_EXIT_CODE
            }
        }
    }

    # cd file holds a raw path — read and cd into it (safe even if CWD was
    # removed by worktree removal).
    if ($cd_file | path exists) {
        let target = (open --raw $cd_file | str trim)
        if ($target != "") {
            cd $target
        }
    }

    # exec file holds arbitrary shell (e.g. from --execute)
    if ($exec_file | path exists) {
        let directive = (open --raw $exec_file | str trim)
        if ($directive != "") {
            nu -c $directive
        }
    }

    rm -f $cd_file $exec_file
    $exit_code
}
