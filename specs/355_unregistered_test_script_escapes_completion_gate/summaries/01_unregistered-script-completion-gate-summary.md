# Implementation Summary: Task #355

- **Task**: 355 - Unregistered test script escapes the completion gate
- **Status**: [COMPLETED]
- **Started**: 2026-10-08T09:40:00Z
- **Completed**: 2026-10-08T11:00:00Z
- **Effort**: ~7 hours
- **Dependencies**: 272, 351 (territory-serialized predecessors; both already landed)
- **Artifacts**: plans/01_unregistered-script-completion-gate.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md,
  shell-strict-mode.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Landed both recommended fixes for the escape that let an unregistered `scripts/tests/test-*.sh`
reach `[COMPLETED]` undetected: **(a)** `sync-manifest-scripts.sh`, a `--check`/`--write` repair
script that derives each extension's `provides.scripts` array from its own tracked `scripts/`
tree, and **(b)** a self-attribution screen (`deploy_baseline_self_attributable_findings`,
`scripts/lib/deploy-baseline-lib.sh`) wired into the temporally-pre-existing branch (c) at both
baseline-tolerant completion call sites (`command-gate-out.sh`'s `rc==6` handler and
`orchestrate-cycle-plan.sh`'s inter-cycle redeploy checkpoint). All six plan phases completed;
redeployed; `verify-deploy.sh` passes 35/35 with zero new findings relative to the Phase-3
baseline snapshot; `run-all.sh` fully green.

## What Changed

- `agent-system/extensions/core/scripts/sync-manifest-scripts.sh` (new) — `--check`/`--write`
  repair for `provides.scripts`, modelled on `generate-context-line-counts.sh`; surgical,
  line-oriented array rewrite that inserts each missing entry at its locally alphabetical
  position without resorting or otherwise touching any existing line.
- `agent-system/extensions/core/scripts/check-extension-docs.sh` — Rule Q
  (`check_undeclared_scripts`) gains a repair-pointer line (prefix deliberately matching neither
  `"  FAIL: "` nor `"["*"]"`, so `verify-deploy.sh` gate 3's FINDING extractor is unaffected) and
  a header note recording the `index-entries.json` asymmetry.
- `agent-system/extensions/core/manifest.json` — registered `sync-manifest-scripts.sh` and the
  two new test suites via `sync-manifest-scripts.sh --write` itself (self-demonstrating).
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` — one-line entry
  for the new script.
- `agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh` — extracted the shared
  `_deploy_baseline_partition_findings` helper; re-expressed `deploy_baseline_unattributable_findings`
  as a thin wrapper (contract unchanged, existing suite passes unedited); added the new exported
  `deploy_baseline_self_attributable_findings`; documented the deliberate fail-safe-direction
  asymmetry between the two polarities; declared `SELF_ATTRIBUTION_GATE_MODE` once (hard default)
  for both call sites to share.
- `agent-system/extensions/core/scripts/command-gate-out.sh` — self-attribution screen in the
  `rc==6` branch (c), before the single postflight re-attempt; withholds completion and leaves
  status unchanged on a self-attributed finding.
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — per-task self-attribution
  screen in checkpoint branch (c); the `deploy_pending_tasks_json` derivation loop now also
  captures each task's own `modified_files`; a self-attributed task is subtracted from
  `post_deploy_reconcile_json` (stays `implementing`) while every other deploy-pending task in
  the same batch still reconciles; the batch-level verdict and existing
  `verify_deploy_baseline_notices` entry are otherwise unchanged, now carrying
  `self_attribution_notices`/`self_attributed_withheld` fields.
- `agent-system/extensions/core/scripts/tests/test-manifest-scripts-sync.sh` (new) —
  `--check`/`--write` behavior, `deprecated/*` exemption, declared-but-absent reporting (never
  auto-removed), non-canonical-manifest formatting preservation, and Rule Q's own first-ever
  fixture coverage. 16 cases.
- `agent-system/extensions/core/scripts/tests/test-deploy-baseline-lib.sh` — 6 new cases for
  `deploy_baseline_self_attributable_findings` and the polarity pair; all 11 pre-existing cases
  pass unedited (the refactor's regression proof).
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — new Arm G in
  Group 29: a two-candidate deploy-pending batch where only the self-attributed candidate is
  withheld; plus a `SELF_ATTRIBUTION_GATE_MODE=off` negative-control sub-case. 8 new assertions;
  full suite 359/359.
- `agent-system/extensions/core/scripts/tests/test-gate-out-self-attribution.sh` (new, focused
  sibling to `test-gate-out-repair-reporting.sh`) — the `rc==6` branch-(c) withheld-re-attempt
  case, a not-self-attributed control, and the `mode=off` negative control, via call-counting
  stubs for `update-task-status.sh`/`deploy-headless.sh`/`verify-deploy.sh`. 11 cases.
- `agent-system/extensions/core/docs/guides/creating-extensions.md` — states the
  `provides.scripts` registration requirement, the `index-entries.json` contrast, and records
  that `provides.agents`/`provides.commands`/`provides.context` have **no** disk-driven
  pre-deploy check at all (worse than `provides.scripts`, not better).
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — documents
  the self-attribution screen as a narrowing filter on branch (c), why that branch needed one,
  and corrects the historical `pre=N post=M new=0` framing (identity-based throughout, never
  count-based — there was nothing to convert).
- `agent-system/extensions/core/index-entries.json` — regenerated `line_count` for the edited
  guardrails pattern file.
- Redeployed `.claude/` tree (`RESULT=landed_verify_clean`, 34 inline checks).

## Decisions

- **Insertion, never resort**: `sync-manifest-scripts.sh --write` inserts a missing entry at its
  locally alphabetical position relative to the EXISTING (not necessarily globally sorted) array,
  reproducing every untouched line byte-for-byte. The real `provides.scripts` arrays in this
  codebase are not strictly alphabetical (several interleave a script with its own test), so a
  full resort would have produced a large, unreviewable diff; this approach keeps every `--write`
  a minimal, single-purpose diff.
- **`SELF_ATTRIBUTION_GATE_MODE` declared once, in the shared library**, not duplicated per call
  site — the two sites cannot drift to different defaults, mirroring why `deploy-baseline-lib.sh`
  itself exists (to stop the two call sites' core algorithm from drifting apart again).
- **Self-attribution narrows branch (c) only; it never widens into a batch-wide defer.** Per the
  plan's Non-Goals, only a task's own `modified_files` may newly block its own promotion; a
  finding attributable to a different task in the same batch is still waved through exactly as
  before.
- **A focused sibling test suite instead of extending `test-gate-out-repair-reporting.sh`
  directly** (Phase 4): that suite's `build_fixture_repo` copies the REAL deployed
  `update-task-status.sh` and its full dependency chain to exercise genuine completion-deploy-gate
  conditions end to end. Reaching `rc==6` through it needs genuine deploy-staleness state;
  `test-gate-out-self-attribution.sh` uses minimal call-counting stubs instead, which the plan's
  own Phase 4 task explicitly sanctions as a fallback.

## Plan Deviations

- **Phase 2** (Scope Hypothesis): assumed exactly three live consumers of `deploy-baseline-lib.sh`.
  A fourth was found by re-grepping (`test-verify-deploy-context-budget.sh`, which calls only
  `deploy_baseline_new_findings`, unaffected by this phase's refactor) and included in
  verification regardless.
- **Phase 3**: `SELF_ATTRIBUTION_GATE_MODE` declared once in `deploy-baseline-lib.sh` rather than
  duplicated in both call-site files (see Decisions above).
- **Phase 4**: added a focused sibling suite (`test-gate-out-self-attribution.sh`) instead of
  extending `test-gate-out-repair-reporting.sh`, per that task item's own explicitly sanctioned
  fallback (see Decisions above). The negative proof (revert the Phase 3 screen, confirm the new
  fixtures FAIL) was fully reproduced end-to-end for `command-gate-out.sh`'s branch (c) via a
  direct comparison against the pre-Phase-3 committed file in an isolated scratch copy (confirmed:
  without the screen, the self-attributed task is wrongly promoted — 2 postflight calls instead
  of the correct 1). For `orchestrate-cycle-plan.sh`, an equivalent from-scratch revert
  reproduction was started but not finished (the dependency-chain reconstruction for
  `reconcile-task-status.sh` was disproportionately expensive for a second proof of the SAME
  shared library function already proven absent-of-screen-fails on the other call site); the
  already-integrated `SELF_ATTRIBUTION_GATE_MODE=off` negative-control sub-case in Arm G serves as
  that call site's live negative control instead, using the real production escape hatch rather
  than a second source revert.

## Verification

- Build: N/A (shell scripts, no compiled build step)
- Tests: Passed — `test-manifest-scripts-sync.sh` 16/16, `test-deploy-baseline-lib.sh` 17/17
  (11 pre-existing unedited + 6 new), `test-orchestrate-cycle-plan.sh` 359/359 (351 pre-existing
  + 8 new Arm G), `test-gate-out-self-attribution.sh` 11/11, `test-gate-out-repair-reporting.sh`
  21/21 (unedited). Full `tests/run-all.sh` battery green via `verify-deploy.sh` gate 8.
- Files verified: Yes — `sync-manifest-scripts.sh --check` clean across all 9 extensions with a
  `scripts/` tree; `generate-context-line-counts.sh --check` clean; `check-task-references.sh`
  clean on both Phase 5 doc edits.
- `shellcheck`: every added/modified `.sh` file's finding count matches its pre-task baseline
  exactly, except `test-deploy-baseline-lib.sh` (+2 SC1090 info-level, identical class to the
  file's own pre-existing SC1090 for the same non-constant-`source` pattern) — no new finding
  class introduced anywhere.
- `verify-deploy.sh` (full gate set, not `--skip-slow`): **35 checks, 0 failures.** Comparing
  against the Phase 3 pre-change snapshot (17 findings, entirely deploy-drift from this task's
  own in-progress edits plus two already-known-flaky gate-8 entries): post-redeploy findings are
  down to exactly the same 2 pre-existing/unrelated entries (`lean` extension's
  `routing_hard`/`routing_agents_hard` warning; `test-four-tier-conflict.sh`'s timing-budget
  flake) that predate this task — zero new findings.
- `deploy-headless.sh`: `RESULT=landed_verify_clean`.
- End-to-end acceptance walkthrough (live, not only stubbed): added
  `scripts/tests/test-zz-scratch.sh` unregistered, committed it, confirmed Rule Q's `FAIL:` line
  fires verbatim and `deploy_baseline_self_attributable_findings` reports it as self-attributed
  against a `modified_files` array naming it, then removed the scratch file (net-zero diff,
  verified via `git diff`) and re-confirmed `sync-manifest-scripts.sh --check` and Rule Q are
  clean again.
- Rule Q's `FAIL:` line text: confirmed byte-identical before/after this task via a direct
  before/after comparison against the real core manifest (temporarily removing then restoring
  the one registered entry).
- No task-number references: `check-task-references.sh` clean on every file this task touched
  under `agent-system/**`.

## Impacts

- A missing `provides.scripts` registration can no longer reach `[COMPLETED]` undetected,
  whichever path completion arrives through (mid-implementation redeploy or the inter-cycle
  reconcile pass).
- The authoring burden for `provides.scripts` is now optional: `sync-manifest-scripts.sh --write`
  is a one-command repair, the same shape `generate-context-line-counts.sh --write` already
  established for `line_count`.
- `SELF_ATTRIBUTION_GATE_MODE=advisory`/`off` are now live, documented escape hatches if the
  screen ever proves too aggressive in practice (see the plan's Rollback/Contingency section).

## Follow-ups

- **Recommended new task**: close the agents/commands/context gap documented in Phase 5 — unlike
  `provides.scripts`, `provides.agents`, `provides.commands`, and `provides.context` have no
  disk-driven pre-deploy check at all (the orphan checks, Rules J/K/L, are deployed-file-driven
  and structurally blind to a file that never deployed because it was never declared). This needs
  three new Rules, not a fix to an existing one, and was explicitly out of this task's scope.
- A narrower future fix for the Gate 8 depth-disagreement residual gap (running only the
  deploy-tree-first suites against gate 8 post-deploy, not the full 105-suite battery) remains
  recommended elsewhere in the codebase; this task did not touch that area.

## References

- `specs/355_unregistered_test_script_escapes_completion_gate/reports/01_unregistered-script-completion-gate.md`
- `specs/355_unregistered_test_script_escapes_completion_gate/plans/01_unregistered-script-completion-gate.md`
- `agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh` (header: the
  "DELIBERATE FAIL-SAFE ASYMMETRY" and `SELF_ATTRIBUTION_GATE_MODE` statements)
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` ("### The
  Inter-Cycle Redeploy Checkpoint" subsection)
- `agent-system/extensions/core/docs/guides/creating-extensions.md` (manifest field reference,
  `provides.scripts` asymmetry note)
