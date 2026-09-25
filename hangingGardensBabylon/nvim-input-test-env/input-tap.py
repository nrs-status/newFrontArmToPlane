#!/usr/bin/env python3
"""PTY tap used by nvim-input-test-env.

Runs a command (normally Neovim) inside a fresh pseudo-terminal while
intercepting every byte the user sends to it.  Everything read from the
user's tty is appended, chunk by chunk, to a log file as a single
``[USER <time>] ...`` line.  Neovim writes its own ``[NVIM ...]`` lines to the
same file via ``vim.on_key`` (see nvim-key-log.lua), so a single

    tail -f <log>

shows the raw input stream and the keypresses Neovim actually registered,
side by side.

Usage::

    input-tap.py [--log LOGFILE] -- COMMAND [ARGS...]

If ``--log`` is omitted, ``$NVIM_INPUT_LOG`` is used, falling back to
``/tmp/nvim-input-test-env/nvim-input.log``.
"""

import errno
import fcntl
import os
import pty
import select
import signal
import sys
import termios
import time
import tty

DEFAULT_LOG = "/tmp/nvim-input-test-env/nvim-input.log"


def parse_args(argv):
    log = os.environ.get("NVIM_INPUT_LOG") or DEFAULT_LOG
    if "--" in argv:
        i = argv.index("--")
        pre, cmd = argv[:i], argv[i + 1:]
    else:
        pre, cmd = [], list(argv)

    j = 0
    while j < len(pre):
        if pre[j] == "--log" and j + 1 < len(pre):
            log = pre[j + 1]
            j += 2
        else:
            j += 1
    return log, cmd


def render(data):
    """Make a raw byte chunk readable without losing control characters."""
    parts = []
    for b in data:
        if b == 0x1B:
            parts.append("<Esc>")
        elif b == 0x0D:
            parts.append("<CR>")
        elif b == 0x0A:
            parts.append("<LF>")
        elif b == 0x09:
            parts.append("<Tab>")
        elif b == 0x20:
            parts.append("<Space>")
        elif b == 0x7F:
            parts.append("<BS>")
        elif 0x20 < b < 0x7F:
            parts.append(chr(b))
        else:
            parts.append("<0x%02x>" % b)
    return "".join(parts)


def main():
    log_path, cmd = parse_args(sys.argv[1:])
    if not cmd:
        sys.stderr.write("input-tap: no command given\n")
        return 2

    log_path = os.path.abspath(log_path)
    log_dir = os.path.dirname(log_path)
    if log_dir:
        os.makedirs(log_dir, exist_ok=True)
    log_fd = os.open(log_path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o644)

    def log(tag, data):
        line = "[%s %s] %s\n" % (tag, time.strftime("%H:%M:%S"), render(data))
        os.write(log_fd, line.encode("utf-8", "replace"))

    stdin_fd = sys.stdin.fileno()
    stdout_fd = sys.stdout.fileno()
    stdin_isatty = os.isatty(stdin_fd)

    old_term = None
    if stdin_isatty:
        old_term = termios.tcgetattr(stdin_fd)
        tty.setraw(stdin_fd)

    log("USER", b"=== input tap attached ===")

    pid, master = pty.fork()
    if pid == 0:  # child: becomes Neovim with the pty slave on fd 0/1/2
        try:
            os.execvp(cmd[0], cmd)
        except OSError as exc:
            os.write(2, ("input-tap: exec failed: %s\n" % exc).encode())
        os._exit(127)

    def propagate_winsize(*_args):
        if not stdin_isatty:
            return
        try:
            size = fcntl.ioctl(stdin_fd, termios.TIOCGWINSZ, b"\0" * 8)
            fcntl.ioctl(master, termios.TIOCSWINSZ, size)
        except OSError:
            pass

    propagate_winsize()
    signal.signal(signal.SIGWINCH, propagate_winsize)

    poller = select.poll()
    poller.register(master, select.POLLIN)
    poller.register(stdin_fd, select.POLLIN)

    child_gone = False
    try:
        while not child_gone:
            try:
                events = poller.poll()
            except InterruptedError:
                continue
            for fd, _events in events:
                if fd == master:
                    try:
                        data = os.read(master, 65536)
                    except OSError as exc:
                        if exc.errno == errno.EIO:
                            child_gone = True
                            break
                        raise
                    if not data:
                        child_gone = True
                        break
                    try:
                        os.write(stdout_fd, data)
                    except OSError:
                        pass
                elif fd == stdin_fd:
                    try:
                        data = os.read(stdin_fd, 4096)
                    except OSError as exc:
                        if exc.errno == errno.EIO:
                            data = b""
                        else:
                            raise
                    if not data:
                        try:
                            poller.unregister(stdin_fd)
                        except (KeyError, OSError):
                            pass
                        continue
                    log("USER", data)
                    try:
                        os.write(master, data)
                    except OSError as exc:
                        if exc.errno == errno.EIO:
                            child_gone = True
                            break
                        raise
    finally:
        if old_term is not None:
            termios.tcsetattr(stdin_fd, termios.TCSADRAIN, old_term)
        os.close(log_fd)

    _, status = os.waitpid(pid, 0)
    if os.WIFEXITED(status):
        return os.WEXITSTATUS(status)
    if os.WIFSIGNALED(status):
        return 128 + os.WTERMSIG(status)
    return 0


if __name__ == "__main__":
    sys.exit(main())
