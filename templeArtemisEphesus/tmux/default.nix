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

  # status-bar taskmux-done indicator segment: a bright-green " DONE" marker that
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

  # Write a kitty OSC 1337 `SetUserVar' escape to a tty:
  #   kitty-set-user-var KEY [VALUE] TTY
  # With no VALUE the variable is cleared.  Kept as a separate script (not
  # an inline `printf' in the wrapper / in tmux config) so the quoting of
  # the `;' separators inside the escape sequence does not have to survive
  # tmux's own command parser.
  setUserVarScript = pkgs.writeShellApplication {
    name = "kitty-set-user-var";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      key="''${1:?missing key}"
      tty="''${3:?missing tty}"
      if [ -n "''${2:-}" ]; then
        b64="$(printf %s "''${2}" | base64 -w0)"
        printf '\033]1337;SetUserVar=%s=%s\007' "$key" "$b64" > "$tty"
      else
        printf '\033]1337;SetUserVar=%s\007' "$key" > "$tty"
      fi
    '';
  };

  # The tmux client wrapper.  In addition to adding -f main.conf it announces
  # every attached client to kitty: smart-splits.nvim only sets kitty's
  # `IS_NVIM' window var when nvim runs directly in kitty, so when nvim runs
  # inside tmux, kitty (templeArtemisEphesus/kitty/conf.nix) would otherwise
  # consume C-hjkl / M-hjkl for kitty-window navigation before tmux could
  # route them (which broke nvim-cmp completion-menu navigation with
  # ctrl+j/ctrl+k).  See the matching `IS_TMUX' pass-through mappings and the
  # explanatory comment in inheritedConf.nix.
  #
  # The var is written raw to the client's own controlling terminal (the
  # kitty pty), which needs neither a running server nor tmux passthrough;
  # an EXIT trap clears it again when the client detaches/exits, so the
  # window falls back to kitty-window navigation.  Non-attaching one-shot
  # commands (`tmux ls', status-bar scripts via @rawTmuxBin@, ...) exec
  # straight through without touching the var.
  # (See templeArtemisEphesus/tmux/inheritedConf.nix for why this is not done
  # with `client-attached' / `client-detached' hooks.)
  wrapperSrc = pkgs.writeText "tmux-wrapper.in" ''
    #!@bashBin@
    # tmux's subcommand may be preceded by flags (e.g. -f, -S), so scan for it
    # anywhere in the argument list; with no arguments at all tmux behaves
    # like `attach'.
    has_client_cmd=0
    [ "$#" -gt 0 ] || has_client_cmd=1
    for arg in "$@"; do
      case "$arg" in
        new | new-session | attach | attach-session | a | n)
          has_client_cmd=1
          break
          ;;
      esac
    done
    if [ "$has_client_cmd" = 0 ]; then
      exec @tmuxBin@ -f @out@/config/main.conf "$@"
    fi

    client_tty="$(tty 2>/dev/null)"
    if [ -n "$client_tty" ]; then
      @setUserVarScript@ IS_TMUX 1 "$client_tty" >/dev/null 2>&1 &
      trap '@setUserVarScript@ IS_TMUX "$client_tty" >/dev/null 2>&1' EXIT
    fi
    exec @tmuxBin@ -f @out@/config/main.conf "$@"
  '';

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

  # the taskmux executable, used by the Ctrl+t grimoire popup below.  It
  # comes from the same flake input as voice-input above (and as the
  # status-bar taskmux-done indicator), so tmux and the rest of the system
  # always agree on *what* taskmux is.  The popup command is pinned to its
  # store path because it runs in a freshly-created grimoire session whose
  # $PATH is not guaranteed to contain taskmux (the tmux server inherits
  # its environment from whoever started it).
  taskmuxExe = pkgsLib.getExe newPkgs.scripts.taskmux;
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

        # main.conf is a template (./main.conf.in): install it and fill in
        # the @...@ placeholders -- the store paths of the status scripts /
        # auxiliary binaries, and this package's own $out, which is only
        # known inside the build.
        install -Dm644 ${./main.conf.in} $out/config/main.conf
        substituteInPlace $out/config/main.conf \
          --replace '@defaultShell@' '${defaultShell}' \
          --replace '@rawTmuxBin@' '${rawTmuxBin}' \
          --replace '@statusTaskmuxDoneScript@' '${statusTaskmuxDoneScript}' \
          --replace '@statusStatsScript@' '${statusStatsScript}' \
          --replace '@taskmuxExe@' '${taskmuxExe}' \
          --replace '@voiceInput@' '${voiceInput}' \
          --replace '@out@' "$out"

        # client wrapper announcing tmux to kitty (see wrapperSrc)
        install -Dm644 ${wrapperSrc} $out/bin/tmux
        substituteInPlace $out/bin/tmux \
          --replace '@bashBin@' '${pkgsLib.getExe pkgs.bash}' \
          --replace '@setUserVarScript@' '${setUserVarScript}/bin/kitty-set-user-var' \
          --replace '@tmuxBin@' '${rawTmuxBin}' \
          --replace '@out@' "$out"
        chmod +x $out/bin/tmux

        runHook postInstall'';
    };
in
pkgsLib.makeOverridable mkTmux { defaultShell = pkgsLib.getExe pkgs.bash; }
