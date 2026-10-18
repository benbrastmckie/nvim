# Implementation Plan: Task #413

- **Task**: 413 - Coordinate full gate-set runs across concurrent sessions in one repository, so sibling /orchestrate sessions stop contending for the same cores
- **Status**: [IMPLEMENTING]
- **Effort**: 10 hours
- **Dependencies**: None
- **Research Inputs**: specs/413_coordinate_concurrent_gate_runs/reports/01_concurrent_gate_run_coordination.md
- **Artifacts**: plans/01_concurrent-gate-run-coordination.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, shell-script-testing.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a repository-scoped `.gate-lock` named mutex to `task-lock.sh` and bracket the two places a
full gate-set battery actually runs — `tests/run-all.sh`'s top level and `verify-deploy.sh`'s
`gate8_run()` — so two concurrent sessions in one checkout serialize their batteries instead of
contending for the same cores. The mechanism is a **bounded-wait lease that fails open**: a
waiter blocks for a budget while printing the holder's identity, then proceeds unserialized with
a loud warning rather than ever refusing verification. Done means: the five required fixtures
pass against the real mechanism, the contract is documented in
`context/patterns/batch-orchestration-guardrails.md`, the deploy is regenerated, and the full
gate set passes with an explicit source-store `TARGET`.

### Research Integration

The research report settles the lease-vs-advisory question the dispatch required be settled
(Decision 1: bounded lease with mandatory fail-open, not pure advisory, not an unbounded lease)
and fixes the reuse surface: `acquire_named_mutex`/`release_named_mutex` plus a
`commit-acquire`/`commit-release`-shaped CLI pair, with the fail-open decision living at the call
sites exactly as `git-commit-scoped.sh` already places it for `.commit-lock`. This plan executes
that design and adds four integration constraints verified in the source store at plan-authoring
time that the report did not surface:

1. **The source-store copy of `task-lock.sh` cannot be invoked.** It sources
   `deploy-root-guard.sh`, which exits 1 for any `scripts/` directory not under `.claude/` or
   `.opencode/`. Both call sites must therefore invoke the **deployed** copy
   (`<repo_root>/.claude/scripts/task-lock.sh`), which is also what makes `PROJECT_ROOT`
   (`SCRIPT_DIR/../..`) resolve to the one repository whose `specs/` tree holds the mutex — the
   dispatch's repo-scoping requirement is satisfied by that resolution, not by new code.
   `verify-deploy.sh` already invokes deployed sub-check copies this way (see its gate 9/gate 10
   comments), so Phase 3 follows an established in-file pattern rather than inventing one.
2. **`tests/run-all.sh` already installs two `EXIT` traps**, one per execution branch
   (`trap 'rm -f "$SUITE_OUT"' EXIT` on the sequential path, `trap 'rm -rf "$OUT_DIR"' EXIT` on
   the parallel path). A top-level release trap installed before them would be silently
   clobbered, leaking the mutex for a full staleness window. Phase 2 therefore routes all three
   cleanups through one composed handler.
3. **A `--only`-narrowed `run-all.sh` run must not take the lock.** Suite narrowing is the
   sanctioned way a non-final phase discharges a sub-`full` verification tier
   (`plan-format.md`'s Verification Tiers section); making a two-suite run wait out a sibling's
   full battery would tax exactly the cheap path the tiering scheme exists to enable. The lock is
   for the full battery only.
4. **The new fixture suite must clear `RUN_ALL_NESTED` for its own unnested cases**, the same
   inherited-variable hazard `test-run-all-parallel.sh` documents and handles at its top.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch, and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- A `.gate-lock` named-mutex family in `task-lock.sh` with `gate-acquire`/`gate-release`
  subcommands, built on the existing `acquire_named_mutex`/`release_named_mutex` primitive.
- Holder-identifying periodic progress output during a wait, so a waiting run is never mistaken
  for a hang.
- Both battery call sites bracketed, nested invocations running as guests, fail-open on every
  coordination failure.
- Five fixtures against the real mechanism, plus a contended before/after wall-clock figure
  carrying its 1-minute load average.
- The contract documented in `context/patterns/batch-orchestration-guardrails.md`, cross-
  referenced from `shell-script-testing.md`'s measurement-discipline section.

**Non-Goals**:
- Changing `orchestrate-batch-gate.sh`, `gate-registry.data`'s `serialized` column, or
  `LOAD_SENSITIVE_BASENAMES` semantics — all complementary, all must keep working unchanged.
- Cross-session reuse of a sibling's gate verdict (research Decision 7: needs an attribution
  layer that does not exist).
