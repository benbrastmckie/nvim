# Implementation Plan: Task #506

- **Task**: 506 - Stop the bounded-waiter hook refusing a write whose prose documents the anti-pattern the hook enforces
- **Status**: [NOT STARTED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/506_bounded_waiter_hook_fires_on_documenting_prose/reports/01_heredoc-aware-hook-detector.md
- **Artifacts**: plans/01_heredoc-aware-waiter-detector.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md, no-record-versioning-in-deliverables.md, shell-script-testing.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`hooks/validate-bounded-waiter.sh` tests a three-leg conjunction (loop keyword + `sleep` +
process-name-match) against the raw `tool_input.command` string, with no awareness of shell
heredoc syntax. A heredoc that writes documentation *about* the forbidden waiter shape puts all
three legs into that string as inert data and is refused exactly like a live waiter. This plan
adopts the research report's Option 1: a self-contained, conservative awk pass inside the hook
that blanks heredoc *body* lines before the three-leg conjunction is applied, leaving the
conjunction's own regexes untouched, and bailing to today's exact verdict on anything it cannot
parse confidently. Option 3 is retained only as an extra stderr hint on that bail path. The work
lands in two source-store files plus a redeploy; no shared library is introduced.

### Research Integration

Findings carried directly into the phases below:

- **The false positive is exactly reproducible, not a formatting accident.** A Bash tool call's
  `tool_input.command` preserves literal newlines, so a heredoc body's `until` / `sleep` /
  `pgrep` tokens sit in the same string the hook greps. Phase 1's fixture (a) pins this.
- **Option 2 (command-position narrowing) is rejected** because a quoted shell example genuinely
  sits in command position inside the heredoc body — the question is data-vs-control-flow, not
  keyword placement. Option 2 would also have to relax the deliberate bare-word `pgrep` ruling,
  which the dispatch forbids silently relaxing.
- **Option 3 (Write/Edit-only authorship, sited pre-emptively) is rejected as the primary fix**:
  it is the documentation-as-prohibition strategy the hook's own header records as already
  failed for the rule the hook enforces. Retained as a refusal-message hint only (Phase 2).
- **Implementation idiom precedent**: `scripts/lib/record-version-patterns.sh`'s
  `strip_exempt_regions()` is a one-pass awk filter that blanks lines between an open and a close
  marker so the caller's pattern tests see only non-exempt text. Cited for *shape only* — not
  sourced, not shared (dispatch hard constraint, and that library serves a `Write|Edit`-matcher
  hook whose input is file content, not a shell command string).
- **This hook is the only one in its family with a `Bash` matcher**, which is why no heredoc
  handling exists anywhere in the family today: heredoc bodies are a `Bash`-only hazard for a
  raw-command-text detector.
- **"Fails open" on malformed heredoc input means "falls back to the pre-feature verdict", not
  "allows".** For an unterminated heredoc whose truncated body carries all three legs, the
  correct assertion is therefore `assert_blocked`. Phase 1 fixture (e1) pins this, with the
  reasoning stated in a fixture comment.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and `roadmap_flag` is not set, so no roadmap
phases are added and no roadmap consultation was performed.

## Goals & Non-Goals

**Goals**:

- A Bash command whose heredoc body documents the forbidden waiter shape is ALLOWED.
- A genuine live self-match waiter stays BLOCKED, including when it appears in the same command
  as an unrelated heredoc (stripping must not create a false negative).
- Anything the stripper cannot parse confidently falls back to testing the unstripped command —
  today's exact verdict, never a blanket allow.
- The adopted ruling and the two rejected options are recorded in the hook's own header, in the
  style of its existing decision-record sections.
- The refusal message redirects a documentation author to Write/Edit in one step when a
  heredoc-like construct was present but not confidently stripped.

**Non-Goals**:

- Changing the three-leg conjunction's own matching logic. The bare-word `pgrep` ruling, the
  `ps`-piped-into-`grep` branch, and the `[b]racket`-variant-by-construction behavior are all
  untouched. This task changes only *what text* the conjunction is tested against.
- Introducing a shared pattern library between this hook and its pattern document, or between
  this hook and `scripts/claude-refresh.sh`'s reaper classifier.
- Modifying the reaper classifier, the hook's registration in
  `merge-sources/settings-hooks.json`, or anything in `context/patterns/bounded-build-waiter.md`.
- Implementing a general shell parser. The stripper handles exactly one heredoc per command with
  an identifier-charset delimiter and bails otherwise.
- The advisory "name this hazard class generally in a pattern note" recommendation from the
  research report's Context Extension section. Explicitly out of scope here.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The stripper creates a FALSE NEGATIVE: a live waiter survives by hiding behind heredoc-shaped text | H | M | Phase 1 fixture (e4) pins a command carrying BOTH a benign heredoc and a live waiter outside its body as still BLOCKED; fixture (e3) pins that a here-string (`<<<`) is never mistaken for a heredoc opener; the "exactly one heredoc, identifier-charset delimiter, bail otherwise" scope rule keeps the confident surface small |
| An awk bug makes the hook exit nonzero, which PreToolUse reads as BLOCK, fail-CLOSED on every Bash call in the repo | H | L | Keep the existing `set -euo pipefail` fail-open idiom: guard the awk invocation so any failure falls through to testing the unstripped command, never propagates a nonzero exit; Phase 1 verification runs the suite's four existing fail-open fixtures unchanged; the source-store edit is not live until Phase 3 deploys it |
| After Phase 3's deploy, a fail-closed hook would block the very Bash calls needed to recover (including `git`) | H | L | Phase 3 deploys only after Phase 1-2 close green against the source-store hook; immediately post-deploy, run the suite in deployed mode (it resolves to `.claude/hooks/`) plus a trivial Bash smoke call, before any other work; see Rollback/Contingency for the recovery path |
| Authoring this task's own content trips the CURRENT hook: both the new fixtures and the header rationale quote the forbidden shape | M | H | Author every edit in Phases 1-2 with Write/Edit, never a Bash heredoc. The test file's own header already mandates this. The hazard ends once Phase 3 lands |
| Record-versioning language leaks into the hook header while explaining the stripper ("the hook used to test raw text", "previously", "this replaces") — forbidden under `agent-system/**` | M | M | State the design in present tense on its own merits only, following the existing header's "Deliberately NOT classified here" and "Shared-pattern-library question: REJECTED" sections as the model; no sentence may be phrased relative to an unstated earlier behavior |
| Phase 3's whole-tree redeploy regenerates from a source store carrying four concurrent siblings' in-flight edits; `verify-deploy.sh` could go red through no fault of this task | M | M | The deployed tree is gitignored, so the deploy contributes nothing to this task's commit; per the dispatch territory note item (4), treat a failure in a file outside this task's `file_scope` as possibly a sibling's in-flight edit, check `git log`, and report rather than "fix" it |
| An overly permissive delimiter charset misparses `<<` as a bitwise shift inside `(( ))` | L | L | The opener regex requires an identifier-charset delimiter token; an arithmetic shift is followed by whitespace and a number or variable. Phase 1 fixture (e5) pins an arithmetic-shift command alongside a live waiter as still BLOCKED |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel. This plan is a strict chain: Phase 2 needs
the stripper's `ambiguous` signal that Phase 1 introduces, and Phase 3 deploys both.

---

### Phase 1: Heredoc-aware stripper, header ruling, and fixture block [NOT STARTED]

**Goal**: The three-leg conjunction is applied to text with heredoc body lines blanked, so a
command whose heredoc documents the forbidden shape is allowed while a live waiter — including
one sharing a command with a benign heredoc — still blocks. The adopted ruling is recorded in the
hook's header, and the new behavior is pinned by fixtures.

**Tasks**:

- [ ] Re-read both target files immediately before editing (concurrent siblings are live on this
      tree; line numbers in the research report and this plan are indicative only).
- [ ] In `hooks/validate-bounded-waiter.sh`, add a self-contained `strip_heredoc_body()` function
      between the existing fail-open guards and the three-leg conjunction. Single awk pass over
      lines, with state `in_body`, `delim`, `dash` (`<<-` vs `<<`), and globals `heredoc_seen`
      and `ambiguous`:
  - Not in body: detect an opener as `<<` or `<<-` NOT followed by a third `<` (excludes the
    here-string `<<<`), then an optional single quote, double quote, or backslash, then a
    delimiter matching `[A-Za-z_][A-Za-z0-9_]*`. Emit the opener line unchanged (it is real
    command text, not body).
  - A second opener anywhere in the command, or a delimiter outside the identifier charset, sets
    `ambiguous=1`.
  - In body: close on a terminator line equal to `delim` exactly (plain `<<`) or equal after
    stripping leading whitespace (`<<-`); blank the terminator line and every body line.
  - End of input while still `in_body` (unterminated heredoc) sets `ambiguous=1`.
  - Final output: if `ambiguous=1`, emit the ORIGINAL command untouched; otherwise emit the
    line-filtered buffer.
- [ ] Guard the awk invocation so any failure or an absent `awk` falls through to the unstripped
      command. It must never propagate a nonzero exit under `set -euo pipefail` (same defensive
      posture as the existing `jq` guards, which use `|| true`).
- [ ] Capture the stripper's output once into a variable and run all three existing `grep -qE`
      leg tests against THAT variable instead of `$COMMAND`. Do not alter any of the three
      regexes.
- [ ] Record the ruling in the hook's header comment, as a new decision-record section in the
      style of the existing `Shared-pattern-library question: REJECTED` and
      `Deliberately NOT classified here` sections: Option 1 adopted; Option 2 rejected (a quoted
      example's keywords genuinely sit in command position, so command-position narrowing answers
      a different question, and it would require relaxing the deliberate bare-word ruling); Option
      3 rejected as the primary rule but retained as a refusal-message hint; the conservative
      scope rule and its bail-to-unstripped-text fallback; and the explicit statement that no
      shared library is introduced. State all of it in present tense, on its own merits — no
      phrasing relative to an earlier behavior, and no task-number references.
- [ ] In `scripts/tests/test-validate-bounded-waiter.sh`, add a clearly separated fixture block
      after the existing must-allow section, titled for heredoc awareness, containing:
  - (a) `assert_allowed`: a heredoc writing prose that quotes all three legs, e.g. a
        `cat > /tmp/doc.md` heredoc with a quoted `EOF` delimiter whose body carries an
        `until ! pgrep -f ...; do sleep 20; done` example line.
  - (a2) `assert_allowed`: the same content via the `<<-` form with a whitespace-indented
        terminator, pinning the dash variant.
  - (c) `assert_allowed`: a heredoc-wrapped one-shot name-match conditional (belt-and-suspenders
        over the existing non-heredoc fixture).
  - (e1) `assert_blocked`: an UNTERMINATED heredoc whose truncated body carries all three legs,
        with a fixture comment stating that "fails open" here means "falls back to the
        pre-feature verdict", which for this input is still a block.
  - (e2) `assert_allowed`: two heredocs in one command (ambiguous by the exactly-one scope rule)
        whose raw text does NOT otherwise satisfy the conjunction — pinning that ambiguity does
        not convert a benign command into a block.
  - (e3) `assert_blocked`: a here-string (`<<<`) carrying the three legs, pinning that `<<<` is
        never treated as a heredoc opener and its text never stripped.
  - (e4) `assert_blocked`: a command carrying BOTH a benign heredoc (body closed) AND a live
        self-match waiter outside that body — the false-negative guard.
  - (e5) `assert_blocked`: an arithmetic bitwise shift inside `(( ))` alongside a live waiter,
        pinning no misparse of `<<` as a heredoc opener.
- [ ] Author BOTH file edits with the Write/Edit tools. A Bash heredoc carrying this content is
      itself blocked by the currently deployed hook.
- [ ] Run the suite against the source store and confirm every assertion passes, pre-existing
      ones included.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: atomic-batch

**Scope Hypothesis**: the suite currently carries 23 assertions (5 must-block, 5 flag-clustering,
1 no-exemption, 8 must-allow, 4 fail-open) and this phase adds 8, for 31. Confirm by counting the
`assert_blocked` / `assert_allowed` / `common_test_pass` call sites in the file before editing and
by reading the runner's `Results: N passed` line after, rather than trusting these numbers.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-bounded-waiter.sh`
is the suite `suite_selection_select` resolves for both touched paths, and the edited hook is a
source-store file that is not live until Phase 3 deploys it, so this phase's blast radius is
exactly that one suite.

**Files to modify**:

- `agent-system/extensions/core/hooks/validate-bounded-waiter.sh` - add `strip_heredoc_body()`,
  feed the three leg tests from its output, record the ruling in the header
- `agent-system/extensions/core/scripts/tests/test-validate-bounded-waiter.sh` - add the
  heredoc-awareness fixture block

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-bounded-waiter.sh`
  exits 0 with no FAILED assertions.
- The three `grep -qE` leg regexes are textually unchanged from their current form (diff
  read-through).
- The hook still blocks via `exit 2` plus stderr and contains no `permissionDecision` key.
- Diff read-through of the new header text confirms every sentence states the design in present
  tense, carries no task-number reference, and is not phrased relative to an earlier behavior.

---

### Phase 2: Refusal-message hint on the conservative bail path [NOT STARTED]

**Goal**: When the conjunction still blocks AND the stripper took its `ambiguous` bail path (a
heredoc-like construct was present but not confidently stripped), the stderr message adds one
line pointing the author at Write/Edit for documentation content, so the next author is
redirected in one step instead of debugging the refusal.

**Tasks**:

- [ ] Re-read `hooks/validate-bounded-waiter.sh` immediately before editing.
- [ ] Surface the stripper's `ambiguous` state to the caller (e.g. a sentinel first line on the
      stripper's stdout that the caller splits off, or a separate variable set by a second
      guarded awk pass). Whichever mechanism is chosen, it must preserve the fail-open posture:
      an unreadable or missing signal defaults to "not ambiguous" and simply omits the hint.
- [ ] In the blocking branch, when `ambiguous` is set, append exactly one stderr line stating
      that a heredoc-like construct was detected but not confidently parsed, and that
      documentation content describing this shape should be authored with the Write or Edit tool
      rather than a shell heredoc.
- [ ] Note the hint's existence in the hook header's decision-record section added in Phase 1, as
      the one retained part of the otherwise-rejected documentation-only option.
- [ ] Extend fixture (e1) in `scripts/tests/test-validate-bounded-waiter.sh` to also assert the
      hint text is present in stderr, and confirm that a blocked command with NO heredoc-like
      construct (e.g. the first must-block fixture) does NOT carry the hint — pinning that the
      hint is scoped to the bail path, not emitted on every refusal.
- [ ] Author both edits with Write/Edit, not a Bash heredoc.

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-bounded-waiter.sh`
covers both touched files, and the change adds one conditional stderr line to a source-store hook
that is not live until Phase 3.

**Files to modify**:

- `agent-system/extensions/core/hooks/validate-bounded-waiter.sh` - surface `ambiguous`, add the
  conditional stderr hint, extend the header decision record
- `agent-system/extensions/core/scripts/tests/test-validate-bounded-waiter.sh` - assert the hint
  on the bail-path fixture and its absence on a plain refusal

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-bounded-waiter.sh`
  exits 0.
- Every blocked fixture still carries the canonical `kill -0` idiom in stderr (the existing
  `assert_blocked` contract is unchanged).
- A plain live-waiter refusal carries no Write/Edit hint line.

---

### Phase 3: Redeploy and full gate [NOT STARTED]

**Goal**: The fix is live in the deployed `.claude/` tree, the deployed hook is confirmed to
behave as the source-store hook does, and the repository's complete gate set is green.

**Tasks**:

- [ ] Confirm Phases 1-2 are closed green and committed before deploying.
- [ ] Redeploy: `timeout 540 bash .claude/scripts/deploy-headless.sh`, invoked with the Bash tool
      `timeout` parameter raised to 600000 (not its 120000 ms default), per the bounded-wait idiom
      in `context/patterns/external-process-wait.md` Rule 1. The deployed tree is reported stale
      for the `core` and `lean` extensions, so this deploy also carries unrelated pending source
      changes; that is expected.
- [ ] Immediately after the deploy, run one trivial Bash call (e.g. `true`) to confirm the newly
      deployed hook has not gone fail-closed on ordinary commands.
- [ ] Run the suite in deployed mode — `bash .claude/scripts/tests/run-all.sh --only test-validate-bounded-waiter.sh`,
      whose relative `HOOK` path resolves to `.claude/hooks/` there — and confirm it is green
      against the deployed copy, not only the source-store one.
- [ ] Confirm the hook's registration in the deployed `settings.json` is still BARE, with no
      `2>/dev/null || echo '{}'` wrapper, by reading the `Bash` matcher block. Read-only check;
      `merge-sources/settings-hooks.json` is not edited by this task.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh`.
- [ ] If a gate fails in a file outside this task's `file_scope`, check `git log` and the working
      tree before treating it as a regression of this task — four sibling tasks are live on this
      same tree this cycle. Report rather than silently repair a sibling's file.
- [ ] Stage only this task's own two source-store files (explicit file list, never a directory or
      glob pathspec) and commit.

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: full

