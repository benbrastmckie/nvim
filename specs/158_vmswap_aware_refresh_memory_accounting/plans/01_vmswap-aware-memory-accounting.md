# Implementation Plan: Task #158

- **Task**: 158 - Make refresh memory accounting VmSwap-aware so zram-compressed idle bloat stops reading as harmless
- **Status**: [COMPLETED]
- **Effort**: 1.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/158_vmswap_aware_refresh_memory_accounting/reports/01_vmswap_aware_memory_accounting.md
- **Artifacts**: plans/01_vmswap-aware-memory-accounting.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`claude-refresh.sh` snapshots processes with `ps -eo pid,ppid,uid,tty,etimes,rss,comm,cgroup:200,args`
— RSS only — so a Lean worker at ~2 MB RSS holding ~1.2 GB of zram-compressed `VmSwap` reports as a
~2 MB process and is invisible to every memory figure the script prints. This plan adds a
reporting-only `get_vmswap_kb()` helper reading `VmSwap` from `/proc/PID/status` through an
overridable `PROC_ROOT` seam, threads combined RSS+swap through all three accumulators while
displaying RSS and swap as separate table columns, records the required snapshot-invariant ruling in
the script header, and extends the matcher suite with fixture-driven cases. Definition of done is
the dispatch's acceptance bar: `--dry-run` shows RSS and swap per process, zero/absent `VmSwap`
renders cleanly, a known-value fixture formats correctly, existing matcher cases pass unchanged,
`bash -n` is clean, and the header states the ruling.

### Research Integration

The research report settles the three decisions this plan encodes rather than re-litigating them:
(1) the **invariant ruling** is that a per-candidate `/proc` read does *not* breach the header's
race-freedom argument, because it is reporting-only, happens strictly after classification, and
normalizes a since-exited PID to `0` instead of erroring — and must be argued in the header rather
than assumed; (2) the **seam shape** is a plain `PROC_ROOT="${PROC_ROOT:-/proc}"` path variable, a
lighter sibling of the existing `_pid_is_alive` function-override seam, because only a path (not a
syscall) needs redirecting; (3) **combined accounting with split display** — `total_mem`,
`active_mem`, and `orphan_mem` all sum `rss + swap_kb`, while the orphan table gains a separate
`Swap` column so an operator can see *why* a low-RSS row is worth reclaiming. Research also
confirmed by grep that nothing downstream machine-parses `format_memory` output, so the table shape
may change freely, and flagged the `orphan_details` pipe-field-count mismatch as the single highest
-probability defect in this change.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found; no roadmap phases required.

## Goals & Non-Goals

**Goals**:
- Add `get_vmswap_kb()` beside `format_memory()`, reading `VmSwap` via an overridable `PROC_ROOT`
  seam, returning `0` for both the absent-line and unreadable-file cases without failing the run.
- Make all three memory accumulators (`total_mem`, `active_mem`, `orphan_mem`) swap-inclusive.
- Show RSS and swap as separate columns for every listed process in `--dry-run`/default output.
- Record the snapshot-invariant ruling as an argued paragraph in the script header comment.
- Add matcher-suite cases covering known-value, absent-line, and missing-file fixtures plus a
  full-output field-count check, without disturbing existing cases (a)-(d).

**Non-Goals**:
- Changing the `ps -eo` snapshot field list or the single-snapshot architecture itself. The
  snapshot stays exactly as it is; swap is read separately, after classification.
- Letting swap gate any candidacy, exclusion, or termination decision. The number is display and
  accumulation only.
- Adding or tuning any memory threshold. Thresholds are the concern of the later tasks this one is
  sequenced ahead of; this task only establishes the accounting primitive.
- Touching any other refresh-adjacent file (skill, systemd unit, alias installer) — research
  confirmed none parse the output.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `orphan_details` gains a field but the `IFS='\|' read -r pid mem age cmd` destructuring and `printf` are not updated in the same edit, silently shifting columns | H | M | Phase 3 treats the write site, the read site, and both `printf` lines as one indivisible edit; Phase 4 asserts on full `--dry-run` output shape, not only the isolated helper |
| Reviewer misreads "per-PID /proc read" as reopening the race the header rules out | M | M | Phase 1 lands the argued header ruling *before* the read is introduced, so the justification is in the file at the moment the code arrives |
| PID reuse between snapshot and `/proc` read attributes swap to the wrong process | L | L | Accepted, named residual risk: the figure is reporting-only and never gates a decision; the header ruling states this explicitly rather than leaving it silent |
| Test asserts against the live `/proc` of the test process, making results machine-dependent | M | M | All cases use `PROC_ROOT="$WORKDIR/fakeproc"` heredoc fixtures per shell-script-testing.md; `PROC_ROOT` is restored/unset after the block so it cannot leak into later assertions |
| Host has no swap configured, so `/proc/PID/status` omits `VmSwap` entirely | M | M | `get_vmswap_kb` normalizes empty `awk` output to `0`; a dedicated Phase 4 fixture covers the absent-line case |
| One extra `/proc` read per matched row on every invocation | L | L | Bounded by the already-narrow comm-gated candidate set; same order as existing per-row work |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel. This plan is a strict serial chain: phases 1-3
all edit the same file (`claude-refresh.sh`), so they are serialized to avoid edit contention even
where the logical dependency is weak.

