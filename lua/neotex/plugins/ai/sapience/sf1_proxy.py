#!/usr/bin/env python3
"""sf1_proxy -- a pty-proxying wrapper that inserts visual separators into sf1's output.

sf1 (the Sapience terminal chat client, ``~/.sapience/sf1.py``) is a vendor-owned, untracked
payload that a daily auto-update can silently overwrite. This module is never installed there
and never edits it; instead it wraps sf1 under a pseudo-terminal it owns and rewrites the
merged output byte stream on the fly, inserting a blank line (or a dim horizontal rule) at the
three points where sf1 currently prints nothing between message parts, so a chat transcript in
a Neovim terminal pane reads like Claude Code's turn-separated output instead of one unbroken
wall of text.

Marker contract (re-verified against the live ``~/.sapience/sf1.py``, 653 lines, mtime
2026-11-03 -- re-check this table against that file before trusting it, since sf1 is exactly
the kind of vendor payload this module must never assume is stable):

================  ============================================  ========  ================================
Boundary          Literal marker                                 Stream    If the vendor changes this text
================  ============================================  ========  ================================
Handoff banner    ``picked up:``   (``Session.start``)            stderr    ``SeparatorFilter`` stops
                                                                             matching B1; the handoff line
                                                                             prints with no separator after
                                                                             it (degrades to no-op, never an
                                                                             error).
Startup banner    ``sf1 {ver} on {host}. /help for commands,``    stderr    Not matched by this filter at
                   ``Ctrl-D to quit.``  (``main``)                          all -- informational only, kept
                                                                             here so a future reader has the
                                                                             full picture of what sf1 writes
                                                                             before the first prompt.
Turn prompt       ``sf1 > `` / ``sf1/{project} > ``               stdout    ``SeparatorFilter`` stops
                   (``_prompt``; deliberately never colored --              matching B3; no separator is
                   see that function's own docstring)                      injected before the prompt, which
                                                                             reverts to sf1's current
                                                                             run-together appearance.
Sources line      ``sources: [n] subject  ...``   (``Session.ask``) stdout   Not matched directly; this
                                                                             filter separates it from what
                                                                             follows via B3 (the *next*
                                                                             prompt), not by matching this
                                                                             line's own text.
Transient status  ``\\r\\x1b[2K`` + dim text, written twice        stderr    If the vendor ever stops pairing
                   (shown, then cleared with the same bytes               the clear with an identical show
                   before any stdout write)                               sequence, ``_indicator_active``
                                                                             can desync and suppress one
                                                                             separator later in the session --
                                                                             never corrupts the stream, since
                                                                             suppression only ever *drops* an
                                                                             insertion, it never drops or
                                                                             reorders a byte of sf1's own
                                                                             output.
================  ============================================  ========  ================================

A single pty merges sf1's stdout and stderr into one byte stream (see the harness below), so
``SeparatorFilter`` watches one stream, not two.

Insertion boundaries (exactly three -- this is deliberately smaller than the five markers
above; the startup banner and the sources line are watched only as *context*, not as their own
insertion points):

- **B1**: one separator immediately after the newline that terminates the ``picked up:``
  handoff line.
- **B2**: one separator immediately after the echoed newline that follows a user-submitted
  line. This boundary needs no OUTPUT pattern matching at all: the pty harness calls
  ``SeparatorFilter.note_submit()`` the moment it forwards a submitted CR/LF keystroke from
  stdin, and the very next newline this filter sees on the (merged, echoed) output stream
  consumes that arming and gets the separator.
- **B3**: one separator immediately before a *fresh* prompt occurrence, including the very
  first prompt of a session (there is no special case excluding it: a prompt reached via a
  genuine newline is always "fresh"). "Fresh" excludes a readline redraw: GNU readline
  re-emits the prompt text verbatim on every line edit (arrow key, Home, backspace, a resize),
  always by first writing ``\\r`` to return to column 0 -- never ``\\n``. A prompt match counts
  as fresh only when this filter is at line start having arrived there via ``\\n``; arrival via
  ``\\r`` structurally disqualifies the match (``_prompt_candidate`` is never armed on a ``\\r``
  arrival), so a redraw cannot re-trigger B3 even if the vendor's prompt text matches exactly.
  A one-shot latch (``_prompt_latch``) additionally guards the same prompt occurrence against a
  second injection; it clears on the next child-emitted ``\\n``.

Pass-through-on-no-match is the design default throughout: every byte that matches nothing is
returned unchanged, in order, with nothing dropped and nothing duplicated, even when a marker
is split across two separate ``feed()`` calls (the filter's state persists across calls for
exactly this reason). The failure mode for a vendor text change is therefore always "no
dividers", never a crash or a corrupted pane.
"""

