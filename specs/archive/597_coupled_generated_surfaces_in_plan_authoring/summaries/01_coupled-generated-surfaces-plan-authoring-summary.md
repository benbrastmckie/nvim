# Implementation Summary: Task #597

- **Task**: 597 - Coupled generated surfaces in plan authoring
- **Status**: [COMPLETED]
- **Started**: 2026-11-12T06:52:55Z
- **Completed**: 2026-11-12T18:40:16Z
- **Effort**: 7 hours
- **Dependencies**: None (task 596 `generated_file_scope_vs_readonly_risk` depends ON this task; task 599 shares `plan-format.md` territory with no dependency edge)
- **Artifacts**: plans/01_coupled-generated-surfaces-plan-authoring.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Both plan-authoring defects named in the task description are fixed in the source store
(`agent-system/extensions/`, re-derived per-extension from `.claude-extensions.json`). Defect A
(a coupled-generated-surface declaration gap) is closed with a repo-agnostic obligation in
`plan-format.md`, a `task_type`-gated reach mechanism in `planner-agent.md`, a named
cross-domain-shared-agent hazard in `context-discovery.md`, a documented declaration schema in
`repo-level-declarations.md`, and an advisory, fail-open `coupled_generated_surfaces` check in
`validate-artifact.sh` with seven new fixtures. Defect B (the `longFile` linter's documented
acceptance window) is corrected in `plan-authoring-gate-collisions.md`'s Condition 7, verified
against the pinned toolchain's own Mathlib source rather than the two cited data points alone.

## What Changed

- `agent-system/extensions/core/context/formats/plan-format.md` — new "Coupled-generated-surface
  declaration obligation" subsection (between "Whole-tree-claim declaration rule" and "Consumers
  of this heading contract") and its paired "### Enforcement level (Coupled generated surfaces)"
  subsection.
- `agent-system/extensions/lean/context/project/lean4/patterns/plan-authoring-gate-collisions.md`
  — Condition 7 rewritten with the verified `candidate = max(defValue, (lines/100)*100 + 200)`
  rule and the incremental re-tightening consequence, confirmed against the pinned toolchain's
  own `Mathlib/Tactic/Linter/Style.lean`; one pointer sentence added to Condition 1.
- `agent-system/extensions/core/agents/planner-agent.md` — Stage 4 checklist items 13
  (task_type-gated domain plan-authoring-gotchas lookup) and 14 (coupled-generated-surface
  declaration), plus a matching Critical Requirements MUST NOT entry.
- `agent-system/extensions/core/context/patterns/context-discovery.md` — new
  "Cross-Domain-Shared-Agent Hazard in `agents[]`" subsection.
- `agent-system/extensions/core/context/standards/repo-level-declarations.md` — new
  `coupled_generated_surfaces` schema section (field contract, bash-glob matching semantics,
  fail-open table, asymmetry against `derived_artifact_probes`, non-unification rationale,
  single-consumer inline-reader decision).
- `agent-system/extensions/core/scripts/validate-artifact.sh` — inline, fail-open
  `coupled_generated_surfaces` reader (repo-root walk from the artifact's own directory, then
  `$(pwd)`) and an advisory per-phase declaration-completeness check in the existing plan loop,
  reusing the authoring-shape scan's own `_ftm_block` capture.
- `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` — seven new CGS
  fixtures: matched-and-missing warning, no-false-positive, absent-key fail-open, malformed-entry
  drop, `--strict` promotion, no-trigger-match, and the `note` field surfacing.
