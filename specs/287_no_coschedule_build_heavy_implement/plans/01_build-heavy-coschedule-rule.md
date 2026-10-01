# Implementation Plan: Task #287

- **Task**: 287 - No co-schedule build-heavy implement (Mode 2 admission rule)
- **Status**: [NOT STARTED]
- **Effort**: 2.5 hours
- **Dependencies**: `specs/decisions/worktree-isolation-removal-verdict.md` ("Mode 2 Ruling: an Admission Rule, Not a PATH Shim" — the specification, not re-openable)
- **Research Inputs**: `specs/287_no_coschedule_build_heavy_implement/reports/01_build-heavy-coschedule-admission.md`
- **Artifacts**: plans/01_build-heavy-coschedule-rule.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Close concurrency failure Mode 2 (shared build-directory contention) by adding a
cycle-split admission rule to `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`:
never dispatch two build-heavy implement tasks in the same cycle — the second defers to a later
cycle with its own named defer reason. The existing `WORKTREE_ISOLATED_TASK_TYPES=("lean4"
"cslib")` array is renamed to `BUILD_HEAVY_TASK_TYPES` to state its now-dual meaning and kept as a
single array with a single reader (`task_selected_for_worktree_isolation()`, which already encodes
"phase == implement AND task_type in family"). Done when the rule is live inside the existing
bucketing loop, documented in the script's header contract, covered by four new fixture cases, and
the wider harness shows no new failures.

### Research Integration

Findings carried in directly from `reports/01_build-heavy-coschedule-admission.md`:

- **Insertion point**: the per-task bucketing loop (`orchestrate-cycle-plan.sh:1786-1839`), which
  builds `dispatch_candidates`/`out_deferred_rows`/`out_blocked_rows` from `eligible_tasks`. The
  new check belongs immediately before `dispatch_candidates+=("$t")` (line 1838), right after the
  existing `admit_decision` defer check.
- **Dry-run/live parity is free**: this loop runs identically in both modes; the fork happens
  downstream at the lock-probe / per-mode row-builder stage (~1842, ~2417, ~2583). There is no
  second row builder to keep in sync, so the dispatch's "byte-for-byte" requirement is satisfied
  structurally rather than by duplicated code.
- **State already in scope**: `task_types[$t]` (populated at 1152-1176) and `g`
  (`effective_group[$t]`, bound at the top of each iteration). Nothing new needs threading in.
- **Output shape**: a plain `{task, reason}` row with a free-text `reason`, per the script's own
  header "Output" contract (~line 205) and every existing locally-produced deferred row. The
  richer `colliding_task_number`/`collision_scope`/`overlapping_path` payload the dispatch warns
  against belongs to `orchestrate-batch-admit.sh`'s separate `file_scope_collision` schema — out
  of scope, untouched.
- **Zero-fan-out rename**: re-verified at plan time. `WORKTREE_ISOLATED_TASK_TYPES` appears on
  exactly two lines in exactly one `.sh`/`.md` file outside `specs/**` (lines 1985 and 1989 of the
  source script). Every other hit is prose in `specs/**`, which is exempt.
- **Test home**: a new Group 32 appended to
  `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` (Group 31 currently
  ends the file at line 4501), reusing the `write_state`/`reset_lock_dirs`/`run_sut`/`jqf` idiom.
- **Fixture confound to avoid**: Group 31's own documented discovery — `orchestrate-batch-admit.sh`
  already defers one of two same-cycle candidates whose `file_scope` entries are identical or
  directory-nested. Keep every build-heavy fixture's `file_scope` empty (Group 30's safe pattern)
  so the new rule, not the pre-existing check, is what fires.

**One research recommendation is corrected by this plan.** Recommendation 2 has the new call site
invoke `task_selected_for_worktree_isolation` at line ~1838, but that function is *defined* at
line 1986 — and everything from line 749 through EOF lives inside `orchestrate_cycle_plan_main`
(invoked on the last line of the file). A function definition nested inside a function body is
only registered when the outer body *executes* that statement, so at loop time the predicate does
not yet exist. Verified empirically at plan time: the call returns 127 ("command not found"),
which an `if` guard silently swallows as false under `set -euo pipefail`. The rule would compile,
shellcheck clean, and never fire. Phase 1 therefore **hoists** the array and predicate above the
bucketing loop before Phase 2 adds any call site. All three existing call sites (2205, 2427, 2594)
are downstream of both the old and the new position, so the hoist is a pure relocation.

