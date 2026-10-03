# Implementation Summary: Task #217

- **Task**: 217 - Cost-aware idle Lean tree reclamation in /refresh: PSS accounting, CPU-delta idleness, notify-before-kill
- **Status**: [COMPLETED]
- **Started**: 2026-10-02T00:00:00Z
- **Completed**: 2026-10-02T06:10:00Z
- **Effort**: ~6 hours (actual, across 9 phases)
- **Dependencies**: None blocking
- **Artifacts**: plans/01_pss-accounting-idle-notify.md, summaries/01_pss-accounting-idle-notify-summary.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Replaced `claude-refresh.sh`'s Claude and Lean passes' double-counting `RSS + VmSwap` memory
accounting with a PSS-based (`smaps_rollup` `Pss_Anon + SwapPss`) reclaimable figure that never
double-counts shared mmapped pages (e.g. Mathlib `.olean` files shared by N Lean workers), fixing
the live-observed "15.1 GB reclaimable" against a real ~2.3 GB reclaim. Built a CPU-delta idle
state machine replacing the broken `pcpu`/`etimes` gate (which misjudged long-lived active trees
as idle), a 1 GB memory-floor cost gate, a `--lean-tree` re-verifying targeted-termination mode,
and a notify-before-kill desktop-notification prompt path with snooze/dedupe and graceful
dependency degrade. All 9 planned phases completed; the full test suite grew from a 112-assertion
baseline to 163 passing assertions, with zero failures at completion.

## What Changed

- `agent-system/extensions/core/scripts/claude-refresh.sh` — `get_pss_reclaimable_kb()` (PSS
  reclaimable helper with approximate-labeled fallback); `read_proc_stat_fields()` (comm-gotcha-
  robust `/proc/PID/stat` parser); `read_lean_tree_state()`/`write_lean_tree_state()` (atomic,
  corruption-tolerant state-file I/O); `update_lean_tree_cpu_state()` (CPU-delta idle state
  machine with pruning); `LEAN_LSP_MEM_FLOOR_MB`/`LEAN_LSP_SNOOZE_MIN` env vars; restructured
  `detect_lean_candidate_trees()` to detect every live tree unconditionally and compute an
  eligibility cost gate (idle AND over the memory floor); restructured `run_lean_pass()`'s report
  to classify `active`/`idle, cheap, kept`/`eligible` and gate termination on eligibility;
  `terminate_lean_tree_ordered()` (shared ordering helper); `run_lean_tree_targeted_termination()`
  (re-verifying `--lean-tree` mode); `have_notify_send()`/`have_systemd_run_for_prompt()`/
  `have_dbus_session()` (dependency probes); `maybe_prompt_for_lean_tree()` (notify-before-kill
  prompt launcher with dedupe); `record_lean_tree_snooze()` and the internal
  `--lean-tree-snooze=` entry point; `main()`'s `--lean-tree=`/`--lean-tree-snooze=` early-return
  dispatch (never folded into the five-pass sequence); corrected the `pcpu` comment; deleted
  `lean_row_is_idle()`; converted a third (unanticipated) `get_vmswap_kb()` call site in the MCP
  fan-out pass for consistency.
- `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` — three new/extended
  assertion blocks (PSS accounting with shared-page de-duplication proof; CPU-delta state machine,
  PID reuse, state-file tolerance, and the floor gate on both sides; the full prompt path —
  Kill/Keep outcomes, three re-verification refusals, snooze dedupe, three dependency degrades,
  unit-name constraint, and the active-tree acceptance bar), plus `install_neutral_notify_stubs()`
  to keep pre-existing eligible-tree fixtures hermetic against this sandbox's genuinely-available
  `notify-send`/`systemd-run`/DBus. Suite baseline 112 passed/0 failed → 163 passed/0 failed.
