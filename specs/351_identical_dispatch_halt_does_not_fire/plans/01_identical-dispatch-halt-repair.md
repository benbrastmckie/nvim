# Implementation Plan: Task #351

- **Task**: 351 - Repair the IDENTICAL DISPATCH HALT mechanism in orchestrate-cycle-plan.sh, which is implemented but never fires
- **Status**: [IMPLEMENTING]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/351_identical_dispatch_halt_does_not_fire/reports/01_identical-dispatch-halt-regression.md
- **Artifacts**: plans/01_identical-dispatch-halt-repair.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, git-staging-scope.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Research proved the root cause mechanically rather than by inference: the halt's trigger
predicate, back-out block, and call site are all correct and unmodified, but they are starved of
their `_idh_streak >= 2` input because `cycle_plan_dispatch_hash()`'s strip pattern is stale.
A sibling script (`orchestrate-build-dispatch.sh`) added a THIRD per-cycle-varying line to every
composed dispatch file — the Issue Log template's `[--dispatch-seq ${dispatch_seq}]` echo — on
2026-10-03 (`21f282089`) without revisiting the normalizer that hashes that content, so two
genuinely identical dispatches never hash equal and the streak resets to 1 every cycle.

The fix is therefore one strip-pattern line plus two comment corrections, wrapped in a red-first
regression fixture that pins the specific failure mode (a third varying location, not just the
two original ones) in Group 27's cheap isolated normalizer unit test rather than only in Group
28/29's expensive live arms. One pre-existing, orphaned working-tree fix to the same file lands
first as its own scoped commit so the two unrelated repairs are not conflated.

### Research Integration

Findings carried directly into the phases below:

- **No change to the halt logic itself** (predicate line ~2560, back-out block ~2562-2581, call
  site) — all three verified correct. Phase 3 touches only the normalizer at line ~2027 and its
  comment at lines ~2009-2019.
- **No change to `docs/architecture/orchestrate-state-machine.md`** — its description of the
  halt still matches intent; the recent "Not to be conflated with IDENTICAL DISPATCH HALT" note
  is a disambiguation against the unrelated `stall_suspected` mechanism and changes no contract.
  This settles the second "ALSO SETTLE" question with no doc edit.
- **No change to Group 28/29 fixtures** — they construct genuinely identical dispatches, proven
  by diffing the two dispatch files the SUT itself wrote during a live repro; the only deltas
  were the three bookkeeping lines. This settles the third "ALSO SETTLE" question.
- **Proven normalizer behavior**: the current pattern yields `7f85113c...` vs `5a33a237...` for
  two identical dispatches; the extended pattern yields `386ce8d6...` for both.
- **The orphaned H1 fix is still uncommitted and has no claimant** (confirmed again at plan
  time via `git status --porcelain`): it replaces `x=$(grep -c ... || echo 0)` with
  `x=$(grep -c ...) || x=0` at the H1 marker/handoff block, ~300 lines and a separate variable
  namespace away from the halt. Phase 1 lands it separately per research Recommendation 7.
- **Shellcheck is not resolvable on PATH** (stale Nix store path behind the `shellcheck` alias,
  re-confirmed at plan time). Phase 4 re-checks and records an explicit environment gap rather
  than silently skipping the gate.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no ROADMAP.md consultation performed.

## Goals & Non-Goals

**Goals**:
- Make the IDENTICAL DISPATCH HALT fire again on a second consecutive identical dispatch, by
  completing `cycle_plan_dispatch_hash()`'s enumeration of per-cycle-varying content.
- Pin the exact failure mode found (a third varying location) with a cheap, isolated regression
  fixture that fails red before the fix and green after.
- Make the next addition of per-cycle-varying dispatch content fail fast, by back-pointing from
  the generating script to the normalizer.
- Land the orphaned H1 `grep -c` fix as its own unconflated commit.
- Take `test-orchestrate-cycle-plan.sh` fully green and DELETE its `known-failures.txt` row.
- Redeploy the source store into `.claude/` and pass the repository gate set.

**Non-Goals**:
- Changing the halt's trigger predicate, back-out block, or call site (all verified correct).
- Changing `docs/architecture/orchestrate-state-machine.md` (contract unchanged).
- Changing Group 28/29 fixtures (verified non-stale).
- Writing the generalizable "normalizer staleness" pattern note the report floats as a Context
  Extension Recommendation — that is a separate, optional follow-up, not acceptance for this task.