**Files to modify**:

- `__WHOLE_TREE__` - this phase invokes `deploy-headless.sh`, regenerating the entire deployed
  tree
- `agent-system/extensions/core/hooks/validate-bounded-waiter.sh` - no further content change;
  staged and committed here
- `agent-system/extensions/core/scripts/tests/test-validate-bounded-waiter.sh` - no further
  content change; staged and committed here

**Verification**:

- `bash .claude/scripts/deploy-headless.sh` completes within its bound and reports success.
- A trivial Bash call succeeds post-deploy (the hook is not fail-closed).
- `bash .claude/scripts/tests/run-all.sh --only test-validate-bounded-waiter.sh` exits 0 against
  the deployed hook.
- `bash .claude/scripts/verify-deploy.sh` exits 0 — the complete gate set, including Gate 8's
  full shell-suite battery. No `--skip-slow` and no `--only-gate` narrowing for this final phase.
- The deployed `settings.json` registers the hook bare.
- `git diff --staged` shows exactly the two source-store files and nothing else.

---

## Testing & Validation

- [ ] A heredoc writing prose that quotes all three legs is ALLOWED (dispatch VERIFY (a)), in
      both the plain `<<` and the `<<-` indented-terminator forms.
- [ ] The motivating live self-match waiter is still BLOCKED (dispatch VERIFY (b)) — the five
      existing must-block fixtures pass unchanged.
