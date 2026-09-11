{ pkgs, ... }:
let
  exampleConfig = pkgs.writeText "example-tiles-config.toml" (builtins.readFile ./exampleConfig.toml);
  tiles = pkgs.writeText "tiles.py" (builtins.readFile ./tiles.py);
in
pkgs.writeShellApplication {
  name = "tiles";
  text = ''
        #!/usr/bin/env bash
    # run.sh — launch the tiles TUI.
    #
    # Usage:
    #   ./run.sh              # launch the TUI with example.toml
    #   ./run.sh my.toml      # launch the TUI with a custom config
    #   ./run.sh -h|--help    # show the help message
    set -euo pipefail


    help() {
        cat <<EOF
    usage: run.sh [CONFIG.toml]

    Launch the tiles TUI with a TOML configuration file.
    Without an argument, example.toml is used.

      -h, --help    show this help and exit
    EOF
    }

    if [[ $# -gt 1 ]]; then
        help >&2
        exit 1
    fi

    case "''${1:-}" in
        -h|--help)
            help
            exit 0
            ;;
        "")
            CONFIG="${exampleConfig}"
            ;;
        -*)
            help >&2
            exit 1
            ;;
        *)
            CONFIG="$1"
            ;;
    esac

    if [[ ! -f "$CONFIG" ]]; then
        help >&2
        exit 1
    fi

    exec ${pkgs.python3} ${tiles} -c "$CONFIG"

  '';
}