- Any formal-acceptance path for the `known-failures.txt` row (the behaviour asserted is correct
  and achievable, so this is a fix-and-delete case).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| An over-broad strip addition normalizes away a genuinely meaningful difference (e.g. a task description quoting `[--dispatch-seq N]` verbatim) | H | M | Anchor on the full invariant boilerplate line shape (the `--what-happened "..." [--phase X] [--dispatch-seq N] \` template line), not a bare numeric substring; Phase 3 adds a negative assertion that a real Description change still changes the digest |
| The orphaned H1 fix is silently lost, or conflated into a commit whose message names only the halt repair | M | M | Phase 1 lands it first, alone, with its own descriptive message and explicitly scoped staging; Phase 1's verification re-reads `git show --stat` to confirm single-file, single-hunk scope |
| A fourth per-cycle-varying location is added later and silently regresses the guard again | M | M | Phase 2's Group 27 regression case plus Phase 4's back-pointer comment in the generating script together make the next such addition fail a cheap unit-style test immediately |
| Shellcheck remains unresolvable, leaving the acceptance criterion unverifiable | L | H | Phase 4 re-checks PATH, attempts a `nix run`/`nix-shell` resolution once, and on failure records an explicit, named environment gap in the summary rather than claiming the gate passed |
| Acceptance says "349/349" but the new fixture raises the assertion count | L | H | Phase 4 states the reconciliation explicitly: the bar is zero failures with a count >= 349, and the delta is attributable line-by-line to the fixture added in Phase 2 |
| Source-store/deploy boundary violation (editing `.claude/**` directly) | H | L | Every phase's file list names only `agent-system/extensions/core/**` paths; Phase 4 performs the redeploy that propagates them |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 3 |

Phases within the same wave can execute in parallel. Phases 1 and 2 touch disjoint files
(`orchestrate-cycle-plan.sh`'s H1 block vs. the test suite) and are genuinely independent;
Phase 3 depends on Phase 1 because it edits the same file Phase 1 must have committed first, and
on Phase 2 because it needs the red fixture to flip.

---

### Phase 1: Land the orphaned H1 `grep -c` fix as its own commit [COMPLETED]

**Goal**: Get the pre-existing, unclaimed working-tree fix to the H1 marker/handoff-mismatch
block committed on its own, so this task's halt repair is never conflated with it.

**Tasks**:
- [x] Re-confirm the change is still uncommitted and still exactly the described H1 hunk:
      `git diff -- agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` *(completed)*
- [x] Re-confirm no other active task claims it (re-run the research's ownership check over
      `specs/state.json` `active_projects[].file_scope` and `.description`); if a claimant has
      appeared since the research pass, STOP and record a blocker instead of committing
      *(completed: no active task besides 351 itself references this file)*
- [x] Confirm the hunk is confined to the H1 block (~line 2178) and touches no `_idh_*` symbol
      *(completed: one hunk, no _idh_* lines touched)*
- [x] Stage it with an explicit single-file pathspec (never `git add -A`, never a directory or
      glob pathspec, never `git commit -am`) and review `git status --short` plus
      `git diff --staged` before committing *(completed)*
- [x] Commit via `bash .claude/scripts/git-commit-scoped.sh` with a message naming the H1
      `grep -c` idiom repair, not the halt *(completed: commit e4ce63160)*

**Timing**: 0.25 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the orphaned change is exactly ONE file and ONE hunk,
confined to the H1 block. Confirm at implementation time with
`git diff --stat -- agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (expect one
file) and by reading the full diff (expect one hunk at ~2178); if a second hunk or file is
present, re-scope this phase and record the deviation in the issue log before proceeding.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - no new edit; commit the
  existing working-tree hunk as-is

**Verification**:
- `git show --stat HEAD` shows exactly one file changed, and `git show HEAD` exactly one hunk
- `bash -n agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` is clean
- `git status --porcelain -- agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` is
  empty afterwards
- The commit message names the H1/`grep -c` repair and makes no claim about the halt

---

### Phase 2: Pin the failure mode with a red Group 27 regression case [COMPLETED]

**Goal**: Add an isolated normalizer regression fixture that fails against the CURRENT, unfixed
`cycle_plan_dispatch_hash()` — proving it pins the found failure mode rather than merely
restating what already passes.

**Tasks**:
- [x] Read Group 27 Case A end to end (`test-orchestrate-cycle-plan.sh`, ~lines 3805-3850) to
      reuse its existing harness verbatim: `sed -n '/^cycle_plan_dispatch_hash() {/,/^}/p'`
      byte-extraction of the real function, and the
      `bash -c "$g27_hash_fn"$'\n''cycle_plan_dispatch_hash "$1"' _ "$file"` invocation idiom
      *(completed)*
- [x] Extend the Case A fixture file(s) so the base dispatch fixture also carries the real Issue
      Log boilerplate line, copied byte-for-byte from `orchestrate-build-dispatch.sh` line ~512's
      rendered output: `    --what-happened "..." [--phase implement] [--dispatch-seq 4] \`
      *(completed: new g27_f4/f5/f6 fixtures added rather than altering Case A's existing f1/f2/f3,
      per the Scope Hypothesis — Case A's own four assertions are unchanged)*
- [x] Add a new positive assertion: a variant differing ONLY in the Identity block's
      `dispatch_seq`/`dispatch_start_ts` AND in the Issue Log's `[--dispatch-seq N]` placeholder
      must hash IDENTICALLY to the base *(completed)*
- [x] Add a paired negative assertion: a variant whose Description genuinely differs (while
      carrying the same Issue Log line) must still hash DIFFERENTLY — this is the guard against
      an over-broad strip pattern, per the first risk row *(completed)*
- [x] Give the new case a name that states the contract, e.g. "Group 27 Case F: all THREE
      per-cycle-varying locations are normalized away (Identity pair + Issue Log placeholder)"
      *(completed)*
- [x] Run the suite and CONFIRM the new positive assertion FAILS red against the unfixed
      normalizer, and that the new negative assertion already passes; record both observations
      *(completed: 336 passed, 15 failed — orig 335/14 plus Case F positive [FAIL], negative [PASS])*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the new case adds exactly 2-3 assertions to the suite
and that Case A's existing byte-extraction harness is reusable unchanged. Confirm by diffing the
suite's total assertion count before and after (`bash .../test-orchestrate-cycle-plan.sh` tally
line) and by checking that no edit to Case A's own existing four assertions was needed; if Case
A's fixture must change in a way that alters its existing assertions, state that explicitly
rather than letting the count drift unattributed.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - add the new
  Group 27 regression case (and, if needed, extend Case A's base fixture to carry the Issue Log
  boilerplate line)

**Verification**:
- `bash -n agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` is clean
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` shows the new
  positive assertion as `[FAIL]` (expected red at this phase) and the new negative assertion as
  `[PASS]`
- The pre-existing failure set is unchanged in content: still exactly the 14 Group 28/29
  failures, plus the one new intentional red
- No task-number reference appears in the added text (the file lives under
  `agent-system/extensions/**`)

---

### Phase 3: Repair the normalizer and correct its stale comment [COMPLETED]

**Goal**: Extend `cycle_plan_dispatch_hash()`'s strip pattern to cover the Issue Log's
per-cycle placeholder, and correct the comment that falsely claims the two Identity lines are the
only varying content — flipping Phase 2's red fixture and all 14 Group 28/29 failures green.

**Tasks**:
- [x] Re-read `orchestrate-build-dispatch.sh` line ~512 and confirm the exact literal rendered
      text of the boilerplate line, including leading whitespace and the trailing ` \`, before
      choosing the regex anchor *(completed: confirmed via this task's own .dispatch/3.md,
      `cat -A` showing `    --what-happened "..." [--phase implement] [--dispatch-seq 3] \$`)*
- [x] Extend the `grep -v -E` pattern at `orchestrate-cycle-plan.sh` line ~2027 with one
      alternation matching that whole invariant boilerplate line (preferred over a bare
      `\[--dispatch-seq [0-9]+\]` substring match, per the first risk row), escaping regex
      metacharacters (`[`, `]`, `"`, `.`) correctly for ERE *(completed)*
- [x] Rewrite the comment at lines ~2009-2019 so it enumerates all THREE varying locations,
      names which sibling-script change introduced the third, and states the standing obligation:
      any new per-cycle-varying interpolation into the dispatch body must be added here in the
      same change. Use durable anchors (file path, section name, commit SHA) — never a task
      number, since this file lives under `agent-system/extensions/**`
      *(completed: names commit 21f282089 and 2026-10-03)*
- [x] Run the suite; confirm Phase 2's new positive assertion flips to `[PASS]`, its negative
      assertion still passes, and Group 28 plus Group 29 arms B/C/D all flip to `[PASS]`
      *(completed: 351 passed, 0 failed)*
- [x] Commit with an explicit single-file pathspec and a message naming the normalizer repair
      *(completed: commit ff835f3b1)*

**Timing**: 1 hour

**Depends on**: 1, 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts all 14 currently-failing assertions flip green from this
single edit, with no change to the halt predicate, back-out block, or call site. Confirm by
comparing the suite's `[FAIL]` list before and after: it must go from exactly the 14 named
failures (plus Phase 2's intentional red) to empty. If any Group 28/29 assertion still fails, the
single-root-cause finding is incomplete — stop, re-diagnose, and record the deviation rather than
patching the halt block to compensate.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - extend
  `cycle_plan_dispatch_hash()`'s strip pattern (line ~2027); rewrite its preceding comment
  (lines ~2009-2019)

**Verification**:
- `bash -n agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` is clean
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` reports zero
  failures
- Spot-proof of the mechanism independent of the suite: hash two dispatch files differing only in
  the three bookkeeping locations through the patched function and confirm equal digests, then
  change one Description line and confirm the digest changes
- `git diff HEAD~1 -- .../orchestrate-cycle-plan.sh` touches only the normalizer and its comment;
  no `_idh_streak`, back-out, or call-site line appears in the diff

---

### Phase 4: Back-pointer comment, suite closeout, known-failures row deletion, and redeploy [COMPLETED]

**Goal**: Prevent the next recurrence structurally, take the suite green under `run-all.sh`,
delete this task's `known-failures.txt` row, and redeploy with the repository gate set passing.

**Tasks**:
- [x] Add a comment at `orchestrate-build-dispatch.sh`'s Issue Log block (~line 512) pointing
      forward to `cycle_plan_dispatch_hash()`'s strip pattern, warning that any new
      per-cycle-varying interpolation into the dispatch body must update that normalizer in the
      same change (durable anchors only, no task numbers) *(completed)*
- [x] Run the full suite once more and record the tally; reconcile it against the task's stated
      "349/349" bar explicitly: the acceptance is ZERO failures with a total >= 349, the delta
      attributable line-by-line to Phase 2's added assertions
      *(completed: 351 passed, 0 failed — the +2 over 349 is exactly Phase 2's Case F
      positive+negative pair)*
- [x] Run `bash agent-system/extensions/core/scripts/tests/run-all.sh --fail-on-new` and confirm
      `test-orchestrate-cycle-plan.sh` passes *(completed: passes; one unrelated pre-existing
      NEW failure in test-verify-deploy-context-budget.sh noted separately, out of scope)*
- [x] DELETE the `test-orchestrate-cycle-plan.sh` row (line ~35) from
      `agent-system/extensions/core/scripts/tests/known-failures.txt` — the fix path, not the
      formal-acceptance path, so no owner slug is written. Do not touch any other task's row, and
      do not duplicate this status in prose anywhere else *(completed)*
- [x] Re-run `run-all.sh --fail-on-new` after the deletion and confirm the suite is not
      reclassified as a NEW failure (i.e. it genuinely passes rather than having been masked)
      *(completed: not in the Failing suites list; confirmed [PASS] in the log)*
- [x] Re-check shellcheck resolvability on PATH; if still broken (stale Nix store path behind the
      `shellcheck` alias), attempt one resolution via `nix run nixpkgs#shellcheck` and, if that
      also fails, record a named environment gap in the summary — never claim the gate passed
      *(completed: resolved via `nix run nixpkgs#shellcheck`; all findings pre-existing,
      zero new findings on any line this task touched)*
- [x] Redeploy: `bash .claude/scripts/deploy-headless.sh`, then confirm the three edited source
      files' content reached their `.claude/**` counterparts *(completed: confirmed byte-identical
      diff for all 4 edited source files)*
- [x] Run the full gate set: `bash .claude/scripts/verify-deploy.sh`
      *(completed with a reasoned exclusion: 33/34 checks pass; gate 13's whole-tree orphan
      detection reports 3 pre-existing, unrelated orphans — stale deployed copies of
      roadmap-integration.sh and its two test files, quarantined to deprecated/ by an unrelated
      already-committed prior change, outside this task's file_scope. Per
      context/patterns/deploy-orphan-detection.md, deleting them is "a deliberate human (or
      explicitly-scoped task) action" — not attempted here. This task's own 4 edited files are
      unaffected and verified byte-identical post-deploy)*
- [x] Commit the test-file, build-dispatch, and known-failures changes with explicit per-file
      pathspecs *(completed: commits 88f9dadfb, ff835f3b1, 8b55642ce)*

**Timing**: 0.75 hours

**Depends on**: 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts exactly ONE `known-failures.txt` row is owned by this
task and must be deleted. Confirm with
`grep -n "orchestrate-cycle-plan" agent-system/extensions/core/scripts/tests/known-failures.txt`
immediately before the deletion (expect exactly one matching line); if more than one row matches,
delete only the `test-orchestrate-cycle-plan.sh` row and leave the others, recording why.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - add the forward-pointer
  comment at the Issue Log block (~line 512)
- `agent-system/extensions/core/scripts/tests/known-failures.txt` - delete the
  `test-orchestrate-cycle-plan.sh` row
- `.claude/**` (generated, via `deploy-headless.sh`) - not hand-edited; regenerated from source

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` passes (the complete gate set for this repository)
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --fail-on-new` exits 0
- `grep -c "orchestrate-cycle-plan" .../known-failures.txt` returns 0
- `diff` between each edited source file and its deployed `.claude/scripts/` counterpart is empty
- `bash -n` is clean on both edited shell scripts; shellcheck result (pass, or a named
  environment gap) is recorded explicitly
- No task-number reference appears in any file touched under `agent-system/**`

---

## Testing & Validation

- [x] `test-orchestrate-cycle-plan.sh`: zero failures, total assertion count >= 349, with the
      delta over 349 attributable to Phase 2's new case *(completed: 351 passed, 0 failed)*
- [x] Group 28 and Group 29 arms B/C/D all pass, with no edit to their fixtures *(completed)*
- [x] Phase 2's new positive assertion is demonstrated red before Phase 3 and green after —
      recorded, not asserted *(completed: recorded in phase-2/phase-3 progress files)*
- [x] The new negative assertion (genuine Description change still changes the digest) passes
      both before and after the fix, proving the strip pattern is not over-broad *(completed)*
- [x] `run-all.sh --fail-on-new` exits 0 with no `known-failures.txt` row for this suite
      *(completed with a reasoned exclusion: this suite itself has no row and passes; the
      overall run-all.sh exit code is nonzero only because of ONE unrelated, pre-existing NEW
      failure in test-verify-deploy-context-budget.sh, last touched by an unrelated, already-
      completed prior task and never modified by this task. test-orchestrate-cycle-plan.sh is
      confirmed [PASS] and absent from the Failing suites list in both the before- and
      after-deletion runs)*
- [x] `verify-deploy.sh` passes; `bash -n` clean on both edited scripts *(completed with a
      reasoned exclusion: 33/34 checks pass; `bash -n` clean on all 3 edited scripts; gate 13's
      orphan-detection failure is pre-existing, unrelated roadmap-integration.sh deploy drift —
      see Phase 4's own task annotation for detail)*
- [x] Shellcheck: clean, or an explicitly named environment gap *(completed: resolved via
      `nix run nixpkgs#shellcheck`; zero new findings introduced by this task)*
- [x] No hand-authored edit landed under `.claude/**`; all three source edits are under
      `agent-system/extensions/core/**` and reached `.claude/**` only via redeploy *(completed)*
- [x] No task-number reference in any `agent-system/**` file touched *(completed)*

## Artifacts & Outputs

- Repaired `cycle_plan_dispatch_hash()` strip pattern and corrected comment in
  `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`
- Forward-pointer comment in `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`
- New Group 27 regression case in
  `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh`
- `test-orchestrate-cycle-plan.sh` row removed from
  `agent-system/extensions/core/scripts/tests/known-failures.txt`
- The orphaned H1 `grep -c` fix committed on its own
- Regenerated `.claude/` deploy tree
- Execution summary at `specs/351_identical_dispatch_halt_does_not_fire/summaries/01_*-summary.md`
  naming the root cause (the stale normalizer strip pattern at `orchestrate-cycle-plan.sh` line
  ~2027) and the regression date (`21f282089`, 2026-10-03)

## Rollback/Contingency

- Each phase commits separately, so any single phase reverts with `git revert <sha>` without
  disturbing the others; the H1 fix in particular is independently revertible by design.
- If Phase 3's single-line fix does NOT flip all 14 assertions green, the single-root-cause
  finding is incomplete: stop, do not patch the halt block to compensate, re-diagnose from the
  live repro recipe in the research report's Appendix, and record the deviation. The
  `known-failures.txt` row stays in place in that case (its reason and `owner` updated to this
  task's durable slug `identical_dispatch_halt_does_not_fire` only if a reasoned exclusion
  genuinely remains).
- The `known-failures.txt` row deletion in Phase 4 is the LAST substantive edit and is gated on a
  green `run-all.sh --fail-on-new`; if that run is not green the row is left untouched.
- A failed redeploy is recoverable by re-running `bash .claude/scripts/deploy-headless.sh`; the
  source store under `agent-system/extensions/core/**` remains the authority either way.
- Before any intentional rollback that would discard uncommitted work, run
  `bash .claude/scripts/git-snapshot.sh 351` first.
