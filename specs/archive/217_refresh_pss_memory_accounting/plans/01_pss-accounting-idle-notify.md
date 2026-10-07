# Implementation Plan: Task #217

- **Task**: 217 - Cost-aware idle Lean tree reclamation in /refresh: PSS accounting, CPU-delta idleness, notify-before-kill
- **Status**: [COMPLETED]
- **Effort**: 14.5 hours
- **Dependencies**: None blocking (former dependency 174 is archived/completed)
- **Research Inputs**: specs/217_refresh_pss_memory_accounting/reports/01_pss-accounting-idle-notify.md
- **Artifacts**: plans/01_pss-accounting-idle-notify.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`claude-refresh.sh`'s Claude and Lean passes both sum per-process `RSS + VmSwap`, so N Lean
workers sharing a 5.6 GB mmapped Mathlib `.olean` set each contribute the full shared-page cost
to the reported total -- the live-observed "15.1 GB reclaimable" against a real reclaim of
~2.3 GB. This plan replaces that accounting with one shared `smaps_rollup`-based helper
(`reclaimable = Pss_Anon + SwapPss`, with `Pss_File` reported separately as uncounted shared
cache and an explicit approximate-label fallback), then builds the two mechanisms that consume
that figure: a CPU-delta idleness state machine replacing the broken `pcpu`/`etimes` gate, and a
notify-before-kill prompt path with a memory-floor cost gate and a snooze window. Done means:
the full `test-claude-refresh-matcher.sh` suite passes with new fixture coverage for all three
mechanisms, `shellcheck` is clean, the source store is redeployed, and nothing is ever killed
without an explicit user action.

### Research Integration

The research report (`reports/01_pss-accounting-idle-notify.md`) is integrated as follows:

- **Seams to reuse, not reinvent**: the existing `PROC_ROOT="${PROC_ROOT:-/proc}"` override seam
  carries the new `smaps_rollup` reads (Phase 1) and the new `/proc/PID/stat` reads (Phase 3);
  a new `LEAN_TREE_STATE_DIR` seam mirrors its shape for the state file. No second `/proc` seam
  is introduced.
- **`SwapPss`, not `VmSwap`, for the swap term**: `VmSwap` is this PID's full swap usage with no
  de-duplication across sharers, so mixing it into a PSS formula would reproduce a milder form of
  the same double-counting defect. `get_vmswap_kb()` is retained strictly as the fallback path.
- **Fallback triggers on missing fields, not only on an unreadable file**: older kernels expose
  `smaps_rollup` without `SwapPss`. Phase 1's helper labels the figure approximate in that case
  too.
- **`/proc/PID/stat` comm-field gotcha**: field 2 is parenthesized and may itself contain spaces
  or parentheses. Phase 3 parses from the **last** `)` in the line, never by naive whitespace
  splitting, and Phase 5 proves it with a deliberately space-containing fixture `comm`.
- **`main()`'s `--lean-tree` mode is a structural change, not additive**: `main()` today runs five
  passes unconditionally, and `systemd/claude-refresh.service`'s own header comment rests on that
  invariant. Phase 6 adds an explicit early-return branch **before** the five-pass sequence, never
  a sixth pass folded into it.
- **`systemd-run` availability-probe + audible-degrade idiom** from `scripts/lake-build-guard.sh`
  (`command -v` plus a cheap no-op probe) is reused verbatim in Phase 7 for `systemd-run`,
  `notify-send`, and the DBus session bus.
- **Atomic state write** reuses `scripts/state-write.sh`'s `mktemp`-in-same-dir + `mv` idiom, not
  its locking/spill/jq-validation machinery.
- **Resolved planning decision** the research explicitly deferred to this plan: `lean_row_is_idle()`
  is **deleted** in Phase 4, not left dormant. The dispatch says "Replace the pcpu/etimes gate
  entirely," and a function with zero callers is worse than no function. Its one call site, its
  entry in the test suite's mutation-check function-name list, and
  `build_waiter_row_is_idle()`'s cross-reference comment are all updated in the same phase.
  `build_waiter_row_is_idle()` itself is untouched -- its `pcpu` gate serves a different pass and
  is out of this task's scope.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided to this dispatch.

## Goals & Non-Goals

**Goals**:

- One shared `get_pss_reclaimable_kb()` helper, used by **both** `run_claude_pass()` and the Lean
  pass, reading `$PROC_ROOT/PID/smaps_rollup` for already-narrowed candidates only.
- Both passes' report formats show reclaimable memory, an approximate marker when the fallback
  fired, and shared cache separately as not counted.
- The in-script `pcpu` comment correctly states that procps-ng `ps pcpu` is lifetime
  `cputime/elapsed`, not a decaying average.
- A CPU-delta idleness state machine keyed by root pid + `/proc/PID/stat` starttime, in an atomic,
  corruption-tolerant `lean-trees.json`, replacing the `pcpu`/`etimes` gate entirely.
- A cost gate: prompt-eligible only when `idle_for >= LEAN_LSP_IDLE_THRESHOLD_MIN` (240) **AND**
  `reclaimable >= LEAN_LSP_MEM_FLOOR_MB` (1024); otherwise reported as "idle, cheap, kept".
- A notify-before-kill prompt path (detached `systemd-run --user` transient unit, single
  `-A default=Kill` `notify-send`, `-t 0`), a `--lean-tree <pid>:<starttime> --force` targeted
  termination mode that re-verifies identity/idleness/floor, and a snooze window with per-tree
  dedupe.
- Graceful degrade to log-only when `notify-send`, `systemd-run`, or a DBus session bus is absent.
- Fixture-driven test coverage (via `PROC_ROOT`, a fixture state dir, and stubbed binaries on
  `$PATH`) for every mechanism above, plus `shellcheck` clean and a successful redeploy.

**Non-Goals**:

- No change to the UID/system-slice safety predicates (`is_system_slice_cgroup`,
  `is_owned_by_current_uid`, `is_claude_executable_comm`, `is_live_inhibitor_target`) or to the
  workers -> server -> root termination ordering.
- No silent kill on any new code path. Termination happens only under `--force` plus an explicit
  user action.
- No edits under `.claude/**` (a disposable deploy artifact). The edit target is
  `agent-system/extensions/core/`.
- No change to `build_waiter_row_is_idle()`'s own `pcpu`-based gate (different pass, out of scope);
  only its comment's cross-reference to the deleted `lean_row_is_idle()` is updated.
- No mako config change and no NixOS home-manager unit install -- those are an external
  `~/.dotfiles` change, documented here but not performed.
- No new `context/patterns/*.md` file for PSS accounting or atomic state writes (research
  recommended deferring both until a second consumer exists).