---

### Phase 1: Record the snapshot-invariant ruling in the header [COMPLETED]

**Goal**: Land the argued invariant ruling in the script header *before* any `/proc` read exists, so
the justification is present in the file at the moment the code that needs it arrives.

**Tasks**:
- [x] Add a new paragraph to the header comment block in
      `agent-system/extensions/core/scripts/claude-refresh.sh`, placed after the existing
      "If the platform's `ps` does not support the `cgroup` column..." paragraph and before
      `set -euo pipefail`. *(completed)*
- [x] State the ruling explicitly: a per-candidate `/proc/PID/status` read for `VmSwap` does NOT
      breach the single-snapshot race-freedom argument, because (a) it is reporting-only and feeds
      no `if` that decides active/orphan/excluded, (b) it is performed strictly after the row's
      classification has already been made from the snapshot, and (c) a process that exited between
      snapshot and read yields an empty read normalized to `0`, never a misclassification. *(completed)*
- [x] Name the residual PID-reuse risk in the same paragraph (worst case: a cosmetic figure briefly
      attributed to the wrong process; never a termination decision) rather than leaving it silent. *(completed)*
- [x] Match the surrounding header's existing voice and the "read this before touching the
      predicates below" register — this block is prescriptive documentation, not a changelog entry. *(completed)*

**Timing**: 0.25 hours

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/scripts/claude-refresh.sh` - header comment block only; no
  executable line changes in this phase

**Verification**:
- Diff read-through confirms every changed hunk lies inside the leading `#` comment block and no
  executable statement moved.
- `bash -n agent-system/extensions/core/scripts/claude-refresh.sh` is clean.
- `bash agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` still passes
  (behavior must be byte-identical after a comment-only edit).

---

### Phase 2: Add the PROC_ROOT seam and get_vmswap_kb() helper [COMPLETED]

**Goal**: Introduce the swap-reading primitive as a standalone, directly-callable, fixture-testable
function with no call sites yet — so it can be verified in isolation before any reporting path
depends on it.

**Tasks**:
- [x] Add `PROC_ROOT="${PROC_ROOT:-/proc}"` as an overridable path seam, with a comment noting it
      mirrors the `_pid_is_alive` overridable-seam precedent and exists so tests can point at a
      synthetic fixture directory. *(completed)*
- [x] Add `get_vmswap_kb()` immediately after `format_memory()`, extracting the value with
      `awk '/^VmSwap:/ {print $2; exit}' "$PROC_ROOT/$pid/status" 2>/dev/null` and echoing `0` when
      the result is empty — no `bc`, no `jq`, integer-only, consistent with `format_memory`'s
      existing no-external-dependency constraint. *(completed)*
- [x] Document in the function's comment that a `0` return covers two distinct benign cases (no
      `VmSwap` line because the host has no swap configured; unreadable file because the process
      exited between snapshot and read) and that neither is an error condition. *(completed)*
- [x] Confirm the helper cannot abort the run under `set -euo pipefail`: the `2>/dev/null` plus the
      empty-result branch must leave no path where a nonzero `awk`/redirect status propagates.
      *(completed: verified via ad-hoc known/absent-line/missing-file checks with `set -u`, exit 0)*

