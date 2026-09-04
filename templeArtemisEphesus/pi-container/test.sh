#!/usr/bin/env bash
# Test that the `pi` container connects to OpenRouter.
#
# The container reads its API key at runtime from
# `/run/secrets/OPENROUTER_API_KEY` (bind-mounted by the caller), via the
# `"! cat /run/secrets/OPENROUTER_API_KEY"` command-value in `auth.json`.
# The key must never appear as a command argument (cmdline vulnerability),
# which this script also asserts.
#
# Usage: sudo ./test.sh   (needs access to /run/secrets/OPENROUTER_API_KEY,
#                          docker/podman, and the nix flake)

set -euo pipefail

IMAGE="localhost/simple-pi-container:nixos"
FLAKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SECRET="/run/secrets/OPENROUTER_API_KEY"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -r "$SECRET" ] || fail "$SECRET is not readable; cannot test"

# 1. Build the container image from the flake and load it into the local
#    docker daemon.
echo "== building container image =="
nix build "$FLAKE_DIR#packages.x86_64-linux.pi-container" -o "$FLAKE_DIR/result-pi-container-test"
docker load -i "$FLAKE_DIR/result-pi-container-test" >/dev/null

# 2. Directory-mount variant: the whole secrets directory is bind-mounted.
echo "== test 1: connection with directory-mounted secret =="
out="$(docker run --rm -v /run/secrets:/run/secrets:ro "$IMAGE" \
  -p "Reply with exactly: CONNECTED")"
echo "$out"
grep -q "CONNECTED" <<<"$out" || fail "pi did not get a completion from OpenRouter"
grep -q "not found for provider" <<<"$out" && \
  fail "configured model missing from the container's model catalog"
grep -q "No API key" <<<"$out" && fail "API key was not resolved"

# 3. File-mount variant: only the secret file itself is bind-mounted.
echo "== test 2: connection with file-mounted secret =="
out="$(docker run --rm -v "$SECRET:$SECRET:ro" "$IMAGE" \
  -p "Reply with exactly: CONNECTED")"
echo "$out"
grep -q "CONNECTED" <<<"$out" || fail "pi did not get a completion from OpenRouter"

# 4. Negative control: without the secret the container must NOT connect.
echo "== test 3: no secret mounted must fail =="
out="$(docker run --rm "$IMAGE" -p "Reply with exactly: CONNECTED" 2>&1 || true)"
grep -q "No API key" <<<"$out" || fail "expected 'No API key found for openrouter' without the secret"
echo "$out" | head -1

# 5. Security: while pi runs, sample every process cmdline in the container;
#    the API key must never appear as a command argument.
echo "== test 4: API key never present in any process cmdline =="
docker run --rm -v /run/secrets:/run/secrets:ro --entrypoint bash "$IMAGE" -c '
  pi -p "Reply with exactly: CONNECTED" >/dev/null 2>&1 &
  pid=$!
  leak=0
  while kill -0 "$pid" 2>/dev/null; do
    for c in /proc/[0-9]*/cmdline; do
      [ -r "$c" ] || continue
      if tr "\0" "\n" < "$c" 2>/dev/null | grep -q "$(cat /run/secrets/OPENROUTER_API_KEY)"; then
        leak=1
      fi
    done
  done
  wait "$pid" || true
  exit $leak
' && echo "no key found in any /proc/*/cmdline" \
   || fail "API key leaked into a process cmdline"

echo
echo "ALL TESTS PASSED: the container connects to OpenRouter, and the API key"
echo "is read from /run/secrets/OPENROUTER_API_KEY without ever appearing in"
echo "a process cmdline."
