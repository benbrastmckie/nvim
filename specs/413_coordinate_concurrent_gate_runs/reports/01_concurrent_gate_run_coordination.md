# Research Report: Task #413

**Task**: 413 - Coordinate full gate-set runs across concurrent sessions in one repository, so sibling /orchestrate sessions stop contending for the same cores
**Started**: 2026-10-18T00:00:00Z
**Completed**: 2026-10-18T00:00:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**:
- `agent-system/extensions/core/scripts/task-lock.sh` (named-mutex family, session registry, `resolve_session_pid`, `session_liveness`)
- `agent-system/extensions/core/scripts/verify-deploy.sh` (Gate 8, selection surface, nested-invocation guard)
- `agent-system/extensions/core/scripts/tests/run-all.sh` (battery runner, `RUN_ALL_NESTED` guard, `--jobs`)
- `agent-system/extensions/core/scripts/orchestrate-batch-gate.sh` (per-batch frequency reduction — complementary, not duplicated)
- `agent-system/extensions/core/scripts/gate-registry.data` (per-gate `serialized` flag — within-pool only)
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` (fail-open posture precedent, `.commit-lock` usage)
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (admission-layer and gate-catalogue structure, Blocking-vs-Advisory criterion, Defer-Not-Fail standard)
- `agent-system/extensions/core/context/standards/shell-script-testing.md` (measurement-discipline section, origin of this task)
**Artifacts**:
- This report: `specs/413_coordinate_concurrent_gate_runs/reports/01_concurrent_gate_run_coordination.md`
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- The mechanism to build on already exists and is proven: `task-lock.sh`'s `acquire_named_mutex`/
  `release_named_mutex` primitive, already backing `.scope-lock` and `.commit-lock`, plus its
  holder-declared staleness and pid-based liveness detection (`resolve_session_pid`,
  `session_liveness`). No new concurrency primitive needs inventing.
- **Recommendation: a bounded-wait LEASE, not pure advisory registration — but one that
  explicitly fails open on timeout rather than refusing.** Pure advisory coordination does not
  satisfy the task's own stated goal ("sibling sessions stop contending for the same cores");
  a pure blocking-forever lease violates the fail-open mandate and risks becoming
  indistinguishable from the exact hang-shaped symptom that motivated this task. The bounded
  lease with mandatory fail-open on budget exhaustion is the synthesis that satisfies both.
- The right CLI surface is two new `task-lock.sh` subcommands, `gate-acquire`/`gate-release`,
  built as near-identical siblings of the existing `commit-acquire`/`commit-release` pair (same
  token-ownership contract, same fail-CLOSED return-2-on-timeout behavior at the primitive
  level) — the fail-OPEN decision belongs at the two call sites, exactly as
  `git-commit-scoped.sh` already does for `.commit-lock` today.
- The two call sites are `tests/run-all.sh`'s own top level (wrapping the whole battery) and
  `verify-deploy.sh`'s `gate8_run()` (wrapping only the `run-all.sh` invocation, not the other 22
  gates) — never the whole `verify-deploy.sh` process, since only Gate 8 is the measured
  contention source.
- Honouring the nested-invocation case is a direct re-application of the `RUN_ALL_NESTED` /
  `VERIFY_DEPLOY_NESTED` export pattern already in both scripts, plus a third, additive
  reentrancy flag (e.g. `GATE_MUTEX_HELD`) mirroring `COMMIT_MUTEX_HELD` so the outer holder's
  acquisition covers the inner, nested call without a second real acquire.
- Observability requires one deviation from the existing silent-poll loop in
  `acquire_named_mutex`: a multi-minute wait must emit periodic progress naming the holder, or it
  reproduces the "looks like a hang" problem one layer down. This is additive (an opt-in
  parameter), not a change to `.scope-lock`/`.commit-lock`'s existing short, silent waits.

## Context & Scope

This research resolves the lease-vs-advisory design question the dispatch requires be settled
explicitly, identifies the exact existing primitives to reuse, and locates the precise
integration points in `verify-deploy.sh` and `tests/run-all.sh` — scoped to the research phase;
exact constant values, the new CLI subcommand bodies, and the fixtures are left for the plan/
implementation phases to execute against this design.

Out of scope (confirmed non-duplicative, per the dispatch's own "what it is not" section):
`orchestrate-batch-gate.sh`'s per-batch frequency reduction (runs the gate set once per
`/orchestrate` invocation, not once per repository); `gate-registry.data`'s `serialized` column
and `tests/run-all.sh`'s `LOAD_SENSITIVE_BASENAMES` (both govern scheduling *within* one
process's own worker pool, never across two processes).

## Findings

### Codebase Patterns

**The named-mutex primitive (`task-lock.sh:616-660`, `acquire_named_mutex`/
`release_named_mutex`)** is a generic, already-reusable building block: `mkdir`-atomic acquire,
holder-declared staleness (`stale_sec` written into the mutex dir by whoever claims it, so every
waiter honours the *claimant's* window, not its own default), stale-reclaim-with-WARN, and a
bounded poll-and-wait budget. Three existing families already wrap it:

- `.scope-lock` (`SCOPE_MUTEX_STALE_SEC=10`, `SCOPE_MUTEX_ACQUIRE_BUDGET_MS=5000`) — short,
  fails CLOSED on timeout (`cmd_acquire` returns 2), used for a single scan-then-mkdir critical
  section.
- `.commit-lock` (`COMMIT_MUTEX_STALE_SEC=30`, `COMMIT_MUTEX_ACQUIRE_BUDGET_MS=15000`) — slightly
  longer, same fail-CLOSED-at-the-primitive-level shape, but its sole caller
  (`git-commit-scoped.sh:704-736`) catches that failure and **fails open**, printing a named
  WARNING and proceeding unserialized. This is the exact fail-open precedent the dispatch names
  and the one this task's new mechanism must mirror, not merely resemble.
- `.contention-claims/<path>` (`CONTENTION_CLAIM_STALE_SEC=1800`, zero wait budget) — a
  long-staleness, no-wait "first claim wins, refuse immediately" lease. Its 1800s staleness is
  useful precedent: this codebase already trusts a 30-minute staleness window for a
  long-running critical section, independent of `TASK_LOCK_STALE_MIN`'s own 30-minute default
  for task locks.

**Holder-identity and liveness machinery already exists and needs no new invention.**
`resolve_session_pid()` (`task-lock.sh:525`) resolves a pid (+ `pid_source`) for the *current*
process without requiring a passed-in session id. `session_liveness()` (`task-lock.sh:1653`)
gives a three-way verdict (`dead-pid` / `stale-heartbeat` / `pid-alive`, plus `corrupt` and
`undeterminable`) by combining a `kill -0` liveness check with a heartbeat-age threshold —
exactly the "stale or crashed holder must not deadlock" property the dispatch requires, and
exactly the "say so with the holder's identity" observability property, once the holder's pid/
session id is written into the mutex directory at acquire time (as `.commit-lock/owner` already
does, read back by `cmd_commit_acquire`'s own timeout branch at lines 1296-1299).

**Neither `verify-deploy.sh` nor `tests/run-all.sh` currently accepts a `session_id` argument.**
Both have an `sh -c`-shellable identity story already, though: `resolve_session_pid()` needs
nothing but the calling process's own pid. The CLI-subcommand design below follows
`commit-acquire`'s existing contract — it takes a `session_id` string positionally (opaque to
the mutex, used only for the owner-identity file and log lines) — so a caller that has no
`/orchestrate` session id on hand can pass any stable string (e.g. `"pid-$$"`); nothing in the
mutex's own correctness depends on the string's shape.

**The nested-invocation guard pattern is already proven twice, independently, in exactly the
shape this task needs.** `tests/run-all.sh:260-263` (`RUN_ALL_NESTED`) and
`verify-deploy.sh:404-412` (`VERIFY_DEPLOY_NESTED`) are structurally identical: check an inherited
env var, force serial behaviour if already nested, export the flag (idempotently) for the
remainder of the process so a further level of nesting also degrades correctly. The
`COMMIT_MUTEX_HELD` reentrancy flag (`task-lock.sh`'s top-of-file comment, lines 60-73;
consumed at `git-commit-scoped.sh:725-726`) is the same idea applied to an actual mutex rather
than a job-count cap: an inherited flag means "run as guest, no nested acquire."　The new
mechanism composes all three: a truly nested gate run (Gate 8 → `run-all.sh`, or
`run-all.sh` → a suite that shells back into `verify-deploy.sh`) must never register as a second
competing session, and the existing `RUN_ALL_NESTED`/`VERIFY_DEPLOY_NESTED` exports are already
set at exactly the right point (before any gate-lock acquisition would happen) to detect this for
free.

**Gate 8 is the correct, narrow scope for the lock — not the whole `verify-deploy.sh` run.**
`verify-deploy.sh`'s own `--skip-slow` documentation (header, lines 59-65) states Gate 8 costs
"117.9s of the ~2.8min total run" under idle conditions — the dominant share, and the only gate
named in the measured contention evidence. `gate8_run()` (`verify-deploy.sh:958-994`) is a
single, self-contained function already structured so that the one costly operation
(`run_all_output=$(... bash run-all.sh ...)` at line 980) is a single, clearly bounded
statement — the natural acquire/release bracket. Locking the entire `verify-deploy.sh` process
instead would needlessly serialize 22 cheap, independent gates that were never the problem.

**`orchestrate-batch-gate.sh` requires no change and is automatically composable.** It calls
`verify-deploy.sh` indirectly via `deploy_findings_snapshot` (`lib/deploy-baseline-lib.sh`), so a
lock placed inside `gate8_run()` is transparently inherited by every existing caller, including
this one, with zero changes to the batch-gate script itself.

**Project-root scoping is already solved and should be reused verbatim.**
`task-lock.sh:226` resolves `PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"` and every named
mutex lives under `$PROJECT_ROOT/specs/...`. A new `.gate-lock` mutex following the identical
pattern is automatically scoped to one repository's own `specs/` tree, so two unrelated
checkouts on the same host never collide — no new resolution logic needed.

