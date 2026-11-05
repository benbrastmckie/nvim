# Implementation Summary: Task #425

- **Task**: 425 - State files dropped as file_scope excursions
- **Status**: [COMPLETED]
- **Started**: 2026-10-17T22:16:48Z
- **Completed**: 2026-10-17T23:03:38Z
- **Effort**: 2.25 hours
- **Dependencies**: None
- **Artifacts**: plans/01_state-files-excursion-allowlist.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`orchestrate-cycle-postflight.sh`'s WORK (h) containment predicate was comparing every
`.return-meta.json` `modified_files` entry against a task's own declared `file_scope`, with no
exemption for the two shared task-management state files (`specs/TODO.md`, `specs/state.json`)
the engine writes on behalf of every task. When a task reported either file in `modified_files`,
WORK (h) classified it as a genuine excursion, producing a false `ADVISORY` line, a false
`EXCURSION DROPPED` line, and an inflated `excursion_dropped_count`. This implementation adds a
third literal-path splice to WORK (h)'s `effective_file_scope_json` that allowlists both files,
mirroring the existing V10 allowlist already landed in `git-commit-scoped.sh` at a sibling,
non-subsuming containment site. Research confirmed the two files were never actually dropped
from the commit itself (a separate, pre-existing unconditional `stage_paths` carve-out in WORK
(i) already covers them) — the confirmed harm fixed here is the false diagnostic and inflated
counter, not commit-time data loss.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — added a guarded
  `effective_file_scope_json` splice allowlisting `specs/TODO.md` and `specs/state.json` inside
  WORK (h), with a rationale comment stating the admission criterion (engine-written on behalf
  of every task, never declarable in any task's own `file_scope`); added a one-line comment at
  WORK (i)'s `stage_paths` seed noting it remains an independent second layer.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — added one
  new fixture case (task 718) proving: zero `EXCURSION DROPPED`/`ADVISORY` lines for either
  state file when both appear in `modified_files`; exactly one such line for a genuine
  out-of-scope path in the same run; both state files present in the resulting commit; the
  genuine excursion absent from the commit and left dirty on disk; and the
  `excursion_dropped_count` summary line (`1 of 4`) counting only the genuine excursion.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — added a note to the
  "Three Containment sites, not one" section documenting site 1's new allowlist, its
  relationship to the pre-existing `stage_paths` carve-out, and that the "Site 1 is NOT subsumed
  by site 3" asymmetry is unchanged.
- Regenerated the `.claude/` deploy tree via `deploy-headless.sh`; confirmed all three deployed
  files are byte-identical to their source-store originals.

## Decisions

- The allowlist is deliberately literal (`"specs/TODO.md"`, `"specs/state.json"`), not derived
  from `$STATE_FILE`, matching the landed V10 precedent in `git-commit-scoped.sh` and avoiding
  untested complexity for a path no caller ever varies.
- WORK (i)'s unconditional `stage_paths` seed is left untouched and documented as an independent
  second layer — the fix is additive, not a replacement of the existing carve-out that already
  prevents commit-time loss today.

## Plan Deviations

- **Phase 2** (pre-fix reproduction check): performed by backing up the real source-store file
  to the scratchpad, disabling the new splice in place, running the suite directly, then
  restoring the original file (verified byte-identical via `md5sum` and a clean `git diff
  --stat`) — rather than redirecting the test harness at a separate scratch copy of the script.
  Same evidentiary result: the new fixture failed with the exact false-positive symptom against
  the disabled version and passed cleanly after restoration.
- **Phase 2** (test-authoring correction): the initial exactly-one-`EXCURSION DROPPED`-line
  assertion used `grep -c "EXCURSION DROPPED"`, which double-counted because the summary line's
  own parenthetical back-reference ("... see EXCURSION DROPPED lines above.") also contains that
  bare substring. Corrected to match the colon-terminated `"EXCURSION DROPPED:"` form that only
  the per-path line carries.
- **Phase 4** (verification tier): per the dispatch's Batch Gate Deferral directive (this task
  ran inside a multi-task `/orchestrate` batch cycle), the complete unscoped gate set
  (`bash .claude/scripts/verify-deploy.sh`, no `--skip-slow`, no `--only-gate`) was deferred to
  the batch stage rather than run independently. This phase instead discharged verification
  against a scoped invocation covering the files it touched: the targeted test suite
  (`run-all.sh --only test-orchestrate-cycle-postflight.sh`) against the deployed tree, and
  `verify-deploy.sh --skip-slow --only-gate 3,4` (doc-lint and task-reference lint), both green.
  The complete gate set still runs once for the whole batch invocation.
- **Phase 4** (verify-deploy.sh `TARGET`): the plan's verification line named the source-store
  subpath as the `TARGET_REPO` argument; the script resolves `TARGET_REPO/.claude`, so the
  project root was used instead (the source-store subpath has no `.claude` tree).

## Verification

- Build: N/A (bash scripts; `bash -n` clean on both edited shell files)
- Tests: Passed — `run-all.sh --only test-orchestrate-cycle-postflight.sh` green (274
  assertions, 0 failed) both against the source store and the deployed tree
- Files verified: Yes — all three changed files confirmed byte-identical between source store
  and deployed tree

## Impacts

- Future `/orchestrate` postflight cycles for any task that self-reports `specs/TODO.md` and/or
  `specs/state.json` in `modified_files` will no longer emit a false `ADVISORY` or `EXCURSION
  DROPPED` diagnostic for either file, and the `excursion_dropped_count` summary will count only
  genuine excursions. The drop-and-warn behavior for every other out-of-`file_scope` path is
  unchanged.

## Follow-ups

- None. The complete, unscoped gate set runs once at this `/orchestrate` batch invocation's
  conclusion stage and is attributed back to this task via its reported `modified_files`, per
  the dispatch's Batch Gate Deferral directive.

## References

- Plan: specs/425_state_files_dropped_as_file_scope_excursions/plans/01_state-files-excursion-allowlist.md
- Research: specs/425_state_files_dropped_as_file_scope_excursions/reports/01_state-files-excursion-predicate.md
- Dispatch: specs/425_state_files_dropped_as_file_scope_excursions/.dispatch/9.md
