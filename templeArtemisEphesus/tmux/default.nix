{ pkgs, pkgsLib, newPkgs, ... }:
let
  # gruvbox theme plugin for the tmux status line / pane colors
  themePlugin = pkgs.tmuxPlugins.gruvbox;

  # the four plugins referenced from the generated inheritedConf (see below)
  # via `run-shell' lines.  Because the conf is produced by string
  # interpolation of these derivations, the store paths in it are always the
  # ones of *this* build's nixpkgs -- and the references themselves put the
  # plugins in the package's runtime closure.
  sensiblePlugin  = pkgs.tmuxPlugins.sensible;
  resurrectPlugin = pkgs.tmuxPlugins.resurrect;
  continuumPlugin = pkgs.tmuxPlugins.continuum;
  sysstatPlugin   = pkgs.tmuxPlugins.sysstat;

  # the tmux config that used to be the checked-in inheritedConf.conf; see
  # the header of inheritedConf.nix for why it is generated instead.
  inheritedConf = import ./inheritedConf.nix {
    inherit pkgs sensiblePlugin resurrectPlugin continuumPlugin sysstatPlugin;
  };

  # status-bar system-stats segment (total CPU %, total RAM %, average CPU
  # temperature, battery level %).  Runs entirely off /proc and /sys, so bash +
  # coreutils are enough; the script is copied into the package so the status
  # bar does not depend on anything in $PATH of the invoking session.
  statusStatsScript = pkgs.runCommand "tmux-status-stats.sh" { } ''
    install -Dm755 ${./status-stats.sh} $out
    patchShebangs $out
  '';

  # status-bar taskmux-done indicator segment: a green " DONE" marker that
  # appears only while at least one tmux session has its task marked done
  # (i.e. while `taskmux list' would display at least one "done" task).
  # Same self-contained /proc-free design as status-stats.sh above: pure
  # bash, the tmux client path is passed in by the #( ) fragment at config
  # load time (see the comment at the -x option below).
  statusTaskmuxDoneScript = pkgs.runCommand "tmux-status-taskmux-done.sh" { } ''
    install -Dm755 ${./status-taskmux-done.sh} $out
    patchShebangs $out
  '';

  # the *unwrapped* tmux client binary of the underlying tmux package:
  # passed to the taskmux-done indicator fragment (and available to other
  # status fragments) so they can query the server without depending on
  # PATH.  (The wrapper $out/bin/tmux adds -f main.conf, which a plain
  # client command would ignore anyway, but pinning the raw client keeps
  # status-bar jobs independent of this wrapper's own config handling.)
  rawTmuxBin = pkgsLib.getExe pkgs.tmux;

  # tmux-palette (eduwass/tmux-palette): a Raycast-style command palette
  # (filterable command list in a tmux popup), bound to C-Space below.  The
  # plugin runs on bun; its package.json has no runtime `dependencies` (the
  # devDependencies are CI-only), so shipping the repo tree as-is and
  # pinning a store bun path is enough -- no `bun install` is needed at
  # build or run time.
  tmuxPaletteSrc = pkgs.fetchFromGitHub {
    owner = "eduwass";
    repo = "tmux-palette";
    rev = "7caa11e845e0aa0515d013158df85613f3ec507f";
    hash = "sha256-Wrfo6G9Uuko0FYM9azwGNmyEYszSi/Tnwb71XY89QxI=";
  };

  bunExe = pkgsLib.getExe pkgs.bun;

  # tmux-grimoire (navahas/tmux-grimoire): summonable floating shells
  # ("shpells", tmux display-popup based sessions).  Like tmux-palette
  # above it is a plain bash-script plugin with no build step and no
  # external deps beyond bash + tmux itself, so shipping the repo tree
  # and patching it is enough.
  tmuxGrimoireSrc = pkgs.fetchFromGitHub {
    owner = "navahas";
    repo = "tmux-grimoire";
    rev = "c5597c628d452bea3312e25b9db2ea30f3c64287";
    hash = "sha256-IKkF8xa3G8dALTB2hC/4uG1dpzTRvM1g7s0Gy9XnyaI=";
  };

  # the voice-input push-to-talk script, the same package the sway
  # configuration binds F13 to (see
  # newThatWaterCharmander/zeusOlympia/sway/swayDecl.nix).  It comes from the
  # same flake input the rest of the system packages use (nasExitGiScorp), so
  # tmux and sway always agree on *what* voice-input does.
  voiceInput = pkgsLib.getExe newPkgs.voice-input;
  mkTmux =
    { defaultShell }:
    pkgs.stdenv.mkDerivation {
      name = "tmux";
      src = ./.;
      nativeBuildInputs = [ pkgs.makeWrapper pkgs.perl ];
      buildInputs = [ pkgs.tmux ];
      installPhase = ''
        runHook preInstall

        mkdir -p $out/bin $out/config

        install -Dm644 ${inheritedConf} $out/config/inheritedConf.conf
        install -Dm644 basic.conf $out/config

        # theme: copy the gruvbox plugin tree (its entrypoint sources files
        # relative to its own directory) and reference it from main.conf
        cp -r ${themePlugin}/share/tmux-plugins/gruvbox $out/config/gruvbox

        # tmux-palette: copy the plugin tree under config/ (its launcher
        # resolves its own directory with `dirname "$0"`, so the tree must
        # be self-contained) and rewrite the paths it resolves from $PATH
        # at run time.  Both the measure pass and the display-popup command
        # spawn `bun` from $PATH, but run-shell jobs and popups only get
        # the invoking client's environment, which may not contain bun at
        # all; TMUX_BIN is likewise resolved with `command -v tmux`, which
        # could find some other tmux binary than *this* wrapped one.  Pin
        # both to the store.
        cp -r ${tmuxPaletteSrc} $out/config/tmux-palette
        chmod -R u+w $out/config/tmux-palette
        f=$out/config/tmux-palette/bin/tmux-palette.sh
        # shellcheck disable=SC2016
        OLD='"$(command -v tmux)"' NEW="\"$out/bin/tmux\"" \
          perl -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/g' "$f"
        # shellcheck disable=SC2016
        OLD='$(bun "' NEW="\$(${bunExe} \"" \
          perl -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/g' "$f"
        OLD="exec bun '" NEW="exec ${bunExe} '" \
          perl -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/g' "$f"
        patchShebangs "$f"

        # tmux-grimoire: copy the plugin tree under config/ (its entrypoint
        # resolves its own directory with `dirname`/BASH_SOURCE, so the tree
        # must be self-contained; the path is persisted via the
        # @grimoire-* options it sets globally).  Every script -- the
        # entrypoint, scripts/*.sh and the bin/ helpers -- invokes the bare
        # `tmux` client from $PATH, but run-shell jobs only get the
        # invoking client's environment, which may not contain *this* wrapped
        # tmux at all (or, during config load, any tmux whatsoever).
        # Rewrite the word `tmux' to this wrapper's absolute path in all of
        # them (word-boundary match, so `tmux_cmd' / `TMUX_PANE' are left
        # alone), then fix up the shebangs to point at the store bash.
        cp -r ${tmuxGrimoireSrc} $out/config/tmux-grimoire
        chmod -R u+w $out/config/tmux-grimoire
        for f in grimoire.tmux scripts/cast_shpell.sh scripts/shpell.sh \
                 scripts/ephemeral_shpell.sh bin/custom_shpell bin/logo \
                 bin/osc52-copy; do
          # shellcheck disable=SC2016
          OLD='tmux' NEW="$out/bin/tmux" \
            perl -pi -e 's/\btmux\b/$ENV{NEW}/g' "$out/config/tmux-grimoire/$f"
        done

        # The entrypoint pushes its bin/ dir plus the *entire* invoking
        # environment's PATH into the server global environment with
        # `set-environment -g PATH "$new_path"`.  On a real shell that
        # argument alone routinely exceeds tmux's command-length limit, and
        # tmux then rejects the whole chained command ("command too long") --
        # taking every bind-key of the entrypoint down with it, so the
        # plugin silently installs nothing.  Nothing else in the plugin
        # actually needs the plugin bin/ dir on PATH (all internal calls use
        # absolute paths, and the custom-shpell/logo helpers are passed as
        # absolute-path arguments), so drop the mutation entirely; users can
        # still run the helpers via their absolute paths under
        # /.../config/tmux-grimoire/bin/.
        # shellcheck disable=SC2016
        perl -ni -e 'print unless /set-environment -g PATH/' "$out/config/tmux-grimoire/grimoire.tmux"

        patchShebangs $out/config/tmux-grimoire

        cat > $out/config/main.conf <<EOF
          set -g default-shell ${defaultShell}
          source-file $out/config/basic.conf
          source-file $out/config/inheritedConf.conf

          # CPU / RAM / temperature stats immediately left of the date
          # --------------------------------------------------------------
          # The gruvbox plugin assembles status-right from three user
          # options: @tmux-gruvbox-right-status-x (date, "%Y-%m-%d"), -y
          # (time, "%H:%M") and -z (hostname).  Setting -x to "<stats
          # fragment> %Y-%m-%d" makes the plugin emit the stats *inside* the
          # date segment, i.e. rendered immediately to the left of the date
          # -- which is exactly where these indicators belong now (they used
          # to be appended to the far right of status-right, after the
          # hostname).
          #
          # Doing it this way (instead of appending yet another status-right
          # fragment after the PREFIX marker further down) also keeps the
          # stats in front of the date regardless of how the trailing
          # segments (REC / PREFIX / hostname) evolve.
          #
          # tmux's #( ) fragment spawns the script; it prints one line, e.g.
          # "CPU 12% | RAM 41% | 54°C | BAT +82%" (the "+" marks a battery
          # that is charging/full; on machines without a battery the BAT
          # segment is omitted).  The script samples /proc/stat twice
          # around a sleep whose length is the interval environment variable
          # (passed inside the fragment below), so the sleep doubles as the
          # CPU-usage measurement window; 5s matches the gruvbox plugin's own
          # status refresh cadence (status-interval 5, set by
          # gruvbox-tpm.tmux), so the segment updates on every
          # status-line redraw without adding load.  Note: #( ) is
          # re-evaluated at most once per status-interval, so each redraw
          # costs exactly one 5s-background-job per tmux client; tmux caches
          # the output between redraws and never blocks the UI on it.  The
          # fragment is prepended to the date inside the -x value so it
          # shares the segment's colour239 background; a #[default] style
          # afterwards restores the date's own fg=colour246 styling.
          #
          # Taskmux-done indicator immediately left of the stats
          # --------------------------------------------------------------
          # Prepended to the -x value above the stats fragment, so it is
          # rendered immediately to the LEFT of the CPU/RAM/temperature
          # module (inside the same date segment): when at least one tmux
          # session has its task marked done (`taskmux done'), the segment
          # shows a green "DONE" in front of the stats; when nothing is
          # done the indicator script prints nothing and the segment
          # contains only the stats.  The separating space between "DONE"
          # and "CPU" is the literal space after the fragment: tmux trims
          # leading/trailing whitespace off #( ) output, so the script
          # cannot carry the space itself (when the indicator is empty the
          # stray space is just background in front of the stats).  The
          # tmux client used by the indicator is pinned via the `tmux'
          # environment variable (see status-taskmux-done.sh): run-shell
          # jobs only inherit the invoking client's environment, which may
          # not have tmux on PATH.  tmux re-evaluates each #( ) fragment at
          # most once per status-interval, so the marker appears/disappears
          # within at most ~5s of a `taskmux done' / `taskmux clear'.
          #
          # This must be set *before* the gruvbox run-shell below: the
          # plugin reads the option when it runs, so setting it afterwards
          # would only take effect on the next tmux-server start.
          set -g @tmux-gruvbox-right-status-x "#[fg=green,bold]#(tmux=${rawTmuxBin} ${statusTaskmuxDoneScript}) #[default]#[fg=colour109,bold]#(interval=5 ${statusStatsScript})#[default] %Y-%m-%d"

          run-shell $out/config/gruvbox/gruvbox-tpm.tmux

          # tmux-grimoire: summonable popup shells ("shpells"), bound after
          # plugin load to prefix+f (open/toggle the main shpell), prefix+F
          # (fresh ephemeral shpell), prefix+X (close & dismiss the current
          # shpell) and prefix+H (the Grimoire welcome banner, itself an
          # ephemeral shpell).  The option overrides must be set *before* the
          # run-shell below: grimoire.tmux reads them once when it runs, and
          # rebinding only happens on the next tmux-server start.
          #
          # @grimoire-kill-key: the upstream default is prefix+C, which would
          # clobber the "prefix C" new-session binding in basic.conf (grimoire
          # loads after it and unconditionally rebinds its kill key).  X is
          # unused anywhere in basic.conf / inheritedConf.conf / gruvbox.
          #
          # @grimoire-osc52: with the default (on), grimoire replaces the
          # copy-mode-vi `y` (copy-selection-and-cancel, from basic.conf) and
          # `Enter` bindings with OSC52-emitting ones -- changing the
          # configured copy-mode behaviour.  Turn it off so basic.conf keeps
          # full ownership of copy-mode-vi; re-enable (value "on") to regain
          # terminal-escape yanking (useful over ssh).
          set -g @grimoire-kill-key X
          set -g @grimoire-osc52 off
          run-shell $out/config/tmux-grimoire/grimoire.tmux

        # tmux-palette: open the command palette with Ctrl+Space (no
        # prefix, matching the plugin's Raycast-style default).  Bound
        # *after* the gruvbox run-shell so a plugin cannot unbind it on
        # reload (gruvbox only touches status options, so this is purely
        # defensive).  C-Space does not collide with anything in
        # basic.conf / inheritedConf.conf (those use C-a, C-h/j/k/l,
        # M-h/j/k/l and prefix-based keys).  The popup needs tmux >= 3.4
        # for `display-popup -E`; the launcher pins TMUX_BIN to this
        # wrapper, so the palette always queries the server it was
        # started from.
        bind-key -n C-Space run-shell "$out/config/tmux-palette/bin/tmux-palette.sh"

        # voice-input on F13, console only
        # --------------------------------------------------------------
        # The run-shell command below passes --console to voice-input: this
        # binding is only installed when there is no graphical session, and
        # on the bare console neither notify-send (D-Bus notifications) nor
        # wtype (wayland) can work, so voice-input must run in its console
        # mode (stderr / tmux display-message reporting, transcription typed
        # into the tmux pane with send-keys).  TMUX_PANE is pinned to the
        # invoking pane via #{pane_id} (run-shell expands formats, see the
        # scrollback binding in basic.conf) so the transcription is typed into
        # the pane F13 was pressed in even when tmux does not export
        # TMUX_PANE to the run-shell job.
        #
        # keyd remaps rightalt to evdev F13 system-wide (see
        # newThatWaterCharmander/empTriageCan/louSelfHit-sofa/keyRemappings.nix);
        # the Linux console (TERM=linux) delivers F13 as \E[25~ (its terminfo
        # kf13 entry).  tmux cannot be given a literal "F13" key name (tmux's
        # key-string parser only knows F1-F12), so the sequence is mapped to a
        # User0 key via the user-keys option and User0 is bound instead.
        #
        # NB: the console only emits \E[25~ if its keymap maps evdev keycode
        # 183 (KEY_F13) to the F13 function key.  keyd's remap reaches the
        # virtual console as keycode 183, and the stock `us` console keymap
        # leaves that keycode as VoidSymbol, so it must be bound explicitly;
        # otherwise this binding silently never fires in a console (it works
        # under sway because sway reads the raw keycode).  That mapping lives
        # in the host config:
        # newThatWaterCharmander/zeusOlympia/console.nix.
        #
        # Under sway, rightalt is
        # already handled by the sway-level bindcode 191 bindings (press =
        # voice-input start, release = voice-input finish; see
        # zeusOlympia/sway/swayDecl.nix) and never reaches tmux, but the
        # binding below is still *only* installed when the tmux server is not
        # running under a graphical session (no Wayland/X display), so a tmux
        # server started inside sway never binds F13 and can never interfere
        # with the sway push-to-talk flow.
        #
        # Behaviour note: unlike sway, tmux cannot observe key *release*
        # events, so the press=start / release=finish pair is approximated by a
        # toggle: press F13 to start recording, press it again to stop the
        # recording and transcribe/insert (voice-input itself tracks the
        # in-progress recording via its pid file).
        #
        # voice-input recording indicator in the status bar
        # --------------------------------------------------------------
        # voice-input tracks an in-progress recording via its pid file
        # (/tmp/voice-input-recording.pid holds the pid of the pw-record
        # process it spawned).  The status-right appended below shows a red
        # "REC" marker whenever that pid is alive, i.e. whenever a voice
        # recording is running -- regardless of whether it was started from
        # the tmux User0/F13 toggle below or from the sway push-to-talk
        # binding.  It must be set *after* the gruvbox run-shell above,
        # because the gruvbox plugin overwrites status-right with its own
        # value; set -ga appends our marker to whatever gruvbox left in
        # place.  pgrep -F avoids nested parentheses inside the #( ) shell
        # fragment (tmux's format parser terminates #( ) at the first
        # unmatched ')', so \$( ) command substitution cannot be used
        # there).
        #
        # tmux re-evaluates #( ) fragments on every status-line redraw (at
        # most once per status-interval, 15s by default), so the User0
        # binding below additionally runs "tmux refresh-client -S" to make
        # the marker appear/disappear immediately on toggle instead of up to
        # 15s later.
        set -ga status-right "#[fg=red,bold]#(pgrep -F /tmp/voice-input-recording.pid >/dev/null 2>&1 && echo ' REC')#[default]"

        # prefix-key indicator in the status bar
        # --------------------------------------------------------------
        # Shows a yellow "PREFIX" marker while a prefix key (C-a, see
        # inheritedConf.conf) is held: the `client_prefix` format returns 1
        # when the invoking client is currently in prefix mode, so the marker
        # appears the moment the prefix is pressed and disappears on the next
        # keypress.  tmux redraws the status line as soon as the client's
        # prefix flag changes, so no polling/refresh is needed.
        #
        # This is appended (set -ga) *after* the voice-input "REC" marker
        # above rather than replacing status-right, so both indicators coexist:
        # pressing the prefix while a recording is in progress still shows REC.
        set -ga status-right "#[fg=yellow,bold]#{?client_prefix,PREFIX,}#[default]"

        # two-line status bar
        # --------------------------------------------------------------
        # With many windows the single default status line gets cramped:
        # the gruvbox status-left and the long status-right (stats, date,
        # time, hostname, REC / PREFIX markers) leave little room in the
        # middle for the window list, which then truncates window names.
        # `status 2` makes tmux render both status-format[0] and
        # status-format[1]; we split the bar across the two lines:
        #
        #   line 0: gruvbox status-left (incl. the session name) ... status-right
        #   line 1: window list only (no session name)
        #
        # Both formats are derived from tmux's own default status-format
        # (`tmux show -gv status-format[0|1]`), so all the range/list
        # markup that makes mouse clicks on status segments and windows
        # work is preserved, and the window entries keep using the gruvbox
        # window-status-format / window-status-current-format options.
        #
        # Line 0 is the default minus the window-list section (the whole
        # `#[list=on ...]#{W:...}` block between the left and right
        # segments), so it keeps exactly the gruvbox bar we had before.
        # Line 1 replaces tmux's default pane list with the window list
        # (copied verbatim from the default line-0 window section) and
        # nothing else: the session name is deliberately NOT repeated here
        # (gruvbox's status-left on line 0 already shows it), so the
        # bottom-most bar contains only the window names and their numbers.
        # The left segment's range markup is kept (with an empty body) so
        # mouse-click targeting and style resolution keep working;
        # gruvbox's status-justify (left) decides where the window list
        # starts, and its window-status-separator is used between windows
        # as usual.
        #
        # `status 2` must be set *after* the gruvbox run-shell above: the
        # plugin sets `status on` (i.e. 1) when it runs.
        set -g status 2

        set -g status-format[0] "#[align=left range=left #{E:status-left-style}]#[push-default]#{T;=/#{status-left-length}:status-left}#[pop-default]#[norange default]#[nolist align=right range=right #{E:status-right-style}]#[push-default]#{T;=/#{status-right-length}:status-right}#[pop-default]#[norange default]"

        set -g status-format[1] "#[align=left range=left #{E:status-left-style}]#[push-default]#[pop-default]#[norange default]#[list=on align=#{status-justify}]#[list=left-marker]<#[list=right-marker]>#[list=on]#{W:#[range=window|#{window_index} #{E:window-status-style}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]#[push-default]#{T:window-status-format}#[pop-default]#[norange default]#{?loop_last_flag,,#{E:window-status-separator}},#[range=window|#{window_index} list=focus #{?#{!=:#{E:window-status-current-style},default},#{E:window-status-current-style},#{E:window-status-style}}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]#[push-default]#{T:window-status-current-format}#[pop-default]#[norange list=on default]#{?loop_last_flag,,#{E:window-status-separator}}}#[norange default]"

        # NB: this heredoc is *unquoted*, so literal dollar signs must be
        # escaped (\$WAYLAND_DISPLAY) to survive the installPhase shell while
        # still being expanded by sh at tmux-config load time.
        if-shell '[ -n "\$WAYLAND_DISPLAY" ] || [ -n "\$DISPLAY" ]' \
          'set -g @voice-input-graphical-session on' \
          'set -s user-keys[0] "\033[25~"; bind-key -n User0 run-shell -b "if [ -f /tmp/voice-input-recording.pid ]; then TMUX_PANE=#{pane_id} ${voiceInput} --console finish; else TMUX_PANE=#{pane_id} ${voiceInput} --console start; fi & sleep 0.5; tmux refresh-client -S"'
        EOF

        makeWrapper ${pkgsLib.getExe pkgs.tmux} $out/bin/tmux \
        --add-flags "-f $out/config/main.conf"

        runHook postInstall'';
    };
in
pkgsLib.makeOverridable mkTmux { defaultShell = pkgsLib.getExe pkgs.bash; }
