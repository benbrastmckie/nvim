# Implementation Summary: Task #478

- **Task**: 478 - Ungate lint-agent-contracts.sh Check J: replace the content gate with a
  curated in-scope list so removal of a handoff-writer section is detected
- **Status**: [COMPLETED]
- **Started**: 2026-11-07T01:21:40Z
- **Completed**: 2026-11-07T02:30:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_ungate-check-j-curated-list.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Check J's subject set used to be derived from the very content it verified: a one-line content
gate skipped any agent file that did not already mention `.orchestrator-handoff.json`, so a file
that later dropped its entire handoff-writing section also dropped out of Check J's scan and the
lint went green at exactly the moment the contract was violated. All four plan phases are
complete: Check J now iterates every dispatchable agent with no content pre-filter and FAILs by
name on a required writer with no section, a short EXCLUDED-style array records the 8 genuine
exceptions, a stale-exclusion sweep closes the array's own inverted drift direction, the fixture
suite gained the regression cases the old design could not express, and the change is landed in
the deployed tree.

## What Changed

- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` -- removed the content
  gate from `check_j_handoff_section_artifacts()`; added `CHECK_J_EXCLUDED_RELATIVE_PATHS` (8
  entries, each with its own reason comment, following the file's EXCLUDED-style precedent
  (`EXCLUDED_TERMINAL_STATUS_RELATIVE_PATHS`, `EXCLUDED_ARTIFACTS_TEMPLATE_RELATIVE_PATHS`,
  `CHECK_G_EXCLUDED_RELATIVE_PATHS`/`CHECK_M_EXCLUDED_RELATIVE_PATHS`)) and
  `is_excluded_from_check_j()`; split the missing-heading FAIL branch into a heading-drift
  variant (file mentions the string, no recognized heading) and a new missing-section variant
  (zero mention at all, naming the exclusion array as the remediation pointer); added
  `_check_j_sweep_stale_exclusions()`, which FAILs an exclusion entry that no longer exists or
  now carries a recognized writer heading, scoped per-extension (an entry is evaluated only if
  its extension's own `agents/` directory exists in the current `$REPO_ROOT` tree) so it does
  not fire spuriously inside a narrow fixture tree.
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-handoff-section.sh` --
  grew from 6 to 9 fixture cases: case 7/(b) (the central regression -- a required writer with
  zero mention of the string, not excluded, must FAIL by name citing the exclusion array), case
  8/(c) (a fixture at the real `literature/agents/literature-agent.md` exclusion path is a
  decided skip), and case 9/(d) (the stale-exclusion sweep reports clean against this tree).
  Header comment updated to document all nine cases and the case-(a)/case-(d) mechanism
  equivalences.
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` -- a collateral
  regression discovered during this task's own Required-Outcome-6 sibling-suite verification
  (not in the plan's original file list): 4 shared "no-FAIL-expected" fixtures
  (`compliant-agent.md`, `check-f-conforming-agent.md`, `check-e-falsepositive-guard-agent.md`,
  `cslib-implementation-agent.md`) newly FAILed Check J's missing-section branch, and the
  stale-exclusion sweep found 3 recorded exclusion entries with no corresponding file in that
  suite's WORKDIR (that tree predates Check J's exclusion array). Repaired with a new shared
  `HANDOFF_SECTION_BLOCK` (inserted into the 4 affected fixtures) and 3 new minimal stub fixtures
  at the real excluded paths (`core/agents/code-reviewer-agent.md`,
  `core/agents/spawn-agent.md`, `cslib/agents/cslib-vet-agent.md`), restoring the suite to its
  61-passed/0-failed baseline. Documented in a new header-comment paragraph matching the file's
  own pre-existing "repair a shared fixture when a new/widened check lands" convention.
- The deployed tree (`.claude/scripts/...`) -- regenerated via `deploy-headless.sh`; confirmed
  byte-identical to the source store for all three edited files.

## Decisions

- In-scope criterion derived from WHY the section is necessary (an agent that writes, or is
  contractually expected to write, `.orchestrator-handoff.json` under `orchestrator_mode`), never
  from current content -- deriving it from content would reproduce the original hole in a new
  location.
- The 8 exclusions were matched against the file's own established EXCLUDED-style convention
  (literal bash array + per-entry reason comments), not an INCLUDED-style array, a
  frontmatter-declared opt-in, or a separate registry file -- the EXCLUDED-style flavor already
  governs the file's majority-in-scope, few-exceptions population shape, and this file has no
  precedent for the other two mechanisms.
- No Check-N-style completeness net was added for Check J: the fail-closed default already makes
  a brand-new agent file in scope the moment it is added, so the one case requiring deliberate
  action (a new forked-subagent-pattern-only agent) fails loudly by name until registered --
  this is already the safer failure direction Check N exists to retrofit onto Checks G/M.
- The stale-exclusion sweep's "does not fire in a narrow fixture tree" guard is scoped per
  extension's `agents/` directory presence, not per file -- sufficient for
  `test-lint-agent-contracts-handoff-section.sh`'s tree (which models no extension's `agents/`
  directory at all, aside from the one case 8 deliberately adds), but this guard does not by
  itself prevent collision with a DIFFERENT suite's tree that independently happens to model a
  subset of the same extension (see Plan Deviations).
- Case (c)'s real-excluded-path fixture uses `literature/agents/literature-agent.md` rather than
  the plan's illustrative `core/agents/code-reviewer-agent.md` example, because literature has
  exactly one `CHECK_J_EXCLUDED_RELATIVE_PATHS` entry under its extension -- creating only that
  one directory brings the stale-exclusion sweep into scope for exactly one entry, never dragging
  in sibling entries under the same extension with no fixture of their own.

## Plan Deviations

- **Phase 3, case (c) fixture path**: used `literature/agents/literature-agent.md` instead of the
  plan's illustrative `core/agents/code-reviewer-agent.md` example, for the reason given above.
- **Phase 3, "Files to modify" scope widened**: this phase's own required sibling-suite
  verification (Required Outcome 6) surfaced a real collateral regression in
  `test-lint-agent-contracts.sh`, a file not in the plan's original Phase 1 or Phase 3 file
  list. Repaired in the same phase rather than deferred, since an unrepaired regression would
  have left that suite red. Committed separately with its own explicit single-file pathspec
  (`git-commit-phase.sh`'s containment self-check correctly dropped it from the phase-scoped
  commit, since it is outside this task's declared `file_scope` in `specs/state.json`; it was
  committed immediately after via `git-commit-scoped.sh` with its own message explaining why).
- **Phase 4, redeploy outcome**: both redeploy runs returned `RESULT=landed_verify_red` rather
  than the plan's target `RESULT=landed_verify_clean`. Both of the 2 failing checks were
  confirmed, independently of this task, to be the pre-existing, out-of-scope findings this
  dispatch's own briefing named before any redeploy was attempted (a gate10 30s wrapper-timeout
  flake that passes standalone, and 2 `/ide` dead-command-recommendation findings in the memory
  extension, a directory this task never touches). The deploy itself landed cleanly; the
  dispatch's own Batch Gate Deferral directive defers the unnarrowed full gate set (where these
  two findings would otherwise block `landed_verify_clean`) to the once-per-batch stage.

## Verification

- Build: N/A (shell scripts, no build step)
- Tests:
  - `lint-agent-contracts.sh` (source store and deployed): 421 passed / 15 warn / 0 failed,
    exactly matching the recorded baseline (zero delta -- excluded files and the stale-exclusion
    sweep both emit `log_info`, never `log_pass`/`log_fail`).
  - `test-lint-agent-contracts.sh`: 61 passed / 0 failed (baseline restored after the
    discovered-and-repaired collateral regression).
  - `test-lint-agent-contracts-await-notification.sh`: 6 passed / 0 failed (unchanged).
  - `test-lint-agent-contracts-heartbeat.sh`: 6 passed / 0 failed (unchanged).
  - `test-lint-agent-contracts-handoff-section.sh` (source store and deployed): 9 passed / 0
    failed (grew from the recorded 6-case baseline as planned).
  - Ad hoc sanity checks (not part of the committed suites, all discarded after use): a scratch
    tree confirmed a required-but-sectionless fixture FAILs by name under the new design; a
    scratch copy with the content gate restored confirmed case 7/(b) is the one assertion that
    flips to FAIL there (direct bug-detection-power proof); a scratch copy with a nonexistent
    exclusion-array path and a path to a real writer file confirmed both stale-exclusion FAIL
    branches fire correctly.
- Files verified: Yes -- source store and deployed tree confirmed byte-identical for all three
  edited files via `diff -q`.
- `check-task-references.sh` / `check-record-versioning.sh` against all three edited files: 0
  task-reference occurrences; one advisory record-versioning hit this task introduced
  ("previously-clean") was reworded and reverified clean; all remaining advisory hits in the
  three files predate this task.

## Impacts

- Removing a handoff-writer section from any of the 44 currently-checked agent files (or any
  future dispatchable agent not on the 8-entry exclusion list) now turns `lint-agent-contracts.sh`
  red by name, closing the exact silent-pass hole task 378's planner deliberately deferred as a
  Non-Goal.
- The 8-entry exclusion array is itself now self-protecting: a stale entry (file renamed/deleted,
  or later becomes a real writer) is a named FAIL rather than a silent permanent skip.
- `test-lint-agent-contracts.sh`'s shared fixtures gained a `HANDOFF_SECTION_BLOCK` and 3 new stub
  fixtures; any future check added to `lint-agent-contracts.sh` that scans all dispatchable
  agents should check whether these same shared fixtures (and the WORKDIR's `core/agents/` and
  `cslib/agents/` directories) need a similar repair, per that file's own now-three-times-used
  convention.

## Follow-ups

- The gate10 (`validate-state.sh --deep`) 30s wrapper-timeout flake and the 2 `/ide`
  dead-command-recommendation findings in the memory extension remain open, pre-existing, and
  out of this task's scope -- flagged by the dispatching orchestrator before this task began and
  independently reconfirmed here as unrelated to this task's files.
- Check N's `'*implementation*agent.md'` glob gap (missing the `*-implement-agent.md` variant) is
  a pre-existing, separately-recorded gap in a different check, out of this task's scope.
- The founder/present writer-registration pointer for `docs/architecture/handoff-schema.md`'s
  "Handoff Writers" table remains an unaddressed documentation recommendation (explicit Non-Goal).

## References

- `specs/478_ungate_lint_check_j_handoff_contract/plans/01_ungate-check-j-curated-list.md`
- `specs/478_ungate_lint_check_j_handoff_contract/reports/01_ungate-check-j-curated-list.md`
- `specs/478_ungate_lint_check_j_handoff_contract/handoffs/phase-1-handoff-20261107T012442Z.md`
- `specs/478_ungate_lint_check_j_handoff_contract/handoffs/phase-2-handoff-20261107T014500Z.md`
- `specs/478_ungate_lint_check_j_handoff_contract/handoffs/phase-3-handoff-20261107T020800Z.md`
