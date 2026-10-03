# Implementation Summary: Surface skeleton-plan follow-ups at completion under the batch engine

- **Task**: 184 - Decide the disposition of the Lean/formal skeleton-plan completion routing lost
  with the single-task engine (ruled: port the sorry_inventory follow-up report only, not
  pr_ready routing)
- **Status**: [COMPLETED]
- **Started**: 2026-10-02
- **Completed**: 2026-10-02
- **Effort**: ~2 hours
- **Dependencies**: 242, 243 (both complete/archived)
- **Artifacts**: plans/01_skeleton-follow-up-reporting.md, reports/01_skeleton-follow-up-routing.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Implemented the ruled disposition: a strategic-sorry skeleton plan already reaches `[COMPLETED]`
through `orchestrate-cycle-postflight.sh`'s ordinary completion-claim gate under the batch engine
(`skill_gate_completion_claim`'s Case 2 unconditional allow, read straight from the handoff's own
`phases_completed`/`phases_total`); the only genuinely lost capability was reporting the
handoff's strategic `sorry_inventory[]` entries at completion. Added report-only surfacing across
all three channels named by the ruling — stderr, `completion_summary`, and a new append-only
`skeleton_follow_ups` state.json field — with zero auto-creation of follow-up tasks and zero
changes to `skill_gate_completion_claim` or the `pr_ready` routing path. All five plan phases are
complete; both the pre-existing and new regression assertions pass.

## What Changed

- `agent-system/extensions/core/scripts/skill-base.sh` — added
  `skill_propagate_skeleton_follow_ups`, a mutex-guarded, append-only writer for the new field,
  placed directly after `skill_propagate_memory_candidates` and following its exact conventions
  (session_id self-generation, `state-write.sh` routing, non-blocking failure warning).
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — inside the
  `implemented)` case's gate-passed branch: detects `handoff.skeleton == true` with a non-empty
  `strategic == true` filter over `sorry_inventory[]`, enriches surviving entries with
  `recorded_cycle`/`session_id`, prints one `SKELETON FOLLOW-UP:` stderr line per entry (both live
  and `--dry-run`), and — under `is_live` only — resolves the completion JSON once, appends a
  "Skeleton follow-ups (not auto-filed; file with /task):" block to its `completion_summary`,
  calls `skill_propagate_skeleton_follow_ups`, and passes the augmented JSON to
  `skill_orchestrate_propagate_completion` as `precomputed_json`. The non-skeleton call to that
  helper is a separate, untouched branch (see Plan Deviations).
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — two new
  fixtures (candidate #970: skeleton=true with a two-entry `sorry_inventory`, 6 assertions;
  candidate #971: non-skeleton contrast, 3 assertions), both on the handoff-present (trusted,
  matching `dispatch_seq`, fresh mtime) path, which no pre-existing fixture in this suite
  exercised for the `implemented)` success case (every existing fixture either stales/mismatches
  the handoff to test recovery, or uses the recovery path directly).
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — the `skeleton` and
  `sorry_inventory` field sections now name `orchestrate-cycle-postflight.sh`'s skeleton-follow-up
  reporting as an additional reader (both engines; a no-op on a base-mode handoff).
- `agent-system/extensions/core/context/standards/status-markers.md` — added a "Skeleton-plan
  terminus" paragraph under `[COMPLETED]` stating the plan's terminus and the three reporting
  channels.
- `agent-system/extensions/core/context/reference/state-management-schema.md` — added
  `skeleton_follow_ups` to the Completion Fields table and a "Skeleton Follow-Ups Field"
  subsection (field table + Lifecycle), styled on "Memory Candidates Field".

## Decisions

- Kept the non-skeleton and skeleton `skill_orchestrate_propagate_completion` calls as two
  separate call sites in an if/else, rather than one shared `precomputed_json` variable feeding a
  single call — see Plan Deviations.
- Used `while IFS= read -r ... done < <(jq -r ...)` for the stderr report (never a word-split
  `for`), matching the plan's own instruction and this script's established idiom elsewhere.
- Built the augmented `completion_summary`'s value via bash string concatenation passed to a
  single `jq --arg`, never shell-interpolated into the filter text itself, per the plan's Risks
  table mitigation for quote/newline-safety.

## Plan Deviations

