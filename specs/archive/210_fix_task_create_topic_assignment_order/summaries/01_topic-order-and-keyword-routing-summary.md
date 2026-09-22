# Implementation Summary: Task #210

- **Task**: 210 - Fix /task create: topic assignment order and registration, and task-type keyword false positives
- **Status**: [COMPLETED]
- **Started**: 2026-09-22T00:00:00Z
- **Completed**: 2026-09-22T02:50:00Z
- **Effort**: ~3 hours
- **Dependencies**: None
- **Artifacts**: plans/01_topic-order-and-keyword-routing.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Fixed two separable defect clusters in `/task`, both rooted in `agent-system/extensions/core/`.
Cluster A: Create Task Mode called `manage-topics.sh set` before the task existed in
`active_projects`, always exiting 4, and its `AskUserQuestion` templates used a schema the tool
does not have. Cluster B: task_type detection was first-keyword-match-wins over bare common
words, so "agent", "lean", and "proof" mentioned in passing misrouted real descriptions, and the
literature extension's `keyword_overrides` mapped literature vocabulary to `meta`. All 8 plan
phases completed; both new fixture suites pass from the deployed copy; the change is deployed
and confirmed end-to-end.

## What Changed

- `agent-system/extensions/core/commands/task.md` — moved Create Mode's `manage-topics.sh set`
  call from step 4.5 (before the task exists) to after step 6's `state-write.sh` write, guarded
  as a hard error with an exact remediation command (D3); annotated step 6's `"topic"` jq clause
  (D2); fixed four bare-string `AskUserQuestion` `options` arrays (Recover, Expand, Review
  follow-up, and the `/task --sync` backfill picker) to the real `{label, description}` object
  schema; replaced step 4's whole 4a-4e keyword-table prose with a call to the new shared
  detection library plus a short resolution-ladder summary.
- `agent-system/extensions/core/context/patterns/topic-assignment-pattern.md` — rewrote Mode A's
  `AskUserQuestion` templates (Steps 2, 4, and the sync-backfill exception) to the real schema;
  added a zero-existing-topics branch to Step 1 (skip the picker, go straight to free-text) per
  Decision D4; updated the Mandatory Assignment Guarantee and batch-variant sections to name the
  new branch; added a pointer to `context/standards/interactive-selection.md`.
- `agent-system/extensions/core/scripts/lib/task-type-detect.sh` (new) — sourceable library
  implementing `detect_task_type`: a strong-anchor + weak-signal-threshold resolution ladder
  (Decision D6) replacing step 4's old first-match-wins table. Strong anchors resolve `meta`/
  `lean4` immediately from high-confidence phrases/patterns; extension `keyword_overrides`,
  project default, and alias remapping port across unchanged; weak-signal scoring requires 2+
  distinct keyword matches per candidate type, with `general` as the zero-match fallback.
- `agent-system/extensions/core/commands/fix-it.md` — research-task language-detection sentence
  now points at the shared library instead of restating a keyword list.
- `agent-system/extensions/literature/manifest.json` — removed the `keyword_overrides` block
  that mapped "literature", "zotero", "bibliography", "citation" to `meta` (the extension has
  `routing_exempt: true` with no `.routing` block, so that task_type was never resolvable).
- `agent-system/extensions/core/context/guides/extension-development.md` — dropped literature
  from the `keyword_overrides` worked-examples list; added an explicit rule that a
  `keyword_overrides` key IS the resolved task_type, so a `routing_exempt: true` extension with
  no `.routing` block must not declare `keyword_overrides` at all.
- `agent-system/extensions/core/scripts/tests/test-manage-topics-create-order.sh` (new) — fixture
  suite: zero-topics case, existing-topics idempotency case, the exit-4 not-found regression
  guard, and a text-order assertion over `commands/task.md` itself.
- `agent-system/extensions/core/scripts/tests/test-task-type-detect.sh` (new) — fixture suite:
  the six Decision-D6 acceptance cases, two negative controls, the literature-keyword regression
  guard, and one case against the real (deployed/source-store) manifest set.
