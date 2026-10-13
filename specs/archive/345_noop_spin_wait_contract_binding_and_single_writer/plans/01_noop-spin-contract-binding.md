# Implementation Plan: Task #345

- **Task**: 345 - No-op spin wait-contract binding and single-writer discipline
- **Status**: [COMPLETED]
- **Effort**: 6 hours
- **Dependencies**: None live. The upstream background-versus-foreground ruling this plan's
  item-4 answer builds on is settled and archived
  (`specs/archive/343_bound_agent_background_wait_stranded_dispatch/`); it is taken as given and
  not re-litigated.
- **Research Inputs**: `specs/345_noop_spin_wait_contract_binding_and_single_writer/reports/01_noop-spin-contract-binding.md`
- **Artifacts**: plans/01_noop-spin-contract-binding.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  shell-strict-mode.md, shell-script-testing.md, source-store-deploy-boundary.md,
  no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The measured incident is **Branch B, not Branch A**: `detect-noop-bash.sh` fired **zero** times
across the 693-call, ~62-minute spin, because the agent alternated one trivial `echo idle` with
one non-trivial log-read and the hook *deletes* its consecutive-trivial counter on every
non-trivial call — maximum streak observed under mechanical replay through the unmodified
production script: **1**, against a threshold of 3. The advisory layer is therefore not unbound
(two independently located historical firings land `additionalContext` inside a dispatched
subagent's own sidechain transcript); it is **unreachable** under the one usage pattern that
matters. So this task's deliverable is a streak-accounting repair in one hook plus two narrow
amendments to the two pattern documents that already own this defect class — and explicitly
**not** a fourth document, not a new detector, and not an agent-prompt edit.

Definition of done: the alternating-call pattern that produced zero firings now produces an
advisory within the first handful of spin calls, proven by a committed fixture built from the
measured command sequence; a productive-work control sequence still produces none; repeated
log-reading-to-poll is named inside the existing "No no-op filler" rule with a stated
alternative; single-writer discipline on a shared fixture tree is stated with a `flock`-based
mechanism modeled on existing prior art; the near-ceiling ruling is recorded; net document count
is unchanged at zero new files.

### Research Integration

`reports/01_noop-spin-contract-binding.md` settles five things this plan implements rather than
re-derives:

- **Branch B confirmed mechanically** (Finding 1): the real 689-command sequence, extracted from
  the subagent's own sidechain transcript and piped through the unmodified
  `hooks/detect-noop-bash.sh`, yields `0` firings and `max streak 1`. The defect is streak
  accounting, located in the hook, not in any document.
- **Binding is not the defect** (Finding 2): two historical firings elsewhere on the machine are
  `isSidechain: true` records carrying the full `additionalContext` attachment keyed to the
  triggering `toolUseID` — the mechanism reaches a dispatched subagent when it fires. Finding 2
  also records a real content gap: the advisory's hard-coded pointer names
  `external-process-wait.md` only, never `bounded-build-waiter.md`, so an agent spinning on a
  *local* build is handed no applicable idiom even when the advisory does arrive.
- **Item 2 is confirmed, not hypothetical** (Finding 3): in the measured sequence the
  `grep`/`tail`/`wc -l` probe of the suite log is literally one-for-one camouflage for
  `echo idle`, and is simultaneously the thing that defeats the counter.
- **Item 3 is confirmed with the exact failure shape** (Finding 4): three overlapping invocations
  of one suite against one shared fixture tree, collision discovered only by hand `/proc`
  scanning, 8-11 stray PIDs killed manually. `lake-build-guard.sh`'s `flock()`-based,
  tree-root-scoped lock is named prior art, including its own "FAMILY CONVENTION" header language.
- **`orchestrator-discipline.md` is rejected as a home** (Finding 5), on its own stated
  orchestrator-role-only audience.

Re-confirmed at plan-authoring time rather than carried: `external-process-wait.md` is 129 lines
with its "No no-op filler" rule at `### 2.` naming only `:`/`true`/`date`/`echo waiting`;
`bounded-build-waiter.md` is 238 lines with four numbered Required Rules, Rule 4 being "One waiter
per log"; `detect-noop-bash.sh` is 192 lines and deletes `$STATE_FILE` at line 156 on any
non-trivial command; `test-detect-noop-bash.sh` is 338 lines and is already registered in
`manifest.json` (line 220), so no registration step is owed. `lint-agent-contracts.sh` Check H
extracts its two expected bullet strings from `bounded-build-waiter.md` by
`grep -F 'canonical idiom VERBATIM' | head -n1` and
`grep -F 'arm a \`Monitor\` to watch a local verification' | head -n1` — a first-match extraction
that an edit *above* the fenced block can silently capture. That constraint drives Phase 2's
verification.

### Prior Plan Reference

No prior plan for this task.

### Roadmap Alignment

No `roadmap_path` was supplied in this dispatch, so `specs/ROADMAP.md` was not loaded. The
dispatch's own non-negotiable boundaries are treated as hard constraints in Goals/Non-Goals
below.

## The Four Rulings This Plan Implements

Recorded here, in one place, because the acceptance criteria are rulings rather than only edits.

**Ruling 1 — one home for the no-op-filler contract: `external-process-wait.md`, amending its
existing Rule 2.** It already owns this defect class, already forbids the filler by name, and
already carries both the bounded-wait idiom and the 540-versus-600 margin reasoning; extending
one existing rule adds the least new surface of any candidate. Rejected candidates, each with its
reason recorded in the file itself (Phase 1):

- **`bounded-build-waiter.md` as the home for the filler prohibition** — rejected. It already
  cross-references `external-process-wait.md` for the filler rule instead of duplicating it, and
  that one-way reference is the property worth preserving; moving the prohibition there would
  invert the existing dependency and leave the remote-wait case pointing at a local-wait document.
- **`context/contracts/orchestrator-discipline.md`** — rejected on audience. Its own opening
  sentence states it "binds the ORCHESTRATOR ROLE itself -- not the agents it dispatches," and its
  entire content concerns the orchestrator's inline reasoning during the state-machine loop, a
  different defect class from a dispatched subagent's own tool-call behavior. Placing an
  agent-facing contract there would require widening that stated audience, which this task has no
  mandate to do, or silently ignoring it. Both are refused; the ruling is written down so a future
  reader does not re-propose the move without re-deriving the finding.
- **A new pattern document** — rejected outright by the task's own anti-proliferation clause.
  Net document count stays at zero new files.

**Ruling 2 — repeated log-reading is inside the prohibition, stated narrowly.** Rule 2 gains
language naming a `cat`/`grep`/`tail`/`head`/`wc` read of a wait target's log or status file
issued *solely and repeatedly* to test whether the job has finished. The narrowness is
load-bearing: reading the log **once**, at the moment writer liveness ends, is correct and is
exactly what the bounded-wait idiom already does. The stated alternative is therefore not "do not
read the log" but "let the wait resolve, then read it once" — `bounded-build-waiter.md` Rule 3
("a dead writer ends the wait immediately") is the mechanism, cross-referenced rather than
restated.

**Ruling 3 — single-writer discipline lands in `bounded-build-waiter.md`, as a new Rule 5,
not merged into Ruling 1's home.** Writer concurrency against a shared local tree is a local-build
concern that belongs beside "one waiter per log," not inside a remote-wait document's filler rule.
Mechanism, not exhortation: at most one writer per shared fixture/build tree per dispatch,
enforced by a `flock()`-held lock file scoped to the tree root, modeled explicitly on
`lake-build-guard.sh` (cited by name as prior art, not reinvented). A second would-be writer must
detect the live lock and either wait on the existing writer or fail loudly naming the holder —
never launch a second overlapping invocation. A kernel-held `flock` rather than a sentinel file is
required precisely because a dead holder's lock is released automatically, avoiding the
stale-sentinel defect this same document's "The Defect" section already records as symptom 1.

**Ruling 4 — the near-ceiling answer, and where it goes.** Consistent with (not conditional on,
and not re-litigating) the settled background-versus-foreground ruling: a job whose expected
duration approaches the Bash tool's 600000ms per-call ceiling must **not** be awaited in a single
bounded-waiter call sized to its full expected runtime — 570s inside a 600s ceiling reproduces the
exact margin problem the 540-versus-600 reasoning already rejects, because the whole call,
inner wait loop included, must return control before the harness auto-backgrounds it. Instead:
launch once, capturing `pid`, then issue a *sequence* of separate Bash calls, each a
`kill -0 "$pid"`-gated wait bounded safely under the ceiling, re-checking liveness between calls
and reading the log or exit status once liveness ends. This is the repeated-bounded-iteration
shape `external-process-wait.md` already prescribes for the remote case, generalized to the local
liveness check. It is recorded in `bounded-build-waiter.md` (beside Rule 1 and the canonical
idiom, which is what the sizing rule is about), cross-referencing the margin reasoning rather
than duplicating it. Sharding or shortening the suite is a **consumer-repo recommendation** and is
recorded as such in the summary only.

**No agent-prompt edit, and therefore no `--file-scope-add`.** The dispatch sanctions a mid-run
re-scope if the item-1 ruling turns out to require an agent-prompt edit — the likely shape of a
*Branch A* fix. Branch B rules that out: the contract text already exists, already sits in the
spinning agent's reference chain, and is additionally injected into every dispatch file by
`orchestrate-build-dispatch.sh`'s unconditional "## Wait Discipline" pointer (verified live at
`scripts/orchestrate-build-dispatch.sh:613`, which names both pattern files by path). Amending
those two files therefore reaches every dispatched agent by the directive route already in place.
The four declared `file_scope` entries are exactly the four files this plan touches.

