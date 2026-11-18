# Implementation Summary: Task #572

- **Task**: 572 - Make a declared `Verification Tier: full` honorable under batch concurrency
- **Status**: [COMPLETED]
- **Started**: 2026-11-16T17:40:00Z
- **Completed**: 2026-11-16T19:30:00Z
- **Effort**: ~2 hours
- **Dependencies**: None
- **Artifacts**: plans/01_full-gate-batch-concurrency.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

A plan phase declaring `**Verification Tier**: full` inside a multi-task `/orchestrate` batch was
unhonorable whenever that phase was not the plan's literal final phase: the `## Batch Gate
Deferral` directive the composer emits named only "the FINAL phase", so an intermediate `full`
phase received no narrowing instruction and the dispatched agent would run (and risk abandoning)
an unscoped aggregator sweep. Separately, a Gate 8 run that was genuinely contended (a long
`specs/.gate-lock` wait, or high ambient load) had no verdict distinct from FAIL, forcing manual
triage to tell contention apart from a real break. This task widened the directive to cover every
`full`-declaring phase, aligned the matching contract prose, added an annotation-only
contention-detected signal to the Gate 8 lock/load path, and redeployed plus ran the complete
gate set (scoped, per this dispatch's own Batch Gate Deferral directive, since this task itself
ran inside a multi-task batch).

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — the `## Batch Gate
  Deferral` block now scans `$plan_path` for every phase section declaring `**Verification
  Tier**: full` (status-marker-independent), renders one set-naming block listing all qualifying
  phases (or a numberless degrade when none are found / the plan is unreadable), and adds a
  bounded-`kill -0`-wait instruction to the two sanctioned unscoped paths (the no-resolvable-
  candidate degrade branch and the UNMAPPABLE CRITERION carve-out).
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — a new "DECIDED AND RECORDED"
  note in `cycle_plan_dispatch_hash()`'s comment block, recording that the directive's now
  plan-derived phase-list content stays deliberately unstripped from the dispatch-hash
  normalizer (content-derived, not status-derived, so it is stable across cycles while the plan
  is unchanged).
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` — 9 new Group 19
  cases: intermediate-phase naming, multi-phase naming (one block), the numberless degrade wording
  for no-declaration and missing-plan-file, and non-presence of the old "FINAL phase" literal in
  every case.
- `agent-system/extensions/core/context/formats/plan-format.md` — `### Batch-aware deferral`
  subsection widened to state every `full`-declaring phase is covered, not only the final one.
- `agent-system/extensions/core/context/contracts/batch-gate-stage.md` — `## Mechanism A's
  Dispatch-Time Siting` section's closing claim replaced with the widened-scan description and the
  coverage gap it closes; `## Finding Severity` section documents the new contention tag as a
  third `WARN-FINDING ` site.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — `gate8_run()` now times its own
  `specs/.gate-lock` acquire wait and samples the entry 1-minute load average (via new
  `_gate8_load_1min()`/`_gate8_now_ms()` helpers with test-only override hooks), and emits a
  `[CONTENTION]` stderr note plus (in `--findings` mode) a `WARN-FINDING gate8 [CONTENTION] ...`
  line when either signal clears its own env-overridable threshold — written directly to
  `FINDINGS_LIST` rather than via `warn_advisory()`, so `CHECKS`/`GATE_DIRTY_LIST` are untouched.
  Annotation only: every `fail()`/`warn()`/`pass()` call site, exit status, and the `^FINDING `
  stream are unchanged.
- `agent-system/extensions/core/scripts/tests/test-gate-lock.sh` — 10 new cases: the tag fires
  under a real, short-held `specs/.gate-lock` wait; fires under a stubbed high load average; does
  not fire on a clean run; and a genuinely failing fixture suite still FAILs with the tag
  independently set (non-vacuousness).
- `agent-system/extensions/core/index-entries.json` — regenerated `line_count` for
  `plan-format.md` and `batch-gate-stage.md` (two generations, once per edit round).
