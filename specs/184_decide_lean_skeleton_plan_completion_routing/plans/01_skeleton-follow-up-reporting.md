# Implementation Plan: Surface skeleton-plan follow-ups at completion under the batch engine

- **Task**: 184 - Surface skeleton-plan follow-ups at completion under the batch engine (ruled: port the sorry_inventory follow-up report, not pr_ready routing)
- **Status**: [IMPLEMENTING]
- **Effort**: 4.5 hours
- **Dependencies**: 242, 243 (both complete/archived — same postflight script/test and handoff-schema.md respectively; no live conflict)
- **Research Inputs**: specs/184_decide_lean_skeleton_plan_completion_routing/reports/01_skeleton-follow-up-routing.md
- **Artifacts**: plans/01_skeleton-follow-up-reporting.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The disposition is already ruled (2026-09-22): a strategic-sorry skeleton plan terminates at
`[COMPLETED]` through the ordinary completion-claim gate, and no `pr_ready`-routing branch is
ported. Only one capability was genuinely lost — the derivation and reporting of
`sorry_inventory[].follow_up_task` entries at completion — so this plan adds a report-only
mechanism to `orchestrate-cycle-postflight.sh`: strategic sorries from the final implement
handoff are printed to the cycle's stderr report, appended to the task's `completion_summary`,
and recorded on an append-only `skeleton_follow_ups` array on the task's `state.json` entry. No
task is ever auto-created; the report is the handoff and the user files follow-ups with `/task`.
Done when the new regression fixture passes and the three documentation files name the new
terminus and field.

### Research Integration

The research report (`reports/01_skeleton-follow-up-routing.md`) resolved every open mechanism
question and this plan adopts its decisions verbatim: field name `skeleton_follow_ups`; entry
shape = the `sorry_inventory` entry plus `recorded_cycle` and `session_id`; filter to
`strategic == true` only; hook point inside the `implemented)` case after
`skill_gate_completion_claim` passes; no `$hard_mode` gate (the `jq // ` defaults are already
harmless in base mode); `skill-base.sh` as the home for the new propagate helper; and
`test-handoff-reader-parity.sh` deliberately left untouched (its removed assertions covered the
deleted single-task engine).

It also flagged two files absent from the task's declared `file_scope` —
`agent-system/extensions/core/scripts/skill-base.sh` and
`agent-system/extensions/core/context/reference/state-management-schema.md`. Both are carried in
this plan's per-phase **Files to modify** lists, so `plan-file-scope-harvest.sh` picks them up at
plan postflight; no manual `file_scope` edit is required.

**One correction to the research report's Recommendation 1(b)**, confirmed by reading the script:
`recover_json` is assigned at `orchestrate-cycle-postflight.sh:677`, which sits inside the
`else` arm of the handoff-present/absent fork — i.e. it is set **only on the recovery path**. On
the handoff-present path (the only path a skeleton handoff can arrive by, since `sorry_inventory`
is a handoff-side field), `recover_json` is unset and
`skill_orchestrate_propagate_completion` is already called with an empty 5th argument, doing its
own `.return-meta.json` read internally. The augmentation therefore cannot simply "append to
`recover_json`" — Phase 2 must obtain the completion JSON itself (reusing a non-empty
`recover_json` when present, else one `orchestrate-recover-outcome.sh` read), augment it, and pass
the result as `precomputed_json`, which also preserves the single-read property the helper's
header documents.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided for this dispatch; ROADMAP.md was not consulted.

## Goals & Non-Goals

**Goals**:
- A skeleton=true final implement handoff with strategic `sorry_inventory` entries prints one
  greppable `SKELETON FOLLOW-UP:` stderr line per entry in the cycle report.
- Those entries are appended to an append-only `skeleton_follow_ups` array on the task's
  `state.json` entry, via `state-write.sh`.
- Those entries are surfaced in the task's `completion_summary` without changing
  `skill_orchestrate_propagate_completion`'s shared contract for any other caller.
- `status-markers.md`, `handoff-schema.md`, and `state-management-schema.md` state how a skeleton
  plan terminates now and document the new field.
- One regression fixture in `test-orchestrate-cycle-postflight.sh` covers the filter, the stderr
  report, the state write, the summary augmentation, and the unchanged completion transition.

**Non-Goals**:
- No auto-creation, drafting, or staging of follow-up tasks (closed by the ruling, clause iii).
- No port of the single-task engine's `pr_ready`/`--allow-pr-ready` routing branch; no change to
  `skill_gate_completion_claim`.
