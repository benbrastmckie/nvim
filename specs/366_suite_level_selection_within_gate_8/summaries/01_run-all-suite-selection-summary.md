# Implementation Summary: Task #366

- **Task**: 366 - Suite-level selection within Gate 8: --filter/--only in run-all.sh plus the touched-file-to-suite mapping
- **Status**: [COMPLETED]
- **Started**: 2026-10-07T23:55:00Z
- **Completed**: 2026-10-08T04:00:00Z
- **Effort**: ~6.5 hours (matches plan estimate)
- **Dependencies**: None
- **Artifacts**: plans/01_run-all-suite-selection.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, shell-script-testing.md, shell-strict-mode.md

## Overview

Added a strictly opt-in `--only SUITE[,SUITE,...]` flag to `run-all.sh` (the suite-discovery
engine behind Gate 8 of `verify-deploy.sh`), plus a new sourced-only library,
`scripts/lib/suite-selection-lib.sh`, that maps touched source-store paths to resolved suite
names via a three-strata mapping (strict basename pairing, grep-based reference lookup, a
full-sweep sentinel for anything unmappable). All six plan phases completed, each with its own
targeted verification and, where the plan called for it, real-battery measurement under this
session's unusually heavy concurrent-sibling host load.

## What Changed

- `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh` — new sourced-only library.
  Public API: `suite_selection_select`, `suite_selection_unmapped`, `suite_selection_classify`,
  `suite_selection_select_annotated`. Three-strata mapping (basename pairing incl. the `lib/`
  `-lib.sh` suffix variant; grep-based reference lookup; a `__FULL_SWEEP__` sentinel on zero
  hits). Resolution-order classification (`source-only`/`source-first`/`deployed-first`) is
  advisory, never selection-blocking.
- `agent-system/extensions/core/scripts/tests/run-all.sh` — `ONLY_SUITES` default, `--only` parse
  case (non-empty-argument check), single filtering site immediately after the self-exclusion
  block and before `TOTAL_DISCOVERED` (validate-all-tokens-first: one unknown token exits 2,
  naming it, before any suite runs). Extended header (usage line, `--only` paragraph, declined-
  `--filter`-alternative note); updated the `-h`/`--help` self-extraction range (`2,117p` ->
  `2,139p`) so help text no longer truncates against the grown header.
- `agent-system/extensions/core/scripts/tests/test-run-all-selection.sh` — new regression suite
  (15 cases): fail-safe escalation and mapping correctness against the real corpus (cheap, no
  suite execution); invalid/mixed/empty `--only` token refusal against the real `run-all.sh`
  directly; no-flag behavior preservation and full mechanism parity (`--jobs`, the
  `RUN_ALL_NESTED` nested guard, `LOAD_SENSITIVE_BASENAMES` serialization, `TOTAL_ACCOUNTED`,
  `known-failures.txt` classification, `--timings` row count) on a synthetic, deterministic
  fixture.
- `agent-system/extensions/core/manifest.json` — one-line registrations: the new suite in the
  `tests/test-*.sh` array, and `lib/suite-selection-lib.sh` in `provides.scripts` (the latter
  added in Phase 5 after a full `verify-deploy.sh` run surfaced the omission via Gate 3's
  doc-lint).
- `agent-system/extensions/core/context/standards/shell-script-testing.md` — new `--only` bullet
  alongside the existing `--jobs`/`--timings`/`--only-gate`/`--skip-slow` narrative, plus a new
  `### Mapping a touched file to its suite` subsection documenting the library's strata,
  sentinel, classification, measured figures, and declined alternatives. Purely additive (98
  insertions, 0 deletions).

## Decisions

- **Flag shape**: `--only SUITE[,SUITE,...]` (exact basename enumeration), not
  `--filter PATTERN` — matches `--only-gate`'s precedent; `--filter` declined-for-now (no
  concrete interactive caller, the library always emits exact lists).
- **Single filtering site**, before `TOTAL_DISCOVERED`: every downstream mechanism inherits the
  narrowing for free, with zero duplicated filtering logic and no changes to the deliberately
  byte-identical sequential/parallel branches.
