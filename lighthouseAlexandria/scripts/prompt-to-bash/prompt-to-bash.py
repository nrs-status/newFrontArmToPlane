#!/usr/bin/env python3
"""prompt-to-bash: voice command -> pi coding agent -> reviewed bash commands.

Reads a transcribed voice command from stdin, asks the pi coding agent to
translate it into a list of bash commands, pipes the result through `vipe`
so the user can review/edit it, and finally executes the commands one after
the other.  If the editor buffer is exited without saving, the commands are
discarded.
"""

import argparse
import json
import os
import shutil
import shlex
import subprocess
import sys

PROG = "prompt-to-bash"
VERSION = "1.0.0"

DEFAULT_CONFIG_PATHS = [
    os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")),
                 PROG, "config.json"),
]

DEFAULT_SYSTEM_PROMPT = (
    "You are a bash command generator. The user gives you a command that was "
    "transcribed from speech. Translate it into the smallest possible list of "
    "bash commands that accomplishes the request.\n"
    "Rules:\n"
    "- Output ONLY the bash commands, one per line.\n"
    "- No explanations, no comments, no markdown fences, no prompt.\n"
    "- Use one simple command per line instead of chains where practical.\n"
    "- You may inspect the filesystem with your read-only tools to understand "
    "the context before deciding on the commands.\n"
    "- If the request is impossible or nonsensical, output nothing."
)


class ConfigError(Exception):
    pass


# --------------------------------------------------------------------------- #
# Configuration                                                               #
# --------------------------------------------------------------------------- #