import errno
import fcntl
import os
import pty
import re
import select
import signal
import struct
import sys
import termios
import tty

# ---------------------------------------------------------------------------
# Marker constants (kept next to the class that uses them, not duplicated).
# ---------------------------------------------------------------------------

_B1_MARKER = b"picked up:"

# `_prompt()` in sf1.py: 'sf1%s > ' % (('/' + project) if project else ''). Anchored full match
# only -- a *prefix* of this pattern is tracked separately in `_is_prompt_prefix` below, since
# the filter must decide, byte by byte, whether a still-growing buffer could still become this.
_PROMPT_RE = re.compile(rb"^sf1(?:/[^ \r\n]*)? > $")

# The exact byte sequence sf1 writes both to show and to clear the transient status indicator
# (`sf1.py` lines ~270/273). Each occurrence toggles `_indicator_active`.
_INDICATOR_SEQ = b"\r\x1b[2K"

# Safety valve bounding how many bytes this filter will hold while still deciding whether a
# fresh line is building toward a prompt match. `_prompt()`'s own grammar is unbounded only in
# the project-name segment; a pathological project name (or an unmatched "sf1..." line that
# never resolves) gives up and flushes verbatim once this bound is hit, so a non-prompt line
# starting with "sf1" is never held back indefinitely.
_MAX_PROMPT_BUF = 128

_DIM_ON = b"\x1b[2m"
_DIM_OFF = b"\x1b[0m"


def _is_prompt_prefix(buf: bytes) -> bool:
    """True if `buf` (bytes seen so far at a fresh line start, containing no \\r or \\n) could
    still become a full match of `_PROMPT_RE` once more bytes arrive."""
    lit = b"sf1"
    if len(buf) <= len(lit):
        return buf == lit[: len(buf)]
    rest = buf[len(lit):]
    if rest[0:1] == b"/":
        i = 1
        while i < len(rest) and rest[i:i + 1] != b" ":
            i += 1
        tail = rest[i:]
    else:
        tail = rest
    full_tail = b" > "
    if len(tail) > len(full_tail):
        return False
    return full_tail[: len(tail)] == tail


