# Implementation Plan: Task #174

- **Task**: 174 - Add a self-excluding orphaned-build-waiter reaper pass to /refresh
- **Status**: [IMPLEMENTING]
- **Effort**: 5 hours
- **Dependencies**: None (the bounded-build-waiter contract it matches against is already merged)
- **Research Inputs**: specs/174_refresh_orphan_waiter_reaper/reports/01_orphan_waiter_reaper.md
- **Artifacts**: plans/01_orphan-waiter-reaper-pass.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a fifth pass, `run_build_waiter_pass()`, to
`agent-system/extensions/core/scripts/claude-refresh.sh` that reaps orphaned build-waiter poll
loops. It reuses the script's existing design: an atomic `ps -eo` snapshot owned by the pass,
detection from structured columns only (never `pgrep -f` or `ps | grep`), the existing
system-slice and UID exclusions, and `terminate_pid()`. The self-exclusion widens from pid/ppid to
pid, ppid, process group, and the reaper's own ancestor chain, all read from that same snapshot
with no second query. The pass's gate is age-threshold-only and ignores `$FORCE`. It then gets a
row in both pass-inventory tables (the two tables must match row for row), and the systemd unit's
"new-passes ruling" comment is re-derived.

### Research Integration

The research report settles the architecture: build the pass inside `claude-refresh.sh`, reuse
`terminate_pid()`, split detection into two signature families, gate on age only, and reach the
hourly cadence in report-only form. The report treats one choice as open: how to get the pgid
for self-exclusion. It offers two options, (a) widen `SNAPSHOT_PS_FIELDS` or (b) add a post-snapshot
`ps -o pgid=` lookup. This plan takes a **third option** that the codebase's own precedent points
to. Every non-Claude pass already takes its **own** snapshot with its own field list
(`LEAN_SNAPSHOT_PS_FIELDS`, `ZOMBIE_SNAPSHOT_PS_FIELDS`, `MCP_SNAPSHOT_PS_FIELDS`). So the new
pass gets `BUILD_WAITER_SNAPSHOT_PS_FIELDS='pid,ppid,pgid,uid,etimes,pcpu,cgroup:200,comm,args'`.
The reaper's own pgid and ancestor chain come from the row where `pid == $$` in **that same
snapshot**. That approach:
- leaves `SNAPSHOT_PS_FIELDS` and every existing `read` call site unchanged (so the
  fixed-column fixture rows for the Claude pass stay as they are);
- adds no post-snapshot live query that gates candidacy (race-free, which keeps the script's
  header invariant intact);
- fails closed: if the `$$` row is missing from the snapshot, the pass reaps nothing and prints
  one warning line.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted (no `roadmap_path` in this dispatch).

## Goals & Non-Goals

**Goals**:
- A new pass inside `claude-refresh.sh` that finds orphaned waiters in two signature families:
  - **Family A (canonical)**: the `timeout N bash -c 'while kill -0 "$1" ...; do sleep N; done' _
    "$pid"` shape. The dead-writer test is precise: the trailing embedded PID is checked through
    the existing `_pid_is_alive` seam.
  - **Family B (legacy / name-match)**: `until grep -q ...` sentinel polls and `until ! ps aux |
    grep -q ...` self-match polls. These carry no writer PID, so the test falls back to age plus
    idle CPU.
- Self-exclusion covers pid, ppid, pgid, and the ancestor chain of `$$`. All of it is evaluated
  against the pass's own frozen snapshot, and the pass fails closed when the `$$` row is absent.
- An explicit, documented gate class: **age-threshold-only**. The pass ignores `--force`, reaps
  whenever `--dry-run` is not set, and never prompts interactively. It is the first pass inside
  `claude-refresh.sh` whose destructive action is not gated by `$FORCE`, and the docs say so.
- An explicit hourly-cadence statement: **Yes (report-only via `--dry-run`; reaping is
  `/refresh`-only)**.
