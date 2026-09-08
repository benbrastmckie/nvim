# Implementation Summary: Task #159

- **Task**: 159 - Add an independently-gated reclamation pass for orphaned Lean LSP process trees
- **Status**: [COMPLETED]
- **Started**: 2026-09-07T00:00:00Z
- **Completed**: 2026-09-07T20:16:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: Task 158 (VmSwap-aware refresh memory accounting) — completed
- **Artifacts**: plans/01_lean-lsp-reclamation-pass.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added a second, fully independent detection-and-reclamation pass to `claude-refresh.sh` for
orphaned `lake serve` -> `lean --server` -> `lean --worker` process trees spawned by
`lean-lsp-mcp` (which has no idle timeout or LRU eviction of its own). The pass takes its own
`ps -C lake,lean` snapshot, uses its own comm+argv predicates, gates candidacy tree-wide (every
member must be idle), reuses the existing cgroup/UID exclusions and VmSwap-aware memory
accounting unchanged, and terminates strictly workers -> server -> `lake serve` root. All six
plan phases completed; the full test suite grew from 17 to 49 passing assertions with two
verified non-vacuousness checks (predicate inversion, termination-order reversal), and
`is_claude_executable_comm` remains byte-identical to its pre-task form.

## What Changed

- `agent-system/extensions/core/scripts/claude-refresh.sh` — added `is_lean_serve_comm`,
  `is_lean_server_comm`, `is_lean_worker_comm` predicates; `LEAN_LSP_IDLE_THRESHOLD_MIN`
  (default 240, env-overridable); `LEAN_SNAPSHOT_PS_FIELDS` + `take_lean_snapshot()`;
  `lean_row_is_idle()`; `detect_lean_candidate_trees()` (tree assembly + tree-wide gate +
  VmSwap-aware per-tree/per-member memory accounting); `terminate_pid()` (extracted from the
  original inline escalation loop, reused by both passes); `run_claude_pass()`/`run_lean_pass()`
  (the original `main()` body restructured into two returning functions so both passes always
  run); `print_help()` extended with the new environment variable.
- `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` — added assertion
  block (f) (predicate cross-contamination in both directions, mutual exclusivity, zombie-row
  rejection, `lake build`/`lake exe cache get` rejection) and block (g) (synthetic 5-row Lean
  tree via fake `ps`, fixture `/proc/<pid>/status`, dry-run-clean assertion, `--force` ORDERING
  assertion via a fake `kill` that shadows the bash builtin, Claude-pass-unaffected assertion);
  extended the mutation-check marker list with all nine new function names.
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md` — fifth "Process Safety" bullet
  plus threshold documentation; new `AskUserQuestion` confirmation block in Step 2 (closing a
  pre-existing gap where the step stored output but never actually prompted).
- `agent-system/extensions/core/commands/refresh.md` — parallel "Process Protection" bullet plus
  threshold documentation.
- `specs/159_orphaned_lean_lsp_reclamation_pass/summaries/01_lean-lsp-reclamation-pass-summary.md`
  — this file.

## Decisions

- `is_lean_serve_comm` matches on a `*" serve"*` argv substring (space-prefixed), correctly
  rejecting `lake build`/`lake exe cache get` and the observed `lake <defunct>` zombie form
  (exact `case` match on `lake` never matches `"lake <defunct>"`).
- `take_lean_snapshot()` distinguishes `ps -C`'s two distinct nonzero-exit outcomes: an empty
  match (exit 1, empty stdout/stderr — normal, not an error) versus a genuine `ps` failure (exit
  nonzero, non-empty error text — loud failure).
- `lean_row_is_idle()` truncates `pcpu` to its pre-decimal integer portion (no bc/floats
  dependency, matching `format_memory`/`get_vmswap_kb`'s existing integer-only convention);
  anything reporting 1% CPU or more is never idle.
- `terminate_pid()` returns a three-way code (0 terminated, 1 failed, 2 already-gone-not-counted)
  rather than a plain boolean, to reproduce the original loop's exact counting behavior; callers
  must invoke it from an `if`/`||` context, never as a bare statement, since a non-zero return is
  a common expected outcome under this script's `set -e`.
- Lean tree termination order is workers (any sibling order) -> server -> root, built as one
  ordered pid list per tree and iterated once, so multiple candidate trees are each fully ordered
  independently.
- `kill` is a bash builtin, not an external command — a plain `PATH=` override (the pattern used
  successfully for faking `ps`) is silently ignored for it. The test suite's fake `kill` is
  shadowed via `enable -n kill` inside a dedicated `bash -c` subshell that then `source`s the
  script and calls `main` explicitly (sourcing bypasses the `BASH_SOURCE[0]==$0` auto-run guard).

## Plan Deviations

- **Task 5.1** (fake `ps` fixture) altered: the fixture's fake `ps` answers every invocation
  shape itself (the `-p` self-check, `-C lake,lean`, and the plain `-eo` table) rather than
  delegating non-matching calls to a resolved real `ps` (the (d-2) ancestry-walk technique) —
  not needed here since none of the fixture's five synthetic rows need to distinguish the running
  test script's own pid.

## Verification

- Build: N/A (shell script, no build step)
- Tests: Passed — `test-claude-refresh-matcher.sh` 49/49 (grew from 17 pre-task); two
  non-vacuousness spot-checks performed and reverted (predicate inversion -> RED -> revert ->
  GREEN; termination-order reversal -> RED -> revert -> GREEN)
- Files verified: Yes — `bash -n` syntax check on every edited shell script; task-reference lint
  clean on all four edited files' trees; live `--dry-run`/`--help` runs against the real machine
  confirmed correct output and that no process was ever terminated by any part of this work

## Impacts

- `/refresh` (and the hourly `claude-refresh.timer --dry-run` cadence) now also detects and can
  reclaim idle Lean LSP process trees, closing the memory-leak pattern the task's research
  diagnosed (a 13-hour-idle tree observed holding 2.06 GiB of swap).
- The interactive (`/refresh` with no flags) path now actually prompts for confirmation before
  terminating anything, closing a pre-existing functional gap the script's own header comment had
  assumed was already closed.

## Follow-ups

- None.

## References

- Plan: `specs/159_orphaned_lean_lsp_reclamation_pass/plans/01_lean-lsp-reclamation-pass.md`
- Report: `specs/159_orphaned_lean_lsp_reclamation_pass/reports/01_lean-lsp-reclamation-pass.md`
- Progress files: `specs/159_orphaned_lean_lsp_reclamation_pass/progress/phase-{1..6}-progress.json`
- Handoffs: `specs/159_orphaned_lean_lsp_reclamation_pass/handoffs/phase-{1..5}-handoff-*.md`
