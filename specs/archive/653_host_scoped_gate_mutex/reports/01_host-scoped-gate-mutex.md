# Research Report: Task #653

**Task**: 653 - Give the gate mutex a host-scoped form
**Started**: 2026-11-19T08:20:00Z
**Completed**: 2026-11-19T08:26:40Z
**Effort**: Medium (one new lock-root resolution helper, one parameterization of an existing
primitive, one new opt-in subcommand pair, three wiring call sites, new cross-directory test
coverage)
**Dependencies**: None (hard prerequisite `full_gate_verification_ceiling_and_stall` is
COMPLETED and its posture ruling is read, not re-litigated, below)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/task-lock.sh`,
  `agent-system/extensions/core/scripts/tests/run-all.sh`,
  `agent-system/extensions/core/scripts/verify-deploy.sh`,
  `agent-system/extensions/core/scripts/deploy-headless.sh`,
  `agent-system/extensions/core/scripts/deploy-root-guard.sh`,
  `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh`,
  `agent-system/extensions/core/scripts/hooks/tts-notify.sh`,
  `agent-system/extensions/core/scripts/tests/test-gate-lock.sh`,
  `agent-system/extensions/core/scripts/tests/test-task-lock-liveness.sh`,
  `agent-system/extensions/core/scripts/test-task-lock-reap.sh`
- Live-host measurement: `XDG_RUNTIME_DIR`, `/run/user/$UID`, `/tmp` filesystem/mount/permission
  probes; `man pam_systemd`; baseline test runs of the three cited existing suites
- `specs/610_full_gate_verification_ceiling_and_stall/reports/01_gate-verification-ceiling-and-stall.md`
  (the hard-prerequisite posture ruling, read for citation, not re-derived)
**Artifacts**:
- This report: `specs/653_host_scoped_gate_mutex/reports/01_host-scoped-gate-mutex.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Re-derived and confirmed the dispatch's structural finding directly from source: all four cited
  lock call sites (`cmd_scope_acquire`, `cmd_commit_acquire`, `cmd_gate_acquire` in
  `task-lock.sh`, plus the hand-rolled `.deploy-lock` mutex in `deploy-headless.sh`) resolve their
  mutex directory as `$PROJECT_ROOT/specs/<name>` (or `$TARGET/specs/.deploy-lock`) — every one
  is repo-scoped by construction, exactly as the dispatch states.
- The gate layer's own single-flight bracket has **three** independent `gate-acquire` call
  sites, not one: `tests/run-all.sh`'s top level, and **two** inside `verify-deploy.sh`
  (`gate8_run()` and a second gate-8-sibling battery, referred to below as "Gate 31"). Deliverable
  4 ("wire the gate layer's own single-flight bracket") must account for all three or leave one
  entry point repo-scoped-only, which would silently reopen exactly the cross-repo blind spot
  this task exists to close for that one path.
- The `acquire_named_mutex` primitive that backs `.scope-lock`/`.commit-lock`/`.gate-lock` uses
  `mkdir`-based atomicity and purely time-elapsed staleness reclaim — it never calls `flock`, and
  it deliberately has **no PID-liveness reclaim path** (a prior attempt at one was reverted; see
  Findings). The dispatch's "whether flock behaves differently" question therefore does not
  constrain this design, and the dispatch's "same liveness logic... already uses for its
  repo-scoped locks" premise needs one correction: that PID-liveness logic (`kill -0`,
  `session_liveness()`) belongs to a *different* mechanism (the per-task `.lock/holder.json`
  family), not to the named-mutex family this task extends — see Findings for the precise scope
  split and why it does not block this design.
- A documented, already-shipping precedent for the exact `${XDG_RUNTIME_DIR}` fallback pattern
  exists in this codebase (`hooks/tts-notify.sh`), and live measurement on this host confirms
  `XDG_RUNTIME_DIR=/run/user/$UID` is `tmpfs`, mode `0700`, user-owned, and — per `pam_systemd(8)`
  — created at first login and removed at final logout, so an abandoned host-scoped lock there is
  reclaimed by the OS independent of any staleness arithmetic this script adds.