- Both inventory tables updated in the same commit, matching row for row: `commands/refresh.md`
  (the "What It Cleans" table plus a new owning subsection) and `skills/skill-refresh/SKILL.md`
  (the "Pass Inventory" table).
- Regression coverage in `scripts/tests/test-claude-refresh-matcher.sh`, including a mutation
  check that shows the pgid exclusion is load-bearing.

**Non-Goals**:
- Widening `SNAPSHOT_PS_FIELDS` or changing the Claude, Lean, zombie, or MCP passes' detection.
- Reaping the *writer* (the embedded PID) or the waiter's outer `timeout` parent. Only the waiting
  shell is signaled. `timeout` exits by itself once its child dies.
- Inspecting log-file contents to decide whether a Family B waiter is orphaned. The script's
  design never reads candidate state beyond the snapshot.
- Adding an argv-parsing addendum to `bounded-build-waiter.md`. The research report flags this as
  a follow-up. This plan adds at most a one-sentence pointer (Phase 3, optional).
- Changing the systemd unit's `ExecStart`. It stays `--dry-run`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The reaper kills its own shell or caller: a repeat of the exit-144 self-match | H | L | Detection uses snapshot columns only, never `pgrep`/`ps \| grep`. The exclusion set covers pid, ppid, pgid, and the ancestor chain of `$$`, all from the same snapshot. If the `$$` row is missing, the pass fails closed. A structural test forbids `pgrep` in the pass block. A mutation test removes the pgid clause and confirms that a test fails. |
| A Family B heuristic matches a live, legitimate foreground wait | M | L | Four conditions must all hold: `comm` is a shell (`bash`/`sh`), argv carries the loop and `grep -q` signature, integer-truncated `pcpu == 0`, and `etimes >= BUILD_WAITER_REAP_MIN` (default 60 min). A legitimate foreground waiter is bounded by the Bash tool's 10-minute cap, and a canonical detached waiter by its own `timeout`. The observed orphans ran 24-55 min, so 60 min clears legitimate waits with margin and still catches the leak class within one hour. |
| Family A: PID reuse makes a dead writer look alive, so the waiter never resolves | L | L | Accepted as a residual risk. The backstop is a secondary ceiling (`BUILD_WAITER_CEILING_MIN`, default 240 min, matching the Lean and session reap precedent): past it, an idle Family A waiter is reaped whatever `kill -0` says. Reaping a waiter never touches the build itself. |
| The age-threshold gate reaps during the no-flag survey invocation that skill-refresh Step 2 runs before its prompt | M | M | This is intended. It matches the rows 5-8 contract ("unconditional past threshold whenever `--dry-run` is not set"). Document it in SKILL.md Step 2, and state explicitly that the Step 2 confirmation trigger MUST NOT key off the new pass's output line. |
| The existing suite's fake `ps` binaries emit Claude-pass rows for **any** `-eo` field list, so the new pass would receive rows in the wrong column shape | M | H | The new pass's row parser validates that pid, ppid, pgid, uid, and etimes are integers and that `pcpu` is numeric, and skips malformed rows (fail closed). Phase 2 also updates every existing fake `ps` to return nothing for the build-waiter field spec, so existing cases stay independent of the new pass. |
| The two inventory tables drift out of step | M | L | Phase 3 edits both tables in one commit. Phase 4 runs a mechanical row-for-row comparison of the Gate and Destructive columns. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Implement run_build_waiter_pass in claude-refresh.sh [COMPLETED]