- Auto-degrading to a narrower gate selection on contention (research Decision 8).
- Any change to `.scope-lock`, `.commit-lock`, or `.contention-claims` behaviour.
- Killing, signalling, or otherwise reaching into another session's processes, ever.
- Substantive new content in `shell-script-testing.md` beyond one cross-reference sentence (two
  sibling tasks are sequenced after this one against that file).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A top-level release trap in `run-all.sh` is clobbered by a branch `EXIT` trap, leaking the mutex | H | H (certain if written naively) | Phase 2 installs one composed handler; the fixture suite asserts the mutex directory is absent after a fixture battery exits on both the sequential and parallel paths |
| An added positional parameter changes `acquire_named_mutex`'s behaviour for its existing callers | H | L | Parameter is optional and appended; Phase 1's verification runs the suites covering all existing callers and asserts the silent-wait path is unchanged when it is omitted |
| A waiter blocks long enough to look like the hang this task exists to remove | H | M | Bounded budget plus mandatory periodic holder-naming progress lines; fail-open on budget exhaustion |
| A crashed holder deadlocks the repository | H | L | Holder-declared staleness reclaim already in `acquire_named_mutex`; Phase 4 fixture proves the reclaim branch is actually taken, asserted on its `WARN: reclaiming stale` line |
| Nested Gate 8 -> `run-all.sh` self-deadlocks | H | M (certain if the guard is omitted) | Three composed guards: `RUN_ALL_NESTED`/`VERIFY_DEPLOY_NESTED` at entry, plus an inherited `GATE_MUTEX_HELD` guest flag; Phase 4 fixture proves no mutex directory is created |
| The deployed `task-lock.sh` is absent or stale in a consumer tree | M | M | Presence check at both call sites; absent copy means skip coordination with a named Note, never a failure |
| A fixture touches the live `specs/.gate-lock` and collides with a real gate run | M | M | Every fixture builds an isolated temp root (`test-task-lock-liveness.sh` / `test-run-all-parallel.sh` pattern); no fixture resolves a path against the live tree |
| A sibling task edits a file in this task's scope mid-flight | M | L | Declared `file_scope` does not intersect the three concurrent siblings' declared scopes (417, 424, 443); re-read each file immediately before editing and stage only this task's own hunks |
| The contended measurement is taken on a quiet host and proves nothing | M | M | The measurement is explicitly specified to run under self-generated concurrency with the load average recorded at measurement time; an idle figure is not accepted as evidence |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4, 6 | 2, 3 |
| 4 | 5 | 4 |
| 5 | 7 | 5, 6 |

Phases within the same wave can execute in parallel.

### Phase 1: `.gate-lock` mutex family and `gate-acquire`/`gate-release` CLI [COMPLETED]

**Goal**: `task-lock.sh` exposes a repo-scoped, holder-identifying, bounded-wait gate mutex with
the same token-ownership contract as `commit-acquire`/`commit-release`, and
`acquire_named_mutex` can optionally report progress while waiting — with every existing caller
unchanged.

**Tasks**:
- [x] Add an optional fifth positional parameter to `acquire_named_mutex`
      (`progress_label`, empty by default). When non-empty, the wait loop emits a line to stderr
      at a fixed interval naming the elapsed wait and the holder read from
      `$mutex_dir/owner` (`session_id`, `pid`), e.g.
      `[gate-lock] waiting 30s for session=<holder_session> pid=<holder_pid> ...`. When empty,
      the loop is byte-equivalent to today's silent wait. Update the function's header comment to
      document the parameter and state that omitting it preserves existing behaviour.
      *(completed: progress_label param added, GATE_MUTEX_PROGRESS_INTERVAL_S-paced progress
      line using the label itself as the bracket tag; byte-equivalent silent wait confirmed for
      existing callers via smoke test)*
- [x] Add the `.gate-lock` constants next to the existing families, both env-overridable in the
      established `${VAR:-default}` style: `GATE_MUTEX_STALE_SEC` (default 1800, matching the
      only existing long-critical-section precedent, `CONTENTION_CLAIM_STALE_SEC`) and
      `GATE_MUTEX_ACQUIRE_BUDGET_MS` (default 600000 — long enough to wait out several idle-host
      batteries, strictly below the staleness window per research Decision 6), plus
      `GATE_MUTEX_PROGRESS_INTERVAL_S` (default 15). Comment the sizing rationale and state
      explicitly that the budget must never exceed the staleness window. *(completed)*