### External Resources

Not consulted — this is a self-contained, already-proven-in-this-repository mechanism; the
dispatch itself states "nothing new needs inventing," which the codebase reading above confirms.

## Decisions

1. **Lease, not pure advisory — but a bounded one, with mandatory fail-open on budget
   exhaustion.** Pure advisory coordination (register intent, let the caller choose) satisfies
   "cannot deadlock" and "fail-open" trivially but does not, by itself, stop two batteries from
   running concurrently — which is this task's entire stated purpose (the load-average-39.91,
   18-concurrent-processes evidence). A pure exclusive lease with an unbounded or very long wait
   risks becoming itself indistinguishable from a hang, the precise symptom this task exists to
   fix, and a budget-exhausted lease that then *refuses* violates the explicit "never fail
   closed" requirement. The synthesis — bounded wait, then unconditionally proceed unserialized
   with a loud, named warning — is the only option that satisfies every stated property
   simultaneously, and it is exactly `git-commit-scoped.sh`'s already-accepted posture for
   `.commit-lock`, applied to a longer-running critical section.
2. **New CLI surface: `task-lock.sh gate-acquire <session_id> [stale_sec] [budget_ms]` /
   `gate-release <token>`**, siblings of `commit-acquire`/`commit-release` (same token-ownership
   contract: a `session_id:pid:claimed_epoch` token, owner file written at acquire, verified at
   release, mismatch warns-and-skips rather than deleting a successor's claim). The primitive
   itself keeps today's convention of failing CLOSED (return 2) on timeout, naming the current
   holder's session/pid read from the owner file — fail-OPEN is a caller decision, applied
   identically at both of the call sites below, never baked into the primitive itself (consistent
   with how `.commit-lock`'s own fail-open posture lives in `git-commit-scoped.sh`, not in
   `task-lock.sh`).
3. **Two call sites, not one**: `tests/run-all.sh`'s top level (acquire before suite discovery,
   release via an `EXIT` trap, skipped entirely when `RUN_ALL_NESTED` was already `1` at entry)
   and `verify-deploy.sh`'s `gate8_run()` (acquire immediately before the `run-all.sh` invocation
   at line 980, release immediately after, skipped entirely when `VERIFY_DEPLOY_NESTED` was
   already `1` at entry, and conditioned on Gate 8 actually being selected — i.e. placed after
   `SKIP_SLOW`/`--only-gate`/`--max-cost` resolution, so a `--skip-slow` or Gate-8-excluding
   invocation never touches the lock at all). This directly satisfies the "composable with
   verify-deploy.sh's existing selection surface" requirement rather than requiring new
   selection-surface code.