## Goals & Non-Goals

**Goals**:

- Close the measured streak-accounting gap in `detect-noop-bash.sh` so an alternating
  trivial/log-probe spin reaches the advisory threshold instead of being structurally incapable of
  it.
- Prove the closure with a committed regression fixture built from the **measured** alternating
  sequence, plus a productive-work control fixture that must not fire.
- Fix the advisory message's content gap: name `bounded-build-waiter.md` and its idiom alongside
  `external-process-wait.md`, and name the newly counted call class, so the nudge is actionable
  for a local build/test spin.
- Extend `external-process-wait.md` Rule 2 to cover repeated completion-polling reads, narrowly,
  with the read-once alternative stated.
- Record Ruling 1's rejected candidates — including the explicit `orchestrator-discipline.md`
  audience ruling — in the file itself.
- State single-writer discipline for a shared fixture/build tree in `bounded-build-waiter.md` with
  a `flock`-based mechanism and the named prior art.
- Record the near-ceiling ruling where the local idiom's sizing lives.
- Keep net document count at zero new files; keep every pre-existing rule intact and every
  pre-existing test case passing unmodified.

**Non-Goals**:

- **No third or fourth pattern document.** The task fails if its deliverable is new prose
  restating what Rule 2 already says.
- **No harness proposals.** The blocked foreground `sleep` and `Monitor`'s absence from the
  dispatched-agent toolset are out of our control and are not addressed.