- [x] Add `acquire_gate_mutex` / `release_gate_mutex` thin wrappers over the primitive, passing
      `".gate-lock"` and the progress label. *(completed)*
- [x] Add `cmd_gate_acquire <session_id> [stale_sec]` and `cmd_gate_release <token>` as close
      siblings of `cmd_commit_acquire`/`cmd_commit_release`: same `session_id:pid:claimed_epoch`
      token, same `owner` file written via `jq -n`, same owner-token-verified release that warns
      and skips on mismatch rather than deleting a successor's claim, same return 2 on timeout
      naming the current holder. Release always returns 0. *(completed)*
- [x] Register both subcommands in the dispatch `case` block and in the usage/help text.
      *(completed: also added to the top-of-file Usage: comment block)*
- [x] Extend the top-of-file contract comment: `.gate-lock` is a third independent critical
      section with its own reentrancy flag `GATE_MUTEX_HELD` (never `COMMIT_MUTEX_HELD` or
      `SCOPE_MUTEX_HELD`), state that the primitive fails CLOSED (return 2) while the call sites
      fail OPEN, and record that it serializes full gate-set batteries across sessions in one
      repository. *(completed)*
- [x] Smoke-exercise the CLI by hand from a throwaway `.claude/scripts`-shaped temp root: acquire
      returns a token and creates `specs/.gate-lock/{claimed_at,stale_sec,owner}`; a second
      acquire with `GATE_MUTEX_ACQUIRE_BUDGET_MS=200` returns 2 and names the holder; release
      with the right token removes the directory; release with a wrong token warns and leaves it.
      *(completed: all four outcomes confirmed; also confirmed .commit-lock's wait path emits no
      progress lines and that the progress-label format itself fires correctly at a 1s interval)*

**Timing**: 1.75 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: The edit is confined to `task-lock.sh` with no change to any existing
signature's behaviour, and the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-task-lock-liveness.sh,test-task-lock-reap.sh,test-session-registry.sh,test-state-write-concurrency.sh,test-state-write-regen-timing.sh,test-git-commit-scoped.sh`,
which exercises every existing `acquire_named_mutex` caller and both existing CLI mutex pairs.

**Scope Hypothesis**: `acquire_named_mutex` is asserted to have exactly three existing wrapper
families (`.scope-lock`, `.commit-lock`, `.contention-claims`) and no other callers — a figure
carried from the research report's codebase-patterns section. Confirm at implementation time with
`grep -n 'acquire_named_mutex' agent-system/extensions/core/scripts/task-lock.sh` before relying
on it; if a fourth caller exists, add its covering suite to this phase's `--only` list.

**Files to modify**:
- `agent-system/extensions/core/scripts/task-lock.sh` - optional progress parameter on
  `acquire_named_mutex`; `GATE_MUTEX_*` constants; `acquire_gate_mutex`/`release_gate_mutex`;
  `cmd_gate_acquire`/`cmd_gate_release`; dispatch `case` and usage text; top-of-file contract
  comment

**Verification**:
- The `--only` suite list above passes with no new failures relative to the known-failure
  baseline.
- `bash -n agent-system/extensions/core/scripts/task-lock.sh` and `shellcheck` on that file
  report no new findings.
- The hand smoke exercise above produces the four stated outcomes, transcript captured in the
  phase's progress notes.
- A no-progress-label wait (e.g. a forced `.commit-lock` timeout in the temp root) emits no
  progress lines, confirming existing callers are untouched.

---

### Phase 2: `tests/run-all.sh` top-level gate-lock bracket [NOT STARTED]

**Goal**: A full, unfiltered `run-all.sh` battery holds `.gate-lock` for its duration, releases
it on every exit path, runs as a guest when nested or when an outer holder exists, skips the lock
entirely for a `--only`-narrowed run, and fails open with a named warning whenever coordination
is unavailable.

**Tasks**:
- [ ] Resolve the deployed `task-lock.sh` in both discovery branches: `deployed` mode ->
      `$DEPLOY_SCRIPTS_ROOT/task-lock.sh`; `source-store` mode -> `<repo_root>/.claude/scripts/task-lock.sh`
      where `<repo_root>` is two levels above `$EXTENSIONS_ROOT`. Record in a comment why the
      source-store copy is not callable (`deploy-root-guard.sh`).
- [ ] Introduce one composed `EXIT` handler (e.g. `run_all_exit_cleanup`) installed once, which
      releases the gate lock if owned here and removes whichever of `$SUITE_OUT` / `$OUT_DIR`
      exists. Replace the two branch-local `trap ... EXIT` installations with assignments to
      those variables so no branch can clobber the release.