- Recommended shape: parameterize `acquire_named_mutex`/`release_named_mutex` with an explicit
  base-directory argument (defaulting every existing call site to `$PROJECT_ROOT/specs`,
  byte-identical to today), add one new `resolve_host_lock_root()` helper with the three-tier
  fallback the dispatch specifies plus a test-only override hook, and add one new opt-in
  subcommand pair (`gate-acquire-host`/`gate-release-host`) that calls the same primitive against
  the host root — no second mutex implementation, no change to any existing default.
- Baseline-confirmed non-regression: `test-task-lock-liveness.sh` (15/15), `test-task-lock-reap.sh`
  (6/6), and `test-gate-lock.sh` (27/27) all pass cleanly today against the unmodified source
  store, run at authoring time as the "must keep passing" baseline the dispatch names.

## Context & Scope

This task was researched from `agent-system/extensions/core` — the source-store edit target the
dispatch names — never from a deployed `.claude/**` tree. Scope is exactly what the dispatch's
"WHAT THIS RECORD OWNS" section states: the host-scoped locking *primitive* and its *contract*
(root resolution, opt-in form, fail-open posture, binds-only-cooperating-callers limit, and
coverage). Explicitly out of scope and not addressed here: any consumer repository's own harness
(a different repository, inaccessible from this session), and the `.gate-lock` *posture* question
(fail-open vs. fail-closed, acquire budget, staleness), which
`full_gate_verification_ceiling_and_stall`'s report 01 already rules on and which this record
inherits rather than re-opens.

Constraints carried into every recommendation below: fail-open on lock-root trouble (a guard that
cannot acquire must never block the work it guards); no change to any existing call site's
default scope; no second mutex implementation — every design here is an additive parameterization
of `acquire_named_mutex`/`release_named_mutex`, never a parallel locking library.

## Findings

### Codebase Patterns

**The four lock call sites, re-derived (dispatch's required pre-design step)**:

| Call site | File:line (approx.) | Resolved directory |
|---|---|---|
| `cmd_scope_acquire` / `acquire_scope_mutex` | `task-lock.sh:765-768`, `1344-1346` | `$PROJECT_ROOT/specs/.scope-lock` |
| `cmd_commit_acquire` / `acquire_commit_mutex` | `task-lock.sh:786-789`, `1411-1413` | `$PROJECT_ROOT/specs/.commit-lock` |
| `cmd_gate_acquire` / `acquire_gate_mutex` | `task-lock.sh:816-819`, `1477-1479` | `$PROJECT_ROOT/specs/.gate-lock` |
| deploy-lock (standalone, hand-rolled, not via `task-lock.sh`) | `deploy-headless.sh:270-306` | `$TARGET/specs/.deploy-lock` |

All four are the same shape: an `mkdir`-exclusive directory created directly under a
repository-relative `specs/` path. `PROJECT_ROOT` in `task-lock.sh` is resolved via
`common_repo_root "$SCRIPT_DIR" 2` (a fixed two-levels-up walk from the deployed script's own
location, guarded by `deploy-root-guard.sh` against running from the source store); `$TARGET` in
`deploy-headless.sh` is that script's own deploy-target argument. Neither has any notion of "the
same host, a different repository" — confirming the dispatch's structural finding directly from
source rather than assuming it.

**The named-mutex primitive's actual atomicity and reclaim mechanism** (`task-lock.sh:695-745`,
`acquire_named_mutex`): the critical section is claimed via a bare `mkdir "$mutex_dir"` (POSIX
atomic exclusive create — no `flock` anywhere in this function or its two siblings
`release_named_mutex`/the three wrapper pairs). Staleness reclaim is **purely elapsed-time**: the
acquiring process writes `claimed_at` and a holder-declared `stale_sec` into the mutex directory,
and a waiter reclaims once `now - claimed_at > stale_sec`, via `rm -rf` plus a retry — there is no
`kill -0`/PID check anywhere in this path. The file's own inline comment (lines 674-694) documents
*why*: a PID-liveness fast path was prototyped and reverted, because the pid recorded for an
`{scope,commit,gate}-acquire` CLI invocation is always the short-lived acquiring subprocess's own
`$$` (e.g. `token=$(bash task-lock.sh gate-acquire ...)`), which exits within milliseconds of a
successful acquire while the real long-lived holder (`verify-deploy.sh` itself) is still running —
a dead-pid check against that recorded pid would misclassify a live, working holder as dead.
`test-gate-lock.sh`'s own serialization case caught this directly when the fast path was tried.