- [ ] A one-shot name-match conditional outside a loop is still allowed (dispatch VERIFY (c)),
      bare and heredoc-wrapped.
- [ ] A bare name-match and a bare process-list-piped-into-grep are still allowed (dispatch
      VERIFY (d)) — the existing must-allow fixtures pass unchanged.
- [ ] Malformed or truncated heredoc input falls back to today's verdict rather than erroring
      (dispatch VERIFY (e)): the unterminated-heredoc fixture BLOCKS, and the two-heredoc
      otherwise-benign fixture is ALLOWED.
- [ ] A live waiter sharing a command with a benign closed heredoc is still BLOCKED (the
      false-negative guard).
- [ ] A here-string and an arithmetic bitwise shift are never treated as heredoc openers.
- [ ] All five existing flag-clustering fixtures still block — the bare-word `pgrep` ruling is
      not silently relaxed.
- [ ] All four existing fail-open fixtures still exit 0 — `jq` absent, empty stdin, non-JSON
      stdin, and a payload with no `tool_input.command`.
- [ ] The hook blocks via exit code 2 plus stderr; no `permissionDecision` key anywhere in it.
- [ ] No file landing under `agent-system/**` carries a task-number reference or
      record-versioning language.
- [ ] `bash .claude/scripts/verify-deploy.sh` exits 0 after the redeploy.

