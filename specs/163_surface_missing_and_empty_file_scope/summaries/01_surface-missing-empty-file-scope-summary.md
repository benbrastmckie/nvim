# Implementation Summary: Task #163

- **Task**: 163 - Surface missing and empty file_scope
- **Status**: [COMPLETED]
- **Started**: 2026-09-29T00:00:00Z
- **Completed**: 2026-09-29T04:45:00Z
- **Effort**: ~4.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_surface-missing-empty-file-scope.md
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md

## Overview

An absent, literal-null, empty-array, or glob-shaped `file_scope` was invisible to every existing
detector. This task adds four new WARN-only detectors — Checks 10/11 in `validate-state.sh`,
Classes F/G in `orchestrate-predispatch-review.sh` — plus a `--strict` flag mirroring
`validate-artifact.sh`'s advisory-first precedent, and fixture-based regression coverage for all
of it. All 8 plan phases completed. Along the way, the implementation discovered and fixed one
genuine pre-existing bug (`--repair` manufacturing a `file_scope` key on an absent-key candidate)
and one pre-existing `--help` truncation regression, both unrelated to the new detectors but
necessary to keep the surrounding scripts correct.

## What Changed

- `agent-system/extensions/core/scripts/lib/file-scope-overlap.sh` — added the shared
  `is_glob_entry` jq def (`test("[*?\\[]")`), matching the character class already used by
  `path_covered_by_scope()` and `orchestrate-cycle-plan.sh`'s
  `_sibling_territory_classify_entry()`.
