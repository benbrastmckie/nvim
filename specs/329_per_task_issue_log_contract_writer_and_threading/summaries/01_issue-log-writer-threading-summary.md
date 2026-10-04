# Implementation Summary: Task #329

- **Task**: 329 - Per-task issue log: contract, writer and dispatch threading
- **Status**: [COMPLETED]
- **Started**: 2026-10-03T23:40:00Z
- **Completed**: 2026-10-04T03:50:00Z
- **Effort**: ~4 hours
- **Dependencies**: Task 326 (completed), Task 285 (completed)
- **Artifacts**: plans/01_issue-log-writer-threading.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md

## Overview

Implemented the full 9-phase plan: a per-task, append-only `specs/{NNN}_{SLUG}/issues.jsonl`
capture log written exclusively by one new script, `issue-record.sh`; threaded a `## Issue Log`
recording instruction to every dispatched agent through the single per-dispatch prompt emitter
(`orchestrate-build-dispatch.sh`) and the two shared contract includes (`phase-closure.md`,
`wrap-up.md`); added seven orchestrator-side call sites across `orchestrate-cycle-postflight.sh`
and `orchestrate-cycle-plan.sh`; and retired the dead state.json `reflection` field end-to-end
across both the core and memory extension source stores, replacing it with the new log's
`kind: "win"`/`kind: "issue"` vocabulary.

## What Changed

- `agent-system/extensions/core/context/formats/issue-log.md` — new format doc: entry schema,
  severity scale, cost-unit convention, 15-class seed enum (open/extensible), the six relation
  verdicts against existing issue-bearing surfaces, and the CAPTURE ONLY boundary.
- `agent-system/extensions/core/scripts/issue-record.sh` — new file; the single writer, modeled
  on `events-append.sh` (JSONL append mechanics), `system-defect-record.sh` (argument/validation
  style and non-fatal convention), and `orchestrate-record-decision.sh` (task-directory
  resolution discipline).
- `agent-system/extensions/core/scripts/tests/test-issue-record.sh` — new file; 15-case
  regression suite (schema validation, byte-identical refusal, genuine concurrency, unknown-class
  warn-and-append, non-fatal failure form, win entries, `--task N` resolution).