class SeparatorFilter:
    """Pure byte-chunk -> byte-chunk stream filter. No I/O, no pty, no global state: every
    piece of state this class needs lives on the instance, so it is fully unit-testable without
    a subprocess, a pty, or a real sf1 session.

    `feed(chunk)` is the entire public surface for stream processing; `note_submit()` is the
    one side-channel the pty harness uses to drive boundary B2 from the input side; `set_width`
    lets the harness keep a `rule` separator's width in sync with `SIGWINCH`.
    """

    def __init__(self, separator="blank", width=80, color=True):
        if separator not in ("blank", "rule", "none"):
            separator = "none"
        self._separator = separator
        self._width = max(1, int(width or 80))
        self._color = bool(color)

        # B1: does the current line (since its own start) contain the handoff marker.
        self._line_tail = b""
        self._line_has_b1 = False

        # B3: fresh-prompt candidate buffering.
        self._prompt_candidate = True  # stream start counts as a fresh line.
        self._prompt_buf = b""
        self._prompt_latch = False

        # Transient `\r\x1b[2K` indicator toggle -- fed every raw byte, control bytes included.
        self._indicator_active = False
        self._raw_tail = b""

        # B2: armed by the harness; consumed by the next child-emitted `\n`.
        self._submit_armed = False

    def note_submit(self):
        """Arm boundary B2. Called by the pty harness the moment it forwards a CR/LF keystroke
        read from its own stdin to the child. Purely an input-side trigger -- this boundary
        performs no matching against sf1's output text at all."""
        self._submit_armed = True

    def set_width(self, width):
        """Update the `rule` separator's width (the harness calls this at startup and again on
        every `SIGWINCH`, so a rule separator tracks a resized pane)."""
        self._width = max(1, int(width or 80))

    def _rendered_separator(self) -> bytes:
        if self._separator == "none":
            return b""
        if self._separator == "blank":
            return b"\n"
        rule = ("─" * self._width).encode("utf-8")
        if self._color:
            return b"\n" + _DIM_ON + rule + _DIM_OFF + b"\n"
        return b"\n" + rule + b"\n"

    def feed(self, chunk: bytes) -> bytes:
        if self._separator == "none":
            return chunk

        out = bytearray()
        for i in range(len(chunk)):
            b = chunk[i:i + 1]

            # Universal, stateless-cost indicator scan: runs on every raw byte, independent of
            # everything else below, so a chunk boundary mid-sequence is handled correctly.
            self._raw_tail = (self._raw_tail + b)[-len(_INDICATOR_SEQ):]
            if self._raw_tail == _INDICATOR_SEQ:
                self._indicator_active = not self._indicator_active
                self._raw_tail = b""

            if b == b"\n":
                if self._prompt_buf:
                    out += self._prompt_buf
                    self._prompt_buf = b""
                inject = b""
                if self._submit_armed and not self._indicator_active:
                    inject += self._rendered_separator()
                self._submit_armed = False
                if self._line_has_b1 and not self._indicator_active:
                    inject += self._rendered_separator()
                out += b"\n" + inject
                self._line_has_b1 = False
                self._line_tail = b""
                self._prompt_candidate = True
                self._prompt_latch = False
                continue

            if b == b"\r":
                if self._prompt_buf:
                    out += self._prompt_buf
                    self._prompt_buf = b""
                out += b"\r"
                self._line_has_b1 = False
                self._line_tail = b""
                self._prompt_candidate = False
                continue

            # Ordinary content byte: B1 rolling-window scan (per-line; reset on \n and \r above).
            self._line_tail = (self._line_tail + b)[-(len(_B1_MARKER) + 4):]
            if _B1_MARKER in self._line_tail:
                self._line_has_b1 = True

            if self._prompt_candidate:
                tentative = self._prompt_buf + b
                if (
                    _PROMPT_RE.fullmatch(tentative)
                    and not self._prompt_latch
                    and not self._indicator_active
                ):
                    out += self._rendered_separator() + tentative
                    self._prompt_buf = b""
                    self._prompt_candidate = False
                    self._prompt_latch = True
                elif _PROMPT_RE.fullmatch(tentative):
                    # Matches, but suppressed (indicator active or already latched this
                    # occurrence): flush verbatim, no separator, stop trying for this line.
                    out += tentative
                    self._prompt_buf = b""
                    self._prompt_candidate = False
                elif _is_prompt_prefix(tentative) and len(tentative) < _MAX_PROMPT_BUF:
                    self._prompt_buf = tentative
                else:
                    out += tentative
                    self._prompt_buf = b""
                    self._prompt_candidate = False
            else:
                out += b

        return bytes(out)


# ---------------------------------------------------------------------------
# PTY harness -- wraps SeparatorFilter around a real child process.
#
# Deliberately a pty, never a pipe: a shell pipe turns the child's stdout into
# a non-tty, which disables both sf1's own color detection and GNU readline's
# line editing. `pty.openpty()` + `setsid()` + `TIOCSCTTY` gives the child a
# real controlling terminal instead.
# ---------------------------------------------------------------------------

_READ_CHUNK = 65536


