#!/usr/bin/env bash
# Full feature-parity test: tmux package BEFORE the refactor (baseline) vs
# AFTER the refactor.
#
# SAFETY: every tmux invocation runs under `env -i` (so the caller's $TMUX is
# gone), against either an explicit `-L` socket or the default socket inside a
# private $TMUX_TMPDIR.  The user's real tmux server is never contacted.
#
# Captures, per side:
#   * all option tables, all hooks, every key table, server environment
#   * the *rendered* status line read from a real attached pty client
#     (detached servers never render #() fragments)
#   * direct probes of the DONE/stats status scripts
#   * the installed config/plugin tree and the wrapper
# Then everything is normalised (package path, volatile option values, digits)
# and diffed side by side.
set -u

BASE=${BASE:-/tmp/tmux-baseline}
NEW=${NEW:-/tmp/tmux-refactor}
RES=${RES:-/tmp/parity/results}
TMPD=${TMPD:-/tmp/tmux-parity}
HOMEDIR=${HOMEDIR:-/tmp/parity/home}
PIDFILE=/tmp/voice-input-recording.pid
PIDBAK=$RES/voice-input-recording.pid.bak
PATH_TAIL=/run/current-system/sw/bin

chmod -R u+w "$RES" 2>/dev/null
rm -rf "$RES" "$TMPD" "$HOMEDIR"
mkdir -p "$RES" "$TMPD" "$HOMEDIR"
BASE=$(realpath "$BASE")
NEW=$(realpath "$NEW")
[ -e "$PIDFILE" ] && cp "$PIDFILE" "$PIDBAK"

pass=0; fail=0

normpipe() { # pkg paths + volatile plugin option values (stdin)
  sed -E \
    -e "s|$BASE|@PKG@|g" \
    -e "s|$NEW|@PKG@|g" \
    -e 's/^(@continuum-save-last-timestamp|@sysstat_cpu_tmp_dir) .*/\1 @VOLATILE@/'
}
norm()  { normpipe < "$1"; }
normd() { norm "$1" | sed -E 's/[0-9]+/N/g'; }

check() { # check <name> <fileA> <fileB>   (normalised diff)
  local d="$RES/diff.$1"
  if diff -u <(norm "$2") <(norm "$3") > "$d" 2>&1; then
    echo "PASS  $1"; pass=$((pass+1))
  else echo "FAIL  $1  (see $d)"; fail=$((fail+1)); fi
}
checkd() { # checkd <name> <fileA> <fileB>  (normalised diff incl. digits)
  local d="$RES/diff.$1"
  if diff -u <(normd "$2") <(normd "$3") > "$d" 2>&1; then
    echo "PASS  $1"; pass=$((pass+1))
  else echo "FAIL  $1  (see $d)"; fail=$((fail+1)); fi
}
checkdir() { # checkdir <name> <dirA> <dirB>  (normalise contents, then diff -r)
  local d="$RES/diff.$1" na=$RES/normtree.$1.a nb=$RES/normtree.$1.b
  normtree "$2" "$na"; normtree "$3" "$nb"
  diff -r "$na" "$nb" > "$d" 2>&1
  if [ ! -s "$d" ]; then echo "PASS  $1"; pass=$((pass+1))
  else echo "FAIL  $1  (see $d)"; fail=$((fail+1)); fi
}
cmpcheck() { # cmpcheck <name> <fileA> <fileB>  (byte-identical)
  if cmp -s "$2" "$3"; then echo "PASS  $1"; pass=$((pass+1))
  else echo "FAIL  $1"; fail=$((fail+1)); fi
}
assert() { # assert <name> <shell-condition>
  if eval "$2" >/dev/null 2>&1; then echo "PASS  $1"; pass=$((pass+1))
  else echo "FAIL  $1"; fail=$((fail+1)); fi
}

normtree() { # normtree <src> <dst>: copy tree, normalise every regular file
  local f tmp
  rm -rf "$2"; cp -r "$1" "$2"; chmod -R u+w "$2"
  while IFS= read -r -d '' f; do
    tmp=$(mktemp); normpipe < "$f" > "$tmp"; cat "$tmp" > "$f"; rm -f "$tmp"
  done < <(find "$2" -type f -print0)
}

