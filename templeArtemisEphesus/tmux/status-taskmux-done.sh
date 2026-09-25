#!/usr/bin/env bash
# status-taskmux-done.sh -- tmux status-bar segment, rendered immediately to
# the left of the CPU/RAM/temperature stats module: prints "DONE" when
# `taskmux list' would display at least one task that is done, and prints
# nothing otherwise (so the segment is simply omitted when no task is done).
# The separating space between "DONE" and the stats module is part of the
# status-right fragment in default.nix, NOT of this output: tmux trims
# leading/trailing whitespace off #( ) fragment output, so a leading space
# printed here would disappear.
#
# taskmux stores a session's task state in the session options
# @task-status ("underway" / "done") and @task-description: `taskmux done'
# sets @task-status to "done" and `taskmux list' lists every session that
# carries a task state as "<session>: <status> - <description>".  So
# "`taskmux list' displays at least one task that is done" is exactly
# "some tmux session has @task-status = done", which is what this script
# checks.  The session options are queried directly instead of running
# `taskmux list' itself because taskmux list is an interactive,
# self-redrawing menu (it loops refreshing its output), which is not
# usable inside a tmux #( ) status fragment.
#
# The tmux client is passed in via the `tmux' environment variable
# (pinned to the store path of this tmux package's own client by the
# status-right fragment in default.nix): #( ) fragments become run-shell
# jobs, which only inherit the invoking client's environment -- that may
# not contain tmux on PATH at all (e.g. a server started from systemd),
# so the unqualified `tmux' cannot be relied on.  The client only
# connects to the running server (list-sessions); it never starts a
# server and never loads the tmux config.
#
# tmux re-evaluates #( ) fragments at most once per status-interval, so
# the marker follows `taskmux done' / `taskmux clear' with at most one
# status-interval of delay.  If no tmux server is reachable the query
# fails and the script prints nothing -- the segment is omitted, as
# required.
statuses=$("${tmux:-tmux}" list-sessions -F '#{@task-status}' 2>/dev/null) || exit 0
case $statuses in
    *done*) printf 'DONE' ;;
esac