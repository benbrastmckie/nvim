# Implementation Summary: Task #643

- **Task**: 643 - Align /orchestrate's conclusion-stage next-batch suggestion with the authored roadmap ordering, or render both so the divergence is visible
- **Status**: [COMPLETED]
- **Started**: 2026-11-17T21:50:00Z
- **Completed**: 2026-11-17T23:58:00Z
- **Effort**: ~2 hours
- **Dependencies**: None
- **Artifacts**: plans/01_roadmap-aware-next-batch-suggestion.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Implemented the research report's Direction (a): `orchestrate-suggest-next-batch.sh`'s Mode A
(`--next-batch`) now walks `specs/state.json`'s authored `roadmap_batches` array, in authored
order, as its primary candidate source, readiness-filtering each batch locally and probing the
first non-empty filtered batch through the existing, unmodified admission chain
(`suggest_from_candidates()` -> `probe_candidate_set()` -> `orchestrate-batch-admit.sh`). On
success it renders the batch's authored position and `description`; on exhaustion it prints an
explicit fallback line and falls through to the pre-existing three mechanical selection-doctrine
options unchanged. All five plan phases completed; the live attestation against this
repository's real 152-task `specs/state.json` confirms the suggestion now names an authored
roadmap batch (`[577, 609]`) identical to `specs/ROADMAP.md`'s own rendered line.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh` — factored the
  readiness predicate into a shared `build_ready_set()` + `task_is_ready()` (Phase 1,
  behavior-preserving); added `read_roadmap_batches()` and `suggest_from_roadmap_batches()`,
  wired into `mode_next_batch()` ahead of the mechanical criteria (Phase 2); extended the
  script's header documentation and widened `usage()`'s `sed -n` range so the new section
  actually appears in `--help`; fixed a latent `set -e` footgun in `build_ready_set()` discovered
  during Phase 5's live attestation (a bare `[ cond ] && action` as the loop's last statement
  silently aborted the whole script when the highest-numbered ready-pool-scan task had an unmet
  dependency on the real repository's live state).
