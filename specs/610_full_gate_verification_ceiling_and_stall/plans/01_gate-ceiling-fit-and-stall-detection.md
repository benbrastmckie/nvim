# Implementation Plan: Task #610

- **Task**: 610 - Full gate verification ceiling and stall
- **Status**: [IMPLEMENTING]
- **Effort**: 12 hours
- **Dependencies**: None blocking. Territory edges 454, 476, 452, 650, 651, `host_scoped_gate_mutex` (see Goals & Non-Goals)
- **Research Inputs**: specs/610_full_gate_verification_ceiling_and_stall/reports/01_gate-verification-ceiling-and-stall.md
- **Artifacts**: plans/01_gate-ceiling-fit-and-stall-detection.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Full-gate verification cannot complete inside one foreground Bash call, so every agent is forced
onto a detach path where a missing bounded wait becomes an unbounded stall; and the orchestration
loop's own stall detector is wired downstream of the event it must detect the absence of. This
plan makes Gate 8 structurally fit under the foreground ceiling by relocating (never dropping)
the nine slow suites onto their own serialized gate, replaces the advisory batch-gate-deferral
directive with a file-sentinel guard that mechanically refuses a nested unfiltered battery,
generalizes the existing Gate-8-only contention tagging to every gate's timeout kill, and wires
the already-built heartbeat strand probe into a watchdog the orchestrator launches beside its
dispatches rather than after them. Done means: a measured Gate 8 wall-clock under 600s with real
headroom, an unfiltered battery that refuses itself when a batch close owes one, a load-killed
gate that is mechanically distinguishable from a real failure, a strand alert that lands in
minutes, and no reduction in what runs by default.

### Research Integration

The research report settles four of the five questions and is adopted as-is on each:

- **Q1**: `JOBS_CAP` raising is ruled out (the pool is straggler-bound; re-confirmed live below).
  Faster *default suite selection* belongs to territory edge 650 and is excluded here. Slow-suite
  relocation is the one remaining lever, and the straggler is `test-gate-cache-equivalence.sh`.
- **Q2**: the deferral directive is prose with no enforcement, and is additionally gated on
  `.task_numbers | length > 1`, so a batch of one never even receives it. A marker-based guard
  read at `verify-deploy.sh`/`run-all.sh` entry is the mechanism. Phases 4 and 5 build it.
- **Q3**: `.gate-lock` keeps its fail-open posture; no change to budgets or staleness. The
  leverage point is Q2's guard, which removes the routine multi-dispatch collision case. Phase 1
  records this ruling durably so the dependent `host_scoped_gate_mutex` record inherits rather
  than re-litigates it.
- **Q4**: generalize `GATE8_CONTENTION_DETECTED`'s two-signal model into the generic registry
  executor as a WARN tag, never a bound extension and never an auto-pass. Phase 6.
- **Q5**: the ordering IS the defect — `stall_suspected` is computed inside Move 3, which cannot
  begin until every Move 2 Agent call returns. The report left the fix's shape open pending an
  unverified orchestrator-side background-Agent capability. This plan closes that open item
  differently (see Decisions 4 and 5): the fix is built on background **Bash**, which needs no
  Agent-tool capability, and on `dispatch-strand-probe.sh`, which already exists.

### Premise Re-Validation

Every trigger-class line the dispatch extracted was checked against live state. Results, stated
explicitly including where they only confirm the description:

| Premise | Verdict |
|---|---|
| Gate 8 declares `timeout_s=1500`, `serialized=true` | **CONFIRMED** live. It is the *only* serialized row among the 30 gate rows in `scripts/gate-registry.data` |
| Gate 22 (shellcheck) declares 170s | **CONFIRMED** live |
| "the remaining 27 gates declare 30-60s each" | **CORRECTED**. The live timeout histogram is 24 gates at 30s, one at 40s, three at 180s, one at 170s, one at 1500s. No gate declares 60s; three declare 180s (gates 3, 4, 10). The research report's "30-180s" characterization is the accurate one |
| Bash foreground ceiling is exactly 600s | **CARRIED** from `context/patterns/external-process-wait.md`'s "The 600s Ceiling Is Measured, Not Assumed" subsection (harness 2.1.322, measured 2026-11-12). Not re-measured in this dispatch — re-measuring a harness ceiling is not a cheap plan-time operation, and the cited subsection records the direct measurement |
| `suite-cost-hints.txt`: 156 rows, 1,406,493ms aggregate, straggler `test-gate-cache-equivalence.sh` at 543,000ms | **CONFIRMED** live, fresh re-derivation this dispatch, matching the report exactly |
| Gate 8 measured 457,197ms idle / 662,354ms under load 1.69-2.26 | **CONFIRMED PRESENT** in `context/standards/shell-script-testing.md`'s "Measured Before/After" table and carried from there. Taking a fresh control measurement is Phase 1's own deliverable |
| `.gate-lock`: `GATE_MUTEX_ACQUIRE_BUDGET_MS` default 600000, `GATE_MUTEX_STALE_SEC` default 1800, two call sites fail OPEN while `acquire_named_mutex` itself fails CLOSED | **CONFIRMED** live in `scripts/task-lock.sh` |
| Batch Gate Deferral is gated on task count | **CONFIRMED** live: `orchestrate-cycle-plan.sh`'s `build_args` composition appends `--batch-gate-deferral` only when the invocation-level `.task_numbers` count is `-gt 1` |
| Move 3 runs only "After ALL Agent calls from Move 2 complete" | **CONFIRMED** verbatim in `skills/skill-orchestrate/SKILL.md`; Move 2's own text requires one message for every Agent call |
| Report's `test-verify-deploy-context-budget.sh` cost of 228,595ms | **CORRECTED**. The live hints row is 30,962ms. The report's figure was itself carried from `shell-script-testing.md` prose and the live hints file now disagrees — Phase 3's scope turns on this, so Phase 3 re-derives it rather than acting on either number |

Two live facts neither the description nor the report records, both of which change the work:

1. **`scripts/dispatch-strand-probe.sh` already exists** and already implements exactly the
   heartbeat-based detector the report proposed building as Q5's fallback: a read-only,
   fail-closed probe that classifies one task's dispatch `live`/`stranded`/`unknown` from a
   three-signal conjunction (heartbeat staleness via `task-lock.sh check`, artifact quiescence,
   commit quiescence), explicitly rejecting process-descendant walks and system load. It is
   consumed today by `orchestrate-cycle-postflight.sh` (as `stranded_suspected`), SKILL.md's Move
   3, and `reconcile-task-status.sh`'s demotion gate — all of them *inside or after* Move 3. The
   missing piece is an invocation site upstream of the blocking wait, not a detector.
2. **A `--cost-class free|moderate|slow|unknown` selection axis already exists** in `run-all.sh`,
   backed by `scripts/lib/suite-selection-lib.sh`'s fixed thresholds
   (`SUITE_SELECTION_COST_FREE_MS=2000`, `SUITE_SELECTION_COST_MODERATE_MS=30000`), validated
   against a closed vocabulary with a loud exit 2 on an unknown token. Slow-suite relocation
   therefore needs no new selection machinery.

Fresh bucket arithmetic over the live hints file (this dispatch, not carried): the `slow` bucket
(>= 30,000ms) is **9 suites totalling 1,077,686ms** — 77% of the aggregate. The non-slow
remainder is **147 suites totalling 328,807ms**, whose longest member is
`test-literature-convert.sh` at 23,724ms. At `--jobs 4` the straggler-bound floor for that
remainder is `max(23,724, 328,807/4 = 82,202) ≈ 82s`, against today's 543,000ms single-suite
floor. That is the arithmetic Phase 2 rests on.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; ROADMAP.md was not
consulted and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- Bring Gate 8's own wall-clock under the 600s foreground ceiling with real headroom, by
  relocating the slow bucket onto its own serialized gate that still runs by default.