- `agent-system/extensions/core/index-entries.json`,
  `agent-system/extensions/lean/index-entries.json` — `line_count` reconciliation for the edited
  context files (deploy-written; two of the four entries landed via concurrent sibling-task
  commits rather than this task's own, recorded as an observation, not re-committed).
- Deployed `.claude/` tree regenerated from the source store (disposable artifact, not committed
  separately).

## Decisions

- The research report's proposed `scripts/lib/coupled-surface-lib.sh` was rejected in favor of an
  inline reader in `validate-artifact.sh`: a new library file requires a `core/manifest.json`
  entry, and that manifest was inside a concurrent sibling task's declared `file_scope` this
  cycle. A header comment records the single-consumer decision and its promotion trigger (a
  second consumer).
- The reach mechanism for a domain's plan-authoring gotchas is a `task_type`-gated lookup
  performed inside the shared `planner-agent.md` itself, not an `agents[]` entry on the domain's
  index entry — the adaptive query's OR semantics make a shared agent in `agents[]` leak that
  domain's content into every other domain's dispatch.
- `lean/index-entries.json` needed no edit: its existing entry already carries
  `task_types: ["lean4"]` and the `plan-authoring` keyword the new lookup keys on.

## Plan Deviations

- None in delivered content. Two inaccuracies were found in the plan's own Verification bullets
  (not in the implemented file content) and are recorded via the issue log rather than hand-edited
  or silently treated as passing: Phase 2's "a declared 3300 against 3200 lines is rejected"
  claim is backwards under the corrected formula (3300 is in fact accepted), and Phase 6's
  "six source-store files" undercounts by one (the correct count is seven, matching the plan's
  own Artifacts & Outputs section).
- A real defect in this task's own first-draft implementation was caught and fixed before
  landing: `_cgs_entries()`'s required-argument guard (`${1:?msg}`) crashed `validate-artifact.sh`
  outright on the ordinary empty-`repo_root` fail-open case (every isolated test fixture), fixed
  to `${1:-}` to match the sibling reader's own tolerance. Caught by running the phase's own named
  Tier Justification suites, which went from 5 failed to 0 failed after the fix.
- A field-by-field cross-check in Phase 6 found that Phase 5's implementation validated the
  schema's optional `note` field but never surfaced it in the warning; fixed before the deploy,
  with a new fixture.

## Verification

- Build: N/A (meta task, no build step)
- Tests: `test-validate-artifact.sh` 146 passed, 0 failed (7 new CGS fixtures). The four
  Phase 5 Tier Justification suites (`test-gate-out-derived-staleness.sh`,
  `test-gate-out-repair-reporting.sh`, `test-orchestrate-cycle-postflight.sh`,
  `test-validate-artifact.sh`) pass except the one pre-existing, already-known
  `test-orchestrate-cycle-postflight.sh` failure.
- Files verified: Yes — all six edited source-store files confirmed byte-identical in the
  deployed tree.
- Inertness: confirmed byte-identical `validate-artifact.sh` output, pre- and post-change, on
  this task's own plan artifact (this repository declares no `coupled_generated_surfaces` key).
- Complete gate set (`verify-deploy.sh`): 4 of 44 checks failed, all four attributed as
  pre-existing or unrelated to this task (none name a file this task edited) — see the issue log
  for the full per-finding account (gate 8's three NEW-classified suites: two confirmed
  parallel-mode flakes that pass standalone, one unrelated sapience-extension timing test; gate
  10's timeout matches an already-documented host-slowness pattern; the orchestrator
  context-budget overage is already triaged as EXPECTED in `known-failures.txt`).
- shellcheck: 0 findings on both edited scripts (one deliberate `SC2053` disable for the
  intentional unquoted glob match).
- Task-reference and record-versioning lints: 0 BLOCKING findings against any file this task
  edited.

## Impacts

- Future Lean plan-authoring dispatches now surface `plan-authoring-gate-collisions.md`
  automatically via the `task_type`-gated lookup, closing the reach gap that let the class recur
  after a prior pruning sweep.
- Any repository that later declares `coupled_generated_surfaces` in its `.claude-extensions.json`
  gets an advisory, fail-open completeness check on every plan validation; this repository's own
  behavior is unaffected (it declares nothing).
- The corrected `longFile` Condition 7 removes a documented-wrong acceptance window that could
  mislead a future plan author into a baseline value the linter would still flag.

## Follow-ups

- Task 596 (`generated_file_scope_vs_readonly_risk`), which depends on this task, can now proceed
  — it refines the declaration this task establishes with the generator-written-vs-hand-edited
  read-only category distinction, deliberately left out of this task's scope.
- The `test-sapience-capture.sh` retry-clamp timing failure (recorded in the issue log, class
  "pre-existing/attributed") is unrelated to this task's scope and is not yet in
  `known-failures.txt`; a follow-up task should triage and either fix or formally accept it.
- The two plan-authoring inaccuracies found in this plan's own Verification bullets (Phase 2's
  "3300 rejected" claim, Phase 6's "six source-store files" undercount) are recorded in the issue
  log; no action taken on the plan file itself since both are in Verification prose, not Tasks
  checklist items.

## References

- `specs/597_coupled_generated_surfaces_in_plan_authoring/reports/01_coupled-generated-surfaces-plan-authoring.md`
- `specs/597_coupled_generated_surfaces_in_plan_authoring/plans/01_coupled-generated-surfaces-plan-authoring.md`
- `specs/597_coupled_generated_surfaces_in_plan_authoring/issues.jsonl`