- `agent-system/extensions/core/scripts/tests/test-orchestrate-suggest-next-batch.sh` — added a
  `set_roadmap_batches()` scratch helper and 9 new regression cases (k-s): a clean authored batch
  renders and suppresses the mechanical options; the absent-key and empty-array paths both fall
  through silently; every-batch-unready prints the explicit fallback; a first empty-filtered
  batch's skip stays visible even when a later batch succeeds; proper-subset filtering names its
  omitted member; a stale `task_id` absent from `active_projects` is treated as not-ready; an
  internal `file_scope` collision inside an authored batch still renders through the unmodified
  ordered-sequence engine; and the `set -e` footgun regression (case s) locks in the Phase 5 fix.
  All 27 cases (18 pre-existing + 9 new) pass; each new case was spot-checked against a
  deliberately reverted behavior and genuinely fails in that condition.
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` — the
  `**Suggested next batch**:` section now documents the roadmap-walk primary source, the
  omitted-member note, and the fallback line, ahead of the existing mechanical-options prose
  (which stays unchanged).
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — new `###
  Shared Readiness Concept: Two Bars, One Idea, Two Call Sites` subsection recording that
  `build_ready_set()`'s predicate and `roadmap-integration.sh`'s `render_next()` terminal-member
  filtering are the same readiness concept at two different bars; the existing Exclusion Table
  row for `orchestrate-suggest-next-batch.sh` was left unaltered.
- `agent-system/extensions/core/index-entries.json` — `line_count` entries for the two edited
  docs reconciled by `deploy-headless.sh`'s automatic regeneration (2328 -> 2345,
  271 -> 284), no unrelated churn.

## Decisions

- Roadmap walk runs before, and suppresses on success, the three mechanical criteria — an
  either/or render, never an always-on dual, so the divergence-confusion the task exists to
  remove is actually resolved rather than reproduced in a different form.
- Readiness stays a local, pre-probe predicate (shared via `build_ready_set()`/`task_is_ready()`);
  admissibility stays exclusively `orchestrate-batch-admit.sh`'s, per the script's own binding
  constraint — the roadmap source changes which sets get probed, never what establishes
  admissibility.
- The fallback line is mandatory whenever at least one authored batch was checked (never printed
  when `roadmap_batches` is absent or empty, preserving byte-identical mechanical-render output
  for every pre-existing test case).
- Verification for this task required exporting `CORE_TEST_SUBJECT_MODE=source-store`: the test
  suite's default `deploy-tree-first` subject resolution silently validates the stale deployed
  tree ahead of a source-store edit until redeploy, which would otherwise have made Phase 1/2's
  "verification passed" claims vacuous with respect to the actual edits.

## Plan Deviations

- **Phase 3** required an unplanned fix in `orchestrate-suggest-next-batch.sh` (beyond its
  test-file-only Scope Hypothesis): writing case (o) surfaced that `mode_next_batch()` populated
  `READY_SET` inside a process-substitution subshell, so `task_is_ready()` never saw it in the
  parent shell. Fixed by calling `build_ready_set()` directly in `mode_next_batch()`'s own shell;
  also added a visible "skipped" line for an empty-filtered batch. Recorded via `issue-record.sh`
  (`class: scope excursion`).
- **Phase 4**'s verification bullet expected a literal zero-exit `verify-deploy.sh` run, but
  `check-extension-docs.sh`'s `INDEX_TRUTH_GATE_MODE` defaults to `hard`, not advisory as the
  plan's Decision 4 text implied — the declared `line_count` drift surfaces as a hard FAIL before
  Phase 5's redeploy reconciles it. Closed on `INDEX_TRUTH_GATE_MODE=advisory` evidence (confirming
  the only findings were the two expected/declared drift categories) plus an independently clean
  task-reference lint. Recorded via `issue-record.sh` (`class: premise correction`).
- **Phase 5** required an unplanned bug fix and one additional regression test case (case s): the
  first live `--next-batch` attestation against the real repository's `specs/state.json` crashed
  silently (a latent `set -e` footgun in `build_ready_set()`, exposed by the READY_SET-persistence
  fix from Phase 3). Fixed, locked in with a new regression case, redeployed a second time, and
  re-ran the live attestation successfully. Recorded via `issue-record.sh` (`class: latent bug
  fixed` and `class: scope excursion`).

## Verification

- Build: N/A (shell scripts; `bash -n` clean on both edited scripts throughout)
- Tests: Passed — 27/27 cases in `test-orchestrate-suggest-next-batch.sh` (18 pre-existing + 9
  new), confirmed against the source-store edits directly and again against the final deployed
  tree
- Files verified: Yes
- Full gate set: 41/41 PASS (via `deploy-headless.sh`'s own internal `verify-deploy.sh` call,
  gate 8's shell-test-suite portion separately discharged via the scoped `run-all.sh --only`
  invocation per this dispatch's Batch Gate Deferral directive)
- Live attestation: `orchestrate-suggest-next-batch.sh --next-batch` against the real
  `specs/state.json` (152 active tasks) names authored roadmap batch `[577, 609]`
  ("The failure-accounting chain's tail, held behind the prioritized head both members depend
  on"), omitting not-ready member 609 and rendering 577 as admitted — identical to
  `specs/ROADMAP.md`'s own rendered `/orchestrate 577, 609` line and description. `specs/state.json`
  left byte-identical (no `--write-edges` used). `validate-state.sh --deep`: 21 passed, 22
  warnings, 0 failed.

## Impacts

- A `/orchestrate` operator reading the conclusion-stage Step 7 suggestion now sees the same
  priority ordering `specs/ROADMAP.md` already shows, or an explicit, stated reason the roadmap
  walk fell back — closing the silent two-disjoint-lists divergence the task describes.
- The fixed `set -e` footgun in `build_ready_set()` was a real, previously-undetected crash risk
  in the live script (triggerable whenever the highest-numbered ready-pool-scan task has an
  unmet dependency); it is now covered by a dedicated regression case.

## Follow-ups

- None required for task completion. Possible future note (not actioned here, out of scope):
  the same `[ cond ] && action` footgun shape appears elsewhere in this script's pre-existing
  code (e.g. `[ -n "$t" ] && arr+=("$t")` patterns); those call sites are low-risk in practice
  (the data they iterate essentially never naturally produces a false condition on the last
  line) and were left unchanged, but a future reader extending this script should be aware of
  the shape.

## References

- Plan: `specs/643_next_batch_suggestion_ignores_roadmap_ordering/plans/01_roadmap-aware-next-batch-suggestion.md`
- Research report: `specs/643_next_batch_suggestion_ignores_roadmap_ordering/reports/01_roadmap_aware_suggester.md`
- Phase handoffs: `specs/643_next_batch_suggestion_ignores_roadmap_ordering/handoffs/phase-{1..5}-handoff-*.md`
