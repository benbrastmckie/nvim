# Implementation Summary: Task #394

- **Task**: 394 - Specify and implement a file_scope-based containment chokepoint for `git-commit-scoped.sh` / `git-commit-phase.sh`
- **Status**: [COMPLETED]
- **Started**: 2026-10-17T04:59:24Z
- **Completed**: 2026-10-17T08:05:00Z
- **Effort**: ~3 hours
- **Dependencies**: None (task 304's exit-code contract was already landed; this plan extends it)
- **Artifacts**: plans/01_file-scope-containment-chokepoint.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added a `file_scope`-Containment gate (label V10) inside `git-commit-scoped.sh`, layered onto the
existing `--task <N>` flag so every caller that already supplies `--task` for the V5
contended-path lease gains Containment with zero call-site edits. The gate classifies each
positive pathspec against the dispatching task's own declared `file_scope` (widened by the task's
own resolved directory, the two fixed `specs/` literals, and declared derived-output prefixes),
drops an uncontained path with a loud, distinct WARN, and emits reserved exit code `7` when a
commit nonetheless succeeded. Posture is drop-and-warn, never refuse, and fail-open on any
missing/empty/malformed `file_scope` or internal error. Ten new regression cases were added to
`test-git-commit-scoped.sh`, and `git-staging-scope.md` was updated end to end: the exit-code
table, a new V10 gate-label entry, an extended "Staging-Layer Containment Filter" subsection
naming all three Containment sites, and the archived specification's Rider ("Phase Commit
(mid-dispatch)" subsection).

## What Changed

- `agent-system/extensions/core/scripts/git-commit-scoped.sh` — new effective-scope resolution
  block (gated on `--task`), the `is_contained_v10` predicate, the V10 classification branch
  inside the V2 loop (evaluated before case 1, reusing V9's already-computed parent-directory
  resolution), the `containment_dropped` ledger, the exit-7 decision block (placed after V9's
  exit-6 decision so V9 keeps precedence), and full header documentation (Safety gates list,
  exit-code list).
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` — a `build_repo_with_scope`
  fixture helper (provisioning baseline `a.txt`/`b.txt` inside the task's own fixture directory
  plus an `out.txt` fixture under a genuinely out-of-scope sibling directory), ten new regression
  cases (Z1-Z10) covering fail-open (no state.json; malformed `file_scope` in four shapes),
  partial drop (exit 7), all-dropped (exit 2), drop-plus-no-diff-survivor (exit 4), the live
  postflight pathspec shape, trailing-slash symmetry, the derived-output exemption, `--task`
  omission, and non-fatality when `issue-record.sh` is absent. `lib/derived-artifact-probe-lib.sh`
  was added to `REQUIRED_SCRIPTS` and all three chmod-exemption copy loops.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — exit-code table rows
  `2`/`4` extended to name V10, row `7` rewritten from "RESERVED" to the landed V10 semantics, a
  new **V10** gate-label entry after V9, a new "Three Containment sites, not one" paragraph in
  the "Staging-Layer Containment Filter" subsection, and a new "Phase Commit (mid-dispatch)"
  subsection (the archived specification's Rider).

## Decisions

- Layered V10 onto the existing `--task` flag rather than a separate opt-in flag, per the
  research report's primary recommendation — every live caller that needs the protection already
  passes `--task`.
- Reused reserved exit code `7`, scoped to the commit-succeeded-with-drops shape, parallel to
  V9's exit `6`; the all-dropped shape stays exit `2` (V3) and the drop-plus-no-diff-survivor
  shape stays exit `4` (V6).
- `git-commit-phase.sh`'s own Phase-Commit Containment Self-Check is left in place as a
  deliberately redundant, non-load-bearing belt-and-suspenders check — V10 now structurally
  subsumes its reach for every caller that forwards `--task` (which it always does), but removing
  it was out of scope (the file is outside this task's `file_scope`) and it remains cheap,
  idempotent, and additionally records its own issue-log entry independently of V10's.

## Plan Deviations

- **Phase 3** (`build_repo_with_scope` fixture design): the original fixture design used
  `specs/999_probe/b.txt` as the "out-of-scope" candidate in the partial-drop/all-dropped/
  no-diff-survivor/non-fatality cases (Z3, Z4, Z5, Z10). This could never actually be dropped,
  because the dispatching task's own resolved directory is an unconditional implicit scope
  member by design. Redesigned to use a new `specs/998_sibling/out.txt` fixture under a genuinely
  separate task directory instead.
- **Phase 5** (verification tier): the phase's own stated verification ("run and observed green")
  closed as `[COMPLETED WITH EXCLUSIONS]` rather than plain `[COMPLETED]` — see the phase's own
  `#### Reasoned Exclusions` table in the plan for the five findings (two deploy-boundary
  artifacts, one duplicate of the first via a second gate, and two pre-existing, unrelated corpus
  test failures confirmed via `git log`/`git status` to predate this task).

