# Implementation Plan: Task #159

- **Task**: 159 - Add an independently-gated reclamation pass for orphaned Lean LSP process trees
- **Status**: [IMPLEMENTING]
- **Effort**: 6.5 hours
- **Dependencies**: Task 158 (VmSwap-aware refresh memory accounting) — completed; provides `get_vmswap_kb`/`format_memory` and the `PROC_ROOT` test seam
- **Research Inputs**: specs/159_orphaned_lean_lsp_reclamation_pass/reports/01_lean-lsp-reclamation-pass.md
- **Artifacts**: plans/01_lean-lsp-reclamation-pass.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-script-testing.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a second, fully independent detection-and-reclamation pass to `claude-refresh.sh` that
identifies idle, orphaned `lake serve` -> `lean --server` -> `lean --worker` process trees spawned
by `lean-lsp-mcp` and terminates them strictly children-first. The new pass takes its own
`ps -C lake,lean` snapshot, uses its own comm+argv predicates, gates tree-wide on CPU idleness
plus a configurable elapsed-time threshold, and reuses the existing `is_system_slice_cgroup` /
`is_owned_by_current_uid` exclusions and task 158's VmSwap-aware memory accounting unchanged.
`is_claude_executable_comm` and the existing Claude pass's classification logic are not touched;
the only edit to existing code is factoring the SIGTERM->sleep->SIGKILL escalation body into a
shared `terminate_pid()` helper and restructuring `main()`'s early `exit 0` sites so the Lean pass
is reachable.

### Research Integration

Findings from `reports/01_lean-lsp-reclamation-pass.md` that directly shape this plan:

- **`comm` is `lake`/`lean`, never the full argv.** The dispatch's "comm in (`lake serve`,
  `lean --server`, `lean --worker`)" is shorthand; the predicate must be a two-part comm-gate +
  argv-pattern match, mirroring `is_claude_executable_comm`'s existing `node` branch shape.
- **The TTY gate cannot be reused.** Live inspection showed `lake serve`/`lean --server` retain a
  non-`?` controlling tty inherited from their spawning pty even when fully orphaned; only
  workers show `?`. The Lean pass gates on comm+args+cpu+age, never on tty.
- **Separate snapshot, not a widened shared one.** `ps -C lake,lean -o pid,ppid,uid,etimes,rss,
  pcpu,cgroup:200,comm,args --no-headers` was verified live. Widening `SNAPSHOT_PS_FIELDS` would
  force all three existing fake-`ps` fixtures to emit an extra column, a large blast radius for a
  pass the dispatch explicitly calls independently gated.
- **`ps -eo ... -C x` silently ignores the `-C` filter**; `ps -C x -o ...` is the correct,
  order-sensitive form.
- **Tree-wide gating, not per-row.** `pid`/`ppid` in the one Lean snapshot fully reconstruct the
  3-level hierarchy; a tree is a candidate only if *every* member passes the gate, so one freshly
  spawned or actively computing worker protects the whole tree.
- **Zombies are excluded by construction.** `ps` renders a defunct row's comm as `lake <defunct>`,
  which an exact `case` match already rejects — to be recorded as deliberate in a code comment.
- **`SKILL.md` Step 2 has no `AskUserQuestion` block today** despite the tool being declared and
  the script's own comment implying one; the new pass closes that pre-existing gap.
- **Default threshold**: 240 minutes, matching this repo's existing reap-threshold precedent
  (`ORCHESTRATOR_SESSION_REAP_MIN`, `TASK_LOCK_REAP_MIN`), env-overridable.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- A new, separately-gated Lean LSP predicate set and detection pass in `claude-refresh.sh`, with
  its own `ps -C lake,lean` snapshot decoupled from `SNAPSHOT_PS_FIELDS`.
- Tree-wide idle candidacy (all members must pass 0%-CPU + configurable elapsed threshold), with
  `is_system_slice_cgroup` and `is_owned_by_current_uid` reused unmodified as defense in depth.
- Strict workers -> server -> `lake serve` termination order, proven by an ORDERING assertion.
- Memory reported through task 158's VmSwap-aware `get_vmswap_kb`/`format_memory`.
- `--dry-run`-clean: the new pass reports and terminates nothing without `--force`.
- Documentation of the new pass in `skill-refresh/SKILL.md` and `commands/refresh.md`, plus the
  `AskUserQuestion` confirmation block the skill currently lacks.