- [ ] Acquire after `--only` resolution and immediately before `SUITE_RUN_START_MS`, only when
      all of: the suite set was not narrowed by `--only`, `RUN_ALL_NESTED` was not already `1` at
      entry, `GATE_MUTEX_HELD` is not inherited, and the deployed `task-lock.sh` is present.
      Export `GATE_MUTEX_HELD=1` on success so launched suites and any nested
      `verify-deploy.sh` run as guests.
- [ ] On acquire failure (exit 2 or any other non-zero), print a single `WARNING:` line naming
      the mutex, this run's session string, the holder if known, and the explicit fail-open worst
      case (contention persists for this run; verification is neither skipped nor altered), then
      proceed. Mirror `git-commit-scoped.sh`'s posture, including its refusal to cite an
      unreproduced result as settled.
- [ ] Print a `Note:` line for each skip reason (`--only` narrowed, nested, inherited guest flag,
      deployed `task-lock.sh` absent) so a lock-free run is always attributable.
- [ ] Use a stable session string when none is available — `"run-all-$$"` — and document that the
      mutex is opaque to its shape.
- [ ] Update `run-all.sh`'s header to document the gate-lock bracket, its four skip conditions,
      and the fail-open posture.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Tier Justification**: The change alters the harness every suite and Gate 8 run under, so the
covering check is the changed module's own suites plus its enumerated direct dependents:
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-run-all-parallel.sh,test-run-all-selection.sh,test-run-all-failure-reporting.sh,test-deploy-verify-wiring.sh,test-task-lock-liveness.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/run-all.sh` - deployed `task-lock.sh` resolution in
  both mode branches; composed `EXIT` cleanup replacing the two branch traps; conditional
  acquire/release bracket with four skip conditions; fail-open warning; header documentation

**Verification**:
- The `--only` suite list above passes with no new failures relative to the baseline.
- `bash -n` and `shellcheck` on `run-all.sh` report no new findings.
- A full battery invocation creates `specs/.gate-lock/` while running and leaves no directory
  behind after exit, observed on both `--jobs 1` and `--jobs 4` (checked in an isolated temp
  root, not the live tree).
- A `--only test-common-lib.sh` invocation creates no `.gate-lock` directory and prints the
  narrowed-run `Note:`.
- A `RUN_ALL_NESTED=1`-prefixed invocation creates no `.gate-lock` directory and prints the
  nested `Note:`.

---

### Phase 3: `verify-deploy.sh` Gate 8 gate-lock bracket [NOT STARTED]

**Goal**: `gate8_run()` brackets only its `run-all.sh` invocation with the gate lock, after
selection resolution, so a `--skip-slow` or Gate-8-excluding run never touches the mutex and the
other 22 gates are never serialized.

**Tasks**:
- [ ] Inside `gate8_run()`, in the branch that actually invokes `run-all.sh` (after the
      `gate_selected 8`, `SKIP_SLOW`, source-store, and runner-presence checks), acquire the lock
      immediately before the `run_all_output=$(...)` assignment and release immediately after,
      on both the success and failure paths.
- [ ] Invoke the deployed copy `$TARGET/.claude/scripts/task-lock.sh`, guarded by a presence
      check, matching the gate 9/gate 10 deployed-sub-check pattern already in this file; absent
      copy means skip coordination with a named `say` note, never a gate failure.
- [ ] Skip acquisition entirely when `VERIFY_DEPLOY_NESTED` was already `1` at entry or
      `GATE_MUTEX_HELD` is inherited; export `GATE_MUTEX_HELD=1` on a real acquisition so the
      `run-all.sh` child runs as a guest and performs no second acquire.
- [ ] On acquire failure, emit the same shaped `WARNING:` fail-open line as Phase 2 and run the
      gate anyway; the gate's own verdict, `FINDING` lines, and summary output must be unchanged
      by anything in this phase.
- [ ] Release on every path out of the bracket, including the `run_all_status != 0` branch;
      prefer an explicit release immediately after the capture over a trap, since this script's
      exit paths are gate-scoped.
- [ ] Document the bracket in the `gate8_run()` header comment: why only Gate 8 is locked, why
      the deployed copy is invoked, and the fail-open posture.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: The edit is confined to one function in `verify-deploy.sh` with no change
to any gate's verdict surface, and the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-verify-deploy-gate-selection.sh,test-verify-deploy-gate-selection-crash-net.sh,test-deploy-verify-wiring.sh,test-deploy-verify-overlap.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` - gate-lock acquire/release bracket
  around `gate8_run()`'s `run-all.sh` invocation, nested/guest skips, fail-open warning, header
  comment

