# Specification: `mkWarnerShellHook`

## Overview

`./default.nix` defines a Nix function for use in the `shellHook` field of `pkgs.mkShell`. It prepends a validation program to the shell hook. The program runs immediately when the shell starts. It checks that the required environment variables are set and that the declared files pass their checks. If any check fails, the shell exits early with an error. Otherwise the remainder of the shell hook runs.

## Types

### `HASet A`

A homogeneous attribute set. Every entry in the set has type `A`.

### `filesASetEntry.check`

A string that contains a bash script.

- The script takes one argument, which must be a valid file path.
- The script must return exit code `0` or `1`.

### `filesASetEntry`

An attribute set with these fields:

| Field   | Type                      | Description                    |
|---------|---------------------------|--------------------------------|
| `path`  | string                    | Path to a file.                |
| `check` | `filesASetEntry.check`    | The check script for the file. |

## Function: `./mkShellHookCheck.nix`

### Arguments

The function takes an attribute set with these fields:

| Argument  | Type                      | Description                                                       |
|-----------|---------------------------|-------------------------------------------------------------------|
| `envVars` | list of strings           | Valid names of environment variables that must be set.            |
| `files`   | `HASet filesASetEntry`    | Files to validate, each with its own check script.                |
| `rest`    | string                    | The rest of the shell hook, which runs only if all checks pass.   |

### Behavior

The function returns a string for the `shellHook` field of `pkgs.mkShell`. It places a validation program at the beginning of the shell hook, before the contents of `rest`. The program runs immediately and does the following, in order:

1. **Check environment variables.** For each name in `envVars`, verify that the environment variable is set.
2. **Check files.** For each entry in `files`, run the script in the entry's `check` field. Pass the entry's `path` field as the script's only argument.
3. **Fail early.** The shell exits early with an error if either of these happens:
   - an environment variable listed in `envVars` is not set, or
   - any `check` script from step 2 returns a nonzero exit code.
4. **Continue.** If every check passes, run the contents of `rest`.