**Goal**: Land the pass, its predicates, the widened self-exclusion, and the `main()`/`--help`
wiring in the source-store script.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/claude-refresh.sh` immediately before
      editing. Sibling tasks are in flight on this tree. *(completed)*
- [x] Add a pass section in the same style as the zombie and MCP sections: *(completed)*
  - [x] Constants: `BUILD_WAITER_SNAPSHOT_PS_FIELDS='pid,ppid,pgid,uid,etimes,pcpu,cgroup:200,comm,args'`,
        `BUILD_WAITER_REAP_MIN` (default 60), and `BUILD_WAITER_CEILING_MIN` (default 240). Both
        thresholds can be overridden from the environment, following the
        `LEAN_LSP_IDLE_THRESHOLD_MIN` pattern. *(completed)*
  - [x] `take_build_waiter_snapshot()`: one `ps -eo "$BUILD_WAITER_SNAPSHOT_PS_FIELDS"
        --no-headers` call. On error it prints to stderr and returns non-zero, mirroring
        `take_zombie_snapshot()`. *(completed)*
  - [x] `is_shell_comm()`: `comm` must be exactly `bash` or `sh`. This is the executable-identity
        gate on `comm`, never on argv. *(completed)*
  - [x] `build_waiter_family()`: classifies argv as `A` (contains `kill -0` and `sleep`, and ends
        in a numeric token), `B` (contains `until` or `while` plus `grep -q`, and `sleep`), or
        empty. It extracts the trailing PID with a bash regex, as `is_live_inhibitor_target` does.
        A Family A-shaped argv whose trailing token does not parse as a PID returns empty, so the
        row is excluded rather than reaped. *(completed)*
  - [x] `build_waiter_row_is_idle()`: integer-truncated `pcpu == 0` and `etimes >=` a threshold
        passed in seconds. Reuse `lean_row_is_idle`'s truncation idiom, or call it directly if its
        signature fits. *(completed: written as its own function reusing the truncation idiom,
        since the threshold is caller-supplied rather than the Lean pass's fixed env var)*
  - [x] `build_self_exclusion_set()`: from the snapshot rows, record the reaper's own pgid (the
        row where `pid == $$`) and walk ppid links from `$$` up to PID 1 (with a hop cap) to
        collect the ancestor pids. If the `$$` row is absent, return non-zero. *(completed)*
- [x] `run_build_waiter_pass FORCE DRY_RUN`: *(completed)*
  - [x] Take the snapshot. Parse each row with `read -r pid ppid pgid uid etimes pcpu cgroup comm
        args` and skip any row with non-numeric numeric fields. *(completed)*
  - [x] Exclusions, in order: `pid == $$`, `ppid == $$`, `pgid == self_pgid`, pid in the ancestor
        set, `is_system_slice_cgroup`, `! is_owned_by_current_uid`, `! is_shell_comm`. *(completed)*
  - [x] Family A is a candidate when it is idle past `BUILD_WAITER_REAP_MIN` AND
        (`! _pid_is_alive embedded_pid` OR `etimes >= BUILD_WAITER_CEILING_MIN`). *(completed)*
  - [x] Family B is a candidate when it is idle past `BUILD_WAITER_REAP_MIN`. *(completed)*
  - [x] Print a report table (PID, family, age, reason, truncated command) and a stable
        no-findings line: `No orphaned build waiters found.` *(completed)*
  - [x] When `$DRY_RUN` is set, print the `[DRY RUN]` banner and terminate nothing. Otherwise call
        `terminate_pid` on each candidate from an `if` context (never as a bare statement, because
        of `set -e`), **whatever the value of `$FORCE`**. `$FORCE` is accepted only for call-site
        symmetry. Put a comment right there recording this deliberate divergence from rows 1-2.
        *(completed)*
  - [x] If the self-exclusion set is unavailable, print one warning and return 0 without reaping.
        *(completed: the warning text deliberately omits the literal `$$` value, since embedding
        it broke the existing zombie-pass assertion's --dry-run/--force output-equality check --
        each subprocess invocation has a different pid)*
- [x] Call `run_build_waiter_pass "$FORCE" "$DRY_RUN"` from `main()`, after `run_lean_pass` so the
      destructive passes stay adjacent. Update the "Both passes always run" comment to cover five
      passes. *(completed)*
- [x] Update `print_help()`: five passes, the new pass's gate, and the two env vars. *(completed)*
- [x] Update the script header's safety/predicate block to describe the pgid and ancestor-chain
      widening and the no-`pgrep` rule. State that the new pass takes its own snapshot and so
      leaves `SNAPSHOT_PS_FIELDS` unchanged. *(completed: worded to avoid the literal substring
      "pgrep" anywhere near the new pass, per Phase 1's own verification grep)*
- [x] Commit only this file (explicit path, never a directory add). *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/claude-refresh.sh`: new pass section, `main()` wiring,
  `--help`, header comment.

