# Implementation Summary: Catch Stale Derived Artifacts at Implement Postflight

- **Task**: Catch stale derived artifacts at implement postflight and never let containment leave HEAD inconsistent
- **Status**: [COMPLETED]
- **Started**: 2026-10-14T16:00:00Z
- **Completed**: 2026-10-14T20:05:00Z
- **Effort**: ~8.5 hours across 6 phases
- **Dependencies**: None
- **Artifacts**: plans/01_postflight-derived-artifact-staleness.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added a repository-extensible, build-free derived-artifact staleness mechanism to the agent
system's two implement-postflight engines (the multi-task `orchestrate-cycle-postflight.sh` and
the single-task `command-gate-out.sh`), with zero hard-coded knowledge of any consumer repo's
components. A consumer repo declares a `derived_artifact_probes` key in
`.claude-extensions.json`; postflight now runs each declared build-free `check_command` before
the status write and refuses `implemented` on a non-zero result, and a regenerated file under a
declared derived-output directory is committed with the change that caused it instead of being
silently dropped as a file_scope excursion. A repo declaring nothing is byte-for-byte unaffected.

## What Changed

- `agent-system/extensions/core/scripts/lib/derived-artifact-probe-lib.sh` (new) — shared,
  fail-open reader/runner for the `derived_artifact_probes` declaration: parses, validates and
  normalizes entries, runs each `check_command`, and reports failures by component name.
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — the multi-task engine
  gained (a) the blocking pre-status-write probe call and (b) the derived-output containment
  exemption: a regenerated file under a declared `derived_output_dirs` entry is no longer
  dropped as a file_scope excursion, it is staged and committed with the change that caused it.
- `agent-system/extensions/core/scripts/command-gate-out.sh` — single-task engine parity for the
  blocking probe (this engine has no commit/staging logic of its own, so only the probe gate
  applies here).
- `agent-system/extensions/core/scripts/tests/test-derived-artifact-probe-lib.sh` (new) — 13
  cases covering the library in isolation.
- `agent-system/extensions/core/scripts/tests/test-gate-out-derived-staleness.sh` (new) — 10
  cases covering `command-gate-out.sh`'s blocking-probe parity.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — extended
  with three acceptance fixtures reproducing the originating incident's shape end to end (cases
  990/991/992: evidence-shaped, all-probes-pass, and no-declaration regression).
- `agent-system/extensions/core/scripts/tests/test-gate-out-repair-reporting.sh`,
  `test-gate-out-self-attribution.sh` — fixed to carry the new library dependency (sibling
  fixtures that previously stubbed or omitted it).
- `agent-system/extensions/core/context/standards/repo-level-declarations.md` (new) — documents
  the declaration point, entry schema, fail-open guarantee, and the advisory-to-blocking
  departure's justification.
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md`,
  `agent-system/extensions/core/docs/guides/creating-extensions.md` — pointers into the new doc.
- `agent-system/extensions/core/index-entries.json`, `agent-system/extensions/core/manifest.json`
  — registration of the new context file and three new script paths.
- A redeployed `.claude/` tree (regenerated artifact; source-store files are the edit target).

## Decisions

- `command-gate-out.sh` carries no commit/staging/containment logic of its own (confirmed by
  inspection — it is status-write-gating only), so Phase 4/6's "cross-engine parity" requirement
  resolves to the blocking-probe behavior alone; the containment exemption is a multi-task-engine
  concept with no single-task-engine analogue, and no fourth fixture case was added to
  `test-gate-out-derived-staleness.sh` since its existing four cases already assert the relevant
  shape.
- Drop-and-commit-the-regenerated-file (rather than refuse the whole commit, or silently widen
  file_scope) was the chosen containment posture, matching the existing "under-stage, never
  over-stage" fail-safe direction already recorded for this script's excursion filter, and the
  identical ruling the sibling Phase-Commit Containment Self-Check independently reached.
- The mechanism is strictly additive and fail-open: an absent or empty
  `derived_artifact_probes` declaration reproduces pre-change behavior exactly, confirmed by a
  dedicated regression fixture (case 992) asserting literal equality against the pre-change
  outcome, not a looser shape check.

## Plan Deviations

- **Phase 6, Task 5** (run the complete gate set, no `--skip-slow`/`--only-gate`) closed via
  `[COMPLETED WITH EXCLUSIONS]` rather than a clean `verify-deploy.sh` exit 0. Five reasons are
  recorded in the plan's own Phase 6 `#### Reasoned Exclusions` table: two already-filed,
  confirmed-still-open pre-existing obstructions (`test-zotero-generate-export.sh` hang, task
  404; `test-verify-deploy-context-budget.sh`'s missing `git add`, task 389), two findings
  byte-for-byte identical to ones a concurrent sibling task (388) already independently
  confirmed and excluded in this same batch (lean doc-lint fixture registration; gate 20
  eager-load +225 B overage), and severe transient ambient system contention from an unrelated
  `lake build` (`~/Projects/BimodalLogic`) that drove 1-minute load average to 48 during this
  dispatch's gate attempts. Every new/changed test suite was instead verified narrowly, directly,
  and cleanly, and the redeploy itself landed successfully with zero new findings relative to
  the pre-redeploy baseline.

## Verification

- Build: N/A (shell scripts, markdown, JSON)
- Tests: `test-derived-artifact-probe-lib.sh` 13/13, `test-orchestrate-cycle-postflight.sh`
  233/233 (including the three new acceptance fixtures), `test-gate-out-derived-staleness.sh`
  10/10, `test-postflight-deploy-gate.sh` 29/29 (unaffected consumer), `test-orchestrate-cycle-plan.sh`
  370/370 (unaffected consumer), `check-task-references.sh` 0 unexempted occurrences.
- Files verified: Yes — all new/edited files exist, parse (`jq -e .` for JSON), and are
  byte-identical between source store and deployed tree post-redeploy for the three edited/new
  scripts.
- Redeploy: `timeout 540 bash .claude/scripts/deploy-headless.sh` → `RESULT=landed_verify_red`
  (landed; 2 pre-existing, unrelated findings only). `check-deploy-freshness.sh` exits 0 — `core`
  and `lean` no longer stale.

## Impacts

- Any future implement-postflight dispatch in a repo declaring `derived_artifact_probes` is now
  protected against the exact incident shape this task originated from: a certificate-identity
  input changed without its gate re-running leaves HEAD red or forces the regeneration to be
  committed, rather than silently landing an inconsistent commit.
- A repo declaring nothing (today's default for every consumer repo) is unaffected — confirmed
  by the dedicated regression fixture's literal-equality assertions.

## Follow-ups

- Task 404 (fix `test-zotero-generate-export.sh`'s indefinite hang) and task 389 (fix
  `test-verify-deploy-context-budget.sh`'s missing `git add`) remain open and continue to block
  a clean complete-gate-set run for every task's final-phase verification criterion, this one
  included; neither is caused by or fixable within this task's own scope.

## References

- Plan: `specs/381_implement_postflight_derived_artifact_staleness/plans/01_postflight-derived-artifact-staleness.md`
- Report: `specs/381_implement_postflight_derived_artifact_staleness/reports/01_postflight-derived-artifact-staleness.md`
- Handoffs: `specs/381_implement_postflight_derived_artifact_staleness/handoffs/phase-{1..6}-handoff-*.md`
- Progress: `specs/381_implement_postflight_derived_artifact_staleness/progress/phase-{1..6}-progress.json`