- `agent-system/extensions/core/commands/refresh.md` — Pass Inventory rows 1-2 updated for the PSS
  figure and the cost gate; new prompt-flow, `--lean-tree`, and env-var documentation.
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md` — same Pass Inventory updates;
  fixed Step 2's interactive-confirmation trigger (see Plan Deviations); prompt-flow and
  `--lean-tree` documentation.
- `agent-system/extensions/core/systemd/claude-refresh.service` — extended the "New-passes ruling"
  header to cover `--lean-tree`/`--lean-tree-snooze` as early-return modes; NixOS `PATH` note.
- `agent-system/extensions/core/systemd/claude-refresh.timer` — cadence-adequacy comment (no
  behavioral change).

## Decisions

- PSS reclaimable figure excludes `Pss_File` (shared cache) entirely rather than attempting any
  cross-process de-duplication of it — file-backed pages are evictable page cache regardless, so
  the kernel can already reclaim them without killing anything.
- The CPU-delta state file (`~/.local/state/claude-refresh/lean-trees.json`) is keyed on
  `root_pid:starttime`, making PID reuse structurally safe (a reused pid gets a different
  starttime and therefore a brand-new, history-free key) rather than requiring a separate
  reuse-detection check.
- The notify-before-kill unit's own inline script re-invokes `claude-refresh.sh` itself via the
  plain `--lean-tree=`/`--lean-tree-snooze=` CLI entry points on either outcome, rather than
  embedding jq/state-file logic directly in the transient unit — keeps the unit's own command a
  simple two-way branch and reuses already-tested code paths.
- Kill-path termination ordering in the test suite is proven via `terminate_pid()`'s own "already
  gone" log-line sequence on fictional pids, not a fake-`kill`-log override, since the Kill
  outcome re-invokes `$SELF_SCRIPT` as a genuine child process that `enable -n kill` (shell-local)
  cannot reach.

## Plan Deviations

- **Phase 1**: Converted a third, unanticipated `get_vmswap_kb()` call site (the MCP fan-out
  pass) to the new PSS helper for consistency, but left that pass's report format unchanged
  (out of the dispatch's named report-format scope).
- **Phase 4**: Assertion (g) and the Phase 2 Lean-PSS full-script cases depended on CPU-delta
  fixtures not yet built; assertion (g) was deferred to Phase 5 as explicitly sanctioned by the
  plan's own Phase 4 verification; the Lean-PSS cases were fixed immediately since they were
  self-owned and bounded.
- **Phase 7-8**: Discovered and fixed three defects outside the original task list, all load-
  bearing for correctness or test-suite safety: (1) `update_lean_tree_cpu_state()` was silently
  dropping the `prompted`/`snooze_until` fields on every detection pass, defeating prompt dedupe
  entirely — fixed by merging onto the prior per-key state object instead of replacing it; (2)
  several pre-existing fixtures now produce eligible trees and this sandbox genuinely has
  `notify-send`/`systemd-run`/DBus available, so those fixtures began launching real desktop
  notifications and real transient systemd units during test runs — fixed via a neutral-stub
  helper; (3) a bare `/usr/bin:/bin` PATH fallback and an inherited `set -e`/`set -u` from
  sourcing `claude-refresh.sh` combined to silently abort the whole test suite on certain
  deliberately-failing assertions — fixed via a PATH-mirror-minus-one-binary technique and the
  `if VAR=$(cmd); then ... else rc=$?; fi` idiom already documented in `scripts/state-write.sh`.
- **Phase 9**: Fixed a real downstream defect in `SKILL.md`'s Step 2 interactive-confirmation
  trigger, which checked for a report string ("No idle Lean LSP process trees found.") that
  Phase 4's unconditional-detection redesign removed entirely; replaced with a check for an
  actually-eligible tree count.

## Verification

- Build: N/A (shell script; no build step)
- Tests: Passed — `test-claude-refresh-matcher.sh` 163/163, up from a 112-assertion baseline
- Files verified: Yes — `shellcheck` clean on both shell files (same pre-existing warning classes
  throughout, no new categories); `deploy-headless.sh` redeployed with `RESULT=landed_verify_clean`
  (33 checks, 0 failures) and the deployed `.claude/scripts/claude-refresh.sh` is byte-identical
  to the source store; `check-task-references.sh` clean on all four Phase 9 deliverable files

## Impacts

- A Lean LSP tree's reported "reclaimable" figure will drop significantly for any multi-worker
  tree sharing a large mmapped file (e.g. Mathlib `.olean`s), matching the real memory a kill
  would free rather than the shared pages' full cost multiplied by worker count.
- An idle Lean tree under the 1 GB floor is never terminated, even under `--force` — this is a
  behavior change from the pre-task posture, where any idle-past-threshold tree was reclaimable
  regardless of cost.
- The hourly `--dry-run` timer run can now launch a real desktop notification for an eligible
  idle tree on a machine with `notify-send`/`systemd-run`/a DBus session bus (this repo's own dev
  sandbox included) — this is new, intentional behavior per the dispatch, not a regression.

## Follow-ups

- The manual end-to-end acceptance check (one real human left-click on one real notification for
  one real, currently-idle Lean LSP tree) could not be performed in this dispatch: `ps -C
  lake,lean` found zero real Lean processes running on this machine, and this is a non-interactive
  agent dispatch with no human present to click a desktop notification regardless. Every
  mechanical piece this check would exercise (real `systemd-run`/`notify-send`/DBus launch
  mechanics, all outcome branches, all re-verification refusals, snooze dedupe, dependency
  degrade) has been verified either by the automated suite or by direct manual testing with real
  (non-stubbed) binaries during this implementation — see Phase 7's and Phase 9's progress
  records for the full detail. A future session with a genuinely idle Lean LSP tree and a human
  present should perform this check once, as the dispatch's own stated acceptance gate.
- The mako notification-daemon config change and the NixOS home-manager unit install
  (`Environment=PATH` fix, timer/service activation) are external `~/.dotfiles` changes per the
  dispatch, not performed in this repo.

## References

- Plan: specs/217_refresh_pss_memory_accounting/plans/01_pss-accounting-idle-notify.md
- Research: specs/217_refresh_pss_memory_accounting/reports/01_pss-accounting-idle-notify.md
- Progress files: specs/217_refresh_pss_memory_accounting/progress/phase-{1..9}-progress.json
