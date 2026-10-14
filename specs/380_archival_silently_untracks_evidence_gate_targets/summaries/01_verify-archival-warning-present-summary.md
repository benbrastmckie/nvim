# Implementation Summary: Task #380

- **Task**: 380 - Warn that archival un-tracks evidence-gate targets under the moved task directory
- **Status**: [COMPLETED]
- **Started**: 2026-10-14T15:24:06Z
- **Completed**: 2026-10-14T16:05:00Z
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_verify-archival-warning-present.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

This task asked for a warning beside the archival `mv` in two source-store files, stating that
moving a task directory into the gitignored `specs/archive/` un-tracks anything under it which an
external gate or document references. Research (`reports/01_warning-already-present.md`) found
that warning already present, committed, and deployed at both named sites — landed incidentally
in commit `7ffb3916658d795d617905b5ff612a11bb541bd7` under an unrelated task's accounting. This
phase re-verified both warnings at implementation time, confirmed zero drift since that commit,
and closes the task on that existing evidence rather than duplicating the warning.

## What Changed

- No files under `agent-system/extensions/core/**` were modified — this is the planned outcome,
  not an omission. A second warning beside an already-warned `mv` would be a duplicate.
- `specs/380_archival_silently_untracks_evidence_gate_targets/summaries/01_verify-archival-warning-present-summary.md` — created (this file).

## Evidence Trail

**Introducing commit**: `7ffb3916658d795d617905b5ff612a11bb541bd7` — "core: note that an archival
mv un-tracks every file under the moved task directory"

**Site 1** — `agent-system/extensions/core/context/patterns/task-abandon-mode.md`, directly under
the "Move task directory to archive" `mv` block (currently lines 69-73):

> Because `specs/archive/` is gitignored, this `mv` removes every file under the directory from
> version control (the files stay on disk locally and are absent from every fresh clone), so any
> guard that cites a file by its task-directory path -- the evidence-probe gate's `WIRED_REPO`
> form in `scripts/check-evidence-probes.sh` -- must be re-pointed, or the file promoted into
> `specs/evidence/`, before the task is archived.

**Site 2** — `agent-system/extensions/core/skills/skill-todo/SKILL.md`, immediately above its
`mv "$source_dir" "$target_dir"` line (currently lines 547-550):

> `# specs/archive/ is gitignored: this mv removes every file under the directory from`
> `# version control (still on disk locally, absent from every fresh clone), so any`
> `# guard citing a file by its task-directory path -- the evidence-probe gate's`
> `# WIRED_REPO form in scripts/check-evidence-probes.sh -- must be re-pointed, or the`
> `# file promoted into specs/evidence/, before the task is archived.`

**Drift check**: `git diff --stat -- agent-system/extensions/core/context/patterns/task-abandon-mode.md agent-system/extensions/core/skills/skill-todo/SKILL.md` returned empty.

**Last-touching commit check**: `git log --oneline -1 --` on both files reports `7ffb39166`,
matching the research-cited commit exactly.

**Acceptance check**: both warnings state the un-tracking consequence of the gitignored `mv` and
name a producer remedy (re-point the external reference, or promote the file to
`specs/evidence/`), satisfying the description's "re-point or force-track" instruction in
substance.

## Decisions

- Closed on existing evidence rather than adding a duplicate warning, per the plan's explicit
  non-goal and the source-store boundary rule (`rules/source-store-deploy-boundary.md`): the
  correct edit target for either file is the source store, never `.claude/**`, and no edit was
  needed here since the source-store copies already carry the warning.

## Plan Deviations

- **Phase 1, final verification step** (full gate set via `verify-deploy.sh`) — altered: the gate
  reported `FAIL — 4 of 37 checks` (doc-lint: 8 findings; manifest-driven verification: 12
  findings; `run-all.sh` suite failures; eager-load budget over baseline). This task made zero
  file edits, so none of these failures can be a regression from this task's own work. Full
  evidence trail:
  - All 12 manifest-driven findings and all 8 doc-lint findings name files that are *not*
    `task-abandon-mode.md` or `skill-todo/SKILL.md` (this task's only two source-store
    `file_scope` files). They instead name files in concurrently-dispatched sibling tasks'
    declared `file_scope` from this same `/orchestrate` cycle (per the dispatch's `Territory`
    block): `scripts/lib/derived-artifact-probe-lib.sh`, `scripts/tests/test-derived-artifact-probe-lib.sh`,
    `scripts/tests/test-gate-out-derived-staleness.sh` (task 381's `file_scope`), and
    `scripts/validate-state.sh`-adjacent / `scripts/orchestrate-cycle-postflight.sh` /
    `scripts/roadmap-integration.sh` content drift (tasks 379/381/388's `file_scope`), plus
    `lean`-extension content drift — already flagged independently by this dispatch's own
    `<deploy-freshness-context>` block as pre-existing staleness on the `core`/`lean` extensions.
  - This matches the territory contract's own guidance: "treat an unexpected build failure in a
    file outside your own `file_scope` as possibly a sibling's in-flight edit, not necessarily
    your own regression."
  - Recorded via `issue-record.sh` (class: gate collision, severity: minor) rather than blocking
    this task's closure on a gate failure this task did not cause and cannot fix within its own
    `file_scope`.

## Verification

- Build: N/A (meta task, no build)
- Tests: N/A — the one test-relevant gate (`run-all.sh`, invoked via `verify-deploy.sh`) failed
  for reasons traced to concurrent sibling work, not this task's files (see Plan Deviations)
- Files verified: Yes — both warning sites re-read in full, `git diff --stat` empty, `git log -1`
  matches the cited commit on both files
- Full gate set (`verify-deploy.sh`): FAIL (4/37), traced to sibling in-flight work and
  pre-existing lean-extension staleness, not this task — see Plan Deviations

## Impacts

- None on the deployed or source-store trees: no files changed.
- Closes the task-management gap: task 380's deliverable, which already existed in the repo
  under commit `7ffb3916658d795d617905b5ff612a11bb541bd7`, is now recorded against its own task
  accounting with a verified evidence trail.

## Follow-ups

- None for this task. The repo-side consumer check (BimodalLogic's own
  `scripts/check-evidence-probes.sh` tracked-ness check) remains out of scope and is already
  filed there as its own task.
- The gate failures recorded above are sibling-caused and expected to clear once tasks 379, 381,
  and 388 complete and the `core`/`lean` extensions are redeployed; no action item for task 380.

## References

- `specs/380_archival_silently_untracks_evidence_gate_targets/reports/01_warning-already-present.md`
- `specs/380_archival_silently_untracks_evidence_gate_targets/plans/01_verify-archival-warning-present.md`
- `agent-system/extensions/core/context/patterns/task-abandon-mode.md`
- `agent-system/extensions/core/skills/skill-todo/SKILL.md`
