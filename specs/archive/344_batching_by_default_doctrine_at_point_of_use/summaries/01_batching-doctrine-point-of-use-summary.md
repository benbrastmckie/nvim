# Implementation Summary: Task #344

- **Task**: 344 - Carry the batching-by-default doctrine to the point of use, and make a territory
  overlap produce a serializing edge rather than a separation
- **Status**: [COMPLETED]
- **Started**: 2026-10-09T01:19:33Z
- **Completed**: 2026-10-09T04:10:00Z
- **Effort**: ~3 hours
- **Dependencies**: 280 (completed), 311 (completed)
- **Artifacts**: plans/01_batching-doctrine-point-of-use.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Carried the already-correct batching-by-default doctrine to seven points of use it was not
reaching, closed the two measured gaps in Rule 1 (no narrowness qualifier, no owner-blocked
carve-out), stated the batch-plan rendering rule, and shipped `update-task-status.sh
--depends-on-add` — a true sibling of `--file-scope-add`/`--research-questions`/`--hold-reason`
— with a mandatory write-time cycle refusal that reuses `validate-state.sh`'s existing Kahn
detector rather than a second implementation. All 8 phases closed; Phase 8 closed
`[COMPLETED WITH EXCLUSIONS]` for one pre-existing, out-of-scope orphan-detection gap unrelated
to this task's edits (see Plan Deviations).

## What Changed

- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — Rule 1
  gained a narrowness qualifier (anchored to `validate-state.sh` Check 8's coarse-`file_scope`
  WARN), an explicit pointer to the existing `MAX_TASKS` cap fallback (truncation-precedence
  sentence preserved verbatim), an owner-blocked carve-out, and a default-move sentence; a new
  `### Rendering an unordered territory overlap in a batch plan` subsection states the
  batch-plan rendering rule; the scope note now distinguishes `file_scope` backfill from
  dependency-edge backfill.