- **Task 2 (item "Pass the augmented JSON as `skill_orchestrate_propagate_completion`'s 5th
  argument... leave the non-skeleton call site byte-for-byte unchanged")** altered: implemented
  as two separate call sites in an if/else on `skeleton_active`, rather than a single shared
  `completion_precomputed_json` variable feeding one call. The non-skeleton call's own two-line
  statement is textually identical to before (same arguments, same behavior) but its indentation
  shifted by 2 spaces because it is now nested one level deeper inside the new if/else. Chosen so
  the non-skeleton behavior is provably identical by construction (a separate, untouched branch)
  rather than merely equal by coincidence of variable assignment.
- **Task 3 (Scope Hypothesis "five assertions in one new case plus one contrast assertion")**
  altered: implemented as 6 assertions in the main case (the file:line-naming check and the
  recorded_cycle/session_id check were split out from their respective length/count checks) plus
  3 contrast assertions (no stderr line; no `skeleton_follow_ups` field; unchanged verdict/status)
  — more granular than the hypothesis anticipated, each pinning one independent failure mode.
- **One correction to the research report**, confirmed by reading the script directly (recorded
  in the plan's Overview before implementation began): `recover_json` is assigned only inside the
  handoff-absent/recovery `else` arm of `orchestrate-cycle-postflight.sh` (one assignment site).
  On the handoff-present path — the only path a skeleton handoff can arrive by, since
  `skeleton`/`sorry_inventory` are handoff-only fields — `recover_json` is reliably empty, so the
  augmentation could not simply "append to `recover_json`" as the research report's
  Recommendation 1(b) had suggested; Phase 2 instead resolves the completion JSON itself (one
  fresh `orchestrate-recover-outcome.sh` read) and passes the augmented result as
  `precomputed_json`, preserving that helper's documented single-read property.

## Verification

- Build: N/A (shell scripts; `bash -n` clean on both edited files)
- Tests: Passed — `test-orchestrate-cycle-postflight.sh`: 166 passed, 0 failed (157 pre-existing +
  9 new assertions across the two new fixtures); `test-handoff-reader-parity.sh`: 13 passed, 0
  failed (unchanged, left deliberately untouched per the ruling)
- Lints: `lint-state-writer-boundary.sh` 0 violations; `lint-json-channel-discipline.sh` 1
  violation, pre-existing in `agent-system/extensions/typst/scripts/chapter-quality-check.sh`,
  unrelated to and untouched by this task; `check-task-references.sh` 0 occurrences on all three
  documentation files
- Files verified: Yes — all six touched files exist and are non-empty; `file_scope` on the task
  entry already includes all six (confirmed via `plan-file-scope-harvest.sh` at plan postflight,
  per the plan's own Overview note)

## Impacts

- A strategic-sorry skeleton plan's completion no longer silently drops its tracked follow-up
  work: the strategic sorries are now visible in the cycle's stderr report, in the task's
  `completion_summary`, and in a durable, append-only `skeleton_follow_ups` array on the task's
  `state.json` entry, for the human to file with `/task` as they see fit.
- No change to any non-skeleton task's completion behavior, routing, or output — the added
  detection/reporting logic is entirely gated on `handoff.skeleton == true` with a non-empty
  strategic `sorry_inventory[]`, confirmed by the new contrast fixture (candidate #971) and by
  the full pre-existing suite remaining green.
- Closes the one permanent-loss deviation recorded without a follow-up in
  `specs/088_mode_gate_skill_orchestrate_multi_task_section/summaries/01_four-move-loop-rewrite-summary.md`.

## Follow-ups

- None required by this task's SCOPE. Two items the ruling explicitly left out of scope for a
  future task, if ever pursued: (a) `/todo` archival-time surfacing of `skeleton_follow_ups`
  (noted by the research report as a possible future task); (b) restoring the removed
  `test-handoff-reader-parity.sh` assertions for the deleted single-task engine (deliberately not
  done — dead-code coverage).

## References

- `specs/184_decide_lean_skeleton_plan_completion_routing/reports/01_skeleton-follow-up-routing.md`
- `specs/184_decide_lean_skeleton_plan_completion_routing/plans/01_skeleton-follow-up-reporting.md`
- `agent-system/extensions/core/context/standards/status-markers.md` (`[COMPLETED]` subsection)
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` (`skeleton`,
  `sorry_inventory` fields)
- `agent-system/extensions/core/context/reference/state-management-schema.md`
  ("Skeleton Follow-Ups Field" subsection)