- Replace the advisory batch-gate-deferral directive with a mechanical guard that refuses an
  unfiltered battery when a batch close already owes one, covering a batch of one identically to
  a multi-task batch.
- Make a load-induced gate kill mechanically distinguishable from a real failure, for every gate
  rather than only Gate 8.
- Detect a silent dispatch in minutes by invoking the existing strand probe from a watchdog
  launched beside the dispatches, not after them.
- Record a measured idle/loaded baseline with `nproc` and loadavg, and record the `.gate-lock`
  posture ruling durably.

**Non-Goals**:

- **No coverage reduction.** Every suite that runs by default today still runs by default after
  Phase 2. The split changes which *gate* schedules a suite, never whether it runs. Phase 2 and
  Phase 8 each carry an explicit before/after coverage statement.
- No change to `.gate-lock`'s fail-open posture, acquire budget, or staleness window (research
  Q3 ruling, adopted).
- No change to `JOBS_CAP` or `VERIFY_DEPLOY_GATE8_JOBS` defaults (research Q1 ruling, adopted).
- No touched-path suite selection or unmapped-path fallback work — territory edge 650 owns the
  scoped touched-path entry point over `run-all.sh --only`/`--jobs auto`/`--timings` and
  `suite-selection-lib.sh`.
- No orchestration-close *policy* statement about who owns the full battery, and no plan-format
  final-phase invariant change — territory edge 651 owns that. This plan supplies the mechanism
  651's policy needs, designed so a batch of one is covered.
- No gate-mutex *scope* change (per-repository vs. host-wide) — the `host_scoped_gate_mutex`
  record owns scope and inherits this plan's posture ruling.
- No agent-side wait-discipline prose: when to choose a foreground form over a detach form, and
  the arrived-but-unconsumed-notification failure shape in `bounded-build-waiter.md`'s Shape
  Taxonomy, are owned by record 454. This plan touches neither
  `context/patterns/bounded-build-waiter.md` nor `context/patterns/external-process-wait.md`.
- No gate-criteria prose rewrite — territory edge 452 owns baseline-relative criteria. Phase 6
  adds a tag to the executor and nothing to the criteria vocabulary.