4. **Nested-invocation handling reuses three existing mechanisms, composed, rather than a new
   fourth one**: (a) `RUN_ALL_NESTED`/`VERIFY_DEPLOY_NESTED` already being `1` at a script's own
   entry is itself sufficient reason to skip gate-lock acquisition entirely (this process did not
   originate the costly operation, an outer process did); (b) a new, additive reentrancy flag
   (name to be finalized at plan time, e.g. `GATE_MUTEX_HELD`) exported by whichever of the two
   call sites acquires the real mutex first, mirroring `COMMIT_MUTEX_HELD` exactly, so that when
   `verify-deploy.sh`'s `gate8_run()` holds the lock and shells into `run-all.sh`, `run-all.sh`'s
   own (otherwise-independent) acquisition attempt sees the inherited flag and runs as guest; (c)
   the token/owner-file ownership check already present in `commit-release`'s pattern, reused
   verbatim for `gate-release`, so a stale-reclaimed lock's original holder can never delete a
   successor's claim on (delayed) release.
5. **Observability requires one additive change to `acquire_named_mutex`'s wait loop.** Today's
   loop (`task-lock.sh:627-654`) waits silently; this is fine for `.scope-lock`/`.commit-lock`'s
   sub-15-second budgets but would itself look like a hang over a multi-minute gate-lock wait —
   exactly the symptom this task exists to eliminate, one layer down. Recommend a new, optional
   parameter (emitted only when a caller opts in, e.g. by passing a non-empty label) that prints a
   periodic `[gate-lock] waiting <Ns> for session=<holder_session> pid=<holder_pid> (<command>)...`
   line, reading the holder identity from the owner file written at acquire time. This keeps
   `.scope-lock`/`.commit-lock`/`.contention-claims` byte-for-byte unaffected (they simply never
   pass the new parameter).