- The hourly `systemd/claude-refresh.service` `ExecStart` stays `--dry-run`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `SwapPss` absent from an older kernel's `smaps_rollup`, silently under-reporting | H | M | Phase 1's helper requires ALL three fields to be present; a missing field triggers the same approximate-labeled fallback as an unreadable file. Phase 2 covers this with a fields-present-but-incomplete fixture. |
| Naive `/proc/PID/stat` whitespace split misparses a `comm` containing a space, corrupting the CPU-tick sum or starttime | H | M | Phase 3 parses from the LAST `)` in the line. Phase 5 adds a fixture row whose fake `comm` deliberately contains a space and a parenthesis. |
| `--lean-tree` mode folded into the five-pass sequence, invalidating `claude-refresh.service`'s documented "all five passes always run" ruling | H | M | Phase 6 adds an explicit early-return branch before `validate_cgroup_support`/the pass sequence, and amends the service-file header comment in Phase 9 to record the new invocation shape. Treated as a MUST NOT violation risk, not a style preference. |
| Effort estimate inherited from the pre-merge task (2 hours) understates three absorbed work items with three separate test matrices | M | H | Re-estimated honestly at 14.5 hours across 9 phases rather than silently under-delivering. If the round must be cut short, Phases 1-2 are a self-contained, shippable deliverable (the accounting fix alone), and Phases 3-9 resume in a later round under the same task number. |
| State file corrupted or concurrently written by a second `claude-refresh.sh` run (the hourly timer overlapping a manual `/refresh`) | M | M | Atomic `mktemp`-in-same-dir + `mv`. A missing or unparseable file is treated as a first sighting, NEVER as idle (so a corrupt file can never authorize a prompt). |
| PID reuse: a new process inherits a recorded root pid and is judged idle on the dead tree's history | H | L | State keys are `root_pid:starttime` from `/proc/PID/stat` field 22; a starttime mismatch is a new tree with no history. Re-verified again at `--lean-tree` termination time (Phase 6) and covered in Phases 5 and 8. |
| mako's `-A default=Kill` click semantics are taken from the dispatch's live observation, not re-verified by research | M | M | Treated as ground truth per the dispatch. Unit tests stub `notify-send` for both outcome branches; the real verification is the manual end-to-end check in Phase 9, reported honestly rather than inferred from the unit tests. |
| Transient unit name accidentally matching `claude-*.scope`, so the user's claude-session-reaper stops the prompt | M | L | Unit name is `claude-refresh-prompt-<rootpid>-<starttime>` (a `.service`, not a `.scope`); Phase 8 asserts the name never matches `claude-*.scope`. |
| Concurrent sibling tasks editing the same shared working tree this cycle | M | M | Per the dispatch's territory block: re-read each file immediately before editing, stage only this task's own hunks (explicit file lists, never a directory or glob `git add`), never run `git-snapshot.sh` in its reverting default mode, and STOP and report any foreign commit or modification. No sibling's declared `file_scope` overlaps this task's six files. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 3 |
| 4 | 5, 6 | 4 |
| 5 | 7 | 6 |
| 6 | 8 | 7 |
| 7 | 9 | 2, 5, 8 |

Phases within the same wave can execute in parallel. The parallel pairs are genuinely disjoint by
file: in wave 2 Phase 2 touches only the test suite while Phase 3 touches only the script; the
same split holds for Phase 5 (test suite) against Phase 6 (script) in wave 4. Any other pairing
would contend on `scripts/claude-refresh.sh` and must be run sequentially.

---

### Phase 1: PSS reclaimable helper and both passes' report format [COMPLETED]

**Goal**: Replace shared-page double-counting with one `smaps_rollup`-based reclaimable figure
used by both passes, reported alongside an uncounted shared-cache figure and an approximate
marker, and correct the `pcpu` comment.

**Tasks**:
- [x] Add `get_pss_reclaimable_kb()` immediately after `get_vmswap_kb()`, reading
      `$PROC_ROOT/$pid/smaps_rollup` through the existing seam. Parse `Pss_Anon:`, `SwapPss:`,
      and `Pss_File:` with the same integer-only `awk`-per-field idiom `get_vmswap_kb()` uses
      (no `bc`, no `jq`). *(completed)*
- [x] Echo a single pipe-delimited line `reclaimable_kb|shared_cache_kb|is_approximate`, matching
      the file's existing `member_details` pipe-delimited convention. Signature takes
      `pid` and `rss_kb` (the already-captured snapshot value) so the fallback needs no extra read.
      *(completed)*
- [x] Fallback path: when `smaps_rollup` is absent, unreadable, **or** missing any of the three
      required fields, return `rss_kb + get_vmswap_kb(pid)` as reclaimable, `0` shared cache, and
      `is_approximate=1`. A PID that exited between snapshot and read must still echo cleanly
      (`0|0|1`), never error or abort under `set -euo pipefail`. *(completed)*
- [x] Wire into `run_claude_pass()`: replace the `swap_kb=$(get_vmswap_kb "$pid"); combined=$((rss + swap_kb))`
      pair with a `get_pss_reclaimable_kb` call; accumulate reclaimable into the existing
      `total_mem`/`active_mem`/`orphan_mem` counters and shared cache into a new parallel counter;
      extend `orphan_details` with the shared-cache and approximate fields. *(completed)*
- [x] Wire into `detect_lean_candidate_trees()`: replace the per-member
      `swap_kb=$(get_vmswap_kb ...)`/`mem_total=$((mem_total + row_rss[m] + swap_kb))` pair the
      same way, accumulating `LEAN_TREE_MEM_KB` from reclaimable only and adding a parallel
      `LEAN_TREE_SHARED_CACHE_KB` array; extend `LEAN_TREE_MEMBER_DETAILS` lines with the
      shared-cache and approximate fields. *(completed)*
- [x] Update both passes' report blocks: rename the per-row `Swap` column to `Reclaimable`, add a
      `Shared cache` column, mark an approximate row with a visible `~` prefix (or equivalent),
      and change the totals line to `Total memory that can be reclaimed: X (shared cache: Y, not counted)`.
      Keep the header-comment "reporting-only read happens strictly AFTER candidacy is decided"
      invariant intact and restate it for the new helper. *(completed)*
- [x] Correct the `pcpu` comment above `lean_row_is_idle()`: procps-ng `ps pcpu` is lifetime
      `cputime/elapsed`, NOT a decaying average (the decaying characterization applies to `top`'s
      live `%CPU`). Do not change `lean_row_is_idle()`'s logic in this phase. *(completed)*
- [x] Run `shellcheck` on `scripts/claude-refresh.sh` and the existing suite to confirm no
      regression in the pre-existing assertions. *(completed: shellcheck clean except two
      pre-existing warnings (RED unused, SC2009 at the chromium grep) unchanged from baseline;
      suite baseline recorded as 112 passed/0 failed; after this phase 110 passed/2 failed, both
      failures isolated to assertion (e)'s renamed-column output-shape case -- the expected
      hand-off to Phase 2, not a defect)*
