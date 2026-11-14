# Implementation Summary: Task #531

- **Task**: 531 - file_scope declaration hygiene remediation for the admission gate
- **Status**: [COMPLETED]
- **Started**: 2026-11-12T06:51:00Z
- **Completed**: 2026-11-12T08:05:00Z
- **Effort**: 3.0 hours
- **Dependencies**: None
- **Artifacts**: plans/01_file-scope-declaration-hygiene.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Remediated both live `file_scope` declaration-hygiene defects in `specs/state.json` that left the
admission/overlap gate blind to real collisions: narrowed two coarse whole-directory declarations
(projects 473 and 518) to the files they actually touch, and backfilled the three non-terminal
tasks (567, 568, 607) that declared no `file_scope` at all. A fourth piece corrected two
source-store files that falsely claimed a nonexistent script (`scripts/check-evidence-probes.sh`)
enforces the archival un-tracking hazard.

## What Changed

- `specs/state.json` — project 473's `file_scope` narrowed from 1 directory entry to 5 measured
  files; project 518's narrowed from 16 directory entries (plus 7 preserved file entries) to 47
  file-level entries; projects 567, 568, 607 backfilled with concrete, on-disk-verified
  `file_scope` arrays (3, 4, and 5 paths respectively); project 531's own stale entry replaced
  with the 5 paths this task actually edited.
- `agent-system/extensions/core/context/patterns/task-abandon-mode.md` — corrected the
  archive-`mv` note to describe the real hazard (a `WIRED_REPO` reference breaks on archival;
  no mechanical detector exists; the discipline is manual) without asserting a nonexistent
  script enforces it.
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` — applied the identical correction to
  the matching `#` comment.
- `agent-system/extensions/core/index-entries.json` — corrected the `line_count` entry for
  `patterns/task-abandon-mode.md` (76 -> 77), the companion fix the edit above required; folded
  into project 531's own `file_scope` self-correction.

## Decisions

- Used `state-write.sh --argjson-file` throughout rather than `--argjson`, since every scope array
  was file-backed JSON; the two forms are equivalent for this purpose.
- `index-entries.json` carried many pre-existing, unrelated uncommitted hunks (present before this
  dispatch began). Rather than pass it to `git-commit-scoped.sh`/`git-commit-phase.sh` (which
  stage a named path wholesale and would have swept in that foreign content), the one hunk this
  task owns was extracted from `git diff` and staged directly via `git apply --cached`, then
  committed with a bare `git commit` (no pathspec) alongside the fully-clean markdown files. The
  phase-closing `git-commit-phase.sh` call for Phase 3 correctly detected and dropped this
  already-committed, declared-out-of-scope path via its Containment Self-Check, depositing a
  `proposed_file_scope` entry that Phase 2's own `file_scope` self-correction for project 531
  then resolved directly (5 paths written, not the plan's literal 4).
- Ran the complete, non-narrowed `verify-deploy.sh` and `run-all.sh` gates in Phase 4 rather than
  a scoped `--only-gate`/`--only` narrowing. This follows the dispatch's own Batch Gate Deferral
  directive's "Unmappable Criterion" carve-out: Phase 4's declared verification criteria
  explicitly require the full, non-narrowed run ("not a --only-gate subset and not --skip-slow"),
  which the directive's narrowing forms cannot express.

## Premise Corrections (dispatch description vs. live state)

The dispatch's own `## Description` carried stale figures from its BimodalLogic-repository
origin, each checked against live state during planning and reconfirmed here:

1. The dispatch cites "Task 177" declaring `FormalSystem/Metalogic/Decidability/` as a coarse
   entry. No project 177 exists in this repository; the live coarse entries were projects 473
   and 518, both remediated.
2. The dispatch cites "28 of 52" non-terminal tasks with no `file_scope`. The live count was 3
   (567, 568, 607), out of 135 non-terminal tasks — now 0.
3. The dispatch attributes the absent-declaration defect to Check 9 ("duplicates"). Check 9 is
   duplicates and was already `[PASS]`; the absent-declaration defect is Check 10
   (missing/null/empty `file_scope`).

## Deliberate Non-Goal: the evidence-probe detector

`scripts/check-evidence-probes.sh`, the script the dispatch's secondary scope item names as the
host for a one-line `WIRED_REPO` detector addition, does not exist anywhere in this repository's
working tree or git history. Building an equivalent from scratch is a materially larger and
different piece of work than the one-line addition the dispatch scopes, and was not attempted.
Phase 3 corrected the two `WIRED_REPO` citations (`task-abandon-mode.md`, `skill-todo/SKILL.md`)
to stop asserting the detector exists, while preserving the underlying hazard description.

**Follow-up recommendation**: resolve whether this repository should have a `WIRED_REPO`/
evidence-probe mechanical detector at all. Three further pre-existing citations of the literal
string `check-evidence-probes` remain, outside this task's own scope (confirmed via
`grep -rn "check-evidence-probes" agent-system/`):
`agent-system/extensions/formal/context/project/logic/domain/ztime-no-finite-carrier-fmp.md:75`
and `agent-system/extensions/lean/context/project/lean4/domain/decidability-provenance.md:84`
(both claim the nonexistent script backs a substantive logic/Lean result — a more consequential
false citation than the archival-hazard prose this task corrected), and
`agent-system/extensions/core/manifest.json:24` (an `external_scripts` dependency declaration).
Correcting the two domain-file claims requires domain judgment about what verification actually
backs them, not a mechanical hazard-description edit, and was left for a future task.

