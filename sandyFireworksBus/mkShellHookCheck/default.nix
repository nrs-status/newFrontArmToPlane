# mkWarnerShellHook
#
# A function for the `shellHook` field of `pkgs.mkShell`. It prepends a
# validation program to the given `rest` string. The validation program runs
# immediately when the shell starts and:
#
#   1. checks that every environment variable named in `envVars` is set,
#   2. for each entry in `files`, runs the entry's `check` bash script with the
#      entry's `path` as the script's only argument.
#
# If a required environment variable is not set, or if any `check` script
# returns a nonzero exit code, the shell exits early with an error (every
# failure is reported before exiting). Otherwise the contents of `rest` run.
#
# Types:
#   envVars :: list of strings (valid environment variable names)
#   files   :: HASet filesASetEntry, where filesASetEntry = {
#                path  :: string,  # path to a file
#                check :: string,  # bash script taking one argument (a file
#                                  # path) and returning 0 or 1
#              }
#   rest    :: string (the rest of the shell hook)
#
# It is a curried function (following the convention of the project library
# this directory is part of): first it takes the library inputs, then the
# argument set.
{ pkgsLib, ... }:
let
  inherit (pkgsLib) concatStringsSep concatMapStringsSep mapAttrsToList escapeShellArg;
in
{
  envVars ? [ ],
  files ? { },
  rest ? "",
}:
let
  # Emit a warning for each missing environment variable.
  envVarChecks = concatMapStringsSep "\n" (v: ''
    if [ -z "''${${v}+x}" ]; then
      printf '%s\n' "mkWarnerShellHook: required environment variable ${v} is not set" >&2
      failed=1
    fi
  '') envVars;

  # Run each file's check script with the entry's path as its only argument.
  # `escapeShellArg` makes both the script and the path safe as single shell
  # arguments, so checks containing quotes, spaces or newlines are fine.
  fileChecks = concatStringsSep "\n" (mapAttrsToList (name: entry: ''
    if ! bash -c ${escapeShellArg entry.check} check ${escapeShellArg entry.path}; then
      printf '%s\n' "mkWarnerShellHook: check failed for file ${escapeShellArg entry.path}" >&2
      failed=1
    fi
  '') files);
in
concatStringsSep "\n" [
  "# --- mkWarnerShellHook validation ---"
  "failed="
  envVarChecks
  fileChecks
  ''
    if [ -n "$failed" ]; then
      printf '%s\n' "mkWarnerShellHook: validation failed, aborting shell hook" >&2
      exit 1
    fi
    # --- end mkWarnerShellHook validation ---
  ''
  rest
]