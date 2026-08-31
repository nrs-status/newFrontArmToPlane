{ pkgs, ... }:
{ envVarName, keyPath }:
assert
  (builtins.match "[A-Za-z_][A-Za-z0-9_]*" envVarName) != null
  || throw "Invalid environment variable name: ${envVarName}";
pkgs.writeShellApplication {
  name = "keyReader";
  excludeShellChecks = [ "SC2086" ]; # so that we may echo the environment variable without enclosing it in double quotes
  runtimeInputs = [ pkgs.yq ];
  text = ''
        set -euo pipefail

        if [ -n "''${${envVarName}+x}" ]; then
            echo ''${${envVarName}}
            exit 0
        fi

        if [[ ''${EUID} -ne 0 ]]; then
            echo "${envVarName} not set; requesting root permissions to read ${keyPath}..." >&2
            KEY=$(sudo -- yq ".${envVarName}" "${keyPath}")
            sudo -k
        else
            # Already root: no need for sudo, just read the key directly.
            KEY=$(yq ".${envVarName}" "${keyPath}")
        fi

        KEY=$(printf '%s' "''${KEY}" | tr -d '"') #removing enclosing double quotes

        if [[ -z "''${KEY}" || "''${KEY}" == "null" ]]; then
            echo "Error: key '${envVarName}' not found or empty in ${keyPath}" >&2
            exit 1
        fi

        echo ''${KEY}
  '';
}
