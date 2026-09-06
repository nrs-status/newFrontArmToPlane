  # Sanity check: the host nix store is 9p-mounted in the guest
  # (via virtualisation.mountHostNixStore). Report its state.
  echo "host nix store: ${builtins.storeDir} mounted in guest"
  ro_store_mounted="$(grep -c ' /nix/.ro-store 9p ' /proc/mounts || true)"
  if [[ "$ro_store_mounted" -ge 1 ]]; then
    echo "  /nix/.ro-store is a 9p mount backed by the host store"
  else
    echo "  WARNING: host nix store NOT mounted at /nix/.ro-store"
  fi
  nix_store_mount="$(grep ' /nix/store ' /proc/mounts | head -n 1 || true)"
  if [[ -n "$nix_store_mount" ]]; then
    echo "  /nix/store mount: $nix_store_mount"
  else
    echo "  WARNING: /nix/store not mounted"
  fi
  echo "  sample store paths: $(ls /nix/store | head -n 2 | tr '\n' ' ')"

  # Exit early (successfully) if the fw_cfg secrets are absent.
  if [[ ! -f ${fwKey} ]]; then
    echo "no fw_cfg API key present; skipping pi run"
    exit 0
  fi
  if [[ ! -f ${fwPrompt} ]]; then
    echo "no fw_cfg prompt present; skipping pi run"
    exit 0
  fi

  # run.sh passes both values as host files (`-fw_cfg ...,file=<path>`),
  # so the raw bytes arrive verbatim; strip any trailing NULs.
  OPENROUTER_API_KEY="$(tr -d '\0' < ${fwKey})"
  PROMPT="$(tr -d '\0' < ${fwPrompt})"
  export OPENROUTER_API_KEY

  # The shared ~/.pi/agent/auth.json resolves its key via
  # `! cat /run/secrets/OPENROUTER_API_KEY`; provide that file too.
  mkdir -p /run/secrets
  printf '%s' "$OPENROUTER_API_KEY" > /run/secrets/OPENROUTER_API_KEY

  echo "fw_cfg received: prompt length ''${#PROMPT} chars, key length ''${#OPENROUTER_API_KEY} chars"

  # /root/project is the 9p share backed by the host workspace
  # directory (see virtualisation.sharedDirectories.pi-project);
  # everything pi writes here is visible on the host.
  cd /root/project
  echo "workspace: $(pwd) (shared with host)"

  # Make sure the session export directory exists on the share.
  mkdir -p /root/project/pi-sessions

  # --offline disables refreshing the model catalog, checking for updates, etc.
  # NOTE: no `--no-session`: pi keeps a real session and, via
  # `--session-dir /root/project/pi-sessions`, writes its JSONL
  # session file directly onto the host-visible share.
  set +e
  ${pi} -p --model openrouter/z-ai/glm-5.3-flash --session-dir /root/project/pi-sessions --offline -- "$PROMPT"
  pi_status=$?
  set -e

  # Export the session file for the host. It lives in
  # /root/project/pi-sessions, which is already on the share, so
  # the host can read it directly. As a convenience we also copy
  # the newest session JSONL to a stable name, session.jsonl.
  # (pi exports PI_SESSION_FILE only inside its own process tree,
  # so we cannot read it from this service script afterwards.)
  latest_session="$(ls -t /root/project/pi-sessions/*.jsonl 2>/dev/null | head -n 1 || true)"
  if [[ -n "$latest_session" ]]; then
    cp -f "$latest_session" /root/project/pi-sessions/session.jsonl
    echo "session exported: $latest_session -> /root/project/pi-sessions/session.jsonl"
  else
    echo "warning: no session file found in /root/project/pi-sessions"
  fi

  # Make every file pi created world-readable on the host share.
  chmod -R a+rX /root/project 2>/dev/null || true

  echo "pi finished (status $pi_status); powering off VM"
  systemctl poweroff
  exit "$pi_status"
