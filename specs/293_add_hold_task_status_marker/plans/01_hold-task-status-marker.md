# Implementation Plan: Task #293

- **Task**: 293 - Add a HOLD task status marker that pauses a task and excludes it from dispatch
- **Status**: [IMPLEMENTING]
- **Effort**: 10.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/293_add_hold_task_status_marker/reports/01_hold-task-status-marker.md
- **Artifacts**: plans/01_hold-task-status-marker.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  shell-strict-mode.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add `hold` as a 13th value to the closed task-status enum so an operator can pause a task:
excluded from `/orchestrate` wave dispatch and from single-command gate-in, with all artifacts
preserved and `/todo` never archiving it. Three new per-task state fields (`hold_reason`,
`held_at`, `prior_status`) make the hold informative and reversible. The edit target throughout is
the **source store** `agent-system/extensions/core/` — never `.claude/**`, which is a disposable
deploy tree (`rules/source-store-deploy-boundary.md`). Definition of done: the live consumer
repository `/home/benjamin/Projects/Logos/Verification` validates with 0 FAILs and regenerates
`TODO.md` with `[HOLD]` markers; a held task shows in `blocked[]` and dispatches nothing; an
explicit `--implement` against a held task is admitted and leaves `status == "hold"`.

### Research Integration

The research report verified every factual claim in the dispatch against the actual source-store
files and the live consumer repo, and resolved all seven decisions ahead of planning. This plan
implements those decisions verbatim; none are re-opened. Key integrations:

- **Decision 1**: `orchestrate-triage-classify.sh` gets a dedicated `group:"hold"` verdict — not a
  reuse of `needs_human` (connotes an error state needing triage) nor `skip` (whose existing reason
  text says "transitional/unknown", which would misdescribe a deliberately-set status).
- **Decision 2**: `orchestrate-cycle-plan.sh`'s bucketing switch gets a `hold)` arm mirroring the
  existing `forced_round_complete)` arm (≈line 1838): push a reasoned `blocked[]` row via
  `out_blocked_rows+=(...)` and `continue` **before** the lock probe, dispatch_seq mint, status
  write, and cycle charge.
- **Decision 3**: `is_terminal_status()` (≈line 1459) stays a 3-case function. Widening it would
  let `/todo` archive held tasks and would let a held dependency wrongly satisfy a dependent task's
  completion-discharge check.
- **Decision 4**: the forcing-flag override is wired at `/orchestrate`'s STAGE 0 only.
  `command-gate-in.sh` gets **no** override — it has no forcing-flag plumbing at all, so a held
  task simply ABORTs on every single-command entry point. Research further confirmed that
  `task_has_forced_phase()` (≈line 1483) and the `effective_group` precedence (≈lines 1679-1702)
  **already** let a forced phase override a status-derived verdict with zero changes, because the
  forced-phase resolution happens before `triage_group[$t]` is consulted.
- **Decision 5**: the lift surface is a new `target_status=unhold` on `update-task-status.sh`,
  operation `preflight`. Its `STATE_STATUS` is **dynamic** (read from the task's own `prior_status`,
  validated via `status_vocabulary_is_valid` before use) — architecturally unlike every other
  `map_status()` arm, whose targets are fixed literals.
- **Decision 6**: a held subtask **continues to block** its parent `[EXPANDED]` task's archival
  (reading (a), unchanged behavior). The mitigation is a reporting improvement, not a logic change.
- **Decision 7**: `generate-todo.sh`'s `active_count`/`terminal_count` split is left unmodified —
  `hold` correctly falls to `active_count` via the existing `*)` catch-all.

Research also flagged, explicitly **out of scope** for this task: the existing
`completed|abandoned|expanded)` arm in `commands/orchestrate.md` STAGE 0 does *not* check
`$FORCE_PHASES_FLAG`, so that file's own documented claim that a forcing flag admits a terminal
task appears honored only in the `--dry-run` path. Phase 5 must NOT copy that arm's
unconditional-skip shape, and must NOT fix the terminal-side gap.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no roadmap phases are included.

### Planning-Time Discovery Beyond the Report

Re-deriving line numbers before planning surfaced one scope item the report did not enumerate: the
prose string `"12-value"` / `"12 values"` / `"closed 12"` appears in **11 files, 14 occurrences**,
not only in `status-vocabulary.sh` and `test-status-vocabulary.sh`. Several are
cross-reference comments in unrelated scripts that deliberately disambiguate the task-level enum
from the narrower `.return-meta.json` enum (e.g. `return-meta-status-vocabulary.sh`,
`validate-return-meta.sh`, `lint-agent-contracts.sh`, `orchestrate-recover-outcome.sh`). Leaving
them stale would make those disambiguating comments silently wrong. Phase 7 owns this sweep; it
carries a Scope Hypothesis because the count is a hypothesis, not a fact.

A second small correction: `validate-state.sh`'s `KNOWN_ENTRY_FIELDS` array holds **20** names
(re-counted at lines 461-465), not the 17 the report states. The edit is unaffected — three names
are appended either way.

## Goals & Non-Goals

**Goals**:
- `hold` is a legal 13th member of the closed task-status enum and its schema twin, rendering as
  `[HOLD]` in `TODO.md`, with `hold_reason` / `held_at` / `prior_status` accepted by both
  validators.
- A held task is never dispatched by `/orchestrate`'s default status-derived routing, and is
  visibly reported in `blocked[]` with its own `hold_reason`.
- A held task ABORTs at `command-gate-in.sh` for `/research`, `/plan`, `/implement`, with the
  existing `revise` exemption preserved and the guard ahead of lock acquisition.
- An explicit `/orchestrate N --research|--plan|--implement` admits a held task for exactly one
  dispatch and leaves `status == "hold"` afterward.
- A hold is settable by an operator (`preflight:hold`) and liftable (`preflight:unhold`), with
  `prior_status` restored and the three fields removed on lift.
- `/todo` never archives a held task, and the held-subtask blocking question is resolved
  explicitly and identically in both duplicated code sites.