client() { # client <pkg> <socket|-> <args...>   (socket '-' = default)
  local pkg=$1 sock=$2; shift 2
  if [ "$sock" = - ]; then
    env -i HOME=$HOMEDIR TERM=xterm-256color "PATH=$pkg/bin:$PATH_TAIL" TMUX_TMPDIR=$TMPD \
      "$pkg/bin/tmux" "$@"
  else
    env -i HOME=$HOMEDIR TERM=xterm-256color "PATH=$pkg/bin:$PATH_TAIL" TMUX_TMPDIR=$TMPD \
      "$pkg/bin/tmux" -L "$sock" "$@"
  fi
}
gclient() { # gclient <pkg> <socket|-> <args...>  (DISPLAY set -> graphical branch)
  local pkg=$1 sock=$2; shift 2
  if [ "$sock" = - ]; then
    env -i HOME=$HOMEDIR TERM=xterm-256color "PATH=$pkg/bin:$PATH_TAIL" TMUX_TMPDIR=$TMPD \
      DISPLAY=:0 WAYLAND_DISPLAY=wayland-0 "$pkg/bin/tmux" "$@"
  else
    env -i HOME=$HOMEDIR TERM=xterm-256color "PATH=$pkg/bin:$PATH_TAIL" TMUX_TMPDIR=$TMPD \
      DISPLAY=:0 WAYLAND_DISPLAY=wayland-0 "$pkg/bin/tmux" -L "$sock" "$@"
  fi
}

capture_side() { # capture_side <pkg> <side> <graphical|console>
  local pkg=$1 side=$2 mode=$3
  local sock=parity-$side-$mode out=$RES/$side-$mode cli=client
  mkdir -p "$out"
  [ "$mode" = graphical ] && cli=gclient
  $cli "$pkg" "$sock" new-session -d -s probe >/dev/null 2>&1
  sleep 2
  $cli "$pkg" "$sock" show-options -g   > "$out/opts-g"
  $cli "$pkg" "$sock" show-options -gw  > "$out/opts-gw"
  $cli "$pkg" "$sock" show-options -gs  > "$out/opts-gs"
  $cli "$pkg" "$sock" show-hooks -g     > "$out/hooks-g"
  $cli "$pkg" "$sock" list-keys         > "$out/keys-full"
  : > "$out/keys-tables"
  for t in $(awk '{for(i=1;i<=NF;i++) if($i=="-T"){print $(i+1); break}}' "$out/keys-full" | sort -u); do
    echo "===== table $t =====" >> "$out/keys-tables"
    $cli "$pkg" "$sock" list-keys -T "$t" >> "$out/keys-tables" 2>&1
  done
  $cli "$pkg" "$sock" show-environment -g > "$out/env-g"
  $cli "$pkg" "$sock" list-sessions -F '#{session_name}' | sort > "$out/sessions"
  $cli "$pkg" "$sock" kill-server >/dev/null 2>&1
}

attach_capture() { # attach_capture <pkg> <outfile> <seconds>
  local pkg=$1 out=$2 secs=$3 sp cpid
  script -qec "stty rows 40 cols 220; env -i HOME=$HOMEDIR TERM=xterm-256color PATH=$pkg/bin:$PATH_TAIL TMUX_TMPDIR=$TMPD $pkg/bin/tmux attach -t probe" "$out" >/dev/null 2>&1 &
  sp=$!
  sleep "$secs"
  cpid=$(client "$pkg" - list-clients -F '#{client_pid}' 2>/dev/null | head -1)
  [ -n "$cpid" ] && kill "$cpid" 2>/dev/null
  sleep 1; kill "$sp" 2>/dev/null; wait "$sp" 2>/dev/null
}

markers() { # markers <raw pty file>: normalised set of rendered status features
  grep -aoE 'DONE|REC|PREFIX|CPU [0-9]+%|RAM [0-9]+%|[0-9]+°C|BAT [+-]?[0-9]+%|[0-9]{2}-[0-9]{2}-[0-9]{2}|[0-9]{2}:[0-9]{2}' "$1" \
    | sed -E -e 's/[0-9]+/N/g' -e 's/^BAT [+-]N%$/BAT N%/' | sort -u
}

