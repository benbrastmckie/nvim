# Implementation Summary: Task #312

- **Task**: 312 - Backlog reconciliation as a required task-creation component: compare every proposed task against the open backlog before it is written
- **Status**: [COMPLETED]
- **Started**: 2026-11-03T17:30:00Z
- **Completed**: 2026-11-03T22:50:00Z
- **Effort**: ~15 hours
- **Dependencies**: 165 (completed), 282 (completed), 300 (completed), 344 (completed) — all cleared
- **Artifacts**: plans/01_backlog-reconciliation-task-creation.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Built a two-layer backlog-reconciliation mechanism for task creation: a single shared matcher
(`scripts/audit-task-proposals.sh`) that compares a proposal against the union of open and
closed records (live non-terminal tasks, live `completed` tasks, and the archive's
`completed_projects`/`archived_projects`/`abandoned_projects`) and emits a structured verdict,
plus an enforcement gate inside `scripts/state-write.sh` that refuses a `specs/state.json` write
introducing a new `active_projects` entry with no recorded audit verdict or explicit override.
A Bash-matcher structural backstop hook closes the remaining bypass (reverting to a raw `jq`
write). All seven task-creation surfaces in the codebase (`/meta`, `/task`, `/fix-it`, `/spawn`,
`/review`, `/errors`, and `meta-builder-agent`) now call the shared matcher before confirmation
and forward the resulting verdict to the write.

## What Changed

- `agent-system/extensions/core/context/patterns/backlog-reconciliation.md` — new canonical
  contract document: the two-pass model (mechanical file-footprint + semantic token-overlap),
  the closed verdict vocabulary, the False-Negative Posture, and the Non-Goals.
