# Implementation Summary: Task #471

- **Task**: 471 - Add lint-extension-readme-table.sh and wire it into verify-deploy.sh's gate set
- **Status**: [COMPLETED]
- **Started**: 2026-11-05T00:00:00Z
- **Completed**: 2026-11-05T02:15:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: task 470 (verify-deploy.sh TARGET-contract task) -- serialized behind it as planned
- **Artifacts**: plans/01_lint-extension-readme-table.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added a new source-store lint, `lint-extension-readme-table.sh`, that bidirectionally diffs the
real `agent-system/extensions/*/` directory set against the first column of
`agent-system/extensions/README.md`'s Available Extensions table, exempting `core` by explicit
name. Wired it as gate 26 via a `gate-registry.data` row and a `gate26_run` function, added a
five-case fixture suite, declared both new scripts in `core`'s manifest, and redeployed. One
live drift was repaired first (the `sapience` extension directory had no table row). All six
plan phases are closed; Phase 6 closed `[COMPLETED WITH EXCLUSIONS]` because the full,
unnarrowed test battery carries seven pre-existing, independently-tracked failures entirely
unrelated to this task's changes.

## What Changed

- `agent-system/extensions/core/scripts/lint/lint-extension-readme-table.sh` -- new lint;
  bidirectional directory/table diff, single optional positional `EXTENSIONS_ROOT`, dual-mode
  root resolution, `[VIOLATION]`/`[EXEMPT]` tags, exit 0/1/2.
- `agent-system/extensions/core/scripts/tests/test-lint-extension-readme-table.sh` -- new
  five-case fixture suite (clean, missing row, extra row, core-exempt-and-visible,
  missing-README environment error).
- `agent-system/extensions/core/scripts/gate-registry.data` -- new 9-field row for gate 26
  (`Extension README table lint`, cost_class `free`, `input_corpus` `@extensions`).
- `agent-system/extensions/core/scripts/verify-deploy.sh` -- new `gate26_run` (mirrors
  `gate24_run`'s shape); two stale `23`-gate-count prose mentions corrected to 26 (line ~173
  "every one of the 26 real gates", line ~737 "GATE FUNCTIONS 1-26").
- `agent-system/extensions/core/scripts/tests/test-gate-registry-resolution.sh` -- deviation:
  bumped three hardcoded assertions (case1 expected-id-count 25->26; case32 live-max probe
  25->26; case33 one-past-max probe 26->27) to track the new gate.
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh` -- deviation:
  bumped two hardcoded assertions (case(c)'s out-of-range probe 24->27; case(d)'s `seq 1 23`
  -> `seq 1 26`) to track the new gate.
- `agent-system/extensions/core/manifest.json` -- `provides.scripts` gained the two new entries
  via `sync-manifest-scripts.sh --write` (plus two unrelated, genuinely-missing entries for a
  concurrent task's already-committed files, which the tool found and declared incidentally).
- `agent-system/extensions/README.md` -- added the missing `sapience` row (Task Type `-`,
  description from `sapience/manifest.json`, placed with the other `-`-task-type rows at the
  table's tail).
- `specs/state.json` -- widened task 471's declared `file_scope` to cover the two gate-count
  test fixtures the deviation above touched.
- Redeployed `.claude/` tree, reaching `RESULT=landed_verify_clean`.

## Decisions

- `core`'s exemption is a hardcoded directory-name string comparison, never a manifest-field
  proxy (`routing_exempt: true` is also set by `approvals`, `slidev`, and `sapience`, all of
  which belong in the table).
- Input contract is a single optional positional `EXTENSIONS_ROOT` (reading `<root>/README.md`
  and enumerating `<root>/*/`), not a two-flag pair, so one scratch directory is a complete
  fixture.
- Kept `sync-manifest-scripts.sh --write`'s two incidental, genuinely-correct entries for a
  concurrent task's already-committed files rather than hand-stripping them back out.

## Plan Deviations

- **Task 4.extra** (not itemized in the plan's numbered task list, recorded against Phase 4):
  bumped five hardcoded gate-count/id expectations across `test-gate-registry-resolution.sh`
  and `test-verify-deploy-gate-selection.sh` -- not in the plan's own Files to modify list, but
  required for those suites (named in Phase 4's own Verification criteria) to pass after gate 26
  was added. A known, recurring maintenance point on every gate addition.
- **Phase 6** closed `[COMPLETED WITH EXCLUSIONS]` rather than fully green: the unnarrowed
  `bash .claude/scripts/tests/run-all.sh` reports 7 failing suites, all pre-existing and
  unrelated to this task (5 share one root cause -- a hardcoded fixture lib-copy allowlist
  predating this dispatch and missing `lib/project-number-inuse.sh` -- and are named in open
  record 476's seven-suite scope, itself citing record 275's stash-based proof against
  unmodified master; 2 are already-declared EXPECTED entries in
  `known-failures.txt`). See the plan's Phase 6 `#### Reasoned Exclusions` table for full,
  per-item evidence.

## Verification

- Build: N/A (shell scripts; no compiled artifact)
- Tests: `lint-extension-readme-table.sh --verbose` exits 0 against the real corpus;
  `test-lint-extension-readme-table.sh` passes all 9 assertions across 5 cases;
  `lint-shellcheck.sh` clean on both new files and on `verify-deploy.sh`; `lint-gate-registry.sh`
  passes (contiguous 1..26); `test-gate-registry-resolution.sh`,
  `test-verify-deploy-gate-selection.sh`, `test-verify-deploy-gate-selection-crash-net.sh` all
  pass; `sync-manifest-scripts.sh --check` clean; `--only-gate 26` runs and passes,
  `--only-gate 27` rejected as out of range. Full unnarrowed `verify-deploy.sh`: 39 checks, gates
  1-26 individually PASS, 1 aggregate FAIL (gate 8, addressed by the Reasoned Exclusions above).
  Full unnarrowed `run-all.sh`: 165 passed, 7 failed (2 EXPECTED, 5 pre-existing and
  independently tracked).
- Files verified: Yes

## Impacts

- The Available Extensions table can no longer silently drift from the real extension directory
  set without a loud, mechanical gate-8/gate-26 failure naming the exact missing or dangling
  row.
- `verify-deploy.sh`'s gate count is now 26; any future `--only-gate` probe tracks the registry's
  live max automatically (confirmed already-resolved, no code change required for that
  mechanism itself).

## Follow-ups

- None owned by this task. The 7 pre-existing `run-all.sh` failures surfaced during Phase 6's
  full-battery run are already tracked by open record 476 (five suites) and open record 423 (one
  of the two EXPECTED suites); no new follow-up task is created here.

## References

- Plan: `specs/471_lint_extension_readme_table_drift/plans/01_lint-extension-readme-table.md`
  (see Phase 6's `#### Reasoned Exclusions` table for the full failure-by-failure evidence)
- Progress files: `specs/471_lint_extension_readme_table_drift/progress/phase-{1..6}-progress.json`
- Handoffs: `specs/471_lint_extension_readme_table_drift/handoffs/phase-{1..6}-handoff-*.md`