This resolves the dispatch's phrasing about "the same liveness logic task-lock.sh already uses for
its repo-scoped locks" with one necessary correction: that PID-liveness/`session_liveness()`
machinery (`kill -0` at `task-lock.sh:1002` and `:1305`, `session_liveness()` at `:1839`) belongs
to a **structurally separate** mechanism — the per-task `.lock/holder.json` family driven by
`cmd_acquire`/`cmd_reap`/`cmd_check` (the subject of `test-task-lock-liveness.sh` and
`test-task-lock-reap.sh`) — not to the `.scope-lock`/`.commit-lock`/`.gate-lock` named-mutex
family this task extends. The two mechanisms are independent: different directories, different
staleness constants, different reclaim logic, no shared code path. A host-scoped gate mutex built
on `acquire_named_mutex` therefore correctly inherits **time-based-only** reclaim, identical in
kind to today's repo-scoped `.gate-lock` — not a regression, and not a design question this task
needs to resolve differently from what `.gate-lock` already does.

**Three gate-acquire call sites, not one**: `grep -rln "gate-acquire\b"` across
`agent-system/extensions/core/scripts` (excluding test files) finds `tests/run-all.sh` (one call,
`run-all.sh:637`) and `verify-deploy.sh` (two calls, `:1427` inside `gate8_run()` and `:1782`
inside a second gate-8-sibling battery below it, both guarded identically: skip if
`--only`/narrowed, skip if nested, run as guest if `GATE_MUTEX_HELD=1` is already inherited,
otherwise acquire-and-export). Deliverable 4's "wire the gate layer's own single-flight bracket"
should be read as covering all three identically-shaped guard blocks, not just `run-all.sh`'s.

**Existing `${XDG_RUNTIME_DIR}`-with-fallback precedent**: `hooks/tts-notify.sh:46` already does
`COOLDOWN_FILE="${XDG_RUNTIME_DIR:-/tmp}/claude-tts-cooldown-${UID:-0}-${WEZTERM_PANE:-nopane}"` —
a two-tier fallback (skips `/run/user/$UID` as an explicit middle tier, going straight to `/tmp`)
that already demonstrates the UID-qualified-filename technique needed to keep a `/tmp` fallback
safe across multiple OS users on one host. The dispatch's required three-tier chain
(`$XDG_RUNTIME_DIR` -> `/run/user/$UID` -> documented temp-dir fallback) is one tier more
conservative than this precedent, closing the gap for a host where `XDG_RUNTIME_DIR` happens to be
unset in the calling shell (e.g. certain non-interactive/cron/detached invocations) but the
systemd/elogind-managed `/run/user/$UID` directory nonetheless exists and is usable.

**Live-host measurement of the lock-root candidates** (deliverable 1's required settling, with
evidence rather than assumption):
- `XDG_RUNTIME_DIR=/run/user/1000`, mounted `tmpfs`, mode `0700`, owned `benjamin:users` — a
  per-OS-user, not cross-user-shared, directory. `mount` confirms `tmpfs on /run/user/1000 type
  tmpfs (...,mode=700,uid=1000,gid=100)`.
- `man pam_systemd` (System Administration section) states `$XDG_RUNTIME_DIR` "is automatically
  created the first time a user logs in and removed on the user's final logout," and explicitly
  warns applications "must be able to deal with stale files" across a logout/login cycle. Two
  consequences for this design: (a) on a systemd/elogind host this directory's *lifetime is
  session-scoped, not reboot-scoped* — it is torn down at final logout (and trivially never
  survives a reboot either, since `tmpfs` is memory-backed) which reclaims an abandoned lock
  there for free, independent of any `stale_sec` arithmetic; (b) the man page's own "must deal
  with stale files" warning is direct documentation-level support for keeping this script's own
  staleness-reclaim logic active rather than assuming OS-level cleanup makes it redundant — a
  session can log out and back in with the SAME `XDG_RUNTIME_DIR` path reused by a new,
  unrelated login, in principle leaving behind files from the prior session if cleanup lagged.