**Verification**:
- `bash -n` and `shellcheck` on the script are clean (no new warnings versus the pre-edit
  baseline).
- `claude-refresh.sh --dry-run` on the live machine completes, prints the new pass section, and
  terminates nothing.
- `grep -n 'pgrep' claude-refresh.sh` finds no occurrence inside the new pass block.
- The existing `test-claude-refresh-matcher.sh` still passes. If a failure comes from the fake-ps
  column-shape issue, record it and fix it in Phase 2, not by weakening the parser.

---

### Phase 2: Extend test-claude-refresh-matcher.sh [COMPLETED]

**Goal**: Regression coverage for detection, self-exclusion (including pgid and ancestors), gate
semantics, and a mutation check.

**Tasks**:
- [x] Re-read the suite before editing. Update every existing fake `ps` (the self-exclusion (d-2),
      swap, Lean, zombie, and MCP fakes) so that a `-eo` call whose field spec contains `pgid`
      emits **no rows**. That keeps pre-existing cases independent of the new pass. *(completed)*
- [x] Add a dedicated fake `ps` for the build-waiter field spec. It emits synthetic rows for:
      *(completed: all 12 non-self cases implemented in the (k) fixture)*
  - [x] a Family A waiter with a dead embedded PID, idle and past threshold, which is selected;
  - [x] a Family A waiter with a live embedded PID, idle, past `REAP_MIN` but under the ceiling,
        which is not selected;
  - [x] a Family A waiter with a live embedded PID past the ceiling, which is selected (the
        PID-reuse backstop);
  - [x] a Family A-shaped argv with a non-numeric trailing token, which is not selected;
  - [x] a Family B `until grep -q "^EXIT=" log` loop, idle and past threshold, which is selected;
  - [x] a Family B loop younger than the threshold, which is not selected;
  - [x] a Family B loop with `pcpu 2.0`, which is not selected;
  - [x] a non-shell `comm` (for example `nvim`) whose argv contains `until grep -q`, which is not
        selected;
  - [x] a waiter-shaped row whose **pgid equals the reaper's pgid**, which is not selected;
  - [x] a waiter-shaped row that is an **ancestor** of `$$`, which is not selected;
  - [x] a row under `/system.slice/` and a row with a foreign uid, neither selected.
- [x] Drive the dead/live embedded-PID cases through the overridable `_pid_is_alive` seam, as
      assertion (c) does. Never use real backgrounded processes, which the suite already measured
      as flaky. *(completed: for this end-to-end case the seam is exercised via a fake `kill`
      binary on `PATH` with the `kill` builtin disabled (`enable -n kill`), the same idiom
      assertion (g)'s Lean ordering test already established for full-script subprocess runs --
      `_pid_is_alive`'s production body, `kill -0 "$1"`, reaches that fake `kill` unmodified. No
      real backgrounded process is spawned.)*
- [x] Gate assertions: with `--dry-run`, the fake `kill` log stays empty. With no flags, the kill
      log contains exactly the selected pids (reaping without `--force`). With `--force`, the
      candidate set is identical. Use the `enable -n kill` plus fake-`kill` sourcing pattern the
      Lean ordering assertion uses. *(completed)*
- [x] Fail-closed assertion: a fake snapshot that has no `$$` row produces the warning line and
      an empty kill log. *(completed: both a direct unit-level call and a full end-to-end run)*
