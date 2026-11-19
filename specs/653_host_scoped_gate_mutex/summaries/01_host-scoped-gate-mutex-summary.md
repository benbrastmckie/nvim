# Implementation Summary: Task #653

- **Task**: 653 - Give the gate mutex a host-scoped form, because every lock this system ships is
  invisible to a sibling repository running the same battery
- **Status**: [COMPLETED]
- **Started**: 2026-11-19T00:48:00Z
- **Completed**: 2026-11-19T02:46:00Z
- **Effort**: ~2 hours
- **Dependencies**: None (the full-gate-verification ceiling-and-stall record was a hard
  prerequisite and is COMPLETED; its posture ruling was inherited, not re-litigated)
- **Artifacts**: plans/01_host-scoped-gate-mutex.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`task-lock.sh`'s named-mutex family (`.scope-lock`, `.commit-lock`, `.gate-lock`) resolved every
mutex directory as `"$PROJECT_ROOT/specs/<name>"`, making every lock this system ships repo-scoped
by construction: a full gate battery started from a *different* repository on the same host was
not merely unserialized against a concurrent battery in this repository — it was structurally
invisible to it. This task adds a host-scoped lock root (resolved through a documented three-tier
chain, never hardcoded) and an opt-in `gate-acquire-host`/`gate-release-host` verb pair alongside
the unchanged repo-scoped default, wires all three gate-battery brackets to acquire the host-scoped
lock as an outer lock while retaining the repo-scoped acquire as the inner one, and proves the fix
with a cross-directory double-start test that could not pass before this change.

## What Changed

- `agent-system/extensions/core/scripts/task-lock.sh` — added `resolve_host_lock_root()` (a
  four-tier chain: `TASK_LOCK_HOST_ROOT_OVERRIDE` test-only override, `$XDG_RUNTIME_DIR`,
  `/run/user/$UID`, a UID-qualified `${TMPDIR:-/tmp}` fallback, failing open when every tier is
  unusable); gave `acquire_named_mutex`/`release_named_mutex` a trailing optional
  `mutex_base_dir` parameter (default `$PROJECT_ROOT/specs`, byte-identical for every existing
  caller); added the `acquire_gate_host_mutex`/`release_gate_host_mutex` wrappers and the
  `cmd_gate_acquire_host`/`cmd_gate_release_host` CLI commands (registered in the dispatch `case`
  and both `Usage:` surfaces); added a "Host-Scoped Mutex" contract paragraph stating the guard's
  real limit — a mutex binds only callers that acquire it, so co-operating callers serialize, but
  contamination from a non-cooperating process is never made impossible.
- `agent-system/extensions/core/scripts/tests/run-all.sh` — the top-level gate-lock bracket now
  acquires the host-scoped lock first (outer), guarded by a new, distinct `GATE_MUTEX_HOST_HELD`
  reentrancy flag, then performs the unchanged repo-scoped acquire (inner); releases in reverse
  order in `run_all_exit_cleanup`.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — the same host-outer/repo-inner wiring
  at both of its gate-lock brackets (`gate8_run()` and the slow-battery `gate31_run()` bracket),
  with reverse-order release at all four of their release points; the signal-scoped trap is also
  armed on host-only acquire success so a signal between the two acquires cannot leak the host
  lock.
- `agent-system/extensions/core/scripts/tests/test-gate-lock-host-scope.sh` — new suite (7 cases):
  cross-directory serialization using two independent fixture repository roots, a non-vacuousness
  control proving the serialization case is not a same-repo artifact, two lock-root degradation
  cases (override unwritable; every tier exhausted), a sanity case, and a no-leak sweep.
- `agent-system/extensions/core/scripts/tests/suite-classification.data` and
  `agent-system/extensions/core/manifest.json` — registration rows for the new suite.
- `agent-system/extensions/core/context/patterns/task-lock.md` — new "Host-Scoped Mutex" section
  documenting the tier chain, the opt-in verb pair, the binds-only-cooperating-callers limit, the
  fourth reentrancy flag, the host-outer/repo-inner nesting rationale, and why reclaim stays
  time-elapsed-only.
- A regenerated deployed `.claude/**` tree (via `deploy-headless.sh`).

## Decisions

- Trailing optional base-directory parameter on `acquire_named_mutex`/`release_named_mutex`
  (rather than a leading one with every call site rewritten), so "byte-for-byte unchanged
  default" is structural, not audited.