**Timing**: 0.25 hours

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/claude-refresh.sh` - `PROC_ROOT` declaration and new
  `get_vmswap_kb()` function, placed directly after `format_memory()`

**Verification**:
- `bash -n agent-system/extensions/core/scripts/claude-refresh.sh` is clean.
- Ad-hoc in-shell check: source the script, then confirm `get_vmswap_kb` returns `0` for a
  nonexistent PID path and the expected integer against a temporary heredoc fixture, with
  `set -u` active and no abort. (Formalized as suite cases in Phase 4.)
- `bash agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` still passes —
  an unreferenced new function must not perturb existing cases.

---

### Phase 3: Thread combined RSS+swap through the reporting path [COMPLETED]

**Goal**: Make every memory figure the script prints swap-inclusive, and give the orphan table a
separate `Swap` column, with the `orphan_details` field-count change applied atomically across its
write site, read site, and both `printf` lines.

**Tasks**:
- [x] In the main loop, immediately after
      `read -r pid ppid uid tty etimes rss comm cgroup args <<< "$line"`, add
      `local swap_kb; swap_kb=$(get_vmswap_kb "$pid")` and `local combined=$((rss + swap_kb))`.
      Declare `swap_kb` and `combined` alongside the existing `local` declaration line.
      *(deviation: altered — swap_kb/combined are declared on the existing `local` line as
      instructed, but the assignment is placed after the candidacy gate (`is_claude_executable_comm`)
      rather than immediately after the `read -r ... <<< "$line"` line, so the reporting-only /proc
      read is bounded to the already-narrow comm-gated candidate set per the Risks & Mitigations
      table's "per matched row" framing, instead of firing for every row in the full system-wide `ps`
      snapshot)*
- [x] Replace `rss` with `combined` in all three accumulations: `total_mem=$((total_mem + rss))`,
      `active_mem=$((active_mem + rss))`, and `orphan_mem=$((orphan_mem + rss))`. *(completed)*
- [x] Extend the `orphan_details` entry to
      `"$pid|$(format_memory "$rss")|$(format_memory "$swap_kb")|$age|$cmd_display"` — RSS and swap
      stay separate strings, deliberately not pre-collapsed into one combined figure. *(completed)*
- [x] In the same edit, update the consumer `IFS='|' read -r pid mem age cmd <<< "$detail"` to
      `IFS='|' read -r pid mem swap age cmd <<< "$detail"`, and update both the header `printf` and
      the row `printf` to a five-column form adding `Swap` between `Memory` and `Age` (header labels
      and the dashed separator row both). *(completed)*
- [x] Leave `format_memory()` itself unchanged — it is reused as-is for RSS, swap, and totals
      individually. *(completed)*
- [x] Confirm the "Found N orphaned processes using ...", "Total memory that can be reclaimed: ...",
      and force-mode "Memory reclaimed: ~..." lines now render swap-inclusive totals by virtue of
      `orphan_mem` alone; they need no edit of their own. *(completed: verified via live fake-ps/fake-proc
      run reproducing the dispatch's ~2 MB RSS / ~1.2 GB VmSwap scenario — totals and Swap column both
      render correctly)*

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts exactly four `format_memory` reporting call sites (the
per-row `orphan_details` entry, the "Found N orphaned processes using" line, "Total memory that can
be reclaimed", and the force-mode "Memory reclaimed"), of which only the first needs editing because
the other three read `orphan_mem`. Confirm at implementation time with
`grep -n 'format_memory' agent-system/extensions/core/scripts/claude-refresh.sh` before editing; if
the count differs from four, or if any call site passes something other than `rss`/`orphan_mem`,
re-derive the edit set from the grep rather than following this list.

**Files to modify**:
- `agent-system/extensions/core/scripts/claude-refresh.sh` - main loop (swap read, combined
  computation, three accumulators, `orphan_details` write), report block (`read -r` destructuring,
  both `printf` format strings and their labels)

**Verification**:
- `bash -n agent-system/extensions/core/scripts/claude-refresh.sh` is clean.
- `bash agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` passes with all
  existing cases (a)-(d) unmodified.
- Live `bash agent-system/extensions/core/scripts/claude-refresh.sh --dry-run` renders a table whose
  columns line up under the new five-column header, with a `Swap` value present for every listed
  row — confirming no field-count mismatch between the write and read sites.

---

### Phase 4: Add fixture-driven VmSwap test cases and run the acceptance pass [COMPLETED]

**Goal**: Close the verification bar with deterministic, machine-independent cases for the new
helper and the changed output shape, plus a `format_memory` case that closes a pre-existing coverage
gap at near-zero marginal cost.

**Tasks**:
- [x] Append a `# Assertion (e): VmSwap-aware memory accounting` section to
      `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh`, before the
      mutation-check section, following the file's `# =====` banner convention and its
      `pass`/`fail`/`info` helper structure. *(completed)*
- [x] Build fixtures as heredocs under `$WORKDIR/fakeproc/<pid>/status` — never against live `/proc`
      or a real PID — per `.claude/context/standards/shell-script-testing.md`. *(completed)*
- [x] Case: known value. A fixture containing `VmSwap:\t    12345 kB` yields `get_vmswap_kb` ==
      `12345`. *(completed)*
- [x] Case: absent line. A fixture status file with no `VmSwap:` line at all yields `0`, not an
      error (no-swap-configured host). *(completed)*
- [x] Case: missing file. A nonexistent `<pid>/status` path yields `0`, not an error, and does not
      abort the sourced test shell. *(completed)*
- [x] Case: formatting. `format_memory 12345` renders the expected unit string — closes the
      pre-existing `format_memory` coverage gap noted in research. *(completed: renders "12.0 MB")*
