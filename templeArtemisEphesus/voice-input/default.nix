# voice-input: push-to-talk audio recording + OpenRouter transcription + insertion at cursor.
#
# subcommands:
#   start                 : start recording the default audio source with pw-record
#   finish                : stop recording, transcribe the wav using the program at
#                           ~/llmSessions/openrouter-audio-transcription.0 (OpenRouter, key read
#                           from /run/secrets/OPENROUTER_API_KEY by that program), and type the
#                           transcription wherever the cursor is with wtype
#   transcribe-file <path>: like finish but transcribes a given file instead of a recording
#                           (useful for testing, e.g. with ~/baghdad_plane/rectest/out.wav)
{ pkgs }:

let
  pyScript = pkgs.writeText "voice-transcriber.py" (builtins.readFile ./transcribe.py);
  pythonEnv = pkgs.python3.withPackages (ps: [ ps.requests ]);
in
pkgs.writeShellScriptBin "voice-input" ''
  set -euo pipefail

  recordFile=/tmp/voice-input-recording.wav
  pidFile=/tmp/voice-input-recording.pid
  logFile=/tmp/voice-input-transcribe.log

  notify() {
    ${pkgs.libnotify}/bin/notify-send -a voice-input "$@"
  }

  transcribeAndInsert() { #$1 = wav file to transcribe
    transcribeScript="${pyScript}"
    if [ ! -f "$1" ]; then
      notify -u critical "voice-input" "no audio file to transcribe: $1"
      return 1
    fi
    if ! text="$(${pythonEnv}/bin/python "$transcribeScript" "$1" 2>"$logFile")"; then
      notify -u critical "voice-input" "transcription failed, see $logFile"
      return 1
    fi
    #flatten newlines and trim whitespace so wtype never hits Enter and inserts nothing superfluous
    text="$(printf '%s' "$text" | tr '\n' ' ' | tr -s ' ' | sed -e 's/^ *//;s/ *$//')"
    if [ ''${#text} -eq 0 ]; then
      notify "voice-input" "transcription was empty, nothing inserted"
      return 0
    fi
    if ${pkgs.wtype}/bin/wtype -s 5 -- "$text"; then
      notify "voice-input" "inserted transcription: ''${text:0:60}..."
    else
      notify -u critical "voice-input" "wtype failed: no wayland cursor to insert at?"
      return 1
    fi
  }

  start() {
    if [ -f "$pidFile" ]; then
      notify -u critical "voice-input" "recording already in progress"
      return 1
    fi
    rm -f "$recordFile"
    ${pkgs.pipewire}/bin/pw-record --target @DEFAULT_AUDIO_SOURCE@ --rate 16000 --channels 1 "$recordFile" >/dev/null 2>&1 &
    echo "$!" > "$pidFile"
    notify "voice-input" "recording started... (release rightcontrol to transcribe)"
  }

  finish() {
    if [ ! -f "$pidFile" ]; then
      notify -u critical "voice-input" "no recording in progress"
      return 1
    fi
    pid="$(cat "$pidFile")"
    rm -f "$pidFile"
    kill -INT "$pid" 2>/dev/null || true
    #wait for pw-record to finalize the wav file (up to 5s)
    i=0
    while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 50 ]; do
      sleep 0.1
      i=$((i+1))
    done
    if kill -0 "$pid" 2>/dev/null; then
      notify -u critical "voice-input" "recorder did not stop, wav may be incomplete"
      return 1
    fi
    transcribeAndInsert "$recordFile"
  }

  case "''${1:-}" in
    start) start ;;
    finish) finish ;;
    transcribe-file)
      file="''${2:-}"
      if [ -z "$file" ]; then
        echo "usage: voice-input transcribe-file <path>" >&2
        exit 1
      fi
      transcribeAndInsert "$file"
      ;;
    *)
      echo "usage: voice-input start|finish|transcribe-file <path>" >&2
      exit 1
      ;;
  esac
''