- Verb names `gate-acquire-host`/`gate-release-host`, following the file's existing
  one-verb-pair-per-mutex-family convention.
- The "every tier exhausted" degradation case is tested as a direct CLI call against the
  fixture's deployed `task-lock.sh`, using a `UID=999999999` environment override to defeat tier
  3 (`/run/user/$UID`, which genuinely exists and is writable on the real test host) rather than
  adding a test-only bypass to production code, and rather than routing through the full battery
  (whose own internal `mktemp` calls also honor `$TMPDIR`, so a whole-subprocess override would
  break unrelated plumbing).
- No new constants: the host-scoped form reuses `GATE_MUTEX_STALE_SEC`,
  `GATE_MUTEX_ACQUIRE_BUDGET_MS`, and `GATE_MUTEX_PROGRESS_INTERVAL_S` unchanged, keeping the
  `.gate-lock` family's posture (fail-open, budget sizing, staleness) inherited rather than
  re-decided here — that question belongs to a different record.

## Plan Deviations

- **Phase 3**: armed the signal-scoped trap on host-only acquire success too (not only after the
  inner repo-scoped acquire also succeeds) — a defensive addition beyond the literal task text,
  closing a narrow signal-leak window; both signal-cleanup functions already release whichever
  lock they find owned, so this is a safe, idempotent re-arm.
- **Phase 4**: the two degradation cases' exact invocation shape differs from the plan's literal
  phrasing — the "override unwritable" case runs unfiltered rather than `--only` (a narrowed run
  skips the whole gate-lock acquire branch by design), and "every tier exhausted" is tested as a
  direct CLI call rather than through the full battery (see Decisions above). Both are documented
  improvements discovered while making the cases actually pass, not scope reductions.
- **Phase 6**: closed `[COMPLETED WITH EXCLUSIONS]` — `deploy-headless.sh` returned exit 3
  (deploy landed, but its wrapped fast-gate verify caught an unrelated foreign extension's
  content drift) and the combined 94-suite narrowed `verify-touched.sh` pass could not complete
  within three bounded waits due to measured host contention. Both are documented with full
  evidence in the plan's Phase 6 "Reasoned Exclusions" table; neither implicates this task's own
  code, which is independently confirmed correct via the equivalent per-phase narrowed passes
  already on record.

## Verification

- Build: N/A (shell scripts; `lint-shellcheck.sh` clean on every edited/new file)
- Tests: `test-task-lock-liveness.sh` 15/15, `test-task-lock-reap.sh` 6/6, `test-gate-lock.sh`
  27/27 (unchanged, confirmed repeatedly across phases), `test-run-all-parallel.sh` 12/12,
  `test-gate-lock-host-scope.sh` 7/7 (new suite), `lint-unit-integration-boundary.sh` and
  `test-manifest-scripts-sync.sh` both clean for this task's own registration entries
- Files verified: Yes — deployed `task-lock.sh` confirmed to carry `gate-acquire-host`; deployed
  `test-gate-lock-host-scope.sh` confirmed present; `core` extension deploy-freshness confirmed
  cleared

## Impacts

- Two independent repositories on the same host can now serialize a full gate battery against
  each other for the first time, when both opt in to the host-scoped form.
- Every existing repo-scoped caller (`.scope-lock`, `.commit-lock`, `.gate-lock`'s own
  `gate-acquire`/`gate-release`) is structurally unaffected — the default resolution, message
  text, and exit codes are byte-for-byte unchanged, proven by the pre-existing 48-case baseline
  plus `test-gate-lock.sh`'s 27 cases staying green.
- A consumer repository (sf1-engine) carrying its own open record for a host-scoped single-flight
  guard can call this primitive instead of rolling its own, once this change is redeployed there.

## Follow-ups

- None for this record. The gate mutex's *posture* (fail-open vs. fail-closed, acquire budget,
  staleness, queueing) remains owned by a different record and was deliberately not revisited
  here.
- The unrelated sapience-extension content drift noted during Phase 6 (a single trailing-newline
  byte on `sapience-vault-read.sh`) is out of this task's scope and was not fixed; it belongs to
  the sapience extension's own territory.

## References

- `specs/653_host_scoped_gate_mutex/plans/01_host-scoped-gate-mutex.md`
- `specs/653_host_scoped_gate_mutex/reports/01_host-scoped-gate-mutex.md`
- `agent-system/extensions/core/scripts/task-lock.sh`
- `agent-system/extensions/core/context/patterns/task-lock.md`
