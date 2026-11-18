# Research Report: Task 610

**Task**: 610 - Full gate verification ceiling and stall
**Started**: 2026-11-18T22:50:00Z
**Completed**: 2026-11-18T22:55:00Z
**Effort**: large (5 research questions, infrastructure-wide)
**Dependencies**: Task 476, Task 607
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/gate-registry.data`, `scripts/verify-deploy.sh`,
  `scripts/task-lock.sh`, `scripts/tests/run-all.sh`, `scripts/lib/gate-registry-lib.sh`,
  `scripts/measure-gate-costs.sh`, `scripts/orchestrate-build-dispatch.sh`,
  `scripts/orchestrate-cycle-plan.sh`, `skills/skill-orchestrate/SKILL.md`
- Checked-in data: `scripts/tests/suite-cost-hints.txt`, `context/standards/shell-script-testing.md`
  (Measured Before/After section), `context/patterns/external-process-wait.md`,
  `context/contracts/batch-gate-stage.md`
- Live host snapshot taken at dispatch time (`nproc`, `/proc/loadavg`)
**Artifacts**:
- specs/610_full_gate_verification_ceiling_and_stall/reports/01_gate-verification-ceiling-and-stall.md
**Standards**: report-format.md, source-store-deploy-boundary.md

## Executive Summary

- The arithmetic conflict is real and already independently measured, not theoretical: Gate 8's
  checked-in before/after table in `shell-script-testing.md` records 457,197ms idle and
  662,354ms under load 1.69-2.26 — the loaded figure already exceeds the Bash tool's measured
  600s foreground ceiling `[CARRIED-UNVERIFIED: agent-system/extensions/core/context/standards/shell-script-testing.md, "Measured Before/After" table]`.
- `JOBS_CAP=4` raising, and the straggler-bound nature of the pool, were already researched and
  rejected in `run-all.sh`'s own header with current-at-the-time figures; this record's own fresh
  re-sum of the live `suite-cost-hints.txt` (156 rows, 1,406,493ms total; longest single suite
  `test-gate-cache-equivalence.sh` at 543,000ms) confirms the straggler is still the single
  largest term and still exceeds `aggregate/4`, so raising the cap still cannot be the fix.
- A load-aware contention-tagging mechanism already exists, but only for Gate 8
  (`GATE8_CONTENTION_DETECTED` in `verify-deploy.sh`, keyed on mutex-wait fraction or entry
  loadavg ≥ 2.0) — it is the right precedent to extend to the other 29 gates' fixed 30-180s
  bounds (research question 4), not a pattern to invent fresh.
- "Batch Gate Deferral" is confirmed to be advisory prose with no enforcement: it is gated on
  `.task_numbers | length > 1` in `orchestrate-cycle-plan.sh`, so a batch of one never even emits
  the directive, and nothing anywhere refuses an unfiltered `verify-deploy.sh`/`run-all.sh`
  invocation regardless of the directive's presence.
- The orchestrator's own unbounded wait (research question 5) traces to a harness-level
  constraint, not only a missing timeout in `skill-orchestrate`: Move 2 issues every dispatch's
  Agent call in one message, and Move 3 runs only "after ALL Agent calls from Move 2 complete" —
  there is currently no documented path for the orchestrator's own session to poll one sibling
  dispatch while others are still in flight. This needs to be confirmed directly against the
  orchestrator's own (non-subagent) session capabilities before a fix is designed; the general
  dispatched-subagent context this report was authored under explicitly lacks that capability.
- A trustworthy idle/loaded baseline could not be freshly measured in this dispatch: another
  session (a sibling implementation dispatch, `impl-607`) and the main orchestrator session were
  both concurrently active throughout, which is exactly the condition this dispatch's own VERIFY
  section and `measure-gate-costs.sh`'s own load guard (threshold 2.0) both say must not be used
  as a baseline. The measured-before/after table above is cited as the best available substitute,
  explicitly carried and marked.

## Context & Scope

This is the infrastructure half of the full-gate-verification stall problem observed during an
eight-task `/orchestrate` batch, where one implement dispatch backgrounded a full verification
run and the orchestration loop made zero forward progress for eight hours because postflight
cannot run until every dispatch in the wave returns. The agent-side wait-discipline half (when to
choose a foreground vs. detached wait) is owned by a separate record and is out of scope here;
this record covers timing (can Gate 8 fit under the foreground ceiling), concurrency (what
happens when N sessions all run a full battery at once), enforcement (can a nested full battery
be made a structural no-op rather than an advisory ask), and the orchestrator's own unbounded
wait on its dispatched agents.

Constraints carried into this research phase from the dispatch:
- No reduction in default verification coverage without an explicit, declared justification.
- No re-litigation of record 454's agent-side wait-discipline scope.
- The canonical bounded-waiter idiom (captured `pid=$!`, `kill -0` liveness loop, outer
  `timeout N`, one Bash call, never `ps | grep`/`pgrep -f`) must be preserved verbatim wherever
  this record's eventual implementation touches it.
- A measured baseline must be taken idle and under load, as a control, and must not be taken
  while other sessions are active — this dispatch could not satisfy that control condition (see
  Findings and Risks below) and defers the fresh measurement rather than producing a
  contaminated one.

## Findings

### Research Question 1 — Can Gate 8 fit under the 600s foreground ceiling?

- **The 600s ceiling itself is independently and directly measured**, not assumed:
  `external-process-wait.md`'s "The 600s Ceiling Is Measured, Not Assumed" subsection records
  foreground Bash calls of 10s/170s/190s/350s/590s completing synchronously under a raised
  `timeout` parameter, and a 620s call backgrounded at exactly the 600s mark, on harness Claude
  Code 2.1.322, measured 2026-11-12
  `[CARRIED-UNVERIFIED: agent-system/extensions/core/context/patterns/external-process-wait.md, "The 600s Ceiling Is Measured, Not Assumed"]`.
- **Gate 8's declared bound (1500s) and its real measured wall-clock are two different
  numbers, and the real one is the one that matters.** `shell-script-testing.md`'s
  "Measured Before/After" table gives Gate 8 (run-all.sh) as 457,197ms idle ("before") and
  662,354ms under load 1.69-2.26, 2 runs averaged ("after") — a ~1.45x regression the same
  section attributes honestly to one new suite (`test-gate-cache-equivalence.sh`, 543,000ms)
  added to the corpus as a correctness proof for a different, prior change
  `[CARRIED-UNVERIFIED: agent-system/extensions/core/context/standards/shell-script-testing.md, "Measured Before/After: Full-Sweep and Incremental Cost"]`.
  The idle figure (457s) is under the 600s ceiling; the mildly-loaded figure (662s) is already
  over it. This means the structural conflict the dispatch names (1500s declared > 600s ceiling)
  actually bites in practice well before the declared bound is approached — a host at even
  moderate load (loadavg ~2, nowhere near this dispatch's own observed 3-6) is enough to push a
  real Gate 8 run past the foreground ceiling.
- **Raising `JOBS_CAP` above 4 has already been researched and rejected, with figures, inside
  `run-all.sh`'s own header.** Its rejected-alternatives paragraph states the pool is
  straggler-bound: `suite-cost-hints.txt`'s then-current 153-row/1,402.17s aggregate divided by
  any candidate cap (4, 8, 12) still lands below the single longest suite's own cost (543s), so
  raising the cap can only add concurrent CPU/memory pressure, not shrink the wall-clock floor —
  and a real `--jobs 4` run on an idle-start host measured 650s and pushed the straggler itself
  over its own per-suite timeout under self-generated contention
  `[CARRIED-UNVERIFIED: agent-system/extensions/core/scripts/tests/run-all.sh, "Rejected alternatives for --jobs" header comment]`.
  This report's own fresh re-derivation against the live file (not carried) confirms the
  structure is unchanged: `suite-cost-hints.txt` today carries 156 hinted rows summing to
  1,406,493ms, and the single longest suite is still `test-gate-cache-equivalence.sh` at
  543,000ms — aggregate/4 ≈ 351,623ms, still below the 543,000ms straggler, so the pool is still
  straggler-bound at the current cap and raising it further still cannot help.
- **A faster default suite SELECTION (narrowing which suites run by touched path) is explicitly
  out of this record's scope** — territory edge 650 (`touched_path_verify_entry_and_unmapped_fallback`)
  owns that arm of this question and answers it with a scoped touched-path entry point over
  `run-all.sh --only`/`suite-selection-lib.sh`. This record keeps only sharding, the jobs cap
  (addressed above — rejected), and slow-suite splitting.
- **Slow-suite splitting is the remaining, unaddressed lever**, and the evidence above points at
  exactly one target: `test-gate-cache-equivalence.sh` (543,000ms) is both the pool's single
  longest member and, on its own, close to the entire 600s ceiling. No amount of worker-count
  tuning touches a single suite's own wall-clock. Splitting it into independently-schedulable
  chunks, or moving it out of the foreground-bound Gate 8 battery into a separately-tracked gate
  (not a coverage reduction — see Recommendations) is the one change that can lower Gate 8's own
  floor below the ceiling with real headroom, rather than the current ~60-140s of margin the
  idle figure alone provides.
- A second large contributor is structural rather than cost-tunable: `shell-script-testing.md`
  records that `test-verify-deploy-context-budget.sh` (228,595ms hinted) spends roughly a fifth
  of the entire discovered-suite-pool's cost on ONE nested, full-battery `--skip-slow` call to
  `verify-deploy.sh` from inside a suite that Gate 8 itself runs — "the gate tree re-enters
  itself" is recorded there as the primary root cause of a 4.4x gap between a naive projection
  and the measured idle wall-clock
  `[CARRIED-UNVERIFIED: agent-system/extensions/core/context/standards/shell-script-testing.md, "The recursive component" and "Verdict table"]`.
  This is adjacent to, but distinct from, the straggler-suite question above: it is a self-tested
  suite re-invoking the thing testing it, not a raw cost problem, and any future Gate 8 fit-under-
  ceiling work should treat "does this suite call verify-deploy.sh at all" as a design question
  on its own.

### Research Question 2 — Should a mechanical guard replace the advisory deferral directive?

- **Confirmed: today's "Batch Gate Deferral" directive is prose only, with no enforcement
  anywhere in the path it constrains.** `orchestrate-build-dispatch.sh` emits the directive text
  (naming the plan's own `full`-tier phases and instructing the dispatch to narrow instead), but
  nothing downstream refuses, intercepts, or no-ops an unfiltered `verify-deploy.sh`/`run-all.sh`
  invocation if the dispatched agent runs one anyway. The three-of-three ignore rate the dispatch
  cites is therefore exactly what this gap predicts, not an anomaly.
- **The directive is gated on batch size in a way that structurally excludes the common case.**
  `orchestrate-cycle-plan.sh`'s `build_args` composition only appends `--batch-gate-deferral`
  when `.task_numbers | length -gt 1` — a single-task `/orchestrate N --implement` invocation
  never receives the directive at all, and `batch-gate-stage.md`'s own "Single-task...
  invariance" section confirms the consequence explicitly: that invocation shape's final phase
  "therefore still runs the complete gate set inline, exactly as before this design existed."
  Territory edge 651 (`orchestration_close_owns_full_battery`) owns fixing this gate and depends
  on this record's mechanical-guard answer to make its policy change enforceable, per its own
  task record.
- **No code path anywhere checks "is a batch-level close already going to cover this" before an
  implement dispatch runs `verify-deploy.sh` unfiltered.** There is no env var, lock-state flag,
  or state.json field consulted by `verify-deploy.sh` or `run-all.sh` at entry for this purpose
  today — `GATE_MUTEX_HELD` exists but answers a different question (is an outer *process* already
  holding the gate-lock mutex in THIS same invocation tree), not "is this invocation's own
  dispatch *supposed* to defer at all."
- **A mechanical guard is buildable on the same shape the system already uses for owed-not-paid
  deferral** (the `__FULL_SWEEP__`/owed-record design territory edge 650 and 651 build). The
  natural mechanism: `orchestrate-build-dispatch.sh` (or `orchestrate-cycle-plan.sh`) writes a
  durable per-invocation marker — e.g. a `batch_gate_pending` field in the multi-task state file,
  or a `specs/.batch-gate-deferred` sentinel scoped to the invocation — whenever Move 4's batch
  gate stage will run this cycle (i.e., whenever any `implement` dispatch occurred). `verify-
  deploy.sh`'s own top-level entry (and `run-all.sh`'s top-level entry, for the bare-suite-runner
  path) checks for that marker before running an UNFILTERED pass: if present, and the invocation
  is not already nested (`VERIFY_DEPLOY_WAS_NESTED_AT_ENTRY`/`GATE_MUTEX_HELD`) and not explicitly
  forced via a stated override flag, it refuses the unfiltered run and prints/returns a "deferred
  to batch close" result rather than executing anything — exactly the "no-op returning the batch
  result" shape research question 2 proposes. A SCOPED invocation (`--only-gate N`, `--only
  SUITE`) is never blocked by this guard; only the unfiltered, full-coverage shape is.
- This guard composes directly with research question 2's "batch of one" requirement that
  territory edge 651 needs: the marker is written whenever Move 4 will run this cycle, which
  `batch-gate-stage.md`'s Trigger section already states is "unless at least one implement-phase
  dispatch occurred this invocation" — independent of task count. Removing the
  `length > 1` gate on Mechanism A (the directive text) and adding this marker-based guard
  together make a batch of one behave identically to a multi-task batch.

### Research Question 3 — Is `.gate-lock`'s fail-open posture the right trade?

- **Confirmed: both call sites fail open by explicit design, not by omission.**
  `task-lock.sh`'s own `.gate-lock` header states plainly that `acquire_named_mutex` itself fails
  CLOSED (returns 2 on budget exhaustion) and that it is the TWO CALL SITES
  (`verify-deploy.sh`'s `gate8_run()`, confirmed read directly; `run-all.sh`'s top level, per the
  same header) that choose to proceed unserialized with a loud warning rather than ever refusing
  verification. The warning text at the `gate8_run()` call site explicitly says this "mirrors
  git-commit-scoped.sh's specs/.commit-lock fail-open posture."
- **Fail-open is the right posture to KEEP, but the thundering-herd cost it produces is better
  addressed by reducing how often the fail-open path is even reached than by hardening the lock
  itself.** A fail-closed-with-queueing redesign runs into the same 600s foreground ceiling
  research question 1 already establishes: an agent queued behind someone else's multi-minute
  battery would itself need to wait past 600s in the common case, forcing every blocked caller
  onto the same detach-and-poll path research question 5 is trying to make safe — fail-closed
  would multiply the stall surface, not shrink it, unless paired with a wait mechanism this
  record is simultaneously trying to replace. A substantially longer acquire budget has the
  identical problem in miniature: it only changes how long a caller waits before giving up, not
  whether that wait itself is safe.
- **Research question 2's mechanical guard is the leverage point, not a change to the mutex's own
  posture.** Once an implement dispatch is structurally prevented from invoking the unfiltered
  battery at all, the only remaining callers of `acquire_gate_mutex` are: Move 4's one
  once-per-invocation shared run, and any genuinely manual/out-of-band invocation. Both are rare
  enough that the fail-open path's "multiplies the very load that produces false reds" cost
  (dispatch's own evidence item (b)) drops from "N concurrent implement dispatches, routinely" to
  "effectively never, except a manual run colliding with an in-flight Move 4" — the posture does
  not need to change for the problem it exists to solve to shrink to a tolerable size.
- **Ruling**: keep fail-open (with its existing loud warning). This record does not propose
  changing `GATE_MUTEX_ACQUIRE_BUDGET_MS`, `GATE_MUTEX_STALE_SEC`, or the fail-open/fail-closed
  choice itself. The host-scope gap that a separate, dependent territory-edge record
  (`host_scoped_gate_mutex`) was filed against — every lock resolving as
  `$PROJECT_ROOT/specs/<name>`, confirmed directly in `task-lock.sh`'s
  `acquire_named_mutex`/`release_named_mutex` (`mutex_dir="$PROJECT_ROOT/specs/${mutex_dirname}"`)
  — is explicitly that record's to fix; this record's posture ruling is what it inherits rather
  than re-litigates, per that edge's own text.

### Research Question 4 — Should per-gate bounds scale with measured load?

- **A load-aware contention-detection mechanism already exists in the codebase, but only for
  Gate 8, and only as an annotation, never as a bound adjustment.** `verify-deploy.sh`'s
  `gate8_run()` computes `GATE8_CONTENTION_DETECTED` from a disjunction of two measured signals:
  the `.gate-lock` acquire wait time (≥10% of `GATE_MUTEX_ACQUIRE_BUDGET_MS` by default, i.e.
  ≥60s against the 600s default budget) and the entry 1-minute loadavg (≥2.0 by default,
  `GATE8_CONTENTION_LOAD_THRESHOLD`, matching `measure-gate-costs.sh`'s own
  `MEASURE_GATE_COSTS_LOAD_THRESHOLD` default for consistency). When triggered, it adds a
  `WARN-FINDING gate8 [CONTENTION] ...` line rather than letting a load-induced kill masquerade
  as an unexplained hard failure. This is exactly the mechanically-distinguishable signal
  research question 4 asks for — it already exists, for one gate.
- **The other 29 gates' fixed 30-180s bounds carry no equivalent.**
  `gate-registry-lib.sh`'s `gate_registry_exec_bounded`/`_greg_pool_job` apply each gate's
  declared `timeout_s` from `gate-registry.data` as a flat kill bound with no load read at all;
  the only load-sensitive branch in that file is a dead-code fallback (`timeout_s` empty →
  600s) for a case the real registry's rows never hit. The dispatch's evidence item (c) — three
  independent issue-log entries of gates killed under batch load and confirmed to pass standalone
  — is the direct, predictable consequence of this gap.
- **Recommendation path is "generalize the proven mechanism," not "invent a new one."** Extending
  `GATE8_CONTENTION_DETECTED`'s two-signal model (mutex-wait fraction, entry loadavg) to the
  generic registry executor is the natural next step: `gate_registry_exec_bounded` could sample
  `/proc/loadavg` at both entry and kill time for any gate whose process was actually killed by
  its timeout, and tag the resulting finding `[CONTENTION]` (WARN, not silently passed) rather
  than a bare `FAIL`, exactly mirroring Gate 8's existing annotation — never silently extending
  the bound itself, since a genuinely slow/broken gate must still be distinguishable from a
  load-killed healthy one, and a WARN-not-FAIL framing (requiring an explicit, reviewed Reasoned
  Exclusion, never an automatic green) is the only shape that satisfies the dispatch's own HARD
  CONSTRAINT against silently weakening coverage.
- Territory edge 452 (`baseline_relative_gate_criteria`) is the natural downstream consumer of
  this finding — it owns baseline-relative gate criteria broadly, and a load-adaptive
  distinguishing signal is exactly the kind of baseline this record's own evidence would feed it.
  This record does not design 452's full criteria scheme; it establishes that the mechanism to
  reuse already exists and names its exact shape and location.

### Research Question 5 — Can the orchestrator bound its own wait on a dispatch?

- **Confirmed: `stall_suspected` cannot fire before the stall itself ends, by the loop's own
  documented ordering.** `skill-orchestrate/SKILL.md`'s Move 3 heading states plainly: "After ALL
  Agent calls from Move 2 complete (never interleaved with dispatch), run this once per
  `dispatch[]` row" — and `stall_suspected` is read out of `orchestrate-cycle-postflight.sh`'s own
  JSON inside that per-row loop, i.e., inside Move 3. There is no code path that evaluates
  `stall_suspected` before Move 3 begins, and Move 3 cannot begin before every Move 2 Agent call
  returns. **The ordering IS the actual defect** the dispatch asks this record to establish: the
  detector is real and already correctly wired to the state it reads, but it is wired downstream
  of the exact event (a dispatch returning) it needs to detect the ABSENCE of.
- **Move 2 issues every dispatch's Agent call "in one message (multiple messages force
  sequential execution)"** — confirmed directly in the SKILL.md text. This is the harness-level
  root of the problem: today's design relies on the harness's own parallel-tool-call semantics to
  get concurrency across sibling dispatches, and that same mechanism is what makes the
  orchestrator's own conversational turn block until every one of those calls resolves. A timeout
  added only inside `orchestrate-cycle-postflight.sh` (Move 3) cannot help, because Move 3's own
  invocation is itself gated on the turn completing.
- **No existing context file in this codebase documents whether the orchestrator's own
  (non-subagent, top-level) session has a background/async Agent-dispatch capability it could use
  instead.** This report's own search of `skill-orchestrate/SKILL.md` and the `context/`/`docs/`
  trees found no mention of `run_in_background` (or an equivalent) in connection with Move 2's
  dispatch. This dispatch's own tool surface — issued as a subagent, not as the orchestrator's own
  top-level session — explicitly disables that parameter ("The run_in_background and name
  parameters are not available in this context. Only synchronous subagents are supported."),
  which is strong first-hand evidence that the capability is role-gated, but does not settle
  whether the orchestrator's own top-level session (which this report cannot directly inspect)
  has it. **This is the single highest-leverage open question for question 5**, and should be
  confirmed directly, from the orchestrator's own session, before any Move 2/3 redesign is
  committed to a plan.
- **If background dispatch is available to the orchestrator's session**, the natural redesign is:
  Move 2 dispatches each row via background Agent calls instead of one blocking message; Move 3
  is restructured into a bounded poll loop (mirroring `bounded-build-waiter.md`'s canonical
  idiom — a captured handle, a liveness check on an interval, an outer hard timeout, all without
  manufacturing no-op filler calls per `external-process-wait.md`) that advances sibling tasks'
  postflight as each one's own dispatch resolves, and raises `stall_suspected` for a specific
  task the moment ITS OWN bounded wait expires, rather than waiting for the slowest sibling.
  This would turn "detected in hours" into "detected in minutes," matching the dispatch's own
  objective, without touching record 454's agent-side wait-discipline scope (this is the
  orchestrator watching its OWN dispatched agents, not an agent watching a Bash subprocess it
  itself launched).
- **If background dispatch is NOT available**, the fallback is necessarily external to the
  orchestrator's own single-threaded turn: a per-task heartbeat file (mirroring
  `task-lock.sh`'s existing heartbeat/staleness pattern) that each dispatched agent is contracted
  to touch at a bounded interval, watched by a process outside the blocked orchestrator turn
  itself — for example via this harness's own `schedule`/`loop` facilities, or an operator-
  visible stale-heartbeat alert the NEXT orchestrator invocation surfaces immediately on
  resumption rather than after a full multi-hour silent wait. This is a materially weaker
  guarantee (it cannot shorten the CURRENT blocked turn, only make the next operator check or
  invocation catch the stall faster) and should only be the fallback, not the first design.

## Decisions

1. Research question 1's "faster default suite selection" arm is NOT answered here — it belongs
   to territory edge 650 and is explicitly excluded from this record's scope to avoid answering
   it twice.
2. Raising `JOBS_CAP` above 4 is ruled out, re-confirmed against the live `suite-cost-hints.txt`
   at authoring time (156 rows, 1,406,493ms aggregate, 543,000ms straggler) rather than only
   inherited from `run-all.sh`'s prior rejection. The straggler-bound structure that rejection
   relied on is unchanged.
3. `.gate-lock`'s fail-open posture is kept as-is. This record's ruling is that the posture is
   not the lever to pull; research question 2's mechanical guard is. The `host_scoped_gate_mutex`
   territory edge inherits this ruling rather than re-litigating fail-open-vs-fail-closed itself.
4. A fresh idle+loaded measured baseline was NOT taken in this dispatch. Another session
   (teammate `impl-607`) and the main orchestrator session were both concurrently active for the
   entirety of this research phase, which is precisely the condition this dispatch's own VERIFY
   section says must not be used as the control, and which `measure-gate-costs.sh`'s own load
   guard (threshold 2.0) would itself refuse to record against (this host's own loadavg sampled
   during this dispatch ranged 3.16-6.97, see Appendix). The existing, dated, checked-in
   measurement in `shell-script-testing.md` is used instead, explicitly carried and marked, and a
   fresh re-measurement is recommended as follow-up work in a genuinely idle window (see
   Recommendations).
5. The orchestrator's unbounded-wait defect (research question 5) is confirmed to be an ordering
   defect as the dispatch asked this record to establish, but the record stops short of
   prescribing the fix, because the fix's shape depends entirely on a capability
   (orchestrator-side background Agent dispatch) this report could not directly verify from a
   dispatched-subagent context. This is recorded as the single open item a plan for this task
   must resolve first.

## Recommendations

1. **(Question 1, highest priority)** Split or relocate `test-gate-cache-equivalence.sh`
   (currently 543,000ms, the pool's single longest suite and, alone, most of the distance to the
   600s ceiling) out of Gate 8's foreground-bound default battery. Do this as an explicit,
   declared change — e.g. a new `cost_class` tier that still runs by default but on a path not
   bound by the 600s foreground constraint (Move 4's batch close, or a dedicated background-
   tracked gate) — never as a silent exclusion. This is the one lever research question 1's own
   evidence shows can actually move Gate 8's wall-clock floor; worker-count tuning cannot.
2. **(Question 1)** Separately evaluate whether `test-verify-deploy-context-budget.sh`'s one
   nested full-`verify-deploy.sh --skip-slow` call site needs to exist at all, or can be narrowed
   to the `--only-gate` scoped calls its other two call sites already use — `shell-script-
   testing.md` attributes roughly a fifth of the entire pool's cost to this one self-re-entrant
   call site.
3. **(Question 2)** Build the marker-based mechanical guard described in Findings: a
   per-invocation "batch gate pending" marker written whenever Move 4 will run this cycle (gated
   on "at least one implement dispatch occurred," per `batch-gate-stage.md`'s own trigger —
   NOT on task count), checked by `verify-deploy.sh`/`run-all.sh` at entry, refusing only an
   UNFILTERED invocation and never a scoped one. This directly unblocks territory edge 651's
   policy change, including its batch-of-one requirement.
4. **(Question 3)** No change to `.gate-lock`'s fail-open posture, budgets, or staleness window.
   Revisit only if, after recommendation 3 lands, fail-open contention is still observed in
   practice — which this record's own reasoning suggests it should not be, since the mechanical
   guard removes the routine multi-dispatch collision case fail-open exists to tolerate.
5. **(Question 4)** Extend `GATE8_CONTENTION_DETECTED`'s two-signal model (entry loadavg,
   `.gate-lock` wait fraction) from `gate8_run()` into `gate_registry_exec_bounded`'s generic
   timeout-kill path, tagging a load-correlated kill `[CONTENTION]` as a WARN-FINDING rather than
   a bare FAIL, for every gate, not only Gate 8. Coordinate with territory edge 452
   (`baseline_relative_gate_criteria`) before editing shared gate-criteria prose, per that edge's
   own note.
6. **(Question 5, open item — resolve before planning the fix)** From the orchestrator's own
   top-level session (not a dispatched subagent), confirm directly whether its Agent tool
   exposes a background/async dispatch mode. If yes, redesign Move 2/3 around bounded per-task
   polling (reusing the `bounded-build-waiter.md` idiom's shape, applied to the orchestrator
   watching its own dispatched agents rather than a Bash subprocess) so `stall_suspected` can fire
   for one stalled task without waiting on its siblings. If no, the fallback is an external
   heartbeat-watch mechanism (see Findings) that improves time-to-discovery on the NEXT
   orchestrator action rather than within the current blocked turn — a materially weaker, but
   still strictly better than today's, guarantee.
7. **(Deliverable follow-up)** Re-run `measure-gate-costs.sh` for a genuine idle baseline (and,
   separately, under representative concurrent load) in a window with no other active session on
   this host, recording `nproc`/loadavg at measurement start per the dispatch's VERIFY
   requirement. Do not substitute a measurement taken while any other session (including a
   sibling `/orchestrate` dispatch) is active — the existing load guard in that script already
   enforces the "idle" half of this mechanically; the "no other session" half is not something
   the script itself can detect and must be an operator/dispatch-timing decision.

## Risks & Mitigations

- **Risk**: Moving `test-gate-cache-equivalence.sh` (or any slow suite) out of Gate 8's default
  foreground battery could be read as, or accidentally become, a coverage reduction.
  **Mitigation**: the dispatch's own HARD CONSTRAINT already requires any reduction in what runs
  by default to be explicit and declared; recommendation 1 above is written as "relocate to a
  path that still runs by default," never "run less," and any implementation plan must carry its
  own explicit before/after coverage statement, not rely on this report's framing alone.
- **Risk**: A load-adaptive WARN tag (recommendation 5) could be used to wave away a genuine
  intermittent failure as "just load."
  **Mitigation**: keep the existing shape — WARN, not auto-pass, and still requiring an explicit
  Reasoned Exclusion record per failure, exactly as Gate 8's own `[CONTENTION]` tag already
  behaves today. This is a classification aid for the human/agent investigating, not an
  auto-green.
- **Risk**: The mechanical no-op guard (recommendation 3) is itself a new way for verification to
  silently not run, if its "unfiltered vs. scoped" and "nested vs. not" detection logic has a gap.
  **Mitigation**: model it on the existing `__FULL_SWEEP__`/owed-record precedent this system
  already uses (never a bare skip — an owed-not-paid record that a later stage must discharge),
  and require its own test coverage proving a seeded unfiltered call is refused, a seeded scoped
  call is not, and a seeded nested call defers to the existing `GATE_MUTEX_HELD` guest path
  unchanged.
- **Risk**: This record's own measured-baseline deliverable is satisfied only by carried,
  dated figures, not a fresh in-session measurement, because of concurrent-session contamination.
  **Mitigation**: explicitly flagged throughout (Decisions item 4, Recommendation 7) rather than
  silently presented as fresh; a planning or implementation phase for this task should treat the
  fresh re-measurement as its own first verification step, taken in a confirmed-idle window.
- **Risk**: Question 5's fix depends on a harness capability (orchestrator-side background Agent
  dispatch) this report could not verify directly.
  **Mitigation**: recorded as an explicit open item (Decision 5, Recommendation 6) rather than
  assumed either way; a planning phase for this task should make confirming it the first step of
  that phase, before committing to either the background-poll design or the heartbeat fallback.

## Context Extension Recommendations

- **Topic**: Load-adaptive gate-timeout classification, generalized beyond Gate 8.
  **Gap**: `GATE8_CONTENTION_DETECTED`'s pattern (entry loadavg + mutex-wait-fraction signals,
  WARN-not-FAIL tagging) exists only inline in `verify-deploy.sh`'s `gate8_run()`; there is no
  standalone pattern document describing it as a reusable shape for the other 29 gates.
  **Recommendation**: once recommendation 5 above lands in the generic registry executor, add a
  `context/patterns/load-adaptive-gate-timeout.md` (or fold into `shell-script-testing.md`)
  naming the two signals, their defaults, and the WARN-not-FAIL framing as the house style for
  any future gate needing the same treatment.
- **Topic**: Orchestrator-side bounded waiting on its own dispatched agents.
  **Gap**: `external-process-wait.md` and `bounded-build-waiter.md` both explicitly scope
  themselves to an agent waiting on a Bash-invoked external/local process it itself launched —
  neither covers the orchestrator's own top-level session waiting on sibling Agent-tool
  dispatches, which this record's research question 5 shows is a materially different situation
  (no Bash subprocess, no PID to `kill -0`, and an open question about whether a background
  dispatch mode even exists for that session).
  **Recommendation**: once research question 5's open item is resolved (Recommendation 6), add a
  dedicated pattern document for whichever mechanism results, rather than overloading the two
  existing Bash-subprocess-scoped patterns with a second, differently-shaped waiting discipline.

## Appendix

### Measured Baseline Table (VERIFY requirement)

| Measurement | Value | nproc | loadavg (1/5/15 min) | Provenance |
|---|---|---|---|---|
| Gate 8 full-sweep, idle | 457,197 ms | not stated in source | not stated in source | `[CARRIED-UNVERIFIED: shell-script-testing.md, "Measured Before/After" table — "before (dispatch baseline)" column]` |
| Gate 8 full-sweep, loaded | 662,354 ms (2 runs averaged) | not stated in source | 1.69-2.26 | `[CARRIED-UNVERIFIED: shell-script-testing.md, "Measured Before/After" table — "after (measured, post-redeploy)" column]` |
| `suite-cost-hints.txt` aggregate (156 suites), re-summed live this session | 1,406,493 ms (≈1,406.5 s) | 24 (this host, sampled live) | 4.88 / 5.87 / 5.97 (sampled at dispatch start, this host) | Fresh this-session re-derivation: `awk -F, '{sum+=$2} END{print sum}' scripts/tests/suite-cost-hints.txt` against the live file |
| Single longest suite (`test-gate-cache-equivalence.sh`) | 543,000 ms | — | — | Fresh this-session re-derivation, same command, sorted |
| Host snapshot at research-dispatch end (NOT an idle control — see Decisions item 4) | — | 24 | 3.16 / 4.98 / 5.63 | Sampled live, this session, `/proc/loadavg` |

No fresh, trustworthy idle-or-controlled-load Gate 8 wall-clock measurement was taken in this
dispatch; see Decisions item 4 and Recommendation 7 for why and what should happen next. The
`suite-cost-hints.txt` re-sum and loadavg samples above ARE fresh measurements taken in this
session (not carried); the two Gate 8 wall-clock figures in the first two rows are carried from
`shell-script-testing.md` and explicitly marked as such.

### Search Queries / Commands Used

- `awk -F'\t' '!/^#/ && NF>1 {print}' scripts/gate-registry.data` — enumerate all 30 gate rows.
- `grep -v '^#' scripts/tests/suite-cost-hints.txt | awk -F, '{sum+=$2; n++} END{...}'` and
  `sort -t, -k2 -nr` — aggregate and rank suite costs.
- `grep -n "GATE8_JOBS\|JOBS_CAP" scripts/verify-deploy.sh scripts/tests/run-all.sh`
- `grep -n "fail open\|GATE_MUTEX" scripts/task-lock.sh`
- `grep -n "GATE8_CONTENTION_DETECTED" scripts/verify-deploy.sh`
- `grep -n "length > 1\|task_numbers" scripts/orchestrate-cycle-plan.sh`
- `grep -n "Move 3\|Move 2\|stall_suspected" skills/skill-orchestrate/SKILL.md`
- `grep -n "PROJECT_ROOT" scripts/task-lock.sh` — confirmed the per-repository mutex scope the
  `host_scoped_gate_mutex` territory edge is filed against.

### References

- `agent-system/extensions/core/scripts/gate-registry.data`
- `agent-system/extensions/core/scripts/verify-deploy.sh`
- `agent-system/extensions/core/scripts/task-lock.sh`
- `agent-system/extensions/core/scripts/tests/run-all.sh`
- `agent-system/extensions/core/scripts/lib/gate-registry-lib.sh`
- `agent-system/extensions/core/scripts/measure-gate-costs.sh`
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- `agent-system/extensions/core/context/standards/shell-script-testing.md`
- `agent-system/extensions/core/context/patterns/external-process-wait.md`
- `agent-system/extensions/core/context/contracts/batch-gate-stage.md`
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt`
