# Implementation Summary: Task #678

- **Task**: 678 - Sapience linked-repo write and capture policy
- **Status**: [IN PROGRESS]
- **Started**: 2026-11-21T19:00:00Z
- **Completed**: (phases 4-6 pending)
- **Effort**: ~1 hour (Phase 3 only)
- **Dependencies**: None
- **Artifacts**: plans/01_linked-repo-write-capture-policy.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

This dispatch implemented Phase 3 only ("Rule File and Existing-Doc Ruling Pointers") of the
six-phase plan, per the hard-mode Phase Mission directive. It threads the five rulings already
recorded in Phase 1's new `linked-repo-write-policy.md` record into the surfaces that each own a
piece of the reasoning: the standing rule file and three existing domain docs.

## What Changed

- `agent-system/extensions/sapience/rules/sapience-write-path.md` — added a "Link State Does Not
  Change the Write Path" section stating Rulings 1-2; corrected the stale corpus figure from
  "exactly three" to the measured 5 of 14 `.md` instruction surfaces; completed the
  sanctioned-discussion-site list from two to six entries.
- `agent-system/extensions/sapience/context/project/sapience/domain/transcript-filter-ceiling.md`
  — added Ruling 4 (link state does not loosen the `source_skip()` filter).
- `agent-system/extensions/sapience/context/project/sapience/domain/command-draft-and-picker.md`
  — added Ruling 5 (a member's own pending suggestions surface through the existing `/sapience`
  draft via `vault.suggestions`).
- `agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md` —
  added a one-paragraph Ruling 2 pointer to the `## Write-Tool Disposition` section.
- `agent-system/extensions/sapience/index-entries.json` — `line_count` resync for the three
  edited context files (119, 61, 126) via `generate-context-line-counts.sh --write`.

## Decisions

- Measured corpus figure is 5 of 14 (not the plan's provisional "6 of 15" prediction) — the plan's
  own Scope Hypothesis instructed writing the measured value, and `linked-repo-write-policy.md`
  (Phase 1's new record) was already one of the 14 `.md` instruction surfaces before this phase.
- The four previously-missing "legitimate sites" resolved to `linked-repo-write-policy.md`,
  `EXTENSION.md`, `index-entries.json`, and the rule file's own "Permission Grant" section.
- Ruling 5 was placed in `command-draft-and-picker.md` immediately before its "Decision-Shaped"
  section, the Stage-3-draft-assembly content it is adjacent to.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A
- Tests: Passed — `verify-touched.sh` across all five touched files: 98 passed, 0 failed.
- Gate 3 (`verify-deploy.sh --skip-slow --only-gate 3`): Rule R (line_count accuracy) reported no
  sapience finding. The run's single FAIL was a pre-existing/expected deployed-content-drift
  condition on `rules/sapience-write-path.md` (this repo's `.claude/` tree was already flagged
  stale for the sapience extension before this dispatch started); Phase 6 is the plan's named
  deploy phase, so this was not cleared here.
- Files verified: Yes — all sanctioned-discussion-list entries confirmed to exist on disk and
  name at least one of the four MCP write tools; diff read-through confirmed every added hunk is
  prose that discusses, never prescribes, an MCP write tool as a write path.

## Impacts

- Phases 4-6 (postflight call-site pass-through, `EXTENSION.md` pointer, deploy/done-when
  verification) remain to complete the task. Phase 3's edits are additive prose only and do not
  change any script behavior.

## Follow-ups

- Phase 6 must redeploy (`deploy-headless.sh`) to clear the `rules/sapience-write-path.md`
  content-drift condition this phase's edit (and the pre-existing staleness) left in
  `check-extension-docs.sh`'s Gate 3 output.

## References

- Plan: `specs/678_sapience_linked_repo_write_and_capture_policy/plans/01_linked-repo-write-capture-policy.md`
- Phase 3 handoff: `specs/678_sapience_linked_repo_write_and_capture_policy/handoffs/phase-3-handoff-20261121T200000Z.md`
- Phase 1 record: `agent-system/extensions/sapience/context/project/sapience/domain/linked-repo-write-policy.md`