- No change to `orchestrate-cycle-plan.sh` (also a concurrent sibling's declared territory this
  cycle — deliberately untouched).
- No restoration of the removed `test-handoff-reader-parity.sh` assertions (dead-code coverage).
- No `/todo` archival-time surfacing of `skeleton_follow_ups` (recorded by research as a future
  task; outside the ruling's SCOPE line).
- No change to the handoff-writer side (`wrap-up.md`, `anti-analysis.md`, `recovery.md`) — the
  `sorry_inventory` schema and strategic test are already correct and unchanged.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Augmenting the completion JSON diverges from `skill_orchestrate_propagate_completion`'s shared contract | M | L | Keep the augmentation entirely inside the `implemented)` case as a local copy; never edit the shared helper |
| `handoff` is unset on the recovery path, so a `jq` read of it errors or mis-defaults | M | M | Read via `"${handoff:-null}"` with `2>/dev/null` and a shell-side fallback, the idiom already used by the `partial)` case's `partial_blocker_count` read |
| An empty agent-written `completion_summary` becomes non-empty after augmentation, silently suppressing the helper's existing "empty completion_summary" WARNING | L | M | Capture pre-augmentation emptiness in the skeleton branch and emit an equivalent named notice there, so the signal is not lost |
| Follow-up prose containing quotes/newlines breaks the state or summary write | M | L | Build every value with `jq --arg`/`--argjson` only; never shell-interpolate into a filter |
| Source-store/deploy boundary: edits land in `.claude/**` and are wiped by the next regeneration | H | L | All edits go to `agent-system/extensions/core/...`; the test suite runs against the source store directly, so no deploy is needed to verify |
| A sibling task edits a shared file mid-cycle | M | L | No file in this plan overlaps a declared concurrent sibling scope; still re-read each file immediately before editing and stage only this task's hunks |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Add `skill_propagate_skeleton_follow_ups` to skill-base.sh [COMPLETED]

**Goal**: A mutex-guarded, append-only writer for the new `skeleton_follow_ups` field exists in
the same place every other propagate helper lives.

**Tasks**:
- [x] Re-read `skill_propagate_memory_candidates` (the "Stage 7a" block) immediately before
      editing, and add the new function directly after it.
- [x] Signature: `skill_propagate_skeleton_follow_ups <task_number> <follow_ups_json> [session_id]`,
      with `session_id` self-generated via `common_session_id` when omitted (mirroring
      `skill_propagate_memory_candidates`'s 3rd-arg handling).
- [x] Guard: write only when `follow_ups_json` is non-empty and not the literal `[]`.
- [x] Write through `"${SKILL_REPO_ROOT}/.claude/scripts/state-write.sh"` with the append filter
      `(.active_projects[] | select(.project_number == $num)).skeleton_follow_ups =
      ((.active_projects[] | select(.project_number == $num)).skeleton_follow_ups // []) + $new_follow_ups`,
      passing `--argjson num` and `--argjson new_follow_ups`; never a hand-rolled
      `jq ... > tmp && mv` sequence.
- [x] On failure, emit the same non-blocking `WARNING: state-write.sh failed to write
      skeleton_follow_ups (non-blocking)` shape and return success.
- [x] Header comment states: append-only semantics, why this is a separate function from
      `skill_propagate_memory_candidates` and `skill_propagate_completion_summary` (different
      fields, never folded together), and that it is report-only — it creates no tasks.
- [x] `bash -n` the file.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/skill-base.sh` - add `skill_propagate_skeleton_follow_ups` after `skill_propagate_memory_candidates`

**Verification**:
- `bash -n agent-system/extensions/core/scripts/skill-base.sh` exits 0.
- `declare -f skill_propagate_skeleton_follow_ups` resolves after sourcing the file in a scratch
  shell with `SKILL_REPO_ROOT` set.
- `bash agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh` reports no new
  violation.

---

### Phase 2: Skeleton detection, stderr report, state write, and summary augmentation in postflight [COMPLETED]

**Goal**: A skeleton completion surfaces its strategic sorries in all three channels (stderr,
`completion_summary`, `state.json`) without touching the completion-claim gate or the shared
propagate helper.

**Tasks**:
- [x] Re-read the `implemented)` case (the `skill_gate_completion_claim` success branch) before
      editing; confirm the hook point and the `recover_json` scoping noted in the Overview.
- [x] Inside the gate-passed branch, before the `is_live` fork, compute:
      `skeleton_flag=$(echo "${handoff:-null}" | jq -r '.skeleton // false' 2>/dev/null)` and
      `skeleton_follow_ups=$(echo "${handoff:-null}" | jq -c '[(.sorry_inventory // [])[] | select(.strategic == true)]' 2>/dev/null)`,
      each with a shell-side fallback (`false` / `[]`) so an unset `handoff` (recovery path) or a
      `jq` failure cannot leak an empty/garbage value into a later test.
- [x] Enrich each surviving entry with `recorded_cycle` (from `${cycle_count:-0}`) and
      `session_id` via a `jq --argjson`/`--arg` map; keep the original
      `{file, line, statement, strategic, assumption, why_deferred, follow_up_task}` fields verbatim.
- [x] Fire the branch only when `skeleton_flag = "true"` AND the enriched array is non-empty and
      not `[]`. Add a short comment recording that no `$hard_mode` gate is applied and why
      (base-mode handoffs never populate these fields, so the read is a no-op there — same
      posture as the unconditional `phases_completed`/`phases_total` reads).
- [x] stderr report (runs in both live and dry-run — it is read-only): one line per entry,
      `${notice_prefix} SKELETON FOLLOW-UP: {file}:{line} — {assumption} (owner: {follow_up_task})`,
      iterated over `jq -r` output with a `while IFS= read -r` loop (never a word-split `for`).
- [x] Under `is_live` only: resolve the completion JSON once — reuse `recover_json` when non-empty,
      otherwise one `bash "${SCRIPT_DIR}/orchestrate-recover-outcome.sh" "$TASK_DIR"
      "$dispatch_start_ts" "$expected_dispatch_seq"` read (the `SCRIPT_DIR`-qualified form used at
      line 677, not a bare relative path), defaulting to `{}` via a separate
      `[ -z ... ] && x='{}'` assignment, never the `${x:-{}}` idiom the helper's own header warns
      about.
- [x] Append a `Skeleton follow-ups (not auto-filed; file with /task):` block — one
      `- {file}:{line} — {assumption} (owner: {follow_up_task})` bullet per entry — to that JSON's
      `.completion_summary` with `jq --arg`; on any `jq` failure fall back to the unaugmented JSON
      rather than passing a corrupted blob.
- [x] Pass the augmented JSON as `skill_orchestrate_propagate_completion`'s 5th
      (`precomputed_json`) argument in place of `"${recover_json:-}"` on this branch only; leave
      the non-skeleton call site byte-for-byte unchanged. *(deviation: altered — implemented as
      two separate call sites in an if/else on `skeleton_active` rather than one shared
      `completion_precomputed_json` variable, so the non-skeleton call's own two-line statement
      is textually identical to before, but its indentation shifted by 2 spaces because it is now
      nested one level deeper; arguments and behavior are unchanged)*
- [x] When the pre-augmentation `.completion_summary` was empty, emit a named
      `${notice_prefix} WARNING: ...` line from the skeleton branch so the helper's suppressed
      empty-summary warning is not silently lost.
- [x] Call `skill_propagate_skeleton_follow_ups "$task_number" "$enriched_json" "$session_id"`
      under `is_live`; print a `[dry-run] would record N skeleton follow-up(s)` line otherwise.
- [x] `bash -n` the file.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: the hook point is the `implemented)` case's `skill_gate_completion_claim`
success branch and `recover_json` is empty there (set only in the handoff-absent `else` arm).
Confirm at implementation time with `grep -n 'recover_json=' agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`
(expect exactly one assignment, inside the recovery arm) and by re-reading the `implemented)`
branch; if either differs, adjust the mechanism and record the deviation in the summary rather
than forcing the planned shape.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - skeleton detection, stderr report, completion-summary augmentation, and the new propagate call inside the `implemented)` gate-passed branch

**Verification**:
- `bash -n agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` exits 0.
- The existing suite still passes unchanged:
  `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` (0 FAIL).
- `grep -c 'skill_orchestrate_propagate_completion' orchestrate-cycle-postflight.sh` shows the
  non-skeleton call site still present and unmodified in `git diff`.
- `bash agent-system/extensions/core/scripts/lint/lint-json-channel-discipline.sh` reports no new
  violation (every added line goes to stderr, none to the fd-3 JSON channel).

---

### Phase 3: Regression fixture in test-orchestrate-cycle-postflight.sh [COMPLETED]

**Goal**: A skeleton=true fixture with a two-entry `sorry_inventory` proves the filter, all three
report channels, and the unchanged completion transition.

**Tasks**:
- [x] Re-read the suite's `setup_sandbox` / `write_state` / `commit_fixture` / `run_sut` helpers
      and one trusted-handoff fixture before writing the new case.
- [x] Add one new acceptance case using a fresh synthetic candidate number (referred to as
      "candidate #N", never "task N", per the suite's own header note).
- [x] Fixture shape: a `state.json` entry at `status: "implementing"`; a `.return-meta.json`
      carrying `status: "implemented"`, the matching `dispatch_seq`, a summary artifact, and a
      non-empty `completion_data.completion_summary`; and a fresh, `dispatch_seq`-matching
      `.orchestrator-handoff.json` with `"status": "implemented"`, `phases_completed == phases_total`,
      `"skeleton": true`, and a two-entry `sorry_inventory` — one `strategic: true` with a non-null
      `follow_up_task`, one `strategic: false` with no `follow_up_task`.
- [x] Assert (a): stderr contains exactly one `SKELETON FOLLOW-UP` line (count it; the
      non-strategic entry is filtered out).
- [x] Assert (b): the task's `state.json` entry has a `skeleton_follow_ups` array of length 1 whose
      entry matches the strategic sorry and carries `recorded_cycle` and `session_id`.
- [x] Assert (c): `completion_summary` on the task entry contains the `Skeleton follow-ups` block
      and the strategic entry's `follow_up_task`.
- [x] Assert (d): the outcome is unchanged — `verdict=ok` and the task's `state.json` status is
      `completed` (the completion-claim gate is unaffected).
- [x] Add a short contrast assertion that a non-skeleton `implemented` fixture emits zero
      `SKELETON FOLLOW-UP` lines and no `skeleton_follow_ups` field.
- [x] Run the suite and confirm 0 FAIL.

**Timing**: 1.25 hours

**Depends on**: 2

**Verification Tier**: full

**Scope Hypothesis**: five assertions in one new case plus one contrast assertion. *(deviation:
altered — implemented as 6 assertions in the main case (1a's file:line naming split into its own
check; 1b's recorded_cycle/session_id split into its own check alongside the length-1 check) plus
3 contrast assertions (no stderr line; no skeleton_follow_ups field; verdict/status unchanged) —
more granular than the hypothesis anticipated, each pinning one independent failure mode rather
than bundling several into one combined check)*

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - new skeleton-follow-up acceptance case plus the non-skeleton contrast assertion

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` exits 0
  with 0 FAIL and the new `[PASS]` lines present.