**Verification**:
- The `--only` suite list above passes with no new failures relative to the baseline.
- `bash -n` and `shellcheck` on `verify-deploy.sh` report no new findings.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 8 /home/benjamin/.config/nvim`
  prints the Gate 8 `[SKIP]` line and creates no `.gate-lock` directory.
- `bash .claude/scripts/verify-deploy.sh --only-gate 1 /home/benjamin/.config/nvim` creates no
  `.gate-lock` directory.
- A single `--only-gate 8` run (no `--skip-slow`) reports the same verdict and summary line shape
  as before the change, with the mutex created during and absent after.

---

### Phase 4: Fixture suite — serialization, stale-holder reclaim, nested invocation [NOT STARTED]

**Goal**: A new registered suite proves, against the real mechanism in an isolated temp root,
that two concurrent full batteries do not overlap, that a killed holder is reclaimed through the
stale path, and that a nested invocation creates no mutex at all.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/tests/test-gate-lock.sh`, executable, built on
      the synthetic-fixture pattern `test-run-all-parallel.sh` establishes (a
      `$WORKDIR/exts/core/manifest.json` source-store anchor with a copied `run-all.sh` and three
      trivial fixture suites) extended with the `.claude/scripts` temp root
      `test-task-lock-liveness.sh` establishes (copied `task-lock.sh`, `deploy-root-guard.sh`,
      `lib/common.sh`, `lib/task-lookup-lib.sh`, `lib/file-scope-overlap.sh`), so the mutex lands
      in `$WORKDIR/specs/.gate-lock` and the live tree is never touched.
- [ ] `unset RUN_ALL_NESTED` and `unset GATE_MUTEX_HELD` once at the top, with the same comment
      `test-run-all-parallel.sh` carries: both are exported into every suite an outer
      `run-all.sh` launches and would silently make the unnested cases vacuous.
- [ ] Case: **serialization**. Launch two concurrent fixture-battery `run-all.sh` invocations,
      each fixture suite appending `start`/`finish` epoch-millisecond markers to a shared file;
      assert the two `[start, finish]` windows do not overlap. Assert on marker ordering, never
      on a wall-clock threshold.
- [ ] Case: **non-vacuousness of the serialization assertion**. Run the same two invocations with
      the lock disabled (deployed `task-lock.sh` removed from the fixture root, which takes the
      documented fail-open skip) and assert the windows *do* overlap, so a passing serialization
      case cannot pass for an unrelated reason.
- [ ] Case: **stale/killed holder**. Acquire via the real CLI from a child process, `kill -9` it
      without releasing, then acquire again with a tiny `GATE_MUTEX_STALE_SEC` and assert both
      that acquisition succeeds and that the holder-declared reclaim branch was taken, by
      matching the primitive's own `WARN: reclaiming stale specs/.gate-lock mutex` line.
- [ ] Case: **nested invocation**. Invoke the fixture battery with `RUN_ALL_NESTED=1`, and
      separately with `GATE_MUTEX_HELD=1`, asserting in both that `$WORKDIR/specs/.gate-lock`
      is never created and that the run still completes with its normal verdict.
- [ ] Case: **no leak**. After each of the above, assert `$WORKDIR/specs/.gate-lock` is absent,
      on both the `--jobs 1` and `--jobs 2` paths, covering Phase 2's composed-trap change.
- [ ] Register the suite in `agent-system/extensions/core/manifest.json`'s `provides.scripts`
      array as `tests/test-gate-lock.sh`, subdirectory-qualified per the registration standard.
- [ ] Add `test-gate-lock.sh` to `run-all.sh`'s `LOAD_SENSITIVE_BASENAMES`, with a one-line
      rationale matching the existing entries' style: it performs real lock contention and
      concurrent process launches, the same property that put `test-state-write-concurrency.sh`
      there.

**Timing**: 2 hours

**Depends on**: 2, 3

**Verification Tier**: interface