- `agent-system/extensions/core/manifest.json` — registered `issue-record.sh` and
  `tests/test-issue-record.sh` in the `scripts` deploy whitelist (required for either file to
  reach the deployed `.claude/scripts/` tree — not named in the original plan's file list).
- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` plus its three block-copy
  consumers (`test-runtime-file-tracking.sh`, `test-orchestrate-unwind-dispatch.sh`,
  `context/standards/orchestrator-runtime-files.md`) and the regenerated `specs/.gitignore`
  managed block — `.issues.lock` registered as the 21st ephemeral runtime-file class member;
  `issues.jsonl` itself stays tracked (durable provenance).
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — new unconditional
  `## Issue Log` section emitter, inserted after `## Handoff`, reaching every dispatched agent in
  every phase (research/plan/implement) without editing any agent definition file.
- `agent-system/extensions/core/context/contracts/phase-closure.md` — during-phase recording
  obligation (both modes).
- `agent-system/extensions/core/context/contracts/wrap-up.md` — hard-mode MIRROR reinforcement at
  the `blockers[]` write moment.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` — extended with
  assertions proving the `## Issue Log` section is genuinely unconditional across all three
  phases.
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — five adjacent
  `issue-record.sh` calls: `RECOVERY_DECLINED`, `OFF_SCHEMA_STATUS`, the `partial)` blocker-gated
  arm, the `failed|blocked)` arm, and the deploy-pending-refusal sub-path.
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — two calls at the
  `MAX_INFRA_FAILURES` and `MAX_CYCLES` loop-guard exhaustion branches, using `--task N`
  resolution.
- `agent-system/extensions/core/context/formats/return-metadata-file.md` — `errors[]` MIRROR
  verdict recorded; the entire `### reflection (optional)` section and all remaining mentions
  removed.
- `reflection` retirement across core: `scripts/validate-state.sh` (`KNOWN_ENTRY_FIELDS`),
  `context/schemas/state-schema.json` (`reflectionObject` definition and property),
  `scripts/orchestrator-postflight.sh` (header, var init/read, Stage 6b event emission, Stage 7d
  write block all removed), `context/reference/state-management-schema.md` (converted to an
  explicit historical note), `skills/skill-todo/SKILL.md` (harvest/display/augmentation/cleanup
  references removed), plus three sites the plan's 7-file hypothesis did not name:
  `scripts/memory-harvest.sh`, `context/patterns/todo-archival-reference.md`,
  `context/standards/user-decision-contract.md`.
- `agent-system/extensions/memory/EXTENSION.md` — corrected the generated `.claude/CLAUDE.md`
  memory-section merge source's `/todo` reflection-harvest sentence.
- `agent-system/extensions/memory/skills/skill-learn/SKILL.md` and `commands/learn.md` —
  removed the state.json `reflection`-field read and pseudo-artifact option; restored
  unconditional file-artifacts-only behavior.
- `agent-system/extensions/core/context/formats/events-format.md` — added a producer-status note
  to the `reflection` event-type row (no live producer; row retained because memory-extension
  query recipes still reference historical rows).
- `agent-system/extensions/memory/context/project/memory/patterns/distill-revise-submode.md`,
  `distill-meta-submode.md`, `distill-usage.md` — one-line producer-status pointer notes added.
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` — registered
  `issue-record.sh`.
- `agent-system/extensions/core/index-entries.json`, `agent-system/extensions/memory/index-entries.json`
  — new/corrected `line_count` values for touched context files.
- `specs/TODO.md` — regenerated to resync with state.json's `329 -> [IMPLEMENTING]` transition
  (pre-existing drift found during Phase 4's deploy verification, unrelated to this task's own
  edits but fixed as a standard maintenance action).
- `.claude/` (regenerated deploy tree) and `specs/329_per_task_issue_log_contract_writer_and_threading/issues.jsonl`
  (created lazily; this task's own dogfooded entries).

## Decisions

- Resolved the plan's "six relation verdicts" vs. the five explicitly bulleted ones in Phase 1's
  task text by splitting the handoff row into two (`blockers[]` and `dead_ends` as separate
  MIRROR rows) — the literal count of named items across the REQUIRED DECISION paragraph is 6
  when `blockers[]`/`dead_ends` are counted separately, matching the Scope Hypothesis's explicit
  "exactly 6 rows" check.
- Added `scripts/issue-record.sh` and `scripts/tests/test-issue-record.sh` to `manifest.json`'s
  `scripts` deploy whitelist, discovered necessary mid-Phase-2 when the new script did not appear
  in the deployed `.claude/scripts/` tree after a deploy run — not named in the plan's file list.
- Converted `state-management-schema.md`'s "Reflection Field" subsection to an explicit historical
  note rather than deleting it outright, per the plan's "Remove or convert" choice — preserves
  context for a future reader without claiming current behavior.
- Mapped the `OFF_SCHEMA_STATUS` call site's `inferred_phase: "unknown"` value to
  `issue-record.sh`'s closed-set `"other"` phase value, since `"unknown"` is not a member of that
  script's closed `--phase` enum.

## Plan Deviations

- **Task 5.verification** (altered): extended the already-existing
  `scripts/tests/test-orchestrate-build-dispatch.sh` fixture suite rather than performing a
  one-off manual invocation, so the "unconditional across all three phases" proof is itself
  regression-checked going forward.
- **Task 2.2 / 3.2** (altered): added `manifest.json` registration for both new scripts — required
  for deploy to install them, not named in the plan's file list.
- **Task 7.scope** (altered): fixed three additional state.json-field `reflection` references the
  plan's 7-file hypothesis did not name (`memory-harvest.sh`, `todo-archival-reference.md`,
  `user-decision-contract.md`), discovered during the mandated inventory step itself.
- **Scope Hypothesis counts exceeded, never under-shot**: Phase 3's test suite reached 15 cases
  against an estimated 9-11 (additional edge-case coverage, not a collapsed area); Phase 4's
  member count and Phase 7's reflection inventory both landed above their respective hypotheses,
  each confirmed and recorded rather than silently expanded.

## Verification

- Build: N/A (meta task; no application build)
- Tests: `test-issue-record.sh` 15/15 PASS; `test-runtime-file-tracking.sh` 9/9 PASS;
  `test-orchestrate-unwind-dispatch.sh` 21/21 PASS; `test-init-specs.sh` 23/23 PASS;
  `test-orchestrate-build-dispatch.sh` 141/141 PASS (including new Issue Log assertions);
  `test-orchestrate-cycle-postflight.sh` 166/166 PASS. Full repo sweep (`run-all.sh`): 107
  passed, 5 failed (3 already tracked EXPECTED, 2 NEW), 1 skipped — all 5 failures confirmed
  via git-log file-overlap analysis (and, for `test-orchestrate-cycle-plan.sh`, direct
  byte-identical re-run against the unmodified git-HEAD copy) to be pre-existing and unrelated to
  this task's edits, not regressions.
- Files verified: Yes — `bash .claude/scripts/verify-deploy.sh` (fast gates): 33 checks, 0
  failures; `shellcheck` finding counts byte-identical to pre-edit baselines (or to modeled
  precedents' baselines for the two new files) across every touched shell file; `jq -e .` /
  `python3 -m json.tool` validated every touched JSON file.

## Impacts

- Every dispatched agent (research/plan/implement, base and hard mode alike) now receives an
  explicit, non-inlined pointer to record issues and wins as they arise, reaching all three
  phases through one threading point rather than any of the 78 agent definition files.
- A blocked, off-schema, or loop-guard-exhausted dispatch now leaves a structured, durable entry
  in `issues.jsonl` instead of only a commit subject line — the detail survives the next
  dispatch's overwrite of `.return-meta.json`/`.orchestrator-handoff.json`.
- The dead `reflection` field is fully retired from core and the memory extension; no dangling
  reads remain, and the live event-type row is honestly marked producerless rather than silently
  orphaned.
- The orchestration conclusion stage (a separate, dependent backlog item) now has a real,
  structured evidence base to derive its three output channels from, across every task that runs
  through this agent system from this point forward.

## Follow-ups

- A machine-checkable `context/schemas/issue-log-schema.json` is deliberately absent (breaking
  the prose+schema pairing convention `events-format.md`/`handoff-schema.md` both follow) —
  recorded as a low-cost follow-up in `issue-log.md` itself, not solved here.
- `scripts/update-phase-status.sh`'s greedy `sed -i "${line_number}s/\[.*\]/[...]/"` pattern
  (line ~322) corrupts a phase heading whose own title contains a literal square-bracket pair
  (encountered and manually fixed during this task's own Phase 7 — see
  `issues.jsonl`'s `tooling bug or gap` entry for the full detail and a suggested anchored-pattern
  fix). Not fixed here; out of this task's scope.
- `scripts/tests/run-all.sh`'s full sweep carries 5 failing suites, 2 of which (`test-orchestrate-cycle-plan.sh`,
  `test-typst-element-lint.sh`) are flagged NEW by its own baseline tracking despite being
  pre-existing and unrelated to this task — the baseline-tracking file itself may need
  refreshing, a separate concern from this task.
- The conclusion stage's own eventual implementation (the task this one is a declared dependency
  of) is the first real consumer that will exercise `issues.jsonl` at scale; this task
  deliberately stops at CAPTURE ONLY.

## References

- Plan: `specs/329_per_task_issue_log_contract_writer_and_threading/plans/01_issue-log-writer-threading.md`
- Research report: `specs/329_per_task_issue_log_contract_writer_and_threading/reports/01_issue-log-contract-writer-threading.md`
- Progress files: `specs/329_per_task_issue_log_contract_writer_and_threading/progress/phase-{1..9}-progress.json`
- This task's own dogfooded capture log: `specs/329_per_task_issue_log_contract_writer_and_threading/issues.jsonl`
