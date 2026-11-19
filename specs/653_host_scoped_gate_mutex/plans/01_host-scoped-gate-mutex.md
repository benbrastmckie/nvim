# Implementation Plan: Task #653

- **Task**: 653 - Give the gate mutex a host-scoped form, because every lock this system ships is
  invisible to a sibling repository running the same battery
- **Status**: [IMPLEMENTING]
- **Effort**: 6 hours
- **Dependencies**: None (the full-gate-verification ceiling-and-stall record is a hard
  prerequisite and is COMPLETED; its posture ruling is inherited, not re-litigated)
- **Research Inputs**: specs/653_host_scoped_gate_mutex/reports/01_host-scoped-gate-mutex.md
- **Artifacts**: plans/01_host-scoped-gate-mutex.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`task-lock.sh`'s named-mutex family resolves every mutex directory as `$PROJECT_ROOT/specs/<name>`,
so a full gate battery started from a *different* repository on the same host is not merely
unserialized — it is structurally invisible to the lock. This plan adds a host-scoped lock root
(resolved, never hardcoded), parameterizes the existing `acquire_named_mutex`/`release_named_mutex`
primitive with an optional base directory whose default is byte-identical to today, exposes an
explicitly named opt-in verb pair (`gate-acquire-host`/`gate-release-host`), and wires the gate
layer's three single-flight brackets to acquire the host-scoped lock as an OUTER lock while keeping
today's repo-scoped acquire as the inner one. Done when the opt-in host form exists, the
repo-scoped default is provably unchanged, all three brackets nest host-outer/repo-inner, the
guard's binds-only-cooperating-callers limit is stated in its own contract text, a
cross-*directory* double-start test fails without the change and passes with it, and the lock-root
degradation path is covered and fails open.

The edit target throughout is the source store (`agent-system/extensions/core/**`), never a
deployed `.claude/**` tree.

### Research Integration

Report `01_host-scoped-gate-mutex.md` is integrated in full. The findings that most shape this
plan, each re-derived from source during plan authoring rather than taken on trust:

- **Three `gate-acquire` call sites, not one** — `tests/run-all.sh` (one), and `verify-deploy.sh`
  (two: `gate8_run()` and the gate-8-sibling slow battery). Confirmed by grep; wiring only the
  first would leave two entry points repo-scoped-only.
- **The named-mutex primitive uses `mkdir` atomicity and purely time-elapsed staleness reclaim.**
  Confirmed: zero `kill -0` occurrences in `acquire_named_mutex`'s body, and the file's own
  comment block documents why a PID-liveness fast path was prototyped and reverted (the recorded
  pid is always the short-lived acquiring subprocess, never the long-lived holder). `flock` is
  never used, so filesystem `flock` semantics do not constrain this design.
- **The `$XDG_RUNTIME_DIR` fallback pattern already ships here** (`hooks/tts-notify.sh`), and the
  measured properties of `/run/user/$UID` on this host (tmpfs, mode 0700, user-owned, created at
  first login and removed at final logout) mean an abandoned host-scoped lock there is reclaimed
  by the OS independent of any staleness arithmetic — while `pam_systemd(8)`'s own "must deal with
  stale files" warning is why staleness reclaim stays active anyway.
- **Posture is inherited, not chosen**: `GATE_MUTEX_STALE_SEC` / `GATE_MUTEX_ACQUIRE_BUDGET_MS` /
  `GATE_MUTEX_PROGRESS_INTERVAL_S` are reused unchanged for the host form; no new constants.
- **A second reentrancy flag is required** (`GATE_MUTEX_HOST_HELD`), kept strictly distinct from
  `GATE_MUTEX_HELD`, or a recursive invocation would attempt a nested acquire on a documented
  non-reentrant primitive.
- **A test-only override hook is required** (`TASK_LOCK_HOST_ROOT_OVERRIDE`); no existing isolation
  technique in this codebase can relocate a path resolved from real OS environment variables.
- **`lib/runtime-file-patterns.sh` is explicitly out of scope** — the host root lives outside any
  repository tree, so that `specs/`-rooted ephemeral-file registry has no claim on it.

**One correction carried forward from research, restated here so it is not re-derived a third
time**: the task description's "the same liveness logic task-lock.sh already uses for its
repo-scoped locks (test-task-lock-liveness.sh and test-task-lock-reap.sh are the existing
precedent)" conflates two independent mechanisms. The PID-liveness machinery those two suites
cover belongs to the per-task `.lock/holder.json` family, not to the named-mutex family this task
extends. The host-scoped form therefore inherits time-elapsed-only reclaim, identical in kind to
today's repo-scoped `.gate-lock` — this is not a regression and not a question this task resolves
differently. Both suites still must keep passing; they simply are not the precedent the phrase
implied.

