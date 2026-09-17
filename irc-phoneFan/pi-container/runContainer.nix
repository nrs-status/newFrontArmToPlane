{ pkgs, pi-container }:
pkgs.writeShellScriptBin "run-pi-container" ''
  set -euo pipefail

  RUNTIME="''${CONTAINER_RUNTIME:-docker}"
  IMAGE="localhost/simple-pi-container:nixos"
  IMAGE_TARBALL="${pi-container}"
  coreutils="${pkgs.coreutils}"

  usage() {
    echo "usage: $0 [--bind HOST_PATH CONTAINER_PATH] \\" >&2
    echo "           [--ro-bind HOST_PATH CONTAINER_PATH] \\" >&2
    echo "           HOST_WORKSPACE_DIR [PI_ARGS...]" >&2
    echo "  HOST_WORKSPACE_DIR is mounted read-write at /workspace in the container" >&2
    echo "  remaining positional arguments are passed to pi (the entrypoint)" >&2
    echo "  set CONTAINER_RUNTIME to override the default 'docker'" >&2
  }

  die() {
    echo "run-pi-container: error: $*" >&2
    usage
    exit 1
  }

  # resolve HOST_PATH to an absolute canonical path and check existence
  resolveHostPath() {
    local p="$1"
    if [ ! -e "$p" ]; then
      die "host path does not exist: $p"
    fi
    "$coreutils/bin/realpath" "$p"
  }

  workspace=""
  mounts=()
  piArgs=()
  seenPositional=0

  while [ $# -gt 0 ]; do
    case "$1" in
      --bind)
        [ $# -ge 3 ] || die "--bind requires a host path and a container path"
        [ -e "$2" ] || die "--bind host path does not exist: $2"
        case "$3" in
          /*) ;;
          *) die "--bind container path must be absolute: $3" ;;
        esac
        mounts+=("-v" "$(resolveHostPath "$2"):$3")
        shift 3
        ;;
      --ro-bind)
        [ $# -ge 3 ] || die "--ro-bind requires a host path and a container path"
        [ -e "$2" ] || die "--ro-bind host path does not exist: $2"
        case "$3" in
          /*) ;;
          *) die "--ro-bind container path must be absolute: $3" ;;
        esac
        mounts+=("-v" "$(resolveHostPath "$2"):$3:ro")
        shift 3
        ;;
      --)
        shift
        piArgs+=("$@")
        break
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      # any other option (e.g. pi's own flags like -p) is passed through
      *)
        if [ "$seenPositional" -eq 0 ]; then
          [ -d "$1" ] || die "workspace is not a directory: $1"
          workspace="$(resolveHostPath "$1")"
          seenPositional=1
        else
          piArgs+=("$1")
        fi
        shift
        ;;
    esac
  done

  [ "$seenPositional" -eq 1 ] || die "a host workspace directory is required"

  # load the image into the runtime's storage if it is not there yet
  if ! "$RUNTIME" image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "run-pi-container: loading image into $RUNTIME ..." >&2
    "$RUNTIME" load -i "$IMAGE_TARBALL"
  fi

  # attach a tty only when running interactively
  ttyFlags=()
  if [ -t 0 ] && [ -t 1 ]; then
    ttyFlags=(-it)
  fi

  exec "$RUNTIME" run --rm \
    "''${ttyFlags[@]+''${ttyFlags[@]}}" \
    -v "$workspace:/workspace" \
    "''${mounts[@]+''${mounts[@]}}" \
    "$IMAGE" \
    "''${piArgs[@]+''${piArgs[@]}}"
''