render_side() { # render_side <pkg> <side>: attached-client rendering + script probes
  local pkg=$1 side=$2
  local out=$RES/$side-render stats done_s p
  mkdir -p "$out"
  stats=$(grep -o '/nix/store/[^ )]*tmux-status-stats.sh'         "$pkg/config/main.conf")
  done_s=$(grep -o '/nix/store/[^ )]*tmux-status-taskmux-done.sh' "$pkg/config/main.conf")
  client "$pkg" - new-session -d -s probe >/dev/null 2>&1
  sleep 2
  # --- DONE + REC present ---
  client "$pkg" - set-option -t probe @task-status done
  sleep 300 & p=$!; echo "$p" > "$PIDFILE"
  attach_capture "$pkg" "$out/on.raw" 13
  kill "$p" 2>/dev/null; rm -f "$PIDFILE"
  # --- DONE + REC absent ---
  client "$pkg" - set-option -t probe @task-status underway
  attach_capture "$pkg" "$out/off.raw" 9
  # --- direct script probes (against this server's default socket) ---
  client "$pkg" - set-option -t probe @task-status done
  env -i HOME=$HOMEDIR TERM=xterm-256color "PATH=$pkg/bin:$PATH_TAIL" TMUX_TMPDIR=$TMPD \
    tmux="$pkg/bin/tmux" "$done_s" > "$out/done-direct"
  client "$pkg" - set-option -t probe @task-status underway
  env -i HOME=$HOMEDIR TERM=xterm-256color "PATH=$pkg/bin:$PATH_TAIL" TMUX_TMPDIR=$TMPD \
    tmux="$pkg/bin/tmux" "$done_s" > "$out/undone-direct"
  env -i HOME=$HOMEDIR TERM=xterm-256color "PATH=$pkg/bin:$PATH_TAIL" TMUX_TMPDIR=$TMPD \
    interval=1 "$stats" > "$out/stats-direct"
  client "$pkg" - kill-server >/dev/null 2>&1
  markers "$out/on.raw"  > "$out/on.markers"
  markers "$out/off.raw" > "$out/off.markers"
}

tree_side() { # tree_side <pkg> <side>
  local pkg=$1 side=$2
  local out=$RES/$side-tree; mkdir -p "$out"
  cp -r "$pkg/config" "$out/config"; chmod -R u+w "$out"
  cp "$pkg/bin/tmux" "$out/wrapper"
  "$pkg/bin/tmux" -V > "$out/version" 2>&1
}

echo "=== capturing baseline ($BASE) ==="
capture_side "$BASE" base graphical
capture_side "$BASE" base console
render_side  "$BASE" base
tree_side    "$BASE" base

echo "=== capturing refactored ($NEW) ==="
capture_side "$NEW" new graphical
capture_side "$NEW" new console
render_side  "$NEW" new
tree_side    "$NEW" new

echo "=== comparisons ==="
for m in graphical console; do
  for f in opts-g opts-gw opts-gs hooks-g keys-full keys-tables env-g sessions; do
    check "$f.$m" "$RES/base-$m/$f" "$RES/new-$m/$f"
  done
done
check "render.on.markers"  "$RES/base-render/on.markers"  "$RES/new-render/on.markers"
check "render.off.markers" "$RES/base-render/off.markers" "$RES/new-render/off.markers"
check "done-direct"        "$RES/base-render/done-direct"   "$RES/new-render/done-direct"
check "undone-direct"      "$RES/base-render/undone-direct" "$RES/new-render/undone-direct"
checkd "stats-direct"      "$RES/base-render/stats-direct"  "$RES/new-render/stats-direct"

# --- installed tree parity ---------------------------------------------------
cmpcheck "tree.basic.conf"         "$RES/base-tree/config/basic.conf"         "$RES/new-tree/config/basic.conf"
cmpcheck "tree.inheritedConf.conf" "$RES/base-tree/config/inheritedConf.conf" "$RES/new-tree/config/inheritedConf.conf"
cmpcheck "tree.status-stats.sh" \
  "$(nix-store -q --requisites "$BASE" | grep 'tmux-status-stats.sh$')" \
  "$(nix-store -q --requisites "$NEW"  | grep 'tmux-status-stats.sh$')"
