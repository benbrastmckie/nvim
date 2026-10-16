# Implementation Plan: Task #170

- **Task**: 170 - Isolate shell test suites from ambient host state (memory and timing axes) and record the isolation convention
- **Status**: [NOT STARTED]
- **Effort**: 8.5 hours
- **Dependencies**: 206, 215, 250, 251, 366 (all archived/completed, verified by research)
- **Research Inputs**: specs/170_isolate_shell_suites_from_host_state/reports/01_ambient-host-state-audit.md
- **Artifacts**: plans/01_ambient-host-state-isolation.md (this file), reports/02_corpus-triage-ledger.md (produced by Phase 4)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The research phase closed the open questions and produced a live-validated fix design, so this
plan is mostly execution rather than discovery. Two concrete suite fixes land first (instance B's
timing-axis coupling in `test-four-tier-conflict.sh` cases 5/6, and a shared-path existence check
in `test-detect-noop-bash.sh`), both already validated in sandbox and both requiring **zero
production-code changes**. A corpus-wide triage ledger then records a verdict for every one of the
153 suites, with the reproducible out-of-scope defects given explicit, evidenced
`known-failures.txt` rows plus spawned owners rather than being silently folded into this task.
The convention section in `shell-script-testing.md` is written last, so its worked examples cite
what actually landed rather than what was planned. A final phase discharges the repeated-run
acceptance bar (three consecutive runs, one under deliberate induced load with a pre-fix
reproduction first, plus full-run/isolated agreement).

### Research Integration

Key findings this plan is built on, all from `reports/01_ambient-host-state-audit.md`:

- **Corpus is 153 suites** (core 130, literature 7, lean 6, approvals 4, books 4, typst 2).
  Re-derived independently at plan-authoring time by replicating `run-all.sh`'s own two-pattern
  discovery; the figure matches the report exactly, so it is verified, not carried.
- **Instance A (memory axis) stays closed.** `test-lake-build-guard.sh` is 48/0 in isolation, has
  no unseamed `/proc`/`pgrep`/`ps` read, and has been in `run-all.sh`'s `LOAD_SENSITIVE_BASENAMES`
  since commit `1435f6e59`. The 2026-09-22 "reopened" claim never pinned a failing case and does
  not reproduce. It is not re-opened by this plan; it is cited as the memory-axis worked example.
- **Instance B root cause is understood, not guessed.** `task-lock.sh`'s `cmd_acquire_retry`
  (around lines 937-975) is entirely counter-based — `waited_ms` increments nominally by
  `TASK_LOCK_RETRY_POLL_MS`, and the loop never reads the clock. The suite's externally measured
  elapsed time is `N` real `sleep` calls (a fixed floor) plus `N+1` `cmd_acquire` attempts' forking
  cost, and only the second term balloons under contention. That exactly explains the recorded
  1752-1798 ms idle vs. 2472-2989 ms loaded figures.
- **The fix is the `assert-causality` rung of the ladder, not window-widening.** A one-line fake
  `sleep` on a `PATH` prepended for just the `acquire-retry` invocation; case 6 then asserts the
  exact retry-iteration count (`BUDGET_MS / POLL_MS`) instead of a wall-clock window. Validated
  twice in sandbox: 1000/100 -> 10, 500/100 -> 5. `cmd_acquire_retry` calls bare `sleep`, never an
  absolute path, so `PATH` substitution is a legitimate external seam — `task-lock.sh` is not
  edited.
- **Case 5's elapsed clause is strictly redundant.** `rc5 -eq 0 && note_count5 -eq 0` already
  proves the retry loop body was never entered, because `NOTE:` is printed only on the first retry
  iteration, before the first sleep. The `elapsed5_ms -lt 500` term is the only host-coupled term
  and is dropped, not widened.
- **Case 1 is clean** — it prints elapsed time in its `pass()` message for diagnostics only and
  never compares on it. No change.
- **The 2026-10-04/10-05 fixture-completeness roster is already resolved.** All six named suites
  plus `test-orchestrate-recover-outcome.sh` now pass when run via `run-all.sh --only`, including
  both previously-`needs-owner` EXPECTED rows. That discharges the dispatch's "give each of the two
  an explicit verdict here" instruction by evidence rather than by new work.
