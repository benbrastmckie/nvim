# Implementation Summary: Task #158

- **Task**: 158 - Make refresh memory accounting VmSwap-aware so zram-compressed idle bloat stops reading as harmless
- **Status**: [COMPLETED]
- **Started**: 2026-09-07T00:00:00Z
- **Completed**: 2026-09-07T01:05:00Z
- **Effort**: ~1.75 hours
- **Dependencies**: None
- **Artifacts**: plans/01_vmswap-aware-memory-accounting.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`claude-refresh.sh` previously accounted memory using only RSS from a single `ps -eo` snapshot,
so a process holding gigabytes of zram-compressed `VmSwap` at only a few MB RSS (the observed Lean
worker case: ~2 MB RSS, ~1.2 GB VmSwap) was invisible to every memory figure the script prints.
This implementation adds a reporting-only `get_vmswap_kb()` helper reading `/proc/PID/status`
through an overridable `PROC_ROOT` seam, threads combined RSS+swap through all three memory
accumulators while displaying RSS and swap as separate table columns, records the required
snapshot-invariant ruling in the script header, and extends the matcher suite with six new
fixture-driven cases. All four plan phases are `[COMPLETED]`.

## What Changed

- `agent-system/extensions/core/scripts/claude-refresh.sh` — added an argued invariant-ruling
  paragraph to the header comment (states that the per-candidate `/proc` read is reporting-only,
  post-classification, and normalizes an exited PID to `0`, so it does not reopen the
  single-snapshot race-freedom argument, plus the named residual PID-reuse risk); added the
  `PROC_ROOT="${PROC_ROOT:-/proc}"` overridable seam and `get_vmswap_kb()` helper directly after
  `format_memory()`; threaded `swap_kb`/`combined` (`rss + swap_kb`) through `total_mem`,
  `active_mem`, and `orphan_mem`; extended `orphan_details` to carry a separate swap field and
  updated both the consumer `read -r` destructuring and the header/row `printf` format strings to
  a five-column form (`PID | Memory | Swap | Age | Command`).
- `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` — added an
  `# Assertion (e): VmSwap-aware memory accounting` section (known-value, absent-line,
  missing-file, `format_memory` formatting, and a two-part `--dry-run` output-shape check using a
  fixture-driven fake `ps` + `PROC_ROOT` harness) and extended the mutation-check's static-absence
  marker list to include `get_vmswap_kb`.

## Decisions

- **Invariant ruling**: the per-candidate `/proc/PID/status` read does NOT breach the header's
  single-snapshot race-freedom argument — it is reporting-only, happens strictly after a row's
  classification, and normalizes an exited-PID read to `0`. The residual PID-reuse risk (a
  cosmetic figure briefly attributed to the wrong process) is named explicitly rather than left
  silent. Argued in the header per the dispatch's ruling requirement.
- **Read placement**: the plan's task text said to compute `swap_kb`/`combined` "immediately
  after" the `read -r ... <<< "$line"` line, but the Risks & Mitigations table frames the cost as
  "bounded by the already-narrow comm-gated candidate set" (i.e., "per matched row"). Computing
  swap for every row in the full system-wide `ps` snapshot (before the `is_claude_executable_comm`
  gate) would contradict that framing, so the assignment was placed immediately after the
  candidacy gate passes, while `swap_kb`/`combined` are still declared on the existing `local`
  line as instructed. See Plan Deviations.
- **Output-shape test**: implemented as two separate pass/fail assertions (header-shape check,
  then row-value check) rather than one combined case, for clearer failure diagnosis if either
  half regresses independently.

## Plan Deviations

- **Task 3.1** altered: `swap_kb`/`combined` assignment moved to immediately after the candidacy
  gate (`is_claude_executable_comm`) rather than immediately after the `read -r` line, to keep the
  extra `/proc` read bounded to the comm-gated candidate set per the plan's own risk framing. The
  `local` declaration itself stayed on the existing declaration line as instructed.
- **Task 4 (output-shape case)** altered: split into two assertions (header shape, row values)
  instead of one combined case; both cover the same scenario the task describes.

## Verification

- Build: N/A (shell script, no build step)
- Tests: Passed — `bash agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh`
  exits 0 with 18/18 cases passing (12 pre-existing cases (a)-(d) byte-identical, 6 new Assertion
  (e) cases), confirmed stable across 3 consecutive runs
- Files verified: Yes — `bash -n` clean on both `claude-refresh.sh` and
  `test-claude-refresh-matcher.sh`

## Impacts

- Every memory figure `claude-refresh.sh` prints or accumulates (total, active, orphan) is now
  swap-inclusive, so a zram-compressed idle process no longer reads as harmless purely because its
  RSS is small.
- The orphan table's row format changed from a 4-field pipe-delimited entry
  (`pid|mem|age|cmd`) to 5 fields (`pid|mem|swap|age|cmd`); research confirmed no downstream
  consumer machine-parses this output, so this is a display-only widening.
- This is a reporting-only accounting change: no candidacy, exclusion, or termination decision is
  affected. The four existing predicates remain the sole authority over what gets killed.

## Follow-ups

- None. This task deliberately establishes only the accounting primitive; tuning any
  memory-based threshold on top of it is out of scope and left to a later, explicitly sequenced
  task.

## References

- specs/158_vmswap_aware_refresh_memory_accounting/plans/01_vmswap-aware-memory-accounting.md
- specs/158_vmswap_aware_refresh_memory_accounting/reports/01_vmswap_aware_memory_accounting.md
- agent-system/extensions/core/scripts/claude-refresh.sh
- agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh
