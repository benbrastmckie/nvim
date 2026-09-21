# Implementation Summary: Task #246

- **Task**: 246 - Make lean-challenge-snapshot.sh identifier comparison locale-independent (false mismatch under en_US.UTF-8)
- **Status**: [COMPLETED]
- **Started**: 2026-09-21T00:00:00Z
- **Completed**: 2026-09-21T00:55:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_locale-independent-identifier-comparison.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`lean-challenge-snapshot.sh` compared two identifier lists sorted under two different
collations (ambient-locale `sort -u` on one side, Python code-point `sorted()` on the other)
with `comm`, which silently corrupts results when its two inputs are not sorted in the same
order. Under `en_US.UTF-8`, mixed-case identifiers reordered relative to `hn_stab`, producing a
false "identifier-set mismatch" (exit 71) that named the SAME identifier as both "only in
goals" and "only in declared." All three plan phases are complete: a RED regression case was
added first, the collation was pinned at the narrowest possible scope, and the fix was
redeployed into the one consuming repo that loads the lean extension.

## What Changed

- `agent-system/extensions/lean/scripts/tests/fixtures/challenge/plan_mixed_case.md` — new
  fixture naming `hnOpenMirror`, `hnStabMirror`, `hn_stab` in both `**Goals**:` and the
  `## Lean Challenge Statements` block, chosen because these three names sort differently under
  dictionary collation (`hnOpenMirror, hn_stab, hnStabMirror`) than under code-point order
  (`hnOpenMirror, hnStabMirror, hn_stab`).
- `agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` — added Case R5
  between R4 and M1: probes `locale -a` for a UTF-8 dictionary-collation locale (`en_US.UTF-8`/
  `en_US.utf8`, `skip`s if neither exists), asserts the mixed-case fixture exits 0 with no
  mismatch text and all three names present under that locale, and asserts the run is
  byte-identical to the same call under `LC_ALL=C`.
- `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh`:
  - `extract_goal_names()`: the trailing `sort -u` is now `LC_ALL=C sort -u`, with a comment
    explaining it must match Python's code-point `sorted()` on the declared side.
  - `cross_validate_identifiers()`: both `comm -23`/`comm -13` calls are now prefixed with
    `LC_ALL=C`, with a comment stating `comm` needs both inputs in one collation and that
    unpinning either site brings back false (or silently missed) mismatches.
  - Both existing Python `sorted()` sites (declared-name lists for R1 and R2) got a one-line
    comment noting they already match the pinned shell side; no functional change there.
  - `sort -V` (plan-file selection) was audited and left untouched — its output is never
    compared against another list.
- `agent-system/extensions/lean/manifest.json` — added the missing
  `tests/fixtures/challenge/plan_mixed_case.md` entry so the new fixture actually deploys (found
  during Phase 3 verification; see Plan Deviations).
- Redeployed: `~/Projects/BimodalLogic/.claude/**` (the only repo, of those checked, whose
  `.claude-extensions.json` lists `lean`) via the non-destructive default resync of
  `deploy-headless.sh` (never `--wipe`).

## Decisions

- Pinned `LC_ALL=C` narrowly, inline on each pipeline, rather than exporting it — matches the
  plan's non-goal of never exporting `LC_ALL` process-wide, and keeps every other message/format
  in the script unaffected.
- Pinned both the producer (`sort -u`) and the consumer (`comm`) as defense-in-depth, per the
  plan's risk mitigation for "a future edit unpins one site."
- Left the two Python `sorted()` sites and the `sort -V` site functionally unchanged, per the
  research's audit finding that only the shell-side producer and `comm` needed a code change.

## Plan Deviations

- **Task 3.6** (added during execution, not in original checklist): the `plan_mixed_case.md`
  fixture added in Phase 1 was not declared in `agent-system/extensions/lean/manifest.json`'s
  file list, so the first non-destructive resync into `~/Projects/BimodalLogic` deployed the
  fixed script and updated suite but NOT the new fixture. Discovered by diffing the deployed
  fixtures directory against the source store during Phase 3 verification. Fixed by adding the
  one missing manifest line and re-running the resync; confirmed byte-identical afterward and
  confirmed the deployed suite (14/14 passing, including R5) actually exercises the fixture.

## Verification

- Build: N/A (shell script, no build step)
- Tests: Passed — `test-lean-challenge-snapshot.sh` 14/14 passing (R1-R5, M1-M3, C1-C5, AV1),
  both in the source store and in the redeployed consuming repo.
- Files verified: Yes
- RED/GREEN proof: R5 failed (rc=71, "hn_stab" named on both sides of the mismatch) against the
  unfixed script; passed after the fix.
- Mutation check: manually reverted only the `sort -u` pin — R5 went RED again (rc=71, "comm:
  file 1 is not in sorted order") while every other case still passed; the pin was restored and
  the suite returned to 14/14. This confirms the new case actually depends on the fix.
- Byte-identity check: `--dry-run` output for the mixed-case fixture is byte-identical under
  `LC_ALL=en_US.UTF-8` and `LC_ALL=C` (empty `diff`).
- No process-wide `export LC_ALL`/`LC_COLLATE`: confirmed via `grep`, zero matches.
- No task-number references in any modified deliverable file: confirmed via `grep`, zero
  matches.

### Audit disposition of all cross-tool sort/compare sites

| Site | Line (source store) | Disposition |
|------|------|------|
| `extract_goal_names()` — `sort -u` | ~353 | **Pinned** `LC_ALL=C` — feeds `comm`, was the false-mismatch root cause |
| `cross_validate_identifiers()` — `comm -23`/`comm -13` | ~461-462 | **Pinned** `LC_ALL=C` — defense-in-depth, same reasoning |
| R1 extractor — Python `sorted(set(declared_names))` | ~440 | **Not needed** — already code-point order; commented to note it matches the pinned shell side |
| R2 extractor — Python `sorted(names)` | ~616 | **Not needed** — already code-point order; commented likewise |
| Plan-file selection — `sort -V` | ~145 | **Not needed** — version-sorts filenames to pick the latest plan file; output is never compared against another list |

## Impacts

- `lean-challenge-snapshot.sh --dry-run` (and the equivalent commit path) no longer produces a
  spurious exit-71 identifier mismatch for mixed-case Lean identifiers under a dictionary-
  collation ambient locale (e.g. `en_US.UTF-8`), the common case on most developer machines.
  This closes the dangerous silent-pass direction too: two genuinely different identifier sets
  can no longer accidentally compare equal under mismatched collations.
- Any running agent invoking this tool from `~/Projects/BimodalLogic` picks up the fix
  immediately — the fix was source-store-only until the Phase 3 redeploy landed it.

## Follow-ups

- None required for acceptance. Optionally, a context/patterns doc for this "two sorted lists
  compared with `comm` must share one collation" hazard class could help future scripts avoid
  the same defect, but the plan explicitly scoped that out as a follow-up, not required here.

## References

- Plan: `specs/246_snapshot_locale_independent_identifier_comparison/plans/01_locale-independent-identifier-comparison.md`
- Research: `specs/246_snapshot_locale_independent_identifier_comparison/reports/01_locale-independent-identifier-comparison.md`
- Modified: `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh`
- Modified: `agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh`
- Modified: `agent-system/extensions/lean/manifest.json`
- New: `agent-system/extensions/lean/scripts/tests/fixtures/challenge/plan_mixed_case.md`