### Prior Plan Reference

No prior plan for this task (this is round 1). Adjacent precedent: task #286's plan explicitly
deferred this mechanism here and instructed that
`task_selected_for_worktree_isolation()`/`WORKTREE_ISOLATED_TASK_TYPES` not be deleted — honored.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's context, so `specs/ROADMAP.md` was not consulted
and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- Never dispatch two build-heavy implement tasks in the same cycle; the second (and later) defer
  to a future cycle — deferred, never failed.
- Rename `WORKTREE_ISOLATED_TASK_TYPES` to `BUILD_HEAVY_TASK_TYPES`, keeping one array with one
  reader so a future extension adds its type in exactly one place.
- Emit the decision as its own named defer reason in `deferred[]`, never overloading the
  `file_scope_collision` reason.
- Document the rule in the script's header contract to the standard of the existing reasons.
- Four fixture cases pass; the wider harness shows no new failures against `known-failures.txt`.

**Non-Goals** (recorded so they are not read as omissions):

- No PATH-shim wrapper for build tools. A bare build invocation from outside an orchestration
  still bypasses `lake-build-guard.sh`'s opt-in lock; the decision record declines the shim for
  now with that residual named. Do not build one, and do not wire the guard into call sites.
- No removal of worktree isolation. `task_selected_for_worktree_isolation()`, its name, and its
  three call sites keep working unchanged — a separate, later task owns the removal.
- No edit to `orchestrate-batch-admit.sh`, no change to its defer-reason schema, no `MAX_TASKS`
  change.
