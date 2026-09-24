{ pkgs, pkgsLib, newPkgs, ... }:
let
  # gruvbox theme plugin for the tmux status line / pane colors
  themePlugin = pkgs.tmuxPlugins.gruvbox;

  # status-bar system-stats segment (total CPU %, total RAM %, average CPU
  # temperature).  Runs entirely off /proc and /sys, so bash + coreutils are
  # enough; the script is copied into the package so the status bar does not
  # depend on anything in $PATH of the invoking session.
  statusStatsScript = pkgs.runCommand "tmux-status-stats.sh" { } ''
    install -Dm755 ${./status-stats.sh} $out
    patchShebangs $out
  '';

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
      nativeBuildInputs = [ pkgs.makeWrapper ];
      buildInputs = [ pkgs.tmux ];
      installPhase = ''
        runHook preInstall

        mkdir -p $out/bin $out/config

        install -Dm644 inheritedConf.conf $out/config
        install -Dm644 basic.conf $out/config

        # theme: copy the gruvbox plugin tree (its entrypoint sources files
        # relative to its own directory) and reference it from main.conf
        cp -r ${themePlugin}/share/tmux-plugins/gruvbox $out/config/gruvbox

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
          # "CPU 12% | RAM 41% | 54°C".  The script samples /proc/stat twice
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
          # This must be set *before* the gruvbox run-shell below: the
          # plugin reads the option when it runs, so setting it afterwards
          # would only take effect on the next tmux-server start.
          set -g @tmux-gruvbox-right-status-x "#[fg=colour109,bold]#(interval=5 ${statusStatsScript})#[default] %Y-%m-%d"

          run-shell $out/config/gruvbox/gruvbox-tpm.tmux

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
