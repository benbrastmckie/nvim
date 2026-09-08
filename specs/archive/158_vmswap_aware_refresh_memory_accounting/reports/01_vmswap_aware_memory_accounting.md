# Research Report: Task #158

**Task**: 158 - Make refresh memory accounting VmSwap-aware so zram-compressed idle bloat stops reading as harmless
**Started**: 2026-09-07T19:00:00Z
**Completed**: 2026-09-07T19:22:00Z
**Effort**: Small (single script, one helper + threading through existing display/accumulation, plus new test cases)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/claude-refresh.sh`
- Codebase: `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh`
- Codebase: `.claude/context/standards/shell-script-testing.md`
- Kernel documentation knowledge: `/proc/PID/status` `VmSwap` field semantics
**Artifacts**:
- This report: `specs/158_vmswap_aware_refresh_memory_accounting/reports/01_vmswap_aware_memory_accounting.md`
**Standards**: report-format.md, subagent-return.md, shell-script-testing.md

## Executive Summary

- `claude-refresh.sh`'s snapshot (`SNAPSHOT_PS_FIELDS='pid,ppid,uid,tty,etimes,rss,comm,cgroup:200,args'`) carries no swap information, so a Lean worker holding ~2 MB RSS but ~1.2 GB of zram-compressed `VmSwap` currently reports as a ~2 MB process — invisible to any threshold or "reclaimable memory" total built on RSS alone.
- The fix is additive, not a snapshot redesign: read `VmSwap` from `/proc/PID/status` per matched-Claude-process row, *after* the single atomic `ps -eo` snapshot has already been taken and every candidacy/exclusion decision made from it. This is a reporting-only read — it must never gate the orphan/active/exclusion decision, only the memory figures displayed once a row's fate is already decided by the existing predicates.
- **Invariant ruling (recommended, to be recorded verbatim in the header comment)**: this does **not** breach the documented race-freedom argument. The race the header protects against is a transient PID from the snapshot being re-queried for *liveness/identity* and found to have exited or been replaced, which could flip a candidacy or exclusion decision. A per-row `/proc/PID/status` read for `VmSwap` is categorically different: it never feeds any `if` that decides active/orphan/excluded, and a process that exited between snapshot and this read produces an empty read (handled as swap=0), not a wrong classification. The one operational risk — a PID being reused between snapshot and read, attributing swap to the wrong process — is the same generic race every PID-keyed `/proc` read on Linux carries, already implicitly accepted by the header's own PID-based model, and immaterial to a purely additive display number (worst case: a harmless process's report briefly shows an unrelated process's swap figure, never a termination decision).
- Recommended implementation shape: a new `get_vmswap_kb()` helper beside `format_memory()`, reading through an overridable `PROC_ROOT` (default `/proc`) seam — mirroring the existing `_pid_is_alive` overridable-seam pattern used for `is_live_inhibitor_target` testing — so tests can point it at a synthetic fixture directory instead of a real PID.
- Recommended reporting shape: keep `format_memory()` single-value as-is (reused for RSS, swap, and combined figures individually); add the swap read and a `combined = rss + swap_kb` computation into the per-row loop; extend `orphan_details` to carry both RSS and swap so the printed table shows both; feed `combined` (not raw `rss`) into `total_mem`/`active_mem`/`orphan_mem` accumulation so "Total memory that can be reclaimed" and "Memory reclaimed" reflect real swap-inclusive footprint.

## Context & Scope

Task 158 is the first of a four-task sequence (158-161, created together per the recent
`file_scope` lifecycle commits) and is explicitly sequenced first because it is
cross-cutting: every later refresh-accounting change builds its numbers on top of whatever
memory-accounting primitive this task establishes. Scope for this research pass is confined to
the single script and its matcher test suite named in the dispatch — no other refresh-adjacent
file (skill, systemd unit, alias installer) needs to change, since none of them parse or depend
on `format_memory()`'s exact string shape (confirmed by grep across
`agent-system/extensions/core/` — `format_memory`/RSS/memory formatting is referenced only in
prose documentation, never machine-parsed downstream).

## Findings

### Codebase Patterns

**Current snapshot and reporting pipeline** (`claude-refresh.sh`):
- Line 65: `SNAPSHOT_PS_FIELDS='pid,ppid,uid,tty,etimes,rss,comm,cgroup:200,args'` — single atomic
  `ps -eo` snapshot, documented at lines 12-33 as the basis of the script's race-freedom
  argument (no candidate PID is ever re-queried live for its candidacy/exclusion decision).
- Lines 182-195: `format_memory(kb)` — pure function, KB in, human string out (`KB`/`MB`/`GB`,
  no `bc` dependency, integer-only arithmetic). No existing test coverage for this function
  (confirmed: `grep -n format_memory` against the test suite returns zero hits — this is a
  coverage gap independent of this task, worth closing alongside the new swap cases).
- Main loop (lines ~264-315): for each snapshot row, `rss` is accumulated into `total_mem`
  (every matched Claude process), `active_mem` (rows with a real tty — active sessions,
  `continue`s before reaching orphan checks), and `orphan_mem` (rows that survive every
  exclusion predicate). `orphan_details` is built as a `pid|memory-string|age|cmd` pipe-joined
  entry, consumed later by a `printf`-formatted table.
- Reporting call sites for `format_memory`: the per-row `orphan_details` entry (line 314), the
  "Found N orphaned processes using X" line (339), "Total memory that can be reclaimed" (350),
  and the post-termination "Memory reclaimed: ~X" line (399, force-mode only). These four are
  exactly the "all existing reporting output" the dispatch names.
- **Existing overridable-seam precedent**: `_pid_is_alive()` (lines 138-140) is deliberately
  extracted as a one-line indirection over `kill -0` specifically so
  `test-claude-refresh-matcher.sh` can substitute a deterministic test double for the duration
  of one assertion block, then restore the production definition immediately after (see the
  test file's Assertion (c) section, lines ~109-150). This is the established idiom for making
  an inherently-live-system-dependent primitive testable in this script, and the natural
  template for the new VmSwap read.

**Test suite structure** (`test-claude-refresh-matcher.sh`, 335 lines):
- Sources the script into a `mktemp -d` copy (never the live file) and calls its functions
  directly by name — `format_memory` and the proposed `get_vmswap_kb` would be exercised the
  same way, no subprocess needed for the pure-function cases.
- Fixture convention per `.claude/context/standards/shell-script-testing.md`: inline heredocs
  into the suite's own `mktemp -d` workdir, never resolved against the live `/proc` tree or
  real PIDs for anything the suite asserts on. This directly forbids a naive test design that
  reads the real `/proc/$$/status` of the test process itself and asserts on whatever swap
  value happens to be present on the machine running the suite (non-deterministic, and would
  violate the "never resolve a path against the live tree" rule quoted in that standard for the
  analogous `specs/`/`.claude/` case — the same principle applies to `/proc`).
- The suite's only case requiring a real subprocess and fake binary today is the self-exclusion
  (d-2) case, which builds a `fakebin/ps` on `PATH`. The new VmSwap cases do not need this
  weight — a `PROC_ROOT`-style path-override seam (a plain fixture directory, no fake binary)
  is sufficient and matches the "no committed fixture tree, no fixture-generator script"
  convention for core's own suites: build `$WORKDIR/fakeproc/<pid>/status` with a heredoc line
  per case.
- Mutation-check convention (see the suite's own end-of-file section) expects any new
  predicate-shaped case to be traceable to a specific pre-fix absence; for this task the
  simplest honest framing is "the current script has no `get_vmswap_kb` function at all, so
  every new case fails with `command not found` against today's HEAD" — a static absence check
  parallel to the existing one, not a fabricated dynamic re-run.

### External Resources

- `/proc/PID/status` is a well-documented kernel interface (`proc(5)`). The relevant line has
  the shape `VmSwap:\t    1234 kB` (tab-separated key, whitespace-padded numeric value, unit
  suffix `kB`). It is present (usually as `VmSwap:\t       0 kB`) on any kernel with
  `CONFIG_PROC_PAGE_MONITOR`/swap accounting enabled, which is effectively universal on modern
  Linux, but the dispatch is right to require defensive handling for two real cases:
  1. **No swap configured on the host at all** — some kernels/containers omit the `VmSwap` line
     entirely rather than printing `0 kB`. Must not error; must render as swap=0/no swap.
  2. **Process exited between snapshot and read** — `/proc/PID/status` for a since-exited PID
     either fails to open (`cat`/`awk` returns nothing, non-zero or empty output) or, worse,
     silently refers to a *different* process if the PID has already been recycled. The read
     must tolerate the empty-output case (treat as swap=0, since the row's classification
     already happened from the snapshot and is not being revisited) and the recommendation
     above already accounts for the PID-reuse edge case as an accepted, immaterial residual risk
     for a reporting-only number.
- Standard extraction idiom, no `bc`/`jq`/external dependency (consistent with this script's
  existing no-`bc` constraint in `format_memory`):
  ```bash
  awk '/^VmSwap:/ {print $2; exit}' "$PROC_ROOT/$pid/status" 2>/dev/null
  ```
  `2>/dev/null` covers the "file no longer exists" case cleanly; an empty result from `awk`
  (line absent, or file unreadable) is the single signal to normalize to `0`.

### Recommendations

1. **New helper, placed immediately after `format_memory()`** (the dispatch's own file-target
   ordering: "format_memory, new helper, header invariant comment"):
   ```bash
   # Overridable seam for testability, mirroring _pid_is_alive above. Production default is
   # the real /proc filesystem; tests point this at a synthetic fixture directory instead.
   PROC_ROOT="${PROC_ROOT:-/proc}"

   # Reads VmSwap (kB) for a candidate PID from /proc/PID/status. This is a reporting-only
   # read performed AFTER the candidate's active/orphan/excluded classification has already
   # been decided from the single ps snapshot -- see the header invariant-ruling comment.
   # Returns 0 (not an error) when the status file is unreadable (process exited between
   # snapshot and this read) or when no VmSwap line is present (no swap configured on this
   # host). Never fails the run.
   get_vmswap_kb() {
       local pid="$1"
       local kb
       kb=$(awk '/^VmSwap:/ {print $2; exit}' "$PROC_ROOT/$pid/status" 2>/dev/null)
       if [ -z "$kb" ]; then
           echo 0
       else
           echo "$kb"
       fi
   }
   ```
   `PROC_ROOT` as a plain environment-overridable variable (not a function-wrapped seam like
   `_pid_is_alive`) is sufficient here because the thing under test is a path, not a syscall;
   this is a smaller, equally-testable seam than duplicating the function-override pattern.

2. **Threading through the main loop**: immediately after the existing
   `read -r pid ppid uid tty etimes rss comm cgroup args <<< "$line"`, compute
   `local swap_kb; swap_kb=$(get_vmswap_kb "$pid")` and
   `local combined=$((rss + swap_kb))`. Feed `combined` into all three accumulators
   (`total_mem`, `active_mem`, `orphan_mem`) in place of raw `rss` — this is what makes
   "Total memory that can be reclaimed" and the post-termination "Memory reclaimed" figure
   swap-aware, directly addressing the motivating case (a 2 MB-RSS process is currently
   invisible to these totals; its true ~1.2 GB footprint would now count). Extend the
   `orphan_details` entry to carry RSS and swap as separate fields
   (`"$pid|$(format_memory "$rss")|$(format_memory "$swap_kb")|$age|$cmd_display"`) so the
   printed table gains a `Swap` column between `Memory` and `Age` — this is what satisfies
   "output shows RSS and swap for every listed process" without collapsing the two figures
   into one opaque combined string (a reviewer/operator needs to see *why* a low-RSS row is
   still worth reclaiming).

3. **Header invariant comment**: add a new paragraph to the existing header block (after the
   "If the platform's `ps` does not support the cgroup column..." paragraph, before `set -euo
   pipefail`) stating the ruling from the Executive Summary verbatim — that a per-candidate
   `/proc/PID/status` read is a reporting-only addition that never gates a termination
   decision, is performed strictly after classification, and tolerates a since-exited PID by
   normalizing to swap=0 rather than erroring, so it does not breach the snapshot-based
   race-freedom argument the header establishes for the *candidacy/exclusion* decisions.

4. **Test cases to add to `test-claude-refresh-matcher.sh`** (append a new
   `# Assertion (e): VmSwap-aware memory accounting` section before the mutation-check
   section, following the file's own `=====` banner convention):
   - `get_vmswap_kb` against a fixture `$WORKDIR/fakeproc/<pid>/status` containing a
     `VmSwap:\t    12345 kB` line returns `12345` (known-value fixture, satisfies "a synthetic
     fixture with a known VmSwap value formats correctly").
   - `get_vmswap_kb` against a fixture status file with **no** `VmSwap:` line at all (simulating
     a no-swap-configured host) returns `0`, not an error.
   - `get_vmswap_kb` against a **nonexistent** `<pid>/status` path (simulating a process that
     exited between snapshot and read) returns `0`, not an error, and does not abort the
     (`set -uo pipefail`-run) test shell.
   - `format_memory` fed the known fixture's KB value renders the expected unit string (closes
     the pre-existing, task-158-unrelated `format_memory` coverage gap noted above, at minimal
     marginal cost since the fixture is already being built for the VmSwap cases).
   - All cases use the `PROC_ROOT="$WORKDIR/fakeproc"` override, restored/unset afterward so it
     cannot leak into later assertions in the same sourced shell, exactly as `_pid_is_alive` is
     restored after Assertion (c).
   - Existing matcher cases (a)-(d) must be re-run unmodified after adding (e) to confirm no
     regression — they do not touch `PROC_ROOT` or `get_vmswap_kb` at all, so none are expected
     to be affected, but this should be explicitly re-verified in the implementation phase's
     acceptance pass (`bash agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh`).

