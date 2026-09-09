# Implementation Summary: Task #197

- **Task**: 197 - Make `/orchestrate N --research`/`--plan`/`--implement` work on a terminal (and/or archived) task
- **Status**: [COMPLETED]
- **Started**: 2026-09-09T06:53:21-07:00
- **Completed**: 2026-09-09T09:45:00-07:00
- **Effort**: ~11 hours (9 phases)
- **Dependencies**: specs/196_research_first_default_unless_fast/ (COMPLETED)
- **Artifacts**: plans/01_forced-phase-terminal-archived-tasks.md
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, shell-script-testing.md, source-store-deploy-boundary.md

## Overview

`/orchestrate N --research`/`--plan`/`--implement` previously did nothing on a terminal
(completed/abandoned/expanded) task, whether still in `active_projects` or already moved to
`specs/archive/` by `/todo`. This plan closed the two named defects (an admission-ordering
defect in `orchestrate-cycle-plan.sh`, and an archive-blind classifier) plus three more
surfaced during research and planning (a hard terminal exit in `skill_validate_input`, an
absent preflight status-regression clamp, and archived-task directory path resolution),
behind one shared archive-aware lookup library (`scripts/lib/task-lookup-lib.sh`). All nine
phases are complete; the full gate set is green; the fix is verified live against this repo's
own real, full-scale production data (a real completed task and a real completed-and-archived
task), not only against small synthetic fixtures.

## What Changed

- `agent-system/extensions/core/scripts/lib/task-lookup-lib.sh` (new) — shared archive-aware
  task lookup: `task_lookup_entry`, `task_lookup_is_active`, `task_lookup_dir`,
  `task_lookup_archived_projects_json`.
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — forced-phase exemption from
  the two `is_terminal_status` `continue`s; preflight status-regression clamp; archive-aware
  task-directory resolution via the shared library.
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` — gained its own
  archive read (mirroring `lookup_project`'s shape) so the classifier and `cycle-plan` agree on
  an archived task's status instead of the classifier calling it nonexistent. Mid-Phase-9 fix:
  both jq call sites that consumed the flattened archive switched from an inline
  `--argjson archived "$archived_projects_json"` (which exceeds Linux's 128 KiB per-argument
  `MAX_ARG_STRLEN` against this repo's real ~1 MB archive, failing with "Argument list too
  long") to writing it to a `mktemp` temp file and reading it back via `--slurpfile
  archived_raw`.
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — archive-aware task
  directory resolution for dispatch-file writes.
- `agent-system/extensions/core/scripts/skill-base.sh` — `skill_validate_input` terminal bypass
  (`--allow-terminal`) for a forced dispatch; archive-absent status-write skip (a task no
  longer in `active_projects` gets no in-progress status write, since the archive is read-only).
- `agent-system/extensions/core/scripts/task-lock.sh` — archive-aware fix surfaced during Phase
  6 fixture work.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — Group 21 Cases
  A-E: active-terminal forced dispatch, archived-terminal forced dispatch, unforced-terminal
  `all_terminal` stop, LIVE no-regression round with the real `update-task-status.sh`, and
  `--force-phases implement` on a completed task.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` — four
  archive-lookup cases (archive-only, `orphan_archived` normalization, neither-store skip,
  both-stores active-wins) for both engines, plus a mid-Phase-9 Case 5: a synthetic 605,938-byte
  archive (2000 entries) reproducing the real "Argument list too long" failure, mutation-checked
  red pre-fix and green post-fix.