- `[HOLD]` is documented as a third status category: non-terminal yet non-dispatchable.

**Non-Goals**:
- No migration of the consumer repo's pre-existing hand-written `hold` values — they are valid
  input the moment Phase 1 lands.
- No widening of `is_terminal_status()`.
- No change to the held-subtask blocking *logic* (Decision 6 resolves it as correct as-is).
- No change to `generate-todo.sh`'s `active_count`/`terminal_count` behavior (Decision 7).
- No fix to the pre-existing terminal-task-plus-forcing-flag gap in `commands/orchestrate.md`
  STAGE 0 (flagged out of scope by research).
- No hand-authored edits under `.claude/**`; no redeploy as a substitute for a source-store edit.
- No new `context/patterns/status-lifecycle-exceptions.md` file (research named this as a
  speculative future gap, not this task's work).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `is_terminal_status()` widened to include `hold`, letting `/todo` archive held tasks and letting a held dependency discharge a dependent's completion check | H | M | Decision 3 is restated in Phase 2's tasks; Phase 2 adds an explicit test asserting `is_terminal_status hold` returns 1 (false) |
| The `hold` group falls into `orchestrate-cycle-plan.sh`'s `skip\|terminal\|exit_partial\|"")` arm (≈line 1853) instead of its own, producing no `blocked[]` row at all — silently failing the acceptance criterion | H | M | Phase 2 adds the `hold)` arm explicitly and Phase 8 asserts the row is present with real `hold_reason` text, not just that no dispatch happened |
| The new `commands/orchestrate.md` STAGE 0 `hold` arm is written by copying the adjacent terminal arm, inheriting its "never checks `$FORCE_PHASES_FLAG`" gap — making the decided override simply not work in the live path | H | M | Phase 5 branches on `$FORCE_PHASES_FLAG` directly; Phase 8's acceptance includes a **live, non-`--dry-run`** `--implement` against a held task |
| The `unhold` arm's dynamic `STATE_STATUS` skips the `status_vocabulary_is_valid` revalidation every other `map_status()` arm gets for free from its closed `case` | H | M | Phase 3 tests both a valid-`prior_status` lift (restores exactly) and a missing/corrupt-`prior_status` lift (fails loudly, never falls back to `not_started`) |
| The two near-byte-identical subtask-blocking blocks (`skills/skill-todo/SKILL.md`, `commands/todo.md`) drift — one patched, one missed | M | M | Phase 4 treats them as one "both files, same change" item and diffs the two blocks after editing |
| Stale `"12-value"` prose leaves disambiguating cross-reference comments in unrelated scripts factually wrong | M | H | Phase 7's sweep, driven by a fresh `grep` rather than the enumerated list |
| A sibling task editing the same working tree this cycle | M | L | Sibling task 292's declared scope is `commands/task.md` and `context/patterns/batch-orchestration-guardrails.md` — disjoint from every file below. Re-read each file immediately before editing; stage explicit file lists only, never a directory or glob pathspec |
| The live consumer repo's held-task set changes mid-implementation (another active session) | M | M | Phase 8 re-runs the live discovery `jq` before asserting the 9-task acceptance criterion, and reports the actual set rather than the researched one |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 2 |
| 4 | 6, 7 | 1, 2, 3, 4, 5 |
| 5 | 8 | 1-7 |

Phases within the same wave can execute in parallel. Wave-2 and wave-4 parallel sets were checked
for file-set disjointness: no file below appears in two phases of the same wave.

All paths below are relative to `agent-system/extensions/core/` unless stated otherwise. Every
line number is a pointer to re-derive with `grep` immediately before editing, never a fact to
trust.

---

### Phase 1: Enum, Schema Twin, and the Three-Field Allowlist [COMPLETED]

**Goal**: `hold` validates and renders. This phase alone un-breaks the consumer repo's
`generate-todo.sh` and clears all 12 of its `validate-state.sh` FAILs.

**Tasks**:
- [x] `scripts/lib/status-vocabulary.sh`: add `"hold"` to `STATUS_VOCABULARY_ENUM` (12 -> 13
      values) and `["hold"]="HOLD"` to `STATUS_VOCABULARY_TODO_MARKER_MAP`. Update this file's own
      "closed 12-value" prose (header ≈line 6, section banner ≈line 34) to 13.
- [x] Leave `STATUS_VOCABULARY_LIFECYCLE_RANK` (≈lines 105-114) **unchanged**: it deliberately
      omits `blocked`/`partial`/`abandoned`/`expanded` as non-linear states, and `hold` belongs in
      that same omitted set. Add a one-line comment saying so, so a future reader does not read the
      omission as an oversight.
- [x] `context/schemas/state-schema.json`: add `"hold"` to `definitions.taskStatus.enum`, keeping
      literal element ORDER aligned with the bash array so a manual diff of the pair stays trivial.
- [x] `context/schemas/state-schema.json`: add `hold_reason`, `held_at`, `prior_status` to
      `definitions.projectEntry.properties` as typed `string` properties with doc comments
      following the `completion_summary` precedent ("Required when status is `hold`;
      schema-optional here since only held entries carry it"). `additionalProperties: false` means
      an unlisted field is rejected outright.
- [x] `scripts/validate-state.sh`: append the same three names to `KNOWN_ENTRY_FIELDS`
      (≈lines 461-465). No status arm is needed here — Check 5 calls
      `status_vocabulary_is_valid` directly and is fixed transitively by the library edit.
- [x] `scripts/tests/test-status-vocabulary.sh`: bump the drift assertion from 12 to 13 (≈line
      107) and its pass/fail message text (≈lines 108, 110); add `hold` to the marker-map coverage
      so `[HOLD]` is asserted, not just counted.
- [x] `scripts/tests/test-validate-state.sh`: add coverage that an entry carrying `hold_reason`,
      `held_at`, and `prior_status` produces no unknown-entry-field FAIL, and that
      `status: "hold"` produces no off-schema-status FAIL.
- [x] Run `bash scripts/tests/test-status-vocabulary.sh` and
      `bash scripts/tests/test-validate-state.sh`; shellcheck both edited scripts.
- [x] Commit the declared file set as one atomic batch (see Commit Mode).

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: full

**Commit Mode**: atomic-batch

The declared batch is exactly these five files:
`scripts/lib/status-vocabulary.sh`, `context/schemas/state-schema.json`,
`scripts/validate-state.sh`, `scripts/tests/test-status-vocabulary.sh`,
`scripts/tests/test-validate-state.sh`. Intermediate per-file states are expected RED and MUST NOT
be committed: editing the bash enum without its schema twin makes `test-status-vocabulary.sh`'s
byte-equality diff fail by construction, and the consumer-repo un-breaking is genuinely
all-or-nothing (the enum alone still leaves 3 unknown-entry-field FAILs). The batch MUST NOT be
retroactively widened to absorb any later phase's file.

**Scope Hypothesis**: `KNOWN_ENTRY_FIELDS` is hypothesized to hold 20 names and
`definitions.projectEntry.properties` 20 keys, both with no pre-existing `hold*`/`prior_status`
entry. Confirm at implementation time with
`jq '.definitions.projectEntry.properties | keys | length' context/schemas/state-schema.json` and
by reading the array, before appending — if either already carries one of the three names, stop
and reconcile rather than duplicating.

**Files to modify**:
- `scripts/lib/status-vocabulary.sh` - enum entry, marker-map entry, 12 -> 13 prose, lifecycle-rank comment
- `context/schemas/state-schema.json` - `taskStatus.enum` entry; three `projectEntry.properties` entries
- `scripts/validate-state.sh` - three `KNOWN_ENTRY_FIELDS` names
- `scripts/tests/test-status-vocabulary.sh` - 13-value drift assertion, `[HOLD]` marker coverage
- `scripts/tests/test-validate-state.sh` - three-new-field and `hold`-status coverage

**Verification**:
- `bash scripts/tests/test-status-vocabulary.sh` passes, including the jq-extracted schema enum
  diffing byte-equal against the bash array as sorted sets.
- `bash scripts/tests/test-validate-state.sh` passes.
- Shellcheck clean per `context/standards/shell-strict-mode.md` on both edited `.sh` files.
- Consumer-repo smoke check (read-only until the deploy lands, then re-run): in
  `/home/benjamin/Projects/Logos/Verification`, `validate-state.sh` reports 0 FAILs and
  `generate-todo.sh` regenerates `TODO.md` with `[HOLD]` on every held task. This is the phase's
  acceptance bar, deferred to Phase 8 only if the deploy step is not available mid-phase.

---

### Phase 2: Exclude Held Tasks from `/orchestrate` Dispatch [COMPLETED]

**Goal**: a hold actually holds in the orchestrate engine. Phase 1 alone makes `hold` validate and
render, so the status *looks* supported while nothing yet prevents dispatch — do not stop between
the two.

**Tasks**:
- [x] `scripts/orchestrate-triage-classify.sh`: add a dedicated `hold` arm to the jq `if/elif`
      classification chain (which currently ends in a catch-all `else` at ≈lines 514-517 producing
      `group:"skip"` with reason `status "..." is transitional/unknown; skip` — exactly where a
      `hold` task falls today). Emit `group:"hold"` per Decision 1, with a reason string built from
      the task's own `hold_reason` field so the text is specific, not generic.
- [x] Add the corresponding `hold` row to the documented status -> group classification table in
      this file's header (≈lines 71-90), covering both engines as the existing rows do. State in
      that row's text *why* `hold` is its own group rather than `needs_human` or `skip`.
- [x] `scripts/orchestrate-cycle-plan.sh`: add a `hold)` arm to the bucketing
      `case "$g" in ...` switch (≈line 1831), mirroring the `forced_round_complete)` arm
      (≈lines 1838-1848) exactly: push a reasoned row via `out_blocked_rows+=(...)` naming the
      hold and its `hold_reason`, then `continue` **before** the lock probe, dispatch_seq mint,
      `skill_preflight_update`, and `orchestrate-build-dispatch.sh`. No lock touched, no dispatch
      file written, no status write, no cycle charge.
- [x] Confirm by reading the code that the `hold` group does NOT fall into the
      `skip|terminal|exit_partial|"")` arm (≈line 1853) — that arm `continue`s with no row and no
      reason, which would fail the acceptance criterion silently.
- [x] Leave `is_terminal_status()` (≈line 1459) **unchanged** at its three cases per Decision 3.
      Add a comment there stating that `hold` is deliberately excluded and why (archival; the
      dependency-discharge check).
- [x] Leave `task_has_forced_phase()` (≈line 1483) **unchanged** — research confirmed it is a pure
      function of CLI/state, independent of status, and already works for hold. Verify by reading
      the `effective_group` precedence (≈lines 1679-1702) that a forced phase is resolved before
      `triage_group[$t]` is consulted, so a forced round already overrides `group:"hold"` with no
      further change. Record the verification in the phase's commit message rather than adding
      redundant code.
- [x] Confirm a forced round does not clear the hold: no code path in this file writes `.status`
      for a forced dispatch beyond the normal preflight transition, so the hold's persistence is a
      property of Phase 3's `map_status()` work plus the absence of a clearing write here. Assert
      it in the test below, not by adding a guard.
- [x] `scripts/tests/test-orchestrate-triage-classify.sh`: assert a `hold`-status task classifies
      as `group:"hold"` with a reason containing its `hold_reason`, and is not `skip`/`needs_human`.
- [x] `scripts/tests/test-orchestrate-cycle-plan.sh`: assert a held task produces a `blocked[]` row
      naming the hold and no dispatch; assert `is_terminal_status hold` returns 1 (false).
- [x] Shellcheck both edited scripts.

**Timing**: 1.75 hours

**Depends on**: 1

**Verification Tier**: full

**Files to modify**:
- `scripts/orchestrate-triage-classify.sh` - header classification table row; jq `hold` arm
- `scripts/orchestrate-cycle-plan.sh` - `hold)` bucketing arm; two explanatory comments
- `scripts/tests/test-orchestrate-triage-classify.sh` - `group:"hold"` coverage
- `scripts/tests/test-orchestrate-cycle-plan.sh` - `blocked[]`-row and `is_terminal_status` coverage

**Verification**:
- `bash scripts/tests/test-orchestrate-triage-classify.sh` and
  `bash scripts/tests/test-orchestrate-cycle-plan.sh` pass.
- An `/orchestrate --dry-run` naming a held task shows it in `blocked[]` with its hold reason and
  dispatches nothing for it.
- `is_terminal_status hold` returns false (asserted by test, not by eyeball).
- Shellcheck clean on both edited scripts.

---

### Phase 3: Make the Hold Operator-Settable and Reversible [COMPLETED]

**Goal**: an operator can set a hold and lift it, through supported paths, with `prior_status`
making the lift exact.

**Tasks**:
- [x] `scripts/update-task-status.sh`: add `hold` and `unhold` to the `target_status` validation
      chain (≈line 211) and its error message (≈line 212), and to the usage text (≈line 202) and
      the header comment block (≈lines 15-18).
- [x] Add a `preflight:hold)` arm to `map_status()` (≈line 285) resolving
      `STATE_STATUS="hold"`, `TODO_STATUS="HOLD"`. **Extend** the existing comment above the
      `postflight:partial)`/`postflight:blocked)` arms — which explicitly reasons that there is
      deliberately no `preflight:partial`/`blocked`/`needs_research` because those are
      dispatch-outcome-derived — to state that `hold` is the first human-initiated status in this
      enum and therefore the deliberate exception to that pattern. Do not silently contradict it.
- [x] Add a `--hold-reason=<string>` CLI flag following the exact validation shape
      `--file-scope-add` / `--research-questions` already establish: a malformed value, or an
      absent value when `target_status == hold`, is a hard validation error, never a silent no-op.
- [x] Writing a hold must set, in the same atomic state write: `hold_reason` (from the flag),
      `held_at` (today's date, `YYYY-MM-DD`, reusing the same timestamp source the jq transform
      already uses for `last_updated` rather than a second `date` call), and `prior_status` (the
      task's CURRENT `.status`, read from state.json **before** the overwrite). Also emit the
      TODO.md `- **Held**: YYYY-MM-DD` line.
- [x] Implement the lift as `preflight:unhold` per Decision 5. Its `STATE_STATUS` is **not** a
      fixed literal: read `prior_status` from the task's entry at call time, validate it with
      `status_vocabulary_is_valid`, and only then use it as the write target. A missing, empty, or
      off-enum `prior_status` MUST fail loudly — never fall back to `not_started` or any other
      default. Because `map_status()`'s other arms are closed `case` literals, this needs a short
      preamble that resolves `prior_status` before (or in place of) the `map_status()` call; keep
      the post-`map_status()` enum backstop (≈lines 324-331) in force for the resolved value.
- [x] Clear the three fields on lift with `del(.hold_reason, .held_at, .prior_status)` in the jq
      transform — field omission, not nulling, matching this codebase's convention for
      present-only-in-one-state fields (`completion_summary`). Also remove the TODO.md
      `- **Held**:` line.
- [x] `scripts/tests/test-update-task-status.sh`: cover (a) `preflight:hold` sets all three fields
      and the `[HOLD]` marker, capturing `prior_status` from the real current status; (b)
      `preflight:hold` without `--hold-reason` fails loudly; (c) `preflight:unhold` with a valid
      `prior_status` restores it exactly and removes all three fields; (d) `preflight:unhold` with
      a missing or off-enum `prior_status` fails loudly and writes nothing.
- [x] Shellcheck the edited script.

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: full

**Files to modify**:
- `scripts/update-task-status.sh` - validation chain, usage, header comment, `preflight:hold` and `preflight:unhold` arms, `--hold-reason` flag, jq field writes and `del(...)`, extended postflight-only comment, and the hold-sticky guard (see deviation note below)
- `scripts/tests/test-update-task-status.sh` - the four set/lift cases above, plus a fifth (Case 16) covering the sticky guard
- `scripts/generate-todo.sh` *(deviation: added -- not in this phase's original files list)*: renders the `- **Held**: YYYY-MM-DD` line for a hold-status task, reading the new `held_at` field through the same positional-field pipeline `effort`/`topic` already use

**Deviation (scope addition, not a plan error)**: implementation surfaced a real gap the plan's
granular task list did not spell out: the rank-based `monotonic-max` clamp
(`skill-base.sh`/`orchestrate-cycle-plan.sh`) does NOT preserve `status == "hold"` across a
forced live dispatch, because `hold` is deliberately UNRANKED (Phase 1) -- `status_vocabulary_would_regress(hold,
implementing)` returns false ("no regression"), so that clamp alone lets an ordinary preflight
write overwrite `hold` -> `implementing`. The plan's own Phase 2 task list anticipated this
("the hold's persistence is a property of Phase 3's map_status() work"), so the fix landed here:
a hold-sticky guard in `update-task-status.sh` that, when the task's CURRENT status is already
`hold`, overrides `STATE_STATUS`/`TODO_STATUS` back to `hold`/`HOLD` for every operation except
`preflight:hold` (updating the reason) and `preflight:unhold` (the lift) -- making the status
write a true no-op while every other side effect (TODO.md regen, hooks, events) still runs. This
is the actual mechanism the Phase 5/8 "forced --implement preserves hold" acceptance criterion
depends on. Covered by Case 16 above.

**Verification**:
- `bash scripts/tests/test-update-task-status.sh` passes, including both loud-failure cases.
- A set-then-lift round trip on a scratch state.json returns the task to its exact original status
  with no residual `hold_reason`/`held_at`/`prior_status` keys (`jq 'has("hold_reason")'` is
  `false`).
- `bash scripts/validate-state.sh` reports 0 FAILs against the held scratch state.
- Shellcheck clean.

---

### Phase 4: `/todo` Archival Audit and the Held-Subtask Resolution [COMPLETED]

**Goal**: confirm (not assume) that held tasks are already never archived, apply Decision 6's
held-subtask resolution identically in both duplicated code sites, and leave notes where a future
reader will look.

**Tasks**:
- [x] `skills/skill-todo/SKILL.md`: VERIFY rather than guard — Stage 2 `ScanTasks` (≈lines 79-83)
      and the archive-write jq (≈lines 454-455) both POSITIVE-match only
      `completed`/`abandoned`/`expanded`, so a `hold` task is excluded from the archive set by
      construction at two independent points. Add no redundant guard. Record the verification as a
      short comment at the Stage 2 selector naming `hold` as excluded-by-construction.
- [x] Note in that same place that the dispatch's `~164-166` pointer actually names the Stage 2.5
      `TopicRevision` selector (a different, inverted-select mechanism for `topic` backfill), not
      the archival guard — so a future reader following that line number is not misled.
- [x] Apply Decision 6 to the `expanded)` arm's subtask-blocking loop (`skill-todo/SKILL.md`
      ≈lines 106-131; `commands/todo.md` ≈lines 163-190, the near-byte-identical duplicate): leave
      the `case "$subtask_status" in completed|abandoned|expanded) ;; *) ((blocking_count++)) ;;`
      pattern **unchanged** — a held subtask continues to block its parent's archival, because a
      hold is a pause and not a completion-equivalent.
- [x] Implement the Decision 6 mitigation in **both** files in lockstep: when a
      `blocking_count` increment is attributable specifically to a `hold` status, name it in the
      existing `deferred_expanded[]` reporting message so the operator reads "deferred because
      subtask N is held (reason: ...)" rather than a generic "still active" line with no actionable
      next step. Edit both files, then diff the two blocks to confirm they have not drifted.
- [x] `scripts/generate-todo.sh`: confirm `hold` falls to `active_count` via the existing `*)` arm
      (≈lines 454-455) and leave the split unmodified per Decision 7. Add a one-line comment at
      that `case` recording that this is intended (a held task is non-terminal, so counting it
      active is correct) so the omission is not re-litigated.
- [x] `commands/todo.md`: audit the `completed|abandoned|expanded)` arm at ≈line 184 for the same
      three-category problem Phase 5 fixes in `commands/orchestrate.md`. If it governs archival
      candidacy only (where hold is correctly excluded by construction), record that in a comment
      and change nothing; if it gates something a held task must reach, restructure it the way
      Phase 5 restructures orchestrate.md's and say so in the commit message.
- [x] Audit Stage 1.5 `ReconcileScan` (`skill-todo/SKILL.md` ≈lines 48-56): confirm its four
      positive-match statuses are exactly `researching`/`planning`/`implementing`/`partial` and
      that `hold` is absent, so reconciliation can never silently promote a task out of hold.
      Record the confirmation; add no code.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

Edits in this phase are confined to comments, markdown prose, and reporting-message text, with no
change to any `case` pattern or control flow — so a diff read-through confirming every changed hunk
lies inside a comment, string, or prose region is the in-phase bar. **Escalation clause**: if the
`commands/todo.md` ≈line 184 audit concludes a real behavior change is required, this phase's tier
escalates to `full` and the full gate set runs before it closes.

**Scope Hypothesis**: four claims are hypothesized and must each be confirmed by reading the code
before anything is written: (1) `skill-todo` Stage 2 and the archive-write jq both positive-match
exactly three statuses; (2) the subtask-blocking block is byte-identical between
`skill-todo/SKILL.md` and `commands/todo.md`; (3) `generate-todo.sh`'s count split is a 2-arm case
with a `*)` catch-all; (4) `ReconcileScan` selects exactly four statuses, none of them `hold`.
Confirm each with `grep -n`/`diff` and report any that does not hold rather than proceeding on the
assumption.

**Files to modify**:
- `skills/skill-todo/SKILL.md` - Stage 2 verification comment, dispatch-pointer correction note, deferred-parent hold-reason reporting, Stage 1.5 confirmation note
- `commands/todo.md` - the same deferred-parent reporting change; the ≈line 184 arm audit note
- `scripts/generate-todo.sh` - one comment recording the intended `active_count` placement

**Verification**:
- Diff read-through confirms no `case` pattern or control-flow hunk changed (Decision 6/7 are
  "leave unmodified" decisions).
- The two subtask-blocking blocks in `skill-todo/SKILL.md` and `commands/todo.md` remain
  equivalent after editing (confirmed by diffing the extracted blocks).
- A scratch `/todo --dry-run` against a state with a held subtask under an `[EXPANDED]` parent
  shows the parent deferred with a message naming the hold, and does not archive the held subtask.
- `bash scripts/generate-todo.sh` still succeeds and counts the held task as active.

---

### Phase 5: Hold Guard at Single-Command Gate-In and `/orchestrate` STAGE 0 [NOT STARTED]

**Goal**: close the single-command entry points, and restructure `/orchestrate` STAGE 0's
two-category arm into the three categories `[HOLD]` requires — with the decided forcing-flag
override actually working in the live (non-dry-run) path.

**Tasks**:
- [ ] `scripts/command-gate-in.sh`: add a `hold` arm inside the **same**
      `if [ "$operation" != "revise" ]` block that holds the terminal guard (≈lines 77-85),
      preserving the `revise` exemption (skill-reviser's contract is "no status-based ABORT
      rules") and keeping the guard **ahead of** the task-lock acquire (≈line 89) so held tasks
      fail fast without touching the lock. Emit a distinct ABORT message referencing `hold_reason`
      and naming the lift path (`update-task-status.sh preflight N unhold`), not a reuse of the
      terminal message.
- [ ] Add no forcing-flag override here, per Decision 4: this gate serves one bare `/research`,
      `/plan`, or `/implement N` and has no forcing-flag plumbing. A held task ABORTs here until
      lifted, or until routed through `/orchestrate N --research|--plan|--implement`, whose
      override is a different mechanism that never calls this guard. State this in the ABORT
      message so the operator's next step is unambiguous.
- [ ] `commands/orchestrate.md`: restructure the STAGE 0 `validated_tasks` loop's
      `case "$status" in completed|abandoned|expanded)` arm (≈line 169), which can only express
      "terminal". Add a third category: a `hold)` arm that branches on `$FORCE_PHASES_FLAG`
      directly (already populated at this point in the script — it is parsed earlier and referenced
      again at ≈lines 244/261). With a forcing flag: admit the task into `validated_tasks` and let
      `orchestrate-cycle-plan.sh`'s own `task_has_forced_phase`/`effective_group` machinery take
      over downstream. Without one: skip with a reason distinct from the terminal one (e.g.
      `"$task_num: held [$hold_reason]"`).
- [ ] Report held tasks **distinctly** from terminal ones in the `skipped_tasks` warnings, so an
      operator can tell a pause from a true terminal skip.
- [ ] Do NOT copy the existing terminal arm's unconditional-skip shape, and do NOT fix the
      adjacent pre-existing gap research flagged (that arm never checks `$FORCE_PHASES_FLAG`,
      apparently leaving its own documented forced-terminal-admission claim honored only in the
      `--dry-run` path). Record that gap as an out-of-scope observation in the phase commit
      message and in the Phase 8 summary so it is not lost.
- [ ] `scripts/tests/test-force-phases.sh`: assert that an explicit `--implement` against a held
      task **is** admitted through STAGE 0 and dispatched, and that `status` remains `"hold"`
      afterward; assert that the same task with no forcing flag is skipped with a hold-specific
      reason.
- [ ] Shellcheck `command-gate-in.sh` and any extracted bash in the edited command file.

**Timing**: 1.25 hours

**Depends on**: 2

**Verification Tier**: full

**Files to modify**:
- `scripts/command-gate-in.sh` - `hold` ABORT arm inside the non-revise block, ahead of the lock acquire
- `commands/orchestrate.md` - STAGE 0 three-category restructure; distinct `skipped_tasks` reporting
- `scripts/tests/test-force-phases.sh` - forced-admit-and-preserve-hold coverage

**Verification**:
- `bash scripts/tests/test-force-phases.sh` passes.
- A bare `/research`, `/plan`, and `/implement` against a held task each ABORT at gate-in with the
  hold-specific message, and `/revise` against the same task does not.
- The ABORT happens before the lock is acquired (confirmed by the absence of a lock file / the
  guard's position in the file).
- A live, **non-`--dry-run`** `/orchestrate N --implement` against a held task with a plan artifact
  dispatches, and `jq '.status'` on that task afterward is still `"hold"`.
- Shellcheck clean.

---

### Phase 6: Documentation and the Decision Record [NOT STARTED]

**Goal**: `[HOLD]` is documented as what it is — a third category, non-terminal yet
non-dispatchable — and the forcing-flag decision is recorded where a future reader will find it.

**Tasks**:
- [ ] `context/standards/status-markers.md`: add a new `#### [HOLD]` section placed beside
      `#### [PARTIAL]` and `#### [BLOCKED]` (≈lines 132-149, the two most directly analogous
      non-terminal exception states). State plainly that `[HOLD]` is non-terminal yet
      non-dispatchable — the property no existing marker has — and that `[BLOCKED]`'s documented
      "any command can run from this status" is exactly what `[HOLD]` does not permit.
- [ ] Add a Required Information block to that section listing `hold_reason`,
      `- **Held**: YYYY-MM-DD` (the TODO.md line), and `prior_status`, and note that unlike
      `[BLOCKED]`'s prose-only "Blocking Reason", these three are machine-checked schema fields.
- [ ] Add a `hold` / `[HOLD]` row to the TODO.md-vs-state.json mapping table (≈lines 272-285) and
      to the Command -> Status mapping table (≈lines 296-302), the latter naming
      `preflight:hold` / `preflight:unhold`.
- [ ] Update the Valid Transition Diagram (≈lines 345-369). Add `hold` as a **distinct annotation
      outside** the "Any Non-Terminal Status" box, not as a member of it: that box's whole premise
      is "/research, /plan, /implement all work from here", which is precisely false for `hold`.
      Document the two edges that exist — any non-terminal status -> `hold` (via
      `preflight:hold`), and `hold` -> `prior_status` (via `preflight:unhold`) — plus the
      single-dispatch forcing-flag override that does not change the status.
- [ ] `merge-sources/claudemd.md`: the status-marker list (≈lines 39-40) currently has exactly two
      categories, "Terminal states" and "Exception states (non-terminal; any command can resume
      from these)". `[HOLD]` fits NEITHER. Add a **third** bullet rather than straining either
      existing one — e.g. a "Paused state" category: non-terminal, but not resumable by any
      ordinary command; only an explicit `/orchestrate --research|--plan|--implement` override (for
      one dispatch, status preserved) or an operator-run lift.
- [ ] `context/reference/state-management-schema.md`: add three rows to the Project Entry Fields
      table (≈lines 76-93) following the "Documented-optional... present only after X" phrasing
      convention already used for `research_questions`. Add a short `### Hold Fields` subsection
      (mirroring `### Research Questions Field` at ≈line 278) narrating that `prior_status` is what
      makes the hold reversible — the field that distinguishes a hold from a one-way archival — and
      documenting the `preflight:unhold` lift surface chosen in Decision 5.
- [ ] Record the forcing-flag decision with its reasoning where a future reader will find it: in
      the new `#### [HOLD]` section of `status-markers.md`, state that an explicit forcing flag IS
      the human lifting the hold for exactly one dispatch, that the hold is preserved afterward,
      and that this reuses the existing `task_has_forced_phase` predicate rather than minting a
      second override concept. Cross-reference that `command-gate-in.sh` deliberately has no such
      override (Decision 4).
- [ ] Verify no task-number references appear in any of these deliverables
      (`rules/no-task-references-in-deliverables.md`) — all four files live outside `specs/**`.

**Timing**: 1.5 hours

**Depends on**: 1, 2, 3, 4, 5

**Verification Tier**: prose

**Files to modify**:
- `context/standards/status-markers.md` - `#### [HOLD]` section, Required Information block, two table rows, transition-diagram annotation, forcing-flag decision record
- `merge-sources/claudemd.md` - third status-marker category bullet
- `context/reference/state-management-schema.md` - three field-table rows, `### Hold Fields` subsection

**Verification**:
- Diff read-through confirms every changed hunk is prose/markdown with no executable surface.
- Every behavioral claim in the new prose matches the code landed in Phases 1-5 (read the prose
  against the code, not against this plan).
- `bash scripts/check-task-references.sh` (or the repo-wide lint equivalent) reports no new
  violations.
- Internal cross-references and links in the edited files resolve.

---

### Phase 7: The 13-Value Prose Sweep [NOT STARTED]

**Goal**: no stale `"12-value"` prose is left asserting a closed enum size that is no longer true —
including the cross-reference comments in unrelated scripts that deliberately disambiguate the
task-level enum from the narrower `.return-meta.json` enum.

**Tasks**:
- [ ] Re-derive the occurrence set with a fresh grep rather than trusting the enumerated list
      below: `grep -rn "12-value\|12 values\|closed 12" --include="*.sh" --include="*.md"
      --include="*.json" .` from `agent-system/extensions/core/`.
- [ ] Update each occurrence from 12 to 13, preserving each comment's surrounding intent. Expected
      sites (re-derive, do not trust): `index-entries.json`,
      `scripts/orchestrate-recover-outcome.sh`, `scripts/update-task-status.sh`,
      `scripts/generate-todo.sh` (two), `scripts/lint/lint-agent-contracts.sh`,
      `scripts/validate-return-meta.sh`, `scripts/lib/return-meta-status-vocabulary.sh`,
      `scripts/validate-state.sh` (two), plus any site Phase 1 did not already cover in
      `scripts/lib/status-vocabulary.sh` and `scripts/tests/test-status-vocabulary.sh`.
- [ ] Leave the **separate** 8-value `.return-meta.json` enum untouched: adding `hold` to the
      task-level enum does not change it, and `scripts/tests/test-return-meta-status-vocabulary.sh`
      asserts 8 (≈line 83). Confirm that test still passes and that `hold` is not wrongly admitted
      to the narrower enum.
- [ ] Shellcheck every edited `.sh` file; `jq .` the edited `index-entries.json` to confirm it
      still parses.

**Timing**: 0.5 hours

**Depends on**: 1, 2, 3, 4, 5

**Verification Tier**: prose

**Scope Hypothesis**: the sweep is hypothesized to cover **11 files and 14 occurrences** of
`"12-value"`/`"12 values"`/`"closed 12"` (measured at planning time). Confirm with the fresh grep
above before editing and again afterward — the post-edit grep for the 12-value forms must return
zero hits outside intentional historical prose, and a count that differs from 14 means the
hypothesis was wrong and the actual set governs, not this number.

**Files to modify**:
- The files the fresh grep returns; expected set named above (all comment/prose lines, plus one
  `index-entries.json` `summary` string)

**Verification**:
- Post-edit `grep -rn "12-value\|12 values\|closed 12"` returns zero hits (or only hits whose
  context makes 12 the correct historical number, each justified in the commit message).
- Diff read-through confirms every hunk is a comment, a markdown line, or a JSON `summary` string —
  no executable code changed.
- `bash scripts/tests/test-return-meta-status-vocabulary.sh` still passes with its 8-value
  assertion intact.
- `jq . index-entries.json` parses; shellcheck clean on every edited script.

---

### Phase 8: Full-Harness Verification and Live Consumer-Repo Acceptance [NOT STARTED]

**Goal**: the whole feature is green against the repository's own gates and against the live
consumer repository that motivated it.

**Tasks**:
- [ ] Run the full shell test harness and compare the result against
      `scripts/tests/known-failures.txt` rather than against zero — a pre-existing known failure is
      not a regression, and a new failure not in that file is.
- [ ] Shellcheck clean across every script touched in Phases 1-7, per
      `context/standards/shell-strict-mode.md`.
- [ ] Confirm the enum and its schema twin are byte-equal as sorted sets
      (`bash scripts/tests/test-status-vocabulary.sh` green, 13 values both sides).
- [ ] Deploy the source store so the consumer repo picks up the change
      (`bash .claude/scripts/deploy-headless.sh` in the consumer repo, or that repo's documented
      deploy path). Do NOT hand-patch anything under `.claude/**` as a substitute.
- [ ] **Re-run the live consumer-repo discovery before claiming completion**, exactly as the
      dispatch requires: `jq '[.active_projects[] | select(.status=="hold") | {project_number,
      hold_reason, held_at, prior_status}]' specs/state.json` in
      `/home/benjamin/Projects/Logos/Verification`. Another active session may have changed which
      tasks are held; report the actual set, not the researched one.
- [ ] In the consumer repo: `validate-state.sh` reports **0 FAILs** (down from 12), and
      `generate-todo.sh` regenerates `TODO.md` successfully with `[HOLD]` markers on every held
      task.
- [ ] In the consumer repo: an `/orchestrate --dry-run` naming a held task shows it in `blocked[]`
      with a hold reason and dispatches nothing for it.
- [ ] In the consumer repo or a scratch fixture: a live, non-`--dry-run` `--implement` against a
      held task with a plan artifact IS admitted, and `status` is still `"hold"` afterward.
- [ ] Confirm a set-then-lift round trip through `update-task-status.sh` restores the exact
      `prior_status` and leaves no residual hold fields.
- [ ] Confirm no task-number references were introduced in any deliverable outside `specs/**`.
- [ ] Record in the implementation summary: the Decision 6 resolution and its reasoning; the
      Decision 7 note; the out-of-scope terminal-plus-forcing-flag gap in `commands/orchestrate.md`
      STAGE 0; and the actual held-task set observed in the consumer repo at verification time.

**Timing**: 1 hour

**Depends on**: 1, 2, 3, 4, 5, 6, 7

**Verification Tier**: full

**Scope Hypothesis**: the consumer repo is hypothesized to hold 9 tasks (125, 126, 127, 128, 141,
142, 143, 162, 165) with 12 `validate-state.sh` FAILs before the fix. Confirm by re-running the
live `jq` and `validate-state.sh` immediately before asserting acceptance; a different set is the
real set, and the "0 FAILs / `[HOLD]` on every held task" bar applies to whatever that set is.

**Files to modify**:
- None (verification only). The implementation summary artifact is written by the implementing
  agent per its own contract.

**Verification**:
- Full harness result matches `known-failures.txt` with no new failures.
- Every acceptance bullet in the dispatch's VERIFICATION AND ACCEPTANCE section is checked off with
  observed output, not asserted from this plan.
- All consumer-repo checks run read-only where possible; any write there is limited to the
  documented deploy and to `generate-todo.sh`'s own regeneration.

---

## Testing & Validation

- [ ] `bash scripts/tests/test-status-vocabulary.sh` — 13-value drift assertion, `[HOLD]` marker
      map coverage, schema/library byte-equality as sorted sets
- [ ] `bash scripts/tests/test-validate-state.sh` — `status: "hold"` and the three new entry
      fields produce no FAILs
- [ ] `bash scripts/tests/test-orchestrate-triage-classify.sh` — a held task classifies as
      `group:"hold"` with a `hold_reason`-specific reason
- [ ] `bash scripts/tests/test-orchestrate-cycle-plan.sh` — a held task yields a `blocked[]` row
      and no dispatch; `is_terminal_status hold` is false
- [ ] `bash scripts/tests/test-force-phases.sh` — forced `--implement` admits a held task and
      leaves `status == "hold"`; unforced is skipped with a hold-specific reason
- [ ] `bash scripts/tests/test-update-task-status.sh` — set/lift round trip, missing
      `--hold-reason` fails loudly, missing/corrupt `prior_status` fails loudly
- [ ] `bash scripts/tests/test-return-meta-status-vocabulary.sh` — the separate 8-value enum is
      unchanged and does not admit `hold`
- [ ] Full shell harness compared against `scripts/tests/known-failures.txt`
- [ ] Shellcheck clean per `context/standards/shell-strict-mode.md` on every edited script
- [ ] `bash scripts/check-task-references.sh` — no new task-number references outside `specs/**`
- [ ] Consumer repo: `validate-state.sh` 0 FAILs; `generate-todo.sh` regenerates with `[HOLD]`;
      `/orchestrate --dry-run` shows `blocked[]` with a hold reason; live `--implement` admits and
      preserves the hold

## Artifacts & Outputs

- `specs/293_add_hold_task_status_marker/plans/01_hold-task-status-marker.md` (this plan)
- Source-store edits under `agent-system/extensions/core/`:
  - `scripts/lib/status-vocabulary.sh`, `context/schemas/state-schema.json`,
    `scripts/validate-state.sh`
  - `scripts/orchestrate-triage-classify.sh`, `scripts/orchestrate-cycle-plan.sh`
  - `scripts/update-task-status.sh`, `scripts/command-gate-in.sh`
  - `commands/orchestrate.md`, `commands/todo.md`, `skills/skill-todo/SKILL.md`,
    `scripts/generate-todo.sh`
  - `context/standards/status-markers.md`, `merge-sources/claudemd.md`,
    `context/reference/state-management-schema.md`
  - the Phase 7 prose-sweep set (`index-entries.json` and the scripts the fresh grep names)
- Test updates: `scripts/tests/test-status-vocabulary.sh`, `test-validate-state.sh`,
  `test-orchestrate-triage-classify.sh`, `test-orchestrate-cycle-plan.sh`, `test-force-phases.sh`,
  `test-update-task-status.sh`
- `specs/293_add_hold_task_status_marker/summaries/01_hold-task-status-marker-summary.md`
  (written at implementation completion), recording the Decision 6/7 resolutions, the out-of-scope
  gap, and the observed consumer-repo held-task set

## Rollback/Contingency

Each phase commits independently (Phase 1 as one declared atomic batch; the rest per green
sub-step), so reverting is a matter of `git revert` on the offending phase commit — no working-tree
discard is needed and none should be attempted. Phase 1 is deliberately standalone and valuable on
its own: if Phases 2-8 must be abandoned, Phase 1 alone leaves the consumer repo un-broken and the
system in a consistent state where `hold` validates and renders but is not yet enforced — a
strictly better position than today, and the only safe stopping point before Phase 2.

If a genuine working-tree rollback becomes necessary, take a snapshot first per
`context/contracts/recovery.md`'s rollback rung (including its out-of-scope override flag for a
deliberate whole-tree case) — never a bare default-mode `git-snapshot.sh` call as a precautionary
checkpoint. For a defensive checkpoint before risky work, use
`bash .claude/scripts/git-snapshot.sh 293 --no-revert`, which is durable and does not revert the
working tree.

Concurrency note: a sibling task is scheduled for dispatch this same `/orchestrate` cycle on this
shared working tree, with declared scope `commands/task.md` and
`context/patterns/batch-orchestration-guardrails.md` — disjoint from every file above. Re-read each
file immediately before editing it, stage explicit per-file lists only (never a directory or glob
pathspec), never run `git-snapshot.sh` in its reverting default mode, and STOP and report a foreign
commit or uncommitted modification rather than proceeding. See
`context/contracts/territory.md` (Cross-Task Territory section).