- `bash agent-system/extensions/core/scripts/tests/test-handoff-reader-parity.sh` still passes
  unchanged (confirming the deliberate decision to leave it untouched costs nothing).

---

### Phase 4: Document the skeleton terminus and the new field [COMPLETED]

**Goal**: The three authoritative documents state how a skeleton plan terminates now, who reads
`skeleton`/`sorry_inventory`, and what `skeleton_follow_ups` is.

**Tasks**:
- [x] `handoff-schema.md`: in the `skeleton` and `sorry_inventory` field sections, amend the "Read
      only by the hard engine" sentences to also name
      `orchestrate-cycle-postflight.sh`'s skeleton-follow-up completion reporting (both engines;
      base-mode handoffs never populate these fields, so the read is a no-op there).
- [x] `status-markers.md`: add a short paragraph under `[COMPLETED]` stating that a strategic-sorry
      skeleton plan reaches `[COMPLETED]` through the ordinary completion-claim gate exactly like
      any other task — never through `[PR READY]` — and that its strategic `sorry_inventory`
      entries are surfaced in the cycle's stderr report, the task's `completion_summary`, and the
      `skeleton_follow_ups` array rather than auto-filed as tasks.
- [x] `state-management-schema.md`: add a `skeleton_follow_ups` row to the Completion Fields table
      and a `### Skeleton Follow-Ups Field` subsection styled on `### Memory Candidates Field` — a
      field table for `{file, line, statement, strategic, assumption, why_deferred,
      follow_up_task, recorded_cycle, session_id}` plus a **Lifecycle** block naming the Producer
      (`orchestrate-cycle-postflight.sh`'s `implemented)` case via
      `skill_propagate_skeleton_follow_ups`), the Consumer (the human, via `/task`), and the
      Semantics (append-only; never auto-filed; no archival consumer today).
