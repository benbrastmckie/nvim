# Research Report: Bounded-Waiter Hook False Positive on Documenting Prose

**Task**: 506 - Stop the bounded-waiter hook refusing a write whose prose documents the
anti-pattern the hook enforces
**Started**: 2026-11-06
**Completed**: 2026-11-06
**Effort**: small (single-file hook change + test fixtures; no shared library)
**Dependencies**: None filed. Ordering note only (not a dependency edge): land this task before
or alongside the open record delivering guidance prose into
`context/patterns/bounded-build-waiter.md` and `context/patterns/external-process-wait.md`,
since that prose is exactly the content class that trips this hook; until both land, author that
prose with Write/Edit.
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/hooks/validate-bounded-waiter.sh` (full read)
- Codebase: `agent-system/extensions/core/scripts/tests/test-validate-bounded-waiter.sh` (full read)
- Codebase: `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` (Rule 2 and
  incident narrative)
- Codebase: `agent-system/extensions/core/merge-sources/settings-hooks.json` (hook registration)
- Codebase: `agent-system/extensions/core/hooks/validate-no-task-references.sh` and
  `agent-system/extensions/core/scripts/lib/record-version-patterns.sh` (sibling textual-shape
  hooks; design precedent for region-stripping)
**Artifacts**:
- This report: `specs/506_bounded_waiter_hook_fires_on_documenting_prose/reports/01_heredoc-aware-hook-detector.md`
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md,
no-task-references-in-deliverables.md, no-record-versioning-in-deliverables.md

## Executive Summary

- The hook's three-leg conjunction (loop keyword + `sleep` + name-match liveness test) is tested
  against the **raw Bash command string**, with no awareness of heredoc syntax. A heredoc body
  that quotes the forbidden shape as documentation (not as control flow the shell will execute)
  satisfies all three legs textually and is refused exactly like a live waiter.
- Recommended fix: **Option 1 from the dispatch** — make the detector heredoc-aware by stripping
  heredoc *body* lines from the text tested against the conjunction, implemented as a
  self-contained, conservative awk pass inside `validate-bounded-waiter.sh` itself (no shared
  library, no change to the three-leg regex logic). The codebase already has an idiomatic
  precedent for exactly this shape of transformation: `record-version-patterns.sh`'s
  `strip_exempt_regions()` blanks lines between two markers with a one-pass awk filter; this
  fix is the same technique keyed on heredoc open/close syntax instead of a marker comment.
- Option 2 (narrow leg (a)/(b) to "command position") is rejected: it does not fix the motivating
  case, because a quoted shell example's `until`/`sleep` genuinely sit in command position inside
  the heredoc body — the false positive is about *data vs. control flow*, not about where in the
  line the keyword appears.
- Option 3 (declare Write/Edit-only authorship, sited pre-emptively) is rejected as the *primary*
  fix: it is the same documentation-as-prohibition strategy the hook's own header says already
  failed for Rule 2 itself, and the dispatch's own origin incident shows the instruction has to
  be re-issued by hand every time this content class is authored. It is retained only as a
  cheap, compatible refinement to the refusal message on the stripper's own conservative bail
  path (see Recommendations).
- The stripper is deliberately scoped to exactly one heredoc per command, with an
  identifier-only delimiter charset, and bails (leaves the command untouched, so the conjunction
  tests the raw text exactly as today) on anything it cannot parse confidently — ambiguity never
  resolves toward allowing a command that would have blocked today.

## Context & Scope

**What was researched**: the mechanics of `validate-bounded-waiter.sh`'s false positive on
heredoc-authored documentation, the three options named in the dispatch, prior art in this
codebase for similar textual-shape hooks, and a concrete, test-driven design for closing the gap
without weakening the live-waiter block.

**Constraints carried from the dispatch** (restated here only to frame the Findings/Decisions
below, not duplicated as a separate section): the live self-match waiter must stay blocked and
pinned by a test; fail-OPEN on every internal error; block via exit code 2 + stderr, never
`permissionDecision: deny`; keep the hook registered bare (no `2>/dev/null || echo '{}'`
wrapper); no shared library between this hook and its pattern document.

**Out of scope**: `scripts/claude-refresh.sh`'s `build_waiter_family()` reaper classifier (an
explicit non-goal per the hook's own header — cleanup and prevention are separate layers) and
any change to the three-leg conjunction's own matching logic (bare-word `pgrep`, `ps|grep`,
`until`/`while`, `sleep`) — this task changes what text the conjunction is tested against, never
the conjunction itself.

## Findings

### Codebase Patterns

**The hook's detection surface (`hooks/validate-bounded-waiter.sh`)**: a single `jq`-parsed
`COMMAND` string is tested with three independent `grep -qE` calls for (a) `\b(until|while)\b`,
(b) `\bsleep\b`, (c) `\bpgrep\b` OR `\bps\b[^|]*\|[^|]*\bgrep\b`. All three ANDed together ->
exit 2. There is no redirection-awareness, no quote-awareness, and no heredoc handling anywhere
in the file — confirmed by a direct read; a grep for `heredoc`/`here-doc` across
`agent-system/extensions/core/hooks/` and `scripts/lib/` returns nothing relevant to this hook.

**Why the false positive is exactly reproducible, not a one-off formatting accident**: a Bash
tool call's `tool_input.command` preserves the literal multi-line script text (including real
newline bytes), so a heredoc written to document the anti-pattern —
```
cat > plan.md <<'EOF'
Never do this:
until ! pgrep -f 'x/check.sh'; do sleep 20; done
EOF
```
— places `until`, `sleep`, and `pgrep` inside the SAME string the hook greps, all three legs
present verbatim, none of them inside shell control flow the shell will ever execute (the body
is inert data piped to `cat`'s stdout redirection). The hook cannot currently tell this apart
from the live incident command it exists to block.

**Sibling hooks already solve an adjacent problem the same way**: `validate-no-task-references.sh`
and `validate-no-record-versioning.sh` are also textual-shape PreToolUse hooks, but they trigger
on `Write|Edit` (matcher in `settings-hooks.json`), never on `Bash` — so they never face the
heredoc problem at all; their payload is already the complete target content, not a shell
command string containing an embedded sub-document. This is why no existing heredoc-stripping
logic shows up anywhere in this hook family: `validate-bounded-waiter.sh` is the *only* hook in
this family whose matcher is `Bash`, and heredoc bodies are a `Bash`-only hazard for a
raw-command-text detector.

**Existing idiom for region-stripping in this codebase**: `scripts/lib/record-version-patterns.sh`'s
`strip_exempt_regions()` is a one-pass awk filter that blanks every line between a
`version-ok:begin` / `version-ok:end` marker pair (or a single `version-ok` line), leaving all
other lines untouched, so the caller's own pattern tests run only against the non-exempt text.
That is structurally the same transformation this task needs — "blank/drop the lines between an
open marker and a close marker before testing patterns" — just driven by heredoc open/close
syntax (`<<'DELIM'` ... `DELIM`) instead of a hand-placed comment marker. It is cited here as a
design precedent for implementation style, not as a library to share: per the dispatch's hard
constraint, no shared library is introduced between this hook and anything else, and
`record-version-patterns.sh` is a different hook family's library serving a `Write|Edit` matcher
with structurally different input (file content, not a shell command string) — reusing it
directly would not fit even if sharing were permitted.

**Test suite shape**: `test-validate-bounded-waiter.sh` drives the hook as a real subprocess via
synthetic PreToolUse JSON on stdin, asserts on exit code (2 = blocked, 0 = allowed) plus a
stderr substring check for blocked cases, and is explicitly flagged (in its own header) as a
file that must be authored with Write/Edit, never a Bash heredoc, once the hook is deployed —
the exact hazard this task is about, already live for this very test file today.

### External Resources

Not applicable — this is a pure codebase/shell-semantics question; no external library or
documentation dependency is involved. Shell heredoc termination semantics (plain `<<DELIM`
requires an unindented line exactly equal to `DELIM`; `<<-DELIM` allows leading tabs/whitespace
on the terminator line; `<<<` is a here-string, not a heredoc, and must not be mistaken for one)
are drawn from POSIX shell grammar, not web research.

## Decisions

1. **Adopt Option 1** (heredoc-aware stripping). It is the only option that fixes the actual
   motivating case — text that is syntactically data, not control flow — without touching the
   conjunction's own matching strictness.
2. **Reject Option 2** (narrow leg (a)/(b) to command-position). The motivating false positive's
   `until ... do sleep 20; done` genuinely sits in command position *inside the heredoc body* —
   a reader (and a naive parser) would call it "in command position" because the quoted example
   is itself a syntactically valid one-line command. Command-position narrowing answers a
   different question ("is this keyword part of a command, or incidental English prose like
   'while this runs'?") than the one this task has: "is this text data being written to a file,
   or code the shell will execute?" Only heredoc/quote-awareness answers the latter.
3. **Reject Option 3 as the primary fix**, retain it as a secondary refinement. Declaring
   "author this content with Write/Edit" and siting that instruction pre-emptively is exactly
   the documentation-as-prohibition strategy the hook's own header says already failed for Rule
   2 (the hook exists because restating the rule in prose did not stop the original incident).
   The same failure mode recurs here: this dispatch's own origin incident shows the instruction
   already had to be issued, by hand, in-plan, for this exact task's own implement phase. A
   rule that must be re-remembered and re-stated every time this content class is authored is
   not a closed false-positive surface; it is the status quo with an extra reminder attached.
4. **Scope the stripper conservatively**: exactly one heredoc per command; delimiter restricted
   to `[A-Za-z_][A-Za-z0-9_]*` (optionally single- or double-quoted, or backslash-escaped —
   quoting only affects in-body expansion, never the terminator match, so it does not need to be
   tracked past delimiter extraction); bail (apply the conjunction to the ORIGINAL unmodified
   command, i.e. today's exact verdict) on: a second heredoc opener anywhere in the command, a
   here-string (`<<<`) misdetection, a delimiter containing anything outside the identifier
   charset, or reaching end-of-command while still inside an unterminated body. "Bail" here means
   falling back to testing the *unstripped* text — which can still legitimately BLOCK if the raw
   text happens to satisfy the conjunction — never a blanket allow. This is what the VERIFY
   fixture for malformed/truncated heredoc input is pinning.
5. **No shared library.** Implement the stripper as a single self-contained awk pass inside
   `validate-bounded-waiter.sh`, consistent with the hook's existing self-contained style (it
   sources nothing today) and with the dispatch's explicit "no shared library" constraint. The
   `record-version-patterns.sh` precedent is cited for implementation shape only.

## Recommendations

**Primary change** (`hooks/validate-bounded-waiter.sh`): insert a `strip_heredoc_body()` (or
similarly named) awk-based preprocessing step between the existing fail-open stdin/jq guards and
the three-leg conjunction. Feed `$COMMAND` through it once, and run all three existing
`grep -qE` tests against its output instead of against `$COMMAND` directly — the conjunction
regexes themselves (legs a/b/c) are untouched.

Algorithm shape (line-oriented, since `tool_input.command` preserves real newlines):
- Single pass over lines. State: `in_body`, `delim`, `dash` (whether `<<-` vs `<<`), and two
  global guards: `heredoc_seen` (count of openers found) and `ambiguous`.
- Not in body: scan the line for a heredoc opener — `<<` or `<<-`, NOT immediately followed by a
  third `<` (excludes here-strings `<<<`), followed by an optional quote/backslash and an
  identifier-charset delimiter. Zero or more than one opener found anywhere across the whole
  command -> set `ambiguous=1` and stop trying to strip (pass everything through unchanged, but
  continue scanning only to confirm the ambiguity, never silently drop lines once ambiguous).
  Exactly one valid opener -> record `delim`/`dash`, set `in_body=1`, emit the opener line itself
  unchanged (it is real command text, not body).
- In body: if `dash` and the line equals `delim` after stripping leading whitespace, OR if not
  `dash` and the line is exactly equal to `delim` (POSIX terminator rule — no leading or
  trailing characters), close the body (`in_body=0`) and drop/emit-blank the terminator line;
  otherwise drop/emit-blank the line (it is heredoc body data, excluded from the conjunction
  test).
- End of input while still `in_body=1` (unterminated heredoc) -> set `ambiguous=1`.
- Final output: if `ambiguous=1`, re-emit the ORIGINAL `$COMMAND` untouched (today's exact
  verdict applies); otherwise emit the line-filtered buffer (body lines blanked, everything else
  intact) for the conjunction test.
- Guard the awk invocation itself the same way the existing `jq` guard works: if `awk` is
  unavailable (defensive symmetry only — POSIX guarantees it), skip straight to testing the
  unstripped command, never exit non-zero from this step.

**Refusal-message refinement (secondary, compatible with Decision 3's "not primary")**: when the
conjunction still blocks AND the stripper's own `ambiguous` path was taken (i.e. a heredoc-like
construct was present but not confidently stripped), append one stderr line suggesting Write/Edit
as the immediate workaround for documentation content, so a future author is redirected in one
step instead of re-discovering the workaround from scratch — operationalizing Option 3 as a
fallback hint on the residual bail path only, never as the detection rule itself.

**Test additions to `tests/test-validate-bounded-waiter.sh`** (author with Write/Edit per the
file's own existing header note, not a Bash heredoc), mapped to the dispatch's VERIFY list:

- (a) `assert_allowed`: a heredoc writing prose that quotes all three legs, e.g.
  `"cat > /tmp/doc.md <<'EOF'\nNever do this:\nuntil ! pgrep -f 'x/check.sh'; do sleep 20; done\nEOF"`.
- (b) `assert_blocked`: the existing motivating-incident fixtures are unaffected (no heredoc
  present, stripper is a no-op passthrough) — re-run as a regression pin, no new fixture text
  needed beyond what already exists.
- (c) `assert_allowed`: existing one-shot-conditional-outside-a-loop fixture already pins this;
  optionally add a heredoc-wrapped variant for belt-and-suspenders coverage.
- (d) `assert_allowed`: existing bare-`pgrep` and bare-`ps|grep` fixtures already pin this.
- (e) `assert_blocked` (this is the subtle one — "fails open to today's verdict", not "fails
  open to allow"): an **unterminated** heredoc whose truncated body contains all three legs,
  e.g. `"cat > /tmp/doc.md <<'EOF'\nuntil ! pgrep -f 'x/check.sh'; do sleep 20; done\n"` with no
  closing `EOF` line at all. The stripper must set `ambiguous=1` and fall back to testing the
  raw, unstripped command — which still contains all three legs verbatim — so the correct
  assertion is `assert_blocked`, with a comment explaining that "fails open" here means "falls
  back to the pre-feature verdict," which for this specific fixture is still a block. A second
  fixture worth adding: two heredocs in one command (ambiguous by the "exactly one" scope rule)
  where the raw text does NOT otherwise satisfy the conjunction, asserted `assert_allowed`, to
  pin that ambiguity does not spuriously convert an otherwise-benign command into a block either.

**Documentation**: record the ruling (Option 1 adopted; Options 2 and 3 rejected, with Option 3
partially retained as a refusal-message hint) in the hook's own header comment, in the same
style as its existing "Deliberately NOT classified here" and "Shared-pattern-library question:
REJECTED" sections — this keeps the reasoning co-located with the code it governs rather than
only in this report.

## Risks & Mitigations

- **Risk**: an overly clever heredoc parser could itself become a second source of false
  negatives (silently allowing a live waiter disguised inside a heredoc-shaped wrapper) or false
  positives (misparsing a legitimate non-heredoc use of `<<` in arithmetic context, e.g. `(( x <<
  1 ))`, though that is `<<` as a bitwise-shift operator inside `(( ))`, a different token
  context entirely). **Mitigation**: the identifier-only delimiter charset and the "exactly one
  heredoc, bail on anything else" scope rule keep the parser's confident surface small and
  conservative; the arithmetic-shift case does not match the opener regex's delimiter
  requirement (a bitwise shift is followed by a space and a number/variable, not an
  identifier-charset heredoc delimiter token) and is additionally guarded by the "bail on
  ambiguity -> test unstripped text" fallback, which never produces a weaker verdict than today.
- **Risk**: this task's own implement/verify phase must author heredoc-documenting test fixtures
  and a hook-header rationale discussing the forbidden shape — exactly the content class that
  trips the CURRENT (pre-fix) hook. **Mitigation**: author with Write/Edit throughout this task's
  own implement phase (as the test file's header already mandates and as task 415's plan phase
  was warned to do), and treat the fix landing as the point after which heredoc-based
  documentation of this pattern becomes safe to author via Bash if ever needed.
- **Risk**: a future narrowing of the three-leg conjunction (e.g. "fix" the bare-word `pgrep`
  ruling to require `-f`) could silently interact with this change in ways not covered by
  today's fixtures. **Mitigation**: the flag-clustering regression fixtures already pinned in
  the test suite are unaffected by this change (no heredoc involved) and continue to guard that
  ruling independently; the new fixtures above guard only the heredoc-stripping behavior, kept
  as a clearly separate fixture block in the same file.

## Context Extension Recommendations

- **Topic**: heredoc-awareness as a general hazard class for `Bash`-matcher PreToolUse hooks.
- **Gap**: `context/patterns/bounded-build-waiter.md` and the hook-authoring precedents
  (`guard-destructive-git.sh`, `validate-no-task-references.sh`) do not currently name "a
  Bash-matcher hook's raw-command-text detector cannot distinguish a heredoc body from live
  shell code" as a general pattern — it is currently implicit, discovered only by hitting it.
  `validate-bounded-waiter.sh` is likely to be the first of more than one hook matching `Bash`
  with a textual-shape detector over time.
- **Recommendation**: once this task's fix lands, consider a short addition to
  `context/standards/shell-script-testing.md` or a new short pattern note naming this hazard
  class generally ("a `Bash`-matcher textual-shape hook must consider heredoc/quoted-literal
  bodies as data, not control flow") so a future hook author checks for it by design rather than
  by incident. Not filed as a task here — this is advisory only, per this agent's scope.

## Appendix

- Searches/reads performed: full read of `hooks/validate-bounded-waiter.sh`,
  `scripts/tests/test-validate-bounded-waiter.sh`,
  `context/patterns/bounded-build-waiter.md` (Rules 1-5 and incident narrative),
  `merge-sources/settings-hooks.json` (hook registration, matcher confirmation),
  `hooks/validate-no-task-references.sh` (matcher contrast), and
  `scripts/lib/record-version-patterns.sh` (`strip_exempt_regions` precedent).
- Grep queries: `heredoc|here-doc|<<-?["']?EOF|<<~` across `hooks/` and `scripts/lib/` (no
  existing heredoc handling found for this hook); `awk` usage across `hooks/*.sh` and
  `scripts/lib/*.sh` (established idiom for textual-shape transforms in this codebase).
- No web research was needed; POSIX heredoc/here-string grammar is well-established and was
  applied directly.
