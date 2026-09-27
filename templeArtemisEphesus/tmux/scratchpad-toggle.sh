#!/usr/bin/env bash
# scratchpad-toggle.sh -- toggle the shared "scratchpad" shell popup.
#
# Bound to M+ (Meta+Shift+Equal) in main.conf.in, console-only (the binding
# is only installed when there is no graphical session, see the if-shell
# there): one keypress opens a large centered floating popup running a
# shell, the next keypress closes it again, like a dropdown terminal
# (Guake/Yakuake style).
#
# The popup is not a throwaway `bash' popup: it attaches to a dedicated,
# persistent tmux session named "scratchpad" (created on first use).  That
# way the scratchpad keeps its state across toggles -- working directory,
# shell history, scrollback and anything running in it (a long build, an
# editor, ...) survive closing the popup, exactly what a scratchpad user
# expects.  The session is created without its own status bar (`status
# off'), so the popup shows only the shell, and since the popup only ever
# appears over the attached client it never shows up in the status bar's
# window list either.
#
# The toggle works through *two* invocations of this script, because of
# how tmux delivers keys while a popup is open: key bindings of the
# summoning client do not fire while its popup is up -- keypresses go
# into the popup pane instead.  The popup runs a tmux *client* (an
# `attach' of the scratchpad session), so that client parses the very
# same M+ and runs this script a second time, now from inside the popup:
#
#   * invoked from a normal client (its session is not "scratchpad"):
#     open the popup on that client.
#   * invoked from the popup's attach client (its session IS
#     "scratchpad"): detach that client.  The popup command is run with
#     `-E', so the popup closes as soon as its command exits -- and
#     detaching makes the attach client exit.  The scratchpad session
#     itself stays alive on the server, detached, so its state survives.
#
# No extra state (files, options) is needed to tell the two cases apart:
# the invoking client's session name is the discriminator, and every
# attached client can toggle its own popup independently (all popups
# attach to the one shared scratchpad session, so the state between them
# is the same -- which is what a scratchpad is for).
#
# Everything the script needs is passed in at build/run time (see
# main.conf.in):
#   $1  target client   (#{client_name}, expanded by tmux before run-shell)
#   $2  tmux binary     (absolute store path; run-shell jobs only inherit
#                       the invoking client's environment, which need not
#                       have tmux on PATH -- and must not find some *other*
#                       server's tmux than the one the key was pressed in)
#   The server socket itself is taken from TMUX (run-shell jobs always
#   have it, "/path/to/socket,pid,session"): the popup's attach client
#   must reach the *same* server, and since tmux refuses to attach while
#   TMUX is set ("sessions should be nested with care"), TMUX is unset
#   and the socket is passed explicitly with -S instead.
set -euo pipefail

client="${1:?missing client}"
tmux_bin="${2:?missing tmux binary}"
scratch_session=scratchpad

socket="${TMUX%%,*}"
if [ -z "$socket" ]; then
    echo "scratchpad: TMUX is not set, cannot determine server socket" >&2
    exit 1
fi

# Is the key press coming from inside the scratchpad popup?  The popup's
# attach client is attached to the scratchpad session, so its
# #{client_session} is "scratchpad" -- while a normal client's is
# whatever session it is on.  For the attach client, detaching *is* the
# close half of the toggle: the attach exits, and the popup (opened with
# -E) closes with it.
client_session="$("$tmux_bin" -S "$socket" display-message -p -c "$client" '#{client_session}' 2>/dev/null || true)"
if [ "$client_session" = "$scratch_session" ]; then
    "$tmux_bin" -S "$socket" detach-client -t "$client"
    exit 0
fi

# Normal client, popup closed: make sure the scratchpad session exists
# (it may have died earlier, e.g. if the user exited its shell), then
# open the popup.  -E closes the popup again when the attach client
# exits -- be it via the M+ detach above, Escape, or the shell exiting.
if ! "$tmux_bin" -S "$socket" has-session -t "$scratch_session" 2>/dev/null; then
    "$tmux_bin" -S "$socket" new-session -d -s "$scratch_session" -n scratch
    # the scratchpad popup shows only the shell, no status bar inside it
    "$tmux_bin" -S "$socket" set-option -t "$scratch_session" status off
fi
"$tmux_bin" -S "$socket" display-popup -c "$client" -w 90% -h 90% -E \
    "exec env -u TMUX $tmux_bin -S $socket attach -t $scratch_session"
