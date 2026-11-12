#!/usr/bin/env python3
"""Unit tests for sf1_proxy.SeparatorFilter.

Run with: python3 lua/neotex/plugins/ai/sapience/sf1_proxy_test.py

Pure stdlib `unittest`, no network, no vendor dependency, no pty: every case here constructs a
synthetic byte transcript shaped like sf1's real output and feeds it directly to
`SeparatorFilter.feed()`. The pty harness itself (Phase 2) is covered by stub-child smoke tests
appended later in this same file.
"""

import os
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


if __name__ == "__main__":
    unittest.main()
