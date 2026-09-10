#!/usr/bin/env python3
"""
Transcribe an audio file or stream via OpenRouter.

Usage:
  python3 transcribe.py out.wav
  python3 transcribe.py audio.mp3
  some-command | python3 transcribe.py -          # read raw audio from stdin

Command line options:
  --config <file>       use <file> as the configuration file instead of the
                        default search path (a missing --config file is an error)
  --api-url <url>       override the 'api_url' config parameter
  --model <id>          override the 'model' config parameter
  --api-key-file <path> override the 'api_key_file' config parameter
  --prompt <text>       override the 'prompt' config parameter
  --pipe-command <cmd>  override the 'pipe_command' config parameter
                        (an empty value disables the pipe entirely)

The API call to OpenRouter is configurable via command line options,
environment variables and the optional configuration file.
Precedence (highest wins):
  1. command line options (--config, --api-url, --model, --api-key-file,
     --prompt, --pipe-command)
  2. environment variables ($OPENROUTER_API_KEY, $OPENROUTER_API_KEY_FILE,
     $OPENROUTER_MODEL, $OPENROUTER_API_URL)
  3. the configuration file (keys below)
  4. built-in defaults
Without any override the API key is read from /run/secrets/OPENROUTER_API_KEY.

Optional configuration file (--config <file>, else searched in this order):
  $VOICE_INPUT_CONFIG
  ${XDG_CONFIG_HOME:-~/.config}/voice-input/config

Config format ('key = value' lines; '#' comments and blank lines ignored):
  api_url = <url>
      OpenRouter endpoint to POST the chat-completions request to.
      Default: https://openrouter.ai/api/v1/chat/completions
      Example: api_url = https://openrouter.ai/api/v1/chat/completions
  model = <model id>
      OpenRouter model used for the transcription (must accept audio input).
      Default: google/gemini-2.5-flash
      Example: model = openai/gpt-4o-audio-preview
  api_key_file = <path>
      File the OpenRouter API key is read from (single line).
      Default: /run/secrets/OPENROUTER_API_KEY
      Example: api_key_file = /home/me/secrets/openrouter.key
  prompt = <text>
      Instruction sent to the model together with the audio.
      Default: "Transcribe this audio to plain text. Output only the transcription."
      Example: prompt = Transcribe this audio. Keep filler words.
  pipe_command = <shell command>
      If set, the transcription text is piped through this shell command
      (text on stdin, transformed text read from stdout) before it is
      printed and ultimately inputted (typed) at the cursor. Example:
        pipe_command = sed -e 's/um //g' -e 's/uh //g'
"""

import argparse
import base64
import json
import os
import subprocess
import sys

import requests

DEFAULTS = {
    "api_url": "https://openrouter.ai/api/v1/chat/completions",
    "model": "google/gemini-2.5-flash",  # supports audio input
    "api_key_file": "/run/secrets/OPENROUTER_API_KEY",
    "prompt": "Transcribe this audio to plain text. Output only the transcription.",
    "pipe_command": None,
}

# all keys accepted in the config file
CONFIG_KEYS = set(DEFAULTS)

# env var -> config key it overrides
ENV_OVERRIDES = {
    "OPENROUTER_API_URL": "api_url",
    "OPENROUTER_MODEL": "model",
    "OPENROUTER_API_KEY_FILE": "api_key_file",
}

# command line option -> config key it overrides
CLI_OPTIONS = {
    "--api-url": "api_url",
    "--model": "model",
    "--api-key-file": "api_key_file",
    "--prompt": "prompt",
    "--pipe-command": "pipe_command",
}


def load_key(api_key_file: str) -> str:
    key = os.environ.get("OPENROUTER_API_KEY")
    if key:
        return key.strip()
    with open(api_key_file) as f:
        return f.read().strip()


def detect_format(data: bytes, path: str) -> str:
    if data[:4] == b"RIFF" and data[8:12] == b"WAVE":
        return "wav"
    if data[:3] == b"ID3" or (len(data) > 1 and data[0] == 0xFF and (data[1] & 0xE0) == 0xE0):
        return "mp3"
    ext = os.path.splitext(path)[1].lstrip(".").lower()
    if ext in {"wav", "mp3", "ogg", "flac", "aac", "opus", "webm", "m4a"}:
        return ext if ext != "m4a" else "aac"
    raise ValueError(f"Cannot determine audio format for {path!r}")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="transcribe.py",
        description="Transcribe an audio file or stream via OpenRouter.",
    )
    parser.add_argument(
        "audio",
        nargs="?",
        help="path to the audio file, or '-' to read raw audio from stdin",
    )
    parser.add_argument(
        "--config",
        metavar="FILE",
        help="configuration file to use (overrides $VOICE_INPUT_CONFIG and the"
        " default search path)",
    )
    for option, key in CLI_OPTIONS.items():
        parser.add_argument(
            option,
            metavar="VALUE",
            help=f"override the '{key}' configuration parameter",
        )
    return parser.parse_args(argv)