- [x] Structural assertion: the new pass block (constants, predicates, and `run_build_waiter_pass`)
      contains no `pgrep` and no `ps aux`. *(completed)*
- [x] Mutation check, per shell-script-testing.md: copy the script, delete the pgid-exclusion
      clause with `sed`, re-run the pgid case against the mutant, and assert that it now
      **fails**. Repeat for the ancestor-chain clause. *(completed: both mutation checks pass,
      confirming RED against the mutant)*
- [x] Add the new function names to the defined-functions loop (around line 1015). Update the
      suite header's list of acceptance-bar assertions. *(completed)*
- [x] Commit only this file. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: The suite has five existing fake `ps` binaries (self-exclusion, swap, Lean,
zombie, MCP) that need a "no rows for the pgid field spec" branch. Confirm with
`grep -n 'cat > .*/ps' test-claude-refresh-matcher.sh` before editing, and cover every hit.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh`: new fakes, cases,
  mutation check, and updates to the existing fakes.

**Verification**:
- `bash test-claude-refresh-matcher.sh` exits 0, and every new case prints `[PASS]`.
- Both mutation runs report the expected failure, which shows the exclusions are load-bearing.
- A second consecutive run also passes (flake check).

---

### Phase 3: Update both pass inventories, the owning subsection, and the systemd ruling [COMPLETED]

**Goal**: Document the new pass consistently everywhere the inventory is stated.

**Tasks**:
- [x] Re-read `commands/refresh.md`, `skills/skill-refresh/SKILL.md`, and
      `systemd/claude-refresh.service` before editing. *(completed)*
- [x] In **both** tables, insert the new pass as **row 5**, so the passes internal to
      `claude-refresh.sh` stay contiguous as rows 1-5, and renumber the old rows 5-10 to 6-11:
      *(completed -- verified byte-identical Gate/Destructive/Hourly cadence cells for row 5 and
      every renumbered row via an awk column diff)*
  - Pass: `Orphaned build-waiter poll loops`
  - Owning subsection (refresh.md): `Orphaned Build Waiters`. Owning Step / Section (SKILL.md):
    `Step 2 / "Process Safety"`.
  - Gate: `age-threshold-only (BUILD_WAITER_REAP_MIN, default 60 min; canonical-shape waiters
    also need a dead embedded writer PID or BUILD_WAITER_CEILING_MIN, default 240 min), no
    interactive confirmation, unaffected by --force`
  - Destructive: `Yes -- the waiting shell only; the writer and its build are never signaled`
  - Hourly cadence: `Yes (report-only via --dry-run; reaping is /refresh-only)`
- [x] Update each table's lead-in paragraph: "rows 1-4 / the four passes internal" becomes "rows
      1-5 / the five passes internal". Add one sentence saying row 5 is the only internal pass
      whose destructive action is not gated by `--force`. *(completed)*
- [x] refresh.md: add an `### Orphaned Build Waiters` subsection covering: *(completed)*
  - [x] the two signature families and their dead-writer tests;
  - [x] the self-exclusion set (pid, ppid, pgid, and the ancestor chain, all from one snapshot,
        with fail-closed behavior), linked to the self-match incident class without citing task
        numbers;
  - [x] the rule that detection never uses `pgrep -f` or `ps | grep` *(altered: phrased as "never
        uses a process-name-substring search (a `ps | grep` shape)", avoiding the literal
        substring "pgrep" for consistency with Phase 1's own verification choice, same meaning)*;
  - [x] the gate class and its rationale (0% CPU and unable to resolve, as opposed to merely
        idle);
  - [x] both env vars;
  - [x] hourly-cadence reachability.
- [x] refresh.md: add a bullet for the new pass to the "Process Protection" list. Update the
      `--force` row in the Options table to name this pass among those unaffected by `--force`.
      *(completed)*
- [x] SKILL.md: add a matching bullet under "Process Safety". In Step 2, add a note covering two
      points. First, the no-flag survey invocation already reaps past-threshold waiters (by
      design, like rows 6-9's sweeps). Second, the confirmation trigger MUST NOT key off
      `No orphaned build waiters found.`, following the existing zombie/MCP carve-out paragraph.
      *(completed)*
- [x] `systemd/claude-refresh.service`: re-derive the "new-passes ruling" comment. `main()` now
      calls five passes. The new pass is **not** `--force`-gated: its destructive trigger is the
      absence of `--dry-run`. Because this unit's `ExecStart` always passes `--dry-run`, the unit
      stays non-destructive. Record that reasoning, and update "four internal passes" and
      "ten-item" to "five" and "eleven-item". *(completed)*
- [x] Optional: add a one-sentence pointer in `context/patterns/bounded-build-waiter.md` naming
      `claude-refresh.sh`'s build-waiter pass as the reaper that matches the canonical signature.
      *(completed)*
- [x] Commit the edited doc files by explicit path, in one commit, so the two tables land
      together. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/commands/refresh.md`: table row, renumbering, lead-in, new
  subsection, Process Protection bullet, Options `--force` row.
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md`: table row, renumbering, lead-in,
  Process Safety bullet, Step 2 note.
- `agent-system/extensions/core/systemd/claude-refresh.service`: the re-derived ruling comment.
- (optional) `agent-system/extensions/core/context/patterns/bounded-build-waiter.md`: the pointer
  sentence.

**Verification**:
- The two tables have 11 rows each, and the Gate, Destructive, and Hourly cadence cells are
  byte-identical per row.
- The text contains no "task N" references (see Phase 4's lint).

---

### Phase 4: Cross-file consistency and final gate [NOT STARTED]

**Goal**: Run the full gate set and confirm the two inventories agree.

**Tasks**:
- [ ] Extract columns 1, 4, 5, and 6 from both tables (with `awk -F'|'`) and `diff` them. Expect
      no differences.
- [ ] Run `bash agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` in
      full.
- [ ] Run `shellcheck` on `claude-refresh.sh` and the test suite.
- [ ] Run `agent-system/extensions/core/scripts/check-task-references.sh` over the edited files.
- [ ] Live dry-run smoke test: `bash agent-system/extensions/core/scripts/claude-refresh.sh
      --dry-run`. Confirm the new section renders and nothing is killed. Do NOT run it without
      `--dry-run` against the live machine during implementation.
- [ ] Confirm that nothing under `.claude/` was hand-edited. That tree is a deploy artifact
      regenerated from the source store.

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Files to modify**:
- None expected (fixes only, if a gate fails).

**Verification**:
- All of the above pass. The table diff is empty.

## Testing & Validation

- [ ] `test-claude-refresh-matcher.sh` passes, including all new build-waiter cases, twice in a
      row.
- [ ] The mutation checks confirm that the pgid and ancestor exclusions are load-bearing.
- [ ] The `--dry-run` path never invokes `kill`. The no-flag path reaps without `--force`.
- [ ] If the `$$` row is missing, the pass fails closed.
- [ ] The two inventory tables agree row for row, and the systemd ruling is re-derived.
- [ ] shellcheck is clean, and the task-reference lint is clean.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/claude-refresh.sh` (new pass)
- `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` (new coverage)
- `agent-system/extensions/core/commands/refresh.md`,
  `agent-system/extensions/core/skills/skill-refresh/SKILL.md`,
  `agent-system/extensions/core/systemd/claude-refresh.service` (inventory and ruling)
- `specs/174_refresh_orphan_waiter_reaper/summaries/01_orphan-waiter-reaper-pass-summary.md`

## Rollback/Contingency

Each phase is a separate, path-scoped commit, so any phase can be reverted with `git revert
<sha>` without touching sibling tasks' work. Emergency disable without reverting: set
`BUILD_WAITER_REAP_MIN` to a very large value, which makes the pass report-only in practice.
Never use `git-snapshot.sh` in its reverting default mode, because sibling tasks share this
working tree.