## Plan Deviations

- Phase 2's self-correction of project 531's own `file_scope` wrote 5 paths rather than the
  plan's literal 4, to directly resolve the `proposed_file_scope` deposit from Phase 3's
  `git-commit-phase.sh` Containment Self-Check (the `index-entries.json` companion fix) in the
  same phase rather than leaving it dangling.
- Phase 3's Testing & Validation criterion "`grep -rn check-evidence-probes agent-system/` returns
  no hits" is not literally satisfied — see "Follow-up recommendation" above for the three
  pre-existing occurrences outside this phase's own Tasks/Scope Hypothesis, recorded via
  issue-record.sh (class "scope boundary") rather than executed.

## Verification

- Build: N/A (data/markdown/comment edits only, no executable surface)
- Tests: Passed — `bash .claude/scripts/tests/run-all.sh` reports 182 passed, 6 failed (5
  pre-registered EXPECTED, 1 NEW — the NEW failure and all 2 doc-lint FAILs and both
  whole-tree-orphan findings trace to sibling task 601's own in-flight uncommitted new lint
  scripts, not yet registered in `manifest.json`'s `provides.scripts`, confirmed via `git
  status`/`git log`). `bash .claude/scripts/verify-deploy.sh` reports 12 of 85 checks FAIL, every
  one attributed to task 601's in-flight work, an unrelated pre-existing SKILL.md context-budget
  overage (last touched by task 609), or a transient gate10 timeout that passed cleanly (54.7s)
  on direct re-run — none within task 531's declared `file_scope`.
- Files verified: Yes — `validate-state.sh` reports Checks 8, 9, 10 and 11 all `[PASS]`;
  `validate-artifact.sh` passes the plan with 0 warnings; `backfill-file-scope.sh --dry-run`
  reports 0 plan-less tasks.

## Impacts

- The admission/overlap gate can now see real file-level collisions on projects 473, 518, 567,
  568, 607 and 531 that a coarse directory or absent declaration previously hid.
- `validate-state.sh`'s per-check cleanliness bar (Checks 8/9/10/11) is now fully met in base
  mode; the only remaining WARNs (Check 4 `audit_override`/`audit_verdict`) are out of this
  task's scope, as the plan's Non-Goals state.
- Two source-store files no longer make a false claim about mechanical enforcement, reducing the
  risk that a future `/task --abandon` or `/todo` archival silently un-tracks a gate-cited file.

## Follow-ups

- Resolve whether a `WIRED_REPO`/evidence-probe mechanical detector should exist in this
  repository at all (see "Follow-up recommendation" above), and if so, correct the three
  remaining `check-evidence-probes` citations (two domain-logic claims, one manifest.json
  dependency entry) accordingly.
- None of this task's own deliverables are outstanding.

## References

- Plan: `specs/531_file_scope_declaration_hygiene_remediation/plans/01_file-scope-declaration-hygiene.md`
- Research report: `specs/531_file_scope_declaration_hygiene_remediation/reports/01_file-scope-hygiene-remediation.md`