- `/tmp` on this host is `ext2/ext3`-backed (not `tmpfs`), mode `drwxrwxrwt` (world-writable,
  sticky bit set) — the sticky bit prevents one user from deleting/renaming another user's
  subdirectory, but does **not** prevent a hostile user from pre-creating a same-named directory
  before the legitimate user's own `mkdir` runs. Any documented temp-dir fallback that lands in
  `/tmp` needs the lock-root *directory name itself* to be UID-qualified (mirroring
  `tts-notify.sh`'s own technique) so two different OS users can never contend over, or spoof,
  the same path; a resolver should additionally not blindly trust a pre-existing fallback
  directory it did not itself just create without confirming it is owned by the resolving user.
  `systemd-tmpfiles`'s shipped `/usr/lib/tmpfiles.d/tmp.conf` on this host governs periodic
  age-based cleaning of `/tmp`, not reboot-clearing — a `/tmp`-rooted fallback is the most durable
  of the three tiers across a reboot, not the least, which is a reasonable property for a
  "last-resort fallback" tier to have as long as the UID-qualification above holds.

**`runtime-file-patterns.sh`'s ephemeral-file class does not need a new entry**: this lib
(`lib/runtime-file-patterns.sh`) is the single source of truth for which `specs/`-rooted
ephemeral files/directories are gitignored and probed by `check-runtime-file-tracking.sh`, and
already lists `.gate-lock`, `.scope-lock`, `.commit-lock`, and `.deploy-lock` by name (lines
116-263) precisely because all four live inside the repository tree under `specs/`. A host-scoped
lock root lives entirely outside any repository (`$XDG_RUNTIME_DIR`/`/run/user/$UID`/a `/tmp`
fallback) and is therefore never a candidate for this registry — no change to this file is implied
or needed by this task, which is worth stating explicitly so the plan/implementation phase does
not spend time looking for a required update here.

**Non-regression baseline, measured at authoring time**: ran all three suites the dispatch names
or that cover the mechanism being extended, against the unmodified source store —
`test-task-lock-liveness.sh` (15/15 passed), `test-task-lock-reap.sh` (6/6 passed), and
`test-gate-lock.sh` (27/27 passed, including its existing same-`$WORKDIR` "serialization" and
"non-vacuousness" cases). These three establish the exact green baseline deliverable 1's "must
keep passing" instruction refers to.

**The existing double-start coverage is same-directory and cannot distinguish scope**:
`test-gate-lock.sh`'s "case: serialization" (lines ~121-159) launches both concurrent fixture
invocations via `cd "$WORKDIR" && bash "$FIXTURE_RUNNER" ...` against the *same* `$WORKDIR` acting
as the one fixture repository (observed directly in this run's output, e.g.
`/tmp/tmp.if5e9qstwQ/specs/.gate-lock`). This is exactly the dispatch's "same-repository
double-start demo" that "cannot distinguish a host-scoped guard from the repo-scoped one it
replaces" — confirmed, not merely asserted, by reading the fixture setup.

### External Resources

None consulted; this is a pure codebase-mechanics question with no external library or API
surface, and the dispatch is explicit that research must be evidence-grounded against this
repository's own primitive rather than general locking literature.

## Decisions

1. The host-scoped form will be built as an additive parameterization of
   `acquire_named_mutex`/`release_named_mutex` (a new leading base-directory argument, defaulting
   every existing call site to `$PROJECT_ROOT/specs` unchanged), not a new function with
   duplicated mkdir/staleness/wait-budget logic — satisfies the "no second mutex implementation"
   hard constraint directly from the primitive's own existing shape.
2. The host-scoped acquire reuses `GATE_MUTEX_STALE_SEC`/`GATE_MUTEX_ACQUIRE_BUDGET_MS`/
   `GATE_MUTEX_PROGRESS_INTERVAL_S` unchanged — no new budget/staleness constants are introduced
   for the host-scoped path. This is a direct consequence of the territory edge filed against
   `full_gate_verification_ceiling_and_stall`'s report 01, Decision 3, which already rules
   `.gate-lock`'s fail-open posture "kept as-is" and names this very task's territory edge as the
   inheritor of that ruling rather than a re-litigation of it.
3. PID-liveness reclaim is deliberately **not** added to the host-scoped (or repo-scoped)
   named-mutex family as part of this task — it remains purely time-elapsed, matching
   `.gate-lock`'s existing behavior exactly, per Findings' documented rationale for why a
   PID-liveness fast path is unsound for this specific primitive shape (the recorded pid is
   always the short-lived acquiring subprocess, never the long-lived holder).
4. `lib/runtime-file-patterns.sh` is not touched by this task: the host-scoped lock root lives
   outside the repository tree entirely and is structurally out of scope for that `specs/`-rooted
   ephemeral-file registry.
5. All three existing `gate-acquire` call sites (`run-all.sh`, and both of `verify-deploy.sh`'s
   gate-battery guards) are treated as in scope for deliverable 4's wiring, not just the first one
   found — leaving one on repo-scope-only would reopen the cross-repo blind spot for that one
   entry point.

## Recommendations

1. **Lock-root resolver**: add `resolve_host_lock_root()` to `task-lock.sh` implementing the
   dispatch's required three-tier chain — `$XDG_RUNTIME_DIR` (if set and writable) ->
   `/run/user/$UID` (if it exists and is writable) -> a documented, UID-qualified `/tmp` (or
   `$TMPDIR`) fallback created with mode `0700` and an ownership check on any pre-existing
   directory at that path before trusting it (mirroring `tts-notify.sh`'s UID-in-filename
   technique, hardened against the pre-creation hazard Findings identifies for the world-writable
   `/tmp` tier). On exhausting all three tiers, return a failure the caller treats exactly like any
   other `acquire_named_mutex` budget-exhaustion failure — i.e. fail open, per the hard constraint.
2. **Primitive parameterization**: give `acquire_named_mutex`/`release_named_mutex` an explicit
   base-directory parameter (e.g. a new leading argument, or a `scope_root` positional before
   `mutex_dirname`) so a caller can pass `resolve_host_lock_root()`'s output instead of the
   implicit `$PROJECT_ROOT/specs`. Every existing call site passes the literal value it already
   implicitly used, preserving byte-for-byte default behavior — the explicit requirement of
   deliverable 2.
3. **New opt-in subcommand pair, named explicitly**: add `gate-acquire-host`/`gate-release-host`
   (or an equivalent explicitly-named verb pair — the exact string is a plan-level naming choice,
   not research-blocking) as siblings to `cmd_gate_acquire`/`cmd_gate_release`, following the
   file's existing one-verb-pair-per-mutex-family convention rather than overloading the existing
   verbs with a silent flag. Document both the new subcommand and this exact repo-scoped-stays-
   default guarantee in the top-of-file usage block, per deliverable 2's explicit naming
   requirement.
4. **A second, host-scope reentrancy flag is needed**: today's single `GATE_MUTEX_HELD` flag
   marks "an outer holder already owns `.gate-lock`" and suppresses a nested acquire (used by both
   `run-all.sh` and `verify-deploy.sh`, and relevant to `verify-deploy.sh`'s Gate 8 recursing into
   `run-all.sh`'s own battery, per `test-gate-lock.sh`'s header comment on exactly that scenario).
   Deliverable 4 asks to keep the repo-scoped lock as an *inner* lock under a *new outer*
   host-scoped lock; without a distinct flag (e.g. `GATE_MUTEX_HOST_HELD`), a process that already
   holds the host-scoped lock and then recurses into a child invocation would attempt — and
   correctly fail or needlessly wait on — a second host-scoped acquire for the same critical
   section it is already inside. Mirror the existing flag's export/unset discipline exactly, kept
   fully distinct from `GATE_MUTEX_HELD` (never conflated, following the same reasoning the file's
   header comment already gives for why `GATE_MUTEX_HELD`/`COMMIT_MUTEX_HELD`/`SCOPE_MUTEX_HELD`
   are three separate flags rather than one shared one).
5. **Wiring order at each of the three call sites**: acquire host-scoped (outer) first, then
   acquire repo-scoped (inner, today's existing call, unchanged) — release in the reverse order.
   This nests cleanly inside each of the three existing guard blocks found in Findings without
   restructuring their guest/nested/narrowed-run skip logic, which should also be left unchanged.
6. **Test-only override hook, required for isolation**: `resolve_host_lock_root()` must consult a
   dedicated override environment variable first (e.g. `TASK_LOCK_HOST_ROOT_OVERRIDE`),
   documented as test-only and never meant for production use. No existing override convention
   for a host-level (non-`PROJECT_ROOT`-relative) path exists anywhere in `task-lock.sh` or its
   test suites today — every existing isolation technique (`deploy-root-guard.sh`'s two-levels-up
   walk, `common_test_workdir_init`'s `mktemp -d`) achieves isolation by relocating the *script
   copy* under a fake repo root, which cannot isolate a path resolved from real OS environment
   variables (`$XDG_RUNTIME_DIR`, `$UID`) or real OS paths (`/run/user/$UID`). Without this hook, a
   test cannot safely exercise the host-scoped acquire without risking collision with the actual
   developer/CI host's own runtime directory, nor can two instances of the new cross-directory
   test (recommendation 7) run concurrently in CI. This is new testability infrastructure this
   task introduces, not something it can borrow from an existing pattern.
7. **New coverage, as the dispatch requires**:
   - A cross-directory double-start test: two **separate** fixture repository trees (two
     distinct `mktemp -d` roots, each with its own `specs/` and a copied `run-all.sh`/
     `task-lock.sh`, following `test-gate-lock.sh`'s existing fixture-construction technique),
     both pointed at one **shared** `TASK_LOCK_HOST_ROOT_OVERRIDE` directory. Prove: (a) two
     concurrent full-battery invocations from the two *different* working directories, using the
     host-scoped acquire, do not overlap (the actual regression this task fixes); (b) the same
     two invocations using only the pre-existing repo-scoped acquire — i.e. this test run against
     the unmodified primitive, or with the host form not engaged — **do** overlap, proving the
     new test is non-vacuous and that a same-repo double-start demo genuinely could not have
     caught this.
   - The absent/unwritable lock-root degradation path: exercise `resolve_host_lock_root()` with
     `XDG_RUNTIME_DIR` unset, `/run/user/$UID` absent or made unwritable (`chmod 000` on a fixture
     stand-in), and the final fallback tier itself unwritable, confirming the acquire call fails
     open (battery still runs, real verdict, named `WARNING:` line) at every degradation step —
     mirroring `test-gate-lock.sh`'s existing "case: fail-open" pattern for the no-deployed-
     `task-lock.sh` scenario.
8. **Contract text, verbatim obligations from the dispatch (deliverable 3)**: the new subcommand's
   usage-block/doc-comment must state, prominently and without hedging, that the guard binds only
   *cooperating* callers — a process that never calls `gate-acquire-host` (a hand-run command, an
   editor task, another tool invoking `run-all.sh`/`verify-deploy.sh` by a path that bypasses the
   guard) is not serialized by it, and the mutex's role is honestly "cooperating callers
   serialize," never "contamination is impossible."

## Risks & Mitigations

- **Risk**: a `/tmp`-fallback lock-root directory name collides across two different OS users on
  a shared multi-user host. **Mitigation**: UID-qualify the fallback directory name (Recommendation
  1) and verify ownership of any pre-existing directory at that path before using it, rather than
  trusting `mkdir`'s success/failure alone.
- **Risk**: a recursive invocation (Gate 8 recursing into `run-all.sh`, as already exercised by
  `test-gate-lock.sh`'s fixture header note) attempts a nested host-scoped acquire and
  self-deadlocks or needlessly waits out its own outer holder's staleness window.
  **Mitigation**: the distinct `GATE_MUTEX_HOST_HELD` reentrancy flag (Recommendation 4), exported
  and checked exactly as `GATE_MUTEX_HELD` already is.
- **Risk**: introducing a new base-directory parameter to `acquire_named_mutex`/
  `release_named_mutex` silently changes an existing call site's resolved directory.
  **Mitigation**: every existing call site must pass the literal `$PROJECT_ROOT/specs` it used
  implicitly before, verified by the existing 15+6+27 = 48 passing baseline cases (Findings)
  continuing to pass unmodified after the parameterization — a regression here would surface as a
  baseline-test failure, not a silent behavior change.
- **Risk**: a test exercising the real host-scoped acquire against the genuine `$XDG_RUNTIME_DIR`
  collides with a real concurrent developer/CI session on the same machine.
  **Mitigation**: the mandatory test-only override hook (Recommendation 6) — no new test should
  ever call `resolve_host_lock_root()` without setting it.
- **Risk**: `GATE_MUTEX_ACQUIRE_BUDGET_MS` exceeding `GATE_MUTEX_STALE_SEC*1000` for the host form
  (the file's own documented invariant for the repo-scoped constants) if a future change tunes one
  without the other. **Mitigation**: Decision 2 above — reuse the identical constants for the host
  form, so the existing invariant (already satisfied: 600000 <= 1800*1000) continues to hold by
  construction rather than needing a second check.

## Context Extension Recommendations

- **Topic**: host-scoped lock-root resolution pattern.
- **Gap**: `context/patterns/task-lock.md` (the canonical spec this file's own header points to)
  documents the repo-scoped named-mutex family in depth but has no section for a host-scoped
  variant, its fallback chain, or its test-isolation override convention — because none exists yet.
- **Recommendation**: once this task's plan/implementation lands the new resolver and subcommand
  pair, extend `context/patterns/task-lock.md` with a "Host-Scoped Mutex" section covering the
  three-tier root resolution, the `GATE_MUTEX_HOST_HELD` reentrancy flag, the
  binds-only-cooperating-callers limit, and the test-only override variable — mirroring the depth
  already given to the repo-scoped family's own sections (staleness, same-session re-entry,
  fail-open rationale).

## Appendix

**Search queries / commands used**:
- `find agent-system/extensions/core/scripts -iname "*task-lock*" -o -iname "*gate-lock*"`
- `grep -n "deploy-lock\|deploy_lock\|DEPLOY_LOCK" task-lock.sh verify-deploy.sh deploy-headless.sh`
- `grep -n "^cmd_gate_acquire\|^cmd_gate_release\|^cmd_scope_acquire\|^cmd_commit_acquire\|acquire_named_mutex \"\.\|GATE_MUTEX\|SCOPE_MUTEX\|COMMIT_MUTEX" task-lock.sh`
- `grep -n "gate-acquire\|gate-release\|GATE_MUTEX_HELD\|gate_mutex" verify-deploy.sh tests/run-all.sh`
- `grep -rln "gate-acquire\b" .` (excluding test files) across `agent-system/extensions/core/scripts`
- `grep -rn "XDG_RUNTIME_DIR" agent-system/`; `grep -rln "flock" agent-system/extensions/core/scripts/*.sh agent-system/extensions/core/scripts/lib/*.sh`
- Live host probes: `echo $XDG_RUNTIME_DIR`; `stat -f -c '%T' "$XDG_RUNTIME_DIR" /tmp`; `mount | grep -E "run/user|/run "`; `stat -c '%a %U:%G' "$XDG_RUNTIME_DIR"`; `man pam_systemd`; `systemd-tmpfiles --cat-config`; `ls -ld /tmp`
- Baseline suite runs: `bash tests/test-task-lock-liveness.sh`, `bash test-task-lock-reap.sh`,
  `bash tests/test-gate-lock.sh` (all against the unmodified source store)
- `jq -r '.active_projects[] | select(.project_number==610) | ...' specs/state.json` (confirming
  the hard-prerequisite task's completion status before citing its ruling)

**References**:
- `agent-system/extensions/core/scripts/task-lock.sh:641-833` (named-mutex family: constants,
  `acquire_named_mutex`/`release_named_mutex`, the three family wrappers)
- `agent-system/extensions/core/scripts/task-lock.sh:674-694` (documented rationale for rejecting a
  PID-liveness fast path on the named-mutex family)
- `agent-system/extensions/core/scripts/task-lock.sh:1344-1530` (the four CLI subcommand bodies:
  `cmd_scope_acquire`/`cmd_commit_acquire`/`cmd_gate_acquire`/`cmd_gate_release`)
- `agent-system/extensions/core/scripts/tests/run-all.sh:601-644` (the gate-acquire guard block,
  call site 1 of 3)
- `agent-system/extensions/core/scripts/verify-deploy.sh:1420-1431`, `:1777-1786` (the gate-acquire
  guard blocks, call sites 2 and 3 of 3)
- `agent-system/extensions/core/scripts/deploy-headless.sh:260-310` (the standalone `.deploy-lock`
  mutex, structurally the same shape, not built on `task-lock.sh`)
- `agent-system/extensions/core/scripts/hooks/tts-notify.sh:46` (existing `${XDG_RUNTIME_DIR:-/tmp}`
  precedent)
- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh:116-263` (the `specs/`-rooted
  ephemeral-file registry, confirmed not applicable to a host-scoped root)
- `specs/610_full_gate_verification_ceiling_and_stall/reports/01_gate-verification-ceiling-and-stall.md`,
  Decision 3 and Recommendation (Question 3) (the posture ruling this record inherits)