- `agent-system/extensions/core/context/patterns/multi-task-operations.md` — §13 ("File
  Footprint Overlap as a Serialization Edge") gained the overlap-to-edge default-move sentence
  for the previously-uncovered case (two separately-created tasks found to overlap with no edge
  yet) and the general direction-rule note.
- `agent-system/extensions/core/merge-sources/claudemd.md` — new `### Batching` heading and
  operative paragraph stating the default posture, the territory-is-a-reason-to-batch rule, the
  overlap-to-edge default move (naming `update-task-status.sh --depends-on-add`), and that
  width-1 serialization is still correct; achieved byte-NEGATIVE (not merely neutral) via two
  offsetting trims of duplicated detail, confirmed present in their non-eager homes before
  cutting.
- `agent-system/extensions/core/scripts/update-task-status.sh` — new
  `--depends-on-add=<json-array>` flag: eager JSON-array-of-numbers validation, self-edge and
  predecessor-existence checks, a status-no-op restriction (only ever rides the existing
  no-op-replay branch), a union-merge write making repeated calls idempotent, a `--dry-run`
  diff render, and a mandatory write-time cycle refusal that builds a scratch `state.json` with
  the candidate edge applied and greps `validate-state.sh --deep`'s output for the cycle-verdict
  line (fail-closed if that script is missing).
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` — `validate-state.sh`
  added to `REQUIRED_SCRIPTS`; a new `build_multi_task_fixture_repo` helper (three entries, one
  pre-existing `dependencies[]` edge); Case 17 (8 sub-cases, 13 assertions) covering write-time
  cycle refusal (under both a real call and `--dry-run`), idempotent re-run, and four negative
  cases. Suite total: 60 passing (47 pre-existing + 13 new), 0 failed.
- `agent-system/extensions/core/index-entries.json` — `line_count` metadata regenerated for
  `batch-orchestration-guardrails.md` and (transiently) `multi-task-operations.md`, a mechanical,
  directly-caused side effect of editing those files' content (not a `file_scope` declaration,
  recorded as a minor scope excursion).
- `specs/state.json` — the next-admissible-batch suggester task's `description` (project_number
  274) appended, via `state-write.sh`, with an `=== EDGE-PROPOSING STEP (ADDED) ===` section:
  propose the serializing edge, then suggest the pair as a sequence, rather than silently
  withholding an overlapping pair. The pre-existing disjointness criterion is verbatim intact.

## Decisions

- Phases 3 and 4 were implemented and committed together: the write path and its cycle guard are
  inseparable in practice, so splitting the commit would have left an uncommitted intermediate
  state with a write-capable, cycle-unchecked flag.
- The `--depends-on-add` status-no-op restriction is a general condition ("the call resolves to
  the task's own current status"), not tied to a specific operation/target_status pair, matching
  the plan's instruction and verified against a task whose status (`not_started`) has no natural
  no-op call at all (expected, not a bug).
- Iterated the `### Batching` paragraph's final wording against the live
  `measure-eager-context.sh --check` output rather than hand-counting bytes — hand estimates were
  consistently off; the tool's `wc -c`-based measurement is authoritative.
- A genuine regression this phase's own verification caught — a literal `verify-deploy` mention
  this task's own Phase 3/4 header-comment prose introduced, violating
  `test-postflight-deploy-gate.sh`'s check-only contract — was fixed in Phase 8, not excluded:
  reworded to "the deploy-verification entry point," re-verified by both the targeted test (29
  passed, 0 failed) and the full `update-task-status.sh` suite (60 passed, 0 failed).

## Plan Deviations

- **Phase 3/4** merged into one commit (see Decisions above); both phases' own task checklists
  were independently completed and both phase headings closed `[COMPLETED]`.
- **Phase 8** closed `[COMPLETED WITH EXCLUSIONS]`: `verify-deploy.sh`'s full gate set (no
  `--skip-slow`) shows 33 of 35 checks passing. The 2 failures (Gate 13 whole-tree orphan
  detection, and Gate 8's `run-all.sh` via `test-verify-deploy-context-budget.sh`'s
  baseline-fixture-clean assertion) share ONE pre-existing, out-of-scope root cause: 3 stray
  `.claude/tmp/noop-bash-shapes-*` runtime files from other/historical Claude Code sessions,
  written by `hooks/detect-noop-bash.sh` (confirmed: that hook writes both
  `noop-bash-count-SESSION` and `noop-bash-shapes-SESSION` per session), which
  `context/patterns/deploy-orphan-detection.md`'s exclusion-class table documents only the
  `noop-bash-count-*` sibling for, not `noop-bash-shapes-*`. The budget-fixture test's own
  fixture symlinks `.claude` to the real repo tree, so it inherits the same hit (confirmed NOT a
  Gate 20/budget issue: `baseline_rc=1` with `gate20 finding lines=0`). Fixing the gap requires
  editing `deploy-orphan-detection.md` and/or the orphan-detection lint, neither in this task's
  declared `file_scope` of 5 source-store paths plus `specs/state.json`. Full evidence and the
  five-condition admission test are recorded in the plan's Phase 8
  `#### Reasoned Exclusions` table.

## Verification

- Build: N/A (no compiled artifact)
- Tests: `test-update-task-status.sh` 60/60 passed; `run-all.sh` 123/128 passed, 4 skipped, 1
  failed (the excluded, pre-existing orphan-detection-downstream case above)
- Files verified: Yes
- `verify-deploy.sh` (full, no `--only-gate`, no `--skip-slow`): 33/35 checks passed (see Plan
  Deviations for the 2 excluded)
- `measure-eager-context.sh --check`: `TOTAL 65939 B` <= `baseline_bytes 65950 B`, 0
  volatile-file hits
- `validate-state.sh --deep`: 0 failures, 10 pre-existing warnings (none naming project_number
  274 or 344)
- `shellcheck -S error`: 0 findings on both touched shell files, matching their pre-edit baseline
- `check-task-references.sh`: 0 unexempted occurrences

## Acceptance Criteria Evidence