- Redeployed `.claude/**` tree (`deploy-headless.sh`).

## Decisions

- The phase-list scan is status-marker-independent (reads each phase's `**Verification Tier**`
  field, never its `[NOT STARTED]`/`[COMPLETED]` heading marker), so the rendered directive text
  stays stable across orchestrate cycles while the plan itself is unchanged — required for
  `cycle_plan_dispatch_hash()`'s IDENTICAL DISPATCH HALT guard to keep working correctly.
- The multi-character join for the phase-number list uses `printf '%s, ' ... | strip trailing`
  rather than `IFS=', '; "${arr[*]}"` — the latter uses only IFS's first character as the
  separator and silently collapses `", "` to `","`.
- The contention-detected signal is written directly to `FINDINGS_LIST` with the `WARN-FINDING `
  prefix rather than through an actual `warn_advisory()` call, because that function also
  increments `CHECKS` and forces `GATE_DIRTY_LIST` — side effects the annotation must never cause
  independent of the gate's real verdict.
- `GATE_MUTEX_ACQUIRE_BUDGET_MS` needed its own inline `${GATE_MUTEX_ACQUIRE_BUDGET_MS:-600000}`
  default in `verify-deploy.sh`'s own process — that variable's real default (600000) is defined
  inside `task-lock.sh`'s separate subprocess and never leaks back into the calling shell.
- Default thresholds: `GATE8_CONTENTION_WAIT_FRACTION=0.1` (60s against the 600s acquire budget)
  and `GATE8_CONTENTION_LOAD_THRESHOLD=2.0` (matching `measure-gate-costs.sh`'s own default).

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (meta task, shell/markdown only)
- Tests: `test-orchestrate-build-dispatch.sh` 232/232; `test-orchestrate-cycle-plan.sh` 441/441
  (unaffected, comment-only edit); `test-gate-lock.sh` 27/27. Shellcheck (`lint-shellcheck.sh
  --verbose`): 0 findings at `-S warning` across 473 files. `check-extension-docs.sh`: no Rule R
  finding (both context-file edits). Scoped Batch Gate Deferral discharge (37-suite selector-
  derived union covering every file Phases 1-3 touched): 35 passed, 2 failed (2 expected, 0 NEW —
  both pre-existing `known-failures.txt` rows, unrelated to this task), run both pre- and
  post-deploy with identical classification.
- Files verified: Yes — all 8 edited files confirmed byte-identical source-vs-deployed after
  `deploy-headless.sh`.

## Impacts

- A future plan declaring `full` on an intermediate (non-final) phase now gets real scoped-
  narrowing coverage under batch concurrency instead of running an unscoped, potentially-abandoned
  aggregator sweep.
- A Gate 8 run that was contended (lock wait or high load) now carries its own visible
  `[CONTENTION]`/`WARN-FINDING ` annotation, giving future triage a direct signal to distinguish
  contention from a genuine break — without altering any verdict or the batch-blocking findings
  channel.
- `orchestrate-cycle-plan.sh`'s dispatch-hash normalizer now carries an explicit, discoverable
  record of why the directive's phase-list content is deliberately left unstripped, closing the
  STANDING OBLIGATION that comment block names for new per-cycle content.

## Follow-ups

- None required by this task. The one deploy-time finding observed during Phase 4
  (`scripts/git-commit-scoped.sh` source-vs-deployed drift) belongs to a different, concurrently
  `implementing` task (specs/state.json's project_number 476) and is already recorded in this
  task's own `issues.jsonl` as non-attributable; no action is owed here.

## References

- Plan: `specs/572_make_full_gate_viable_under_batch_concurrency/plans/01_full-gate-batch-concurrency.md`
- Report: `specs/572_make_full_gate_viable_under_batch_concurrency/reports/01_batch-gate-full-tier-viability.md`
- Progress files: `specs/572_make_full_gate_viable_under_batch_concurrency/progress/phase-{1,2,3,4}-progress.json`
- Handoffs: `specs/572_make_full_gate_viable_under_batch_concurrency/handoffs/`
