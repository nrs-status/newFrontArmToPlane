#!/usr/bin/env bash
# scan-and-connect.sh — locate the lanchamarcou NixOS machine on the LAN and
# connect to it over SSH, the same way it was done during the install session:
#   1. auto-detect the local /24 subnet
#   2. parallel ping sweep to find live hosts
#   3. identify the target by its MAC address, or by probing for an SSH banner
#   4. connect over SSH:
#        - with the installer host key (installed system: plat2548 / root), or
#        - with password auth via SSH_ASKPASS (live ISO: nixos)
#
# Usage:
#   ./scan-and-connect.sh                 # interactive SSH session
#   scan-and-connect.sh <command...>      # run a command on the target
#   scan-and-connect.sh -k <keyfile>      # force SSH-key auth with given key
#   scan-and-auth.sh -p <password> ...    # override password
#   scan-and-connect.sh -m <MAC> ...      # match a different MAC
#   scan-and-connect.sh -n <CIDR> ...     # scan a different subnet (e.g. 192.168.1.0/24)

set -u

# ------------------------------------------------------------------ defaults
TARGET_MAC="${TARGET_MAC:-48:d2:24:7d:66:c2}"   # lanchamarcou's WiFi MAC
DEFAULT_USER="${DEFAULT_USER:-nixos}"           # live-ISO user
DEFAULT_PASS="${DEFAULT_PASS:-tmprootpass}"
KEY_USER="${KEY_USER:-plat2548}"                # installed-system user (key auth)
SSH_PORT=22

# ------------------------------------------------------------------ options
KEYFILE=""
PASSWORD="$DEFAULT_PASS"
USER_NAME="$DEFAULT_USER"
CIDR_ARG=""
while getopts "k:p:u:n:h" opt; do
  case "$opt" in
    k) KEYFILE="$OPTARG" ;;
    p) PASSWORD="$OPTARG" ;;
    u) USER_NAME="$OPTARG" ;;
    n) CIDR_ARG="$OPTARG" ;;
    h) grep '^#' "$0" | sed 's/^# \{0,1\}//' | tail -n +2; exit 0 ;;
    *) echo "unknown option -$opt" >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))
REMOTE_CMD=("$@")

# ------------------------------------------------------------------ helpers
die() { echo "error: $*" >&2; exit 1; }
log() { echo "[scan] $*" >&2; }

# detect local /24 subnet from the default route (falls back to any IPv4 iface)
detect_cidr() {
  if [ -n "$CIDR_ARG" ]; then echo "$CIDR_ARG"; return; fi
  local dev prefix
  dev=$(ip -4 route show default 2>/dev/null | awk '{print $5; exit}')
  [ -n "$dev" ] || die "no default route; specify subnet with -n"
  prefix=$(ip -4 addr show dev "$dev" scope global 2>/dev/null \
           | awk '/inet /{split($2,a,"/"); print a[1]"/"a[2]; exit}')
  [ -n "$prefix" ] || die "no IPv4 address on $dev; specify subnet with -n"
  echo "$prefix"
}

# read the SSH banner from host:port (bash /dev/tcp, like the manual probe)
ssh_banner() {
  timeout 8 bash -c "exec 3<>/dev/tcp/$1/$SSH_PORT && timeout 6 head -n1 <&3" 2>/dev/null
}

# ------------------------------------------------------------------ 1. sweep
CIDR=$(detect_cidr)
BASE=${CIDR%.*}
BITS=${CIDR#*/}
[ "$BITS" = 24 ] || log "warning: non-/24 subnet handling is limited to 254 hosts"
OWN_IP=$(ip -4 addr show scope global | awk '/inet /{split($2,a,"/"); print a[1]}')
log "scanning ${BASE}.1-${BASE}.254 (own IP: ${OWN_IP:-unknown}) ..."

ALIVE=()
for i in $(seq 1 254); do
  ( ping -c1 -W1 "${BASE}.${i}" >/dev/null 2>&1 && echo "${BASE}.${i}" ) &
done >/tmp/scan-and-connect.alive.$$
wait
mapfile -t ALIVE < /tmp/scan-and-connect.alive.$$
rm -f /tmp/scan-and-connect.alive.$$
log "live hosts: ${ALIVE[*]:-none}"

# ------------------------------------------------------------------ 2. identify
TARGET_IP=""
# preferred: match the target by its MAC address in the ARP/neighbour table
if [ -n "$TARGET_MAC" ]; then
  for h in "${ALIVE[@]}"; do
    mac=$(ip neigh show "$h" 2>/dev/null | awk '{print tolower($5)}')
    if [ "$mac" = "$(echo "$TARGET_MAC" | tr 'A-F' 'a-f')" ]; then
      TARGET_IP="$h"; break
    fi
  done
  [ -n "${TARGET_IP:-}" ] && log "matched target MAC $TARGET_MAC at $TARGET_IP"
fi

# fallback: probe port 22 on every live host and pick one that speaks SSH
if [ -z "${TARGET_IP:-}" ]; then
  log "probing port $SSH_PORT for SSH banners..."
  for h in "${ALIVE[@]}"; do
    [ "$h" = "$OWN_IP" ] && continue
    banner=$(ssh_banner "$h") || continue
    case "$banner" in
      SSH-*)
        log "  $h: $banner"
        # remember the first ssh host found; prefer one already in ARP cache
        [ -z "${TARGET_IP:-}" ] && TARGET_IP="$h"
        ;;
    esac
  done