def load_config_file(path):
    """Load a JSON configuration file. Returns {} if path is None."""
    if path is None:
        return {}
    if not os.path.isfile(path):
        raise ConfigError(f"config file not found: {path}")
    try:
        with open(path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except json.JSONDecodeError as exc:
        raise ConfigError(f"invalid JSON in config file {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise ConfigError(f"config file {path} must contain a JSON object")
    return data


CONFIG_KEYS = {
    "provider": str,
    "model": str,
    "thinking": str,
    "api_key": str,
    "pi_path": str,
    "vipe_path": str,
    "editor": str,
    "system_prompt": str,
    "no_tools": bool,
    "no_session": bool,
    "keep_going": bool,
    "dry_run": bool,
    "extra_pi_args": list,
}


def validate_config(data, source):
    for key, value in data.items():
        if key not in CONFIG_KEYS:
            raise ConfigError(f"unknown key {key!r} in {source} "
                              f"(valid: {', '.join(sorted(CONFIG_KEYS))})")
        expected = CONFIG_KEYS[key]
        if expected is list:
            if not isinstance(value, list) or not all(isinstance(v, str) for v in value):
                raise ConfigError(f"{key!r} in {source} must be a list of strings")
        elif not isinstance(value, expected):
            raise ConfigError(f"{key!r} in {source} must be of type {expected.__name__}")


def build_config(args):
    """Merge configuration: defaults < config file < environment < CLI."""
    config = {
        "provider": None,          # let pi use its own default
        "model": None,
        "thinking": None,
        "api_key": None,
        "pi_path": "pi",
        "vipe_path": "vipe",
        "editor": None,            # honour $VISUAL/$EDITOR
        "system_prompt": DEFAULT_SYSTEM_PROMPT,
        "no_tools": False,
        "no_session": True,
        "keep_going": False,
        "dry_run": False,
        "extra_pi_args": [],
    }

    # 1. Config file
    path = args.config or os.environ.get("PTB_CONFIG")
    if path is None:
        for candidate in DEFAULT_CONFIG_PATHS:
            if os.path.isfile(candidate):
                path = candidate
                break
    if path:
        file_cfg = load_config_file(path)
        validate_config(file_cfg, f"config file {path}")
        config.update(file_cfg)

    # 2. Environment variables
    env_map = {
        "PTB_PROVIDER": "provider",
        "PTB_MODEL": "model",
        "PTB_THINKING": "thinking",
        "PTB_API_KEY": "api_key",
        "PTB_PI": "pi_path",
        "PTB_VIPE": "vipe_path",
        "PTB_EDITOR": "editor",
        "PTB_SYSTEM_PROMPT": "system_prompt",
    }
    for env, key in env_map.items():
        value = os.environ.get(env)
        if value is not None:
            config[key] = value
    if os.environ.get("PTB_NO_TOOLS", "").lower() in ("1", "true", "yes"):
        config["no_tools"] = True
    if os.environ.get("PTB_KEEP_GOING", "").lower() in ("1", "true", "yes"):
        config["keep_going"] = True
    if os.environ.get("PTB_DRY_RUN", "").lower() in ("1", "true", "yes"):
        config["dry_run"] = True
    extra = os.environ.get("PTB_EXTRA_PI_ARGS", "").strip()
    if extra:
        try:
            config["extra_pi_args"] = config.get("extra_pi_args", []) + shlex.split(extra)
        except ValueError as exc:
            raise ConfigError(f"PTB_EXTRA_PI_ARGS is not valid shell syntax: {exc}") from exc

    # 3. Command-line options (highest precedence)
    for key in ("provider", "model", "thinking", "api_key",
                "pi_path", "vipe_path", "editor", "system_prompt"):
        value = getattr(args, key, None)
        if value is not None:
            config[key] = value
    if args.no_tools:
        config["no_tools"] = True
    if args.keep_going:
        config["keep_going"] = True
    if args.dry_run:
        config["dry_run"] = True
    config["extra_pi_args"] = config.get("extra_pi_args", []) + (args.extra_pi_arg or [])

    return config


# --------------------------------------------------------------------------- #
# Pipeline steps                                                              #
# --------------------------------------------------------------------------- #

def read_stdin():
    if sys.stdin.isatty():
        raise ConfigError("no input on stdin; pipe a voice-command transcript into "
                          f"{PROG} (see --help)")
    return sys.stdin.read().strip()


def build_pi_argv(config):
    argv = [config["pi_path"]]
    if config["provider"]:
        argv += ["--provider", config["provider"]]
    if config["model"]:
        argv += ["--model", config["model"]]
    if config["thinking"]:
        argv += ["--thinking", config["thinking"]]
    if config["api_key"]:
        argv += ["--api-key", config["api_key"]]
    if config["no_tools"]:
        argv.append("--no-tools")
    if config["no_session"]:
        argv.append("--no-session")
    argv += config["extra_pi_args"]
    argv += ["--print", "--mode", "text",
             "--system-prompt", config["system_prompt"]]
    return argv


def translate_to_commands(config, transcript):
    """Ask pi to translate the transcript into bash commands."""
    argv = build_pi_argv(config) + ["--", transcript]
    try:
        proc = subprocess.run(argv, input="", text=True,
                              stdout=subprocess.PIPE, stderr=None)
    except FileNotFoundError:
        raise ConfigError(f"pi executable not found: {config['pi_path']!r} "
                          "(set --pi-path or $PTB_PI)")
    if proc.returncode != 0:
        raise ConfigError(f"pi exited with status {proc.returncode}")
    return extract_commands(proc.stdout)


def extract_commands(text):
    """Strip markdown code fences, if any, and trim whitespace."""
    text = text.strip()
    lines = text.splitlines()
    fence_lines = [ln for ln in lines if ln.strip().startswith("```")]
    if len(fence_lines) >= 2 and (lines[0].strip().startswith("```")):
        # drop the first fence line and everything after the closing fence
        end = None
        for i in range(1, len(lines)):
            if lines[i].strip().startswith("```"):
                end = i
                break
        if end is not None:
            lines = lines[1:end]
        else:
            lines = lines[1:]
        text = "\n".join(lines).strip()
    return text


def review_with_vipe(config, commands):
    """Let the user review/edit the commands. Returns edited text or None."""
    env = dict(os.environ)
    if config["editor"]:
        env["VISUAL"] = config["editor"]
        env["EDITOR"] = config["editor"]
    try:
        proc = subprocess.run([config["vipe_path"]], input=commands, text=True,
                              stdout=subprocess.PIPE, stderr=None, env=env)
    except FileNotFoundError:
        raise ConfigError(f"vipe executable not found: {config['vipe_path']!r} "
                          "(set --vipe-path or $PTB_VIPE)")
    if proc.returncode != 0:
        return None
    edited = proc.stdout
    if not edited.strip():
        return None
    return edited


def run_commands(commands_text, keep_going=False, dry_run=False):
    """Execute the (reviewed) commands one after the other."""
    lines = [ln.strip() for ln in commands_text.splitlines()]
    commands = [ln for ln in lines if ln and not ln.startswith("#")]
    if not commands:
        print("No commands to run.", file=sys.stderr)
        return 0
    for i, cmd in enumerate(commands, 1):
        if dry_run:
            print(f"[{i}/{len(commands)}] (dry-run) {cmd}")
            continue
        print(f"[{i}/{len(commands)}] $ {cmd}", file=sys.stderr)
        bash = shutil.which("bash") or shutil.which("sh") or "/bin/sh"
        proc = subprocess.run(cmd, shell=True, executable=bash)
        if proc.returncode != 0 and not keep_going:
            print(f"{PROG}: command {i} failed with exit status "
                  f"{proc.returncode}; stopping.", file=sys.stderr)
            return proc.returncode
    return 0


# --------------------------------------------------------------------------- #
# CLI                                                                         #
# --------------------------------------------------------------------------- #

def parse_args(argv):
    parser = argparse.ArgumentParser(
        prog=PROG,
        description="Pipe a voice-command transcript from stdin through the pi "
                    "coding agent to obtain a list of bash commands, review it "
                    "with vipe, then execute it.",
        epilog="Configuration precedence: command line > environment variables "
               "> config file > defaults.  Environment variables: PTB_PROVIDER, "
               "PTB_MODEL, PTB_THINKING, PTB_API_KEY, PTB_PI, PTB_VIPE, "
               "PTB_EDITOR, PTB_SYSTEM_PROMPT, PTB_CONFIG, PTB_NO_TOOLS, "
               "PTB_KEEP_GOING, PTB_DRY_RUN, PTB_EXTRA_PI_ARGS.")
    parser.add_argument("--version", action="version", version=f"{PROG} {VERSION}")
    parser.add_argument("-c", "--config", metavar="FILE",
                        help="JSON config file (default: $PTB_CONFIG, then "
                             "~/.config/prompt-to-bash/config.json)")
    parser.add_argument("--provider", metavar="NAME",
                        help="pi provider (e.g. openrouter, anthropic, google)")
    parser.add_argument("--model", metavar="PATTERN",
                        help="pi model pattern (e.g. anthropic/claude-sonnet-4)")
    parser.add_argument("--thinking", metavar="LEVEL",
                        help="pi thinking level: off|minimal|low|medium|high|...")
    parser.add_argument("--api-key", metavar="KEY",
                        help="API key passed to pi (normally not needed)")
    parser.add_argument("--pi-path", metavar="PATH",
                        help="path to the pi binary (default: pi)")
    parser.add_argument("--vipe-path", metavar="PATH",
                        help="path to the vipe binary (default: vipe)")
    parser.add_argument("--editor", metavar="CMD",
                        help="editor used by vipe (default: $VISUAL/$EDITOR)")
    parser.add_argument("--system-prompt", metavar="TEXT",
                        help="override the system prompt given to pi")
    parser.add_argument("--no-tools", action="store_true",
                        help="run pi with --no-tools (pure text translation)")
    parser.add_argument("--keep-going", action="store_true",
                        help="continue with remaining commands even if one fails")
    parser.add_argument("--dry-run", action="store_true",
                        help="print the reviewed commands instead of running them")
    parser.add_argument("--extra-pi-arg", metavar="ARG", action="append",
                        help="extra argument forwarded to pi (repeatable)")
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    try:
        config = build_config(args)
        transcript = read_stdin()
        if not transcript:
            raise ConfigError("received an empty transcript on stdin")
        commands = translate_to_commands(config, transcript)
        if not commands.strip():
            print(f"{PROG}: pi produced no commands; aborting.", file=sys.stderr)
            return 1
        reviewed = review_with_vipe(config, commands)
        if reviewed is None:
            print("Discarded (buffer not saved).", file=sys.stderr)
            return 0
        return run_commands(reviewed, keep_going=config["keep_going"],
                            dry_run=config["dry_run"])
    except ConfigError as exc:
        print(f"{PROG}: error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