cmpcheck "tree.status-taskmux-done.sh" \
  "$(nix-store -q --requisites "$BASE" | grep 'tmux-status-taskmux-done.sh$')" \
  "$(nix-store -q --requisites "$NEW"  | grep 'tmux-status-taskmux-done.sh$')"
checkdir "tree.gruvbox"      "$RES/base-tree/config/gruvbox"      "$RES/new-tree/config/gruvbox"
checkdir "tree.tmux-grimoire" "$RES/base-tree/config/tmux-grimoire" "$RES/new-tree/config/tmux-grimoire"
checkdir "tree.tmux-palette"  "$RES/base-tree/config/tmux-palette"  "$RES/new-tree/config/tmux-palette"
check    "tree.wrapper"      "$RES/base-tree/wrapper"             "$RES/new-tree/wrapper"
cmpcheck "tree.tmux -V"      "$RES/base-tree/version"             "$RES/new-tree/version"

strip_comments() { grep -v '^[[:space:]]*#' "$1" | grep -v '^[[:space:]]*$' | sed "s|$BASE|@PKG@|g;s|$NEW|@PKG@|g" | sed 's/[[:space:]]\+/ /g'; }
if diff -u <(strip_comments "$RES/base-tree/config/main.conf") \
           <(strip_comments "$RES/new-tree/config/main.conf") > "$RES/diff.main.conf.functional" 2>&1; then
  echo "PASS  tree.main.conf.functional"; pass=$((pass+1))
else
  echo "FAIL  tree.main.conf.functional  (see $RES/diff.main.conf.functional)"; fail=$((fail+1))
fi

