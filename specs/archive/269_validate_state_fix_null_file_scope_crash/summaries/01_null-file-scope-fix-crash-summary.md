# Implementation Summary: Task #269

- **Task**: 269 - validate-state.sh --fix crashes on literal-null file_scope
- **Status**: [COMPLETED]
- **Started**: 2026-09-30T17:14:39Z
- **Completed**: 2026-09-30T17:38:10Z
- **Effort**: ~35 minutes
- **Dependencies**: None
- **Artifacts**: plans/01_null-file-scope-fix-crash.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`validate-state.sh --fix`'s mutation filter gated duplicate-removal on `has("file_scope")`, a
key-presence test that is `true` for a literal-`null` value; the subsequent `reduce .[]` then
tried to iterate `null` and jq aborted, so `state-write.sh` correctly refused the write and
`--fix` silently repaired nothing despite reporting its findings. The fix swaps the predicate to
the type test `(.file_scope|type) == "array"`, rewrites the comment block that had endorsed the
defective `has()` form, and extends the existing `FIX_FIXTURE_DIR` regression fixture to prove
the crash is gone while the three documented invariants (order-preserving dedup, no
`file_scope: []` manufacture, idempotence) all hold. Both edits were made in the source store
only (`agent-system/extensions/core/scripts/`), never under the gitignored `.claude/**` deploy
tree.

## What Changed

- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` — extended the
  `FIX_FIXTURE_DIR` block with project 3 (`"file_scope": null`) and project 4 (no `file_scope`
  key), added `fix_p3_null`/`fix_p4_has_key` capture lines, added three new conjuncts to the
  pass/fail condition (null-and-present preserved, key-absent preserved, no
  `--fix: state-write.sh failed` in `$out`), extended the fail diagnostics, and rewrote the block
  comment to describe all four fixture entries.
- `agent-system/extensions/core/scripts/validate-state.sh` — swapped the mutation filter's
  `if has("file_scope") then` to `if (.file_scope|type) == "array" then` (the `reduce`/`else`
  body is byte-identical), and rewrote the comment block above `_fix_report` to document the
  type-test gate and explain why `has()` was wrong (true for literal-null, causing jq to abort on
  the reduce).

## Decisions

- Used a type test (`(.file_scope|type) == "array"`) rather than a `// []` default at the
  assignment site, per the research/plan: a `// []` default would have manufactured
  `file_scope: []` on a previously-null entry, violating the no-manufacture invariant.
- Left the report filter (`select(has("file_scope")) | ($t.file_scope // []) as $fs`) untouched —
  it was already null-safe via its `// []` guard and only the separate mutation filter handed to
  `state-write.sh` was defective.
- Committed the Phase 1 fixture (red) and Phase 2 filter+comment (green) as two separate commits,
  per the plan, so the red state stands as a legitimate documented reproduction if Phase 2 is
  ever reverted independently.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (bash script, no build step)
- Tests: Passed — `bash agent-system/extensions/core/scripts/tests/test-validate-state.sh`
  reported 24 passed / 1 failed after Phase 1 (red, confirming the fixture has teeth: the
  `--fix fixture` case failed with `--fix: state-write.sh failed` present in `$out` and project
  1's duplicates left unrepaired), then 25 passed / 0 failed after Phase 2 (green, no other case
  regressed).
- Files verified: Yes — `bash -n` passed on both modified files; `git diff` on
  `validate-state.sh` showed exactly two hunks (the comment block and the one filter-predicate
  line), with no `unique` introduced and the reduce body unchanged.
- Direct repro (Phase 3): the exact three-shape jq one-liner from the plan produced the expected
  output (`null` preserved, `["a","b"]` order-preserving dedup, no key manufactured on the
  keyless entry).
- Idempotence (Phase 3): built a throwaway fixture under `specs/_tmp_269_idemp_$$`, ran `--fix`
  twice; second run logged "nothing to repair" and the file was byte-identical to the first run's
  output.
- Scope (Phase 3): `git status --short` after all edits showed no path under `.claude/**`;
  `NOMFG_FIXTURE_DIR`'s D4 `--fix non-manufacture fixture` case was unchanged and still passed.

## Impacts

- `validate-state.sh --fix` no longer aborts on a `state.json` containing any
  `active_projects[].file_scope: null` entry; a genuine duplicate elsewhere in the same file is
  now actually repaired rather than silently left in place.
- No change to `state-write.sh`, the report filter, or Checks 8-11.

## Follow-ups

- Not fixed here (explicitly out of scope, recorded during research/planning): a failed `--fix`
  write is exit-code-invisible — the failure branch uses a raw `echo` rather than `log_fail`, so
  base-mode `--fix` can exit 0 even when the write was refused. This is a real, separate defect
  in the same block; routing it through `log_fail` would change `--fix`'s exit contract for every
  existing caller and belongs in its own task.
- The deployed copy at `.claude/scripts/validate-state.sh` was confirmed byte-identical to the
  source-store file before this change and is now stale relative to it; this task deliberately
  did not redeploy (three concurrent sibling tasks were editing other source-store files this
  same cycle). The next ordinary deploy propagates the fix.

## References

- Plan: specs/269_validate_state_fix_null_file_scope_crash/plans/01_null-file-scope-fix-crash.md
- Research: specs/269_validate_state_fix_null_file_scope_crash/reports/01_null-file-scope-fix-crash.md