- `agent-system/extensions/core/scripts/validate-state.sh` — added Check 10 (missing / literal-null
  / empty-array `file_scope`, three distinguishable sub-states with counts), Check 11
  (glob-shaped entries), and a `--strict` flag (copying `validate-artifact.sh`'s exact
  `total_issues` semantics); header documents the D2 ruling and both promotion criteria; fixed a
  `--help` truncation regression the header's own growth exposed (hardcoded `sed -n '2,107p'`
  replaced with a dynamic `awk`-based range).
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` — added Class F
  (missing/null/empty `file_scope` on a batch candidate) and Class G (glob-shaped entry), both
  scoped to `$cands` only; added new sourcing of `lib/file-scope-overlap.sh` (this script never
  spliced `FILE_SCOPE_OVERLAP_JQ_DEFS` before, contrary to the plan's premise); fixed a genuine
  pre-existing bug in `--repair`'s write filter that silently manufactured `file_scope: []` on an
  absent-key candidate sharing an invocation with a genuinely-null sibling.
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` — 7 new fixture cases:
  Check 10 positive/negative/terminal-exclusion, Check 11 positive+control, `--strict`
  finding+clean, `--fix` non-manufacture. 25/25 total, all green.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh` — 3 new
  scenarios (Class F, Class G, `--repair` D4) plus 2 new assertions extending the existing
  all-clean Scenario 4; sandbox setup extended twice (`lib/file-scope-overlap.sh`, then
  `task-lock.sh`) to keep pace with the SUT's new dependencies. 34/34 total, all green.

## Decisions

- **D1-D9** (all recorded in the plan, transcribed into both scripts' headers): two new checks
  rather than widened Check 8/9; all three sub-states (missing/null/empty) warn, separately
  labelled; Classes F and G (never "Class C", correcting the addendum's drafting slip); absent
  keys never touch any repair path; `--strict` copies `validate-artifact.sh` exactly; Check 11's
  WARN wording states the concrete Overlap-blindness consequence, never "invalid"; one shared
  `is_glob_entry` def; scope extension to `lib/file-scope-overlap.sh` and both test files,
  recorded deliberately; exact counts are fixture-asserted only, never bound to a live
  `specs/state.json`.
- **Load-bearing correction (Phase 1)**: the plan and its research report both assert
  `orchestrate-predispatch-review.sh` "already splices" `FILE_SCOPE_OVERLAP_JQ_DEFS` — this is
  false (confirmed via `grep`: zero occurrences before this task). Classes C/D/E re-present
  `orchestrate-batch-admit.sh` subprocess verdicts and never touched the jq defs directly. Phase 5
  added new sourcing instead of reusing a nonexistent splice, using the
  `if ! . "${SCRIPT_DIR}/lib/file-scope-overlap.sh" 2>/dev/null; then` idiom (required, not
  stylistic, under `set -euo pipefail` — see Plan Deviations).

## Plan Deviations

- **MAJOR — genuine pre-existing bug discovered and fixed (Phase 7)**: writing the `--repair` D4
  fixture revealed that `--repair`'s write filter used plain `.field == null` (no `has()` guard)
  for both `dependencies` and `file_scope`. Since jq's dot-access cannot distinguish an ABSENT key
  from a PRESENT literal null, a candidate with no `file_scope` key at all had `file_scope: []`
  silently manufactured onto it whenever it shared a `--repair` invocation with another candidate
  that had a genuine literal null. This contradicted the script's own documented contract ("a
  present, non-null value is never overwritten") and this task's D4 guarantee/acceptance
  criterion. Confirmed pre-existing (not introduced by this task) via `git show` against the
  pre-task commit and a manual reproduction. Fixed by gating both the preview `select()` and the
  write transform on `has(field) and .field == null`; pinned by Scenario 10 in
  `test-orchestrate-predispatch-review.sh`. This is a correctness fix to the EXISTING Class B
  repair machinery, not a new repair branch for Classes F/G, which remain completely untouched by
  `--repair` per D4/Non-Goals.
- **Phase 1 correction**: `orchestrate-predispatch-review.sh` did not already splice
  `FILE_SCOPE_OVERLAP_JQ_DEFS` — see Decisions above. Added new sourcing rather than reusing an
  existing splice.
- **Phase 2 fix**: `validate-state.sh`'s `--help` handler used a hardcoded `sed -n '2,107p' "$0"`
  range that silently truncated output once Check 10/11's header text grew past line 107. Replaced
  with a dynamic `awk`-based range immune to future header growth.
- **Phase 5/Phase 7 test-harness fixes**: `test-orchestrate-predispatch-review.sh`'s synthetic
  sandbox setup was extended twice — once to carry `lib/file-scope-overlap.sh` (required once the
  SUT gained its new fail-closed sourcing), once to carry `task-lock.sh` (required by the new
  `--repair` D4 fixture's `state-write.sh` mutex acquisition). Both were necessary to keep the
  pre-existing 21-case suite (and the new cases) green.
- Two literal apostrophes in an early draft of the Class F/G jq-block bash comments prematurely
  terminated the enclosing single-quoted jq program string (a bash parse-time issue, not a jq
  one), producing a bash syntax error. Rewrote both comments apostrophe-free.
- A bash parameter-expansion gotcha: `${var:-{}}` as a jq-input default silently appends a stray
  trailing `}` whenever `var` is non-empty (confirmed via isolated repro). Fixed by using
  `${var:-null}` instead in `validate-state.sh`'s Check 10 block.

## Verification

- Build: N/A (shell scripts)
- Tests: `test-validate-state.sh` 25/25 pass; `test-orchestrate-predispatch-review.sh` 34/34 pass;
  `test-init-specs.sh` 23/23 pass
- Files verified: Yes — `shellcheck --severity=warning` clean on `validate-state.sh`,
  `orchestrate-predispatch-review.sh`, and both edited test files; one PRE-EXISTING SC2053 in
  `lib/file-scope-overlap.sh` (unrelated, unfixed — see Follow-ups)
- Live measurement, this repo (`specs/state.json`, 28 non-terminal tasks): 1 missing-key, 0
  literal-null, 0 empty-array, 0 glob-shaped entries; exit 0
- Live measurement, `~/Projects/BimodalLogic/specs/state.json` (47 non-terminal tasks): 23
  missing-key, 5 literal-null, 0 empty-array, 0 glob-shaped entries (28 lacking a usable value —
  diverges from the dispatch's stale 22/17/5 citation, confirming D9's expectation that the
  corpus has moved on since the dispatch was authored); script exit 1 overall due to 9
  PRE-EXISTING FAIL-level findings unrelated to Checks 10/11 (both new checks are WARN-only and
  never contribute to FAILED)

## Impacts

- Any caller of `validate-state.sh` in default mode now sees an additional, non-blocking
  visibility signal for missing/null/empty/glob `file_scope` declarations; no existing caller's
  exit-code behavior changes (confirmed against the 4 live callers:  `commands/task.md`,
  `verify-deploy.sh` gate 10, `test-init-specs.sh`, `test-validate-state.sh` — none passes
  `--strict`).
- `commands/task.md`'s existing `file_scope` advisory grep (`grep -a 'file_scope'`) automatically
  picks up the new Check 10/11 WARN lines — a free win, confirmed not excessive in volume.
  `orchestrate-predispatch-review.sh`'s default report now surfaces two additional classes per
  batch review; `--repair`'s behavior for the pre-existing Class B literal-null case is now
  strictly more correct (an absent key sharing an invocation with a null sibling is no longer
  silently mutated).

## Follow-ups

- One PRE-EXISTING `shellcheck --severity=warning` SC2053 in
  `lib/file-scope-overlap.sh`'s `path_covered_by_scope()` (unquoted glob comparison in `[[ ... ]]`)
  remains unfixed, per this task's Non-Goal against fixing unrelated pre-existing shellcheck
  notes. A future task could quote the right-hand side of that `==` comparison.
- The promotion criteria recorded in both scripts' headers (promote missing-key/literal-null from
  WARN to FAIL once no non-terminal task under `specs/` lacks a usable `file_scope`) are
  deliberately NOT executed by this task — a future task should re-measure and decide.
- `orchestrate-cycle-plan.sh`'s own bash glob transcription (`_sibling_territory_classify_entry()`)
  was deliberately left without a cross-reference comment pointing to the new jq `is_glob_entry`
  sibling, since that file is inside a concurrent sibling task's declared `file_scope` this same
  cycle (per the plan's explicit Non-Goal). A future task could add that one-line pointer comment.

## References

- Plan: `specs/163_surface_missing_and_empty_file_scope/plans/01_surface-missing-empty-file-scope.md`
- Research: `specs/163_surface_missing_and_empty_file_scope/reports/01_missing-empty-file-scope-visibility.md`
- Progress files: `specs/163_surface_missing_and_empty_file_scope/progress/phase-{1..8}-progress.json`
- Handoffs: `specs/163_surface_missing_and_empty_file_scope/handoffs/phase-{1,4,7}-handoff-*.md`
