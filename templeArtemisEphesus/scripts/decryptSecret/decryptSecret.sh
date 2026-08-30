set -euo pipefail

die() {
    echo "Error: $*" >&2
    exit 1
}

usage() {
    echo "Usage: $0 <path-to-yaml-file> <yaml-key>" >&2
}

#validation

if [[ $# -ne 2 ]]; then
    usage
    die "expected exactly 2 arguments (got $#)"
fi

file=$1
key=$2

if [[ -z $file ]]; then
    usage
    die "yaml file path must not be empty"
fi

if [[ -z $key ]]; then
    usage
    die "yaml key must not be empty"
fi

if [[ ! -f $file ]]; then
    die "file '$file' does not exist or is not a regular file"
fi

if [[ ! -r $file ]]; then
    die "file '$file' is not readable"
fi


if [[ -z ${SOPS_AGE_KEY:-} ]]; then
    die "SOPS_AGE_KEY is not set."
fi

#main

sops -d "$file" | yq --exit-status ".${key}" -