- **Four failures in the full 153-suite run, none of this task's class**: a stray-artifact false
  failure in `test-detect-noop-bash.sh` (in scope to fix, Phase 3), a `test-gate-cache-equivalence.sh`
  `TIMEOUT` attributable to the research session's own load, and two reproducible out-of-scope real
  defects (`test-guard-git-push.sh` grant matching, `test-verify-deploy-context-budget.sh`
  byte-count drift).
- **Pre-existing positive exemplars exist** for the convention to cite: `test-gate-registry-resolution.sh`
  cases 15/16/17 and `test-state-write-regen-timing.sh` case 1 for causal assertion;
  `test-run-task-observers.sh` case (j), `test-zotero-generate-export.sh`'s `t_timeout_guard_fires`,
  `test-run-all-selection.sh` cases 11/13 and `test-gate-registry-resolution.sh` case 13 for the
  generous-bounded-widening last resort.

### Prior Plan Reference

No prior plan. This is the task's first plan round (`artifact_number` 1).

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and `roadmap_flag` is not set, so no roadmap
phases are added and no roadmap items are claimed.

## Goals & Non-Goals

**Goals**:

- Remove the wall-clock host coupling from `test-four-tier-conflict.sh` cases 5 and 6 by asserting
  the causal property directly, with a demonstrated non-vacuousness check.
- Make `test-detect-noop-bash.sh`'s two "no stray directory" checks delta-based, so externally
  created debris at a shared, non-fixture path cannot be falsely attributed to the run under test.
- Record a triage verdict for every one of the 153 suites in the current corpus: either
  affected-and-isolated, false-positive-with-reason, or legitimately-host-dependent-and-loud-skipped.
- Give each reproducible full-run failure that is NOT this task's defect class an explicit,
  evidenced verdict — a `known-failures.txt` row with a live-output-matched reason and a named
  owner, plus a spawned follow-up — rather than leaving the gate ambiguous.
- Extend `shell-script-testing.md` with an ambient-host-state isolation section that composes with
  the existing Fixture convention, Loud-skip discipline, and `--jobs`/`LOAD_SENSITIVE_BASENAMES`
  sections rather than duplicating them.
- Reach the repeated-run acceptance bar: three consecutive runs with no NEW failure, at least one
  under deliberate induced load, with the load first shown to reproduce the original failures
  against a pre-fix copy, and full-run/isolated agreement for every suite that fails or was touched.

**Non-Goals**:

- Re-doing instance A's memory-axis isolation. It is verified closed; `test-lake-build-guard.sh` is
  deliberately absent from `file_scope` and is not edited.
- Fixing `test-guard-git-push.sh`'s grant-matching defect or `test-verify-deploy-context-budget.sh`'s
  byte-count drift. Both are reproducible in isolation, load-independent, outside this task's defect
  class, and outside `file_scope`. They get verdicts and owners here, not fixes.
- Editing any production script. Both suite fixes are external-seam-only by design; adding an env
  seam to `task-lock.sh` was evaluated and rejected as the larger diff.
- Editing `run-all.sh`, `verify-deploy.sh`, or `suite-selection-lib.sh`. The per-suite timeout is
  already overridable via the documented `RUN_ALL_SUITE_TIMEOUT_S` env seam, which is what the
  loaded run uses.
- Hand-authoring anything under `.claude/**`. All edits target `agent-system/extensions/**` per
  `source-store-deploy-boundary.md`.
- Relaxing any guard threshold, widening any assertion into vacuity, or marking any case skipped to
  make a suite pass.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| "Green gate" is literally unreachable: two reproducible out-of-scope defects are red and cannot be fixed within `file_scope` | H | H | Discharge acceptance as **zero NEW failures under `--fail-on-new`** with every EXPECTED row re-validated against live output and owned. This is the codebase's own sanctioned mechanism and `known-failures.txt` is in `file_scope` precisely for it. Stated explicitly in Phase 4 and in the summary, never left implicit. |