- **No re-litigation of background-versus-foreground.** That ruling is settled upstream and
  archived; item 4 answers only the narrower near-the-ceiling question.
- **No agent definition file edits, and no addition to `bounded-build-waiter.md`'s generated-copy
  agent-contract bullet pair.** Adding a third bullet would require editing fourteen agent files
  plus `lint-agent-contracts.sh`'s curated in-scope array — that is the standing ground of
  `propagate_bounded_wait_contract_and_lint_coverage`, cited by project name, and absorbing it
  here is explicitly forbidden. Phase 2 records this non-propagation as a stated ruling so a
  reader does not mistake the omission for an oversight.
- **No consumer-repo changes.** The certify suite's runtime, sharding, and the deployed
  `.claude/hooks/` copy in the consumer repo are untouched; consequences are recorded as
  recommendations.
- **No blocking gate.** The hook stays advisory-only, always exit 0, always fail-open. Branch B
  removes the motivation for teeth: the advisory was never reached, not ignored.
- **No weakening, reordering, or renumbering** of any existing rule in either pattern document.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A Phase 2 edit above the fenced "Copy this exact text" block introduces a line matching `canonical idiom VERBATIM` or ``arm a `Monitor` to watch a local verification``, silently capturing Check H's `head -n1` extraction and breaking the fourteen-agent bullet check | H | M | New Rule 5 and the near-ceiling note must not contain either literal string; Phase 2 verification runs `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose` and confirms Check H still reports fourteen passes |
| The accounting change produces false advisories during ordinary productive work (literal `echo` separators interleaved with real commands) | M | M | The productive-work control fixture in Phase 4 is a required, committed acceptance case, not a spot check; the classifier's new class is read-only-inspection-only and repeat-gated, and the reset-on-genuine-progress path is unchanged |
| Changing the state-file format breaks pre-existing test cases that assert a bare integer counter and deletion-on-reset | M | H | The design keeps `noop-bash-count-<session>` a bare integer at the same path and keeps deletion-on-genuine-progress; the new memory lives in a separate sidecar file. Phase 4's first verification item is that every pre-existing case passes **unmodified** |
| The measured log-probe commands defeat the classifier's non-quote-aware segment split (a quoted `\|` or `[` inside a `grep` pattern fragments the segment), so the real sequence still never reaches the threshold | H | M | The fix is repeat-gated on a **command-shape** fingerprint (leading words per segment), not on exact text, and Phase 3's verification is a replay of the real extracted sequence, not a synthetic one — if the replay does not fire, the phase is not done |
| The hook's fail-open / never-block contract regresses while adding state | H | L | The existing fail-open cases (empty stdin, non-JSON, non-Bash tool, missing session id, unwritable state dir) stay in the suite unmodified and are the gate; every new state write follows the existing `mkdir -p … \|\| true` / `rm -f … \|\| true` tolerance pattern |
| A fixture built from a real consumer-repo transcript leaks task-number references or absolute private paths into `agent-system/**` | M | M | The fixture carries command *shapes* with paths normalized to the generic log names already used in the suite; `no-task-references-in-deliverables.md` applies, and Phase 5 greps the diff for task-number patterns |
| A sibling task edits a shared path mid-phase | L | L | Siblings in this cycle own `orchestrate-cycle-postflight.sh` and `post-destructive-git-checklist.md`/`guard-destructive-git.sh` — no overlap with these four files. Still: re-read each file immediately before editing, stage only this task's own hunks (never a directory or glob `git add`), never `git-snapshot.sh` in reverting mode |
| The advisory message's wording change breaks a test asserting on `external-process-wait.md` appearing in the message | L | H | Existing cases assert `grep -q "external-process-wait.md"`; the amended message must keep that substring and add the second pointer, so no pre-existing assertion needs editing |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 3 |
| 3 | 5 | 1, 2, 4 |

Phases within the same wave can execute in parallel. Phases 1, 2 and 3 touch three disjoint files
and share no state.

### Phase 1: `external-process-wait.md` — Rule 2 extension and the home ruling [COMPLETED]

**Goal**: Make Rule 2 cover repeated completion-polling reads with a stated read-once
alternative, state that the rule applies identically to a local-build wait, and record the home
ruling with its rejected candidates — all inside the existing document, with no rule renumbered
and nothing relaxed.

**Tasks**:
- [x] Re-read `context/patterns/external-process-wait.md` immediately before editing (concurrent
      cycle). *(completed)*
- [x] Extend `### 2. No no-op filler` with the repeated-read prohibition: a `cat`/`grep`/`tail`/
      `head`/`wc` read of the wait target's log or status file issued solely and repeatedly to
      test whether the job has finished is the same defect as `:`/`true`/`date`/`echo waiting`,
      not a lesser one. Keep the existing sentence and examples intact and additive. *(completed)*