- [x] Case: output shape. Assert on full `--dry-run` output (not only the isolated helper) that the
      table carries both a `Memory` and a `Swap` column, structurally catching an
      `orphan_details` field-count mismatch — matching how the existing (d-2) case asserts on full
      script output. *(deviation: altered — implemented as two separate pass/fail assertions (header
      shape, then row values) rather than one combined case, for clearer failure diagnosis; both
      assertions cover the same single output-shape scenario the task describes)*
- [x] Set `PROC_ROOT="$WORKDIR/fakeproc"` for the block and restore/unset it immediately afterward,
      exactly as `_pid_is_alive` is restored after Assertion (c), so it cannot leak. *(completed)*
- [x] Extend the mutation-check section's static-absence marker list to include `get_vmswap_kb`,
      keeping its existing framing: against today's pre-fix HEAD the function does not exist, so
      every new case fails with `command not found` (RED confirmed) — a static absence check, not a
      fabricated dynamic re-run. *(completed)*
- [x] Run the full acceptance pass and confirm each dispatch acceptance criterion individually.
      *(completed)*

**Timing**: 0.75 hours

**Depends on**: 3

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts five new cases in a new Assertion (e) block and that the
existing four assertion groups (a)-(d) pass unchanged. Confirm at implementation time by running the
suite before and after the addition and comparing the pre-existing `[PASS]` lines verbatim; if any
previously-passing case changes status, treat that as a Phase 3 regression to fix rather than a test
to adjust.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` - new Assertion (e)
  section and an extended mutation-check marker list

**Verification**:
- `bash -n` clean on both the test suite and `claude-refresh.sh`.
- `bash agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` exits 0 with the
  pre-existing `[PASS]` lines unchanged and the new (e) cases passing.
- `bash agent-system/extensions/core/scripts/claude-refresh.sh --dry-run` shows RSS and swap for
  every listed process.
- `grep -n 'VmSwap' agent-system/extensions/core/scripts/claude-refresh.sh` shows the ruling present
  in the header comment.

---

## Testing & Validation

- [x] `bash -n agent-system/extensions/core/scripts/claude-refresh.sh` exits 0. *(completed)*
- [x] `bash -n agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` exits 0.
      *(completed)*
- [x] `bash agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` exits 0;
      existing cases (a)-(d) pass unchanged, new (e) cases pass. *(completed: 18/18 passed, 3
      consecutive runs, pre-existing 12 [PASS] lines byte-identical)*
- [x] `bash agent-system/extensions/core/scripts/claude-refresh.sh --dry-run` displays a `Swap`
      column with a value for every listed process, columns aligned. *(completed: verified via
      fixture-driven fake-ps/PROC_ROOT harness in Assertion (e) since no live orphans exist on this
      machine at implementation time; live run confirms no-orphan path unaffected)*
- [x] A process with zero or absent `VmSwap` renders as `0 KB` (or equivalent) rather than erroring
      or producing an empty column. *(completed: get_vmswap_kb returns "0" for absent-line and
      missing-file fixtures)*
- [x] The synthetic known-VmSwap fixture formats to the expected string. *(completed: 12345 kB ->
      "12.0 MB")*
- [x] The header comment states the snapshot-invariant ruling, with the reporting-only,
      post-classification, and normalize-to-zero grounds argued explicitly. *(completed)*
- [x] No file outside `agent-system/extensions/core/` was modified; no `.claude/**` file was
      hand-edited (canonical-source constraint). *(completed: git status confirms only
      claude-refresh.sh, test-claude-refresh-matcher.sh, and specs/158_.../ paths touched by this
      dispatch)*
- [x] No task-number references appear in either modified file (deliverable rule). *(completed:
      grep for task-number patterns in both files returns none)*

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/claude-refresh.sh` - header invariant ruling paragraph,
  `PROC_ROOT` seam, `get_vmswap_kb()` helper, swap-threaded main loop and report block
- `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` - Assertion (e)
  section, extended mutation-check marker list
- `specs/158_vmswap_aware_refresh_memory_accounting/summaries/01_*-summary.md` - execution summary
  (produced by the implementation phase)

## Rollback/Contingency

All changes are confined to two files in a single git-tracked directory with no schema, state, or
generated-artifact side effects, so `git checkout -- agent-system/extensions/core/scripts/claude-refresh.sh
agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` (on a clean tree, or after
`bash .claude/scripts/git-snapshot.sh 158`) fully reverts. Because phases commit per green sub-step,
a partial rollback to any completed phase boundary is available via `git revert` of that phase's
commit. If the `orphan_details` field-count change proves unstable under review, a narrower fallback
preserves the accounting win: keep the swap-inclusive accumulators and drop only the added `Swap`
column, restoring the four-field pipe format — this still satisfies the totals half of the acceptance
bar while sacrificing per-row visibility, and should be treated as a degraded outcome to be flagged,
not a silent substitution.