| `test-gate-cache-equivalence.sh` (543 s hinted cost) `TIMEOUT`s under the induced load of Phase 6, masking the real result | H | H | Raise the bound for the loaded run only, via the documented `RUN_ALL_SUITE_TIMEOUT_S` env seam (no file edit), and record the value used. A timeout under deliberately induced load is a measurement artifact, not a finding — and this is itself the "timeout tuned to an idle machine" sub-shape the convention section names. |
| Phase 6's run budget (3 full runs at ~11-12 min each, plus a loaded run and isolated re-runs) exceeds a single dispatch's practical budget and gets excluded — exactly the quieter failure mode the task description warns about | H | M | Background each run with its own log and PID, wait with the bounded-waiter idiom (`kill -0` on the captured PID, hard timeout, one waiter per log) per `context/patterns/bounded-build-waiter.md`. Never a foreground run. If the budget genuinely runs out, close the phase `[PARTIAL]` with the runs completed so far recorded, never `[COMPLETED WITH EXCLUSIONS]` on Gate 8. |
| The `PATH`-shim technique reads as "too clever" against this codebase's plain style | M | L | It is a single `mktemp -d`-scoped one-line file, needs no production change, and is validated against two budget values. Document the rationale in a comment at the shim site so the next reader does not have to re-derive it. |
| Acceptance (c) read literally — isolated re-runs of all 153 suites — would cost more than the three full runs combined | M | H | Scope the agreement check to every suite that fails in any of the three runs, plus every suite this task touched. State the narrowing and its reasoning explicitly in the summary; a suite green in all three full runs has no disagreement to detect. |
| `test-detect-noop-bash.sh`'s external interference is not root-caused, so the delta fix could mask a real defect | M | L | The delta check still fails when the directory did not exist before and does after — the exact condition the original check existed to catch. Non-vacuousness check in Phase 3 plants the directory mid-run to prove it. |
| The new convention section pushes a context-budget gate over its pin | M | L | `shell-script-testing.md` is not an eager `@`-import, so Gate 20's eager-context baseline is unaffected; Phase 5 verifies this rather than assuming it. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |
| 5 | 6 | 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Clean Baseline and Corpus Re-derivation [NOT STARTED]

**Goal**: Establish the pre-change ground truth every later phase measures against: the exact
suite corpus, and one clean full-run roster with per-suite timings, taken on a committed tree.

**Tasks**:
- [ ] Confirm the working tree carries no uncommitted change to any `file_scope` path (`git status --short` on those paths); if one exists, resolve or record it before measuring, since a dirty tree already produced one mis-attributed failure in this task's history.
- [ ] Re-derive the corpus by replicating `run-all.sh`'s own discovery (`<ext>/scripts/tests/test-*.sh` plus flat `<ext>/scripts/test-*.sh`, per extension) and record the per-extension and total counts.
- [ ] Remove the stale `agent-system/extensions/core/tmp/` directory if it has reappeared (`rmdir` only, and only if empty) — this is the known debris that blocks clean measurement of `test-detect-noop-bash.sh`.
- [ ] Launch one full `bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet --timings <timings-file>` in the background, redirecting to its own log and capturing its PID.
- [ ] Wait on it with the bounded-waiter idiom: a hard timeout, writer liveness via `kill -0` on the captured PID, one waiter per log. Never `pgrep -f`, never a foreground run.
- [ ] Record the end-of-run roster verbatim (the `[run-all] Failing suites (N):` block and the tally line), the 1-minute load average observed during the run, and the per-suite timings file path.
- [ ] For each failing suite in the roster, re-run it alone via `run-all.sh --only <basename>` and record whether it agrees with the full-run verdict. This is the pre-change half of acceptance criterion (c).

**Timing**: 1.25 hours (dominated by one ~11-12 min full run plus per-failure isolated re-runs)

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: This phase edits no tracked file, and its only product — the captured
baseline roster — is itself verified by the `run-all.sh --quiet --timings` invocation the phase
performs and the `--only` re-runs that follow it.

**Scope Hypothesis**: The corpus is hypothesized to be 153 suites (core 130, literature 7, lean 6,
approvals 4, books 4, typst 2) — a figure taken from `reports/01_ambient-host-state-audit.md` and
independently re-derived at plan-authoring time, so it is verified rather than carried; confirm it
again by re-running the discovery replication above, since the corpus has grown 72 -> 111 -> 153
over this task's life. The baseline is further hypothesized to show 4 failures matching the
research roster; confirm against the live roster and treat any divergence as the real baseline.

**Files to modify**:
- none planned — this phase is measurement only. Captured logs, timings, and roster text belong in the scratchpad or the task directory, not in `agent-system/extensions/**`.