6. **Staleness and wait-budget sizing are Plan-phase numeric decisions, not Research-phase
   ones, but are bounded by measured evidence already in hand**: the worst observed single run
   was 650s-plus-two-retries under contention; the only existing long-staleness precedent in this
   codebase (`CONTENTION_CLAIM_STALE_SEC=1800`) and `TASK_LOCK_STALE_MIN`'s own 30-minute default
   independently converge on the same order of magnitude. Recommend the plan size
   `GATE_MUTEX_STALE_SEC` and `GATE_MUTEX_ACQUIRE_BUDGET_MS` (both env-var overridable, mirroring
   every existing mutex constant's own override convention) in that neighbourhood, with the
   acquire budget no larger than the staleness window — a waiter should never wait longer than it
   would take to simply reclaim a genuinely dead holder.
7. **Rejected alternative: "reuse the sibling's result."** Unsafe to generalize: two concurrent
   sessions can have different `modified_files`/`file_scope`, so one session's gate verdict is
   not provably valid for the other's working tree without the same kind of attribution machinery
   `orchestrate-batch-gate.sh` already builds for the *single-session, single-batch* case — and
   even that mechanism re-confirms findings with a second snapshot rather than trusting one
   capture outright. Cross-session reuse would need an equivalent confirm-and-attribute layer
   that does not exist today; building it is a materially larger, separate undertaking, not a
   cheap add-on to this task.
8. **Rejected alternative: "degrade to a narrower gate selection on contention" as the default
   remedy.** Composable as an opt-in caller choice (nothing here forecloses a future flag), but
   not the mechanism's own default behavior, because the dispatch's own verification bullet
   requires the final phase to declare the complete gate set with an explicit source-store
   target — an auto-degraded run on contention would silently fail to meet that bar on exactly
   the runs where contention is most likely (busy, multi-session periods).
9. **No `user_decision` is set.** The lease-vs-advisory question the dispatch asked to be settled
   is an engineering judgment resolvable from the evidence and existing patterns above, not a
   preference, external cost, or ambiguity requiring the user's own input.

## Recommendations

1. Add `gate-acquire`/`gate-release` subcommands to `task-lock.sh` (source-store path:
   `agent-system/extensions/core/scripts/task-lock.sh`), implemented as close siblings of
   `cmd_commit_acquire`/`cmd_commit_release`, backed by a new `.gate-lock` named-mutex family
   (`GATE_MUTEX_STALE_SEC`, `GATE_MUTEX_ACQUIRE_BUDGET_MS` constants) built on the existing
   `acquire_named_mutex`/`release_named_mutex` primitive — no new mutex engine.
2. Extend `acquire_named_mutex`'s wait loop with an optional, additive progress-reporting
   parameter so a multi-minute gate-lock wait prints the holder's identity periodically, leaving
   every existing caller's silent-wait behavior unchanged when the parameter is omitted.
3. Wire the acquire/release pair into `tests/run-all.sh`'s top level (full-script bracket, skipped
   when already `RUN_ALL_NESTED`) and into `verify-deploy.sh`'s `gate8_run()` (bracketing only the
   `run-all.sh` invocation, skipped when already `VERIFY_DEPLOY_NESTED` or when Gate 8 is not in
   the selected set), using a shared additive reentrancy export (e.g. `GATE_MUTEX_HELD`) so the
   nested `verify-deploy.sh` → `run-all.sh` call never double-acquires.
