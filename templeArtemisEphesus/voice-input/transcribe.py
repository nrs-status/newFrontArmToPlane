#!/usr/bin/env python3
"""
Transcribe an audio file or stream via OpenRouter.

Usage:
  python3 transcribe.py out.wav
  python3 transcribe.py audio.mp3
  some-command | python3 transcribe.py -          # read raw audio from stdin

Reads the API key from /run/secrets/OPENROUTER_API_KEY
(or $OPENROUTER_API_KEY_FILE / $OPENROUTER_API_KEY).
Model can be overridden with $OPENROUTER_MODEL.
"""

import base64
import json
import os
import sys

import requests

API_URL = "https://openrouter.ai/api/v1/chat/completions"
DEFAULT_MODEL = "google/gemini-2.5-flash"  # supports audio input
KEY_FILE_DEFAULT = "/run/secrets/OPENROUTER_API_KEY"

TRANSCRIPTION_PROMPT = "Transcribe this audio to plain text. Output only the transcription."


def load_key() -> str:
    key = os.environ.get("OPENROUTER_API_KEY")
    if key:
        return key.strip()
    key_file = os.environ.get("OPENROUTER_API_KEY_FILE", KEY_FILE_DEFAULT)
    with open(key_file) as f:
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


def transcribe(audio: bytes, fmt: str, key: str, model: str) -> str:
    payload = {
        "model": model,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": TRANSCRIPTION_PROMPT},
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
        API_URL,
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
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    path = args[0]

    if path == "-":
        audio = sys.stdin.buffer.read()
        fmt = detect_format(audio, "stream")
    else:
        with open(path, "rb") as f:
            audio = f.read()
        fmt = detect_format(audio, path)

    key = load_key()
    model = os.environ.get("OPENROUTER_MODEL", DEFAULT_MODEL)
    text = transcribe(audio, fmt, key, model)
    print(text)


if __name__ == "__main__":
    main()
