# Implementation Summary: Task #174

- **Task**: 174 - Add a self-excluding orphaned-build-waiter reaper pass to /refresh
- **Status**: [COMPLETED]
- **Started**: 2026-09-22T06:00:00Z
- **Completed**: 2026-09-22T06:34:33Z
- **Effort**: ~1 hour
- **Dependencies**: None
- **Artifacts**: plans/01_orphan-waiter-reaper-pass.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added a fifth, independently-gated pass (`run_build_waiter_pass`) to `claude-refresh.sh` that
reaps orphaned build-waiter poll loops -- the defect class that twice killed an ad-hoc cleanup
shell via self-match (`pgrep -f 'until grep' | ... | kill` matching its own command line, exit
144). The new pass takes its own atomic `ps -eo` snapshot (adding a `pgid` column no other pass
reads), detects two signature families (the canonical bounded-build-waiter idiom and the legacy
self-match shape it replaces), and widens self-exclusion from pid/ppid to also cover the reaper's
own process group and its full ancestor chain up to PID 1 -- all from that one frozen snapshot,
fail-closed if its own row is missing. Both pass-inventory docs and the systemd unit's ruling
comment were updated to match.

## What Changed

- `agent-system/extensions/core/scripts/claude-refresh.sh` -- new pass section
  (`BUILD_WAITER_SNAPSHOT_PS_FIELDS`, `BUILD_WAITER_REAP_MIN`/`BUILD_WAITER_CEILING_MIN`,
  `take_build_waiter_snapshot`, `is_shell_comm`, `build_waiter_family`,
  `build_waiter_row_is_idle`, `build_self_exclusion_set`, `run_build_waiter_pass`), wired into
  `main()` after `run_lean_pass`; `print_help()` and the top-of-file safety header updated.
- `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` -- new assertion
  (k): 6 unit-level checks, a 12-row end-to-end fixture (3 expected selections), gate assertions
  across `--dry-run`/no-flag/`--force`, a fail-closed end-to-end run, a structural no-`pgrep`
  check, and two per-clause mutation checks (pgid, ancestor-chain). The five pre-existing fake
  `ps` fixtures were updated to emit no rows for a pgid-bearing field spec. Also fixes a real bug
  found during this work: `build_waiter_family()` was originally called via
  `$(build_waiter_family ...)`, which forks a subshell and silently discards its
  `BUILD_WAITER_EMBEDDED_PID` side effect -- fixed to set two globals and be called as a plain
  statement.
- `agent-system/extensions/core/commands/refresh.md` -- new row 5 in "What It Cleans" (old rows
  5-10 renumbered to 6-11), new `### Orphaned Build Waiters` subsection, Process Protection
  bullet, `--force` Options-row update.
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md` -- matching row 5 in "Pass
  Inventory," Process Safety bullets (including both env-var overrides), and a Step 2 note on the
  no-flag survey's reap-without-confirmation behavior and the confirmation-trigger carve-out.
- `agent-system/extensions/core/systemd/claude-refresh.service` -- re-derived "new-passes ruling"
  comment: `main()` now calls five passes; the new pass's destructive trigger is the absence of
  `--dry-run`, not `--force`, but the unit stays non-destructive because its `ExecStart` always
  passes `--dry-run`.
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` -- one-sentence pointer
  naming the new pass as a reaper matching the canonical idiom's signature.

## Decisions

- Self-exclusion is computed from the SAME frozen snapshot the pass already takes (no second
  query), per the plan's "third option": the new pass's own field list adds `pgid`, leaving
  `SNAPSHOT_PS_FIELDS` and every other pass's fixed-column `read` sites untouched.
- The Family A ceiling check compares `etimes` directly against `BUILD_WAITER_CEILING_MIN * 60`
  seconds rather than reusing `build_waiter_row_is_idle` a second time, matching the plan's
  literal wording.
- The fail-closed warning text deliberately omits the literal `$$` pid value -- embedding it made
  `--dry-run` and `--force` output diverge non-deterministically in the existing zombie-pass
  output-equality assertion (each subprocess invocation has a different pid).
- Every mention of the literal substring "pgrep" was avoided in the new pass's script comments
  and documentation prose (rephrased as "process-name-substring search"), matching Phase 1's own
  verification step (`grep -n 'pgrep' claude-refresh.sh` must find nothing in the new block).

## Plan Deviations

- **Phase 4, task 1** altered: the plan's literal "columns 1, 4, 5, and 6" instruction was
  corrected to columns 2/5/6/7, since a raw `awk -F'|'` split of an 8-pipe-delimited markdown
  table row places Pass at field 2 and Gate/Destructive/Hourly-cadence at fields 5/6/7 (field 1 is
  the empty string before the leading pipe). See the plan's Phase 4 task annotation and
  `progress/phase-4-progress.json`'s `deviations` array.

## Verification

- Build: N/A (bash script; verified via `bash -n` and `shellcheck`)
- Tests: Passed -- `test-claude-refresh-matcher.sh` 112/112, run four times with no flakiness;
  both mutation checks confirm RED against a mutant with the pgid/ancestor-chain clause removed
- Files verified: Yes

## Impacts

- `/refresh` (and the hourly `claude-refresh.timer`, in report-only form) now surfaces and, on an
  explicit non-`--dry-run` invocation, reaps orphaned build-waiter poll loops -- closing the leak
  class that previously required manual, error-prone `pgrep`-based cleanup.
- No change to any existing pass's detection, `SNAPSHOT_PS_FIELDS`, or the systemd unit's
  `ExecStart` (still `--dry-run`-only).

## Follow-ups

- None required for this task. The research report's noted follow-up (an argv-parsing addendum to
  `bounded-build-waiter.md`) was addressed minimally via the one-sentence pointer added in Phase
  3; a fuller addendum remains genuinely out of scope, as the plan's Non-Goals state.

## References

- Plan: `specs/174_refresh_orphan_waiter_reaper/plans/01_orphan-waiter-reaper-pass.md`
- Research: `specs/174_refresh_orphan_waiter_reaper/reports/01_orphan_waiter_reaper.md`
- Progress files: `specs/174_refresh_orphan_waiter_reaper/progress/phase-{1,2,3,4}-progress.json`
- Handoffs: `specs/174_refresh_orphan_waiter_reaper/handoffs/phase-{1,2,3,4}-handoff-*.md`
