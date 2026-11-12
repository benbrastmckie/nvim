#!/usr/bin/env python3
"""Unit tests for sf1_proxy.SeparatorFilter.

Run with: python3 lua/neotex/plugins/ai/sapience/sf1_proxy_test.py

Pure stdlib `unittest`, no network, no vendor dependency, no pty: every case here constructs a
synthetic byte transcript shaped like sf1's real output and feeds it directly to
`SeparatorFilter.feed()`. The pty harness itself (Phase 2) is covered by stub-child smoke tests
appended later in this same file.
"""

import os
import subprocess
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sf1_proxy import SeparatorFilter  # noqa: E402


def _handoff_line(colored=True):
    if colored:
        return b"\x1b[32mpicked up: something interesting\x1b[0m\n"
    return b"picked up: something interesting\n"


def _banner_line(colored=True):
    text = b"sf1 1.0 on host. /help for commands, Ctrl-D to quit.\n"
    if colored:
        return b"\x1b[2m" + text[:-1] + b"\x1b[0m\n"
    return text


def _prompt(project=None):
    if project:
        return ("sf1/%s > " % project).encode("utf-8")
    return b"sf1 > "


def _sources_line(colored=True):
    text = b"sources: [1] Example Source\n"
    if colored:
        return b"\x1b[2m" + text[:-1] + b"\x1b[0m\n"
    return text


def _full_turn_transcript():
    """One realistic turn: handoff -> banner -> prompt -> user line -> answer -> sources ->
    next prompt. Four separator sites: after the handoff line (B1), before the first prompt
    (B3), after the user's submitted line (B2), and before the second prompt (B3 again)."""
    return (
        _handoff_line()
        + _banner_line()
        + _prompt()
        + b"hello\n"
        + b"This is the streamed answer.\n"
        + _sources_line()
        + _prompt()
    )


class FullTurnTranscriptTest(unittest.TestCase):
    def test_four_separators_at_the_right_boundaries(self):
        f = SeparatorFilter(separator="blank")
        transcript = _full_turn_transcript()
        # note_submit() must be armed at the moment the harness forwards the user's Enter
        # keystroke, which is chronologically right before the child echoes "hello\n" -- not
        # before the whole transcript, which would let the handoff line's own \n consume it.
        pre, _, post = transcript.partition(b"hello\n")
        out = f.feed(pre)
        f.note_submit()
        out += f.feed(b"hello\n")
        out += f.feed(post)

        handoff_idx = out.index(b"\x1b[0m\n") + len(b"\x1b[0m\n")
        self.assertEqual(out[handoff_idx:handoff_idx + 1], b"\n", "B1: separator after handoff")

        first_prompt_idx = out.index(_prompt())
        self.assertEqual(
            out[first_prompt_idx - 1:first_prompt_idx], b"\n",
            "B3: separator before first (fresh) prompt",
        )

        hello_nl_idx = out.index(b"hello\n") + len(b"hello\n")
        self.assertEqual(out[hello_nl_idx:hello_nl_idx + 1], b"\n", "B2: separator after submit")

        second_prompt_idx = out.rindex(_prompt())
        self.assertEqual(
            out[second_prompt_idx - 1:second_prompt_idx], b"\n",
            "B3: separator before second (fresh) prompt",
        )
        self.assertNotEqual(first_prompt_idx, second_prompt_idx)


class ReadlineRedrawTest(unittest.TestCase):
    def test_redraw_reemission_yields_exactly_one_separator(self):
        f = SeparatorFilter(separator="blank")
        # Fresh arrival at the prompt (via \n): the \n itself, then exactly one injected
        # separator, then the prompt -- two consecutive \n bytes here is the correct rendering
        # of "a blank-line separator right after a genuine newline", not a double injection.
        first = f.feed(b"\n" + _prompt())
        self.assertEqual(first, b"\n\n" + _prompt())

        # Readline redraws: \r then the same prompt text, repeated. None of these are "fresh"
        # (arrived via \r, not \n), so each must be forwarded byte-for-byte with zero insertion.
        for _ in range(5):
            redraw = f.feed(b"\r" + _prompt())
            self.assertEqual(redraw, b"\r" + _prompt())

    def test_fails_without_the_cr_discrimination_rule(self):
        # Documents the property the plan's verification step exercises manually (temporarily
        # treat \r as if it were \n and observe this exact assertion fail, then revert): a
        # prompt reached via \r must never match. This test asserts the correct behavior
        # directly; it is not itself the manual inversion drill.
        f = SeparatorFilter(separator="blank")
        f.feed(b"\n")
        out = f.feed(b"\r" + _prompt())
        self.assertNotIn(b"\n" + _prompt(), out)