## Decisions

- **Invariant ruling**: per-candidate `/proc/PID/status` reads do **not** breach the documented
  snapshot race-freedom invariant, on the grounds stated above (reporting-only, post-decision,
  fails closed to swap=0). This must be recorded in the header comment by the implementation
  phase, not silently assumed.
- **Seam shape**: a plain `PROC_ROOT` environment-overridable path variable, not a
  function-wrapped seam — smaller and sufficient given the seam only needs to redirect a
  filesystem path, unlike `_pid_is_alive` which wraps an actual syscall.
- **Combined accounting**: all three memory accumulators (`total_mem`, `active_mem`,
  `orphan_mem`) should sum RSS+swap combined, while the per-row display keeps RSS and swap as
  separate columns rather than pre-collapsing them — this satisfies both the "combined" and the
  "shows RSS and swap" halves of the acceptance bar without contradiction.

## Risks & Mitigations

- **Risk**: reading `/proc/PID/status` for every matched-Claude row (not just orphans) adds a
  syscall per row to every invocation. **Mitigation**: this is bounded by `total_count`
  (already-narrow, comm-gated candidate set), the same order of magnitude as the existing
  per-row work in the loop; no measurable performance concern for a refresh tool run
  interactively or on a systemd timer.
- **Risk**: a reviewer could misread "add a per-PID /proc read" as reopening the exact race the
  header spends its first three paragraphs ruling out. **Mitigation**: the header comment
  addition (item 3 above) exists precisely to make the distinction explicit and citable, rather
  than relying on an implementer's or future reader's memory of this report.
