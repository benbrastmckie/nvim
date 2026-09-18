# Implementation Summary: Task #188

- **Task**: 188 - Fix orchestrate-predispatch-review.sh Class A false positive: archived completed dependencies reported as nonexistent
- **Status**: [COMPLETED]
- **Started**: 2026-09-17T00:00:00Z
- **Completed**: 2026-09-17T01:20:00Z
- **Effort**: ~2.75 hours
- **Dependencies**: None
- **Artifacts**: plans/01_archive-aware-dependency-classifier.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`orchestrate-predispatch-review.sh`'s Class A dependency-edge classifier resolved
`dependencies[]` targets against `active_projects[]` only, so any dependency that was completed
and then archived by `/todo` resolved to null and was reported as `"nonexistent"` — the loudest
verdict the classifier has — despite being satisfied. This implementation teaches Class A a
fifth bucket, `archived_satisfied`, adopted from the archive-aware pattern
`orchestrate-triage-classify.sh` already proves in this codebase (source `lib/task-lookup-lib.sh`,
stage the archive array via a `mktemp` tempfile read back with `--slurpfile`, never `--argjson`).
Report rendering demotes archived-satisfied edges to a separate, clearly-labeled informational
list rather than suppressing them. New test fixtures (3 scenarios, 7 new assertions) pin both
outcomes, and the guardrail documentation and SUT header comment were synced to the new
five-bucket vocabulary.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` — Phase 1: sourced
  `lib/task-lookup-lib.sh`; staged the flattened archive array via `mktemp` + `trap ... EXIT` +
  `--slurpfile archived_raw` (never `--argjson`, per the ~960KB ARG_MAX precedent already
  observed in `orchestrate-triage-classify.sh`); merged active + archived into `$all`
  (active-first, preserving `task_lookup_entry`'s active-wins contract); extended the Class A
  bucket decision to four branches, adding `archived_satisfied` ahead of the terminal-status
  check. Phase 2: split the Class A report section into a "Primary (live/terminal/nonexistent):"
  list and an "Archived (satisfied):" list, mirroring the existing Class C/D
  Deferred/Admitted two-part convention; both lists are unconditional (demotion, never
  suppression) with their own accurate "0 findings" negatives; updated the header comment's
  four-bucket enumeration to five.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh` — Phase 3:
  added `lib/task-lookup-lib.sh` to `setup_sandbox`'s copy list and `require_file` preflight;
  added a `write_archive_state` helper mirroring `write_state`; added three scenarios (5: archived
  dependency renders `archived_satisfied`, never `nonexistent`; 6: a genuinely absent dependency
  still renders `nonexistent`; 7: no `specs/archive/state.json` at all still exits 0 and renders
  Class A). 21 passed, 0 failed (up from 14 pre-existing).
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — Phase 4:
  Non-Negotiable 3's bucket enumeration updated from four to five buckets, and its "warning
  loudly ... for all three non-`intra_batch` subcases" clause corrected to reflect that
  `archived_satisfied` reports informationally, not loudly, since a satisfied edge is not a
  hazard. Scope statements (REVIEW-stage-only, Open Design Fork still open) preserved unchanged.
- `agent-system/extensions/core/index-entries.json` — auto-derived `line_count` sync for the
  guardrails doc (1014 -> 1018), a direct side effect of the Phase 4 edit.
- Regenerated (not committed, gitignored): `.claude/scripts/orchestrate-predispatch-review.sh`,
  `.claude/scripts/tests/test-orchestrate-predispatch-review.sh`,
  `.claude/context/patterns/batch-orchestration-guardrails.md` via Phase 5's `deploy-headless.sh`.

## Decisions

- Archive resolution order in the bucket branch: `archived_satisfied` is checked BEFORE the
  terminal-status check, since an archived entry's normalized status (completed/abandoned/
  expanded, per `task_lookup_archived_projects_json`) would otherwise also satisfy
  `is_terminal` and be misclassified as `out_of_batch_terminal`.
- Report rendering reuses the exact "Deferred: .../Admitted: ..." two-part convention Classes C
  and D already established, rather than inventing a new top-level section — keeps the report's
  visual grammar consistent.
- No new verdict was added for "completed but not yet archived" and neither
  `orchestrate-batch-admit.sh` nor `orchestrate-triage-classify.sh` was touched, per the plan's
  settled Non-Goals (research already confirmed neither needs correction).

## Plan Deviations

- **Phase 5, Task 5.1** altered: `deploy-headless.sh` returned exit 3 (`RESULT=landed_verify_red`)
  rather than the expected exit 0. The deploy itself landed cleanly (the source-vs-deployed diff
  is empty) and both acceptance checks plus the deployed test suite pass. The non-zero exit comes
  from `verify-deploy.sh` check 20 (`measure-eager-context.sh --check` + per-file ceilings),
  reporting the live eager-context-load total (65198 B) over its recorded baseline (64450 B) and
  `commands/orchestrate.md` over its configured ceiling (a pre-existing WARN, gate mode `warn`).
  Neither is caused by this task: `measure-eager-context.sh --check`'s own eager-file enumeration
  does not include `context/patterns/batch-orchestration-guardrails.md` (the only content file
  this task touches outside `scripts/`), and `git status --short` confirmed this task never
  touched `CLAUDE.md`, any `merge-sources/**` file, or any `rules/**` file — the three channels
  that sum to the reported total. This is pre-existing/concurrent drift in the orchestrator
  context budget, out of this task's scope, observed rather than fixed here.

## Verification

- Build: N/A (bash scripts; `bash -n` clean on all edited scripts)
- Tests: Passed — `test-orchestrate-predispatch-review.sh` 21/21, from both the source store and
  the deployed `.claude/` copy
- Files verified: Yes

## Impacts

- `/orchestrate`'s Class A pre-dispatch advisory no longer produces false-positive `nonexistent`
  findings for dependencies satisfied by an archived task — measured live in this repository: 24
  real archived-satisfied edges across the current `active_projects[]` set (including this task's
  own dependency on the now-archived #197), all previously reported as the loudest possible
  false-positive verdict.
- `context/patterns/batch-orchestration-guardrails.md`'s Non-Negotiable 3 now accurately
  describes the classifier's five-bucket behavior for any future reader relying on that
  guardrail narrative.

## Follow-ups

- The pre-existing eager-context-budget drift noted in Plan Deviations (baseline 64450 B vs. live
  65198 B, and `commands/orchestrate.md` over its ceiling) is unrelated to this task and was left
  unresolved; it may warrant its own task if the growth is not already tracked elsewhere.
- The guardrail doc's Open Design Fork (whether an out-of-batch-live/nonexistent predecessor
  should be excluded from live dispatch) remains open, unchanged by this task, as scoped.

## References

- Plan: `specs/188_predispatch_review_archived_dependency_false_positive/plans/01_archive-aware-dependency-classifier.md`
- Research: `specs/188_predispatch_review_archived_dependency_false_positive/reports/01_archived-dependency-false-positive.md`
- Edited: `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh`
- Edited: `agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh`
- Edited: `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