4. At both call sites, on `gate-acquire` timeout (exit 2), print a loud, holder-identifying
   WARNING and proceed to run the gate unserialized anyway — mirroring
   `git-commit-scoped.sh:734`'s exact posture and its explicit statement of what the fail-open
   worst case is (contention persists for this run) and is not (verification silently skipped or
   corrupted).
5. Document the finished contract in `context/patterns/batch-orchestration-guardrails.md`,
   placed alongside the existing admission-layer and gate-catalogue material — classify it using
   the file's own Blocking-vs-Advisory criterion (this guardrail is neither: it never refuses
   dispatch, it defers a cost-only operation with a mandatory fail-open escape) and its own
   Defer-Not-Fail / ordering-constraint-not-exclusion framing (the lock is a self-clearing
   ordering constraint — it clears the moment the holder releases, finishes, or goes stale,
   exactly like the existing `session_active` and held-lock rows in that file's Gate Catalogue).
6. Add exactly one cross-reference sentence to `context/standards/shell-script-testing.md`'s
   existing "Measurement discipline" section, pointing at the new
   `batch-orchestration-guardrails.md` section — per the dispatch's sequencing note, no
   substantive content there, since two sibling tasks are sequenced after this one against the
   same file.
7. Build the five required fixtures directly against the real mechanism (never a mock): (a) two
   concurrent full-battery invocations serialize rather than overlap (observable via start/finish
   timestamps written by each to a shared marker file, not via timing assertions); (b) a
   deliberately killed/stale holder is reclaimed, with the reap/stale-override branch
   demonstrably taken (log line assertion); (c) a `RUN_ALL_NESTED=1`-preset invocation never
   creates the `.gate-lock` mutex directory at all; (d) a forced-to-fail acquire (e.g. a stubbed
   `gate-acquire` returning 2) still yields a completed gate run with a real verdict and the
   WARNING line; (e) two genuinely concurrent sessions against identical repository state produce
   byte-identical `FINDING`/summary lines to a single serialized baseline run.
8. Take the required before/after wall-clock comparison with the 1-minute load average recorded
   at measurement time (per `shell-script-testing.md`'s own measurement-discipline standard) —
   deliberately under contention, not on an idle host, since contention is the condition under
   test.

## Context Extension Recommendations

None beyond what this task's own required documentation already covers: the new contract's home
is the existing `batch-orchestration-guardrails.md` admission-layer/gate-catalogue structure, and
the cross-reference lands in the existing `shell-script-testing.md` measurement-discipline
section — no undocumented topic surfaced during this research that calls for a new context file.

## Appendix

### Search queries / codebase exploration performed

- `grep -n "serialized\|gate 8\|run-all.sh\|only-gate\|skip-slow\|cost.class" scripts/verify-deploy.sh`
- `grep -n "RUN_ALL_NESTED\|PROJECT_ROOT" scripts/tests/run-all.sh`
- Read `scripts/task-lock.sh` acquire/release-mutex family (`acquire_named_mutex`,
  `release_named_mutex`, `cmd_scope_acquire/release`, `cmd_commit_acquire/release`,
  `cmd_claim_acquire/release`, `cmd_session_register/heartbeat/release/reap/list`,
  `resolve_session_pid`, `session_liveness`).
- `grep -n "fail-open\|FAIL_OPEN\|worst case" scripts/git-commit-scoped.sh`, then read the
  `.commit-lock` acquire/release block (lines ~704-736) in full.
- Read `scripts/orchestrate-batch-gate.sh` in full (confirmed its per-batch, not cross-session,
  scope).
- Read `context/patterns/batch-orchestration-guardrails.md`'s admission-layer, Blocking-vs-
  Advisory, Gate Catalogue, and Defer-Not-Fail sections.
- Read `context/standards/shell-script-testing.md`'s "Measurement discipline" section (the
  cross-reference target named by the dispatch).
- Confirmed via `.claude-extensions.json` / directory listing that the source store is
  `agent-system/extensions/core/**`, matching the dispatch's own instruction.