- `agent-system/extensions/core/commands/orchestrate.md` and
  `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — documented the
  posture for all three forcing flags on terminal and archived tasks.
- `agent-system/extensions/core/merge-sources/claudemd.md` — CLAUDE.md's `/orchestrate` row
  updated to describe the forced-phase/terminal/archived behavior.

## Decisions

- (a) Eligibility mechanism: an up-front "has a pending forced phase" predicate exempts exactly
  those tasks from the two `is_terminal_status` `continue`s; section (f) itself is not
  reordered.
- (b) A terminal task's status stays `completed` throughout a forced round, enforced by a new
  preflight-side clamp (the postflight clamp alone cannot cover it, since preflight already
  overwrites the comparator it would read).
- (c) `--implement` on a terminal task is permitted on the same terms as `--research`/`--plan`
  (documented, not gated) — it is the safest of the three on the status axis, since
  `postflight:implement` always resolves to `completed`.
- (d) The classifier gained its own archive read, mirroring `lookup_project`'s shape, per task
  196's precedent (routing logic lives in the classifier, not a caller post-adjustment).
- (e) The archive read is strictly read-only everywhere; `/todo`'s archive is never written or
  un-archived by this feature.

## Plan Deviations

- **Phase 9** (mid-phase, not a plan deviation from the original design but a real defect found
  and fixed during Phase 9's own live verification work): `orchestrate-triage-classify.sh`'s
  two `jq --argjson archived "$archived_projects_json"` call sites (added in Phase 5) failed
  with "Argument list too long" (exit 126) against this repo's real ~1 MB
  `specs/archive/state.json`, silently degrading every classifier invocation to the
  non-archive-aware inline fallback — meaning Phase 5's fix, though correct in shape and green
  against every small synthetic fixture, had never actually executed against this repo's real
  data. Fixed by switching both call sites to `--slurpfile` against a `mktemp` temp file. Added
  mutation-checked Case 5 fixture coverage (both engines) reproducing the failure at a
  comparable byte scale. Verified: `orchestrate-cycle-plan.sh`'s own sibling archive read
  (`task_lookup_entry`, via stdin piping rather than argv) was never affected by this class of
  bug.

## Verification

- Build: N/A (shell scripts, no build step)
- Tests:
  - `test-orchestrate-cycle-plan.sh`: 170 passed, 0 failed
  - `test-orchestrate-triage-classify.sh`: 57 passed, 0 failed
  - `test-orchestrate-cycle-postflight.sh`: 65 passed, 0 failed
  - `check-task-references.sh`: 0 unexempted occurrences across 4 trees
  - `shellcheck`: zero new findings on every modified shell file (only pre-existing info-level
    findings remain, verified via `git log -L` blame per finding)
- Files verified: Yes — `.claude/scripts/lib/task-lookup-lib.sh` confirmed present in the
  deployed tree after redeploy; `deploy-headless.sh` reports
  `RESULT=landed_verify_clean` (33 checks, 0 failures), run twice (before and after the
  mid-Phase-9 classifier fix)
- Live acceptance walk (isolated `/tmp` root mirroring this repo's real `specs/state.json`,
  `specs/archive/state.json`, and real task directories, running the deployed, unstubbed
  scripts — no production file touched):
  - Forced research on active-terminal task 189 (real, completed): dispatched, `force:true`,
    status stayed `completed`.
  - Forced research on archived-terminal task 137 (real, completed, in `specs/archive/`):
    dispatched into `specs/archive/137_.../.dispatch/1.md`, `archive/state.json` untouched.
  - Unforced `/orchestrate` on task 189: stopped with `all_terminal`, zero dispatch rows.
  - Deployed classifier resolves both real tasks directly (no ARG_MAX fallback warning),
    ~0.12s each, against the real ~1 MB archive.

## Impacts

- `/orchestrate N --research|--plan|--implement` now works on any terminal task, whether still
  active or already archived by `/todo`, without ever regressing its status or requiring
  un-archiving.
- The classifier's Phase 5 archive-awareness — previously silently non-functional at this
  repo's real scale — now actually executes, which also benefits task 196's research-first
  default routing (the classifier is a shared dependency) for any task that happens to be
  archived.
- The `--slurpfile`-over-`--argjson` pattern for large flattened archive payloads is now the
  precedent for any future jq call that needs to consume `task_lookup_archived_projects_json`'s
  output; the existing `task_lookup_entry` stdin-piping pattern remains the other safe
  precedent.

## Follow-ups

- `commands/orchestrate.md` is 17,755 bytes against a warn-mode 8,000-byte context-budget
  ceiling (`ORCHESTRATOR_BUDGET_GATE_MODE=warn`); this predates this task (it was already over
  budget at 16,557 bytes before Phase 8's documentation additions) and is out of this task's
  scope, but is flagged here since Phase 8 made it modestly larger. Trimming
  `commands/orchestrate.md` is a candidate for a future task before the gate is promoted from
  warn to hard.

## References

- `specs/197_forced_phase_on_terminal_and_archived_tasks/reports/01_forced-phase-terminal-archived-tasks.md`
- `specs/197_forced_phase_on_terminal_and_archived_tasks/plans/01_forced-phase-terminal-archived-tasks.md`
- `specs/197_forced_phase_on_terminal_and_archived_tasks/progress/phase-1-progress.json` through `phase-9-progress.json`