**Non-Goals**:
- Any modification to `is_claude_executable_comm` (hard constraint: byte-identical at task end).
- Any change to the existing Claude pass's candidacy, exclusion, or tty logic.
- Any change to the `--dry-run`/`--force` flag contract or the addition of a Lean-specific flag.
- Widening `SNAPSHOT_PS_FIELDS` / `take_snapshot()`.
- Patching `lean-lsp-mcp` or `leanclient` (third-party, outside this repo).
- Tuning `lean-lsp-mcp`'s own LRU/eviction behavior.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Idle threshold set too low reclaims a tree the user is about to reuse | L (recoverable: MCP respawns; costs a rebuild) | M | Default 240 min per repo precedent; env-overridable `LEAN_LSP_IDLE_THRESHOLD_MIN`; documented in `--help` and both doc files |
| Busy tree misclassified as idle | M | L | Tree-wide gate: every member (root + server + all workers) must independently pass 0%-CPU and age gates; any one failing protects the whole tree |
| Parent killed before children, orphaning workers into PID 1 | M | L | Strict per-tree ordering (workers -> server -> root) via shared `terminate_pid()`; enforced by a fake-`kill` ORDERING assertion, not final-state checks |
| Accidental widening or drift of `is_claude_executable_comm` | H (violates hard constraint) | L | New code is fully additive; a dedicated byte-identity check against the pre-task blob in the final phase; cross-contamination assertions in both directions |
| `main()`'s two existing `exit 0` sites make the Lean pass unreachable | M | H (structural, already present) | Explicit restructure phase: the Claude pass's report/terminate bodies become functions; `exit 0` is replaced by a return so both passes always run |
| New `ps` invocation unsupported on some platform | L | L | Reuse the existing loud-failure convention: a failed `ps -C` invocation prints the command and exits non-zero, never silently degrading |
| Test-suite non-vacuousness gap for new assertions | M | M | New predicates did not exist before this change; assert their absence in the pre-task blob (function-absence proof), mirroring the suite's existing mutation-check reasoning |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 3 |
| 4 | 5 | 2, 4 |
| 5 | 6 | 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Lean Predicates and Separately-Scoped Snapshot [COMPLETED]

**Goal**: Add the additive, independently-callable Lean detection primitives to
`claude-refresh.sh` — three predicates and one snapshot function — with no wiring into `main()`
yet, so nothing in the existing Claude pass can be perturbed.

**Tasks**:
- [x] Add `is_lean_serve_comm(comm, args)`: comm exactly `lake` AND args matching ` serve` in the
      leanclient-spawned shape (`.../bin/lake serve -- -Dserver.reportDelayMs=0`), rejecting other
      `lake` subcommands (`lake build`, `lake exe cache get`). *(completed)*