**Verification**:
- The re-derived per-extension counts and total are recorded, and any divergence from 153 is called out rather than silently absorbed.
- A complete run-all.sh tally line was captured (not a truncated or timed-out log).
- Every failing suite in the roster has a recorded isolated-run verdict alongside its full-run verdict.
- The observed load average during the run is recorded, per the existing Measurement discipline section's requirement.

---

### Phase 2: Isolate Instance B — `test-four-tier-conflict.sh` Cases 5 and 6 [NOT STARTED]

**Goal**: Replace case 6's wall-clock window with a deterministic causal assertion on the retry
loop's iteration count, and drop case 5's redundant host-coupled elapsed clause — the
`assert-causality` rung of the ladder, not window-widening.

**Tasks**:
- [ ] Add a suite-local fake `sleep` helper: a one-line executable written into the suite's existing `mktemp -d` workdir that appends to a counter file and exits 0 without delaying. Add a comment at the site recording why `PATH` substitution is the seam (`cmd_acquire_retry` calls bare `sleep`, never an absolute path) and that no production change is needed.
- [ ] Rewrite case 6: prepend the shim directory to `PATH` for the `$TL acquire-retry` invocation only; assert `rc6 -eq 1` (unchanged) and `sleep_count == BUDGET_MS / POLL_MS` exactly. Keep the `pass()` message informative, naming the counted iterations.
- [ ] Optionally retain a generous, explicitly-labelled backstop (`elapsed6_ms` well under a minutes-scale bound) as defense-in-depth only — never as the primary signal, and only with a comment saying so.
- [ ] Rewrite case 5: drop the `elapsed5_ms -lt 500` clause entirely, keeping `rc5 -eq 0 && note_count5 -eq 0`. Update the case's comment block to state why that pair is already a complete proof the retry loop body was never entered.
- [ ] Leave case 1 untouched; confirm by reading it that its `if` condition still never compares on elapsed time.
- [ ] Non-vacuousness check (mandatory): drive the opposite direction — run case 6's shape at a second budget (e.g. `BUDGET_MS=500, POLL_MS=100`) and confirm `sleep_count` scales to 5, proving the assertion tracks the loop rather than hardcoding a pass. Record both observed counts.
- [ ] Verify with `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-four-tier-conflict.sh`, and separately confirm the suite still passes when run directly.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-four-tier-conflict.sh`
is the suite that covers this file, and the edit is confined to that one suite with no production
script or shared library touched.

**Scope Hypothesis**: Exactly two cases are hypothesized to need edits (5 and 6, at roughly lines
271 and 294 of a 504-line file), with case 1 needing none — carried from
`reports/01_ambient-host-state-audit.md`'s per-case reads. Confirm by reading all three cases
before editing; if any other case compares on an elapsed-time variable, widen this phase's scope
and say so rather than deferring it.

**Files to modify**:
- `agent-system/extensions/core/scripts/test-four-tier-conflict.sh` - add the fake-`sleep` shim helper; rewrite case 6's assertion to a `sleep_count` causal invariant; drop case 5's elapsed clause; update both cases' comment blocks

**Verification**:
- `run-all.sh --only test-four-tier-conflict.sh` passes, with case 5 and case 6 both reported as passing.
- The non-vacuousness check is recorded: two different budgets produce two different, correctly proportional `sleep_count` values.
- `git diff` confirms no file outside this suite changed, and `task-lock.sh` in particular is untouched.
- No assertion was deleted or loosened: case 5 still asserts `rc` and `NOTE:` count; case 6 still asserts `rc` plus a strictly stronger invariant than the window it replaced.

---

### Phase 3: Make `test-detect-noop-bash.sh`'s Stray-Path Checks Delta-Based [NOT STARTED]

**Goal**: Stop a pre-existing or externally created directory at a shared, non-fixture path from
being falsely attributed to the run under test, without weakening what the check catches.

**Tasks**:
- [ ] Snapshot, once at suite start (before any case runs), whether `SOURCE_STORE_TMP` (`$SCRIPT_DIR/../../tmp`) already exists, into a clearly named variable.
- [ ] Rewrite both existence checks (the Decision 2 check around line 326 and the sidecar-robustness check around line 522) to fail only on the delta: the directory did not exist at suite start but does now. When it existed at start, emit a loud, visible skip naming exactly what was skipped and why — per the existing Loud-skip discipline section, never a silent pass.
- [ ] Update the comment blocks at both sites to state the rule (a "nothing stray was created" check against a shared, live-tree path must be delta-based) and why.
- [ ] Non-vacuousness check (mandatory): with the directory absent at suite start, create it mid-run and confirm the check goes red; then confirm that with the directory present at suite start the check reports a loud skip rather than a false failure. Record both observations.
- [ ] Verify with `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-detect-noop-bash.sh`.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-detect-noop-bash.sh`
is the covering suite, and the edit is confined to that one file with the hook under test unchanged.