- `agent-system/extensions/core/manifest.json` — registered the three new scripts above in
  `provides.scripts` (caught by doc-lint on the first deploy attempt).

## Decisions

- D1-D8 as recorded in the plan's Decisions table (move-not-inline for the topic-assignment
  fix, keep step 6's redundant topic clause, hard-error the post-move `set` call, zero-topics
  goes straight to free-text, remove rather than remap literature's `keyword_overrides`,
  strong-anchor + weak-threshold detection rule, also fix the plan's four picker sites in Phase
  1, leave `meta-builder-agent.md` untouched).

## Plan Deviations

- **Phase 1**: widened from the plan's named "three illustrative pickers" (Recover, Expand,
  Review follow-up) to four — the `/task --sync` backfill picker at ~line 607 was also a
  bare-string `options` array, and Phase 1's own Verification criterion ("No `"options": [`
  block in `task.md` contains a bare string element") is file-wide, so it was included.
- **Phase 8 (task 8.2 and 8.5)**: `run-all.sh` is not literally "green" in either the source
  store (1 of 91 suites fails) or the deployed tree (3 of 84 suites fail). Every failure was
  traced and confirmed pre-existing or caused by a concurrent sibling task's in-flight edit
  (task 242's edit to `agents/general-implementation-agent.md`), never by a file this task's
  commits touch — see the plan's Phase 8 task annotations for the full `git log` evidence trail.

## Verification

- Build: N/A (documentation + shell scripts)
- Tests: Passed — both new suites pass from the source store (9/9 and 10/10 respectively) and
  from the deployed copy (identical results). Full `run-all.sh`: 90/91 (source store) and 81/84
  (deployed tree) passing, with every non-passing suite confirmed pre-existing or
  concurrent-sibling-caused, not a regression from this task.
- shellcheck: Clean for `task-type-detect.sh`; the two new test suites carry only the
  established, accepted info-level SC2329 "cleanup() never invoked" false positive present on
  every `trap ... EXIT`-cleanup suite in this codebase.
- Files verified: Yes — all three new scripts confirmed deployed with correct content and
  executable bits; `jq .` valid on both modified manifest.json files.
- End-to-end ACCEPTANCE walkthrough: a scratch fixture repo with the deployed
  `manage-topics.sh`/`state-write.sh`, starting from a fresh `state.json`
  (`active_projects: []`, `active_topics: []`), produced a task with `topic` set and
  `active_topics` populated, with no non-zero exit at any step.

## Impacts

- `/task` create mode now reliably assigns and registers a topic on every fresh-repo first task,
  closing a defect that previously always failed silently (`manage-topics.sh set` exiting 4,
  swallowed by the old pre-move call site).
- Task-type detection is now centralized in one sourceable, unit-testable library instead of
  duplicated prose in `commands/task.md` and `commands/fix-it.md`, closing the drift risk the
  dispatch's absorbed former task (211) identified.
- Three real descriptions that previously misrouted (a business-strategy description mentioning
  "agent"/"proof"/"lean" in passing) now correctly resolve to `general`; a lean4 description
  that happens to mention "literature" no longer force-routes to `meta`.

## Follow-ups

- None required for this task's scope. The weak-signal threshold (`DTD_WEAK_THRESHOLD = 2`) is
  a single named, retunable constant if a future case reveals it misroutes a genuine short
  description — see the plan's Risk table.
- The pre-existing `test-verify-deploy-context-budget.sh` eager-load baseline mismatch (caused
  by a concurrent sibling task's rules-file edit, not this task) remains unresolved; it is that
  sibling task's concern, not this task's.

## References

- `specs/210_fix_task_create_topic_assignment_order/plans/01_topic-order-and-keyword-routing.md`
- `specs/210_fix_task_create_topic_assignment_order/reports/01_topic-order-and-keyword-routing.md`
- `specs/210_fix_task_create_topic_assignment_order/progress/phase-{1..8}-progress.json`