- `agent-system/extensions/core/scripts/audit-task-proposals.sh` — new shared matcher (D1's
  name, superseding the dispatch's original `audit-open-tasks.sh`). Two call shapes
  (single-proposal flags; `--proposals-file`/stdin set mode), a four-source corpus union, the
  mechanical pass (reusing `lib/file-scope-overlap.sh`'s predicate unmodified) and the semantic
  pass (recall-biased token-overlap shortlist, threshold 0.4), and a new `--id CORRELATION_ID`
  flag (added during wiring once every single-mode caller needed it — the original design
  hardcoded `id: null`).
- `agent-system/extensions/core/scripts/tests/test-audit-task-proposals.sh` — hermetic fixture
  suite reproducing the motivating incident (309-analog subset-of-302, 310-analog
  duplicate-of-272 caught via the semantic pass with exactly one shared path, 311-analog
  genuinely-new) plus the extended closed-record cases.
- `agent-system/extensions/core/scripts/state-write.sh` — new `--audit-verdict FILE` /
  `--audit-override REASON` flags and exit 5: a write introducing a new `active_projects` entry
  with no covering verdict/override is refused, target file untouched, on both the real-write
  and `--dry-run` paths. Coverage recorded durably as `.audit_verdict`/`.audit_override` on the
  new entry.
- `agent-system/extensions/core/hooks/validate-task-creation-audit.sh` — new Bash-matcher
  structural backstop: detects a write-shape targeting a `state.json`-named path that also
  mentions `active_projects` and was not routed through `state-write.sh`; refuses with exit 2.
  Registered in `root-files/settings.json` and `merge-sources/settings-hooks.json`, and in
  `manifest.json`'s `provides.hooks`.
- `agent-system/extensions/core/scripts/tests/test-validate-task-creation-audit.sh` — new
  fixture suite for the backstop hook.
- `agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md` — new
  `### 4b. Backlog Reconciliation (Required)` component (between 4a and Component 5), a
  **Backlog Check** column added to Component 7's confirmation table, and the Current
  Compliance Status table updated to reflect actual wiring.
- Seven creation surfaces wired to call the matcher before confirmation and forward the verdict:
  `agent-system/extensions/core/context/workflows/meta-interview.md` (new Stage 4.6 /
  Step 4.5 — the real call site `skill-meta/SKILL.md` delegates to),
  `agent-system/extensions/core/skills/skill-meta/SKILL.md` (delegation-context field),
  `agent-system/extensions/core/agents/meta-builder-agent.md` (forwards via `--audit-verdict`;
  also converted its number allocation from a precomputed, race-prone scheme to incremental
  `--allocate-into`),
  `agent-system/extensions/core/commands/task.md` (new Step 5.5, both Create Task Mode and
  Expand Mode — the latter via `context/patterns/task-expand-mode.md`'s existing reuse of
  Create Task Mode's pattern — with a non-interactive escape valve for a programmatic caller),
  `agent-system/extensions/core/skills/skill-fix-it/SKILL.md` (new Step 8.2d, with its own
  AskUserQuestion since this skill has no dispatched agent in its creation path; also converted
  to incremental allocation),
  `agent-system/extensions/core/skills/skill-spawn/SKILL.md` (new Stage 9.6; rendered in the
  Stage 17 return summary since this skill's postflight has no confirmation gate),
  `agent-system/extensions/core/commands/review.md` (new Step 3.5),
  `agent-system/extensions/core/commands/errors.md` (new Step 3.6, non-interactive, exercising
  `/task`'s escape valve since `/errors` delegates creation to a literal `/task "..."` call).
- `agent-system/extensions/core/manifest.json`, `agent-system/extensions/core/index-entries.json`
  — registration and line-count updates for all new/grown files.
- `agent-system/extensions/core/scripts/test-state-write-concurrency.sh`,
  `agent-system/extensions/core/scripts/tests/test-force-phases.sh`,
  `agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh` — regression fixes
  for pre-existing suites whose own fixtures create `active_projects` entries without audit
  evidence, and an allowlist entry for the new backstop hook's own deliberate dirty-fixture text.
- `specs/state.json` — this task's own `file_scope` extended across the implementation as real
  touch points were discovered (standard incremental widening, not a scope change).

## Decisions

- **Enforcement anchor**: inside `scripts/state-write.sh` (the real single writer), with the
  Bash-matcher hook as a structural backstop only — research's measured finding that the
  dispatch's original option (a), a `Write|Edit` PreToolUse matcher, would be a no-op hook since
  `specs/state.json` is mutated via Bash-invoked `jq`/`state-write.sh`, not the Write/Edit tools.
- **Verdict acquisition stays at the skill/command layer**, never inside a dispatched agent —
  reusing the existing Foreground Requirement pattern rather than inventing a second interactive
  gate.
- **`--audit-verdict` matches on `project_name`, not `project_number`** — the real number is
  rarely known at audit time (before `--allocate-into` allocates it); the caller sets the
  verdict's `proposal.id` to the slug it is about to use.
- **`scope-blind` is emitted unconditionally** for every corpus record declaring no `file_scope`,
  per the dispatch's explicit instruction — a documented noise trade-off, with display
  compaction (never suppression) left to each calling surface.
- **`narrow-open` is never auto-emitted** by the mechanical classifier — it is not mechanically
  distinguishable from `overlaps-open` by containment alone; both remain valid vocabulary a
  human/caller may still choose.
- **`/errors`' non-interactivity is preserved** via a load-bearing cross-file contract: `/task`'s
  Step 5.5 skips its own audit re-run and its own `AskUserQuestion` when a caller has already set
  `$backlog_audit`, which `/errors`' Step 3.6 exercises by pre-resolving the audit itself.

## Plan Deviations

- **Phase 1**: index entry placed under subdomain `patterns` (directory-matching convention)
  rather than the dispatch's literal `orchestrator` subdomain, which does not exist anywhere in
  `index-entries.json`.
- **Phase 2**: converted `meta-builder-agent.md`'s and `skill-fix-it/SKILL.md`'s upfront
  `base_num + position` task-number precompute to incremental, write-time allocation via
  `--allocate-into` — a precomputed map is structurally incompatible with that flag's
  derive-at-write-time contract.
- **Phase 3**: the mechanical classifier never auto-emits `narrow-open` (see Decisions above).
- **Phase 7**: registered the backstop hook in `merge-sources/settings-hooks.json` in addition to
  `root-files/settings.json` — the latter is install-once per its own header comment; the former
  is what actually reaches this already-deployed repo on resync.
- **Phase 8**: `skill-meta/SKILL.md`'s literal call site lives in `context/workflows/meta-interview.md`
  (the file it already delegates all interview logic to, including the pre-existing Component 4a
  check); added `--id` to `audit-task-proposals.sh`'s single-proposal mode (originally hardcoded
  `id: null`, making `--audit-verdict` matching impossible for every single-mode caller); added
  the non-interactive escape valve to `/task`'s Step 5.5 for `/errors`' sake.
- **Phase 9**: the unfiltered `scripts/tests/run-all.sh` leg of the full gate set was deferred to
  the batch-level stage per this dispatch's own Batch Gate Deferral section (this task is one of
  several co-dispatched `implement`-phase tasks in one `/orchestrate` batch). Discharged against
  a scoped `--only` invocation covering the 8 suites this task's phases touched or regressed
  (all pass); `verify-deploy.sh` itself ran unscoped via `deploy-headless.sh`'s own verify step.

## Verification

- Build: N/A (no compiled artifact)
- Tests: Passed — `test-audit-task-proposals.sh` (17 assertions), `test-validate-task-creation-audit.sh`
  (9 assertions), plus the four pre-existing `test-state-write-*.sh` suites and `test-force-phases.sh`,
  all green against the deployed tree. Scoped `run-all.sh --only` (8 suites): 8 passed, 0 failed.
- Files verified: Yes — all new/modified files confirmed present and correct in both the source
  store and the deployed `.claude/` tree.
- `verify-deploy.sh` (unscoped, via `deploy-headless.sh`): 35 of 37 checks pass; the 2 failures
  are pre-existing and unrelated to this task (see Follow-ups).
- Acceptance: both the open-backlog and closed-record acceptance checks verified live against
  the deployed tree and real repository state (see Decisions/Plan Deviations and the Phase 9
  checklist in the plan file for exact project numbers and verdicts).

## Impacts

- Every future task created through `/meta`, `/task`, `/fix-it`, `/spawn`, `/review`, or
  `/errors` is now compared against the full open+closed backlog before creation, with every
  non-`genuinely-new` finding surfaced to a human rather than silently created.
- `scripts/state-write.sh` callers elsewhere in the codebase that introduce a new
  `active_projects` entry must now supply `--audit-verdict` or `--audit-override`, or the write
  is refused (exit 5). This was the main regression risk this implementation managed directly
  (three pre-existing suites fixed; see Plan Deviations).
- `meta-builder-agent.md` and `skill-fix-it/SKILL.md` no longer precompute task numbers before
  writing — numbers are now allocated incrementally, closing a latent race condition as a side
  effect of wiring in the audit.

## Follow-ups

- Four pre-existing, unrelated gaps were observed during Phase 9's full gate sweep and recorded
  non-fatally via `issue-record.sh` rather than fixed (out of this task's `file_scope`):
  1. `check-extension-docs.sh`: the `specs` extension has no `manifest.json`/`README.md`.
  2. `lint-task-lookup-adoption.sh`: 5 hand-rolled lookups in
     `scripts/test-state-write-concurrency.sh`, confirmed to predate this task.
  3. `validate-wiring.sh`: 41 "Missing context file" FAILs for `memory`/`nix`/`neovim` context
     paths that physically exist on disk — likely a validator defect, not investigated further.
  4. `check-record-versioning.sh`: 3 BLOCKING occurrences, all in
     `lua/neotex/plugins/tools/himalaya/docs/` (unrelated Neovim plugin docs).
- The unfiltered `scripts/tests/run-all.sh` run (172 suites) is deferred to this `/orchestrate`
  batch's end-of-cycle stage, per the Batch Gate Deferral directive — not yet independently
  confirmed green at full breadth by this dispatch.
- `/task --review` mode (a distinct mode from Create Task Mode/Expand Mode) remains unwired,
  honestly marked `No (not yet wired)` in the Current Compliance Status table — out of this
  task's declared scope.
- Task 421 (`retarget_distill_meta_as_evidence_consumer`) can now consume
  `scripts/audit-task-proposals.sh`'s `--proposals-file` set-mode call shape directly, with no
  allocated task number and no enforcement hook in the path, as the dispatch's "Known downstream
  consumer" note anticipated.

## References

- Plan: `specs/312_backlog_reconciliation_required_at_task_creation/plans/01_backlog-reconciliation-task-creation.md`
- Report: `specs/312_backlog_reconciliation_required_at_task_creation/reports/01_backlog-reconciliation-task-creation.md`
- Canonical contract: `agent-system/extensions/core/context/patterns/backlog-reconciliation.md`
- Progress files: `specs/312_backlog_reconciliation_required_at_task_creation/progress/phase-{1..9}-progress.json`
- Handoffs: `specs/312_backlog_reconciliation_required_at_task_creation/handoffs/`
