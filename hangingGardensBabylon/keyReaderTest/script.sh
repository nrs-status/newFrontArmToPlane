#!/nix/store/9ipfvwnqp1q8ijnmi5sxvlx9r8w34lw3-bash-5.3p15/bin/bash
set -o errexit
set -o nounset
set -o pipefail

export PATH="$PATH"

set -euo pipefail

if [ -n "${age+x}" ]; then
    echo ${age}
fi

# Key not in environment: we need root to read the key file.
if [[ ${EUID} -ne 0 ]]; then
    echo "age not set; requesting root permissions to read /etc/keys.yaml..." >&2
    exec sudo -- "$0" "$@"
fi

# Running as root now: extract the key with yq.
KEY=$(yq ".age" "/etc/keys.yaml")

if [[ -z "${KEY}" || "${KEY}" == "null" ]]; then
    echo "Error: key 'age' not found or empty in /etc/keys.yaml" >&2
    exit 1
fi

echo ${KEY}