def config_path(explicit: str | None = None) -> str | None:
    """Return the path of the config file to use, or None if there is none."""
    if explicit:
        if not os.path.isfile(explicit):
            sys.exit(f"voice-input: config file not found: {explicit}")
        return explicit
    explicit = os.environ.get("VOICE_INPUT_CONFIG")
    if explicit:
        if not os.path.isfile(explicit):
            sys.exit(f"voice-input: config file not found: {explicit}")
        return explicit
    xdg = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    path = os.path.join(xdg, "voice-input", "config")
    return path if os.path.isfile(path) else None


def load_config(path: str | None) -> dict:
    """Parse the config file and return the configuration (defaults merged in)."""
    config = dict(DEFAULTS)
    if path is None:
        return config
    seen: set[str] = set()
    with open(path) as f:
        for lineno, raw in enumerate(f, 1):
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            if "=" not in line:
                sys.exit(f"voice-input: malformed line {lineno} in {path} (expected 'key = value'): {line!r}")
            key, _, value = line.partition("=")
            key, value = key.strip().lower(), value.strip()
            if key not in CONFIG_KEYS:
                sys.exit(f"voice-input: unknown config key {key!r} in {path} (line {lineno})")
            if key in seen:
                sys.exit(f"voice-input: duplicate {key!r} in {path} (line {lineno})")
            if not value:
                sys.exit(f"voice-input: {key!r} has an empty value in {path} (line {lineno})")
            seen.add(key)
            config[key] = value
    return config


def pipe_through(text: str, command: str) -> str:
    """Pipe text through a shell command (text on stdin, output from stdout)."""
    proc = subprocess.run(
        command,
        shell=True,
        input=text,
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        stderr = proc.stderr.strip()
        raise RuntimeError(
            f"pipe command {command!r} failed with exit code {proc.returncode}"
            + (f": {stderr[:500]}" if stderr else "")
        )
    return proc.stdout


def transcribe(audio: bytes, fmt: str, key: str, model: str, api_url: str, prompt: str) -> str:
    payload = {
        "model": model,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {
                        "type": "input_audio",
                        "input_audio": {
                            "data": base64.b64encode(audio).decode(),
                            "format": fmt,
                        },
                    },
                ],
            }
        ],
    }
    resp = requests.post(
        api_url,
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        },
        json=payload,
        timeout=120,
    )
    if resp.status_code != 200:
        sys.exit(f"OpenRouter API error {resp.status_code}: {resp.text[:2000]}")
    result = resp.json()
    if "error" in result:
        sys.exit(f"OpenRouter error: {json.dumps(result['error'])[:2000]}")
    return result["choices"][0]["message"]["content"]


def main() -> None:
    args = parse_args(sys.argv[1:])
    if args.audio is None:
        sys.exit("transcribe.py: no audio file given (usage: transcribe.py <file> | -)"
                 " [--config FILE] [--api-url URL] [--model ID]"
                 " [--api-key-file FILE] [--prompt TEXT] [--pipe-command CMD]")
    path = args.audio

    #parse the config first so config errors fail fast, before reading/transcribing
    config = load_config(config_path(args.config))

    #environment variables override the config file (see docstring for precedence)
    for env_var, key in ENV_OVERRIDES.items():
        if os.environ.get(env_var):
            config[key] = os.environ[env_var]

    #command line options have the highest precedence (see docstring)
    for option, key in CLI_OPTIONS.items():
        value = getattr(args, option[2:].replace("-", "_"))
        if value is not None:
            config[key] = value

    if path == "-":
        audio = sys.stdin.buffer.read()
        fmt = detect_format(audio, "stream")
    else:
        with open(path, "rb") as f:
            audio = f.read()
        fmt = detect_format(audio, path)

    key = load_key(config["api_key_file"])
    text = transcribe(
        audio,
        fmt,
        key,
        config["model"],
        config["api_url"],
        config["prompt"],
    )

    #optionally pipe the transcription through a command from the config file
    #before it is printed (and later inputted/typed at the cursor)
    command = config["pipe_command"]
    if command:
        try:
            text = pipe_through(text, command)
        except RuntimeError as e:
            sys.exit(f"voice-input: {e}")
    print(text)


if __name__ == "__main__":
    main()
