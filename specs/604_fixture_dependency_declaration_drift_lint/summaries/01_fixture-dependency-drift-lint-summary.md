# Implementation Summary: Fixture dependency declaration drift lint

- **Task**: 604 - Fixture dependency declaration drift lint
- **Status**: [COMPLETED]
- **Started**: 2026-11-17T21:30:00Z
- **Completed**: 2026-11-17T23:55:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_fixture-dependency-drift-lint.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Built a lint-time detector (`lint-fixture-dependency-declaration.sh`, gate 30) that reports when
a `scripts/tests/*.sh` fixture suite's hand-maintained sandbox copy-list omits a mandatory
`scripts/lib/*.sh` dependency of a script it copies — the exact drift class behind three
historical runtime failures, all repaired by hand before this task. A seeded regression suite
(`test-lint-fixture-dependency-declaration.sh`) proves the detector against the three
pre-repair commits, two dedicated optional-shape negative cases, and the live corpus, and the
convention is now documented in `shell-script-testing.md` for the first time. All five plan
phases closed `[COMPLETED]`.

## What Changed

- `agent-system/extensions/core/scripts/lint/lint-fixture-dependency-declaration.sh` — new
  detector: unified both-shape declared-set extraction (named array, open-coded pair, and a
  wildcard-copy-all third shape), a four-shape mandatory/optional guard classifier, and a
  depth-bounded transitive closure over mandatory dependencies.
- `agent-system/extensions/core/scripts/tests/test-lint-fixture-dependency-declaration.sh` — new
  regression suite: 3 positive cases seeded from the exact pre-repair text of commits
  `d3e45535e`, `1c10b01f7`, `4c96ccb4f`; 3 matching current-text negatives; 2 dedicated
  OPTIONAL-shape negatives (isolating the single-line degrade-safe guard from the
  log-and-continue search-loop pass-through); and the live-corpus standing case. 18/18 passing.
- `agent-system/extensions/core/scripts/gate-registry.data` — one new row, gate 30 (id computed
  at edit time as `max(existing)+1`, confirmed 30 with no concurrent sibling collision).
- `agent-system/extensions/core/scripts/verify-deploy.sh` — `gate30_run`, a structural copy of
  `gate29_run`.
- `agent-system/extensions/core/context/standards/shell-script-testing.md` — new "Dependency
  declaration completeness" subsection: the two declaration shapes, the wildcard-copy-all third
  shape, and the four-shape guard taxonomy including why the lazy fail-closed-on-first-use shape
  is deliberately never flagged.
- `agent-system/extensions/core/context/formats/plan-format.md` — one line-number citation
  updated (`shell-script-testing.md:178-183` → `:232-237`), tracking the insertion's shift.
- `agent-system/extensions/core/index-entries.json` — `line_count` for the edited standards file
  updated to match (1427); confirmed exact by the deployed tree's own `--check` after Phase 5.
- `agent-system/extensions/core/manifest.json` — `provides.scripts` entries for both new scripts.

## Decisions

- **Siting: route (a), joined `gate-registry.data`** — matching the plan's own ruling; two
  already-registered gates (27, 29) scan the identical corpus for an identical class of problem,
  and a hand-run-only utility would itself be the kind of check that drifts out of use.
- **Shape (iii)'s ambiguous default is OPTIONAL, not MANDATORY** — the plan's own prose summary
  ("neither found: MANDATORY, safe default") was corrected against the live corpus: a genuinely
  ambiguous occurrence (no exit/return found) is, in every measured instance, a degrade-safe
  idiom, not a hard-fail one. The plan's own underlying rule ("a log-and-continue with no exit ->
  OPTIONAL") already implied this; only its one-line prose summary overstated the default.
- **Shape (iv) is flagged only when unconditionally reached (column-0)** — an indented
  occurrence is a lazy, conditionally-called function wrapper (`ensure_file_scope_overlap_lib`),
  whose reachability static analysis cannot determine; the research report itself notes this
  shape drove none of the measured repairs, so flagging it would gain no coverage while
  introducing a live false-positive risk against the current corpus.
- **A wildcard `cp .../lib/*.sh` copy is a third legitimate declared-set shape**, not named
  explicitly in the plan's prose but load-bearing for a clean corpus run (several suites,
  including one named-array suite, rely on it).

## Plan Deviations

- **Task 1** (detector shapes): added the multi-line variant of the degrade-safe guard
  (`if [ -f "<literal>" ]; then source "<same literal>"; fi`), the wildcard-copy-all recognition,
  and a Tier C extraction for an open-coded word-list for-loop concatenating `lib/$VAR` — none
  named explicitly in the plan's prose, all required for a clean live-corpus run.
- **Task 1/shape (iii) and shape (iv)**: corrected the ambiguous-default direction and narrowed
  shape (iv) to column-0 occurrences only, as detailed in Decisions above.
- **Task 4.3** (line-count regeneration): `generate-context-line-counts.sh --write` refuses to
  run from the source store (deploy-root-guard.sh-style guard); applied the mechanically
  equivalent `wc -l` value by hand instead, confirmed exact by the deployed tree's own `--check`
  after Phase 5's redeploy.
- **Task 5** (complete gate-set verification): altered per this dispatch's own Batch Gate
  Deferral directive — discharged via a scoped `--only-gate 30 --skip-unchanged` invocation plus
  a gate-8 `run-all.sh --only` slice for the three directly relevant suites, with the complete
  sweep deferred to the once-per-invocation batch-level stage. Gates 3/4 hit a 60s timeout under
  measured host load (load average 8.90) during `deploy-headless.sh`'s own internal fast-gate
  pass; confirmed transient (not a regression) by a clean standalone re-run.

## Verification

- Build: N/A (shell scripts)
- Tests: Passed — regression suite 18/18; live corpus 159 files checked, 15 suites selected, 0
  violations; `lint-gate-registry.sh` 7/7; `sync-manifest-scripts.sh --check` and
  `generate-context-line-counts.sh --check` both exit 0 against the deployed tree; gate 30 PASS
  post-deploy; gate 8 scoped slice 3/3 PASS; `[SKIP]` branch confirmed against a synthetic
  non-source-store target.
- Files verified: Yes

## Impacts

- A future `scripts/tests/*.sh` suite that copies a helper script gaining a new mandatory
  `scripts/lib/*.sh` dependency now gets a lint-time report instead of an opaque runtime "No such
  file or directory" failure.
- No existing suite's pass/fail semantics changed, and no previously-green gate (other than the
  two transient host-load timeouts, independently confirmed unrelated) regressed.

## Follow-ups

- The advisory `known-failures.txt` roster-staleness check is a separate, dependent task (named
  in the dispatch's Non-Goals) and was not touched here.
- The complete `verify-deploy.sh` gate set, deferred per the Batch Gate Deferral directive, still
  runs once for the whole batch at the end of this `/orchestrate` invocation and is attributed
  back to this task by its own `modified_files`.

## References

- `specs/604_fixture_dependency_declaration_drift_lint/plans/01_fixture-dependency-drift-lint.md`
- `specs/604_fixture_dependency_declaration_drift_lint/reports/01_fixture-dependency-drift-lint.md`
- `specs/604_fixture_dependency_declaration_drift_lint/handoffs/phase-1-handoff-20261117T215800Z.md`
  through `phase-5-handoff-20261117T235500Z.md`