def _color_wanted():
    """Mirrors sf1's own `color_wanted()` in `~/.sapience/sf1.py` exactly, so the proxy's
    `rule` separator is colored (or not) consistently with sf1's own output."""
    if os.environ.get("NO_COLOR") or os.environ.get("SF1_NO_COLOR") or "--no-color" in sys.argv:
        return False
    if os.environ.get("SF1_COLOR") == "1":
        return True
    return (
        hasattr(sys.stdout, "isatty")
        and sys.stdout.isatty()
        and os.environ.get("TERM") != "dumb"
    )


def _winsize(fd):
    """Read the terminal size of `fd` via `TIOCGWINSZ`. Returns `(rows, cols)`, falling back to
    `(24, 80)` when `fd` is not a tty (e.g. redirected stdin) or the ioctl otherwise fails."""
    try:
        packed = fcntl.ioctl(fd, termios.TIOCGWINSZ, struct.pack("HHHH", 0, 0, 0, 0))
        rows, cols, _, _ = struct.unpack("HHHH", packed)
        if rows > 0 and cols > 0:
            return rows, cols
    except Exception:
        pass
    return 24, 80


def parse_argv(argv):
    """Parse `--separator {blank,rule,none}` (default `blank`) followed by a `--` terminator
    and the child command. Everything after `--` is the child's own argv, untouched -- so sf1's
    own `--project` is never consumed by this proxy."""
    separator = "blank"
    i = 0
    n = len(argv)
    while i < n:
        a = argv[i]
        if a == "--":
            i += 1
            break
        if a == "--separator":
            if i + 1 >= n:
                raise SystemExit("sf1_proxy: --separator requires a value")
            separator = argv[i + 1]
            i += 2
            continue
        if a.startswith("--separator="):
            separator = a.split("=", 1)[1]
            i += 1
            continue
        raise SystemExit("sf1_proxy: unrecognized argument: %s" % a)
    else:
        # Reached end of argv without a `--` terminator at all.
        i = n

    child_argv = list(argv[i:])
    if separator not in ("blank", "rule", "none"):
        raise SystemExit(
            "sf1_proxy: --separator must be one of blank, rule, none (got %r)" % separator
        )
    if not child_argv:
        raise SystemExit("sf1_proxy: missing child command after `--`")
    return separator, child_argv


def _exec_child_in_place(child_argv):
    """Degradation path: pty allocation or termios setup failed. `exec` the child directly in
    the proxy's own process, in place of proxying it -- an unstyled but fully working session,
    never a broken one."""
    try:
        os.execvp(child_argv[0], child_argv)
    except FileNotFoundError:
        sys.stderr.write("sf1_proxy: %s: command not found\n" % child_argv[0])
        sys.exit(127)
    except Exception as exc:  # pragma: no cover - defensive
        sys.stderr.write("sf1_proxy: exec failed: %s\n" % exc)
        sys.exit(126)


