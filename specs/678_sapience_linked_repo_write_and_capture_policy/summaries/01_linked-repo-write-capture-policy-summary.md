# Implementation Summary: Task #678

- **Task**: 678 - Sapience linked-repo write and capture policy
- **Status**: [IN PROGRESS]
- **Started**: 2026-11-21T19:00:00Z
- **Completed**: (phases 5-6 pending)
- **Effort**: ~1 hour (Phase 3) + ~1 hour (Phase 4) + ~0.3 hour (Phase 5)
- **Dependencies**: None
- **Artifacts**: plans/01_linked-repo-write-capture-policy.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

This dispatch covers Phase 3 ("Rule File and Existing-Doc Ruling Pointers"), Phase 4
("Resolve-Once Pass-Through at the Postflight Call Site"), and Phase 5 ("Line-Neutral
`EXTENSION.md` Pointer") of the six-phase plan, each a separate hard-mode dispatch per the Phase
Mission directive. Phase 3 threads the five rulings already recorded in Phase 1's new
`linked-repo-write-policy.md` record into the surfaces that each own a piece of the reasoning.
Phase 4 cuts the per-task `GET /v1/people/projects` call count for a linked repo from
one-per-note to one-per-task. Phase 5 makes the new record reachable from the merged
`.claude/CLAUDE.md` section without breaching `EXTENSION.md`'s 60-line ceiling.

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
- `agent-system/extensions/sapience/scripts/postflight-sapience-notes.sh` (Phase 4) — resolves
  this repo's Sapience project key AT MOST ONCE per completed task (duplicating
  `sapience-remember.sh`'s own PROJECT-KEY RESOLUTION block) and forwards it to every
  `sapience-remember.sh` call as `--project-key`, short-circuiting that script's own per-call
  GET. An unlinked repo (no `.sapience/project.json`) takes a pure filesystem-stat path: zero
  GETs, no `--project-key` forwarded, unchanged from pre-Phase-4 behavior. A resolution failure
  degrades the whole batch to untagged writes with exactly one
  `infrastructure/transport unavailable` issue row recorded once, never per note.
- `agent-system/extensions/sapience/scripts/tests/test-postflight-sapience-notes.sh` (Phase 4) —
  added Cases 10 (linked: 3-note batch, one GET, same resolved key on all 3 calls) and 11
  (unlinked: zero GETs, no `--project-key` flag at all).

## Decisions

- Measured corpus figure is 5 of 14 (not the plan's provisional "6 of 15" prediction) — the plan's
  own Scope Hypothesis instructed writing the measured value, and `linked-repo-write-policy.md`
  (Phase 1's new record) was already one of the 14 `.md` instruction surfaces before this phase.
- The four previously-missing "legitimate sites" resolved to `linked-repo-write-policy.md`,
  `EXTENSION.md`, `index-entries.json`, and the rule file's own "Permission Grant" section.
- Ruling 5 was placed in `command-draft-and-picker.md` immediately before its "Decision-Shaped"
  section, the Stage-3-draft-assembly content it is adjacent to.
- Phase 4: resolving the project key via a resolve-only flag added to `sapience-remember.sh`
  itself was rejected -- that script is outside this phase's declared `Files to modify` -- in
  favor of duplicating its PROJECT-KEY RESOLUTION block directly into
  `postflight-sapience-notes.sh`, the same duplication pattern that block's own header already
  uses to justify its own copies across the sapience scripts. The duplicate is NOT added to that
  block's tracked nine-file lockstep set (`test-sapience-mcp-registration.sh` Case 30); the two
  copies are intentionally independent.
- Phase 4: on a resolution failure (binding present but the GET fails or matches no entry), this
  script omits `--project-key` from the per-note calls, so each `sapience-remember.sh` invocation
  still attempts its own fallback resolution (unchanged pre-Phase-4 behavior for that one call).
  The "resolve once" guarantee is therefore exact for the SUCCESS path (the one the plan's
  Verification criterion names) and a best-effort reduction (one extra issue row, not necessarily
  one extra GET) on the degrade path -- documented inline in the script rather than silently
  assumed.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A
- Tests (Phase 3): Passed — `verify-touched.sh` across all five touched files: 98 passed, 0
  failed.
- Gate 3 (`verify-deploy.sh --skip-slow --only-gate 3`, Phase 3): Rule R (line_count accuracy)
  reported no sapience finding. The run's single FAIL was a pre-existing/expected
  deployed-content-drift condition on `rules/sapience-write-path.md` (this repo's `.claude/` tree
  was already flagged stale for the sapience extension before this dispatch started); Phase 6 is
  the plan's named deploy phase, so this was not cleared here.
- Files verified (Phase 3): Yes — all sanctioned-discussion-list entries confirmed to exist on
  disk and name at least one of the four MCP write tools; diff read-through confirmed every added
  hunk is prose that discusses, never prescribes, an MCP write tool as a write path.
- Tests (Phase 4): Passed — `test-postflight-sapience-notes.sh` 41/41 (9 pre-existing + 2 new),
  `test-sapience-remember.sh` 11/11 (Phase 2's flag contract unchanged), both run with
  `CORE_TEST_SUBJECT_MODE=source-store` against the source-store copy (the deployed `.claude/`
  tree for the sapience extension was already flagged stale at dispatch start; Phase 6 redeploys).
  New Case 10 confirmed exactly one GET for a 3-note linked batch; new Case 11 confirmed zero
  GETs and no `--project-key` flag for an unlinked batch.
- Tests (Phase 5): `verify-touched.sh agent-system/extensions/sapience/EXTENSION.md` selected and
  passed 3 suites (`test-index-entries-schema.sh`, `test-manifest-scripts-sync.sh`,
  `test-sapience-capture.sh`): 3 passed, 0 failed. `wc -l` on `EXTENSION.md` measured 60 both
  before and after the edit. `verify-deploy.sh --only-gate 3 --skip-unchanged` (the dispatch's
  Batch Gate Deferral scoped narrowing) reported no Rule U/V finding for `EXTENSION.md`
  specifically; its one FAIL is the same pre-existing Phase 2-4 deploy-drift condition already
  named above, not attributable to Phase 5's edit.

## Impacts

- Phase 6 (deploy/done-when verification) remains to complete the task. Phase 3's edits are
  additive prose only. Phase 4's edit changes `postflight-sapience-notes.sh` runtime behavior
  only for a repo carrying `.sapience/project.json` -- an unlinked repo's behavior (every repo in
  this codebase today) is unchanged. Phase 5's edit is a net-zero-line, purely additive context
  pointer with no runtime behavior change.

## Follow-ups

- Phase 6 must redeploy (`deploy-headless.sh`) to clear the `rules/sapience-write-path.md`,
  `scripts/postflight-sapience-notes.sh`, and `scripts/tests/test-postflight-sapience-notes.sh`
  content-drift conditions Phases 3-4's edits (and the pre-existing staleness) left in
  `check-extension-docs.sh`'s Gate 3 output, which will also carry Phase 5's `EXTENSION.md`
  change into the deployed tree.

## References

- Plan: `specs/678_sapience_linked_repo_write_and_capture_policy/plans/01_linked-repo-write-capture-policy.md`
- Phase 3 handoff: `specs/678_sapience_linked_repo_write_and_capture_policy/handoffs/phase-3-handoff-20261121T200000Z.md`
- Phase 4 handoff: `specs/678_sapience_linked_repo_write_and_capture_policy/handoffs/phase-4-handoff-20261121T201000Z.md`
- Phase 5 handoff: `specs/678_sapience_linked_repo_write_and_capture_policy/handoffs/phase-5-handoff-20261121T202146Z.md`
- Phase 1 record: `agent-system/extensions/sapience/context/project/sapience/domain/linked-repo-write-policy.md`