- [x] Add `is_lean_server_comm(comm, args)`: comm exactly `lean` AND args containing `--server`. *(completed)*
- [x] Add `is_lean_worker_comm(comm, args)`: comm exactly `lean` AND args containing `--worker`. *(completed)*
- [x] Write a header comment block above the three predicates recording *why* they exist as a
      separate gate: comm alone cannot distinguish the three forms; the TTY gate is unusable here
      (live-verified: `lake serve`/`lean --server` keep an inherited pty); exact-`case` matching
      deliberately excludes `<defunct>` zombie rows (signaling a zombie reclaims nothing — only
      the parent's `wait()` reaps it), which must not be "fixed" into substring matching later. *(completed)*
- [x] Add `LEAN_LSP_IDLE_THRESHOLD_MIN="${LEAN_LSP_IDLE_THRESHOLD_MIN:-240}"` with a comment
      citing the 240-min precedent and the single-data-point nature of the 13h observation. *(completed)*
- [x] Add `LEAN_SNAPSHOT_PS_FIELDS` and `take_lean_snapshot()` using
      `ps -C lake,lean -o pid,ppid,uid,etimes,rss,pcpu,cgroup:200,comm,args --no-headers`, with a
      comment recording that `-C` must not be combined with `-e` (the `-eo ... -C` form silently
      returns the whole table), and the same loud-failure-on-`ps`-error convention as
      `take_snapshot()`. An empty result is normal (no Lean processes), not an error. *(completed)*
- [x] Add a field-index map comment for the Lean snapshot mirroring the existing
      `SNAPSHOT_PS_FIELDS` map comment. *(completed)*
- [x] Extend `print_help()` with a line documenting `LEAN_LSP_IDLE_THRESHOLD_MIN`. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts exactly three Lean process forms (`lake serve`,
`lean --server`, `lean --worker`) and one new snapshot function, touching one file. Confirm at
implementation time by running `ps -C lake,lean -o pid,ppid,comm,args --no-headers` against a
live `lean-lsp-mcp` tree (or the research report's recorded capture if none is running) and
verifying no fourth Lean-family process form appears; if one does, record it and extend the
predicate set rather than silently ignoring it.

**Files to modify**:
- `agent-system/extensions/core/scripts/claude-refresh.sh` — three new predicates, threshold
  constant, `LEAN_SNAPSHOT_PS_FIELDS`, `take_lean_snapshot()`, header/field-map comments, help text

**Verification**:
- `bash -n agent-system/extensions/core/scripts/claude-refresh.sh` passes
- Sourcing the script and calling each new predicate by hand against the research report's
  recorded rows returns the expected 0/1 for each of the three forms
- `bash agent-system/extensions/core/scripts/claude-refresh.sh --dry-run` output is unchanged
  from its pre-phase form (the additions are inert)
- `git diff` shows zero changed lines inside `is_claude_executable_comm`

---

### Phase 2: Predicate Test Block with Cross-Contamination Assertions [COMPLETED]

**Goal**: Add the acceptance bar's dedicated predicate test block to
`test-claude-refresh-matcher.sh`, proving the Lean matcher matches the three Lean forms and
rejects Claude comms, and that `is_claude_executable_comm` rejects all three Lean forms — no
cross-contamination in either direction.

**Tasks**:
- [x] Add assertion block `(f)` following the suite's existing `pass()`/`fail()`/`info()` and
      `WORKDIR` conventions. *(completed)*
- [x] Assert each Lean predicate returns true for its own form using the research report's live
      argv strings verbatim as fixtures. *(completed)*
- [x] Assert each Lean predicate returns false for the other two Lean forms (mutual exclusivity). *(completed)*
- [x] Assert all three Lean predicates return false for every Claude comm the existing suite
      exercises (`claude`, `node` with `claude-code` argv, `bash` with the script's own path). *(completed)*
- [x] Assert `is_claude_executable_comm` returns false for all three Lean rows (the reverse
      direction the acceptance bar requires). *(completed)*
- [x] Assert the zombie rows `lake <defunct>` / `lean <defunct>` are rejected by all three Lean
      predicates, with an inline comment naming this as a deliberate, tested exclusion. *(completed)*
- [x] Assert `is_lean_serve_comm` rejects `lake build` and `lake exe cache get` argv forms. *(completed)*
- [x] Extend the existing mutation check's marker list with the three new predicate names and
      `take_lean_snapshot`, so the pre-task blob demonstrably defines none of them
      (function-absence non-vacuousness proof, matching the suite's own recorded reasoning). *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase assumes the existing suite's five assertion blocks (a)-(e) and
one mutation check, so the new block is (f). Confirm by grepping the suite's block headers before
writing; renumber if the count differs.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` — new assertion
  block (f), extended mutation-check marker list

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` exits 0 with
  every prior assertion still passing and the new ones reported
- Temporarily inverting one new predicate's return makes the new block fail (non-vacuousness
  spot-check; revert immediately)

---

### Phase 3: Tree Assembly and Tree-Wide Idle Candidacy Gate [COMPLETED]

**Goal**: Turn the Lean snapshot into candidate trees and decide reclamation eligibility entirely
from the frozen snapshot, with VmSwap-aware memory accounting for reporting.

**Tasks**:
- [x] Parse `take_lean_snapshot()` rows into parallel indexed arrays keyed by pid (pid, ppid, uid,
      etimes, rss, pcpu, cgroup, comm, args), classifying each row via the Phase 1 predicates. *(completed)*
- [x] For each `lake serve` root, resolve its `lean --server` child by `ppid`, then that server's
      `lean --worker` children by `ppid`, entirely in-memory with no live re-query. *(completed)*
- [x] Apply zero-query self-exclusion (`pid`/`ppid` == `$$`) to every Lean row, matching the
      Claude pass. *(completed)*
- [x] Implement `lean_row_is_idle(etimes, pcpu)`: `pcpu` at/near zero AND
      `etimes >= LEAN_LSP_IDLE_THRESHOLD_MIN * 60`. Handle `pcpu`'s decimal form without
      `bc`/floats (integer comparison on the pre-decimal portion, documented inline). *(completed)*
- [x] Implement the tree-wide gate: a tree is a candidate only if **every** member (root, server
      if present, all workers) passes `lean_row_is_idle` AND `! is_system_slice_cgroup` AND
      `is_owned_by_current_uid`. Any single failure disqualifies the whole tree. *(completed)*
- [x] Handle the two edge cases the research names: a `lake serve` with no server child, and a
      server with zero workers — both still eligible when idle; record the ruling inline. *(completed)*
- [x] Accumulate per-tree reclaimable memory as `rss + get_vmswap_kb(pid)` summed over members,
      formatted with `format_memory` (both reused unmodified from task 158). *(completed)*
- [x] Add a comment recording that `get_vmswap_kb`'s post-snapshot `/proc` read is reporting-only
      here too, so the existing header's invariant ruling continues to hold for the new pass. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase assumes the 3-level hierarchy (root -> one server -> N workers)
observed live. Confirm at implementation time against a live tree that no `lake serve` has more
than one `lean --server` child; if multiple appear, generalize the server resolution to a loop
rather than assuming a single child.

**Files to modify**:
- `agent-system/extensions/core/scripts/claude-refresh.sh` — tree assembly, `lean_row_is_idle`,
  tree-wide gate, per-tree memory accounting

**Verification**:
- `bash -n` passes; `git diff` still shows zero changed lines in `is_claude_executable_comm`,
  `is_system_slice_cgroup`, `is_owned_by_current_uid`
- Hand-driving the gate function against the research report's recorded live rows classifies the
  observed tree as a candidate at threshold 40 min and as a non-candidate at threshold 240 min
  (the observed tree's `etimes` was ~3007s / ~50 min), confirming the threshold is load-bearing
- With `LEAN_LSP_IDLE_THRESHOLD_MIN` unset, the default 240 is used

---

### Phase 4: Ordered Termination and main() Wiring [COMPLETED]

**Goal**: Factor the existing SIGTERM->sleep->SIGKILL escalation into a shared helper, add strict
per-tree workers -> server -> root termination, and restructure `main()` so the Lean pass is
reachable and participates in the existing `--dry-run`/`--force` contract without changing it.

**Tasks**:
- [x] Extract the existing termination loop body into `terminate_pid(pid)` returning success/
      failure and emitting the same `PID N: terminated (graceful|forced)` / `already gone` /
      `failed to ...` lines verbatim; rewrite the Claude pass's loop to call it. No behavior or
      output change for the Claude pass. *(completed)*
- [x] Restructure `main()`'s two `exit 0` sites (the `orphan_count -eq 0` early return and the
      non-`--force` report-and-exit path) so the Claude pass's reporting and termination bodies
      become functions that *return* instead of exiting, and the Lean pass always runs afterward.
      Preserve every existing output line and its ordering for the Claude portion. *(completed)*
- [x] Add the Lean pass's default/`--dry-run` reporting: candidate trees with per-tree PIDs,
      roles, ages, `format_memory` RSS and swap columns, and a total reclaimable figure, under a
      clearly separated heading. `--dry-run` adds the same `[DRY RUN]` banner semantics already
      used; the no-flag path is identical to `--dry-run` minus the banner, exactly as the Claude
      pass does. *(completed)*
- [x] Add the `--force` Lean termination: iterate candidate trees; within each tree call
      `terminate_pid` for every worker first (siblings in any order), then the server, then the
      `lake serve` root. Multiple trees are handled one at a time, each fully ordered. *(completed)*
- [x] Ensure the "nothing found" case for either pass prints an explicit, non-alarming line rather
      than silence, and that the script's exit code semantics are unchanged. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts exactly two `exit 0` early-return sites inside `main()`
that must be restructured (the `orphan_count -eq 0` branch and the non-`--force` report branch).
Confirm by `grep -n 'exit 0' agent-system/extensions/core/scripts/claude-refresh.sh` before
editing; restructure every site found inside `main()`, not only two.

**Files to modify**:
- `agent-system/extensions/core/scripts/claude-refresh.sh` — `terminate_pid()` extraction,
  `main()` restructure, Lean reporting and ordered termination

**Verification**:
- `bash -n` passes; the full existing test suite still passes unchanged
- `bash agent-system/extensions/core/scripts/claude-refresh.sh --dry-run` on the live machine
  prints both sections and terminates nothing (`ps` shows the Lean tree still alive afterward)
- `--help` output documents the threshold env var
- `git diff` confirms the Claude pass's output strings are byte-identical

---

### Phase 5: Ordering and Dry-Run-Clean Assertions [COMPLETED]

**Goal**: Prove the acceptance bar's two behavioral claims with fixtures, not inspection: that
`--dry-run` lists a Lean tree without terminating anything, and that `--force` signals in the
documented order.

**Tasks**:
- [x] Add a fake `ps` on `PATH` (extending the suite's existing `FAKE_BIN_DIR` pattern) that
      recognizes the `-C lake,lean` invocation and emits a synthetic 5-row tree (root, server,
      three workers) with old `etimes` and zero `pcpu`, while delegating every other `ps`
      invocation to the real `ps` resolved to an absolute path before `PATH` is overridden — the
      same ancestry-safe technique assertion (d-2) already uses. *(deviation: altered — this fixture's fake ps answers every invocation shape itself (-p self-check, -C lake,lean, and the plain -eo table) rather than delegating non-matching calls to the real ps; the ancestry-walk self-pid trick from (d-2) is not needed here since no row in this fixture needs to distinguish the running test script's own pid -- all 5 rows are synthetic Lean-tree PIDs unrelated to $$)*
- [x] Add fixture `/proc/<pid>/status` files for the synthetic PIDs and drive them via the
      existing `PROC_ROOT` seam so `get_vmswap_kb` reads fixtures, never live `/proc`. *(completed)*
- [x] Assert `--dry-run` output lists all five synthetic PIDs and the reclaimable total, and that
      no `kill` was invoked (fake-`kill` log absent or empty) — the dry-run-clean assertion. *(completed)*
- [x] Add a fake `kill` on `PATH` that appends `"<signal> <pid>"` lines to a log file and exits 0
      without signaling anything; ensure it also answers `kill -0` liveness probes deterministically
      so the escalation path is exercised without real processes. *(completed: kill is a bash builtin; used `enable -n kill` in a dedicated subshell to shadow it, not a plain PATH override)*
- [x] Assert against the log that the three worker PIDs all appear before the server PID, and the
      server PID before the `lake serve` root PID — an ORDERING assertion on the log sequence, not
      a final-state check. Sibling worker order is unconstrained. *(completed)*
- [x] Assert the Claude pass's own `--dry-run` output is unaffected by the presence of Lean rows. *(completed)*
- [x] Add the new function/fixture names to the mutation-check marker list where applicable. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 2, 4

**Verification Tier**: local

**Scope Hypothesis**: This phase assumes a 5-row synthetic tree (1 root, 1 server, 3 workers) is
sufficient to exercise ordering. Confirm the ordering assertion actually fails when the
termination loop is reordered root-first (temporarily invert, observe RED, revert) — if it still
passes, the assertion is vacuous and must be strengthened.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` — fake `ps`
  extension, fake `kill`, fixture `/proc` entries, dry-run-clean and ORDERING assertions

**Verification**:
- Full suite exits 0 with all prior assertions intact
- Deliberately reversing the termination order in the script makes the ORDERING assertion fail
  (RED confirmed), then reverting restores GREEN
- No real process is signaled by the suite (`kill` is always the fake within these blocks)

---

### Phase 6: Documentation, Confirmation Prompt, and Acceptance Sweep [NOT STARTED]

**Goal**: Document the new pass in both user-facing files, add the `AskUserQuestion` confirmation
block `SKILL.md` currently lacks, and verify every acceptance-bar item including the
`is_claude_executable_comm` byte-identity constraint.

**Tasks**:
- [ ] Add a fifth bullet to `skill-refresh/SKILL.md`'s "Process Safety" section describing the
      Lean pass: separate snapshot, comm+argv predicate, tree-wide idle gate, configurable
      threshold, reused cgroup/UID exclusions, strict termination order — matching the existing
      four bullets' prose style.
- [ ] Add the parallel bullet to `commands/refresh.md`'s "Process Protection" section.
- [ ] Note in both files that the Lean pass deliberately does *not* use the TTY signal, with the
      live-verified reason (inherited pty survives orphaning).
- [ ] Document `LEAN_LSP_IDLE_THRESHOLD_MIN` (default 240 minutes, why conservative, how to
      override) in both files.
- [ ] Add an explicit `AskUserQuestion` block to `SKILL.md` Step 2 covering both Claude and Lean
      orphans in a single confirmation, then re-running with `--force` when confirmed — closing
      the pre-existing gap the script's own comment already assumes.
- [ ] Acceptance sweep: confirm `is_claude_executable_comm` is byte-identical to its pre-task form
      via `git show <pre-task-ref>:agent-system/extensions/core/scripts/claude-refresh.sh` and an
      extracted-function diff; confirm the `--dry-run`/`--force` contract and flag parsing are
      unchanged; run the full test suite; run `--dry-run` live and verify nothing is terminated.
- [ ] Confirm no task-number references appear in any edited deliverable outside `specs/**`.

**Timing**: 1 hour

**Depends on**: 5

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts two documentation sections ("Process Safety" in
`SKILL.md`, "Process Protection" in `refresh.md`) each currently holding five bullets. Confirm the
section names and bullet counts by grep before editing; if the sections have drifted, match the
current structure rather than the counts recorded here.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md` — Process Safety bullet,
  threshold documentation, Step 2 `AskUserQuestion` block
- `agent-system/extensions/core/commands/refresh.md` — Process Protection bullet, threshold
  documentation

**Verification**:
- Extracted-function diff of `is_claude_executable_comm` against the pre-task blob is empty
- `bash agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` exits 0
- `bash agent-system/extensions/core/scripts/claude-refresh.sh --dry-run` and `--help` behave as
  documented; `ps` confirms no process was terminated
- `bash .claude/scripts/check-task-references.sh` (or equivalent repo lint) reports no new
  violations in the edited files
- All edits are under `agent-system/extensions/core/`; no `.claude/**` file was hand-edited

---

## Testing & Validation

- [ ] Lean predicates match all three live-observed argv forms and reject each other's forms
- [ ] Lean predicates reject every Claude comm; `is_claude_executable_comm` rejects every Lean row
- [ ] `<defunct>` zombie rows rejected by all three Lean predicates
- [ ] `lake build` / `lake exe cache get` rejected by `is_lean_serve_comm`
- [ ] Tree-wide gate: one non-idle member disqualifies the whole tree
- [ ] `--dry-run` lists a Lean tree and terminates nothing (fake-`kill` log empty)
- [ ] `--force` termination order is workers -> server -> root, proven by log-sequence assertion
- [ ] Reordering the termination loop makes the ORDERING assertion fail (non-vacuousness)
- [ ] Existing Claude-pass assertions (a)-(e) and the mutation check still pass unchanged
- [ ] `is_claude_executable_comm` byte-identical to pre-task form
- [ ] `--dry-run`/`--force` flag contract and `--help` semantics unchanged apart from the added
      threshold documentation line

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/claude-refresh.sh` — three Lean predicates,
  `take_lean_snapshot()`, `lean_row_is_idle()`, tree assembly and tree-wide gate,
  `terminate_pid()` helper, ordered Lean termination, restructured `main()`
- `agent-system/extensions/core/scripts/tests/test-claude-refresh-matcher.sh` — predicate
  cross-contamination block, dry-run-clean assertion, ORDERING assertion, extended mutation check
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md` — Process Safety bullet,
  `AskUserQuestion` confirmation block, threshold documentation
- `agent-system/extensions/core/commands/refresh.md` — Process Protection bullet, threshold
  documentation
- `specs/159_orphaned_lean_lsp_reclamation_pass/summaries/01_*.md` — execution summary

## Rollback/Contingency

Every change is confined to four files under `agent-system/extensions/core/`, all tracked in git,
with per-phase commits. Rollback is `git revert` of the task's phase commits, or
`git checkout <pre-task-ref> -- <the four paths>` after a snapshot via
`bash .claude/scripts/git-snapshot.sh 159`. The Lean pass is additive and independently gated: if
it misbehaves in production, setting `LEAN_LSP_IDLE_THRESHOLD_MIN` to a very large value disables
reclamation in practice without any code change, and the Claude pass continues to work because it
shares no predicate, no snapshot, and no candidacy logic with the Lean pass. No state outside the
repository is mutated; terminated Lean trees are respawned automatically by `lean-lsp-mcp` on the
next tool call, so no data loss path exists.