- No hand-editing of `.claude/scripts/orchestrate-cycle-plan.sh` (a disposable deploy mirror).
- No `defer_ledger` entry for the new reason. Decided deliberately: no consumer reads
  `defer_ledger` contents for behavior, and the acceptance criteria name only the `deferred[]`
  row. Research left this to implementation discretion; this plan closes it as "omit".

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Predicate called before its nested definition executes — silent always-false (rc 127 swallowed by `if`) | H | H (certain, if the hoist is skipped) | Phase 1 hoists the array + predicate above the loop and lands a comment stating the definition-order constraint; Phase 3 Case (i) is the behavioral proof the rule actually fires |
| A fixture trips the pre-existing in-batch `file_scope_collision` check instead of the new rule, giving a false pass | H | M | Every build-heavy fixture uses `"file_scope": []` (Group 30's pattern) and task-directory numbers off any `critical_paths` entry so `self_modifying` stays false; Case (i) additionally asserts on the new reason's text, which `file_scope_collision` can never produce |
| Chasing pre-existing shellcheck noise, or reading it as a regression | M | M | Baseline captured at plan time: 3 × SC2154 (warning) at lines 1661/1780/2601, plus 7 × SC1091, 4 × SC2012, 60 × SC2016 (all info) — all false positives from the `run_capture_stdout` nameref idiom. "Clean" means *no new findings beyond this baseline* |
| A future refactor moves the hoisted block back down, silently re-breaking the rule | M | L | The hoisted block carries an explicit comment naming the definition-order constraint and the 127-swallowed-by-`if` failure mode |
| Ordering nuance: the first-admitted build-heavy candidate is later deferred by the lock probe, so the cycle dispatches zero build-heavy tasks instead of one | L | L | Accepted, not fixed. Mirrors the existing `file_scope_collision` decision's own relationship to the lock probe (also decided before, never re-validated after) and does not violate "deferred, never failed" — the task simply waits for the next cycle. Recorded here so it is not rediscovered as a defect |
| A defer-reason string containing `task <N>` trips the no-task-references lint | L | M | `TASK_PATTERN` matches `\b[Tt]asks?[ _-]?[0-9]+\b`; the reason string uses the test suite's own `candidate #<N>` phrasing instead. The row's JSON key `task` is followed by `$t`, not a digit literal, so it cannot match |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel. This plan is strictly linear: Phase 2 needs
the predicate in scope, Phase 3 needs Phase 2's exact reason string to assert on, and Phase 4 is
the acceptance gate over everything.

---

### Phase 1: Hoist and rename the build-heavy task_type array [NOT STARTED]

**Goal**: `BUILD_HEAVY_TASK_TYPES` and its single reader are defined *before* the bucketing loop,
with no behavior change anywhere, so Phase 2 can call the predicate at all.

**Tasks**:

- [ ] Move the comment block + `WORKTREE_ISOLATED_TASK_TYPES=(...)` + `task_selected_for_worktree_isolation()` (currently lines ~1975-1993) to immediately **above** the `# ── Bucket eligible_tasks into dispatch-candidates / deferred / blocked / skip ──` banner at line 1784.
- [ ] Rename the array identifier to `BUILD_HEAVY_TASK_TYPES` at both occurrences (its assignment and the `for candidate in "${...[@]}"` loop inside the predicate). Change nothing else about the predicate — not its name, not its signature, not its body logic.
- [ ] Rewrite the block's leading comment to state the array's now-dual meaning: it drives (a) the pre-existing, unremoved worktree-isolation selection predicate and (b) the new build-heavy co-scheduling admission rule, and it is the single place a future extension adds its task_type.
- [ ] Add to that comment an explicit note on **why the block lives here and must not be moved back down**: everything from line 749 through EOF is inside `orchestrate_cycle_plan_main`, so a nested definition is only registered when execution reaches it; a call from the bucketing loop to a predicate defined later returns 127, which an `if` guard swallows as a silent false.
- [ ] Confirm the three existing call sites (originally lines 2205, 2427, 2594) are untouched and still downstream of the new definition position.

**Timing**: 0.3 hours

**Depends on**: none

**Verification Tier**: `local`

**Scope Hypothesis**: the rename touches exactly 2 lines in exactly 1 file, and the predicate has
exactly 3 existing call sites. Confirm at implementation time with
`grep -n 'WORKTREE_ISOLATED_TASK_TYPES\|BUILD_HEAVY_TASK_TYPES\|task_selected_for_worktree_isolation' agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`
before and after: the old identifier must reach 0 hits, the new one exactly 2, and the predicate
name 1 definition + 3 call sites + its own comment mentions.

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - relocate and rename the array/predicate block; expand its comment

**Verification**:

- `grep -c WORKTREE_ISOLATED_TASK_TYPES` on the file returns 0; `BUILD_HEAVY_TASK_TYPES` returns 2.
- The definition's line number is strictly less than the bucketing-loop banner's line number, and strictly less than all three call sites' line numbers.
- `shellcheck agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` yields no findings beyond the recorded baseline (3 × SC2154, 7 × SC1091, 4 × SC2012, 60 × SC2016).
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` passes with the same pass/fail counts as before this phase (Groups 30 and 31 exercise the predicate and must be unaffected — this phase is a pure relocation).

---

### Phase 2: Add the Mode 2 co-scheduling admission rule and its header contract [NOT STARTED]

**Goal**: at most one build-heavy implement task is admitted per cycle; every later one lands in
`deferred[]` with its own named reason, identically in `--dry-run` and the live path.

**Tasks**:

- [ ] Declare a scalar before the bucketing loop (beside `declare -a dispatch_candidates=()` at line 1785) holding the first build-heavy implement candidate admitted this cycle, e.g. `build_heavy_implement_admitted=""`.
- [ ] Inside the loop, immediately before `dispatch_candidates+=("$t")` (after the existing `admit_decision` defer check), test candidacy via `task_selected_for_worktree_isolation "$g" "${task_types[$t]:-}"` — calling the predicate, never re-iterating the array, so "single array, single reader" holds literally.
- [ ] On a hit with the scalar already set: push a `{task, reason}` row onto `out_deferred_rows` and `continue` (never reaching `dispatch_candidates`). On a hit with the scalar empty: set it to `$t` and fall through to admission.
- [ ] Use a distinct, grep-able reason string that names the colliding in-cycle candidate inline as prose (the way `MAX_INFRA_FAILURES`/`MAX_CYCLES` reasons already interpolate detail), never the literal `file_scope_collision`. Phrase the cross-reference as `candidate #<N>`, not `task <N>` — see the Risks table's lint entry. Suggested text: `build-heavy implement co-scheduling: candidate #<N> is already this cycle's one build-heavy implement dispatch; deferring to a later cycle`.
- [ ] Add an inline comment at the new check in the style of the surrounding `Decision N` / Phase-N comments: state the rule, that it is implement-phase-scoped (a research or plan dispatch does not build), that it sits in the shared loop so `--dry-run` and live render the identical choice with no second row builder, and that it is deferred-never-failed.
- [ ] Update the header's `isolation` paragraph (~line 215) to name `BUILD_HEAVY_TASK_TYPES`.
- [ ] Add a short header paragraph beside it, in the existing `Decision N` style, documenting the new `deferred[]` reason to the standard of the existing reasons: what it means, that it is implement-phase-only, that it is emitted identically in both modes, and a pointer to `specs/decisions/worktree-isolation-removal-verdict.md`'s "Mode 2 Ruling" section.
- [ ] Do **not** add a `defer_ledger` entry (see Non-Goals).

**Timing**: 0.7 hours

**Depends on**: 1

**Verification Tier**: `full`

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - new scalar + admission check inside the bucketing loop; inline decision comment; header `isolation` paragraph update; new header paragraph for the defer reason

**Verification**:

- `shellcheck` on the file yields no findings beyond the Phase 1 baseline.
- A manual two-candidate smoke run (two `lean4`/`cslib` `implementing` fixtures, empty `file_scope`) under `--dry-run` shows `.dispatch | length == 1` and `.deferred | length == 1` with the new reason text.
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` shows no regression against the Phase 1 counts (no existing group co-schedules two build-heavy implement candidates, so none should change verdict — if one does, that is a real finding to report, not a fixture to silence).
- The header now documents the new reason, and `grep -nE '\b[Tt]asks?[ _-]?[0-9]+\b'` over the diff finds no match.

---

### Phase 3: Group 32 fixture coverage for the four acceptance cases [NOT STARTED]

**Goal**: the four dispatch-named behaviors are pinned by fixtures, including the dry-run/live
parity assertion.

**Tasks**:

- [ ] Append a new `# Group 32:` banner + `info` line after Group 31 (currently ending at line 4501), following the file's established `write_state`/`reset_lock_dirs`/`run_sut`/`jqf`/`pass`/`fail` idiom.
- [ ] Case (i): two build-heavy `implementing` candidates (one `lean4`, one `cslib`), both with `"file_scope": []`, under `--dry-run` -> assert `.dispatch | length == 1` **and** `.deferred | length == 1` **and** that `.deferred[0].reason` contains the new rule's distinguishing substring. Assert on counts and reason text, not on which specific number dispatched.
- [ ] Case (ii): one build-heavy (`lean4`) + one `general` candidate, both `implementing` -> assert `.dispatch | length == 2` and `.deferred | length == 0` (ordinary implement traffic unchanged).
- [ ] Case (iii): two build-heavy candidates in different phases (one `"status": "implementing"`, one `"status": "researched"`) -> assert `.dispatch | length == 2`, confirming implement-phase scoping.
- [ ] Case (iv): the Case (i) fixture run once under `--dry-run` and once live -> assert the two runs' `.deferred[].reason` strings are byte-for-byte identical and both `.dispatch | length == 1`. Reuse Group 30 Cases D-F's already-staged `dispatch-worktree.sh` and `orchestrate-build-dispatch.sh` stubs (they persist in `$WORKDIR/.claude/scripts/` per Group 31's header note); pick task numbers that avoid 3005, the one number Group 30's stub is coded to fail provision for.
- [ ] Keep every fixture's project numbers off any `critical_paths` entry so `self_modifying` stays false and does not confound the result.
- [ ] Phrase all `pass`/`fail` messages as `candidate #N` / `project #N`, per the test file's own documented NOTE and `rules/no-task-references-in-deliverables.md`.

**Timing**: 1.0 hours

**Depends on**: 2

**Verification Tier**: `local`

**Scope Hypothesis**: exactly four new cases in one new group in one file, and Group 30's live-path
stubs are still in place and reusable at the append point. Confirm at implementation time by
re-reading Group 30's Cases D-F stub setup and Group 31's header note before writing Case (iv);
if the stubs turn out not to persist that far, stage them locally in Group 32 rather than
dropping the live half of the parity assertion.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - append Group 32 with the four cases

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` reports all four new cases PASS and the suite's prior cases unchanged; exit 0.
- Sanity check that Case (i) is really exercising the new rule: temporarily assert the deferred reason does **not** contain `file_scope`, or confirm by inspection that both fixtures declare `"file_scope": []`.
- `shellcheck` on the test file yields no findings beyond its recorded baseline (1 × SC2016, 1 × SC2034, 2 × SC2319, 1 × SC2329).

---

### Phase 4: Harness regression gate and acceptance sweep [NOT STARTED]

**Goal**: the acceptance criteria are demonstrably met with evidence, and no new failure was
introduced anywhere in the harness.

**Tasks**:

- [ ] Run the wider harness (`bash agent-system/extensions/core/scripts/tests/run-all.sh`) and diff its failures against `agent-system/extensions/core/scripts/tests/known-failures.txt`. Note that `known-failures.txt` currently records no `orchestrate-cycle-plan` entries, so any failure in that suite is new by definition.
- [ ] Confirm no new failure. If one appears, report it with its output rather than adjusting the fixture to pass.
- [ ] Re-run `shellcheck` on both edited files and record the final counts against the plan-time baselines.
- [ ] Run the task-reference lint (`bash .claude/scripts/check-task-references.sh` or equivalent) to confirm no task-number citation landed outside `specs/**`.
- [ ] Walk the acceptance list explicitly and record evidence for each item: rule inside the existing cycle-split layer; own defer reason; reason documented in the header contract; array has one reader and a name stating its current meaning; shellcheck clean against baseline; four cases pass; no new harness failures.
- [ ] Confirm no file under `.claude/**` was hand-edited (the deploy mirror is regenerated, never authored).

**Timing**: 0.5 hours

**Depends on**: 3

**Verification Tier**: `full`

**Files to modify**:

- none planned (verification-only phase; any file touched here is a fix fed back into Phase 1-3's targets)

**Verification**:

- `run-all.sh` failure set is a subset of `known-failures.txt`.
- Both files' shellcheck findings equal their plan-time baselines.
- The task-reference lint passes.
- Every acceptance bullet has a recorded evidence line.

---

## Testing & Validation

- [ ] Case (i): two build-heavy implement candidates in one cycle -> 1 dispatch row + 1 deferred row carrying the new reason.
- [ ] Case (ii): one build-heavy + one ordinary implement candidate -> both dispatch, unchanged.
- [ ] Case (iii): two build-heavy candidates in different phases -> both dispatch (implement-phase scoping).
- [ ] Case (iv): `--dry-run` and live report the identical decision, byte-for-byte.
- [ ] `test-orchestrate-cycle-plan.sh` exits 0 with Groups 1-31 unchanged.
- [ ] `run-all.sh` introduces no failure absent from `known-failures.txt`.
- [ ] `shellcheck` on both edited files equals the plan-time baselines (no new findings).
- [ ] No task-number reference outside `specs/**`.
- [ ] No hand-edit under `.claude/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — hoisted + renamed
  `BUILD_HEAVY_TASK_TYPES`, the new in-loop admission check, its inline decision comment, and the
  header-contract documentation for the new `deferred[]` reason.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — new Group 32 with
  the four acceptance cases.
- `specs/287_no_coschedule_build_heavy_implement/summaries/01_*-summary.md` — implementation
  summary (written at implement time).

## Rollback/Contingency

Both edits are confined to two files in the source store, and each phase ends at a green,
independently committed milestone, so the ordinary contingency is `git revert` of the offending
phase commit — no working-tree rollback needed.

If a genuine working-tree rollback of uncommitted work becomes necessary, take a durable
non-reverting checkpoint first (`bash .claude/scripts/git-snapshot.sh 287 --no-revert`) and then
follow `context/contracts/recovery.md`'s rollback rung for the exact reverting invocation,
including its `--allow-out-of-scope` override for the deliberate whole-tree case.

Partial-completion fallbacks, in increasing order of retreat:

- Phase 3 or 4 blocked: Phases 1-2 are independently green and shippable; the rule is live and
  documented, only its fixture coverage is outstanding. Record the gap explicitly rather than
  weakening an assertion to pass.
- Case (iv)'s live half unreachable (stubs not reusable, live path too costly to fixture): keep
  the dry-run half, and substitute a structural argument in the summary — the single shared
  bucketing loop is the only producer of this deferred row, so parity holds by construction.
  State the substitution; do not report Case (iv) as passed.
- Phase 2 blocked: revert Phase 1's commit. The rename/hoist has no standalone value and leaves a
  reader wondering why the block moved.