fi
[ -n "${TARGET_IP:-}" ] || die "no SSH-capable host found on ${CIDR}"
log "target: $TARGET_IP"

# ------------------------------------------------------------------ 3. connect
SSH_OPTS=(-o StrictHostKeyChecking=no
          -o UserKnownHostsFile=/dev/null
          -o ConnectTimeout=15
          -o ServerAliveInterval=15)

try_key_auth() { # $1=keyfile $2=user -> 0 if auth works
  [ -f "$1" ] || return 1
  ssh -i "$1" -o IdentitiesOnly=yes -o BatchMode=yes "${SSH_OPTS[@]}" \
      "$2@${TARGET_IP}" true 2>/dev/null
}

try_password_auth() { # $1=user $2=password -> 0 if auth works
  local askpass
  askpass=$(mktemp)
  printf '#!/bin/sh\necho %q\n' "$2" > "$askpass"
  chmod 700 "$askpass"
  SSH_ASKPASS="$askpass" SSH_ASKPASS_REQUIRE=force DISPLAY=:0 \
    ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no \
        "${SSH_OPTS[@]}" "$1@${TARGET_IP}" true 2>/dev/null
  local rc=$?
  rm -f "$askpass"
  return "$rc"
}

# figure out how to authenticate
AUTH_USER=""
AUTH_MODE=""
if [ -n "$KEYFILE" ]; then
  try_key_auth "$KEYFILE" "$USER_NAME" && AUTH_MODE=key || die "key auth with $KEYFILE as $USER_NAME failed"
  AUTH_USER="$USER_NAME"; AUTH_MODE=key
else
  # try the installed system first (key auth, ISO host key if available), then ISO password auth
  for cand_key in "${KEYFILE:-}" "${ISO_KEY:-/tmp/iso_host_ed25519_key}"; do
    [ -n "$cand_key" ] && [ -f "$cand_key" ] || continue
    if try_key_auth "$cand_key" "$KEY_USER"; then
      KEYFILE="$cand_key"; AUTH_USER="$KEY_USER"; AUTH_MODE=key; break
    fi
  done
  if [ -z "$AUTH_MODE" ]; then
    if try_password_auth "$USER_NAME" "$PASSWORD"; then
      AUTH_USER="$USER_NAME"; AUTH_MODE=password
    else
      die "could not authenticate to $TARGET_IP (tried key + password)"
    fi
  fi
fi
log "authenticated as $AUTH_USER@$TARGET_IP ($AUTH_MODE auth)"

if [ "$AUTH_MODE" = key ]; then
  exec ssh -i "$KEYFILE" -o IdentitiesOnly=yes "${SSH_OPTS[@]}" \
       "$AUTH_USER@${TARGET_IP}" ${REMOTE_CMD[@]+"${REMOTE_CMD[@]}"}
else
  askpass=$(mktemp)
  printf '#!/bin/sh\necho %q\n' "$PASSWORD" > "$askpass"
  chmod 700 "$askpass"
  trap 'rm -f "$askpass"' EXIT
  # no exec: the EXIT trap must clean up the askpass file afterwards
  env SSH_ASKPASS="$askpass" SSH_ASKPASS_REQUIRE=force DISPLAY=:0 \
      ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no \
          "${SSH_OPTS[@]}" "$AUTH_USER@${TARGET_IP}" ${REMOTE_CMD[@]+"${REMOTE_CMD[@]}"}
  exit $?
fi