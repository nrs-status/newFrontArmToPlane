# arunman — specification

## 1. Overview

`arunman` is a command line tool (written in Haskell) that manages runs of the
pi microvm runner `run-pi-microvm` (from the `frontArmToPlane` flake) whose
configuration lives in the `runConfigs` attribute set of a nix flake. Every
run is tracked in a postgresql `run` table, from creation to completion.

The tool has two subcommands: `run` and `list`.

## 2. Common option

Both subcommands take a required option `--config` (`-c`) giving the path of a
TOML configuration file. The config contains:

* `databaseUrl` — a URL to a Postgres SQL server (postgresql-simple
  connection syntax; URIs and keyword strings both work), holding the `run`
  table,
* `openrouterApiKey` — an OpenRouter API key string handed to the VM.

## 3. The `run` subcommand

    arunman run -c CONFIG <flakeref>#<runConfig>

The argument has the form `<flakeref>#<config>`, where the left-hand side of
the hash sign is a flake ref of the same sort seen in the usual nix commands,
and the right-hand side designates an output of the flake accessible at the
attribute `runConfigs`.

### 3.1 `runConfigs` schema

An element of the attribute `runConfigs` is an attribute set of the form:

    roDirs: list of paths
    rwDirs: list of paths
    disk:   positive integer
    ram:    positive integer
    model:  string
    prompt: string

### 3.2 Database entry

If `run` successfully validates the `runConfigs` attribute and validates that
the passed flakeref is valid, it inserts an entry in the postgresql server
located at the URL passed in the config. The table has the following schema:

    'run' table
    id:                    primary key, integer
    config:                nix store path of the flake
    workdir:               a string representing a path
    status:                one of: ongoing, done, initializing, terminated
    "startTime":           datetime
    "endTime":             datetime
    output:                nix store path of the output (see 3.5)

The new entry itself consists of:

* a unique ID,
* the actual nix store path of the flake that was passed as an argument,
* `workdir`: the path of a new temporary directory created just for this
  entry using `mktemp -d`,
* `status` = `initializing`, `startTime` = the time right now,
* `endTime` and `output` are empty for the moment.

### 3.3 Running the job

Once the entry is made, `run` executes the `run-pi-microvm` script, passing
the selected `runConfigs` element as its configuration:

* `--workdir` is the path of the temporary directory created for the entry,
* `--disk-size`, `--ram`, `--read-only`, `--read-write` come from the
  `runConfig`'s `disk`, `ram`, `roDirs`, `rwDirs`,
* `--model` comes from `model`,
* `--api-key-file` receives the openrouter API key from the TOML config,
* the prompt from `prompt` is passed on stdin.

The `run-pi-microvm` script is resolved from, in order of precedence: the
`--run-pi-microvm` option, the `ARUNMAN_RUN_PI_MICROVM` environment variable,
then by building `pi-vm.run-pi-microvm` from the `frontArmToPlane` flake (its
ref can be overridden with `ARUNMAN_FRONT_ARM_TO_PLANE`).

### 3.4 Monitoring

While the script is running, `run` monitors its state and updates the entry:
the status moves from `initializing` to `ongoing` once the job is confirmed
running. The status is set to `terminated` only in case the script did not
exit correctly (i.e. the virtual machine it ran did not exit correctly), in
which case `endTime` is set as well.

### 3.5 Output

If `run-pi-microvm` finishes successfully, the temporary directory given as
the `workdir` value is made into a derivation in the nix store
(`nix store add`); the resulting store path is stored in the `output` column
(with `status` = `done` and `endTime` set), and `run` prints the store path
of the result on stdout.

## 4. The `list` subcommand

    arunman list -c CONFIG [-s STATUS]

By default it only lists the entries of the `run` table whose status is
either `ongoing` or `initializing`. Otherwise the `--status` (`-s`) option
filters which entries are displayed, using a string of status letters:

    --status odit   # list everything
    --status o      # only ongoing
    --status d      # only done
    --status t      # only terminated
    --status i      # only initializing
    --status it     # only initializing and terminated