## Verification

- Build: N/A (no build step for this change)
- Tests: `test-git-commit-scoped.sh` — 62/62 passed (52 pre-existing + 10 new Z-cases), zero
  regressions. `test-git-commit-phase.sh` — passed. Negative-control check: the 4 drop-dependent
  new cases (Z3, Z4, Z5, Z10) confirmed to FAIL against a copy of the pre-V10 script, proving
  they are non-vacuous; the remaining 6 (fail-open/exemption cases) pass both before and after,
  by the same accepted "unchanged behavior" shape this suite's own T15/T16 cases already
  document.
- Files verified: Yes — all three declared `file_scope` files edited and committed; no
  out-of-scope file touched by this task's own commits (confirmed via `git status --porcelain`
  on `index-entries.json` throughout).
- Full gate set: run twice (once under heavy concurrent load, once confirmed-idle) — see Phase
  5's Reasoned Exclusions table for the five findings, none attributable to this task's own
  changes.

## Impacts

- Every one of the roughly dozen per-extension implementation agents that already call
  `git-commit-phase.sh` → `git-commit-scoped.sh --task <N>` now gains file_scope-Containment
  protection automatically, with no agent-definition edits required — closing the original gap
  the archived specification identified (a pathspec inside the repository but outside the
  dispatching task's own declared scope was previously undetected by any mechanism reaching this
  surface reliably).
- A future consumer branching on `git-commit-scoped.sh`'s exit code can now distinguish a
  Containment drop (`7`) from a repository-boundary drop (`6`), a post-commit integrity mismatch
  (`5`), or an ambiguous no-commit (`4`).

## Follow-ups

- `orchestrate-cycle-postflight.sh`'s explicit `case` branch for `git-commit-scoped.sh`'s exit
  codes does not yet name `7` by code (it falls through the existing `*)` "unrecognized future
  exit code" branch, which is still loud and attributable but lacks the explicit list's durable
  `issue-record.sh` entry) — a natural, small follow-up for a future pass over that script,
  explicitly out of this task's `file_scope`.
- Two pre-existing, unrelated test-corpus failures were observed and recorded
  (`test-run-all-selection.sh`'s `common.sh` full-sweep-sentinel expectation, and
  `test-gate-cache-equivalence.sh`'s gate-10 timeout bound) — see the `issue-record.sh` entry
  filed this phase (`--class "unrelated test corpus defect"`) for a future dispatch to pick up.
- Migrating the ~12 per-extension implementation agents' own hand-typed `stage_paths` shape onto
  `git-commit-phase.sh` directly remains a separately-scoped follow-up (already recorded in
  `git-staging-scope.md`'s "Scope of the `git-commit-phase.sh` migration" paragraph) — this task
  deliberately requires no such migration, since V10 already reaches every one of those agents'
  existing `--task`-supplying calls.

## References

- Plan: `specs/394_file_scope_containment_chokepoint_for_scoped_commit/plans/01_file-scope-containment-chokepoint.md`
- Research report: `specs/394_file_scope_containment_chokepoint_for_scoped_commit/reports/01_containment-chokepoint-exit-code.md`
- Archived specification: `specs/archive/336_phase_commit_staging_has_no_scope_check/evidence/03_followup-mechanical-check.md`
- Phase handoffs: `specs/394_file_scope_containment_chokepoint_for_scoped_commit/handoffs/`
