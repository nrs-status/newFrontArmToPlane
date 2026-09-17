#!/usr/bin/env bash
# Functional test for the gopass native-messaging integration in
# templeArtemisEphesus/firefox/default.nix.
#
# Verifies that the gopass-jsonapi binary that Firefox spawns (as declared in
# the native messaging manifest):
#   1. has the tools on its PATH that are needed to use GPG keys protected by
#      a passphrase: gopass, gpg, gpg-agent, a pinentry program and git,
#   2. answers the JSON API when spawned the way Firefox does (argument-less
#      -- the wrapper appends `listen`), and
#   3. reports startup failures as framed JSON errors instead of plaintext on
#      the protocol pipe (the "exceeds the limit of 1048576 bytes" bug).
#
# Usage (from the flake root, after `nix build .#firefox`):
#   bash templeArtemisEphesus/firefox/gopass-native-messaging-test.sh
# or pass the wrapped binary as $1.
set -euo pipefail

# Locate the wrapped gopass-jsonapi via the manifest installed into the
# firefox package (default `result` symlink of `nix build .#firefox`).
MANIFEST="${2:-result/lib/mozilla/native-messaging-hosts/com.justwatch.gopass.json}"
WRAPPED="${1:-$(sed -n 's/.*"path": "\(.*\)",/\1/p' "$MANIFEST")}"
[ -n "$WRAPPED" ] && [ -x "$WRAPPED" ] || { echo "FAIL: wrapped gopass-jsonapi not found via $MANIFEST"; exit 1; }

PASSPHRASE='correct horse battery staple'
SECRET='s3cr3t-firefox-gopass-test'

# The wrapped environment = the store bin dirs the makeWrapper prepends.
# We test with ONLY those on PATH (as minimal emulation of Firefox's env).
WRAPPED_PATH=$(grep -o "^PATH='/nix/store/[^']*" "$WRAPPED" | sed "s|^PATH='||" | paste -sd:)
echo "Wrapped PATH: $WRAPPED_PATH"

# Sanity: all required tools resolvable from the wrapped PATH only
# (gopass-jsonapi itself is invoked by Firefox via the absolute manifest path,
# so it does not need to be on PATH)
for tool in gopass gpg gpg-agent pinentry-qt pinentry-curses git; do
  PATH="$WRAPPED_PATH" command -v "$tool" >/dev/null || { echo "FAIL: $tool not in wrapped PATH"; exit 1; }
  echo "ok: $tool -> $(PATH="$WRAPPED_PATH" command -v "$tool")"
done

# Isolated test environment
T=$(mktemp -d)
export HOME="$T/home"
export GNUPGHOME="$T/gnupg"
export XDG_CONFIG_HOME="$T/home/.config"
export XDG_DATA_HOME="$T/home/.local/share"
mkdir -p "$HOME" "$GNUPGHOME"
chmod 700 "$GNUPGHOME"

# gpg-agent: allow presetting passphrases (so the test is non-interactive)
cat > "$GNUPGHOME/gpg-agent.conf" <<EOF
allow-preset-passphrase
pinentry-program $(echo "$WRAPPED_PATH" | tr ':' '\n' | grep pinentry-curses)/pinentry-curses
EOF

# 1. GPG key WITH a passphrase
PATH="$WRAPPED_PATH" gpg --batch --pinentry-mode loopback --passphrase "$PASSPHRASE" \
  --quick-generate-key "gopass-test <gopass-test@example.com>"
KEYID=$(PATH="$WRAPPED_PATH" gpg --list-secret-keys --with-colons | awk -F: '/^sec/{print $5; exit}')
echo "Generated passphrase-protected key: $KEYID"

# 2. gopass store backed by that key
STORE="$XDG_DATA_HOME/gopass/stores/root"
mkdir -p "$STORE" "$XDG_CONFIG_HOME/gopass"
echo "gopass-test@example.com" > "$STORE/.gpg-id"
cat > "$XDG_CONFIG_HOME/gopass/config.yml" <<EOF
root:
  askformore: false
  autoimport: true
  autosync: false
  cliptimeout: 45
  nocolor: false
  notifications: false
  path: $STORE
  safe_content: false
EOF

# 3. Store a secret (encryption only needs the public key)
echo "$SECRET" | PATH="$WRAPPED_PATH" gopass insert -f test/secret
echo "Secret encrypted into store."