**Tier Justification**: The new suite plus the `LOAD_SENSITIVE_BASENAMES` edit changes the
battery's own scheduling surface, so the covering check is the changed module plus its direct
dependents:
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-gate-lock.sh,test-run-all-parallel.sh,test-run-all-selection.sh,test-double-loading-check.sh,test-common-lib.sh`,
together with `bash <source_dir>/scripts/verify-deploy.sh --skip-slow --only-gate 6,7 /home/benjamin/.config/nvim`
for the manifest-registration surface.

**Scope Hypothesis**: This phase assumes `LOAD_SENSITIVE_BASENAMES` currently holds 5 entries and
that the suite corpus `run-all.sh` discovers is the ~147-suite battery the dispatch cites — both
carried figures (the first from `run-all.sh`'s own in-file comment, the second from the task
description). Confirm at implementation time by reading the array and by the suite count
`run-all.sh` prints; neither figure is load-bearing for correctness, only for the comment text,
so correct the comment rather than the design if they differ.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-gate-lock.sh` - new suite (serialization,
  non-vacuousness, stale reclaim, nested, no-leak cases)
- `agent-system/extensions/core/manifest.json` - add `tests/test-gate-lock.sh` to
  `provides.scripts`
- `agent-system/extensions/core/scripts/tests/run-all.sh` - add the new suite to
  `LOAD_SENSITIVE_BASENAMES` with its rationale comment

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-gate-lock.sh` exits 0 with every case
  `[PASS]` and a non-zero `Passed:` count.
- The non-vacuousness case genuinely fails when the lock is disabled, demonstrated by its own
  assertion rather than asserted in prose.
- The `--only` list and the gate 6,7 subset above pass with no new failures relative to the
  baseline.
- `jq -e '.provides.scripts | index("tests/test-gate-lock.sh")' agent-system/extensions/core/manifest.json`
  succeeds.
- `shellcheck` on the new suite reports no findings.

---

### Phase 5: Fixture suite — fail-open and verdict identity, plus the contended measurement [NOT STARTED]

**Goal**: The suite additionally proves that a forced coordination failure still yields a real
gate verdict, that coordination changes no result, and the required before/after wall-clock
comparison is recorded under genuine contention with its load average.

**Tasks**:
- [ ] Case: **fail-open**. Force the acquire to fail in the fixture root — a stub
      `.claude/scripts/task-lock.sh` whose `gate-acquire` exits 2 — and assert the fixture
      battery still runs, still reports its real verdict and summary line, and emits the named
      `WARNING:` fail-open line. Repeat for the `verify-deploy.sh` call site with
      `--only-gate 8` against the fixture root.
- [ ] Case: **verdict identity**. Run the fixture battery twice concurrently from two distinct
      session strings against identical fixture state, and once serially as a baseline; assert
      the `[FAIL]`/`[PASS]`/`[SKIP]` line sets and the final summary line are byte-identical
      across all three, so coordination provably does not change results. Use the repository's
      verdict-line extraction contract rather than an ad hoc grep.
- [ ] Take the contended before/after wall-clock comparison deliberately under self-generated
      concurrency: two real `verify-deploy.sh --only-gate 8 <source_dir>` invocations started
      together, measured once with the gate lock active and once with it disabled via
      `GATE_MUTEX_ACQUIRE_BUDGET_MS=0` (which forces the documented fail-open path rather than
      requiring a code change). Record for each: both invocations' wall-clock times, the
      1-minute load average immediately before and immediately after each window, and the host's
      core count.
- [ ] Record the measurement in the task's progress notes with an explicit statement that the
      figures were taken under contention by design and are not idle-host figures — and state
      the one thing they do not show (they measure this host, this moment, two writers; they are
      not a general throughput claim).
- [ ] Record issues and wins to `issues.jsonl` as they arise during the measurement, per the
      dispatch's issue-log mandate.

**Timing**: 1.75 hours

**Depends on**: 4

**Verification Tier**: interface

**Tier Justification**: The added cases exercise both call sites' fail-open paths together, so
the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-gate-lock.sh,test-run-all-failure-reporting.sh,test-verify-deploy-gate-selection.sh`
plus the two measured real `--only-gate 8` runs this phase already performs.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-gate-lock.sh` - add the fail-open and
  verdict-identity cases

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-gate-lock.sh` exits 0 with the two new
  cases `[PASS]`.
- The fail-open case asserts on the presence of the `WARNING:` line AND on a real verdict, not
  merely a zero exit.
- The verdict-identity case compares extracted verdict lines byte-for-byte against the serial
  baseline.
- Both measured `--only-gate 8` windows are recorded with pre- and post-window 1-minute load
  averages and the core count; the gate-lock-active pair shows non-overlapping battery windows.
- The `--only` list above passes with no new failures relative to the baseline.

---

### Phase 6: Document the contract [NOT STARTED]