- [x] Cite durable anchors only — no task-number references in any of these three files (they sit
      outside `specs/**`).
- [x] Keep every added line inside the repo's no-emoji convention.

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: prose

**Scope Hypothesis**: three files, one edit region each (the `skeleton`/`sorry_inventory` field
sections; the `[COMPLETED]` subsection; the Completion Fields table plus one new subsection).
Confirm by re-reading each region before editing; if a section has moved or already says part of
this, adapt rather than duplicating.

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - who reads `skeleton`/`sorry_inventory`
- `agent-system/extensions/core/context/standards/status-markers.md` - how a skeleton plan terminates under `[COMPLETED]`
- `agent-system/extensions/core/context/reference/state-management-schema.md` - `skeleton_follow_ups` field table and lifecycle

**Verification**:
- Diff read-through confirming every changed hunk is prose inside the named section.
- `bash agent-system/extensions/core/scripts/check-task-references.sh` (or the repo's equivalent
  invocation) reports no new occurrence in these three files.
- The field names in the docs match the implemented filter/writer exactly (grep the three
  documented field names against the Phase 1/2 diffs).

---

### Phase 5: Cross-cutting gate run and wrap-up [NOT STARTED]

**Goal**: The full gate set is green across code, test, and docs together, and the work is
committed with the task's own scoped hunks only.