**Scope Hypothesis**: Exactly two call sites are hypothesized to need the delta treatment (both
guarded by `[ ! -d "$SOURCE_STORE_TMP" ]`, around lines 326 and 522) — confirm by grepping the
suite for every `SOURCE_STORE_TMP` reference before editing, and cover any additional site found.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh` - add a suite-start existence snapshot; convert both stray-directory checks to delta form with a loud skip on the pre-existing branch; update both comment blocks

**Verification**:
- `run-all.sh --only test-detect-noop-bash.sh` passes with the directory absent at suite start.
- The same invocation passes with a loud, visible skip (not a silent pass, not a failure) when the directory is planted before the suite starts.
- The planted-mid-run canary still turns the check red — recorded as the non-vacuousness check.
- `git diff` confirms `hooks/detect-noop-bash.sh` itself is untouched.

---

### Phase 4: Record the Corpus Triage Ledger and the Out-of-Scope Verdicts [NOT STARTED]

**Goal**: Give every suite in the corpus a recorded verdict, and give every reproducible non-class
failure an explicit, evidenced, owned `known-failures.txt` row — making the gate's state
unambiguous rather than merely green-looking.

**Tasks**:
- [ ] Re-run the dispatch's own keyword sweep over every suite in the re-derived corpus (memory/`proc`, wall-clock timing, load/CPU count, network, disk, process table), plus a targeted sweep for elapsed-time variables compared with `-lt`/`-le`/`-ge`/`-gt`.
- [ ] Extend the sweep past the suites themselves: for each suite with a hit, check whether host coupling enters through a sourced library or through the script under test rather than the suite (the route instance A arrived by).
- [ ] Write `specs/170_isolate_shell_suites_from_host_state/reports/02_corpus-triage-ledger.md`: one row per suite with its verdict (`affected-and-isolated`, `false-positive-with-reason`, or `legitimately-host-dependent-and-loud-skipped`) and a one-line reason. Group the no-hit majority under a single explicitly-labelled block with the sweep command that cleared them, rather than padding 140-odd identical rows.
- [ ] Record in the ledger, as named exclusions with their reasons, the defect classes the dispatch forbids misfiling here: fixture-completeness (verified resolved) and the two reproducible out-of-scope real defects.
- [ ] Re-validate each candidate `known-failures.txt` row against live output before writing it, per the existing "Re-validate a row's claimed symptom" section: capture the suite's live `[FAIL]` text and match it against the reason being recorded.
- [ ] Add `known-failures.txt` rows for `test-guard-git-push.sh` (grant-matching/test-isolation, `real-defect`) and `test-verify-deploy-context-budget.sh` (baseline byte-count drift, `real-defect`), each with a live-output-matched reason and a durable-anchor owner — never a bare task number, since this file lives outside `specs/**`.
- [ ] Confirm that the two previously-`needs-owner` rows named in the task description are genuinely absent from the current manifest and genuinely pass, and record that evidence in the ledger — this discharges the dispatch's "give each of the two an explicit verdict" instruction.
- [ ] Spawn a follow-up task per newly added row so neither is left as a `needs-owner` steady state, and record the spawned task numbers in the ledger.
- [ ] Verify the manifest still parses as `run-all.sh` expects by running `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-run-all-failure-reporting.sh`.

**Timing**: 1.75 hours

**Depends on**: 2, 3

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-run-all-failure-reporting.sh`
is the suite that covers `known-failures.txt`'s format, roster annotation, and `--fail-on-new`
semantics — the only executable surface this phase touches, the ledger itself being a `specs/**`
artifact with none.

**Scope Hypothesis**: 153 suites are hypothesized to need verdicts, of which ~2 are
affected-and-isolated (the two fixed in Phases 2 and 3), ~12 are keyword hits already read and
cleared as false positives by the research sweep, and the remainder have no hit at all — carried
from `reports/01_ambient-host-state-audit.md`'s corpus sweep. Confirm by re-running the sweep
against the Phase 1 re-derived corpus; any suite added since the research pass needs its own
verdict, and a new hit shape widens this phase rather than deferring.

**Files to modify**:
- `specs/170_isolate_shell_suites_from_host_state/reports/02_corpus-triage-ledger.md` - new file: per-suite triage verdicts, the named out-of-scope exclusions, and the live-output evidence for each manifest row
- `agent-system/extensions/core/scripts/tests/known-failures.txt` - add one `real-defect` row per reproducible out-of-scope failure, each with a live-output-matched reason and a durable-anchor owner

**Verification**:
- Every suite in the Phase 1 re-derived corpus is accounted for in the ledger, with no suite silently unlisted.
- Each added manifest row's reason was matched against that suite's live `[FAIL]` output, and the match is recorded.
- `run-all.sh --only test-run-all-failure-reporting.sh` passes, confirming the manifest still parses and classifies correctly.
- A full-run roster taken after this phase annotates both added rows as EXPECTED rather than NEW.
- No task-number reference appears in `known-failures.txt` (its own header prohibits them); owners are durable anchors.

---

### Phase 5: Write the Ambient-Host-State Isolation Convention [NOT STARTED]

**Goal**: Record the convention in `shell-script-testing.md` so future suites inherit it by
default, citing what actually landed in Phases 2-4 as the worked examples.

**Tasks**:
- [ ] Read the current file's section order and place the new section so it composes with the existing Fixture convention, Loud-skip discipline, `--jobs`/`LOAD_SENSITIVE_BASENAMES`, and Measurement discipline sections — cross-referencing them rather than restating them.
- [ ] Name the defect class (any assertion whose outcome depends on ambient host state) and state why it is load-bearing: one suite failure fails Gate 8, which fails `verify-deploy.sh`, which fails `deploy-headless.sh`, which defers an entire orchestrate batch — and a gate that cannot finish inside a dispatch's budget becomes an exclusions-table row with no red signal anywhere, which is worse than red.
- [ ] State the seam-first rule for readable-input axes, with instance A (`test-lake-build-guard.sh`'s `LAKE_BUILD_GUARD_PSI_PATH`/`MEMINFO_PATH`) as the worked example, and the bar for adding a new seam: a genuine documented override point with a real-host default, never a test-only branch or an "if running under test" conditional.
- [ ] State separately that the timing axis needs a different technique, with the full ladder: inject the clock (or intercept the delay) / assert ordering or causality / widen to generous-but-still-bounded only as a last resort with explicit justification naming what the widened bound still falsifies. State the rule that elapsed wall clock must never be used as a proxy for a property that is directly observable.
- [ ] Cite instance B's `PATH`-shimmed fake `sleep` as the primary worked example of the top rung; cite `test-gate-registry-resolution.sh` cases 15/16/17 and `test-state-write-regen-timing.sh` case 1 as pre-existing causal-assertion exemplars; cite `test-run-task-observers.sh` case (j), `test-zotero-generate-export.sh`'s `t_timeout_guard_fires`, `test-run-all-selection.sh` cases 11/13 and `test-gate-registry-resolution.sh` case 13 as the correctly-applied last-resort set.
- [ ] Add the shared-path sub-shape: a "nothing stray was created" check against a shared, non-fixture, live-tree path must be delta-based (before/after), not an absolute existence check — citing Phase 3's fix as the worked example, and cross-referencing Loud-skip discipline for the pre-existing branch.
- [ ] Add the timeout sub-shape: a per-suite or per-gate timeout tuned to an idle machine is itself ambient-host-state coupling, and `RUN_ALL_SUITE_TIMEOUT_S` is the documented seam for a deliberately loaded run — cross-reference the `--jobs` section's `--jobs 1` vs. `--jobs auto` asymmetry rather than restating it.
- [ ] Require the per-suite non-vacuousness check on every axis: after isolating, drive the opposite direction and confirm the behavior still trips. An isolation that makes a suite assert nothing is worse than the coupling it replaced.
- [ ] Forbid threshold relaxation as a remedy, and state that the bounded-widening rung is a narrow, justified exception on the timing axis only — never licence to relax a guard's own constants.
- [ ] Verify with the source-store-targeted gate subset: `bash <source_dir>/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 <source_dir>`, resolving `<source_dir>` from `.claude-extensions.json` — never the bare no-argument form, which defaults `TARGET` to the consumer repo root and silently SKIPs both gates.
- [ ] Confirm the file is not an eager `@`-import (so the context-budget gate's eager baseline is unaffected) rather than assuming it.

**Timing**: 2 hours

**Depends on**: 4

**Verification Tier**: prose

**Tier Justification**: The edit is confined to one markdown file with no executable surface, and
`bash <source_dir>/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 <source_dir>` is the
covering check for a source-store markdown edit with no mapped suite.

**Files to modify**:
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - add the ambient-host-state isolation section (defect class and blast radius, seam-first rule for readable inputs, the timing-axis ladder, the shared-path and timeout sub-shapes, the non-vacuousness requirement, the threshold-relaxation prohibition), cross-referencing the existing sections rather than restating them

**Verification**:
- `verify-deploy.sh --skip-slow --only-gate 3,4 <source_dir>` reports zero findings for gates 3 and 4, and neither gate reports SKIP (a SKIP would mean the invocation checked nothing).
- Diff read-through confirms every changed hunk is prose, and that each cross-referenced section name actually exists in the file at its cited heading.
- No task-number reference appears in the new section; every citation is a durable anchor (filename, case number, heading, or verified fact).
- The file is confirmed absent from the eager `@`-import set.

---

### Phase 6: Repeated-Run Acceptance Under Deliberate Load [NOT STARTED]

**Goal**: Discharge the acceptance bar that a single green run does not meet: three consecutive
runs with no NEW failure, at least one under deliberate induced load whose ability to reproduce the
original failures is first demonstrated, with full-run and isolated-run verdicts agreeing.

**Tasks**:
- [ ] Demonstrate the load first, against a pre-fix copy: extract the pre-fix `test-four-tier-conflict.sh` from git history into the scratchpad (`git show <sha>:<path> > <scratchpad>/...`, never a destructive git operation on the working tree) and confirm that under the induced load its cases 5 and/or 6 fail as originally recorded. A load that does not reproduce the original failure proves nothing about the fix.
- [ ] Record the load-generation method precisely enough to be reproducible: the memory-pressure mechanism (driving swap usage above the lake guard's own `SWAP_USED_RATIO_THRESHOLD=50`), the CPU/IO contention mechanism, and the observed 1-minute load average — per the existing Measurement discipline section.
- [ ] Confirm the post-fix `test-four-tier-conflict.sh` passes under that same load (the paired half of the demonstration).
- [ ] Run three consecutive full `run-all.sh --quiet --timings <file> --fail-on-new` invocations, each backgrounded to its own log with its PID captured, each waited on with the bounded-waiter idiom (hard timeout, `kill -0` on the captured PID, one waiter per log). Never a foreground run; never a no-op polling loop.
- [ ] Make at least one of the three runs carry the deliberate load, with `RUN_ALL_SUITE_TIMEOUT_S` raised for that run only (documented env seam, no file edit) so `test-gate-cache-equivalence.sh`'s 543 s hinted cost does not time out under induced contention. Record the value used.
- [ ] For every suite that fails in any of the three runs, plus every suite this task touched, re-run it alone via `run-all.sh --only <basename>` and confirm the isolated verdict agrees with the full-run verdict. Record the narrowing of acceptance criterion (c) to this set, and why a suite green in all three full runs has no disagreement to detect.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (source-store path `agent-system/extensions/core/scripts/verify-deploy.sh`), without `--skip-slow` and without `--only-gate`, and confirm Gate 8 among the rest.
- [ ] Record every run's roster and tally line verbatim in the implementation summary, together with the ledger reference, so the acceptance evidence is auditable rather than asserted.
- [ ] If the dispatch budget genuinely runs out mid-sequence, close the phase `[PARTIAL]` with the completed runs recorded — never a Gate 8 Reasoned Exclusion, which is the precise failure mode the task description identifies as the quiet one.

**Timing**: 2.25 hours (three ~11-12 min runs, a loaded run with a longer bound, the pre-fix reproduction, and the isolated agreement re-runs)

**Depends on**: 5

**Verification Tier**: full

**Scope Hypothesis**: Three full runs are hypothesized to be reachable inside one dispatch at
roughly 11-12 min each under `--jobs auto` (carried from `reports/01_ambient-host-state-audit.md`'s
measured ~11 min run), with the loaded run taking materially longer; confirm each run's actual
wall clock from its own log and, if the first two runs show the budget will not cover three, say so
and close `[PARTIAL]` rather than silently dropping a run.

**Files to modify**:
- none planned — this phase measures and records. If a run surfaces a genuine regression in a file this task already touched, fix it in that file and note the deviation; a regression anywhere else is a finding for the ledger and an owner, not an in-phase edit.

**Verification**:
- Three consecutive full `run-all.sh` runs completed to a tally line, each with zero NEW failures under `--fail-on-new`; every EXPECTED failure traces to a `known-failures.txt` row written in Phase 4 with a live-output-matched reason.
- The induced load is shown to reproduce the original pre-fix failure, and the post-fix suite is shown to pass under that same load — both recorded, with the load-generation method and the observed load average.
- Full-run and isolated-run verdicts agree for every suite that failed in any run and every suite this task touched; the narrowing of criterion (c) is stated explicitly.
- `bash .claude/scripts/verify-deploy.sh` runs in full (no `--skip-slow`, no `--only-gate`) and is green, Gate 8 included.
- No guard threshold was raised, no assertion loosened, and no case skipped to reach any of the above — confirmed by reading the cumulative `git diff` for this task.

## Testing & Validation

- [ ] `run-all.sh --only test-four-tier-conflict.sh` passes, with the case 6 non-vacuousness check recorded at two budgets.
- [ ] `run-all.sh --only test-detect-noop-bash.sh` passes both with the shared directory absent and (as a loud skip) with it planted at suite start; the planted-mid-run canary turns it red.
- [ ] `run-all.sh --only test-run-all-failure-reporting.sh` passes after the manifest edit.
- [ ] `verify-deploy.sh --skip-slow --only-gate 3,4 <source_dir>` reports zero findings and no SKIP for the convention-doc edit.
- [ ] Three consecutive full `run-all.sh` runs show zero NEW failures, one of them under demonstrated load.
- [ ] `bash .claude/scripts/verify-deploy.sh` is green in full.
- [ ] Every suite in the re-derived corpus carries a triage verdict in `reports/02_corpus-triage-ledger.md`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/test-four-tier-conflict.sh` — cases 5 and 6 isolated from wall-clock host coupling
- `agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh` — stray-path checks made delta-based
- `agent-system/extensions/core/scripts/tests/known-failures.txt` — one evidenced, owned row per reproducible out-of-scope failure
- `agent-system/extensions/core/context/standards/shell-script-testing.md` — the ambient-host-state isolation convention
- `specs/170_isolate_shell_suites_from_host_state/reports/02_corpus-triage-ledger.md` — per-suite triage verdicts and out-of-scope exclusions
- Implementation summary recording the acceptance evidence: three run rosters, the load-generation method, the observed load averages, and the full-run/isolated agreement table

## Rollback/Contingency

Every edit is confined to four files under `agent-system/extensions/**` plus one new `specs/**`
artifact, and no production script is touched, so reverting any single phase is an ordinary
targeted revert of that phase's own commit — the commit-per-green-substep granularity makes each
phase independently revertible without disturbing the others.

- If Phase 2's `PATH`-shim approach fails to hold up in the real suite (as opposed to the research
  sandbox), fall back down the ladder in order: assert the observable causal property another way
  (a counter or log line the loop already emits), and only then the generous-bounded-widening rung,
  with explicit justification naming what the widened bound still falsifies. Never widen case 6's
  window back to a proportional multiple of the budget — that is the defect being removed.
- If Phase 6 cannot reach three runs inside the dispatch budget, close `[PARTIAL]` with the
  completed runs recorded and the remaining runs named as the resume point. Do not discharge Gate 8
  by a Reasoned Exclusion: the task description identifies that specific outcome as the quiet
  failure mode this work exists to prevent.
- If a full run surfaces a NEW failure in a suite outside `file_scope`, it does not become this
  task's fix work: record it in the ledger with live output and spawn an owner, exactly as Phase 4
  does for the two already known.