- [x] State the alternative in the same rule: let the wait resolve and read the log or exit status
      **once**, at the point liveness ends — cross-reference `bounded-build-waiter.md` Rule 3 as
      the mechanism rather than restating it. State the narrowing explicitly so the rule cannot be
      read as forbidding log inspection in general. *(completed)*
- [x] Add one sentence stating Rule 2 applies identically to a local detached build/gate/test
      wait, pointing at `bounded-build-waiter.md` for that case's idiom (the "Local vs. Remote
      Waits" section already exists and is the natural anchor to reference). *(completed)*
- [x] Record the home ruling compactly, adjacent to Rule 2: this file is the single home for the
      filler prohibition; `bounded-build-waiter.md` and `context/contracts/orchestrator-discipline.md`
      were evaluated and rejected, the latter because its own first paragraph binds the
      orchestrator role and not the agents it dispatches, and widening that audience is out of
      scope here. Name no task numbers. *(completed)*
- [x] Confirm the measured-incident shape is already covered by the existing "The Defect" section
      and add nothing restating it (the four-step failure, the ~130 no-op calls, and the
      540-versus-600 reasoning are all already present). *(completed: confirmed unchanged, nothing
      added restating it)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/context/patterns/external-process-wait.md` - Rule 2 extended with
  the repeated-read prohibition and the read-once alternative; one local-case applicability
  sentence; a compact home ruling with rejected candidates

**Verification**:
- Diff read-through confirms every changed hunk is prose inside this one file; no rule renumbered,
  no existing sentence weakened or deleted.
- Rule 2 names the repeated-read case AND states the read-once alternative (both halves present —
  a prohibition without the alternative does not satisfy the acceptance criterion).
- The `orchestrator-discipline.md` rejection is written down with its audience reason.
- No task-number reference anywhere in the diff.
- Document count unchanged: `git status --short` shows a modification, never an addition.

---

### Phase 2: `bounded-build-waiter.md` — single-writer Rule 5 and the near-ceiling ruling [COMPLETED]

**Goal**: Add the single-writer rule for a shared fixture/build tree with a `flock`-based
mechanism and named prior art, record the near-ceiling sizing ruling beside Rule 1 and the
canonical idiom, and record the non-propagation ruling — without disturbing the generated-copy
fragment or Check H's extraction anchors.

**Tasks**:
- [x] Re-read `context/patterns/bounded-build-waiter.md` immediately before editing. *(completed)*
- [x] Add `5. **One writer per shared tree.**` to `## Required Rules`, after Rule 4: at most one
      writer per shared fixture/build tree per dispatch; before launching, acquire a `flock()`-held
      lock file scoped to the tree root and hold it until the writer completes; a second would-be
      writer detects the live lock and either waits on the existing writer or fails loudly naming
      the holder, never launching a second overlapping invocation. State why a kernel-held `flock`
      rather than a sentinel file: a dead holder's lock is released automatically, so this avoids
      the stale-sentinel defect already recorded as symptom 1 in this file's own "The Defect"
      section. *(completed)*