class TransientIndicatorTest(unittest.TestCase):
    def test_injection_suppressed_while_indicator_active(self):
        f = SeparatorFilter(separator="blank")
        # Show the indicator, then -- while it is active -- emit a handoff-shaped line. No
        # separator should appear, because injection is suppressed while the indicator is live.
        out = f.feed(b"\r\x1b[2k".replace(b"2k", b"2K") + b"thinking" + _handoff_line())
        self.assertNotIn(b"\x1b[0m\n\n", out, "no separator while indicator is active")

        # Clear the indicator (second occurrence of the same toggle sequence), then repeat the
        # handoff line: now the separator must appear normally.
        f.feed(b"\r\x1b[2K")
        out2 = f.feed(_handoff_line())
        self.assertIn(b"\x1b[0m\n\n", out2, "separator restored once indicator clears")


class ByteAtATimeEquivalenceTest(unittest.TestCase):
    def test_one_byte_at_a_time_matches_whole_chunk(self):
        transcript = _full_turn_transcript()
        pre, _, post = transcript.partition(b"hello\n")
        offset = len(pre)

        # Whole-chunk run, split into exactly the three pieces note_submit's timing requires.
        whole = SeparatorFilter(separator="blank")
        chunk1 = whole.feed(pre)
        whole.note_submit()
        chunk2 = whole.feed(b"hello\n")
        chunk3 = whole.feed(post)
        whole_combined = chunk1 + chunk2 + chunk3

        # Byte-at-a-time run, arming note_submit at the identical transcript offset.
        per_byte = SeparatorFilter(separator="blank")
        out = bytearray()
        for i in range(len(transcript)):
            if i == offset:
                per_byte.note_submit()
            out += per_byte.feed(transcript[i:i + 1])

        self.assertEqual(bytes(out), whole_combined)


class SeparatorNoneIdentityTest(unittest.TestCase):
    def test_none_is_a_pure_identity_passthrough(self):
        f = SeparatorFilter(separator="none")
        transcript = _full_turn_transcript()
        f.note_submit()
        self.assertEqual(f.feed(transcript), transcript)

    def test_unrecognized_separator_value_degrades_to_none(self):
        f = SeparatorFilter(separator="not-a-real-value")
        transcript = _full_turn_transcript()
        self.assertEqual(f.feed(transcript), transcript)


class NoColorTest(unittest.TestCase):
    def test_rule_separator_omits_dim_wrapper_when_color_disabled(self):
        f = SeparatorFilter(separator="rule", width=10, color=False)
        f.note_submit()
        out = f.feed(b"\nhi\n")
        self.assertNotIn(b"\x1b[2m", out)
        self.assertNotIn(b"\x1b[0m", out)
        self.assertIn(("─" * 10).encode("utf-8"), out)

    def test_rule_separator_includes_dim_wrapper_when_color_enabled(self):
        f = SeparatorFilter(separator="rule", width=10, color=True)
        f.note_submit()
        out = f.feed(b"\nhi\n")
        self.assertIn(b"\x1b[2m", out)
        self.assertIn(b"\x1b[0m", out)


class ChunkBoundarySplitTest(unittest.TestCase):
    def test_marker_split_across_two_feed_calls_still_matches(self):
        f = SeparatorFilter(separator="blank")
        line = _handoff_line()
        mid = len(line) // 2
        out = f.feed(line[:mid]) + f.feed(line[mid:])
        self.assertEqual(out[:len(line)], line)
        self.assertEqual(out[len(line):], b"\n")

    def test_prompt_split_across_many_feed_calls(self):
        f = SeparatorFilter(separator="blank")
        f.feed(b"\n")
        prompt = _prompt("myproj")
        out = bytearray()
        for i in range(len(prompt)):
            out += f.feed(prompt[i:i + 1])
        self.assertEqual(bytes(out), b"\n" + prompt)