- **Risk**: PID reuse between snapshot and the `/proc` read could attribute swap to the wrong
  process in a pathological case. **Mitigation**: accepted as immaterial residual risk (see
  Executive Summary) — the number is cosmetic/reporting-only and never feeds a decision; this
  should still be named, not silently ignored, which the header ruling does.
- **Risk**: extending `orphan_details`' pipe-joined format (adding a field) could break the
  `IFS='|' read -r pid mem age cmd <<< "$detail"` unpacking further down if the field-count
  change is missed at both write and read sites. **Mitigation**: both sites are in the same
  ~15-line span of the same function: the plan/implementation phase should update the `read -r`
  destructuring line and the `printf` header/rows in the same edit, and the new test cases
  should include the full dry-run report output shape (not just the isolated helper) to catch
  a field-count mismatch structurally, matching how the existing self-exclusion (d-2) case
  asserts on full script output rather than only on the isolated predicate.

## Context Extension Recommendations

- **Topic**: shell-script testability seams for `/proc`-backed reads.
- **Gap**: `.claude/context/standards/shell-script-testing.md` documents the general fixture
  convention (mktemp workdir, inline heredocs, never resolve against the live tree) but does not
  yet name an explicit pattern for a path-override environment variable (`PROC_ROOT`-style) as a
  lighter-weight sibling to the function-override seam it does document (`_pid_is_alive`-style).
  This task's `get_vmswap_kb`/`PROC_ROOT` pairing would be a good second worked example if that
  standard is ever revised to enumerate seam shapes explicitly.