- [x] Cite `scripts/lake-build-guard.sh` by name as the prior art implementing exactly this shape
      (a tree-root-scoped `flock` lock, result sharing instead of a redundant second build, and
      its own header's reusable-family-convention language). Do not reinvent or re-specify the
      mechanism's internals. The existing "Conforming Examples" section already cites this script
      and is the natural anchor to extend. *(completed)*
- [x] Record the measured failure shape in one or two sentences: three overlapping invocations
      against one shared fixture tree, collision found only by hand process scanning, strays
      killed manually, one spurious failure diagnosed — enough that a reader sees Rule 5 is
      evidenced, not speculative. No task numbers; cite the suite and tree by path shape only.
      *(completed)*
- [x] Add the near-ceiling sizing ruling beside Rule 1 / the canonical idiom: a job whose expected
      duration approaches the Bash tool's per-call ceiling is not awaited in one call sized to its
      full runtime; launch once capturing `pid`, then issue a sequence of separate calls, each a
      `kill -0`-gated wait bounded safely under the ceiling, reading the log or exit status once
      liveness ends. Cross-reference `external-process-wait.md`'s margin reasoning rather than
      restating the numbers. State consistency with the settled background-versus-foreground
      ruling by concept, never by task number. *(completed)*
- [x] Record the non-propagation ruling: Rule 5 is **not** added to the "Canonical Agent-Contract
      Bullet (Generated-Copy Source)" bullet pair, because that would require a literal-copy pass
      across every carrying agent file plus an addition to the lint's curated in-scope array —
      the standing ground of `propagate_bounded_wait_contract_and_lint_coverage`, cited by that
      project name. One or two sentences, placed so a reader of the generated-copy section finds
      it. *(completed)*
- [x] Verify no added line contains the literal `canonical idiom VERBATIM` or
      ``arm a `Monitor` to watch a local verification`` — Check H extracts both by `grep -F … |
      head -n1`, so an earlier match would silently capture the extraction. *(completed:
      confirmed both literal strings occur only at their original two lines; `lint-agent-contracts.sh
      --verbose` Check H passes all 14 in-scope files)*

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase assumes `bounded-build-waiter.md` has exactly four numbered
Required Rules (Rule 4 being "One waiter per log") so the new rule is numbered 5, and that Check
H's two extraction anchors are the only `grep -F` dependencies any script has on this file's text.
Confirm at implementation time with `grep -n '^[0-9]\. \*\*' context/patterns/bounded-build-waiter.md`
and `grep -rn 'bounded-build-waiter' agent-system/extensions/core/scripts/` before editing; if a
third consumer exists, extend this phase's verification rather than proceeding.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` - new Rule 5
  (single-writer, `flock`-based, prior art named); near-ceiling sizing ruling beside Rule 1 and
  the canonical idiom; non-propagation ruling; measured failure shape recorded

**Verification**:
- Diff read-through confirms prose-only changes in one file; Rules 1-4 byte-identical; the fenced
  "Copy this exact text" block byte-identical.
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose` green, with
  Check H reporting a pass for every file in its in-scope array (count matches the array's length,
  re-derived at run time, not quoted from this plan).
- Rule 5 states a detection-or-prevention mechanism, not only an exhortation, and names
  `lake-build-guard.sh` as prior art.
- The near-ceiling ruling is present and is stated as consistent with the settled
  background-versus-foreground ruling, by concept.
- No task-number reference anywhere in the diff; the adjacent task is cited by project name only.

---

### Phase 3: `detect-noop-bash.sh` — streak accounting that survives alternation [COMPLETED]

**Goal**: Make a repeated read-only completion probe stop clearing the filler streak, so the
measured alternating pattern reaches the threshold, and make the advisory actionable for a local
build/test spin — while keeping the hook advisory-only, fail-open, and compatible with every
pre-existing test assertion.

**Design to implement** (settled here so the phase is executable; the implementer confirms it
against the replay before committing):

- **Class W (genuine progress)** — any non-trivial command that is not a repeated inspection
  probe. Behavior unchanged: delete the counter file.
- **Class T (trivial)** — `is_trivial_command` unchanged. Increments the counter. Unchanged.
- **Class P (repeated inspection probe)** — NEW. A non-trivial command whose every
  separator-delimited segment's leading word is in a narrow read-only inspection allowlist
  (`cat`, `tail`, `head`, `wc`, `grep`, `ls`, `stat`, `test`, `[`), **and** whose command-shape
  fingerprint (the ordered leading words, e.g. `wc|grep|tail`, not the exact text) has already
  been recorded for this session. A class-P call neither increments nor resets — it is not
  evidence of progress, so it must not clear a filler streak, and it is not filler itself, so it
  must not count as one. A *first-seen* inspection shape is class W (resets) and has its
  fingerprint recorded; only repetition changes the behavior.
- **State**: `noop-bash-count-<session>` stays a bare integer at the same path, deleted on class W
  exactly as today. The fingerprint memory lives in a **separate sidecar**,
  `noop-bash-shapes-<session>`, one normalized fingerprint per line, FIFO-capped at a small bound
  (10), surviving a class-W reset (otherwise a reset erases the very memory that detects the
  alternation). Every read/write stays inside the existing `|| true` tolerance pattern; an
  unreadable or malformed sidecar means "no memory," never a crash.
- **Message**: name `bounded-build-waiter.md` and its captured-`pid`/`kill -0`/outer-`timeout`
  idiom alongside the existing `external-process-wait.md` pointer, and name the newly counted
  class so the nudge is actionable. The substring `external-process-wait.md` must remain present
  (pre-existing assertions depend on it).

**Tasks**:
- [x] Re-read `hooks/detect-noop-bash.sh` immediately before editing. *(completed)*
- [x] Re-locate the measured sequence via the transcript path recorded in the research report's
      Finding 1 and extract the raw command list to the session scratchpad. If the transcript is
      no longer on disk, fall back to the alternation shape quoted verbatim in Finding 1 and say
      so in the summary — never silently substitute a synthetic pattern. *(completed: transcript
      still on disk at the recorded path; all 689 real Bash commands extracted)*
- [x] Record the BEFORE measurement by replaying that list through the unmodified hook with a
      scratch `NOOP_BASH_STATE_DIR` (expected: 0 firings, max streak 1). *(completed: 0 firings,
      max streak 1 -- matches the research report exactly)*
- [x] Implement the inspection-shape classifier as its own function beside `is_trivial_command`,
      with a header comment stating the same conservative-direction principle the file already
      documents, and blanking quoted spans before splitting segments so a quoted `|`/`[` inside a
      `grep` pattern cannot fragment a segment (the existing non-quote-aware split is safe only
      because its errors push toward "non-trivial"; here they would push toward "reset," which is
      the failure being fixed). *(completed: `inspection_fingerprint`, with the allowlist widened
      per the Scope Hypothesis to also accept a bare/literal `echo` (reusing `is_trivial_segment`)
      and a `kill -0`-only liveness check, covering 258/262 (98.5%) of the measured alternation's
      non-trivial neighbor commands; the 4 uncovered calls (an `awk` /proc/meminfo read, a
      for/case /proc scan) are deliberately left Class W, recorded rather than silently widened
      further)*
- [x] Implement the sidecar read/write/FIFO cap and the three-class dispatch, preserving
      deletion-on-class-W and the integer counter format. *(completed)*
- [x] Update the advisory message per the design above. *(completed)*
- [x] Update the file header's `Contract (non-negotiable)` block: the `RESETS on any non-trivial
      command` line is now false as written and must be restated as "resets on any genuine-progress
      command; a repeated read-only inspection probe is neither counted nor treated as progress,"
      with the measured alternation named as the reason. Keep ADVISORY ONLY and FAILS OPEN
      verbatim. *(completed)*
- [x] Record the AFTER measurement by replaying the same list through the modified hook.
      *(completed: 77 firings, max streak 36; first firing at call 139 of 689 -- the 27th call
      into the spin, which starts at index 112)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase assumes the measured sequence is still recoverable at the
transcript path recorded in the research report, and that its log-probe commands are composed only
of allowlisted inspection utilities. Confirm by extracting the list and inspecting the distinct
leading words before implementing; if a probe uses a utility outside the allowlist, widen the
allowlist deliberately (read-only utilities only) and record the addition, rather than declaring
the replay unrepresentative.

**Files to modify**:
- `agent-system/extensions/core/hooks/detect-noop-bash.sh` - inspection-shape classifier, sidecar
  fingerprint memory, three-class dispatch, widened advisory message, corrected header contract

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh` passes with **no
  edits to any pre-existing case** (the fixture additions are Phase 4; this phase must not need
  an assertion relaxed to go green).
- Replay of the measured sequence through the modified hook fires the advisory, and the BEFORE/
  AFTER firing counts and max-streak figures are both recorded for the summary.
- `shellcheck agent-system/extensions/core/hooks/detect-noop-bash.sh` clean; the file keeps its
  existing `set -euo pipefail` class per `context/standards/shell-strict-mode.md`.
- Manual fail-open spot check: empty stdin, non-JSON stdin, and an unwritable state dir each still
  yield `{}` and exit 0.
- The message still contains `external-process-wait.md` and now also `bounded-build-waiter.md`.

---

### Phase 4: `test-detect-noop-bash.sh` — measured alternation fixture and control [COMPLETED]

**Goal**: Make the closed gap a committed regression, and bound the false-positive direction with
a productive-work control that must not fire.

**Tasks**:
- [x] Re-read `scripts/tests/test-detect-noop-bash.sh` immediately before editing. *(completed)*
- [x] Add the alternating-call regression case built from Phase 3's extracted sequence: one
      trivial `echo idle`, one log-probe read, repeated, with paths normalized to the generic log
      names this suite already uses. Assert the advisory fires, and assert *when* (the call index)
      so a future accounting change that merely delays the fire to call 50 is caught. Carry a
      provenance comment stating the pattern is measured, not invented. *(completed: 29-command
      slice, indices 112-140 of the real 689-command transcript, paths normalized to
      /tmp/test-suite.{log,pid}; fires at call 28, asserted both "fires at least once" and "fires
      at or before call 28")*
- [x] Add a case asserting the pre-change behavior is genuinely gone: the same sequence under the
      old accounting produced zero firings and a maximum streak of 1 — assert the new maximum
      streak exceeds the threshold. *(completed: asserts new max streak (3) > 1)*
- [x] Add the productive-work control: a sequence of real commands (`git status`, a build-ish
      command, distinct `grep`s of *different* targets interleaved with occasional literal `echo`
      separators) asserting **no** advisory fires, so the new class cannot be read as counting
      ordinary inspection work. *(completed)*
- [x] Add a first-seen-versus-repeat case: one inspection probe resets the counter (class W);
      the same shape a second time does not (class P). *(completed)*
- [x] Add a sidecar-robustness case: a malformed/unreadable sidecar still yields `{}` and exit 0,
      and the hook never creates state outside `NOOP_BASH_STATE_DIR`. *(completed: malformed
      sidecar case plus unwritable-state-dir case plus re-confirmation of the no-stray-tmp-dir
      assertion)*
- [x] Confirm every pre-existing case is untouched, including the stray-`tmp`-directory assertion
      at the end of the suite (the sidecar must honor `NOOP_BASH_STATE_DIR` too). *(completed:
      `git diff --stat` shows 199 insertions, 0 deletions; all 40 pre-existing cases plus 10 new
      cases pass, 50/50)*

**Timing**: 1.25 hours

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the suite's pre-existing cases all still pass unmodified
and that the new cases are purely additive. Confirm with `git diff` on the test file showing only
additions plus, at most, the suite header comment — any modified pre-existing assertion is a
signal the Phase 3 design regressed documented behavior and must be reconciled before committing.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh` - measured alternation
  regression case, pre-change-behavior-gone case, productive-work control, first-seen-versus-repeat
  case, sidecar fail-open case

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh` green, every case
  passing, zero failures, and the pre-existing case count still present in the summary line.
- `shellcheck` clean on the test file per `context/standards/shell-strict-mode.md` (the suite is
  Class B, `set -uo pipefail`, counter idiom — do not migrate it).
- The alternating case fails if applied against the unmodified hook (demonstrate once, e.g. via
  `git stash` of the hook change or a copy of the pre-change file in the scratchpad) — a
  regression test that passes both before and after proves nothing.
- `git diff --stat` shows additions only on the pre-existing cases.

---

### Phase 5: Final gate, acceptance sweep, and recorded recommendations [COMPLETED WITH EXCLUSIONS]

**Goal**: Run the complete gate set, check each acceptance criterion off against the landed diff
rather than against intent, and record the consumer-repo and follow-up items as recommendations.

**Tasks**:
- [x] `bash .claude/scripts/verify-deploy.sh` (source-store path:
      `agent-system/extensions/core/scripts/verify-deploy.sh`) — complete gate set, including Gate
      8's full suite sweep. If the run approaches the per-call ceiling, apply this task's own
      Ruling 4: launch once with a captured `pid` and wait across a sequence of bounded
      `kill -0`-gated calls. Do not background-and-await-notification, and do not fill the wait
      with `echo`/log-poll calls — this task's own prohibition applies to this task's own gate run.
      *(completed: ran per this task's own Ruling 4 -- launched once with a captured pid, waited
      across five bounded 300s `kill -0`-gated calls (~20 min total), read the log once after
      liveness ended. Result: FAIL, 3 of 35 checks failed -- see Reasoned Exclusions below; none
      traces to this task's own 4 files being wrong)*
- [x] `shellcheck` clean on both changed shell files. *(completed: both
      `hooks/detect-noop-bash.sh` and `scripts/tests/test-detect-noop-bash.sh` clean)*
- [x] `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose` green
      (Check H unaffected). *(completed: 0 failed; Check H passes all 14 in-scope agent files)*
- [x] Net-document-count check: `git status --short` over `agent-system/**` shows four
      modifications and zero additions. *(completed: this task's 4 commits show exactly 4 `M`
      entries under `agent-system/**` -- the declared file_scope -- and zero `A` entries)*
- [x] Task-reference check: `bash .claude/scripts/check-task-references.sh` (or the equivalent
      sanctioned entry point) clean for every file landing outside `specs/**`. *(completed: 0
      occurrences in all 4 files)*
- [x] Walk the dispatch's acceptance list item by item against the landed diff, recording for each
      the file and section that satisfies it. *(completed -- see summary)*
- [x] Record in the summary, as recommendations and not as work done: the consumer-repo items (the
      ~9.5-minute certify suite sits 30s inside the 600s ceiling — shard or shorten it *there*;
      the deployed `.claude/hooks/` copy picks the accounting change up on its next regeneration);
      and the one declined-for-now follow-up (context-sensitive advisory text that detects a local
      backgrounded job, left declined because the message now names both idioms unconditionally,
      which closes Finding 2's gap without new detection logic). *(completed -- see summary)*
- [x] Record the BEFORE/AFTER replay figures from Phase 3 in the summary with the measurement
      method named. *(completed -- see summary)*

**Timing**: 1 hour

**Depends on**: 1, 2, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the task's total footprint is exactly the four declared
`file_scope` files, zero new files, and that no `--file-scope-add` was required. Confirm with
`git status --short` and `git diff --name-only` against the task's own commits; if a fifth file was
touched, stop and either revert it or add it via `scripts/update-task-status.sh --file-scope-add`
with the overlap accepted, per the dispatch's sanctioned re-scope path.

**Files to modify**:
- none planned — gate execution and acceptance accounting only; outputs go to the summary

**Verification**:
- `verify-deploy.sh` exits 0, with the gate it reports as complete named in the summary (not a
  hand-picked subset). **Not met as a bare pass** — see Reasoned Exclusions below; the 3 findings
  are each evidenced as outside this task's own 4-file scope.
- Every acceptance criterion in the dispatch has a named file and section satisfying it, or an
  explicit, reasoned exclusion.
- Zero new files under `agent-system/**`; zero task-number references outside `specs/**`.

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| `verify-deploy.sh` exits 0 (full gate set) | 3 of 35 checks FAIL, none attributable to a defect in this task's own 4 files. (a) Gate 5's "content differs from source" lists `hooks/detect-noop-bash.sh` and `scripts/tests/test-detect-noop-bash.sh` -- this is the structurally expected state of an unmerged source-store edit per `context/patterns/regeneration-is-manual-only.md` ("Source-store edits still do not deploy themselves... A stale deployed tree remains an expected state"); redeployment runs only through one of exactly two sanctioned automated call sites (`command-gate-out.sh`'s `rc==6` branch, `orchestrate-cycle-plan.sh`'s Inter-Cycle Redeploy Checkpoint), neither of which this dispatch is, so self-remedying by invoking `deploy-headless.sh` here would be an unsanctioned third call site. (b) The same gate's other two findings (`scripts/orchestrate-cycle-postflight.sh`, `scripts/tests/test-orchestrate-cycle-postflight.sh`) and all 3 of doc-lint's (gate 3) `core` FAIL lines trace to concurrent territory-sibling in-progress edits, exactly as this dispatch's own Territory payload named and warned not to treat as a regression. (c) Gate 8's sole failing suite, `test-four-tier-conflict.sh` case 6 (a timing-budget assertion), is unrelated to any of this task's 4 files. | (a) `verify-deploy.sh` log: `core: Content differs from source: hooks/detect-noop-bash.sh`, `core: Content differs from source: scripts/tests/test-detect-noop-bash.sh`. (b) This dispatch's own Territory payload names sibling task 284's declared `file_scope` as exactly `scripts/orchestrate-cycle-postflight.sh`, `scripts/tests/test-orchestrate-cycle-postflight.sh`, `specs/archive/state.json` -- a byte-for-byte match against the other two gate-5 findings and the doc-lint FAIL lines. (c) `test-four-tier-conflict.sh` re-run standalone immediately afterward: `Results: 13 passed, 0 failed` (case 6 passing with `exhaustion elapsed 1656ms within [1000ms, 2000ms)`), versus the full-suite run's `[FAIL] 6: budget-bound -- rc=1 elapsed_ms=2745 budget_ms=1000` -- confirming load-induced timing flakiness during the concurrent multi-gate run, not a regression. This task's own 4 files are independently verified clean: `shellcheck` clean on both shell files, `test-detect-noop-bash.sh` 50/50 green (including inside the full `run-all.sh` sweep), `lint-agent-contracts.sh --verbose` 0 failed, `check-task-references.sh` 0 occurrences on all 4 files. |

No residual work follows from this exclusion: the deploy-staleness half resolves automatically via the sanctioned redeploy-checkpoint mechanism on a future cycle (not a follow-up this task owns), the sibling-attributable findings resolve when that sibling task commits and the tree is next regenerated, and the flaky timing test is unrelated to this task's scope.

---

## Testing & Validation

- [x] `bash agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh` green, with every
      pre-existing case passing unmodified and the new alternation, control, first-seen-versus-repeat
      and sidecar cases passing. *(50/50 passing)*
- [x] The alternation case demonstrably fails against the pre-change hook (shown once, recorded in
      the summary). *(confirmed: 4 of the new assertions fail against `git show HEAD~1`'s hook,
      then restored and diff-confirmed identical)*
- [x] Replay of the measured command sequence through the modified hook fires the advisory; the
      BEFORE (0 firings / max streak 1) and AFTER figures are both recorded. *(BEFORE 0/1, AFTER
      77 firings / max streak 36 on the full 689-command transcript; 1/3 firings / max streak 3 on
      the committed 29-command fixture slice)*
- [x] `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose` green,
      Check H passing for every file in its curated array. *(0 failed; Check H 14/14)*
- [ ] `bash .claude/scripts/verify-deploy.sh` green — complete gate set, including Gate 8's full
      suite sweep. *(NOT met as a bare pass -- see Phase 5's Reasoned Exclusions: 3 of 35 checks
      FAIL, none attributable to this task's own 4 files)*
- [x] `shellcheck` clean on `detect-noop-bash.sh` and `test-detect-noop-bash.sh` per
      `context/standards/shell-strict-mode.md`; no strict-mode class changed. *(both clean;
      `set -euo pipefail` / `set -uo pipefail` unchanged)*
- [x] Both pattern documents: no rule deleted, renumbered, or weakened; `bounded-build-waiter.md`'s
      fenced generated-copy block byte-identical. *(confirmed via diff read-through; Rules 1-4 and
      the "Copy this exact text" block unchanged)*
- [x] Net document count unchanged — four modifications, zero additions under `agent-system/**`.
      *(confirmed: exactly 4 `M`, 0 `A` under `agent-system/**` across this task's 4 commits)*
- [x] No task-number references in any file landing outside `specs/**`; the adjacent coverage task
      cited by project name only. *(0 occurrences in all 4 files; the coverage task is cited by
      project name, `propagate_bounded_wait_contract_and_lint_coverage`, in
      `bounded-build-waiter.md`)*

## Artifacts & Outputs

- `agent-system/extensions/core/context/patterns/external-process-wait.md` (Rule 2 extension,
  local-case sentence, home ruling with rejected candidates)
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` (Rule 5 single-writer,
  near-ceiling sizing ruling, non-propagation ruling)
- `agent-system/extensions/core/hooks/detect-noop-bash.sh` (three-class streak accounting, sidecar
  fingerprint memory, widened advisory message, corrected header contract)
- `agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh` (measured alternation
  regression, productive-work control, first-seen-versus-repeat, sidecar fail-open)
- `specs/345_noop_spin_wait_contract_binding_and_single_writer/summaries/01_*-summary.md`
  (BEFORE/AFTER replay figures with method, the acceptance-criterion walk, consumer-repo
  recommendations, the declined follow-up, and any drift from this plan's figures)

## Rollback/Contingency

Each phase commits per-substep and the four files are independent of one another, so rollback is a
revert of the owning phase's commits. A partial landing is safe in both directions: the two pattern
documents are prose consumed on demand, and the hook stays advisory-only and fail-open, so a
reverted hook change restores exactly today's behavior with no stale state (the counter and sidecar
live in a transient `tmp` state dir and are regenerated per session).

There is therefore no scenario in this task requiring a working-tree-discarding rollback. Should one
nonetheless arise, follow `context/contracts/recovery.md`'s rollback rung for the
snapshot-then-rollback invocation shape, including its out-of-scope override flag — never a bare
precautionary `git-snapshot.sh` in its default reverting mode. The ordinary defensive checkpoint
before the Phase 3 hook edit is `bash .claude/scripts/git-snapshot.sh --no-revert 345`, which is
durable without reverting the working tree.

Contingency if Phase 3's replay does not fire even after the classifier change (for example because
the real probe commands vary more than their shape fingerprint tolerates): land Phases 1, 2 and 4's
prose and fixture work, record the replay result honestly as a still-open accounting gap with the
measured reason, and leave the hook unchanged rather than loosening the classifier until something
fires — a classifier tuned to make one fixture pass is worse than a documented open gap, and
Branch B's finding stands either way.