**Goal**: The coordination contract is documented where this class of orchestration guardrail
already lives, classified by that file's own criteria, and cross-referenced from the
measurement-discipline section that already describes the hazard.

**Tasks**:
- [ ] Add a new section to `context/patterns/batch-orchestration-guardrails.md` covering: the
      lease-vs-advisory decision and why a bounded lease with mandatory fail-open was chosen over
      both alternatives; the `.gate-lock` mechanism and its reuse of the existing named-mutex
      primitive; the two call sites and why only Gate 8 is bracketed; the four skip conditions
      (narrowed run, nested, inherited guest flag, deployed script absent); the fail-open posture
      with its explicit worst case; repo scoping via the deployed copy's `PROJECT_ROOT`
      resolution; the never-kill-another-session's-process invariant; and composability with
      `orchestrate-batch-gate.sh` and `verify-deploy.sh`'s selection surface.
- [ ] Classify it against that file's own Blocking-vs-Advisory criterion, stating that it is
      neither — it never refuses dispatch, it defers a cost-only operation and always has a
      fail-open escape — and add a `Gate Catalogue` row classifying it as a self-clearing
      ORDERING CONSTRAINT (it clears when the holder releases, finishes, or goes stale), in the
      same shape as the existing `session_active` and held-lock rows.
- [ ] Record the two rejected alternatives on their own merits: cross-session verdict reuse
      (needs an attribution-and-confirm layer that does not exist) and auto-degrading to a
      narrower gate selection on contention (would silently miss the complete-gate-set bar on
      exactly the busy runs where contention is likeliest).
- [ ] Add exactly one cross-reference sentence to `context/standards/shell-script-testing.md`'s
      "Measurement discipline" section pointing at the new section — no substantive content
      there, per the dispatch's sequencing note.
- [ ] Keep both files free of task-number references and record-versioning language; cite durable
      anchors (file names, section headings) only.

**Timing**: 1.25 hours

**Depends on**: 2, 3

**Verification Tier**: prose

**Tier Justification**: Both edits are pure prose in markdown files with no executable surface,
and the covering check is the diff read-through for comment/prose confinement plus
`bash <source_dir>/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
(doc-lint and task-reference lint, named with the explicit source-store `TARGET` because the bare
form would silently take both gates' SKIP branch).

**Files to modify**:
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - new
  coordination-contract section, Blocking-vs-Advisory classification, Gate Catalogue row,
  rejected alternatives
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - one cross-reference
  sentence in the "Measurement discipline" section

**Verification**:
- `bash <source_dir>/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  exits 0 with both gates actually running (not SKIP) and no new findings.
- `bash .claude/scripts/check-task-references.sh` reports no new occurrences for either file.
- A diff read-through confirms the `shell-script-testing.md` change is one sentence in the
  measurement-discipline section and nothing else.
- Every cross-reference in the new section resolves to an existing file and heading.

---

### Phase 7: Redeploy and full gate set [NOT STARTED]

**Goal**: The source-store changes are deployed to the running `.claude/` tree and the complete
gate set passes against the explicit source-store target.

**Tasks**:
- [ ] Re-read each touched source-store file immediately before this phase to confirm no sibling
      task has modified it, and confirm every phase above is committed with its own scoped hunks.
- [ ] Run `bash .claude/scripts/deploy-headless.sh` to regenerate the deployed tree, and confirm
      `.claude/scripts/task-lock.sh`, `.claude/scripts/verify-deploy.sh`,
      `.claude/scripts/tests/run-all.sh`, `.claude/scripts/tests/test-gate-lock.sh`, and the two
      context files carry the new content.
- [ ] Run the complete gate set with an explicit source-store `TARGET`:
      `bash .claude/scripts/verify-deploy.sh /home/benjamin/.config/nvim` — the full aggregator,
      no `--skip-slow`, no `--only-gate`, no `--max-cost`, so every gate including Gate 8's full
      battery and the source-store-only gates actually runs.
- [ ] Compare the result against the known-unrelated pre-existing failures the dispatch
      enumerates (Gate 3 lean4 doc-lint missing `index.json` entry; Gate 20 eager-load budget
      over baseline; Gate 8 suites `test-detect-noop-bash.sh`, `test-four-tier-conflict.sh`,
      `test-guard-git-push.sh`). Attribute nothing to this work without evidence, and fix none of
      them here.
- [ ] Confirm the gate run's own Gate 8 took the lock and released it — the mechanism verifying
      itself under its own final gate — and that `specs/.gate-lock` is absent afterwards.