# --- feature assertions ------------------------------------------------------
assert "render.on.has-DONE.base"  'grep -qx DONE "$RES/base-render/on.markers"'
assert "render.on.has-DONE.new"   'grep -qx DONE "$RES/new-render/on.markers"'
assert "render.on.has-REC.base"   'grep -qx REC "$RES/base-render/on.markers"'
assert "render.on.has-REC.new"    'grep -qx REC "$RES/new-render/on.markers"'
assert "render.on.has-stats.base" 'grep -q "^CPU N%$" "$RES/base-render/on.markers" && grep -q "^RAM N%$" "$RES/base-render/on.markers"'
assert "render.on.has-stats.new"  'grep -q "^CPU N%$" "$RES/new-render/on.markers" && grep -q "^RAM N%$" "$RES/new-render/on.markers"'
assert "render.off.no-DONE.base"  '! grep -qx DONE "$RES/base-render/off.markers"'
assert "render.off.no-DONE.new"   '! grep -qx DONE "$RES/new-render/off.markers"'
assert "render.off.no-REC.base"   '! grep -qx REC "$RES/base-render/off.markers"'
assert "render.off.no-REC.new"    '! grep -qx REC "$RES/new-render/off.markers"'
assert "done.direct.base"         'grep -qx DONE "$RES/base-render/done-direct"'
assert "done.direct.new"          'grep -qx DONE "$RES/new-render/done-direct"'
assert "done.direct.off"          '[ ! -s "$RES/base-render/undone-direct" ] && [ ! -s "$RES/new-render/undone-direct" ]'
assert "stats.format"             'grep -Eq "^CPU [0-9]+% \| RAM [0-9]+%" "$RES/base-render/stats-direct" && grep -Eq "^CPU [0-9]+% \| RAM [0-9]+%" "$RES/new-render/stats-direct"'
assert "voice.console.userkeys"   'grep -q "user-keys" "$RES/base-console/opts-gs" && grep -q "user-keys" "$RES/new-console/opts-gs"'
assert "voice.console.binding"    'grep -q " User0 " "$RES/base-console/keys-tables" && grep -q " User0 " "$RES/new-console/keys-tables"'
assert "voice.graphical.flag"     'grep -q "@voice-input-graphical-session on" "$RES/base-graphical/opts-g" && grep -q "@voice-input-graphical-session on" "$RES/new-graphical/opts-g"'
assert "voice.graphical.nobinding" '! grep -q " User0 " "$RES/base-graphical/keys-tables" && ! grep -q " User0 " "$RES/new-graphical/keys-tables"'
assert "plugins.grimoire.keys"    'grep -q "prefix f " "$RES/base-graphical/keys-tables" && grep -q "prefix X " "$RES/base-graphical/keys-tables" && grep -q "prefix F " "$RES/base-graphical/keys-tables" && grep -q "prefix H " "$RES/base-graphical/keys-tables" && grep -q "prefix f " "$RES/new-graphical/keys-tables" && grep -q "prefix X " "$RES/new-graphical/keys-tables"'
assert "plugins.palette.key"      'grep -q "C-Space" "$RES/base-graphical/keys-full" && grep -q "C-Space" "$RES/new-graphical/keys-full"'
assert "plugins.taskmux.key"      'grep -q "C-t " "$RES/base-graphical/keys-full" && grep -q "C-t " "$RES/new-graphical/keys-full"'
assert "plugins.resurrect.keys"   'grep -q "C-s" "$RES/base-graphical/keys-tables" && grep -q "C-s" "$RES/new-graphical/keys-tables"'
assert "plugins.sysstat"          'grep -q "sysstat" "$RES/base-graphical/opts-g" && grep -q "sysstat" "$RES/new-graphical/opts-g"'
assert "plugins.continuum"        'grep -q "@continuum-restore on" "$RES/base-graphical/opts-g" && grep -q "@continuum-restore on" "$RES/new-graphical/opts-g"'
assert "plugins.gruvbox.status"   'grep -q "@tmux-gruvbox-right-status-x" "$RES/base-graphical/opts-g" && grep -q "@tmux-gruvbox-right-status-x" "$RES/new-graphical/opts-g"'
assert "config.prefix"            'grep -q "^prefix C-a$" "$RES/base-graphical/opts-g" && grep -q "^prefix C-a$" "$RES/new-graphical/opts-g"'
assert "config.two-line"          'grep -q "^status 2$" "$RES/base-graphical/opts-g" && grep -q "^status 2$" "$RES/new-graphical/opts-g"'
assert "config.default-shell"     'grep -q "^default-shell /nix/store/.*bash" "$RES/base-graphical/opts-g" && grep -q "^default-shell /nix/store/.*bash" "$RES/new-graphical/opts-g"'
assert "wrapper.loads.conf"       'grep -q "config/main.conf" "$RES/base-tree/wrapper" && grep -q "config/main.conf" "$RES/new-tree/wrapper"'
assert "build.no-placeholders"    '! grep -qE "@(defaultShell|rawTmuxBin|statusTaskmuxDoneScript|statusStatsScript|taskmuxExe|voiceInput|out)@" "$RES/new-tree/config/main.conf"'
assert "build.no-dollar-out"      '! grep -q "\$out/" "$RES/new-tree/config/main.conf"'
assert "build.no-stale-path"      '! grep -rq "$BASE" "$RES/new-tree/config" && ! grep -rq "$NEW" "$RES/base-tree/config"'
assert "grimoire.pinned"          'grep -q "$BASE/bin/tmux" "$RES/base-tree/config/tmux-grimoire/grimoire.tmux" && grep -q "$NEW/bin/tmux" "$RES/new-tree/config/tmux-grimoire/grimoire.tmux"'
assert "grimoire.no-path-mut"     '! grep -q "set-environment -g PATH" "$RES/base-tree/config/tmux-grimoire/grimoire.tmux" && ! grep -q "set-environment -g PATH" "$RES/new-tree/config/tmux-grimoire/grimoire.tmux"'
assert "palette.pinned"           'grep -q "$BASE/bin/tmux" "$RES/base-tree/config/tmux-palette/bin/tmux-palette.sh" && grep -q "$NEW/bin/tmux" "$RES/new-tree/config/tmux-palette/bin/tmux-palette.sh" && ! grep -q "exec bun " "$RES/base-tree/config/tmux-palette/bin/tmux-palette.sh" && ! grep -q "exec bun " "$RES/new-tree/config/tmux-palette/bin/tmux-palette.sh"'

[ -s "$PIDBAK" ] && cp "$PIDBAK" "$PIDFILE"

echo
echo "=== RESULT: $pass passed, $fail failed ==="
[ "$fail" -eq 0 ]