def run_proxy(separator, child_argv):
    """Run `child_argv` under a pty, filtering its merged stdout/stderr through a
    `SeparatorFilter`, and return the exit code to propagate (`128 + signal` on a signal
    death). Degrades to a direct in-place `exec` of the child -- unstyled, never broken -- on
    any pty/termios setup failure."""
    stdin_fd = sys.stdin.fileno() if hasattr(sys.stdin, "fileno") else 0
    stdin_is_tty = os.isatty(stdin_fd)

    try:
        master_fd, slave_fd = pty.openpty()
    except Exception:
        _exec_child_in_place(child_argv)
        return 126  # unreachable unless execvp itself failed oddly

    saved_attrs = None
    if stdin_is_tty:
        try:
            saved_attrs = termios.tcgetattr(stdin_fd)
        except Exception:
            saved_attrs = None

    pid = os.fork()
    if pid == 0:
        # Child: new session, new controlling terminal, then exec.
        os.close(master_fd)
        try:
            os.setsid()
        except Exception:
            pass
        try:
            fcntl.ioctl(slave_fd, termios.TIOCSCTTY, 0)
        except Exception:
            pass
        os.dup2(slave_fd, 0)
        os.dup2(slave_fd, 1)
        os.dup2(slave_fd, 2)
        if slave_fd > 2:
            os.close(slave_fd)
        try:
            os.execvp(child_argv[0], child_argv)
        except FileNotFoundError:
            sys.stderr.write("sf1_proxy: %s: command not found\n" % child_argv[0])
            os._exit(127)
        except Exception as exc:  # pragma: no cover - defensive
            sys.stderr.write("sf1_proxy: exec failed: %s\n" % exc)
            os._exit(126)
        os._exit(127)  # pragma: no cover - unreachable

    # Parent.
    os.close(slave_fd)

    if stdin_is_tty and saved_attrs is not None:
        try:
            tty.setraw(stdin_fd)
        except Exception:
            saved_attrs = None  # nothing to restore if raw-mode setup itself failed

    rows, cols = _winsize(stdin_fd if stdin_is_tty else 1)
    sep_filter = SeparatorFilter(separator=separator, width=cols, color=_color_wanted())

    def _apply_winsize():
        try:
            packed = struct.pack("HHHH", rows, cols, 0, 0)
            fcntl.ioctl(master_fd, termios.TIOCSWINSZ, packed)
        except Exception:
            pass

    _apply_winsize()

    def _on_winch(signum, frame):
        nonlocal rows, cols
        rows, cols = _winsize(stdin_fd if stdin_is_tty else 1)
        sep_filter.set_width(cols)
        _apply_winsize()

    old_winch = signal.getsignal(signal.SIGWINCH) if hasattr(signal, "SIGWINCH") else None
    if hasattr(signal, "SIGWINCH"):
        signal.signal(signal.SIGWINCH, _on_winch)

    exit_code = 1
    try:
        stdin_open = True
        while True:
            watch_fds = [master_fd] + ([stdin_fd] if stdin_open else [])
            try:
                rlist, _, _ = select.select(watch_fds, [], [], 1.0)
            except InterruptedError:
                continue
            except OSError as exc:
                if exc.errno == errno.EINTR:
                    continue
                break

            if master_fd in rlist:
                try:
                    data = os.read(master_fd, _READ_CHUNK)
                except OSError:
                    data = b""
                if not data:
                    break
                filtered = sep_filter.feed(data)
                if filtered:
                    _write_all(1, filtered)

            if stdin_open and stdin_fd in rlist:
                try:
                    data = os.read(stdin_fd, _READ_CHUNK)
                except OSError:
                    data = b""
                if not data:
                    stdin_open = False
                else:
                    if b"\r" in data or b"\n" in data:
                        sep_filter.note_submit()
                    _write_all(master_fd, data)

            # Reap a child that exited while we were still draining its pty output.
            try:
                reaped_pid, status = os.waitpid(pid, os.WNOHANG)
            except ChildProcessError:
                reaped_pid, status = pid, None
            if reaped_pid == pid and status is not None:
                exit_code = _status_to_exit_code(status)
                # Drain any remaining buffered output before returning.
                try:
                    while True:
                        data = os.read(master_fd, _READ_CHUNK)
                        if not data:
                            break
                        _write_all(1, sep_filter.feed(data))
                except OSError:
                    pass
                return exit_code
    finally:
        if hasattr(signal, "SIGWINCH") and old_winch is not None:
            signal.signal(signal.SIGWINCH, old_winch)
        if saved_attrs is not None:
            try:
                termios.tcsetattr(stdin_fd, termios.TCSADRAIN, saved_attrs)
            except Exception:
                pass
        try:
            os.close(master_fd)
        except OSError:
            pass

    try:
        _, status = os.waitpid(pid, 0)
        exit_code = _status_to_exit_code(status)
    except ChildProcessError:
        pass
    return exit_code


def _status_to_exit_code(status):
    if os.WIFEXITED(status):
        return os.WEXITSTATUS(status)
    if os.WIFSIGNALED(status):
        return 128 + os.WTERMSIG(status)
    return 1


def _write_all(fd, data):
    view = memoryview(data)
    while view:
        n = os.write(fd, view)
        view = view[n:]


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    separator, child_argv = parse_argv(argv)
    return run_proxy(separator, child_argv)


if __name__ == "__main__":
    sys.exit(main())
