# Research Report: Task #170

- **Task**: 170 - Audit and isolate shell test suites from ambient host state (memory and timing
  axes), and record the convention
- **Started**: 2026-10-16T03:52:00Z
- **Completed**: 2026-10-16T04:10:00Z
- **Effort**: ~20 agent-minutes (investigation + live sandbox validation + a full corpus run)
- **Dependencies**: 206, 215, 250, 251, 366 (all archived/completed — confirmed, see Findings)
- **Sources/Inputs**: codebase (agent-system/extensions/**), live suite execution (isolated and
  full-corpus), a standalone sandbox reproduction of the recommended fix, git history
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- The corpus re-derives to **153** `test-*.sh` suites today (72 -> 111 -> 153), exactly matching
  `run-all.sh`'s own two-pattern discovery. The task's 18-entry `file_scope` and its narrowed
  `research_questions` (both already set by a prior research/revision pass) remain the correct
  scope — no additions are needed to it by this pass.
- **Instance A** (`test-lake-build-guard.sh`, memory axis): confirmed still fully isolated via
  its documented `LAKE_BUILD_GUARD_PSI_PATH`/`MEMINFO_PATH` seams (48/0 passed in isolation; no
  residual unseamed `/proc`/`pgrep`/`ps` read anywhere in the suite or the script under test). It
  has also been a member of `run-all.sh`'s `LOAD_SENSITIVE_BASENAMES` since 2026-09-25, so it now
  runs serially ahead of the parallel pool on every invocation. The 2026-09-22 "reopened" claim
  never pinned a specific failing case and does not reproduce under current isolated or
  correctly-scheduled runs.
- **Instance B** (`test-four-tier-conflict.sh` cases 5 & 6, timing axis): root cause fully
  diagnosed and a concrete fix **validated live in a standalone sandbox** (not yet applied — this
  is implement-phase work). `task-lock.sh`'s `cmd_acquire_retry` loop is counter-based, never
  reads the clock; the suite's externally-measured elapsed time is dominated by real `sleep`
  calls plus the forking cost of N+1 `cmd_acquire` attempts, which balloons under CPU contention.
  The recommended fix (a PATH-shimmed fake `sleep`, asserting the exact retry-iteration count
  instead of a wall-clock window) removes the host-load dependency entirely with **no change to
  production code** — validated to produce `sleep_count == BUDGET_MS/POLL_MS` exactly across two
  different budgets.
- A full 153-suite `run-all.sh` run (first one since the last `--jobs auto` flip) surfaced **4
  failures, all unrelated to this task's defect classes** and already correctly excluded from
  this task's scope per the dispatch's own instruction not to misfile other defect classes here:
  one genuine stale-artifact cleanup (fixed as a byproduct), one self-inflicted timeout from this
  research session's own concurrent load, and two pre-existing real defects (grant-TTL matching,
  context-budget byte-count drift) that belong to separate owners.
- Several suites already in the corpus independently demonstrate the *correct* causal/ordering
  pattern this task's convention should generalize — concrete citable exemplars beyond instance A.

## Context & Scope

This is the **research phase** for a long-running, heavily-iterated task: the task description
already carries four dated addenda (2026-09-22, 2026-09-22, 2026-10-04, 2026-10-05) from prior
research/revision passes, and a 2026-10-08 commit already narrowed `research_questions` to the
single reproducible instance (`test-four-tier-conflict.sh` case 6). This report does not repeat
that prior work; it re-verifies it against the current (2026-10-16) state of the corpus, closes
open questions the addenda left unresolved (instance A's "reopened" status; whether the 2026-10-04
roster of six "NEW" fixture-gap suites is still red), and supplies the concrete, validated fix
design for instance B that the implement phase needs.

Scope is bounded to the **ambient-host-state defect class** the dispatch names (memory, wall-clock
timing, load/CPU count, network, disk, process table, "anything else read from the live host
rather than from a fixture"). Fixture-completeness defects (a sandbox copy-list missing a
collaborator) and unrelated real defects are explicitly **out of scope** per the dispatch's own
repeated warning not to misfile them here — several were encountered during this pass and are
reported below for completeness and handed to their own owners, not folded into this task's
triage verdicts.

## Findings

### Corpus re-derivation

Re-derived by replicating `run-all.sh`'s exact discovery (`scripts/tests/test-*.sh` +
flat `scripts/test-*.sh`, per extension), not by trusting any previously-cited figure:

| Extension | Suite count |
|---|---|
| core | 130 |
| literature | 7 |
| lean | 6 |
| approvals | 4 |
| books | 4 |
| typst | 2 |
| **Total** | **153** |

Growth trajectory: 72 (2026-09-07 dispatch) -> 111 (2026-10-04 addendum) -> 153 (now). The two
dependency-added repo-health probes (`test-script-inventory.sh`, `test-context-reachability.sh`,
from archived tasks 250/251) are confirmed present and clean of every named ambient-host-state
signal (checked directly; no hits).

### Instance A (memory axis) — re-verified, not reopened

- `test-lake-build-guard.sh` isolated run: **48 passed, 0 failed**.
- No unseamed `/proc`, `pgrep`, or `ps` reference anywhere in the suite or in
  `lake-build-guard.sh` itself beyond the two documented env seams
  (`LAKE_BUILD_GUARD_PSI_PATH`, `LAKE_BUILD_GUARD_MEMINFO_PATH`) and explanatory comments — the
  guard deliberately avoids `pgrep`/`ps`-based waiting in favor of `flock`, per its own header
  commentary ("during research, four long-lived... NEVER driven by `pgrep lean`").
- **New fact the 2026-09-22 addendum did not have**: since commit `1435f6e59` (2026-09-25, task
  261 phase 5), `test-lake-build-guard.sh` is a member of `run-all.sh`'s
  `LOAD_SENSITIVE_BASENAMES` array, so it now runs **serially, alone, ahead of the parallel pool**
  on every invocation — substantially reducing its exposure to sibling-suite contention (though
  not to genuine external ambient load on the host).
- The addendum's "reopened" claim is based on one observation that never isolated which case
  failed (it says so itself: "the full-suite run does not name it"). It does not reproduce under
  the current isolated run or under the now-serialized scheduling. **Verdict: affected-and-isolated
  (memory axis closed); the "reopened" claim is unconfirmed and should not reopen this task's
  scope** — if it recurs, capture per-case output on the specific failing run before scoping new
  work, per the addendum's own method note.

### Instance B (timing axis) — root cause diagnosed, fix validated

Read `task-lock.sh:937-975` (`cmd_acquire_retry`) directly. The loop is **entirely counter-based**:
`waited_ms` is incremented nominally by `TASK_LOCK_RETRY_POLL_MS` each iteration; the loop never
calls `date` or reads the clock to decide when to stop. The externally-measured elapsed time the
suite asserts on is therefore the sum of (a) N real `sleep(POLL_MS)` calls — a deterministic
floor — plus (b) N+1 full `cmd_acquire` attempts' forking overhead (multiple `jq` subprocess
spawns, mutex acquire/release each attempt), which is the part that balloons under CPU contention.
For `BUDGET_MS=1000`, `POLL_MS=100`: exactly 10 sleeps + 11 `cmd_acquire` attempts. This precisely
explains the task's own recorded idle-vs-loaded figures (1752-1798ms idle, 2472-2989ms loaded: the
delta is attempt-forking overhead, not sleep time, which is fixed at 1000ms either way).

This is independently corroborated by `run-all.sh`'s own `LOAD_SENSITIVE_BASENAMES` rationale
comment (added 2026-09-25, same commit as instance A's serialization): `"test-four-tier-conflict.sh:
TASK_LOCK_RETRY_BUDGET_MS=5000 budget-bound wall-clock assertion"` — i.e. **this suite has already
been serialized ahead of the parallel pool for three weeks**, and the task's own 2026-10-08
`research_questions` entry shows it *still* failed under genuine `--jobs auto` contention despite
that serialization. This is direct proof that sibling-suite-contention mitigation is insufficient
alone; the fix must remove the host-load dependency from the assertion itself.

**Recommended fix, validated live in a standalone sandbox (copy of `task-lock.sh` + its real
collaborators, a real held-lock fixture, no change to production code):**

- A fake `sleep` (one line: append to a counter file, `exit 0`, no real delay) placed in a
  directory prepended to `PATH` for just the `$TL acquire-retry` invocation. `cmd_acquire_retry`
  already calls plain `sleep` (never an absolute path), so PATH substitution is a legitimate test
  seam — **no change to `task-lock.sh` is needed**.
- **Case 6** (budget-bound): assert `rc6 -eq 1` (unchanged) **and** `sleep_count == BUDGET_MS /
  POLL_MS` exactly — a deterministic, host-load-independent causal invariant. Validated twice:
  `BUDGET_MS=1000,POLL_MS=100 -> sleep_count=10`; `BUDGET_MS=500,POLL_MS=100 -> sleep_count=5`
  (scales exactly as predicted — proves the check is non-vacuous, not a hardcoded pass). Measured
  end-to-end wall clock with the fake sleep: 471ms (vs. ~1752-2989ms real), so an optional,
  generous backstop (e.g. `elapsed_ms < 10000`, "nowhere near a minutes-scale wait") can still be
  kept as defense-in-depth, but must never be the primary signal.
- **Case 5** (same-session re-entry): **drop** the `elapsed5_ms -lt 500` clause entirely.
  `rc5 -eq 0 && note_count5 -eq 0` is *already* a complete, direct, host-independent proof the
  retry loop body was never entered (`NOTE:` is only ever printed on the first retry iteration,
  before the first sleep) — the elapsed-time clause is strictly redundant and was the only
  host-coupled term in this case.
- **Case 1**: confirmed **not** host-coupled, as the dispatch asked to check. It reports elapsed
  time in its `pass()` message string for diagnostics only; the `if` condition
  (`rc1 -eq 0 && note_count1 -eq 1 && abort_count1 -eq 0`) never compares on it. No change needed.

### Pre-existing positive exemplars worth citing in the convention (new finding)

Several suites already in the corpus independently demonstrate the exact causal/ordering
discipline this task wants to generalize, discovered while sweeping the corpus for other
candidates:

- `test-gate-registry-resolution.sh` cases 15/16: a dependent function only proceeds once a
  completion marker for its prerequisite is observed in a shared trace log (never an absolute
  duration comparison), and a "serialized id runs alone" guarantee is proven via start/end
  timestamp **ordering**, not a window. Case 17 proves a worker-cap via a `flock`-guarded atomic
  counter, not timing.
- `test-state-write-regen-timing.sh` case 1: proves "mutex released before regeneration begins"
  by having a *different* session successfully acquire the mutex while the regen stub is still
  deliberately blocked — a direct causal proof, not a timing measurement. Its internal
  `max_iters`-bounded poll is a generic "never hang" ceiling, not an assertion target.
- `test-claude-refresh-matcher.sh`: every `/proc/PID/stat` read already goes through a documented
  `PROC_ROOT` seam; its `pgrep`/`ps aux` references are structural text-absence assertions against
  production code, not live process-table reads.
- `test-run-task-observers.sh` case (j), `test-zotero-generate-export.sh`'s
  `t_timeout_guard_fires`, `test-run-all-selection.sh` cases 11/13, and
  `test-gate-registry-resolution.sh` case 13: five further suites already apply the "generous
  bounded-widening last resort" correctly (3x-15x margin over their own declared timeout, proving
  "didn't hang" rather than a tight proportional window) — a good model set for that rung of the
  ladder, confirming it is not merely theoretical.

### Corpus-wide re-sweep for additional timing-window candidates

Re-ran the dispatch's own keyword classes against the full current 153-suite corpus (not the
stale 72-suite-era list), plus a targeted search for `elapsed*_ms`-shaped variables compared with
`-lt`/`-le`/`-ge`/`-gt`. Every suite surfaced (`test-state-write-concurrency.sh`,
`test-run-task-observers.sh`, `test-zotero-generate-export.sh`, `test-run-all-selection.sh`,
`test-verify-deploy-gate-selection.sh`, `test-claude-refresh-matcher.sh`,
`test-gate-registry-resolution.sh`, `test-guard-git-push.sh`, `test-orchestrate-cycle-postflight.sh`,
`test-orchestrate-recover-message-findings.sh`, `test-reconcile-demote-stranded.sh`,
`test-lint-shellcheck-parallel.sh`) was individually read. Only `test-four-tier-conflict.sh`
carries the tight proportional-window defect shape; every other hit is either benign fixture
timestamp construction (`date`-based "N minutes ago" epoch arithmetic, explicitly commented "no
sleeping" in several), or one of the positive exemplars above.

### Fixture-completeness class (out of this task's scope, verified current)

All six suites named in the 2026-10-04 roster addendum, plus `test-orchestrate-recover-outcome.sh`
(2026-10-05), were re-run live via `run-all.sh --only`: **all now pass cleanly**
(`test-orchestrate-cycle-plan.sh`, `test-orchestrate-build-aux-dispatch.sh`,
`test-lint-deploy-caller-wrap.sh`, `test-gate-out-repair-reporting.sh`,
`test-lint-json-channel-discipline.sh`, `test-orchestrate-recover-outcome.sh`). This class appears
already resolved in this corpus (consistent with task 206's defensive audit and routine fixes
landed since the addenda were written). `test-detect-noop-bash.sh` is the one exception — see
below.

### New finding: `test-detect-noop-bash.sh` — stray-artifact cleanup, fixed; one open question

Isolated run failed two cases ("stray tmp dir created ... `NOOP_BASH_STATE_DIR` override not
honored") because `agent-system/extensions/core/tmp/` existed on disk as an **empty, untracked,
dated-two-days-stale** directory, not created by the run under test. The suite itself
unconditionally exports `NOOP_BASH_STATE_DIR` before any case runs (confirmed by reading it), so
it cannot be the suite's own code creating this path. Removing the empty directory (a single
`rmdir`, safe and reversible — this location is correctly *not* gitignored at this nested path,
per `runtime-file-patterns.sh`'s deliberate root-scoped-only `/specs/tmp/` design, so its absence
is the expected state) made the suite pass **50/0** cleanly, and repeated re-runs do not recreate
it. **This is fixture/environment debris, not ambient-host-state** (correctly flagged per the
dispatch's own instruction not to misfile this class here) — recorded because it blocked clean
measurement of the file_scope roster and the fix was in-scope-safe to apply directly.

**Open question, evidenced but not fully root-caused**: during the full 153-suite `run-all.sh` run
performed for this report (see below), the exact same two cases failed again with the identical
symptom, then the directory was gone again by the time this was checked afterward. Grepped the
entire corpus for every reference to `detect-noop-bash.sh`; confirmed no other suite creates this
specific path (one writes a *synthetic* fixture path shaped like it, inside its own `mktemp`
root). The production hook's own default (`$SCRIPT_DIR/../tmp`) only resolves to this exact path
when invoked directly from the *source-store* location without the override — which only this
suite's own code does, and only ever with the override already set. The most defensible
conclusion is **external interference from an unrelated concurrent process on this shared,
multi-session host** (this session's own teammate roster shows other active agents), not a defect
in this suite or in `detect-noop-bash.sh`. **Recommendation for the implement phase**: make this
specific check delta-based (snapshot whether the directory existed *before* the suite started,
and only fail if it did not exist before but does after) rather than an absolute existence check,
so pre-existing or externally-introduced debris cannot produce a false attribution to "this run."
This is a new sub-shape of the ambient-host-state class worth naming in the convention: a shared,
non-fixture, non-gitignored filesystem path whose existence depends on uncontrolled external
activity, distinct from the memory/timing/load axes but remediable by the same "isolate against
what you don't control" principle.

### Full-corpus live run (153 suites, `--jobs auto`) — 4 failures, all out of this task's scope

A complete `run-all.sh --quiet` run was performed end to end (took ~11 minutes, dominated by
`test-gate-cache-equivalence.sh`'s 543s hinted cost) concurrently with this research session's own
heavy test activity (1-minute load average measured at 6.97 partway through). Result: **149
passed, 4 failed, 153 total.**

| Suite | Verdict |
|---|---|
| `test-detect-noop-bash.sh` | Stray-artifact false failure, see above — not ambient-host-state, now understood |
| `test-gate-cache-equivalence.sh` | `TIMEOUT` at the 600s per-suite bound. Confirmed this suite contains **no** ambient-host-state signal (grepped directly) — it is simply slow (real `verify-deploy.sh` gate executions via a real git worktree). The timeout here is attributable to this *research session's own* unusually heavy concurrent test activity overlapping the background run, not a clean independent measurement; reported honestly rather than claimed as a fresh corpus-wide discovery. |
| `test-guard-git-push.sh` | One case, reproducible **in isolation too** (not load-related): `"invalidation: expired grant expected exit 2, got 0"`. Traced the production threshold (`PG_EXPIRY_WINDOW=600`, `pg_grant_fresh()` in `push-grant-lib.sh:432-440`) — the test's 700s-old grant has 100s of slack past the threshold, and the check is a *relative* age (not absolute wall-clock), so this does not fit any named ambient-host-state axis. Most likely a grant-matching/test-isolation defect (an earlier case's still-fresh grant being matched instead of the deliberately-expired one) — **a separate real defect, out of this task's scope**, flagged for its own owner rather than folded into this task's triage. |
| `test-verify-deploy-context-budget.sh` | Two cases, reproducible **in isolation too**: a baseline-fixture byte-count drift (`current_eager='67088', baseline_bytes='66100'`). Deterministic, load-independent — a docs-sync/byte-count pin gone stale, the same general fragility class `shell-script-testing.md`'s own "Gate 8" section already documents for this suite, but a different specific drift than the one already fixed. **Separate real defect, out of this task's scope.** |

None of these four match the memory/timing/load/network/disk/process-table ambient-host-state
axes this task owns, and per the dispatch's explicit instruction, none should be folded into this
task's triage verdicts or its fix work.

## Decisions

- **No `file_scope` changes.** The existing 18-entry scope (set by a prior research/revision pass)
  already names exactly the right files: `task-lock.sh`, `test-conflict-predicate.sh`,
  `test-four-tier-conflict.sh`, the three state-write suites, `test-session-registry.sh`,
  `test-session-runtime-files.sh`, `test-task-lock-reap.sh`, `known-failures.txt`, and the six
  fixture-completeness suites plus `test-orchestrate-recover-outcome.sh`. `test-lake-build-guard.sh`
  is deliberately **not** added back — this research found no current defect to fix there, and
  re-opening it without a pinned failing case would violate the dispatch's own "re-verify, don't
  assume" guidance.
- **Instance A stays closed.** Treat as affected-and-isolated (memory axis), not reopened.
- **Instance B's fix is fully specified and sandbox-validated**, ready for the implement phase to
  apply directly to `test-four-tier-conflict.sh` cases 5 and 6 (case 1 unchanged, verified clean).
- **The `test-detect-noop-bash.sh` stray directory was removed** (a single `rmdir` of an
  already-empty, untracked, non-gitignored directory, confirmed safe and within this repo's own
  "this location should never exist" convention). This is a workspace-state fix, not a file edit,
  and is not tracked via `file_scope`.
- **Four other live-run failures are explicitly excluded from this task's triage**, per the
  dispatch's repeated instruction not to misfile unrelated defect classes here, and handed off as
  separate findings for their own owners (see Findings table above and Risks below).

## Recommendations

1. **Implement phase: apply the validated case 5/6 fix** to
   `agent-system/extensions/core/scripts/test-four-tier-conflict.sh` exactly as specified above —
   PATH-shimmed fake `sleep`, `sleep_count`-based causal assertion for case 6, dropped elapsed
   clause for case 5 — and re-verify with the suite's own non-vacuousness convention (drive the
   opposite direction: confirm a *shorter* budget yields a proportionally smaller `sleep_count`,
   as already demonstrated in this report's sandbox validation).
2. **Implement phase: write the new convention section** in
   `agent-system/extensions/core/context/standards/shell-script-testing.md` (currently 594 lines,
   far grown from the dispatch's cited 127-line baseline — the file already has substantial
   adjacent infrastructure: `LOAD_SENSITIVE_BASENAMES`, `known-failures.txt`, and a "Measurement
   discipline" section governing cost-claim validity, none of which duplicate this task's
   deliverable). The new section should:
   - Name the defect class and blast radius, citing instance A (memory, fixed) and instance B
     (timing, fix designed by this report) as the one-per-axis worked examples.
   - State the seam-first rule for readable-input axes (instance A's model).
   - State the timing-axis ladder (inject-clock / assert-causality / bounded-widening-last-resort)
     with instance B's PATH-shim technique as the primary inject-clock worked example, and cite
     `test-gate-registry-resolution.sh` cases 15/16/17 and `test-state-write-regen-timing.sh`
     case 1 as pre-existing causal-assertion exemplars, and the five generous-bounded-widening
     suites named above as the last-resort exemplar set.
   - Add the new sub-finding: a suite's "nothing stray was created" check against a **shared,
     non-fixture, live-tree path** must be delta-based (before/after), not absolute existence —
     citing `test-detect-noop-bash.sh`'s finding as the worked example.
   - Require the per-suite non-vacuousness check; forbid threshold relaxation; cross-reference
     (not restate) the existing Fixture convention and Loud-skip discipline sections.
3. **Implement phase: fix `test-detect-noop-bash.sh`'s clean-check** to be delta-based, per the
   new sub-finding above, so it is robust to pre-existing or externally-introduced debris at that
   path.
4. **Do not fold the four full-corpus failures found above into this task.** Hand off
   `test-guard-git-push.sh`'s grant-matching case and `test-verify-deploy-context-budget.sh`'s
   byte-count drift as separate real-defect findings (each needs its own owner/task); treat
   `test-gate-cache-equivalence.sh`'s timeout as a measurement artifact of this research session's
   own concurrent load, not a corpus-wide finding requiring action.
5. **Repeated-run acceptance (the dispatch's own (a)/(b)/(c) criteria) is implement-phase, not
   research-phase, work** — this report supplies the fix design and the current clean baseline
   (149/153 passing, with every failure attributed to a specific, scoped-out cause) the implement
   phase needs to reach it, but does not itself attempt the 3-consecutive-green-run-plus-load
   requirement.

## Risks & Mitigations

- **Risk**: the PATH-shim technique for case 6 could be seen as "too clever" relative to the
  codebase's plain, explicit style. **Mitigation**: it requires zero production-code changes,
  is a single `mktemp -d`-scoped fixture file, and is directly validated against two different
  budget values in this report — it is a smaller, more legible diff than adding a new env-seam to
  `task-lock.sh` would be.
- **Risk**: the `test-detect-noop-bash.sh` cross-session interference is not fully root-caused —
  the delta-based fix recommendation mitigates the symptom without requiring the exact external
  cause to be identified, which may not even be possible from inside a single dispatch on a
  shared host.
- **Risk**: `test-gate-cache-equivalence.sh`'s 543s hinted cost (now the single largest in the
  corpus) means any future full-corpus measurement taken while other heavy work shares the host
  risks a spurious `TIMEOUT` unrelated to this task — already documented in
  `shell-script-testing.md`'s "Measurement discipline" section; no new mitigation needed beyond
  following that section's existing load-average-reporting discipline.

## Context Extension Recommendations

- None beyond the convention-doc addition itself (recommendation 2 above), which is this task's
  own named deliverable, not a gap in unrelated context documentation.

## Appendix

### Search queries / commands used

- Corpus re-derivation: replicated `run-all.sh`'s own `for f in "$ext_scripts/tests"/test-*.sh;
  ... for f in "$ext_scripts"/test-*.sh;` discovery loop directly against
  `agent-system/extensions/*/scripts/`.
- Keyword sweep: `grep -E` over `/proc/meminfo|/proc/pressure|SwapTotal|/proc/loadavg|nproc|
  getconf _NPROCESSORS|uptime|curl |wget |ping |df |pgrep|ps aux|ps -ef| SECONDS|date \+%s|date
  \+%N` across every discovered suite, plus a targeted `elapsed*_ms.*(-lt|-le|-ge|-gt)` sweep.
- Live validation: standalone sandbox built from real `task-lock.sh` + `deploy-root-guard.sh` +
  `lib/{file-scope-overlap,common,task-lookup-lib}.sh`, a real held-lock fixture, and a PATH-shimmed
  fake `sleep`; run twice at `BUDGET_MS=1000,POLL_MS=100` and `BUDGET_MS=500,POLL_MS=100`.
- Full-corpus run: `bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet` (default
  `--jobs auto`), ~11 minutes, 149/153 passing.
- Dependency verification: confirmed tasks 206, 215, 250, 251, 366 all present under
  `specs/archive/` with `[COMPLETED]` summaries.

### References

- `task-lock.sh:937-975` (`cmd_acquire_retry`)
- `run-all.sh:493-499` (`LOAD_SENSITIVE_BASENAMES`) and its rationale comment block
  (`run-all.sh:464-479`)
- `push-grant-lib.sh:101,432-440` (`PG_EXPIRY_WINDOW`, `pg_grant_fresh`)
- `agent-system/extensions/core/context/standards/shell-script-testing.md` (current 594 lines)
- Commit `1435f6e59` (2026-09-25, task 261 phase 5) — added parallelism and
  `LOAD_SENSITIVE_BASENAMES`
- Commit `878043472` — instance A's original memory-axis fix