## Artifacts & Outputs

- Modified: `agent-system/extensions/core/hooks/validate-bounded-waiter.sh` — heredoc-aware
  stripper, conditional Write/Edit hint on the bail path, header decision record.
- Modified: `agent-system/extensions/core/scripts/tests/test-validate-bounded-waiter.sh` —
  heredoc-awareness fixture block (8 new assertions).
- Regenerated (gitignored, not committed): the deployed `.claude/` tree.
- Summary artifact at implementation completion:
  `specs/506_bounded_waiter_hook_fires_on_documenting_prose/summaries/01_heredoc-aware-waiter-detector-summary.md`.

## Rollback/Contingency

- **Phases 1-2 (source store only, nothing live)**: revert the two files with
  `git checkout HEAD -- <the two explicit paths>` if the tree is clean of other work for them, or
  take a defensive checkpoint first with
  `bash .claude/scripts/git-snapshot.sh 506 --no-revert`. Four siblings are live on this tree, so
  never use `git-snapshot.sh` in its default reverting mode here.
- **Phase 3, deployed hook misbehaving**: the hazard is a fail-closed hook blocking the Bash
  calls needed to recover. The pre-deploy green suite plus the guarded awk fallback make this
  unlikely, but if ordinary Bash calls start refusing after the deploy, do not attempt further
  Bash work: the recovery is to restore the prior hook content in the source store with the
  Write/Edit tools (which no `Bash` matcher can block) and redeploy, or, if the deploy itself
  cannot run, report the condition to the user rather than continuing.
- **Phase 3, `verify-deploy.sh` red in a file outside this task's `file_scope`**: this is more
  likely a sibling's in-flight edit than a regression here. Check `git log` and the working tree,
  report, and do not repair another task's territory.