- **Fail-safe direction**: an unmapped touched file escalates to the full-sweep sentinel, never
  to an empty/zero-suite selection. A single unmappable path among several escalates the whole
  multi-path call (union-except-escalate aggregation rule).
- **Resolution-order classification is advisory only**: a `deployed-first` suite is still
  selected and still reported as such; the classification is a textual heuristic over suite
  source code (explicitly documented as an approximation), not a semantic trace of runtime path
  resolution.
- **`--only` and `suite-selection-lib.sh` compose, neither calls the other**: the library is a
  separate, independently sourced piece a future caller resolves suite names through first, then
  passes to `run-all.sh --only <list>`.
- **No `verify-deploy.sh` pass-through built**: Gate 8 keeps invoking the full sweep unchanged by
  design (the plan's non-negotiable "tiering governs granularity only, never the final gate"
  invariant); a cheaper mid-task phase gate can invoke `run-all.sh --only` directly.
- **Corrected a failure characterization mid-task** (Phase 6): suites observed failing during
  real-battery measurements were initially characterized uniformly as "host-load-flaky." Direct
  investigation found `test-gate-out-repair-reporting.sh` fails deterministically (a real,
  pre-existing defect in `skill-base.sh`/`validate-artifact.sh`, outside this task's file_scope),
  while `test-four-tier-conflict.sh` is confirmed genuinely load-sensitive and
  `test-skill-base-lifecycle.sh`/`test-update-task-status.sh` showed real flaky (inconsistent)
  behavior across runs. This does not change any acceptance conclusion — every one of these
  suites behaved identically with and without `--only` selection in every run observed.

## Plan Deviations

- **Phase 3** verification: the full-battery no-flag byte-identity diff and the full
  `verify-deploy.sh` run (both separately listed in Phase 3's own Verification section) were
  deferred to Phase 5, which is independently tasked with the identical checks — running the
  ~11-25-minute real battery three times (once per phase) for the same net result would itself
  be the kind of redundant full-sweep re-run this task exists to reduce.
- **Phase 4** verification: likewise deferred its own full `verify-deploy.sh` run and an exact
  "discovered count = Phase 1 count + 1" assertion to Phase 5 — the latter additionally because
  concurrent-sibling suite creation during this session had already made the Phase 1 baseline
  count stale through no fault of this phase's work.
- **Phase 5**: `--jobs 1` was not re-measured (the plan's own "if the load condition permits"
  conditional — host load (6.12–12.90) did not permit a second, even-slower pass). The no-flag
  byte-identity proof used the rigorous deterministic synthetic-fixture exact-match (Phase 4) plus
  a real-battery format-level check, instead of a literal real-battery transcript diff against
  Phase 1's reference — attempted and found not meaningful, traced concretely to host-load-driven
  suite flakiness and corpus population drift, neither caused by this change.
- **Phase 1**: the zero-reference candidate population re-derivation used a cleaner scoping than
  the research report's frozen figures, which did not reconcile exactly against any clean tally.
- **Phase 6**: the failure-characterization correction above; `generate-context-line-counts.sh
  --write` was deliberately not run to fix this file's own (pre-existing, now-larger)
  `index-entries.json` line_count drift, since that script rewrites the whole file and would
  touch several other in-flight tasks' entries outside this task's file_scope.

Full detail and reasoning for every deviation above is recorded in each phase's own progress
file (`specs/366_suite_level_selection_within_gate_8/progress/phase-{1..6}-progress.json`,
`deviations` and `approaches_tried` arrays).

## Verification

- Build: N/A (shell scripts, no compile step)
- Tests: `test-run-all-selection.sh` — 15/15 cases PASS, standalone and stable across 4+ repeated
  runs. Real-battery full sweep (123 suites, `--jobs auto`): 116 passed, 3 failed (all pre-
  existing/environmental, not introduced by this task — see Decisions), 4 skipped (concurrent
  sibling in-flight non-executable files, transient). `shellcheck` clean on all three touched
  shell files.
- Files verified: Yes — all three new/changed shell files exist, are non-empty, executable where
  required, and pass standalone execution.

## Measured Figures (acceptance item 1 — every figure with its load condition)

- Host load: `uptime` load average ranged 3.99–12.90 across this task's entire measurement
  window (multiple concurrent sibling dispatches' own phase-gate test batteries running
  throughout) — heavier than `shell-script-testing.md`'s previously recorded "loaded" condition
  (14m1.5s/6m47.4s).
- Full sweep, `--jobs 1` (Phase 1): 1,276,085ms (~21.3min), 119 discovered, 112/5/2.
- Full sweep, `--jobs auto` (Phase 1): 670,581ms (~11.2min), 120 discovered, 112/5/3.
- Full sweep, `--jobs auto` (Phase 5, fresh): 760,286ms (~12.7min), 123 discovered, 116/3/4.
- Representative selection (5 touched files -> 32 resolved suites), `--jobs auto` (Phase 5):
  375,669ms (~6.3min), 29/2/1 — ~49.4% of the Phase 5 full sweep's wall-clock.
- **Honest caveat**: `test-verify-deploy-context-budget.sh` (the corpus's single most expensive
  suite) was pulled into the 32-suite selection via a `lint/` file's grep-stratum reference and
  accounted for 99.8% of the selected run's own wall-clock. Most of the measured saving came from
  not running the ~90 other, mostly-cheap suites, not from avoiding the single heaviest one —
  recorded as the honest result per the plan's own Contingency guidance, not tuned away.
- Strict-subset proof (acceptance item 2): all 32 suites overlapping between the selected and a
  freshly-measured full run report byte-identical PASS/FAIL/SKIP results — zero mismatches.

## Impacts

- A future caller (an agent's mid-task phase gate, or a planning-layer guidance change — the
  companion "tier-selection-discipline" task depends on this one existing) can now resolve a
  bounded set of touched source files to a resolved suite list and run only those, instead of
  Gate 8's full ~95-125-suite sweep, while Gate 8's own final-gate coverage stays unchanged by
  default.
- Two downstream tasks recorded in the dispatch as depending on this one's existence
  (`isolate_shell_suites_from_host_state`, which owns this task's one contended path,
  `shell-script-testing.md`; and `systematic_script_and_test_corpus_efficiency`, the standing
  consumer of `script-inventory.sh`) can now build on a real `--only` flag and mapping library
  rather than a declared-but-nonexistent mechanism.

## Follow-ups

- `test-gate-out-repair-reporting.sh` has a currently-reproducing, deterministic real-defect
  (`SKILL_VALIDATE_FIXES=0` where a nonzero accumulation is expected) in `skill-base.sh`/
  `validate-artifact.sh`. Neither file is in this task's file_scope; a follow-up task should
  triage it (candidate `known-failures.txt` category: `real-defect`, owner: `needs-owner`) rather
  than this or a future dispatch re-attributing it to host-load flakiness.
- `agent-system/extensions/core/context/standards/shell-script-testing.md`'s own
  `index-entries.json` `line_count` entry drifted further during this task (declared 232, now
  actual 360) on top of pre-existing drift (actual 262 before this task's edit). A future
  `/todo`-adjacent or housekeeping pass should run
  `generate-context-line-counts.sh --write` once several other currently-in-flight tasks'
  entries (`plan-format.md`, `state-management-schema.md`, `state-schema.json`,
  `todo-archival-reference.md`) have also landed, rather than this task widening its own commit
  scope to fix them mid-flight.
- A `verify-deploy.sh` pass-through for `--only` was deliberately not built (declined
  alternative, recorded in `shell-script-testing.md`); revisit only if a concrete caller needs
  `--only` reachable specifically through the `verify-deploy.sh` CLI surface rather than calling
  `run-all.sh` directly.

## References

- Plan: `specs/366_suite_level_selection_within_gate_8/plans/01_run-all-suite-selection.md`
- Research report: `specs/366_suite_level_selection_within_gate_8/reports/01_suite-level-selection-mechanism.md`
- Progress files: `specs/366_suite_level_selection_within_gate_8/progress/phase-{1..6}-progress.json`
- Handoffs: `specs/366_suite_level_selection_within_gate_8/handoffs/phase-{1..6}-handoff-*.md`