# 4. Preset the key passphrase into gpg-agent (simulates the user having
#    typed the passphrase into the pinentry dialog that gpg-agent popped up).
#    Every keygrip (primary + subkeys) needs the preset.
for KEYGRIP in $(PATH="$WRAPPED_PATH" gpg --with-keygrip --list-secret-keys --with-colons \
  | awk -F: '/^grp/{print $10}'); do
  HEXPASS=$(printf '%s' "$PASSPHRASE" | xxd -p | tr -d '\n')
  PATH="$WRAPPED_PATH" gpg-connect-agent "PRESET_PASSPHRASE $KEYGRIP -1 $HEXPASS" /bye | grep -q OK \
    || { echo "FAIL: preset passphrase for $KEYGRIP"; exit 1; }
done
echo "Passphrase preset into gpg-agent."

# 5. Decrypt through gopass using ONLY the wrapped environment
GOT=$(PATH="$WRAPPED_PATH" gopass show -o test/secret)
if [ "$GOT" = "$SECRET" ]; then
  echo "PASS: gopass decrypted a passphrase-protected GPG secret from the wrapped native-messaging environment"
else
  echo "FAIL: got '$GOT'"
  exit 1
fi

# 6. Verify the host responds when invoked exactly the way Firefox does:
#    with NO arguments (the manifest path is spawned argument-less). This
#    exercises the makeWrapper `--add-flags listen` fix: without it
#    gopass-jsonapi would print its help text onto the protocol pipe.
#    Responses are 4-byte little-endian length prefixed, as per Firefox's
#    native messaging spec.
MSG='{"type":"getVersion"}'
LENS=$(printf '%08x' ${#MSG})
REQFILE=$(mktemp)
printf "\\x${LENS:6:2}\\x${LENS:4:2}\\x${LENS:2:2}\\x${LENS:0:2}" > "$REQFILE"
printf '%s' "$MSG" >> "$REQFILE"
RESPFILE=$(mktemp)
timeout 10 "$WRAPPED" < "$REQFILE" > "$RESPFILE" 2>/dev/null
rm -f "$REQFILE"
RESP=$(tail -c +5 "$RESPFILE" | head -c 500) || true
rm -f "$RESPFILE"
echo "JSON API response: $RESP"
echo "$RESP" | grep -q '"version"' || { echo "FAIL: JSON API"; exit 1; }
echo "PASS: wrapped gopass-jsonapi answers the gopass-bridge JSON API when spawned argument-less (as Firefox does)"

# 7. Regression test for the "exceeds the limit of 1048576 bytes" corruption
#    bug. When gopass store initialization fails, upstream gopass-jsonapi
#    printed "Failed to initialize gopass API: ..." as plaintext to stdout,
#    which IS the native-messaging protocol pipe; the browser then read the
#    ASCII "Fail" (0x6C696146 LE) as a message length of 1818845510 bytes.
#    The flake patches gopass-jsonapi to report the failure on stderr and to
#    send a properly framed JSON error response instead.
#    Verify: with an UNINITIALIZED store, the host must respond with a small
#    framed JSON error (readable in the browser), never raw text.
T2=$(mktemp -d)
HOME="$T2" XDG_CONFIG_HOME="$T2/.config" XDG_DATA_HOME="$T2/.local/share" \
  timeout 10 "$WRAPPED" >"$T2/out" 2>"$T2/err" && true
LEN=$(head -c 4 "$T2/out" | od -An -tu4 | awk '{print $1}')
[ -n "$LEN" ] || { echo "FAIL: no response on stdout for uninitialized store"; exit 1; }
BODY=$(tail -c +5 "$T2/out" | head -c "$LEN")
rm -rf "$T2"
echo "Uninitialized-store response: $BODY"
# the length must be a sane JSON size, not bytes of text misread as a length
[ "$LEN" -lt 4096 ] || { echo "FAIL: length header $LEN looks like misread plaintext"; exit 1; }
echo "$BODY" | grep -q '"error"' || { echo "FAIL: expected framed JSON error"; exit 1; }
echo "PASS: startup failures are framed JSON errors, not raw stdout text (no more 1818845510-byte garbage)"

rm -rf "$T"
echo "ALL TESTS PASSED"