- [x] **Deviation (recorded)**: the scope hypothesis assumed exactly two `get_vmswap_kb()`
      reporting call sites; a third exists in the MCP fan-out pass (`run_mcp_fanout_pass`'s
      per-server loop). Converted its accounting to `get_pss_reclaimable_kb()` for consistency
      (a matched MCP server process could equally mmap a shared library), but left its aggregated
      single-"Memory"-column report format unchanged, since the dispatch's report-format
      requirement (b) names only the Claude and Lean passes.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: full

**Scope Hypothesis**: There are exactly two `get_vmswap_kb()` reporting call sites to convert
(one in `run_claude_pass()`, one in `detect_lean_candidate_trees()`) and the "decaying average"
mischaracterization appears at exactly two comment lines, both inside `lean_row_is_idle()`'s
header block. Confirm at implementation time with `grep -n 'get_vmswap_kb\|decaying'
scripts/claude-refresh.sh` before editing; if a third call site or a third occurrence exists,
convert it too and record the deviation.

**Files to modify**:
- `agent-system/extensions/core/scripts/claude-refresh.sh` - new `get_pss_reclaimable_kb()`; both passes' accounting and report blocks; `pcpu` comment correction

**Verification**:
- `shellcheck agent-system/extensions/core/scripts/claude-refresh.sh` exits clean.
- `bash agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` still passes
  (pre-existing assertion (e) cases may need their expected column labels updated in Phase 2 --
  if assertion (e)'s output-shape case fails here solely on the renamed column, that is the
  expected hand-off to Phase 2, not a defect; record it explicitly rather than silently editing
  the test in this phase).
- `grep -n 'Pss_Anon\|SwapPss\|Pss_File' scripts/claude-refresh.sh` shows all three fields parsed.

---

### Phase 2: PSS accounting tests [COMPLETED]

**Goal**: Prove de-duplication of shared pages across multiple workers, correct `smaps_rollup`
field parsing, and the approximate-labeled fallback, using the suite's established two-layer
fixture pattern.

**Tasks**:
- [x] Extend assertion (e)'s block with isolated-helper cases against fixture
      `$WORKDIR/fakeproc/<pid>/smaps_rollup` heredocs: known `Pss_Anon`/`SwapPss`/`Pss_File`
      values parse to the expected pipe-delimited triple; `PROC_ROOT` unset immediately after,
      per the block's existing leakage discipline. *(completed)*
- [x] Fallback cases: (i) `smaps_rollup` absent but `status` present -> reclaimable equals
      `rss + VmSwap` with `is_approximate=1`; (ii) `smaps_rollup` present but lacking `SwapPss`
      -> same approximate fallback (the older-kernel risk); (iii) PID path entirely absent ->
      clean `0|0|1`, no error. *(completed)*
- [x] Shared-page de-duplication case: a fixture of N (>= 3) worker PIDs each with a large,
      identical `Pss_File` and a small distinct `Pss_Anon`. Assert the summed reclaimable equals
      `sum(Pss_Anon + SwapPss)` exactly, and that the large `Pss_File` total appears only in the
      shared-cache figure -- i.e. the pre-fix `RSS + VmSwap` sum would have been strictly larger.
      *(completed: isolated-helper level, N=3 workers)*