**Tasks**:
- [ ] `bash -n` both edited shell files.
- [ ] Run the postflight suite and the handoff-reader-parity suite; confirm 0 FAIL.
- [ ] Run the three relevant lints: `lint-state-writer-boundary.sh`,
      `lint-json-channel-discipline.sh`, and the task-reference check.
- [ ] Re-read `git status --short` and `git diff --staged`; stage only this task's own files
      (explicit file list, never `git add -A`/`.`/a directory pathspec) and commit via
      `git-commit-scoped.sh`.
- [ ] Write the implementation summary recording: the `recover_json`-scoping correction to the
      research report's Recommendation 1(b), the empty-summary-warning interaction, and the two
      `file_scope` additions.

**Timing**: 0.5 hours

**Depends on**: 3, 4

**Verification Tier**: full

**Files to modify**:
- none planned (verification and wrap-up only; summary artifact is written under `specs/`)

**Verification**:
- All suites and lints above exit 0.
- `git log -1` shows the task-scoped commit with only this plan's files in it.

## Testing & Validation

- [ ] `bash -n` clean on `skill-base.sh` and `orchestrate-cycle-postflight.sh`.
- [ ] `test-orchestrate-cycle-postflight.sh` exits 0, 0 FAIL, including the new skeleton case's
      five assertions and the non-skeleton contrast assertion.
- [ ] `test-handoff-reader-parity.sh` unchanged and passing.
- [ ] `lint-state-writer-boundary.sh`, `lint-json-channel-discipline.sh`, and the task-reference
      check report no new violations.
- [ ] A non-skeleton `implemented` postflight produces byte-identical behavior to before (no
      stderr line, no `skeleton_follow_ups`, unmodified propagate call site).

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/skill-base.sh` — new `skill_propagate_skeleton_follow_ups`.
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — skeleton-follow-up
  reporting branch in the `implemented)` case.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — new
  regression case.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md`,
  `agent-system/extensions/core/context/standards/status-markers.md`,
  `agent-system/extensions/core/context/reference/state-management-schema.md` — documentation.
- `specs/184_decide_lean_skeleton_plan_completion_routing/summaries/01_*-summary.md` — execution
  summary.

## Rollback/Contingency

Every phase is a small, independently committed source-store edit, so rollback is `git revert` of
the phase commits — no working-tree-discarding operation is needed and none should be run. If a
defensive checkpoint is wanted before Phase 2 (the only phase editing live orchestration control
flow), use `bash .claude/scripts/git-snapshot.sh 184 --no-revert`, which is durable without
reverting the working tree; the bare reverting form belongs only to a genuine rollback
(see `context/contracts/recovery.md`'s rollback rung for that invocation shape). If Phase 2's
augmentation turns out to interact badly with `skill_orchestrate_propagate_completion`, the
narrower fallback is to keep the stderr report and the `skeleton_follow_ups` write (Phases 1 and
the first half of 2) and drop only the `completion_summary` augmentation, which still satisfies
the ruling's clause (ii) and most of (i); record that narrowing explicitly in the summary rather
than leaving it implicit.