- [ ] Write the implementation summary, including the contended measurement from Phase 5 with its
      load averages.

**Timing**: 1 hour

**Depends on**: 5, 6

**Verification Tier**: full

**Files to modify**:
- none planned (verification, deploy, and summary only)

**Verification**:
- `bash .claude/scripts/deploy-headless.sh` completes successfully and the six deployed paths
  above carry the new content.
- `bash .claude/scripts/verify-deploy.sh /home/benjamin/.config/nvim` — the complete gate set,
  every gate run with the explicit source-store target — reports no failures other than the five
  enumerated known-unrelated pre-existing ones, each matched to its dispatch-named symptom rather
  than assumed.
- `bash agent-system/extensions/core/scripts/tests/test-gate-lock.sh` passes against the
  deployed tree as well as the source store.
- `specs/.gate-lock` does not exist after the gate run completes.

---

## Testing & Validation

- [ ] Two concurrent full-battery invocations in one repository do not run the battery
      unserialized, proven by non-overlapping start/finish markers against the real mechanism.
- [ ] The serialization assertion is non-vacuous: with coordination disabled, the same two
      invocations provably overlap.
- [ ] A killed holder does not deadlock the repository, and the stale-reclaim branch is proven
      taken by its own `WARN: reclaiming stale` line.
- [ ] The nested Gate-8-invokes-`run-all.sh` path creates no mutex and is never treated as a
      competing session, under both `RUN_ALL_NESTED=1` and an inherited `GATE_MUTEX_HELD`.
- [ ] With coordination forced to fail, verification still runs and still reports its real
      verdict, with a named fail-open warning, at both call sites.
- [ ] Two concurrent invocations from separate sessions produce byte-identical verdict lines and
      summary line to a single serialized baseline run.
- [ ] A before/after wall-clock comparison for the concurrent case, taken under deliberate
      contention, with the 1-minute load average recorded before and after each window and the
      core count stated.
- [ ] A `--only`-narrowed run, a `--skip-slow` run, and a Gate-8-excluding `--only-gate` run each
      touch no mutex.
- [ ] `shellcheck` and `bash -n` clean on all four modified shell files.
- [ ] The complete gate set passes with an explicit source-store `TARGET`, modulo the five
      enumerated known-unrelated failures.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/task-lock.sh` — `.gate-lock` family,
  `gate-acquire`/`gate-release`, optional progress reporting
- `agent-system/extensions/core/scripts/tests/run-all.sh` — top-level gate-lock bracket,
  composed exit cleanup, `LOAD_SENSITIVE_BASENAMES` entry
- `agent-system/extensions/core/scripts/verify-deploy.sh` — Gate 8 gate-lock bracket
- `agent-system/extensions/core/scripts/tests/test-gate-lock.sh` — new fixture suite (five
  required fixtures plus the non-vacuousness and no-leak cases)
- `agent-system/extensions/core/manifest.json` — suite registration
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — the
  documented contract, its classification, and its Gate Catalogue row
- `agent-system/extensions/core/context/standards/shell-script-testing.md` — one cross-reference
  sentence
- Regenerated `.claude/` deploy tree
- `specs/413_coordinate_concurrent_gate_runs/summaries/01_concurrent-gate-run-coordination-summary.md`
  — including the contended measurement with its load averages

## Rollback/Contingency

Every phase lands as its own scoped commit, so the ordinary rollback is `git revert` of the
phase commits in reverse order followed by `bash .claude/scripts/deploy-headless.sh` to
regenerate the deployed tree — no working-tree-destructive operation is required, and none should
be used while sibling sessions share this tree.

If uncommitted work must be discarded mid-phase, take the snapshot first per
`context/contracts/recovery.md`'s rollback rung (which also documents the out-of-scope override
flag for a deliberate whole-tree case), then run the destructive command. For an ordinary
defensive checkpoint before the Phase 2 trap rewrite, use
`bash .claude/scripts/git-snapshot.sh 413 --no-revert`, which is durable without reverting the
working tree.

Partial-rollback escape hatches, in increasing order of reach: set
`GATE_MUTEX_ACQUIRE_BUDGET_MS=0` to force every acquire down the already-tested fail-open path,
which disables serialization with no code change; remove the `tests/test-gate-lock.sh` entry from
`provides.scripts` and redeploy to drop the suite alone; revert the Phase 2 and Phase 3 call-site
commits to leave the `task-lock.sh` primitive in place but unwired, which is inert because
nothing else calls it.