- [x] Full-script output-shape case: drive a fake `ps -C lake,lean` (reusing assertion (g)'s
      technique, including the `*pgid*) exit 0` guard that keeps the fake inert for the
      build-waiter pass) plus fixture `smaps_rollup` files, run `--dry-run`, and assert the
      rendered Lean table carries the `Reclaimable` and `Shared cache` columns with the
      de-duplicated total -- the field-count-mismatch catcher. *(completed: dedicated 3-row
      root/server/worker fixture, own pids/dirs, isolated from assertion (g)'s own fixture)*
- [x] Fallback-label output case: same full-script shape with `smaps_rollup` removed, asserting
      the approximate marker is visible in the rendered output (not only in the helper's return).
      *(completed)*
- [x] Update assertion (e)'s existing Claude-pass output-shape expectations for the renamed column
      and the new totals line, and add `get_pss_reclaimable_kb` to the mutation-check
      function-name list. *(completed: also updated the mutation-check's expected-missing-count
      bounds from 27/28 to 28/29 to account for the 28th function name added to the list)*
- [x] Update the suite's header comment to describe the new cases. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase adds roughly 8-10 new cases and touches assertion (e)'s block
plus the mutation-check function-name list. Confirm by counting `pass`/`fail` call sites added and
by checking the suite's reported PASSED total rises by that amount; the exact count is a
hypothesis, not a target -- cover the behaviors, then record the real number.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` - assertion (e) extension; mutation-check list; header comment

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` exits 0 with
  zero `[FAIL]` lines.
- Non-vacuousness check: temporarily revert `get_pss_reclaimable_kb()` to a plain
  `rss + VmSwap` sum and confirm the de-duplication case FAILS; restore afterward and note the
  result in the phase record.
- `shellcheck` on the test file exits clean.

---

### Phase 3: /proc/PID/stat parsing, state-file I/O, and the CPU-delta state machine [COMPLETED]

**Goal**: Add the primitives the idleness gate needs -- a safe `/proc/PID/stat` parser, an
atomic corruption-tolerant `lean-trees.json`, and the per-tree CPU-delta bookkeeping -- without
yet changing which trees are selected.

**Tasks**:
- [x] Add `LEAN_TREE_STATE_DIR="${LEAN_TREE_STATE_DIR:-$HOME/.local/state/claude-refresh}"`
      immediately below the `PROC_ROOT` seam, with a comment naming it as the same
      override-for-testing shape. *(completed)*
- [x] Add `read_proc_stat_fields()` reading `$PROC_ROOT/$pid/stat`: locate the LAST `)` in the
      line, split the remainder, and echo `starttime|utime|stime` (whitespace fields 22, 14, 15
      counted from the canonical field numbering). Document the parenthesized-`comm` gotcha
      inline with a one-line `man proc` justification. Unreadable or malformed input echoes an
      empty result, never a partial or guessed one. *(completed)*
- [x] Add `read_lean_tree_state()`: `mkdir -p` the state dir idempotently; a missing file, an
      empty file, or a file that fails `jq` validation is treated as **no history** (first
      sighting), never as idle. Emit one explicit log line when a present file is unparseable --
      degrade audibly, never silently. *(completed)*
- [x] Add `write_lean_tree_state()`: `mktemp` in the SAME directory as the target, write, then
      `mv` for an atomic rename (the `scripts/state-write.sh` idiom, not its locking/spill
      machinery). Remove the tmp file on any failure path. *(completed)*
- [x] Add `update_lean_tree_cpu_state()`: for each detected tree, key on `root_pid:starttime`;
      store `cputime_ticks` (summed `utime+stime` across all members), `last_active` (epoch
      seconds), and `last_seen`. First sighting -> record and set `last_active=now`. Unchanged
      `cputime_ticks` -> leave `last_active` alone. Increased `cputime_ticks` -> reset
      `last_active=now`. Compute `idle_for_min = (now - last_active) / 60`. *(completed: takes
      current-run tree keys/cputicks via two parallel global input arrays
      CPU_STATE_KEYS/CPU_STATE_CPUTICKS, since detect_lean_candidate_trees() is not wired to call
      it until Phase 4)*
- [x] Prune entries whose `root_pid:starttime` key is absent from the current detection pass
      (tree no longer exists), in the same write. *(completed)*
- [x] Run `shellcheck`; do not yet wire any of this into tree selection. *(completed: shellcheck
      clean, same two pre-existing warnings; full suite unchanged at 125/0 since nothing new is
      wired in yet; manual smoke tests verified first-sighting, cputime-increase, idle-accrual,
      pruning-on-disappearance, the comm-with-space-and-parenthesis gotcha, and
      corrupt/empty/missing state-file tolerance, with no stray tmp file left in the state dir)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: No existing code in this repo parses `/proc/PID/stat` or reads
`~/.local/state/claude-refresh/`, so all five new functions are net-new with zero existing call
sites to migrate. Confirm with `grep -rn '/stat\b\|lean-trees.json\|LEAN_TREE_STATE_DIR'
agent-system/extensions/core/scripts/` before writing; a pre-existing consumer would change the
approach from additive to migrative.

**Files to modify**:
- `agent-system/extensions/core/scripts/claude-refresh.sh` - `LEAN_TREE_STATE_DIR` seam; `read_proc_stat_fields()`; `read_lean_tree_state()`; `write_lean_tree_state()`; `update_lean_tree_cpu_state()`

**Verification**:
- `shellcheck agent-system/extensions/core/scripts/claude-refresh.sh` exits clean.
- `bash .../test-claude-refresh-matcher.sh` still passes (behavior unchanged so far).
- Manual smoke: with `LEAN_TREE_STATE_DIR` pointed at a scratch dir, two consecutive `--dry-run`
  runs leave a well-formed `lean-trees.json` and the second run reports a nonzero `idle_for` for
  any tree whose cputime did not change.

---

### Phase 4: Replace the pcpu/etimes gate with the CPU-delta idle gate plus memory-floor cost gate [COMPLETED]

**Goal**: Make tree eligibility depend on CPU-delta idleness AND the reclaimable-memory floor,
delete the superseded row-level gate, and report cheap idle trees as kept rather than reclaimable.

**Tasks**:
- [x] Add `LEAN_LSP_MEM_FLOOR_MB="${LEAN_LSP_MEM_FLOOR_MB:-1024}"` beside the existing
      `LEAN_LSP_IDLE_THRESHOLD_MIN`, with a comment recording the user-approved 1 GB floor and the
      live observation that motivated it. *(completed)*
- [x] Remove the `lean_row_is_idle` call from `detect_lean_candidate_trees()`'s member loop;
      delete `lean_row_is_idle()` itself; rewrite `build_waiter_row_is_idle()`'s comment so its
      integer-truncation rationale is self-contained instead of cross-referencing the deleted
      function. The UID and system-slice member checks in that same loop are unchanged.
      *(completed: grep confirms zero remaining calls, only an explanatory NOTE comment)*
- [x] Have `detect_lean_candidate_trees()` keep detecting every live tree (no idleness filter at
      detection time), call `update_lean_tree_cpu_state()` once per run, and expose per-tree
      `LEAN_TREE_IDLE_MIN` and `LEAN_TREE_ELIGIBLE` arrays alongside the existing ones.
      *(completed: two-pass restructure -- pass 1 assembles every live tree and accumulates
      per-tree CPU_STATE_KEYS/CPU_STATE_CPUTICKS for one single update_lean_tree_cpu_state() call;
      pass 2 does PSS accounting and populates the public arrays plus the cost gate)*
- [x] Implement the cost gate as a single predicate: eligible when
      `idle_for_min >= LEAN_LSP_IDLE_THRESHOLD_MIN` AND
      `reclaimable_kb >= LEAN_LSP_MEM_FLOOR_MB * 1024`. Everything else is reported, never
      actioned. *(completed)*
- [x] Update `run_lean_pass()`'s report to classify each tree as `active`, `idle, cheap, kept`
      (idle past the threshold but under the floor), or `eligible` (both gates passed), showing
      `idle_for` and the reclaimable figure in each case. The totals line counts only eligible
      trees as reclaimable. *(completed)*
- [x] Gate `run_lean_pass()`'s `--force` termination loop on `LEAN_TREE_ELIGIBLE` so a cheap or
      active tree can never be terminated even under `--force`. Termination ordering
      (workers -> server -> root) and `terminate_pid()` are untouched. *(completed)*
- [x] Run `shellcheck`. *(completed: clean, same two pre-existing warnings)*
- [x] **Deviation (recorded, explicitly sanctioned by this phase's own Verification)**: assertion
      (g) now fails (3 cases) because its fixture tree lacks `/proc/PID/stat`/seeded-state
      fixtures the new CPU-delta gate requires -- owed to Phase 5 per this phase's own
      Verification bullet. My own Phase 2 "Lean PSS (e)" full-script cases hit the identical
      structural dependency; fixed now (not deferred) by adding `/proc/PID/stat` fixtures, a
      pre-seeded `lean-trees.json`, and `LEAN_LSP_MEM_FLOOR_MB=1` overrides, since I own those
      fixtures and the fix was bounded. Full suite: 122 passed / 3 failed (only assertion (g)'s
      three cases, all pre-named as acceptable in this phase's Verification).

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: full

**Scope Hypothesis**: `lean_row_is_idle` has exactly one production call site, one definition, one
cross-reference comment in `build_waiter_row_is_idle()`, and one entry in the test suite's
mutation-check function-name list (the test-suite entry is handled in Phase 5). Confirm with
`grep -rn 'lean_row_is_idle' agent-system/extensions/core/` immediately before deleting; any
further reference must be resolved in this phase rather than left dangling.

**Files to modify**:
- `agent-system/extensions/core/scripts/claude-refresh.sh` - `LEAN_LSP_MEM_FLOOR_MB`; delete `lean_row_is_idle()`; `detect_lean_candidate_trees()` gate restructure; `run_lean_pass()` classification, report, and eligibility-gated termination; `build_waiter_row_is_idle()` comment

**Verification**:
- `shellcheck` exits clean and reports no unused-function or undefined-function finding.
- `grep -rn 'lean_row_is_idle' agent-system/extensions/core/scripts/claude-refresh.sh` returns
  nothing.
- Existing assertion (g) ordering test still passes (ordering guarantee preserved); if it fails
  because its fixture tree is no longer eligible under the new gate, that is a fixture update
  owed to Phase 5 -- record it, do not weaken the gate.
- Manual smoke with a fixture `PROC_ROOT` + state dir: a tree over the idle threshold but under
  the floor renders as `idle, cheap, kept` and is not terminated under `--force`.

---

### Phase 5: CPU-delta and cost-gate tests [COMPLETED]

**Goal**: Cover the idle state machine, the `comm`-gotcha-robust `/proc/PID/stat` parse, state-file
tolerance, PID reuse, and the floor gate on both sides of its threshold.

**Tasks**:
- [x] New assertion block for `read_proc_stat_fields()`: a normal fixture row; a row whose fake
      `comm` deliberately contains a space AND a parenthesis (e.g. `(lean (worker) x)`) asserting
      `starttime`/`utime`/`stime` are still correct; a malformed row returning empty, not partial.
      *(completed, plus a non-vacuousness check proving a naive `awk '{print $22}'` split would
      actually misparse the comm-gotcha fixture)*
- [x] State-machine cases over a fixture `LEAN_TREE_STATE_DIR` plus fixture `PROC_ROOT`: first
      sighting is NOT idle; unchanged `cputime` across two runs accrues `idle_for`; increased
      `cputime` resets `last_active` to now; an entry for a vanished tree is pruned. *(completed)*
- [x] PID-reuse case: same root pid, different `starttime` -> treated as a new tree with zero
      `idle_for`, never inheriting the old entry's history. *(completed)*
- [x] State-file tolerance cases: missing file, empty file, and syntactically invalid JSON each
      treated as first sighting (never idle), each emitting the audible log line; atomic-write
      case asserting no stray `tmp` file remains in the state dir after a write. *(completed)*
- [x] Floor-gate cases on both sides: idle past threshold with reclaimable just BELOW
      `LEAN_LSP_MEM_FLOOR_MB` renders `idle, cheap, kept` and is not terminated under `--force`;
      the same tree just ABOVE the floor renders eligible. Drive both through full-script runs with
      an overridden low `LEAN_LSP_MEM_FLOOR_MB` so fixtures stay small. *(completed)*
- [x] Update assertion (g)'s fixtures for the new eligibility gate (the ordering guarantee must
      still be asserted on a now-eligible fixture tree), and replace `lean_row_is_idle` with the
      new function names in the mutation-check list. *(completed: assertion (g) now carries
      /proc/PID/stat fixtures plus a pre-seeded lean-trees.json making its tree eligible;
      mutation-check list drops lean_row_is_idle and adds read_proc_stat_fields/
      read_lean_tree_state/write_lean_tree_state/update_lean_tree_cpu_state, bounds updated to
      31/32)*
- [x] Update the suite header comment. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: local

**Scope Hypothesis**: Roughly 12-15 new cases across one new assertion block plus edits to
assertion (g) and the mutation-check list. Confirm against the suite's reported PASSED delta; the
behavior list above is the contract, the count is not.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` - new CPU-delta/cost-gate assertion block; assertion (g) fixture updates; mutation-check list; header comment

**Verification**:
- Full suite exits 0 with zero `[FAIL]` lines.
- Non-vacuousness: temporarily make `update_lean_tree_cpu_state()` treat a first sighting as idle
  and confirm the first-sighting case FAILS; restore and record.
- Non-vacuousness: temporarily parse `/proc/PID/stat` with a naive `awk '{print $22}'` and confirm
  the space-containing-`comm` case FAILS; restore and record.
- `shellcheck` on the test file exits clean.

---

### Phase 6: `--lean-tree <pid>:<starttime>` targeted-termination mode [COMPLETED]

**Goal**: Add a single-tree, re-verifying termination entry point as an explicit early-return
branch in `main()`, preserving the five-passes-always-run invariant for every other invocation.

**Tasks**:
- [x] Extend `main()`'s argument loop with a value-taking `--lean-tree=<pid>:<starttime>` arm
      (the `=`-joined form, chosen over a following-arg convention because the existing loop is a
      flat `for arg in "$@"` that cannot consume a second token; document the choice inline).
      Reject a malformed value loudly with a nonzero exit, never a silent no-op. *(completed:
      whole-string regex validation, not a glob case pattern, to reject a colon-less value that a
      glob-then-split approach would silently misparse)*
- [x] Add `run_lean_tree_targeted_termination()`: call `detect_lean_candidate_trees()`, filter to
      the one tree whose root pid AND starttime both match, and re-verify (i) the tree still
      exists with that starttime, (ii) it is still idle past `LEAN_LSP_IDLE_THRESHOLD_MIN`, and
      (iii) its reclaimable figure is still at/above `LEAN_LSP_MEM_FLOOR_MB`. Any failed check
      logs an explicit named reason and returns without signaling anything. *(completed)*
- [x] Reuse `run_lean_pass()`'s existing ordered workers -> server -> root sequence and
      `terminate_pid()` for the one tree -- do not duplicate the ordering loop. Extract the loop
      into a small shared helper if reuse requires it, keeping the ordering guarantee textually
      in one place. *(completed: terminate_lean_tree_ordered(), used by both run_lean_pass()'s
      force loop and run_lean_tree_targeted_termination())*
- [x] Require `--force` for this mode: `--lean-tree` without `--force` reports what it WOULD do
      and exits 0, terminating nothing. *(completed)*
- [x] In `main()`, place the `--lean-tree` dispatch as an early return AFTER
      `validate_cgroup_support` but BEFORE `run_claude_pass`, with a comment explaining why it is
      not a sixth pass and pointing at `systemd/claude-refresh.service`'s header ruling.
      *(completed; systemd/claude-refresh.service's own header text is updated in Phase 9)*
- [x] Clear the tree's `prompted` marker in the state file once termination is attempted, so a
      respawned tree starts clean. *(completed: also clears snooze_until)*
- [x] Extend `print_help()` with `--lean-tree` and run `shellcheck`. *(completed: clean, same two
      pre-existing warnings; full suite unchanged at 143/0; manual verification: two --dry-run
      runs byte-identical, --lean-tree=99999:1 --force against an empty fixture logs a named
      refusal and exits 0 with nothing signaled, a malformed value exits 1, --lean-tree without
      --force previews only, and a live eligible-tree end-to-end run terminates correctly and
      clears prompted/snooze_until)*

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: full

**Scope Hypothesis**: `main()` currently has exactly three flag arms, all zero-value, and calls
exactly five pass functions unconditionally. Confirm by reading `main()` immediately before
editing; if a sixth pass or a value-taking flag has appeared since the research pass, re-derive
the early-return placement rather than assuming this shape.

**Files to modify**:
- `agent-system/extensions/core/scripts/claude-refresh.sh` - `main()` argument arm and early-return branch; `run_lean_tree_targeted_termination()`; shared ordered-termination helper; `print_help()`

**Verification**:
- `shellcheck` exits clean.
- Full suite still passes.
- `bash claude-refresh.sh --dry-run` output is byte-identical to its pre-phase output (the new
  branch is unreachable without `--lean-tree`), confirming the five-pass path is untouched.
- `bash claude-refresh.sh --lean-tree=99999:1 --force` against a fixture `PROC_ROOT` logs a named
  refusal (no such tree) and exits without signaling.

---

### Phase 7: notify-before-kill prompt path with snooze and graceful degrade [COMPLETED]

**Goal**: Have the headless `--dry-run` run prompt once per snooze window for an eligible tree via
a detached transient unit, treat anything but the default action as Keep, and never kill without
an explicit user action.

**Tasks**:
- [x] Add `LEAN_LSP_SNOOZE_MIN="${LEAN_LSP_SNOOZE_MIN:-240}"` beside the other two Lean env vars.
      *(completed)*
- [x] Add dependency probes following `scripts/lake-build-guard.sh`'s two-step idiom:
      `command -v notify-send`; `command -v systemd-run` plus a cheap
      `systemd-run --user --scope --quiet --collect -- true` liveness probe; and a DBus
      session-bus check (`$DBUS_SESSION_BUS_ADDRESS` non-empty, or a cheap
      `dbus-send --session` probe). Any missing dependency logs one explicit line and the prompt
      path becomes log-only -- never a kill, never silence. *(completed; manually verified all
      three degrade paths individually against a curated PATH excluding exactly one dependency
      each)*
- [x] Add `maybe_prompt_for_lean_tree()`, called from `run_lean_pass()` only on the non-`--force`
      path (so the hourly `--dry-run` unit reaches it and `--force` never does). For each eligible
      tree: skip if `snooze_until > now` or `prompted` is already set for the current window.
      *(completed; dedupe-within-window and re-prompt-after-expiry both manually verified via
      state-file evidence)*
- [x] Record `prompted` in the state file BEFORE launching the unit (dedupe must survive a crash
      mid-launch), via the Phase 3 atomic write. *(completed)*
- [x] Read the project label from `$PROC_ROOT/<root_pid>/cwd` (basename), falling back to the root
      pid when unreadable. *(completed)*
- [x] Launch detached:
      `systemd-run --user --unit=claude-refresh-prompt-<rootpid>-<starttime> ...` running
      `notify-send -a claude-refresh -u critical -t 0 -A default=Kill --wait "Idle Lean tree (<project>)" "idle Xh, N GB reclaimable -- click to kill, dismiss to keep 4h"`.
      The unit is a `.service`, and the name must never match `claude-*.scope`. *(completed:
      systemd-run itself is detached by construction without needing explicit backgrounding --
      verified no process blocks on the unit's own --wait)*
- [x] Outcome handling: `--wait` printing `default` -> run
      `claude-refresh.sh --lean-tree=<pid>:<starttime> --force`. Anything else -- empty output,
      another action string, dismiss, right-click, or expiry -- is Keep: record
      `snooze_until = now + LEAN_LSP_SNOOZE_MIN` and clear `prompted`. *(completed: the unit's own
      inline script re-invokes $SELF_SCRIPT with --lean-tree= or the new internal
      --lean-tree-snooze= entry point, rather than embedding jq/state-file logic in the unit
      itself -- both outcome branches manually verified end-to-end)*
- [x] Add a comment recording the mako-specific design: a single `-A default=Kill` action because
      mako has no dmenu-style action launcher and invokes the default action on left-click, with
      `-t 0` so the notification never auto-expires. *(completed)*
- [x] Interactive `/refresh` keeps its existing `AskUserQuestion` prompt; this path adds no second
      interactive prompt. Confirm `run_lean_pass()`'s existing early `return 0` for the
      non-`--force` branch still hands control back to the skill unchanged. *(completed: the
      `return 0` is unchanged; the prompt loop runs just before it)*
- [x] Run `shellcheck`. *(completed: clean, same baseline warnings plus one new SC2016 info for
      the deliberately single-quoted inline bash -c script passed to systemd-run, where `$1`-`$4`
      must expand inside that subshell, not the parent)*
- [x] **Critical fix (recorded, not in the original task list)**: discovered mid-phase that
      several PRE-EXISTING fixtures (from Phases 1-6, predating this prompt path) now produce an
      eligible tree during a plain `--dry-run` invocation, and this sandbox genuinely has
      `notify-send`/`systemd-run`/a DBus session bus available -- so those fixtures started
      launching REAL desktop notifications and REAL detached systemd units (one observed hanging
      indefinitely on a blocking `notify-send --wait -t 0`, which never auto-expires) instead of
      staying hermetic. Added `install_neutral_notify_stubs()` to the test suite and wired it into
      the three affected fixtures (Lean PSS (e), assertion (g), the floor-gate above-floor case).
      Manually verified and stopped three leaked real transient units
      (`systemctl --user stop`/`reset-failed`) that had accumulated from ad hoc verification
      before this fix landed.

**Timing**: 2 hours

**Depends on**: 6

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/claude-refresh.sh` - `LEAN_LSP_SNOOZE_MIN`; dependency probes; `maybe_prompt_for_lean_tree()`; snooze/prompted state fields; `run_lean_pass()` call site

**Verification**:
- `shellcheck` exits clean.
- Full suite still passes.
- With `notify-send` removed from a scratch `$PATH`, a `--dry-run` run logs the named
  missing-dependency line and terminates nothing.
- No code path in `maybe_prompt_for_lean_tree()` reaches `terminate_pid()` directly -- confirmed by
  reading the function and by `grep -n 'terminate_pid' scripts/claude-refresh.sh` showing call
  sites only inside the two pass-level termination loops and
  `run_lean_tree_targeted_termination()`.

---

### Phase 8: Prompt-path tests [COMPLETED]

**Goal**: Cover both notification outcomes, all three re-verification refusals, snooze dedupe
across a window boundary, the degrade-to-log-only paths, and the unit-name constraint.

**Tasks**:
- [x] New assertion block with stubbed `notify-send` and `systemd-run` first on `$PATH`. The
      `systemd-run` stub records its full argv to a log file and executes the trailing command
      directly (no real transient unit), so the test observes both the unit name and the
      notification outcome. *(completed)*
- [x] Kill-path case: stub `notify-send` prints `default` -> assert
      `claude-refresh.sh --lean-tree=<pid>:<starttime> --force` is invoked and the ordered
      workers -> server -> root sequence is signaled (reuse assertion (g)'s fake-`kill` logging
      technique). *(completed with an adapted technique: the Kill outcome re-invokes $SELF_SCRIPT
      as a genuine child process, a boundary `enable -n kill` cannot reach, so ordering is proven
      via terminate_pid()'s own "already gone" log-line sequence on fictional, never-real pids --
      equally conclusive, recorded as a deviation)*
- [x] Keep-path cases: stub prints nothing; stub prints another action string; stub exits nonzero.
      Each must record `snooze_until` and signal nothing. *(completed)*
- [x] Re-verification refusal cases: (i) root pid present but `starttime` differs (PID reuse);
      (ii) tree's `cputime` grew since the state snapshot, so no longer idle; (iii) reclaimable
      dropped below the floor. Each logs a named refusal and signals nothing. *(completed, as
      direct isolated calls to run_lean_tree_targeted_termination())*
- [x] Snooze dedupe cases: a second `--dry-run` run inside the snooze window launches no second
      prompt (`systemd-run` stub log unchanged); a run after the window expires prompts again.
      *(completed -- this exposed a genuine implementation bug, see Critical fix below)*
- [x] Degrade cases: `notify-send` absent; `systemd-run` absent; `DBUS_SESSION_BUS_ADDRESS` empty.
      Each logs the named line, prompts nothing, and signals nothing. *(completed, via a
      PATH-mirror-minus-one-binary technique rather than a bare `/usr/bin:/bin` fallback -- see
      Critical fix below)*
- [x] Unit-name case: assert the recorded `--unit=` value matches
      `^claude-refresh-prompt-[0-9]+-[0-9]+$` and does NOT match `claude-*.scope`. *(completed)*
- [x] Active-tree case covering the dispatch's acceptance bar directly: a 5h-old tree whose
      `cputime` grows between two runs is never eligible and never prompted. *(completed)*
- [x] Update the suite header comment and the mutation-check function-name list. *(completed:
      added terminate_lean_tree_ordered, run_lean_tree_targeted_termination, have_notify_send,
      have_systemd_run_for_prompt, have_dbus_session, record_lean_tree_snooze,
      maybe_prompt_for_lean_tree; bounds updated to 38/39)*
- [x] **Critical fix (recorded, found by this phase's own snooze-dedupe case)**:
      `update_lean_tree_cpu_state()` (Phase 3/4) rewrote each key's state object as a bare
      `{cputime_ticks, last_active, last_seen}` on every detection pass, silently DROPPING the
      `prompted`/`snooze_until` fields the prompt path (Phase 7) stores on that same object --
      defeating dedupe entirely, since every `detect_lean_candidate_trees()` call wipes the
      snooze before `maybe_prompt_for_lean_tree()` ever reads it. Fixed by merging onto the prior
      per-key object (jq's `+`) rather than replacing it outright. Manually verified: two
      consecutive runs now launch exactly one unit, with `snooze_until` persisting correctly.
- [x] **Critical fix (recorded, not anticipated by the original task list)**: discovered and
      fixed two additional test-harness-only defects while building this phase's fixtures: (1) a
      bare `/usr/bin:/bin` PATH fallback for the degrade cases doesn't contain `bash` itself on
      this sandbox, and `claude-refresh.sh`'s own `set -e` is inherited into the sourcing test
      suite's shell, so a bare failing command-substitution assignment (not wrapped in `if`)
      silently aborted the ENTIRE suite with no error text -- fixed via a PATH-mirror-minus-one
      technique for the degrade cases and the `if VAR=$(cmd); then ... else rc=$?; fi` idiom
      (already documented in `scripts/state-write.sh`) for the three refusal-case assignments;
      (2) an earlier assertion block's `unset LEAN_TREE_STATE_FILE` left it genuinely undefined,
      which is an immediate fatal "unbound variable" (not merely stale) under the same inherited
      `set -u` -- fixed by re-deriving it explicitly wherever `LEAN_TREE_STATE_DIR` is reassigned
      for a direct isolated function call.

**Timing**: 1.5 hours

**Depends on**: 7

**Verification Tier**: local

**Scope Hypothesis**: Roughly 14-16 new cases in one new assertion block. Confirm against the
suite's PASSED delta; the enumerated behaviors are the contract.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` - new prompt-path assertion block; mutation-check list; header comment

**Verification**:
- Full suite exits 0 with zero `[FAIL]` lines.
- Non-vacuousness: temporarily treat an unrecognized `notify-send` outcome as Kill and confirm the
  keep-path cases FAIL; restore and record.
- Non-vacuousness: temporarily skip the `prompted`-before-launch write and confirm the dedupe case
  FAILS; restore and record.
- `shellcheck` on the test file exits clean.

---

### Phase 9: Documentation, systemd notes, final gate, and redeploy [COMPLETED]

**Goal**: Bring `refresh.md`, `SKILL.md`, and the systemd units in line with the new idle
definition, cost gate, flag, and env vars; then run the complete gate set, redeploy, and report
the manual end-to-end check honestly.

**Tasks**:
- [x] `commands/refresh.md`: update Pass Inventory rows 1 and 2 for the PSS-based reclaimable
      figure, the CPU-delta idle definition, and the cost gate (noting that an idle-but-cheap tree
      is reported kept, not reclaimed). Add a short subsection documenting the prompt flow, the
      `--lean-tree` flag, and `LEAN_LSP_IDLE_THRESHOLD_MIN` / `LEAN_LSP_MEM_FLOOR_MB` /
      `LEAN_LSP_SNOOZE_MIN`. *(completed)*
- [x] `skills/skill-refresh/SKILL.md`: the same Pass Inventory row updates, plus a note that the
      interactive `AskUserQuestion` prompt now uses the same gate and the same reclaimable/idle
      numbers as the headless prompt path, and the `--lean-tree` flag in the invocation reference.
      *(completed; also fixed a real downstream defect this phase discovered: Step 2's
      interactive-confirmation trigger checked for the now-removed "No idle Lean LSP process
      trees found." string. Since detection is unconditional (Phase 4), that check would never
      have fired correctly; replaced with a grep for an actually-eligible tree count)*
- [x] `systemd/claude-refresh.service`: extend the "New-passes ruling" header comment to record
      that `--lean-tree` is an explicit early-return invocation mode, NOT a sixth pass, so the
      ruling still holds; confirm `ExecStart` still ends in `--dry-run` and state that prompting
      happens only in the separate transient unit. Document that
      `Environment=PATH=/usr/bin:/bin` is broken on NixOS and that NixOS installs these units via
      home-manager (an external dotfiles change, not performed here), while keeping the generic
      unit portable. *(completed; also covers --lean-tree-snooze)*
- [x] `systemd/claude-refresh.timer`: confirm the hourly cadence is adequate for the CPU-delta
      granularity (it is, per the dispatch) and add a one-line comment saying so; no behavioral
      change. *(completed)*
- [x] Final gate: `shellcheck` on both shell files; full
      `test-claude-refresh-matcher.sh` run; any other repo lint that covers these paths.
      *(completed: shellcheck clean on both files -- same baseline warning classes, no new
      categories; suite 163 passed / 0 failed; check-task-references.sh clean on all four
      deliverable files)*
- [x] Redeploy via `bash .claude/scripts/deploy-headless.sh` and confirm the regenerated
      `.claude/scripts/claude-refresh.sh` matches the source store (`diff` the two). Never
      hand-edit `.claude/**`. *(completed: deploy-headless.sh RESULT=landed_verify_clean, 33
      checks/0 failures; diff empty)*
- [x] Manual end-to-end check (the dispatch's own acceptance gate, which unit tests do not
      substitute for): on a real eligible tree, confirm exactly one notification per snooze
      window, a left-click Kill that refuses when the tree became active, and a dismiss that
      records a 4h snooze. Report the actual observed outcome, including anything not reachable in
      this environment, rather than inferring it from the test suite. *(reported honestly: `ps -C
      lake,lean` found zero real Lean LSP processes running on this machine during this dispatch
      -- there is no real eligible tree to click a notification for, and this non-interactive
      agent dispatch has no human present to physically click one regardless. What WAS verified
      with the real (non-stubbed) `systemd-run`/`notify-send`/DBus session bus during Phase 7's
      manual testing: real detached transient units genuinely launch and run (observed via
      `systemctl --user list-units` as "active running", later stopped and cleaned up -- see
      Phase 7's progress record); every outcome branch (Kill re-invocation, Keep/snooze, the
      three re-verification refusals, snooze dedupe, and all three dependency degrades) is
      exercised end-to-end by the automated suite against a structurally faithful fixture tree,
      using the real binaries wherever this sandbox has them. The literal "one real human
      left-click on one real notification for one real Lean tree" scenario is NOT reachable in
      this dispatch's environment; this is reported as a genuine gap, not inferred as passing.)*

**Timing**: 1.5 hours

**Depends on**: 2, 5, 8

**Verification Tier**: full

**Scope Hypothesis**: Both Pass Inventory tables have exactly 11 rows, of which rows 1 and 2 need
edits. Confirm by reading both tables before editing; a row added by a concurrent change must be
preserved, not overwritten.

**Files to modify**:
- `agent-system/extensions/core/commands/refresh.md` - Pass Inventory rows 1-2; prompt flow, `--lean-tree`, env vars
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md` - Pass Inventory rows 1-2; shared-gate note; `--lean-tree`
- `agent-system/extensions/core/systemd/claude-refresh.service` - header ruling extension; NixOS PATH note
- `agent-system/extensions/core/systemd/claude-refresh.timer` - cadence-adequacy comment

**Verification**:
- `shellcheck` clean on `scripts/claude-refresh.sh` and `scripts/tests/test-claude-refresh-matcher.sh`.
- Full `test-claude-refresh-matcher.sh` run exits 0, zero `[FAIL]`.
- `grep -c '^| [0-9]' ` on both Pass Inventory tables still returns 11.
- `diff <(cat agent-system/extensions/core/scripts/claude-refresh.sh) <(cat .claude/scripts/claude-refresh.sh)` is empty after redeploy.
- No task-number reference appears in any of the four deliverable files
  (`bash .claude/scripts/check-task-references.sh` or equivalent, if present).

---

## Testing & Validation

- [ ] `shellcheck agent-system/extensions/core/scripts/claude-refresh.sh` exits clean.
- [ ] `shellcheck agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` exits clean.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` exits 0 with
      zero `[FAIL]` lines, and its PASSED count is strictly greater than the pre-task baseline
      (record the baseline before Phase 2 starts).
- [ ] Acceptance (PSS): a fixture of N workers sharing a large `Pss_File` reports
      `reclaimable = sum(Pss_Anon + SwapPss)` and the shared cache separately; the pre-fix
      `RSS + VmSwap` sum would have been strictly larger.
- [ ] Acceptance (fallback): the unreadable-`smaps_rollup` and missing-`SwapPss` paths are both
      labeled approximate in rendered output.
- [ ] Acceptance (idleness): an active 5h-old tree whose cputime grows between runs is never idle.
- [ ] Acceptance (cost gate): a tree idle >= 240 min with < 1 GB reclaimable is reported kept and
      is not terminated even under `--force`.
- [ ] Acceptance (prompt): stubbed `notify-send` printing `default` kills; anything else snoozes;
      re-verification refuses on starttime mismatch, regained activity, or a dropped reclaimable
      figure; dedupe holds inside the snooze window and releases after it.
- [ ] Acceptance (degrade): a missing `notify-send`, `systemd-run`, or DBus session bus yields
      log-only, never a kill.
- [ ] Acceptance (safety): the UID/system-slice predicates and the workers -> server -> root
      ordering are unchanged -- confirmed by `git diff` showing no edit inside
      `is_system_slice_cgroup`, `is_owned_by_current_uid`, `is_claude_executable_comm`,
      `is_live_inhibitor_target`, or `terminate_pid`, and by assertion (g) still passing.
- [ ] Acceptance (deploy): `deploy-headless.sh` redeploys and the deployed script matches the
      source store byte-for-byte.
- [ ] Acceptance (manual): the end-to-end notification check in Phase 9, reported as actually
      observed.
- [ ] No file under `.claude/**` is modified by hand (confirmed via `git status`).

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/claude-refresh.sh` - PSS reclaimable helper, `/proc/PID/stat`
  parser, atomic state-file I/O, CPU-delta idle state machine, memory-floor cost gate,
  `--lean-tree` targeted-termination mode, notify/snooze prompt path, corrected `pcpu` comment,
  `lean_row_is_idle()` removed.
- `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` - three new/extended
  assertion blocks (PSS accounting, CPU-delta + cost gate, prompt path) with fixture `/proc` via
  `PROC_ROOT`, a fixture state dir, and stubbed `notify-send`/`systemd-run` on `$PATH`.
- `agent-system/extensions/core/commands/refresh.md` - updated Pass Inventory and new prompt-flow,
  flag, and env-var documentation.
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md` - updated Pass Inventory and
  shared-gate note.
- `agent-system/extensions/core/systemd/claude-refresh.service` - extended header ruling and NixOS
  PATH note.
- `agent-system/extensions/core/systemd/claude-refresh.timer` - cadence-adequacy comment.
- `specs/217_refresh_pss_memory_accounting/summaries/01_*-summary.md` - implementation summary.
- Runtime artifact (not a repo file): `~/.local/state/claude-refresh/lean-trees.json`.

## Rollback/Contingency

Each phase commits separately (per-substep granularity, per `rules/git-workflow.md`), staging only
this task's own files by explicit path -- never a directory or glob `git add`, since sibling tasks
are live on this same working tree this cycle. That gives a clean per-phase revert point:
`git revert <sha>` for the offending phase, newest first, leaves the earlier verified phases
intact. The phase boundaries are chosen so each is independently shippable in that sense: Phases
1-2 (accounting) stand alone without 3-9; Phases 3-5 (idleness + cost gate) stand alone without
6-8.

If an uncommitted working tree must be discarded instead, that is a genuine rollback, not a
precautionary checkpoint: take the snapshot per `context/contracts/recovery.md`'s rollback rung
(which also documents the out-of-scope override flag for a deliberate whole-tree case) before
running the destructive command. For an ordinary defensive checkpoint before risky work, use
`git-snapshot.sh --no-revert`, which is durable without reverting the tree.

Runtime contingency: deleting `~/.local/state/claude-refresh/lean-trees.json` is always safe --
the read path treats a missing file as a first sighting, never as idle, so the worst outcome is
that every tree's idle clock restarts and nothing is prompted for another threshold window.