1. **Always-loaded layer states the posture, token cost justified in writing** — `### Batching`
   heading added to `merge-sources/claudemd.md` with an operative paragraph (not a pointer-only
   restatement), achieved byte-NEGATIVE via two confirmed-duplicated trims (eager-load TOTAL
   65941 B before this task's edits -> 65939 B after, against `baseline_bytes` 65950 B). Written
   justification: a posture must fire before any file read; a pointer-only design already
   existed and did not reach the point of use (per the dispatch's own verification); the cost
   here is zero-or-negative because the addition is paid for by removing duplicated detail.
2. **Rule 1 narrowness qualifier + cap-aware fallback, measured instances cited** — Both added
   to `### The dominance rule` rule 1 in the guardrails doc. Re-measured 2026-10-09:
   `manifest.json` ties 4 open (9 total) tasks into one nominal group in this repo (down from
   the 2026-10-06 figure of 5 open, cited with its own date per the plan's Scope Hypothesis); the
   sibling repo's rename task still declares ~135 paths (project 170, `not_started`, confirmed
   live).
3. **Owner-blocked carve-out stated, five-file certificate pair as worked instance** — Added
   immediately after rule 1's qualifier/fallback paragraphs; cites the
   `components/framed_channel/certificate/*.txt` glob pattern (no task number) as the worked
   instance.
4. **Batch-plan rendering rule stated, "never with" can itself be false** — New
   `### Rendering an unordered territory overlap in a batch plan` subsection states both the
   rendering rule and the false-exclusion evidence (measured against a sibling repo's own
   `file-scope-overlap.sh`); states the ROADMAP-grammar/lint boundary explicitly.
5. **`--depends-on-add` with `--dry-run`, direction rule, mandatory write-time cycle refusal,
   no second detector** — All shipped; `grep -niE 'kahn|in_?degree|topolog'` across the whole
   script diff surfaces only 2 comment lines naming the reused check.
6. **Fixtures prove cycle refusal and idempotent re-run** — Case 17a (refusal, nonzero exit,
   cycle named, state byte-identical) and 17b (same under `--dry-run`); Case 17c (idempotent
   re-run, byte-for-byte no-op).
7. **Suggester re-pointed without weakening disjointness** — `specs/state.json` project_number
   274's `description` appended via `state-write.sh`; pre-existing disjointness criterion
   confirmed verbatim intact by `grep` immediately after the write.
8. **Shellcheck clean; no task-number references outside `specs/**`** — `shellcheck -S error`
   exits 0 on both touched shell files (matching pre-edit baseline exactly); 0 unexempted
   task-reference occurrences across the whole diff.

## Impacts

- Agents composing a batch `/orchestrate` invocation now encounter the batching-default posture
  directly in the always-loaded `CLAUDE.md`, not only by following a pointer into a ~1,900-line
  pattern file.
- A territory overlap between two existing tasks now has a mechanized, cycle-checked,
  idempotent primitive (`--depends-on-add`) to turn into a sequence, closing the gap Item 6
  identified (previously: hand-edit `state.json` via `state-write.sh` with no cycle check unless
  the writer remembered to run `validate-state.sh` separately).
- The next-admissible-batch suggester (project_number 274, still `[NOT STARTED]`, depends on
  this task among others) now has a specified edge-proposing step to implement, rather than
  silently withholding colliding pairs.

## Follow-ups

- The `tmp/noop-bash-shapes-*` orphan-detection exclusion-class gap (Plan Deviations above) is a
  real, pre-existing, small defect in `context/patterns/deploy-orphan-detection.md` affecting any
  task's full `verify-deploy.sh` run right now. Not filed as a new task by this dispatch (outside
  this agent's scope to create tasks); flagged here for operator awareness.
- The sibling repo's 2026-10-09 re-measurement of its own rename task's `file_scope` width (~135
  paths, 170, `not_started`) should be re-confirmed if cited again, per the plan's own
  re-measurement convention.

## References

- Plan: `specs/344_batching_by_default_doctrine_at_point_of_use/plans/01_batching-doctrine-point-of-use.md`
- Research report: `specs/344_batching_by_default_doctrine_at_point_of_use/reports/01_batching-doctrine-point-of-use.md`
- Per-phase handoffs: `specs/344_batching_by_default_doctrine_at_point_of_use/handoffs/`