**One registration surface this plan adds beyond the research report**: `manifest.json`'s
`provides.scripts[]` enumerates every test file individually (178 `tests/` entries) and is
sync-enforced by `test-manifest-scripts-sync.sh`. A new suite needs a manifest row alongside its
`suite-classification.data` row, or it never reaches the deployed `.claude/scripts/tests/`
directory that Gate 8 actually discovers.

### Premise Re-Validation

The dispatch flagged five description lines for carried-figure checking. Each was checked against
the prior research artifact and against live source during plan authoring:

| Flagged claim | Result |
|---|---|
| Source store is the edit target (`agent-system/extensions/core/**`) | **Confirmed.** `.claude-extensions.json` resolves `extensions.core.source_dir` to `/home/benjamin/.config/nvim/agent-system/extensions/core`, and the dispatch's own deploy-freshness block reports the deployed `.claude/` tree STALE for `core` — redeploy is scheduled as this plan's final phase. |
| The guard's real limit (binds only cooperating callers) must be stated in contract text | **Carried unchanged.** A design obligation, not a measurement; discharged by Phase 2 (script contract text) and Phase 5 (canonical spec). |
| A same-repository double-start demo cannot distinguish host scope from repo scope | **Confirmed by reading the fixture**, not by assumption: `test-gate-lock.sh`'s serialization case launches both concurrent invocations with `cd "$WORKDIR"` against one shared `$WORKDIR`, so the assertion is identical before and after this change. |
| Fail-open matches `cmd_gate_acquire`'s existing posture | **Confirmed.** `acquire_named_mutex` returns non-zero on budget exhaustion (fails closed), and all three call sites choose to fail open with a named `WARNING:` line. This plan adds no new branch to that choice. |
| Mechanical overlap with other claimants of `verify-deploy.sh`/`task-lock.sh`; no edge filed | **Confirmed non-contending for this cycle.** The dispatch's Territory block lists exactly one concurrent sibling (task 647), whose entire `file_scope` is under `agent-system/extensions/sapience/` — disjoint from every path this plan touches. |

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no roadmap phases are added.

## Goals & Non-Goals

**Goals**:
- A host-scoped lock root resolved through a documented tier chain, never hardcoded, that fails
  open when no tier is usable.
- An explicitly named, opt-in host-scoped acquire/release verb pair alongside the repo-scoped one.
- The repo-scoped default byte-for-byte unchanged — a caller that does not ask for host scope
  observes exactly today's semantics.
- All three gate-battery brackets nesting host-scoped (outer) over repo-scoped (inner), so
  per-repository serialization is retained, not replaced.
- The guard's honest limit — co-operating callers serialize; contamination is not made impossible —
  stated prominently in its own contract text and in the canonical spec.
- Coverage that genuinely discriminates: a double-start whose second invocation runs from a
  different working directory, plus the absent/unwritable lock-root degradation path.

**Non-Goals**:
- The gate mutex's *posture* (fail-open vs fail-closed, acquire budget, staleness, queueing) —
  owned by the full-gate-verification ceiling-and-stall record and inherited here as it stands.
