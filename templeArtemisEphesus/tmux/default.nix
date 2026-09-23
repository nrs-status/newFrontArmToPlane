{ pkgs, pkgsLib, newPkgs, ... }:
let
  # gruvbox theme plugin for the tmux status line / pane colors
  themePlugin = pkgs.tmuxPlugins.gruvbox;

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
          run-shell $out/config/gruvbox/gruvbox-tpm.tmux

        # voice-input on F13, console only
        # --------------------------------------------------------------
        # keyd remaps rightalt to evdev F13 system-wide (see
        # newThatWaterCharmander/empTriageCan/louSelfHit-sofa/keyRemappings.nix);
        # the Linux console (TERM=linux) delivers F13 as \E[25~ (its terminfo
        # kf13 entry).  tmux cannot be given a literal "F13" key name (tmux's
        # key-string parser only knows F1-F12), so the sequence is mapped to a
        # User0 key via the user-keys option and User0 is bound instead.
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
        # NB: this heredoc is *unquoted*, so literal dollar signs must be
        # escaped (\$WAYLAND_DISPLAY) to survive the installPhase shell while
        # still being expanded by sh at tmux-config load time.
        if-shell '[ -n "\$WAYLAND_DISPLAY" ] || [ -n "\$DISPLAY" ]' \
          'set -g @voice-input-graphical-session on' \
          'set -s user-keys[0] "\033[25~"; bind-key -n User0 run-shell -b "if [ -f /tmp/voice-input-recording.pid ]; then ${voiceInput} finish; else ${voiceInput} start; fi"'
        EOF

        makeWrapper ${pkgsLib.getExe pkgs.tmux} $out/bin/tmux \
        --add-flags "-f $out/config/main.conf"

        runHook postInstall'';
    };
in
pkgsLib.makeOverridable mkTmux { defaultShell = pkgsLib.getExe pkgs.bash; }
