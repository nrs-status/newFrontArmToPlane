#!/usr/bin/env bash
# Functional test for the gopass native-messaging integration in
# templeArtemisEphesus/firefox/default.nix.
#
# Verifies that the gopass-jsonapi binary that Firefox spawns (as declared in
# the native messaging manifest) has the tools on its PATH that are needed to
# use GPG keys protected by a passphrase: gopass, gpg, gpg-agent, a pinentry
# program and git.
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

# 6. Also verify the wrapped gopass-jsonapi itself runs and speaks the JSON
#    API that gopass-bridge uses (messages are 4-byte little-endian length
#    prefixed, as per Firefox's native messaging spec)
MSG='{"type":"getVersion"}'
LENS=$(printf '%08x' ${#MSG})
REQFILE=$(mktemp)
printf "\\x${LENS:6:2}\\x${LENS:4:2}\\x${LENS:2:2}\\x${LENS:0:2}" > "$REQFILE"
printf '%s' "$MSG" >> "$REQFILE"
RESP=$(timeout 10 "$WRAPPED" listen < "$REQFILE" 2>/dev/null | head -c 500) || true
rm -f "$REQFILE"
echo "JSON API response: $RESP"
echo "$RESP" | grep -q '"version"' || { echo "FAIL: JSON API"; exit 1; }
echo "PASS: wrapped gopass-jsonapi answers the gopass-bridge JSON API"

rm -rf "$T"
echo "ALL TESTS PASSED"