- Any consumer repository's own battery harness (a different repository, not reachable from here).
- PID-liveness reclaim for the named-mutex family, repo- or host-scoped.
- A second mutex implementation, or any change to `deploy-headless.sh`'s hand-rolled
  `.deploy-lock` (same shape, different owner, not in this record's territory).
- Any change to `lib/runtime-file-patterns.sh`.
- Changing the default scope of any existing lock call site.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The new base-directory parameter silently changes an existing call site's resolved directory | H | L | Make the parameter a *trailing optional* positional defaulting to `$PROJECT_ROOT/specs`, so no existing caller is edited at all; the 48-case baseline (`test-task-lock-liveness.sh` 15, `test-task-lock-reap.sh` 6, `test-gate-lock.sh` 27) turns any drift into a test failure rather than a silent behavior change |
| Existing WARN/progress message text changes for the default base, breaking an anchored assertion | M | M | Derive a display label that is literally `specs/<dirname>` when the base is the default and the absolute path otherwise; `test-gate-lock.sh` asserts on these lines and is in Phase 1's verification |
| A recursive invocation (Gate 8 recursing into `run-all.sh`) attempts a nested host acquire and waits out its own outer holder | H | M | A distinct `GATE_MUTEX_HOST_HELD` flag, exported/unset with exactly the discipline `GATE_MUTEX_HELD` already uses, never conflated with it |
| A deployed `task-lock.sh` predating this change does not understand `gate-acquire-host`, and a call site treats the unknown-subcommand exit as fatal | H | M | Unknown subcommand already exits non-zero, which lands in each site's existing fail-open branch; the plan adds no new branch and Phase 3 verifies the degradation explicitly |
| A `/tmp` fallback lock root collides with, or is pre-created by, another OS user on a shared host | M | L | UID-qualify the fallback directory name, create it mode `0700`, and refuse a pre-existing directory whose owner UID is not the resolving user |
| A test exercising the real host root collides with a concurrent developer/CI session on this machine | H | M | `TASK_LOCK_HOST_ROOT_OVERRIDE` is mandatory in every new case; no new test may call the resolver without it |
| The new suite is written but never runs in production because it is not registered | M | M | Phase 4 edits both registration surfaces in its own phase: `suite-classification.data` (lint-blocking via `lint-unit-integration-boundary.sh`) and `manifest.json` (`test-manifest-scripts-sync.sh`) |
| Host-scoped serialization makes two sibling repositories' batteries queue, lengthening wall-clock | M | H | Accepted and intended — serialized-and-correct beats concurrent-and-contaminated; the existing acquire budget bounds the wait and the fail-open posture bounds the worst case |

## Decisions

1. **Trailing optional base-directory parameter**, not a leading one. `acquire_named_mutex` gains a
   6th positional (after the existing optional `progress_label`) and `release_named_mutex` a 2nd,
   each defaulting to `$PROJECT_ROOT/specs`. This satisfies "byte-for-byte unchanged default"
   structurally — no existing call site is edited at all — rather than by audit, which is the
   cheaper and more verifiable of the two shapes research left open.
2. **Verb names**: `gate-acquire-host` / `gate-release-host`, following the file's existing
   one-verb-pair-per-mutex-family convention rather than overloading `gate-acquire` with a silent
   flag. Research explicitly left the exact string as a plan-level choice; this fixes it.
3. **The non-vacuousness control arm uses two *distinct* override roots** rather than a copied
   pre-change `task-lock.sh`. Two fixture repositories each resolving their own private lock root
   is exactly what repo-scoping reduces to, so the control reproduces today's behavior through the
   new code path, with no second copy of the script to drift. (Fallback if that proves
   insufficiently faithful: a stub `task-lock.sh` whose `gate-acquire-host` exits 2, exercising the
   fail-open path instead — record the switch as a deviation if taken.)
4. **Resolver failure returns the same non-zero the budget-exhaustion path returns**, so every call
   site's *existing* fail-open branch covers lock-root trouble with no new branch at any of the
   three sites. This is what makes "fail open on lock-root trouble" a structural property rather
   than three hand-maintained copies of a decision.
5. **No new constants.** The host form reuses `GATE_MUTEX_STALE_SEC` /
   `GATE_MUTEX_ACQUIRE_BUDGET_MS` / `GATE_MUTEX_PROGRESS_INTERVAL_S`, which keeps the documented
   invariant (`ACQUIRE_BUDGET_MS <= STALE_SEC*1000`) satisfied by construction and keeps the
   posture ruling inherited rather than forked.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 5 | 2 |
| 4 | 4 | 3 |
| 5 | 6 | 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Host lock-root resolver and named-mutex base-directory parameterization [COMPLETED]

**Goal**: Add `resolve_host_lock_root()` and give `acquire_named_mutex`/`release_named_mutex` an
optional trailing base-directory parameter defaulting to `$PROJECT_ROOT/specs`, so a caller can
point the existing primitive at a host-scoped root without any existing caller changing.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/task-lock.sh` lines 641-833 immediately before
      editing (a sibling task is dispatched this same cycle on this shared tree) and confirm the
      primitive's shape is unchanged since plan authoring. *(completed: re-read confirmed shape
      unchanged; no `.plan-revised.json` sentinel present)*
- [x] Add `resolve_host_lock_root()` directly above the named-mutex family, resolving in strict
      tier order: `TASK_LOCK_HOST_ROOT_OVERRIDE` (documented test-only, never for production) ->
      `$XDG_RUNTIME_DIR` (set, a directory, writable) -> `/run/user/$UID` (exists, writable) ->
      `${TMPDIR:-/tmp}/task-lock-host-$UID` (UID-qualified name, created with `mkdir -p` then
      `chmod 0700`). *(completed)*
- [x] Make the final tier refuse a pre-existing directory at that path whose owner UID is not the
      resolving user (`stat -c %u`), since `/tmp` is world-writable with only the sticky bit — the
      sticky bit prevents deletion by another user, not pre-creation by one. *(completed)*
- [x] Make the resolver print nothing and return non-zero when every tier fails. It must never
      `exit`, never create anything outside the resolved root, and never block. *(completed)*
- [x] Add the 6th optional positional `mutex_base_dir` to `acquire_named_mutex` (after
      `progress_label`) and the 2nd optional positional to `release_named_mutex`, both defaulting
      to `$PROJECT_ROOT/specs`; resolve `mutex_dir="$mutex_base_dir/$mutex_dirname"`. *(completed)*
- [x] Preserve every existing message byte-for-byte for the default base: derive a display label
      that is literally `specs/<dirname>` when the base equals `$PROJECT_ROOT/specs`, and the
      absolute `<base>/<dirname>` otherwise. This covers the stale-reclaim `WARN:` line and the
      `[gate-lock] waiting ...` progress line, both of which embed `specs/${mutex_dirname}` today.
      *(completed: confirmed byte-identical via test-gate-lock.sh's 27/27)*
- [x] Create the base directory with `mkdir -p` only for a non-default base (a host root may not
      yet have the mutex's parent); leave the default path's behavior untouched. *(completed)*
- [x] Write a block comment above the resolver documenting the tier order, the fail-open return
      contract, the UID-qualification rationale, and that the override variable is test-only.
      *(completed)*

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/task-lock.sh` — the single edited file, which `suite_selection_select` resolved at authoring time to a covering set of 42 suites spanning this primitive's lock, gate, commit and state-write consumers.

**Scope Hypothesis**: no existing caller of `acquire_named_mutex`/`release_named_mutex` (the
`.scope-lock`, `.commit-lock`, `.gate-lock`, and `.contention-claims` wrapper pairs) needs an edit,
because the new parameter is trailing and optional. Confirm with
`grep -n 'acquire_named_mutex\|release_named_mutex' agent-system/extensions/core/scripts/task-lock.sh`
before closing the phase; if any caller *does* need an edit, record that as a scope finding rather
than making it silently.

**Files to modify**:
- `agent-system/extensions/core/scripts/task-lock.sh` - new `resolve_host_lock_root()`; optional
  trailing base-directory parameter on both named-mutex primitives; display-label derivation

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-task-lock-liveness.sh` passes (15/15
  baseline)
- `bash agent-system/extensions/core/scripts/test-task-lock-reap.sh` passes (6/6 baseline)
- `bash agent-system/extensions/core/scripts/tests/test-gate-lock.sh` passes (27/27 baseline),
  which is also what proves the message text is byte-identical for the default base
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh agent-system/extensions/core/scripts/task-lock.sh` exits 0
- The narrowed `verify-touched.sh` pass named in Tier Justification is green

---

### Phase 2: Opt-in host-scoped verb pair and its contract text [COMPLETED]

**Goal**: Expose the host-scoped acquire/release as an explicitly named, opt-in CLI verb pair with
the repo-scoped form unchanged as the default, and state the guard's real limit in the script's own
contract text.

**Tasks**:
- [x] Add `acquire_gate_host_mutex` / `release_gate_host_mutex` wrappers that call
      `resolve_host_lock_root()` for the base and reuse `GATE_MUTEX_STALE_SEC`,
      `GATE_MUTEX_ACQUIRE_BUDGET_MS` and `GATE_MUTEX_PROGRESS_INTERVAL_S` unchanged — no new
      constants. Use a distinct progress label (e.g. `gate-lock-host`) so a waiting host-scoped run
      is distinguishable in logs from a waiting repo-scoped one. *(completed)*
- [x] Add `cmd_gate_acquire_host` / `cmd_gate_release_host` mirroring `cmd_gate_acquire` /
      `cmd_gate_release` exactly: same owner-token format, same owner-file write, same
      no-trap-of-its-own contract, same owner-token-verified release that never force-removes a
      successor's mutex. *(completed)*
- [x] On resolver failure, return the same non-zero code the budget-exhaustion path returns, with
      an `ERROR:` line naming the lock-root failure, so every call site's existing fail-open branch
      covers it (Decision 4). *(completed: confirmed via manual smoke test, rc=2 with named ERROR:
      line)*
- [x] Register both verbs in the CLI `case` dispatch and in the final `Usage: $0 {...}` line.
      *(completed)*
- [x] Add both verbs to the top-of-file `Usage:` block. *(completed)*
- [x] Add a contract paragraph to the top-of-file comment that states, prominently and without
      hedging: this mutex binds only callers that acquire it; a battery started by a process that
      never calls `gate-acquire-host` — a hand-run command, an editor task, another tool — is not
      serialized by it; the honest claim is that **co-operating callers serialize**, never that
      contamination is impossible. The same paragraph records that repo scope remains the default,
      that host scope is opt-in, that `GATE_MUTEX_HOST_HELD` is a fourth, distinct reentrancy flag,
      and that reclaim here is time-elapsed only for the same documented reason the repo-scoped
      family gives. *(completed: "Host-Scoped Mutex" paragraph added to the top-of-file comment)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/task-lock.sh` — still the single edited file, resolving to the same measured 42-suite covering set, which includes the suite that exercises the repo-scoped verbs this phase must leave untouched.

**Scope Hypothesis**: this phase is purely additive — no existing subcommand's argument parsing,
usage line, exit code, or message text changes. Confirm by reading the `case`-dispatch diff and by
re-running `test-gate-lock.sh`'s 27 cases before closing; a change to any existing verb is a
deviation to record, not to absorb.

**Files to modify**:
- `agent-system/extensions/core/scripts/task-lock.sh` - host-scoped wrapper pair, `cmd_*_host`
  bodies, CLI dispatch entries, `Usage:` block entries, contract paragraph

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-gate-lock.sh` passes unchanged (27/27)
- `bash agent-system/extensions/core/scripts/task-lock.sh` with no arguments prints a usage line
  naming both new verbs
- A manual smoke acquire/release against a `TASK_LOCK_HOST_ROOT_OVERRIDE` temp directory returns a
  token, creates the mutex under that root (never under any `specs/`), and releases cleanly
- A manual acquire with the override pointed at an unwritable path returns non-zero and prints the
  named `ERROR:` line rather than hanging or creating anything
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh agent-system/extensions/core/scripts/task-lock.sh` exits 0

---

### Phase 3: Wire the three gate-battery brackets to the host-scoped form [COMPLETED]

**Goal**: Make each of the gate layer's three single-flight brackets acquire the host-scoped lock
as the OUTER lock while keeping today's repo-scoped acquire as the inner one, releasing in reverse
order at every release point.

**Tasks**:
- [x] Re-read both files immediately before editing (concurrent-sibling discipline). *(completed;
      re-ran the Scope Hypothesis grep too -- confirmed exactly 3 acquire blocks, 5 release points,
      no drift since plan authoring)*
- [x] `tests/run-all.sh`: in the acquire branch (around line 637), acquire host-scoped first —
      guarded by `GATE_MUTEX_HOST_HELD` exactly as the inner acquire is guarded by
      `GATE_MUTEX_HELD` — export `GATE_MUTEX_HOST_HELD=1` on success, then perform today's existing
      repo-scoped acquire unchanged. On host-acquire failure emit a `WARNING:` line naming host
      scope and proceed (fail open), then still attempt the inner acquire. *(completed)*
- [x] `tests/run-all.sh`: in `run_all_exit_cleanup` (around line 585), release the inner
      repo-scoped lock first, then the host-scoped lock, unsetting each flag with the same
      discipline already used for `GATE_MUTEX_HELD`. *(completed)*
- [x] `verify-deploy.sh` `gate8_run()`: the same outer/inner acquire at the acquire block (around
      line 1427), and reverse-order release at BOTH of its release points — the signal-cleanup path
      (around line 1320) and the ordinary release (around line 1651). *(completed: trap also armed
      on host-only acquire success, a small defensive addition beyond the literal task text --
      see progress file `approaches_tried`)*
- [x] `verify-deploy.sh` slow-battery bracket: the same outer/inner acquire (around line 1782) and
      reverse-order release at both of its release points (around lines 1744 and 1838).
      *(completed, same defensive trap addition as gate8_run)*
- [x] At all three sites, treat a deployed `task-lock.sh` that does not understand
      `gate-acquire-host` exactly like an acquire failure — fail open with the named `WARNING:`,
      never abort. An unknown subcommand already exits non-zero, so this needs no new branch; the
      task is to confirm it, not to add one. *(completed: confirmed via a stub fixture built from
      the pre-Phase-2 task-lock.sh, which genuinely lacks gate-acquire-host -- produced a real
      verdict plus the named WARNING line)*
- [x] Leave every existing skip branch untouched: narrowed (`--only`/`--class`/`--tag`/
      `--cost-class`), nested, guest (`GATE_MUTEX_HELD` inherited), and missing-`task-lock.sh`. The
      host-scoped acquire is skipped under exactly the same conditions the repo-scoped one is.
      *(completed; confirmed via the narrowed --only run touching neither lock root)*
- [x] Confirm the two `verify-deploy.sh` batteries remain `serialized=true` and scheduled one at a
      time, so the second never contends with the first's host-scoped holder. *(completed: both
      gate 8 and gate 31 confirmed serialized=true in gate-registry.data; no edit needed)*

**Timing**: 1.25 hours

**Depends on**: 2

**Verification Tier**: interface

**Tier Justification**: the newly exported `GATE_MUTEX_HOST_HELD` is an inherited-environment contract spanning both edited files, and `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/tests/run-all.sh agent-system/extensions/core/scripts/verify-deploy.sh` resolved at authoring time to the enumerated 41-suite dependent set that covers that contract across the gate, run-all and verify-deploy consumers.

**Scope Hypothesis**: there are exactly three acquire blocks and five release points —
`tests/run-all.sh:586`, and `verify-deploy.sh:1320`, `:1651`, `:1744`, `:1838` — measured by grep
at plan authoring. Re-run
`grep -n 'gate-release\|MUTEX_OWNED_HERE' agent-system/extensions/core/scripts/tests/run-all.sh agent-system/extensions/core/scripts/verify-deploy.sh`
before editing and reconcile any difference explicitly; do not edit only the sites listed here if
the grep shows more.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/run-all.sh` - outer host acquire in the acquire
  branch; reverse-order release in the exit cleanup
- `agent-system/extensions/core/scripts/verify-deploy.sh` - outer host acquire in both gate
  brackets; reverse-order release at all four of their release points

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-gate-lock.sh` passes unchanged (27/27) —
  its existing serialization, fail-open, nested, no-leak and verdict-identity cases all still hold
- `bash agent-system/extensions/core/scripts/tests/test-run-all-parallel.sh` passes
- A `--only`-narrowed `run-all.sh` run touches neither lock root (confirm the existing `Note:` line
  and that no host-lock directory appears under the override root)
- A run with a stub `task-lock.sh` lacking `gate-acquire-host` still produces a real verdict plus
  the named fail-open `WARNING:`
- The narrowed `verify-touched.sh` pass named in Tier Justification is green

---

### Phase 4: Cross-directory double-start and lock-root degradation coverage [COMPLETED]

**Goal**: Prove the regression the host form fixes with a test that could not pass before the
change, prove that test is non-vacuous, and cover the absent/unwritable lock-root degradation path.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/tests/test-gate-lock-host-scope.sh`, built on
      `test-gate-lock.sh`'s fixture technique but constructing TWO independent fixture repository
      roots: two separate `mktemp -d` trees, each with its own
      `agent-system/extensions/core/scripts/tests/`, `.claude/scripts/` (copied `task-lock.sh`,
      `deploy-root-guard.sh`, `lib/common.sh`, `lib/task-lookup-lib.sh`,
      `lib/file-scope-overlap.sh`), `specs/`, and a copied `run-all.sh` plus marker fixture suite.
      Keep the two-levels-up nesting `test-gate-lock.sh`'s header documents — both roots need it for
      `PROJECT_ROOT`/`EXTENSIONS_ROOT` arithmetic to agree. *(completed)*
- [x] Clear `RUN_ALL_NESTED`, `GATE_MUTEX_HELD` and `GATE_MUTEX_HOST_HELD` at the top of the suite,
      following `test-gate-lock.sh`'s documented precedent, so the cases are not silently vacuous
      when this suite is itself discovered by an outer `run-all.sh`. *(completed)*
- [x] Case **cross-directory serialization**: both roots share ONE
      `TASK_LOCK_HOST_ROOT_OVERRIDE`; launch two concurrent unfiltered fixture batteries, one `cd`'d
      into each root; assert their start/finish marker intervals do not overlap. *(completed)*
- [x] Case **non-vacuousness control**: the same two roots, each given its OWN distinct
      `TASK_LOCK_HOST_ROOT_OVERRIDE` — exactly what repo-scoping reduces to; assert the intervals
      DO overlap, proving the first case measures host scope and not some same-repo artifact.
      *(completed)*
- [x] Case **degradation, override unwritable**: point the override at a `chmod 000` directory with
      `XDG_RUNTIME_DIR` unset; assert the battery still runs, prints a real verdict, and emits the
      named fail-open `WARNING:` line. *(completed; deviation: run unfiltered rather than `--only`
      -- a narrowed run skips the acquire branch entirely, see progress file `approaches_tried`)*
- [x] Case **degradation, every tier exhausted**: `XDG_RUNTIME_DIR` unset, `TMPDIR` pointed at an
      unwritable path; assert `resolve_host_lock_root()` returns non-zero and the call site fails
      open rather than blocking. *(completed; deviation: tested as a direct CLI call against the
      fixture's deployed task-lock.sh, using a UID-override technique to defeat tier 3, rather than
      through the full battery -- TMPDIR also governs run-all.sh's own internal mktemp calls, so a
      whole-subprocess override broke unrelated plumbing; see progress file `approaches_tried`)*
- [x] Case **no leak**: no host-scoped lock directory survives a completed invocation at either
      root. *(completed)*
- [x] Add the suite's row to `agent-system/extensions/core/scripts/tests/suite-classification.data`
      (class `integration`, `invokes:` naming `run-all.sh` and `task-lock.sh`) —
      `lint/lint-unit-integration-boundary.sh` fails loudly on an unclassified discovered suite, so
      this row is commit-blocking and belongs in this phase, not a later reconciliation.
      *(completed)*
- [x] Add `tests/test-gate-lock-host-scope.sh` to `agent-system/extensions/core/manifest.json`'s
      `provides.scripts[]` — the manifest enumerates every test file individually and
      `test-manifest-scripts-sync.sh` enforces the sync; an unlisted suite never reaches the
      deployed `.claude/scripts/tests/` directory Gate 8 discovers. *(completed)*
- [x] Run the new suite from a working directory that is NEITHER fixture root, and never against
      the real `$XDG_RUNTIME_DIR`. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's three touched paths (the new suite, the classification data file, and the manifest) — measured at authoring the selector returns the `__FULL_SWEEP__` sentinel for that set, because the new suite does not yet exist on disk, so no mapped suite covers it and the honest in-phase check is the new suite's own run plus the two registration lints named under Verification below.

**Scope Hypothesis**: six cases, and `suite-classification.data` plus `manifest.json` are the
complete registration set for a new core test suite. Confirm the registration claim before closing
by grepping an existing suite basename across the extension
(`grep -rn 'test-gate-lock.sh' agent-system/extensions/core --include='*.json' --include='*.data' --include='*.txt'`)
and add any further surface that grep reveals rather than assuming this list is exhaustive.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-gate-lock-host-scope.sh` - new suite (two
  fixture roots; serialization, non-vacuousness control, two degradation cases, no-leak)
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - classification row for
  the new suite (commit-blocking lint surface)
- `agent-system/extensions/core/manifest.json` - `provides.scripts[]` entry for the new suite
  (sync-enforced deployment surface)

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-gate-lock-host-scope.sh` passes, run from a
  directory that is neither fixture root
- The non-vacuousness control case genuinely observes overlap — a run where both cases report
  "no overlap" is a failed proof, not a pass
- `bash agent-system/extensions/core/scripts/lint/lint-unit-integration-boundary.sh` clean
- `bash agent-system/extensions/core/scripts/tests/test-manifest-scripts-sync.sh` passes
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh agent-system/extensions/core/scripts/tests/test-gate-lock-host-scope.sh` exits 0
- The narrowed `verify-touched.sh` pass named in Tier Justification is green

---

### Phase 5: Host-scoped mutex section in the canonical spec [NOT STARTED]

**Goal**: Extend `context/patterns/task-lock.md` — the canonical spec `task-lock.sh`'s own header
points to — with a Host-Scoped Mutex section, so the contract lives where consumers are told to
read it rather than only in a script comment.

**Tasks**:
- [ ] Add a "Host-Scoped Mutex" section covering: the three-tier root resolution chain and the
      test-only override variable; the opt-in verb pair and the guarantee that repo scope stays the
      default; `GATE_MUTEX_HOST_HELD` as a fourth, distinct reentrancy flag; time-elapsed-only
      reclaim and why PID-liveness remains rejected for this family; and the fail-open-on-lock-root-
      trouble posture, inherited from the repo-scoped family rather than decided here.
- [ ] State the binds-only-cooperating-callers limit as prominently here as in the script: a mutex
      binds only callers that acquire it, so the honest claim is that co-operating callers
      serialize, never that contamination is impossible.
- [ ] Describe the host-outer / repo-inner nesting at the three gate brackets and why per-repo
      serialization is retained rather than replaced.
- [ ] Give the section the same depth the repo-scoped family's existing sections have (staleness,
      same-session re-entry, fail-open rationale).
- [ ] No task-number references and no record-versioning language anywhere in the file.

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: prose

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/context/patterns/task-lock.md` — measured at authoring, the selector resolves that path to `test-audit-task-proposals.sh`, `test-four-tier-conflict.sh`, `test-phase-heartbeat.sh`, `test-session-registry.sh`, `test-task-lock-liveness.sh`, `test-task-lock-queue.sh` and `test-task-lock-reap.sh`, which is the covering set for a documentation edit with no executable surface.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/task-lock.md` - new Host-Scoped Mutex section

**Verification**:
- Diff read-through confirming every changed hunk is prose, with no executable surface touched
- The section's described contract matches the implemented verb names, flag name, tier chain and
  override variable exactly — a mismatch here is a documentation defect, not a cosmetic one
- `bash agent-system/extensions/core/scripts/check-task-references.sh` exits 0 for the edited file
  (no task-number reference outside `specs/**`)
- The narrowed `verify-touched.sh` pass named in Tier Justification is green

---

### Phase 6: Redeploy and closing verification [NOT STARTED]

**Goal**: Regenerate the deployed tree so the deployed `task-lock.sh`, `run-all.sh`,
`verify-deploy.sh` and the new suite are the ones Gate 8 actually runs, then close verification for
the task.

**Tasks**:
- [ ] Redeploy with the bounded-wait idiom: `timeout 540 bash .claude/scripts/deploy-headless.sh`,
      with the Bash tool's own `timeout` parameter raised to 600000 (never its 120000 default), per
      `context/patterns/external-process-wait.md` Rule 1.
- [ ] Confirm the deployed `.claude/scripts/task-lock.sh` carries `gate-acquire-host` and that
      `.claude/scripts/tests/test-gate-lock-host-scope.sh` exists in the deployed tests directory.
- [ ] Confirm the deploy-freshness warning for the `core` extension has cleared.
- [ ] Run the scoped touched-path check over this task's own touched paths
      (`bash .claude/scripts/verify-touched.sh <this task's modified files>`).
- [ ] Defer the complete gate battery to the orchestration close rather than invoking an
      independent full battery here — that is the once-per-invocation obligation, discharged at the
      close, never forgiven.

**Timing**: 0.5 hours

**Depends on**: 4, 5

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed `.claude/**` tree

**Verification**:
- `deploy-headless.sh` exits 0 within its bounded wait
- `grep -q 'gate-acquire-host' .claude/scripts/task-lock.sh` succeeds and
  `.claude/scripts/tests/test-gate-lock-host-scope.sh` exists
- The scoped `verify-touched.sh` pass over this task's touched paths is green
- The complete gate set is explicitly deferred to the orchestration close (Move 4), stated as a
  deferral in the phase's closure note, not silently skipped

---

## Testing & Validation

- [ ] The 48-case baseline is still green after every phase: `test-task-lock-liveness.sh` (15),
      `test-task-lock-reap.sh` (6), `test-gate-lock.sh` (27)
- [ ] A caller that does not ask for host scope resolves its mutex exactly where it did before, and
      every existing WARN/progress line is byte-identical
- [ ] Two concurrent full batteries started from two different working directories, sharing one
      host lock root, do not overlap
- [ ] The same two batteries with distinct lock roots DO overlap (non-vacuousness)
- [ ] Every lock-root degradation step — override unwritable, `XDG_RUNTIME_DIR` unset,
      `/run/user/$UID` absent, fallback tier unwritable — fails open: the battery runs, the verdict
      is real, a named `WARNING:` is emitted
- [ ] A narrowed (`--only`) run touches neither lock root
- [ ] A nested/guest invocation performs no second host-scoped acquire
- [ ] No lock directory, repo- or host-scoped, survives a completed invocation
- [ ] `lint-unit-integration-boundary.sh` and `test-manifest-scripts-sync.sh` are clean with the
      new suite registered
- [ ] The complete gate set runs once for this orchestration invocation, at its close

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/task-lock.sh` — `resolve_host_lock_root()`, the
  base-directory-parameterized named-mutex primitives, the `gate-acquire-host`/`gate-release-host`
  verb pair, and the contract text stating the guard's real limit
- `agent-system/extensions/core/scripts/tests/run-all.sh` and
  `agent-system/extensions/core/scripts/verify-deploy.sh` — three brackets nesting host-outer over
  repo-inner
- `agent-system/extensions/core/scripts/tests/test-gate-lock-host-scope.sh` — cross-directory
  double-start, non-vacuousness control, degradation and no-leak coverage
- `agent-system/extensions/core/scripts/tests/suite-classification.data` and
  `agent-system/extensions/core/manifest.json` — registration rows for the new suite
- `agent-system/extensions/core/context/patterns/task-lock.md` — the Host-Scoped Mutex section
- A regenerated deployed `.claude/**` tree

## Rollback/Contingency

Every phase is a scoped, independently committed change to the source store, so rollback is
per-phase `git revert` of that phase's commit followed by a redeploy; nothing in this plan writes
outside the source store except the deploy itself, which is regenerated from it.

- If Phase 1's parameterization causes any baseline failure, revert that phase and reconsider the
  parameter position (a leading positional with every existing call site updated explicitly is the
  documented alternative) rather than patching message text to satisfy an assertion.
- If Phase 3's wiring destabilizes a gate bracket, the host-scoped acquire can be removed from the
  affected bracket alone — the brackets are independent, and the repo-scoped inner lock is
  untouched by this plan, so partial reversion degrades to exactly today's behavior rather than to
  no serialization at all.
- If the Phase 4 control arm (two distinct override roots) proves an unfaithful stand-in for
  repo-scoping, switch to the stub-`task-lock.sh` fallback named in Decision 3 and record the
  switch as a deviation.
- If a lock-root tier behaves unexpectedly on a host, the resolver's fail-open return means the
  worst case is today's unserialized behavior plus a warning — never a blocked verification.