- **Recommendation**: not urgent enough to block this task; worth a one-paragraph addition to
  `shell-script-testing.md` the next time that file is touched for an unrelated reason, citing
  both `_pid_is_alive` (function-seam) and `get_vmswap_kb`/`PROC_ROOT` (path-seam) as the two
  sanctioned shapes.

## Appendix

- Search queries / commands used:
  - `sed -n` reads of `claude-refresh.sh` (header, `format_memory`, main loop, all reporting
    call sites) and the full `test-claude-refresh-matcher.sh` suite.
  - `grep -n "ps -eo\|format_memory\|rss\|RSS\|VmSwap\|/proc/"` across `claude-refresh.sh`.
  - `grep -rn "VmSwap\|/proc/\$pid\|/proc/\${pid}\|/proc/.*status"` across
    `agent-system/extensions/core/scripts/` (zero pre-existing `/proc` usage found — this is a
    new pattern for the codebase, not an extension of an existing one).
  - `grep -rln "format_memory\|claude-refresh"` across `agent-system/extensions/core/` to
    confirm no downstream machine-parsing dependency on the current output shape.
- Kernel reference: `proc(5)` `VmSwap` field semantics (pretrained knowledge, not web-fetched
  this session — no network research was needed given the interface is a stable, decades-old
  kernel ABI already well understood).