_PROXY_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sf1_proxy.py")

# A deliberately tiny, scripted "sf1-shaped" transcript -- never the real sf1 binary, so this
# test suite has no network dependency and no vendor dependency in its test path. It asserts
# its own stdout is a real tty (proving the pty path is genuinely in use, not a pipe), prints a
# banner, a prompt, reads one line, echoes it with a trailing sources-shaped line, prints a
# second prompt, then exits 42 immediately (never waiting on a second `input()`: this process's
# own stdin reaching EOF -- as `communicate()` deliberately does below -- stops forwarding into
# the child's pty but, exactly like a real terminal, does not itself deliver EOF to the child's
# still-open pty slave; a stub that waited on a second line would hang forever on exactly that
# real-terminal property, which is not what this smoke test is exercising).
_STUB_CHILD_SRC = (
    "import sys\n"
    "assert sys.stdout.isatty(), 'stub child expected a real tty, pty path is not in use'\n"
    "sys.stderr.write('sf1 1.0 on host. /help for commands, Ctrl-D to quit.\\n')\n"
    "sys.stderr.flush()\n"
    "sys.stdout.write('sf1 > ')\n"
    "sys.stdout.flush()\n"
    "try:\n"
    "    line = input()\n"
    "except EOFError:\n"
    "    sys.exit(0)\n"
    "sys.stdout.write('you said: ' + line + '\\n')\n"
    "sys.stdout.write('sources: [1] Example Source\\n')\n"
    "sys.stdout.write('sf1 > ')\n"
    "sys.stdout.flush()\n"
    "sys.exit(42)\n"
)


def _run_proxy(stub_src, stdin_bytes, separator="blank", timeout=10):
    proc = subprocess.Popen(
        [sys.executable, _PROXY_PATH, "--separator", separator, "--", sys.executable, "-c", stub_src],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    out, err = proc.communicate(input=stdin_bytes, timeout=timeout)
    return proc.returncode, out, err


class StubChildPtySmokeTest(unittest.TestCase):
    """Exercises the real pty harness (fork, setsid, TIOCSCTTY, select loop, winsize, exit
    status) against a stub child -- never against real sf1."""

    def test_separators_appear_and_output_reaches_this_process(self):
        code, out, err = _run_proxy(_STUB_CHILD_SRC, b"hello\n")
        self.assertEqual(err, b"", "stub child's own stderr must come back via the pty, not leak")
        # Separator before the first (fresh) prompt, reached via \n from the banner line.
        self.assertIn(b"\n\nsf1 > ", out)
        # Separator after the submitted "hello" line (B2).
        self.assertIn(b"hello\r\n\n", out)
        # A second, later "sf1 > " occurrence also got its own fresh-prompt separator.
        self.assertEqual(out.count(b"sf1 > "), 2)
        self.assertEqual(code, 42, "stub child's own exit code must reach the proxy's exit code")

    def test_stdin_forwarding_reaches_the_stub(self):
        code, out, _err = _run_proxy(_STUB_CHILD_SRC, b"a distinctive line\n")
        self.assertIn(b"you said: a distinctive line", out)
        self.assertEqual(code, 42)

    def test_signal_death_propagates_as_128_plus_signum(self):
        import signal

        stub = (
            "import os, signal, sys\n"
            "sys.stdout.write('sf1 > ')\n"
            "sys.stdout.flush()\n"
            "os.kill(os.getpid(), signal.SIGTERM)\n"
        )
        code, _out, _err = _run_proxy(stub, b"")
        self.assertEqual(code, 128 + signal.SIGTERM)

    def test_separator_none_leaves_prompt_unseparated(self):
        code, out, _err = _run_proxy(_STUB_CHILD_SRC, b"hi\n", separator="none")
        self.assertNotIn(b"\n\nsf1 > ", out)
        self.assertEqual(code, 42)


if __name__ == "__main__":
    unittest.main()