**The canonical bounded-waiter idiom is not touched.** This plan achieves the dispatch's stated
preference: no phase edits `bounded-build-waiter.md`'s Canonical Agent-Contract Bullet or its
Forbidden-Shape Lint Anchor, so no consuming agent file needs a same-commit change. Phase 7's new
watchdog *consumes* the idiom (captured `pid=$!`, a `kill -0 "$pid"` liveness loop, an outer
`timeout N`, one Bash call, never `ps | grep` or `pgrep -f`) without restating or amending it;
Phase 8 verifies `lint-agent-contracts.sh` Check K still passes, including its self-trip
exemption.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The slow/non-slow split is read as, or becomes, a coverage reduction | H | M | Both gates run by default in the unfiltered aggregator. Phase 2 states the before/after suite inventory explicitly and asserts set equality (today's discovered set == gate 8's new set ∪ the new gate's set), verified by a test, not by prose |
| The hints file is advisory and optional — if absent, every suite buckets `unknown` and a naive split would run nothing in Gate 8 | H | L | Decision 2: `unknown` goes to Gate 8, and a missing/unreadable hints file degrades to exactly today's behavior (Gate 8 runs everything, the new gate discovers nothing and reports a documented no-op). Pinned by a test fixture with the hints file removed |
| A stale batch-gate-pending sentinel silently disables the full battery everywhere | H | M | The sentinel carries `written_at` and is ignored, with a loud named warning, past a staleness window; the guard refuses only an unfiltered, non-nested, non-guest invocation; a documented override flag exists; and the refusal exits with a distinct status that can never be mistaken for a pass |
| The deferral refusal is mistaken for a green verification | H | M | Decision 3: the refusal uses a new reserved exit status, never 0 and never 1, with the word DEFERRED in its own output line. Phase 5 pins both the status and the text |
| The `[CONTENTION]` WARN tag becomes a way to wave away a genuine intermittent failure | M | M | Keep Gate 8's existing shape exactly: WARN-FINDING, never an auto-pass, never a bound extension, still requiring an explicit Reasoned Exclusion per failure |
| The watchdog's alert cannot interrupt the orchestrator's blocked turn, so the stall is still discovered only at turn end | M | H | Accepted and declared, not hidden (Decision 5). Even in that case the alert is durable and operator-visible at launch time, and Move 3's first act is to read it — strictly better than today's recompute-after-the-fact ordering. Phase 7 records which guarantee was achieved |
| A new runtime marker file needs a new ephemeral gitignore class across four surfaces | M | L | Avoided entirely by Decision 1: the marker lives under the already-ignored `specs/.orchestration/` tree |
| Phase 1's control measurement cannot be taken because another session is active | M | H | Phase 1 carries an explicit decision gate: if the host is not idle, the measurement is deferred to a durable `records/` note with the observed loadavg stated, and the remaining phases proceed. The measurement is a deliverable, never a blocker on the mechanism work |
| Two phases collide on a shared declaration surface (`manifest.json`, `suite-classification.data`, `index-entries.json`) | M | M | The wave map is deliberately near-sequential for exactly this reason; see the Dependency Analysis note |

## Decisions

1. **The batch-gate-pending marker lives at
   `specs/.orchestration/batch-gate-pending-<session_id>.json`**, not at a new top-level
   `specs/.batch-gate-pending`. `specs/.orchestration/` is already ignored wholesale
   (`specs/.gitignore`'s `**/.orchestration/` rule, verified live with `git check-ignore -v`), so
   the marker needs no new ephemeral class. *Rejected alternative*: a new top-level sentinel,
   which would require a new class member in `scripts/lib/runtime-file-patterns.sh`, a
   `.gitignore` entry under the manifest's `root_files`, an
   `context/standards/orchestrator-runtime-files.md` Consumer Repo Setup update, and a change to
   the test that pins those two to each other — four surfaces of cost for no benefit. The
   consumer finds the marker by globbing `batch-gate-pending-*.json` in that directory, so it
   never needs the orchestrator's session id.
2. **The `unknown` cost bucket stays with Gate 8.** `suite-cost-hints.txt` is advisory and
   optional by its own header, so an absent file must not empty Gate 8. Sending `unknown` to the
   relocated slow gate would do exactly that. The cost is that a genuinely slow but unhinted
   suite lands in the bounded gate; Phase 2 mitigates by having the slow gate's own run emit a
   named advisory line for any `unknown`-bucket suite whose measured time exceeds the moderate
   threshold, so the hints file's drift is visible rather than silent.
3. **A deferral refusal exits with a new reserved status, not 0 and not 2.** `verify-deploy.sh`
   and `run-all.sh` both already use 0/1/2 with established meanings (2 = harness failure /
   zero-checks). A deferral is neither a pass, a failure, nor a harness error, and exiting 0
   would let a deferred run be read as green by every existing caller. Phase 5 allocates and
   documents the new status in both scripts' headers and pins it in tests.
4. **Q5's fix is built on background Bash, not on background Agent dispatch.** The report left
   Q5 open pending confirmation that the orchestrator's own session can dispatch an Agent
   asynchronously. That confirmation is not needed: a backgrounded Bash call is available to
   every session, so the watchdog can be launched in the same Move 2 message as the Agent calls
   without depending on any Agent-tool capability. This removes the report's single blocking open
   item rather than deferring it.
5. **The watchdog's guarantee is declared, not assumed.** Whether a background Bash exit
   notification reaches the orchestrator *during* its blocked turn or only at turn end is a
   harness behavior this plan does not assert in either direction. The build is identical either
   way; only the documented guarantee differs (minutes-to-detection within the turn, versus
   minutes-to-detection at the next orchestrator action). Phase 7 observes which holds and
   records it. The orchestrator **never awaits** the watchdog — Move 3 reads its durable alert
   file — so no phase of this plan introduces the detach-then-await-a-notification shape Check K
   forbids.
6. **`.gate-lock`'s posture is unchanged** (research Q3). Phase 1 records the ruling in
   `context/standards/shell-script-testing.md` beside the measured figures, which is the surface
   the dependent `host_scoped_gate_mutex` record reads, so that record inherits a posture it can
   cite rather than re-deriving one.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3, 7 | -- |
| 2 | 2 | 1 |
| 3 | 4 | 2 |
| 4 | 5 | 2, 4 |
| 5 | 6 | 5 |
| 6 | 8 | 1, 2, 3, 4, 5, 6, 7 |

Phases within the same wave can execute in parallel. The map is deliberately near-sequential:
phases 2, 4, 5 and 6 all touch `scripts/verify-deploy.sh` or the shared declaration surfaces
(`manifest.json`, `scripts/tests/suite-classification.data`), and serializing them is cheaper
than reconciling a collision. Wave 1's three phases are genuinely disjoint in file territory.

---

### Phase 1: Measured Baseline and the Gate-Lock Posture Record [COMPLETED]

**Goal**: Produce the record's measured-baseline deliverable under a confirmed-idle control, and
record the `.gate-lock` fail-open posture ruling durably where the dependent record can cite it.

**Tasks**:
- [x] Sample `nproc` and `/proc/loadavg` and decide the gate: if the 1-minute loadavg is at or
      above `measure-gate-costs.sh`'s own `MEASURE_GATE_COSTS_LOAD_THRESHOLD` default, or any
      other session is active, take the **deferred branch** below instead of measuring. *(completed: nproc=24, loadavg 3.42 >= 2.0 threshold, concurrent siblings live — deferred branch taken)*
- [ ] Idle branch: run `bash agent-system/extensions/core/scripts/measure-gate-costs.sh` for a
      Gate 8 / full-battery wall-clock baseline. Reuse this script rather than building an ad hoc
      timing harness — it already averages runs, refuses (exit 2) a measurement taken above its
      load threshold, and protects against overwrite. *(deviation: skipped — host non-idle, deferred branch taken instead)*
- [ ] Idle branch: take a second measurement under representative concurrent load, so the table
      has both the control and the loaded figure the record asks for. *(deviation: skipped — moot without a control measurement to compare against; see records/baseline-deferred.md)*
- [x] Deferred branch: write `records/baseline-deferred.md` under this task directory stating the
      observed `nproc`/loadavg, which sessions were live, and that the control was not taken —
      never a contaminated measurement presented as a control. *(completed)*
- [x] Update `context/standards/shell-script-testing.md`'s "Measured Before/After" section with
      whichever figures were actually obtained, each row carrying `nproc` and the loadavg at
      measurement time, so a future reader can tell a real regression from an environmental one. *(completed: no new measured row added — deferral noted in a new "Gate 8 Ceiling Fit: Control Measurement Deferred" subsection instead, since no figure was obtained)*
- [x] In the same section, record the `.gate-lock` posture ruling: fail-open is kept, with its
      existing loud warning; `GATE_MUTEX_ACQUIRE_BUDGET_MS`, `GATE_MUTEX_STALE_SEC` and the
      fail-open/fail-closed choice are unchanged; the leverage point is the mechanical guard, not
      the mutex; and lock *scope* is a separate, orthogonal question owned elsewhere. State it as
      a current ruling with its grounds, citing the durable anchors (the script and section
      names), never a record number. *(completed: new "Gate Mutex (specs/.gate-lock) Posture Ruling" subsection)*

**Timing**: 1.5 hours (plus unattended measurement wall-clock on the idle branch)

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh context/standards/shell-script-testing.md`
covers this phase's only non-`specs/**` edit, and the measurement itself is self-verifying
(`measure-gate-costs.sh` refuses to record above its own load threshold).

**Scope Hypothesis**: The Gate 8 figures this phase replaces are carried from
`context/standards/shell-script-testing.md`'s own "Measured Before/After" table (457,197ms idle;
662,354ms under load 1.69-2.26, 2 runs averaged) and are expected to be superseded, not
confirmed, by a fresh measurement — the live `suite-cost-hints.txt` aggregate has already moved
since those figures were taken. Confirm by comparing the fresh run's own output against the
table's existing rows and recording both, rather than overwriting the dated figures.

**Files to modify**:
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - fresh baseline rows with nproc/loadavg; the gate-lock posture ruling
- `agent-system/extensions/core/index-entries.json` - this file's `line_count` entry moves when the standard above is edited (coupled generated surface; reconciled by Phase 8's redeploy, which auto-repairs it)
- `agent-system/extensions/core/scripts/gate-cost-model.csv` - written by `measure-gate-costs.sh` on the idle branch only
- `specs/610_full_gate_verification_ceiling_and_stall/records/baseline-deferred.md` - deferred branch only

**Verification**:
- The measured table carries `nproc` and loadavg on every new row, or the deferred-branch record
  exists and names the contaminating sessions.
- `bash agent-system/extensions/core/scripts/verify-touched.sh context/standards/shell-script-testing.md`
  exits 0.
- The posture ruling cites `scripts/task-lock.sh` and the two fail-open call sites by name, and
  contains no record-versioning language and no task-number reference.

---

### Phase 2: Relocate the Slow Bucket onto Its Own Serialized Gate [COMPLETED]

**Goal**: Bring Gate 8's own wall-clock under the 600s foreground ceiling with headroom by
scheduling the slow cost-class bucket as a separate serialized gate, with zero change to which
suites run by default.

**Tasks**:
- [x] Re-derive the bucket split live before editing anything: suite count and aggregate per
      bucket, and the longest member of the non-slow remainder. Record the figures in the phase's
      own commit message or progress notes. *(completed: re-confirmed UNCHANGED from plan-authoring time -- 9 slow / 1,077,686ms aggregate; 147 hinted non-slow / 328,807ms aggregate, longest `test-literature-convert.sh` 23,724ms. Real cross-extension discovery total measured at 209 suites, not 178 (core-only) or 156 (hints-file row count) -- see the deviation below)*
- [ ] Narrow Gate 8's `run-all.sh` invocation to the non-slow buckets by passing the existing
      `--cost-class` axis (`free`, `moderate`, `unknown` per Decision 2), leaving `--jobs`,
      `--fail-on-new`, the `--gate8-touched` narrowing and the `.gate-lock` bracket untouched.
      *(deviation: altered — `--cost-class free,moderate,unknown` was implemented, measured
      live against the real repo, and found to silently DROP 8 real suites from Gate 8's run
      entirely: `suite_selection_by_cost_class`'s own `unknown` bucket is core-extension-scoped
      (`_ssl_discovered_basenames`), a real mismatch against run-all.sh's own cross-extension
      discovery (209 real vs. 178 core-only vs. 156 hinted) that this task does not own
      (territory edge 650). A `--cost-class`-based narrowing would have been a coverage
      regression, forbidden by this task's own Hard Constraint. Replaced with an explicit
      `--only <all discovered minus hints-file-slow>` list, built by replicating run-all.sh's
      own discovery algorithm directly in `gate8_run()` (cited, not duplicated via a shared
      function, since run-all.sh's discovery is inline) — `--jobs`, `--fail-on-new`, the
      `--gate8-touched` narrowing (now intersected with the slow-exclusion, not replaced by it),
      and the `.gate-lock` bracket are all otherwise unchanged. See verify-deploy.sh's own "WHY
      `--only <everything minus slow>` HERE" comment in `gate8_run()` for the full account.*)*
- [x] Add one new registry row for the relocated slow bucket: the next contiguous gate id (Check
      E of `lint-gate-registry.sh` requires contiguity from 1), `serialized=true`,
      `cost_class=slow`, `input_corpus` matching Gate 8's, and a `timeout_s` derived from the
      re-derived slow-bucket aggregate rather than copied from Gate 8's 1500. *(completed: gate
      31, timeout_s=900, derived from the 543,000ms single-suite straggler floor with reasonable
      headroom — well under Gate 8's old 1500s bound and under the 600s foreground ceiling with
      headroom in the one standalone measurement taken this dispatch)*
- [x] Implement that gate's `run` function in `verify-deploy.sh`, mirroring `gate8_run`'s
      structure: the same `.gate-lock` bracket semantics, the same nested/guest guard
      (`VERIFY_DEPLOY_WAS_NESTED_AT_ENTRY`, `GATE_MUTEX_HELD`), the same `[FAIL]` extraction, the
      same `--fail-on-new` EXPECTED/NEW accounting, and the same roster-token prohibition (the
      roster block must never contain the literal `[FAIL]`). *(completed: `gate31_run()` plus its
      own `_gate31_signal_cleanup`, since `_gate8_signal_cleanup` is hardcoded to gate8's own
      mutex-token variables and cannot be shared)*
- [x] Carry Gate 8's `--skip-slow` deferral semantics onto the new gate: `--skip-slow` must defer
      both, so a `--skip-slow` run's coverage is unchanged from today's. *(completed; pinned by
      test case (c))*
- [x] Emit the `unknown`-bucket drift advisory Decision 2 requires: a named advisory line when an
      `unknown`-bucket suite's own measured time exceeds the moderate threshold. *(completed,
      altered in shape: emits one `[COST-DRIFT]` advisory per suite that is both running in gate8
      (non-slow) AND entirely absent from the hints file by basename — the earlier draft compared
      a full suite PATH against the basename-keyed hints file, which never matched and falsely
      flagged every suite; fixed to compare basenames, consistent with the explicit `--only`-list
      mechanism above)*
- [x] Add a test suite pinning: set equality of the before/after discovered-suite inventory; the
      hints-file-absent degradation (Gate 8 runs everything, the new gate is a documented no-op);
      `--skip-slow` deferring both gates; and `--only-gate` selecting each gate independently.
      *(completed: `test-gate-slow-bucket-split.sh`, 9 cases, all passing. Case (a)'s set-equality
      check targets the actual gate-level mechanism (hints-file parse + discovery replica), not
      `suite_selection_by_cost_class` directly, for the reason named in the deviation above. Cases
      (c)/(d) expect exit 2 ("cannot attest") rather than exit 0 for an all-skipped `--only-gate`
      selection — a pre-existing, correct `verify-deploy.sh` guard, not a regression)*
- [x] Declare the new suite: a `provides.scripts` entry in `manifest.json` and a row in
      `scripts/tests/suite-classification.data` (an unclassified live suite is itself a violation
      of `lint-unit-integration-boundary.sh`), plus a fixture-dependency declaration if the suite
      copies helper scripts into a sandbox. *(completed: `lint-fixture-dependency-declaration.sh`'s
      own predicate confirmed this suite does not qualify — its one `cp` destination carries no
      `.claude/scripts` path segment — so no fixture-dependency declaration was needed)*
- [x] Write the explicit before/after coverage statement into the gate's own header comment: the
      suite inventory is unchanged; only the scheduling gate differs. *(completed, both
      `gate8_run()`'s and `gate31_run()`'s own header comments)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: interface

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh scripts/gate-registry.data scripts/verify-deploy.sh`
covers the gate-inventory consumers this edit reaches — gate selection, the gate cache, registry
resolution and the crash-net — which is the full one-hop dependent set for a registry row plus a
new gate function.

**Scope Hypothesis**: The split is hypothesized to be 9 slow suites (1,077,686ms) against 147
non-slow suites (328,807ms aggregate, longest member 23,724ms), giving a straggler-bound
non-slow floor near 82s at `--jobs 4` — derived fresh from the live `suite-cost-hints.txt` at
plan-authoring time. Confirm by re-deriving both buckets at implementation time before choosing
the new gate's `timeout_s`; the hints file turns over continuously and the floor figure is the
basis for the headroom claim.

**Files to modify**:
- `agent-system/extensions/core/scripts/gate-registry.data` - one new serialized slow-bucket gate row
- `agent-system/extensions/core/scripts/verify-deploy.sh` - Gate 8's `--cost-class` narrowing; the new gate's run function; `--skip-slow` coverage for both; header coverage statement
- `agent-system/extensions/core/scripts/tests/test-gate-slow-bucket-split.sh` - new suite pinning set equality, hints-absent degradation, `--skip-slow`, and independent `--only-gate` selection
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - classification row for the new suite
- `agent-system/extensions/core/manifest.json` - `provides.scripts` entry for the new suite

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-gate-registry.sh` passes, including Check
  E's contiguity check.
- The new test suite passes, including its set-equality case and its hints-file-absent case.
- `bash agent-system/extensions/core/scripts/verify-touched.sh scripts/gate-registry.data scripts/verify-deploy.sh`
  exits 0.
- A timed Gate 8 run reports a wall-clock under 600s, with the measured figure recorded.

---

### Phase 3: Narrow the Self-Re-Entrant Nested Battery Call Site [COMPLETED]

**Goal**: Stop (or confirm the absence of) a suite inside Gate 8 re-invoking the full
`verify-deploy.sh` battery, which makes the gate tree re-enter itself.

**Tasks**:
- [x] Re-derive the live cost of `test-verify-deploy-context-budget.sh` and the live shape of its
      `verify-deploy.sh` call sites before editing. The two available figures disagree (30,962ms
      in the live hints file against 228,595ms carried in the research report), so neither is
      acted on directly. *(completed: live hints file confirms 30,962ms)*
- [x] Enumerate that suite's `verify-deploy.sh` invocations and classify each as full-battery or
      `--only-gate` scoped. *(completed: 4 invocations — two `--only-gate 20` scoped, one baseline at `--skip-slow --max-cost moderate` with no `--only-gate`, one non-invocation existence check)*
- [ ] If a full-battery (even `--skip-slow`) invocation remains, narrow it to the `--only-gate`
      scoped form its sibling call sites already use, preserving exactly what the assertion needs
      to observe. If narrowing would change what the suite can assert, leave it and record why in
      the suite's own header instead. *(deviation: skipped — no-op branch taken, see below)*
- [x] **No-op branch**: if no full-battery invocation remains (plausible given the cost
      movement), record that finding in the suite's header comment and close the phase with no
      functional change — a confirmed absence is the phase's legitimate outcome, not a skip.
      *(completed: the one non-`--only-gate` invocation was already narrowed to `--max-cost moderate`
      by prior work with its own rationale recorded; added a "RE-ENTRANT-BATTERY CHECK" paragraph
      to the suite's header confirming the live re-derivation and the absence of any remaining
      full-battery call site)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh scripts/tests/test-verify-deploy-context-budget.sh`
covers this phase's one edited file, resolving to test-verify-deploy-context-budget.sh,
test-run-all-parallel.sh, test-verify-deploy-gate-selection.sh and
test-verify-deploy-gate-selection-crash-net.sh.

**Scope Hypothesis**: Hypothesized that at most one full-battery `verify-deploy.sh --skip-slow`
call site remains in that suite, and that its own cost is now near 30,962ms rather than the
228,595ms carried in the research report from `context/standards/shell-script-testing.md`'s
recursive-component discussion. Confirm by enumerating the call sites and timing the suite
directly before deciding between the narrowing branch and the no-op branch.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh` - narrow the full-battery call site, or record the confirmed absence in its header

**Verification**:
- The suite passes standalone.
- `bash agent-system/extensions/core/scripts/verify-touched.sh scripts/tests/test-verify-deploy-context-budget.sh`
  exits 0.
- The suite's header states, with the re-derived figure, which branch was taken.

---

### Phase 4: Batch-Gate-Pending Marker Lifecycle [COMPLETED]

**Goal**: Write a durable, staleness-bounded marker whenever this invocation's batch gate stage
will run, and remove it when that stage discharges — the producer half of the mechanical guard,
covering a batch of one identically to a multi-task batch.

**Tasks**:
- [x] Write `specs/.orchestration/batch-gate-pending-<session_id>.json` from
      `orchestrate-cycle-plan.sh` whenever this cycle dispatches at least one `implement` phase,
      carrying `session_id`, `pid`, `written_at`, the invocation's task numbers, and the per-task
      `dispatch_seq`. Gate it on "at least one implement dispatch occurred", matching
      `batch-gate-stage.md`'s own trigger — **never** on task count. *(completed: gated on the
      FINAL `.implement_agents` map's own length, read once after the whole per-task loop
      completes — the exact same emptiness test `orchestrate-batch-gate.sh`'s own no-op check
      already uses)*
- [x] Remove the `-gt 1` task-count gate on the `--batch-gate-deferral` directive so a
      single-task implement invocation receives the same directive as a batch, closing the
      single-task invariance gap `batch-gate-stage.md` documents. *(completed)*
- [x] Remove the marker from `orchestrate-batch-gate.sh` once its own run has completed and its
      `batch_gate` record is written — the discharge point, so the marker's lifetime matches the
      owed obligation exactly. *(completed; never on the --dry-run or no-op paths, matching those
      paths' own no-mutation contracts)*
- [x] Make removal idempotent and failure-tolerant: a missing marker at discharge is normal (a
      research-only invocation never wrote one) and must not fail the stage. *(completed: bare
      `rm -f ... || true`)*
- [x] Define the staleness window in one place and document it, so a crashed orchestrator cannot
      wedge verification: a marker older than the window is ignored by consumers with a loud,
      named warning. *(completed: new `scripts/lib/batch-gate-marker-lib.sh`,
      `BATCH_GATE_MARKER_STALE_SEC` default 3600s, sourced by both the writer and the
      discharger; Phase 5's entry guards will be its third consumer)*
- [x] Update `context/contracts/batch-gate-stage.md`: the directive is no longer task-count
      gated, the marker is the mechanical half, and its single-task invariance section now
      describes the new behavior. *(completed; also records the Phase 5 entry-guard contract
      up front, since both phases land in the same body of work)*
- [x] Add a test suite pinning: marker written on an implement dispatch including a batch of one;
      not written on a research-only or plan-only invocation; removed at discharge; idempotent
      removal with no marker present; and the staleness window honored. *(completed, split across
      three homes rather than one dedicated fixture: the write-side cases (batch-of-one write,
      research-only non-write) were added to `test-orchestrate-cycle-plan.sh`'s own Group 4/5,
      reusing its already-live, non-dry-run implement-dispatch fixture rather than re-deriving
      one; the discharge-removal/idempotency/dry-run cases were added as `test-orchestrate-batch-gate.sh`'s
      own Case 11; and the new `test-batch-gate-pending-marker.sh` owns the library's own pure
      functions -- path construction, staleness-window honoring (including the exact-boundary
      and malformed-input fail-open cases), and the warning text)*
- [x] Declare the new suite in `manifest.json` `provides.scripts` and
      `scripts/tests/suite-classification.data`. *(completed, plus the new library file itself)*

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: interface

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh scripts/orchestrate-cycle-plan.sh scripts/orchestrate-batch-gate.sh`
covers the cycle-plan and batch-gate consumers whose dispatch composition and state writes this
phase changes.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - write the marker on an implement dispatch; drop the `-gt 1` directive gate
- `agent-system/extensions/core/scripts/orchestrate-batch-gate.sh` - remove the marker at discharge, idempotently
- `agent-system/extensions/core/context/contracts/batch-gate-stage.md` - the marker mechanism; the un-gated directive; the revised single-task invariance statement
- `agent-system/extensions/core/index-entries.json` - `line_count` for the contract file above (coupled generated surface; reconciled by Phase 8's redeploy)
- `agent-system/extensions/core/scripts/tests/test-batch-gate-pending-marker.sh` - new suite pinning the write/removal/staleness/batch-of-one cases
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - classification row for the new suite
- `agent-system/extensions/core/manifest.json` - `provides.scripts` entry for the new suite

**Verification**:
- The new suite passes, including the batch-of-one write case and the staleness case.
- A dry-run invocation writes no marker (matching `orchestrate-batch-gate.sh`'s existing
  no-mutation dry-run contract).
- `bash agent-system/extensions/core/scripts/verify-touched.sh scripts/orchestrate-cycle-plan.sh scripts/orchestrate-batch-gate.sh`
  exits 0.
- `git check-ignore -q specs/.orchestration/batch-gate-pending-sess_probe.json` succeeds, so no
  new gitignore class is needed.

---

### Phase 5: Entry Guards That Mechanically Refuse a Deferred Unfiltered Battery [COMPLETED]

**Goal**: Make a nested unfiltered full battery a structural no-op returning a documented
deferral, rather than a directive three of three dispatches can ignore — the consumer half of the
guard.

**Tasks**:
- [x] Add an entry guard to `verify-deploy.sh`: when a non-stale marker exists, this invocation is
      **not** nested (`VERIFY_DEPLOY_WAS_NESTED_AT_ENTRY`) and **not** a guest
      (`GATE_MUTEX_HELD`), the invocation is unfiltered (no `--only-gate`, no `--gate8-touched`),
      and no override was passed, refuse before any gate runs and print a DEFERRED line naming
      the marker's session and age. *(completed; also prints any stale/malformed markers'
      warning unconditionally, not nested inside the pending branch — a bug caught by this
      phase's own test suite, since a stale marker is by definition never "pending", so the
      warning call would otherwise be unreachable)*
- [x] Add the parallel guard to `run-all.sh`'s top level for the bare-suite-runner path, scoped
      the same way: unfiltered only (no `--only`, no `--class`/`--tag`/`--cost-class`), non-nested
      (`RUN_ALL_WAS_NESTED_AT_ENTRY`), non-guest. *(completed)*
- [x] Exit with the new reserved status per Decision 3 — never 0, never 1, never 2 — and document
      it in both scripts' exit-code headers alongside the existing codes. *(completed: exit 3,
      confirmed unused by either script beforehand)*
- [x] Add the documented override flag and have `orchestrate-batch-gate.sh` pass it, since that
      stage is the discharger and must never refuse itself. Verify the nested/guest path is
      byte-identical to today's, so a suite running under Gate 8 is unaffected. *(completed:
      `--override-batch-gate-deferral` on both scripts, passed by orchestrate-batch-gate.sh's own
      two deploy_findings_snapshot calls; the nested/guest conditions are checked identically to
      every pre-existing bracket in both files, so a suite running under gate 8/31 is unaffected
      by construction — it never reaches either top-level guard in the first place)*
- [x] Leave every scoped invocation unguarded: `--only-gate N`, `--only SUITE`, the
      `--cost-class`/`--class`/`--tag` axes, and `--gate8-touched` must all behave exactly as
      today whether or not a marker exists. *(completed; confirmed by Case 8 and by
      gate8_run/gate31_run's own internal `--only` invocations never even reaching run-all.sh's
      guard, since ONLY_SUITES is non-empty by construction once Phase 2 landed)*
- [x] Extend the Phase 4 suite (or add a sibling) pinning: a seeded unfiltered call is refused
      with the reserved status; a seeded scoped call is not; a nested call defers to the existing
      guest path unchanged; a stale marker is ignored with the warning; the override is honored;
      and an absent marker leaves output byte-identical to today's. *(completed: 7 new cases
      (Cases 7-13) in the same `test-batch-gate-pending-marker.sh` the Phase 4 note already named
      as the likely extension point; one test-authoring bug found and fixed along the way — a
      stray duplicate run-all.sh invocation that ran the real unfiltered battery before the
      marker was seeded, hanging the suite — and one production bug found and fixed, see above)*
- [x] Record the mechanism in `context/contracts/batch-gate-stage.md`'s own Trigger/discharge
      narrative, so the contract and the code cannot drift. *(completed in Phase 4's own
      commit, since both phases' documentation landed together — see that phase's own checklist
      note)*

**Timing**: 2 hours

**Depends on**: 2, 4

**Verification Tier**: interface

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh scripts/verify-deploy.sh scripts/tests/run-all.sh`
covers the gate-selection, gate-lock, run-all-selection and batch-gate consumers that read both
scripts' entry behavior and exit codes.

**Scope Hypothesis**: Hypothesized that the two entry guards are the only call sites needing the
check — `verify-deploy.sh`'s top-level entry and `run-all.sh`'s top level — because those are the
two sites that acquire `.gate-lock` for an unfiltered battery today. Confirm at implementation
time by enumerating every `acquire_gate_mutex` caller before writing the second guard; a third
caller would need the same treatment.

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` - entry guard, reserved deferral status, override flag, header exit-code documentation
- `agent-system/extensions/core/scripts/tests/run-all.sh` - parallel top-level entry guard and header documentation
- `agent-system/extensions/core/scripts/orchestrate-batch-gate.sh` - pass the override so the discharger never refuses itself
- `agent-system/extensions/core/context/contracts/batch-gate-stage.md` - the guard's refusal contract and reserved status
- `agent-system/extensions/core/index-entries.json` - `line_count` for the contract file above (coupled generated surface; reconciled by Phase 8)
- `agent-system/extensions/core/scripts/tests/test-batch-gate-pending-marker.sh` - refusal/scoped/nested/stale/override/absent cases

**Verification**:
- Every case above passes: seeded unfiltered refused with the reserved status; seeded scoped not
  refused; nested path unchanged; stale ignored with a warning; override honored; absent marker
  byte-identical.
- `bash agent-system/extensions/core/scripts/verify-touched.sh scripts/verify-deploy.sh scripts/tests/run-all.sh`
  exits 0, and the exit status is checked, not only the output text.

---

### Phase 6: Generalize Contention Tagging to Every Gate's Timeout Kill [COMPLETED]

**Goal**: Make a load-induced gate kill mechanically distinguishable from a real failure for
every gate, by extending the proven Gate-8-only mechanism rather than inventing a new one.

**Tasks**:
- [x] Re-derive the gate inventory and which gates carry no contention signal today, before
      editing. *(completed: the live registry now carries 31 rows, not 30 -- Phase 2 added gate
      31 since this plan's Scope Hypothesis was authored. 30 of 31 carry no contention signal
      (only gate 8's own bespoke GATE8_CONTENTION_DETECTED exists); confirmed by grep, no third
      signal site found)*
- [x] Extend `gate_registry_exec_bounded`'s timeout-kill path (and the concurrent pool's own
      per-id `124` branch) to sample `/proc/loadavg` at entry and at kill time for any gate whose
      process its declared bound actually killed. *(completed, altered in SITING: the sampling
      itself lives in the two CALLERS of `gate_registry_exec_bounded` --
      `_greg_pool_job` for the concurrent path, and verify-deploy.sh's own generic per-gate loop
      for the sequential path -- rather than inside `gate_registry_exec_bounded` itself, since
      that function cannot see a per-id output directory/id pair for the sequential call site
      (a bare `mktemp` file, not a `$dir/out.$id`-shaped path) and runs in a BACKGROUNDED
      subprocess under the pool path, where a plain global-variable return would not propagate
      back to the caller. Both callers already know their own id and kill/no-kill outcome, so
      sampling at the call site was the natural fit; `gate_registry_exec_bounded`'s own
      signature and behavior are unchanged*)*
- [x] Reuse Gate 8's two-signal model and its env-overridable defaults verbatim rather than
      inventing new names or thresholds: the entry-loadavg threshold and the mutex-wait fraction
      already defined for `GATE8_CONTENTION_DETECTED`, whose load threshold deliberately matches
      `measure-gate-costs.sh`'s own default. *(completed for the load threshold
      (`GATE8_CONTENTION_LOAD_THRESHOLD`, read verbatim, same 2.0 default, no new env var name);
      the mutex-wait fraction is NOT generalized -- it is specific to Gate 8's own
      `specs/.gate-lock` acquire, which most gates never touch at all, so there is no generic
      analog to reuse. This generic mechanism is load-only by nature, stated explicitly rather
      than silently narrowed)*
- [x] Tag a load-correlated kill as a `[CONTENTION]` WARN-FINDING, mirroring Gate 8's existing
      annotation exactly. **Never** extend the bound, never auto-pass, and never reclassify a
      failure as a pass — a genuinely slow or broken gate must stay distinguishable from a
      load-killed healthy one, and a Reasoned Exclusion is still required per failure.
      *(completed; pinned by case1/case2/case3)*
- [x] Add a test suite pinning: a killed gate under a seeded high load tags `[CONTENTION]`; a
      killed gate under a seeded low load does not; the tag never changes the gate's verdict; and
      Gate 8's own existing annotation path is unchanged. *(completed:
      `test-gate-contention-tagging.sh`, 8 cases including both the sequential and concurrent-
      pool paths, built on the pre-existing `gate_store_fixture_build` scaffold rather than a
      from-scratch fixture)*
- [x] Declare the new suite in `manifest.json` and `scripts/tests/suite-classification.data`.
      *(completed, plus a fourth now-latent fixture suite --
      `test-orchestrate-unwind-dispatch.sh`, found by `lint-fixture-dependency-declaration.sh` --
      needing the same `batch-gate-marker-lib.sh` fixture-copy fix Phase 4/5 already applied to
      three siblings)*
- [x] Do **not** edit gate-criteria prose or introduce a baseline-relative criterion — that is
      territory edge 452's. This phase adds a tag at the executor and nothing to the vocabulary.
      *(confirmed: no gate-criteria file touched)*

**Timing**: 2 hours

**Depends on**: 5

**Verification Tier**: interface

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh scripts/lib/gate-registry-lib.sh scripts/verify-deploy.sh`
covers the registry-resolution, gate-cache and gate-selection consumers of the executor whose
kill path this phase changes.

**Scope Hypothesis**: Hypothesized that 29 of the 30 live gate rows carry no contention signal
today (only Gate 8 does), and that `gate_registry_exec_bounded` plus the concurrent pool's `124`
branch are the only two kill sites needing the sample. Confirm by enumerating the registry rows
and the `124` return sites at implementation time before writing the sampling code.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/gate-registry-lib.sh` - entry/kill-time loadavg sampling on the bounded and pooled kill paths
- `agent-system/extensions/core/scripts/verify-deploy.sh` - emit the generic `[CONTENTION]` WARN-FINDING; share Gate 8's thresholds rather than duplicating them
- `agent-system/extensions/core/scripts/tests/test-gate-contention-tagging.sh` - new suite pinning the tagged/untagged/verdict-unchanged/gate-8-unchanged cases
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - classification row for the new suite
- `agent-system/extensions/core/manifest.json` - `provides.scripts` entry for the new suite

**Verification**:
- The new suite passes all four cases.
- A seeded contention tag demonstrably does not change the gate's pass/fail verdict.
- `bash agent-system/extensions/core/scripts/verify-touched.sh scripts/lib/gate-registry-lib.sh scripts/verify-deploy.sh`
  exits 0.

---

### Phase 7: Dispatch Watchdog Launched Beside the Dispatches, Not After Them [COMPLETED]

**Goal**: Detect a silent dispatch in minutes by invoking the existing strand probe from a
bounded watchdog the orchestrator launches in the same message as its Agent calls, so detection
is no longer wired downstream of the event it must detect the absence of.

**Tasks**:
- [x] Write `scripts/orchestrate-dispatch-watchdog.sh`: given this cycle's task numbers, a poll
      interval and a hard outer bound, poll `dispatch-strand-probe.sh` per task and act on the
      first `stranded` verdict. Never re-implement staleness, never walk process descendants, and
      never use `ps | grep` or `pgrep -f` — the probe already owns all three refusals and is
      fail-closed (`unknown` is never `stranded`). *(completed)*
- [x] Use the canonical bounded-waiter idiom internally — captured `pid=$!`, a `kill -0 "$pid"`
      liveness loop, an outer `timeout N`, all inside one Bash call — consuming the idiom without
      editing `bounded-build-waiter.md`'s copied Canonical Agent-Contract Bullet or its
      Forbidden-Shape Lint Anchor. *(completed: realized across two sites rather than one, since
      the watchdog itself is never awaited — SKILL.md's Move 2 launch captures `pid=$!` on the
      backgrounded watchdog process; the watchdog's own internal sweep loop is bounded by a
      foreground `timeout "$OUTER_BOUND"` re-exec of itself, the simpler form
      bounded-build-waiter.md's own text prefers over the detach form whenever a command fits
      foreground; Move 4's cleanup performs a single non-blocking `kill -0 "$pid"` check — never
      a loop, since the orchestrator never awaits this process — to reap it if still running)*
- [x] On a strand verdict, write a durable alert row keyed by `{task, dispatch_seq}` and print a
      loud operator-visible line naming the task, its heartbeat age and the probe's verdict; then
      exit non-zero naming the task. *(completed)*
- [x] Launch the watchdog from Move 2 as one backgrounded Bash call covering that cycle's
      dispatched tasks, issued in the same message as the Agent calls. The orchestrator **never
      awaits it** — stating this explicitly in SKILL.md, because awaiting a notification is the
      exact shape Check K forbids. *(completed)*
- [x] Make Move 3's first act reading the alert file and routing any alert into the existing
      one-re-prompt relay, reusing the `stall_reprompted[]` `{task, dispatch_seq}` idempotency key
      unchanged so exactly one re-prompt fires per dispatch_seq regardless of which signal
      arrived. *(completed: folds into `stranded_suspected` before the existing relay logic, so
      the idempotency key and relay path are unchanged)*
- [x] Observe and record which guarantee the harness actually delivers (Decision 5): whether the
      background exit notification reaches the orchestrator during its blocked turn, or only at
      turn end. Record the observed behavior in the watchdog's own header; assert neither
      outcome without observing it. *(completed: recorded in the watchdog's own header — the
      question is moot by construction for this mechanism, not merely unobserved, since nothing
      downstream ever consumes this process's exit or notification at all; Move 3 reads the
      alert FILE on its own schedule instead, so detection latency is bounded by
      `--poll-interval` and by Move 3's own cadence, neither a notification-timing claim)*
- [x] Add a test suite pinning: a seeded stranded task produces an alert row and a non-zero exit;
      a seeded `live` or `unknown` verdict produces neither; the outer bound terminates the loop;
      the alert is idempotent per `{task, dispatch_seq}`; and the forbidden process-lookup shapes
      are absent from the script. *(completed: 10 cases, all passing standalone)*
- [x] Declare the script and its suite in `manifest.json` `provides.scripts` and the suite in
      `scripts/tests/suite-classification.data`; satisfy the test-root-resolution and
      fixture-dependency declaration conventions the corresponding lints enforce. *(completed)*

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: interface

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh skills/skill-orchestrate/SKILL.md scripts/dispatch-strand-probe.sh`
covers the stall-reprompt wiring, cycle-postflight and strand-probe consumers that read the Move
2/3 contract and the probe's verdict vocabulary.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-dispatch-watchdog.sh` - new bounded watchdog over `dispatch-strand-probe.sh`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Move 2 launches the watchdog in the same message, never awaited; Move 3 reads the alert file first and routes it into the existing relay
- `agent-system/extensions/core/scripts/tests/test-orchestrate-dispatch-watchdog.sh` - new suite pinning the stranded/live/unknown/bound/idempotency/forbidden-shape cases
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - classification row for the new suite
- `agent-system/extensions/core/manifest.json` - `provides.scripts` entries for the new script and suite

**Verification**:
- The new suite passes every case, including the absence of `ps | grep`/`pgrep -f`.
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` passes, Check K
  included — the watchdog introduces no detach-then-await-a-notification shape.
- `bash agent-system/extensions/core/scripts/verify-touched.sh skills/skill-orchestrate/SKILL.md scripts/dispatch-strand-probe.sh`
  exits 0.
- The watchdog's header records the observed notification-timing behavior and the guarantee it
  therefore provides.

---

### Phase 8: Redeploy, Full Gate Set, and the Coverage Statement [COMPLETED WITH EXCLUSIONS]

**Goal**: Deploy every source-store change into the live tree and verify the whole record against
the complete gate set, with an explicit statement that default coverage is unchanged.

**Tasks**:
- [x] Redeploy via `deploy-headless.sh` so every edited source-store file reaches the live
      `.claude/` tree. Several phases above touch indexed `context/**` files, whose
      `index-entries.json` `line_count` entries this regeneration auto-repairs — that is the
      reconciliation the earlier phases' coupled-surface declarations defer to. *(completed:
      multiple redeploys across this phase as residual bugs were found and fixed; final redeploy
      landed with only the pre-existing Gate 27 finding remaining)*
- [x] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (source-store path:
      `agent-system/extensions/core/scripts/verify-deploy.sh`). Note that a source-store
      directory has no `.claude/` subdirectory, so the `TARGET` must be the repository root that
      holds both the deployed tree and `agent-system/extensions` — not `source_dir`. *(completed:
      four full-battery runs plus two scoped gate-8-only timing runs, all under sustained
      non-idle host load (loadavg 4-12 throughout); see Reasoned Exclusions below for the
      residual findings and the live bugs this process itself discovered and fixed)*
- [x] Run `bash .claude/scripts/lint/lint-agent-contracts.sh` and confirm Check K passes,
      including its self-trip exemption, and that no copied contract bullet changed. *(completed:
      394 passed, 12 pre-existing warnings, 0 failed, Check K unaffected)*
- [x] Record the final before/after coverage statement: the discovered-suite inventory running by
      default is unchanged; the slow bucket moved gate, not status; `--skip-slow` defers both
      gates exactly as it deferred one. *(completed; see this phase's own Verification section
      below and Phase 2's own set-equality test proof)*
- [x] Record the achieved Gate 8 wall-clock against the 600s ceiling, with `nproc` and loadavg,
      and state the headroom. *(completed: 349s measured twice independently (5m50s at loadavg
      4.15, 5m49s at loadavg 7.22; nproc=24 both times) against the 600s ceiling — 251s/~42%
      headroom, under real non-idle load, not a clean idle control (see Phase 1's own deferred
      baseline for why an idle control was never available this dispatch))*
- [x] Confirm no file landing under `agent-system/**` carries a task-number reference or
      record-versioning language. *(completed: check-task-references.sh reports 0 unexempted
      occurrences; check-record-versioning.sh reports 0 BLOCKING, 796 pre-existing ADVISORY
      findings in files this task never touched)*

**Timing**: 1.5 hours (plus full-battery wall-clock)

**Depends on**: 1, 2, 3, 4, 5, 6, 7

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`, an implicit scope claim over the entire deployed tree
- `agent-system/extensions/core/index-entries.json` - `line_count` entries reconciled by the regeneration above
- `specs/610_full_gate_verification_ceiling_and_stall/summaries/01_gate-ceiling-fit-and-stall-detection-summary.md` - completion summary with the coverage statement and the measured headroom

**Verification**:
- `bash .claude/scripts/verify-deploy.sh <repo_root>` exits 0, or every residual finding carries
  a Reasoned Exclusion.
- `bash .claude/scripts/lint/lint-agent-contracts.sh` exits 0 with Check K passing.
- `bash .claude/scripts/check-task-references.sh` and the record-versioning lint report no new
  occurrence under `agent-system/**`.
- The measured Gate 8 wall-clock is recorded, under 600s, with `nproc` and loadavg stated.

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Gate 27 (`lint-subject-resolution-declaration.sh`): 3 unmigrated `common_test_resolve_candidate` call sites (`test-suite-resolver-lib.sh`, `test-unmapped-fallback-lib.sh`, `test-verification-scope-lib.sh`) | Confirmed pre-existing, unrelated to this task's `file_scope` — none of the three files were touched by any phase. Observed identically during Phase 4's own mid-dispatch `verify-touched.sh` run, before Phase 5/6/8 began, ruling out a regression introduced later in this dispatch. | `bash agent-system/extensions/core/scripts/lint/lint-subject-resolution-declaration.sh --verbose` names all three by path, unchanged across every run in this phase; `git log` shows no commit in this task touching any of the three files. |
| `test-mcp-merge-target.sh`: Assertions C/E fail (hand-written `.mcp.json` entries not surviving a regenerate/unload cycle) | Confirmed pre-existing, unrelated to this task — the suite exercises `merge_targets.mcp`/`merge.lua`, a deploy-engine mechanism this task's `file_scope` never touches. Fails identically whether run standalone (no load, no nesting) or inside the full battery. | `bash agent-system/extensions/core/scripts/tests/test-mcp-merge-target.sh` fails Assertions C and E standalone, independent of any full-battery run. |
| `test-gate-lock.sh`: fails only when run nested inside gate 8's own `run-all.sh` (never standalone) | Pre-existing structural vulnerability to the SAME nested-env-inheritance hazard this phase found and fixed in `test-batch-gate-pending-marker.sh` (`RUN_ALL_NESTED`/`VERIFY_DEPLOY_NESTED`/`GATE_MUTEX_HELD`, exported by the OUTER gate-8 `run-all.sh`, silently inherited by this suite's own internal `verify-deploy.sh` subprocess calls, exempting them from the very behavior under test). Out of this task's `file_scope` — `test-gate-lock.sh` was never touched by any phase, and fixing a sibling suite's own pre-existing structural issue is a separate, worthwhile follow-up this task does not claim. | `bash agent-system/extensions/core/scripts/tests/test-gate-lock.sh` passes 27/0 standalone; `RUN_ALL_NESTED=1 VERIFY_DEPLOY_NESTED=1 GATE_MUTEX_HELD=1 bash .../test-gate-lock.sh` reproduces 4 failures deterministically, the identical mechanism this phase's own fix for `test-batch-gate-pending-marker.sh` addresses (see that suite's own "ANTI-RECURSION / ANTI-INHERITANCE INVARIANT" header comment). |
| Gate 8 own-suite-pool transient load effects observed across 4 full-battery runs this phase, beyond the three items above | The host carried sustained non-idle load (loadavg 4-12) throughout this entire dispatch due to multiple concurrent sibling `/orchestrate` sessions never under this task's control; an idle control was never available (same condition Phase 1's own deferred-baseline record names). Every OTHER suite flagged as a "NEW" failure in any one run reproduced none of these three items and passed cleanly standalone on direct re-check, confirming transient, load-correlated flakiness rather than a regression — the exact phenomenon this task's own research documented (finding (c)) and the generalized `[CONTENTION]` tag (Phase 6) is designed to surface, which it did: every full-battery run recorded a `[CONTENTION] gate8: entry 1-minute load average N.NN (>= 2.0)` line. | Four full-battery run logs (this task directory's own progress notes cite each); direct standalone re-checks of every flagged suite other than the three named above, each passing cleanly; `[CONTENTION]` WARN-FINDING lines present in every run. |

## Testing & Validation

- [x] Gate 8's measured wall-clock is under 600s, recorded with `nproc` and loadavg. (349s twice, nproc=24, loadavg 4.15 and 7.22)
- [x] The discovered-suite inventory is provably unchanged across the gate split (set equality,
      pinned by a test, not asserted in prose). (`test-gate-slow-bucket-split.sh` case(a))
- [x] A missing `suite-cost-hints.txt` degrades the split to exactly today's behavior. (case(b))
- [x] A seeded unfiltered `verify-deploy.sh`/`run-all.sh` call is refused with the reserved
      deferral status while a marker is pending; a seeded scoped call is not. (`test-batch-gate-pending-marker.sh` Cases 7-8)
- [x] A nested or guest invocation's behavior is byte-identical to today's. (Cases 9-10)
- [x] A stale marker is ignored with a loud named warning; the override flag is honored; the
      batch-gate discharger never refuses itself. (Cases 11-12; `test-orchestrate-batch-gate.sh` Case 11)
- [x] A batch of one writes the marker and receives the deferral directive, identically to a
      multi-task batch. (`test-orchestrate-cycle-plan.sh` Group 4/5)
- [x] A load-correlated gate kill tags `[CONTENTION]` as a WARN and never changes the verdict. (`test-gate-contention-tagging.sh`, and live in every full-battery run)
- [x] A seeded stranded dispatch produces a durable alert and a non-zero watchdog exit; `live` and
      `unknown` produce neither; the outer bound terminates the loop. (`test-orchestrate-dispatch-watchdog.sh`)
- [x] `lint-agent-contracts.sh` Check K passes and no copied contract bullet changed. (394 passed, 12 pre-existing warnings, 0 failed)
- [x] `lint-gate-registry.sh` Check E (contiguity) passes with the new gate row. (7 passed, 0 failed)
- [x] No unclassified live suite (`lint-unit-integration-boundary.sh`). (0 violations after this phase's own misclassification fix)
- [x] The complete gate set passes after redeploy, with exclusions. (see Reasoned Exclusions above: 1 of 41/43 fast-plus-full checks failed across runs, fully accounted for)

## Artifacts & Outputs

- `specs/610_full_gate_verification_ceiling_and_stall/plans/01_gate-ceiling-fit-and-stall-detection.md` (this plan)
- A measured baseline table in `context/standards/shell-script-testing.md`, or
  `records/baseline-deferred.md` if the control window was unavailable
- One new serialized slow-bucket gate row and its run function
- `scripts/orchestrate-dispatch-watchdog.sh`
- Four new test suites: the gate split, the batch-gate marker and its entry guards, contention
  tagging, and the dispatch watchdog
- A durable `.gate-lock` posture ruling the dependent scope record can cite
- `specs/610_full_gate_verification_ceiling_and_stall/summaries/01_gate-ceiling-fit-and-stall-detection-summary.md`

## Rollback/Contingency

Every phase is independently revertable and each lands as its own commit, so the cheapest
contingency is reverting the offending phase's commit and redeploying.

Phase-specific contingencies, in descending order of concern:

- **The marker guard misfires and verification stops running.** Highest-severity failure mode,
  because it is silent in the wrong direction. Three independent escapes exist by design: delete
  the marker file (it lives in an ignored runtime directory and nothing depends on its
  persistence), wait out the staleness window, or pass the documented override. If the guard
  misbehaves at all, revert Phase 5 and leave Phase 4's marker in place — the marker alone is
  inert without a consumer.
- **The gate split loses coverage.** Revert Phase 2's registry row and the Gate 8 narrowing; the
  `--cost-class` axis it uses is pre-existing and unchanged, so there is nothing else to undo.
- **The contention tag confuses triage.** Revert Phase 6; it is additive annotation only and
  changes no verdict.
- **The watchdog misreports.** Revert Phase 7's Move 2 launch step; the probe it wraps is
  pre-existing and is left untouched.

If an intentional rollback must discard uncommitted work, snapshot first per
`context/contracts/recovery.md`'s rollback rung, using the invocation shape recorded there
(including its out-of-scope override flag where the revert reaches beyond this task's declared
`file_scope`) rather than a bare precautionary checkpoint.
