# Roadmap

*Forward-only: what remains, in what order, and the gates. Finished work is removed, not archived
here. Task detail lives in `specs/TODO.md`; this file carries ordering, gates and rulings only.
Figures carry the date measured. Last measured 2026-11-11.*

## Goal

`/orchestrate` is the only lifecycle entry point, and it is token-cheap by construction: delegate,
read back compact verdicts, ask the user only when a decision is genuinely the user's. `MAX_TASKS`
is 8, enforced in `commands/orchestrate.md`.

Counts and rosters are generated (`generate-task-order.sh --print`,
`roadmap-integration.sh --regenerate`, `orchestrate-suggest-next-batch.sh --next-batch`). Never
transcribe one here. As of 2026-11-11: **137 open (2 held), 5 awaiting `/todo` archival**.

## Gate state

Every bullet carries its own measurement date. A CARRIED-UNVERIFIED figure must be re-derived
before it is cited (standing rule 5).

- **Gate 8 is red: 5 declared suites**, re-measured 2026-11-11 by a full
  `tests/run-all.sh --jobs 4`: **178 passed, 7 failed (5 expected, 2 NEW), 2 skipped, 187
  total**. The declared roster is `test-double-loading-check.sh`,
  `test-gate-cache-equivalence.sh`, `test-lint-unit-integration-boundary.sh`,
  `test-orchestrate-cycle-postflight.sh`, `test-verify-deploy-context-budget.sh`. The four
  records that accounted for most of the earlier red have all landed, and none of their failures
  was about what the suites test — a hardcoded repo-root walk-up depth across five suites, a
  missing `lib/project-number-inuse.sh` dependency-copy line in three fixtures, and two
  single-assertion failures the first of those had already closed. `568` owns
  `test-orchestrate-cycle-postflight.sh` (25 of 304 assertions, status-name and
  `persisted_status` drift, confirmed pre-existing); `test-double-loading-check.sh` (case 5
  bucket-classification) and `test-lint-unit-integration-boundary.sh` (6 violations across 170
  discovered suites, suites with no `suite-classification.data` row) are both needs-owner.
  `476` owns the residue and **must be re-measured, not sized** — its title still says seven, and
  the roster has never been stable run-to-run. A standing red Gate 8 destroys the signal value of
  the full gate for every later task, which is the real cost.
- **Two roster claims this re-measure overturned.** (a) **`test-gate-lock.sh` now passes** — it
  was the undeclared failure (red, no `known-failures.txt` row) and is off the roster. (b)
  **`test-verify-deploy-context-budget.sh` is red again and declared EXPECTED**, so its row is
  *not* stale and *must not* be removed; the earlier reading that gate 24 passing retired the
  row's condition was wrong. The roster now also carries one genuinely stale row:
  **`test-run-all-parallel.sh` has a row and passes**, which is exactly the instance `605` exists
  to flag.
- **Both NEW failures are contention artefacts, not defects — measured in the same pass.**
  `test-lake-build-guard.sh` failed one of 51 assertions ("case 3: command-substitution
  mismatch") and `test-roadmap-generation.sh` failed under load; re-run in isolation immediately
  afterwards they returned **51 passed / 0 failed** and **105 passed / 0 failed**. The
  `test-roadmap-generation.sh` failure is self-explaining: it carries a "live-tree isolation"
  assertion over the real `specs/ROADMAP.md`, and this pass was rewriting that file while the
  battery ran. This is a concrete instance of the cost `572` owns — **two of seven failures in a
  full battery run were false** — and the mechanism is cheap to state: a suite asserting over a
  live tracked file false-fails whenever anything else writes it.
- **The re-measure was also blocked before it could start: another live session held
  `specs/.gate-lock` for its own Gate 8.** The lock was correctly held — the registered owner pid
  was dead but its parent `verify-deploy.sh` was alive, so this was contention, not a leak, and
  releasing the token would have been wrong. The `gate-acquire` waiter blocked for over two
  minutes before the lane cleared. The ~11-minute serialization `584` exists to remove is
  therefore observable from an unrelated session, not only from a batch's own run.
- **Gate 16 needs re-measuring** (last measured red 2026-11-04). The record that owned it —
  retiring `routing_hard`/`routing_agents_hard` in favour of `hard_contracts` — has landed, and
  nothing open owns the gate. Do not carry the red forward on this entry's authority; re-run the
  gate before sizing anything against it.
- **Gate 20 passes on 80 B.** Eager load 66,720 B against baseline 66,800 B; per-file margins 4 B
  (`commands/orchestrate.md`, 21,496/21,500) and 307 B (`skills/skill-orchestrate/SKILL.md`,
  24,693/25,000). The 1,488 B of total headroom recorded on 2026-11-04 is gone: merging one
  extension's `EXTENSION.md` into `.claude/CLAUDE.md` consumed it, and that merge had to be
  trimmed from 44 lines to 28 mid-implementation to land under the baseline at all. **Any new
  extension carrying a CLAUDE.md merge target now re-fires this gate.** Prefer a relocation trim
  over another ceiling move; both ceilings moved on 2026-11-04.
- **Gate 24 passes** (re-measured 2026-11-11: 1078 files checked, 752 candidate lines scanned,
  752 exempted, 0 violations). The two findings it once carried were a deployed-tree staleness,
  not a defect in the prose: `memory-setup.md` and `memory-troubleshooting.md` both already
  recommend the Claude Code built-in `/ide` in wording the lint's exemption logic accepts, and a
  redeploy closed the gate. **Neither `512` nor `590` has a live finding to clear, and neither
  should be sized until re-measured.** `590` additionally **declares a path that does not exist**
  (`agent-system/extensions/core/scripts/lint-dead-command-recommendations.sh`, missing the
  `lint/` segment; the file is at `.../scripts/lint/lint-dead-command-recommendations.sh`, which
  `512` declares correctly) — re-confirmed 2026-11-11 — which is why `file-scope-overlap.sh`
  reports the pair clean.
- **`validate-state.sh --deep`: 20 passed, 0 failed, 8 warnings** (re-measured 2026-11-11, after
  the preceding batch landed). No dangling edges, no cycles, no duplicate or glob-shaped
  `file_scope` entries, and TODO.md byte-identical to a regeneration. The warnings are three
  classes: **two** coarse `file_scope` (473's `docs/architecture/` overlapping 11 non-terminal
  records, 518's `lean/agents/` overlapping 5 — decision 19, not a defect); **four** absent-key
  `file_scope` (567, 568 and 607, plus the roll-up line — 3 missing-key out of 137, 0 literal-null,
  0 empty-array), which decision 19 does not cover — 568's is a live dispatch hazard, since the
  admission gate sees none of its collisions; **two** reporting `audit_verdict` (77 records) and
  `audit_override` (36 records) as unknown entry fields, written by the lifecycle but modelled in
  neither `state-schema.json`'s `definitions.projectEntry` nor `KNOWN_ENTRY_FIELDS`. The schema
  gap is the cheapest of the three to close, is still unowned, and grows with every task created.
- **`--deep` is the only call that checks TODO.md sync**, and it caught a desync on 2026-11-09
  the plain call passed. A bare `state-write.sh` leaves TODO.md stale unless it carries
  `--regen-todo` or `generate-todo.sh` follows; the plain `validate-state.sh` reports 11 passed
  and will not notice.
- **Never run `verify-deploy.sh` concurrently with the battery.** A contended run cannot
  distinguish a slow gate from a failing one; four gate timeouts were misread this way on
  2026-11-03.
- A source-store commit without a resync is itself a red gate.

## Next

**The order of this list is set by instruction, not by fan-out.** An operator asked that the most essential work for agent-system health, functionality and speed lead it, and the batches were re-ordered against exactly three questions, applied in this order: does the system still make progress at all; does one dispatch hand the next the truth; and what does a run cost. Fan-out -- how many open records a record transitively gates -- is recorded below because it is cheap to re-derive, but it did not choose this order and must not be read as if it had. Re-derive with `generate-task-order.sh --print`.

**The ranking rule, stated so it can be argued with.** A batch ranks higher when its members decide whether work happens (a write path that refuses, a lock that never reaps, a guard that never converges), or whether a verdict can be trusted (a gate reporting a red nobody can attribute, a validator refusing conforming input, a detection charged to the wrong task). It ranks lower when its members improve what a future plan or document says without unblocking anything currently stuck. Cost sits immediately below verdict-truth rather than at the head: an optimisation measured against a red gate set is measured against noise, so batch four waits on batch one by construction.

Re-derived 2026-11-18 over the 122 open records. **The backlog is broad and shallow**: depth is 5 waves, the waves run 69 / 34 / 10 / 6 / 3, and **69 of 122 records have no open predecessor**. The widest gates are `479` and `599` at 3 direct open dependents each, then `431`, `451`, `452`, `472`, `484`, `539`, `548`, `593` and `597`-rooted chains at 2. **Fan-out does not discriminate between candidates at this shape, so it cannot choose the order** -- with more than half the backlog immediately ready, the binding question is which ready work matters, which is a judgment and not a measurement.

**The verification substrate is the head of the list for the first time.** Batch one is the whole of the currently-known red surface: the one substantive defect left of seven Gate 8 findings a full battery filed, the three standing findings blocking `RESULT=landed_verify_clean`, the two-engine defect that makes one suite red by design plus the roster rows for it, and the single repo-wide violation each of gates 4 and 29 report. Until that lands, every batch below it dispatches against a gate verdict an operator has a rational incentive to ignore. Batch four then owns what the battery costs -- the orchestrator eager-load ceiling, per-gate timeout sensitivity at two widths, and the first standing consumer the suite/gate cost probes have ever had.

**The renderer is sound and all three of its callers are wired.** `## Next` and `## Open work` are rendered wholly from `state.json`'s `roadmap_batches` / `roadmap_notes` entries by `roadmap-integration.sh`, which makes no judgment calls. A batch naming only terminal members drops out of the rendering entirely -- its `/orchestrate` line and its `Why this order:` bullet alike -- so retiring one by hand is tidiness, not correctness. Three such batches were retired this pass (the prioritized handoff-defect head, the `verify-deploy.sh` honorable-full-tier lane, and the sapience per-repo activation run), every member of all three having landed. `/todo` and `/review` reach `--regenerate` behind the shared preflight classifier, and `/orchestrate`'s conclusion stage has its own script, `orchestrate-conclusion-roadmap.sh`, which `skill-orchestrate` names and a dedicated suite covers.

```
/orchestrate 645, 560, 629, 630, 631, 632, 633   # Make verify-deploy's verdict mean something again: the red suites, the roster, three single reds
/orchestrate 475, 613, 514, 574   # Hard stops: task creation dies on a big verdict, a lock never reaps, a run never converges
/orchestrate 556, 472, 646, 551, 519, 570, 577, 609   # What one dispatch hands the next: settle the handoff/return-meta shapes, fix failure accounting
/orchestrate 607, 586, 605, 610   # Make a full verification affordable: eager-load ceiling, per-gate timeouts, suite cost verdicts
/orchestrate 639, 477, 484, 486, 501, 508, 524   # Evidence integrity: stop losing issue entries, normalize classes, collapse scope-excursion rows
/orchestrate 548, 567, 553, 598, 536, 535, 541   # Commit containment: stop phase commits dropping legitimate files and carrying foreign ones
/orchestrate 545, 564, 579, 575   # Four false-failure signals in the artifact and ceiling validators, each costing a dispatch
/orchestrate 599, 592, 520, 565, 518, 571   # Dispatch composition: gate narrowing, starting position, deploy order, prior art, stale seq
/orchestrate 506, 542, 552, 561   # Bounded-waiter: unstrand the dispatches a blocked wait killed, and stop the hook self-refusing
/orchestrate 521, 525, 510, 511, 523   # Enforcement that silently does not run: a half-matching glob, two dead fixtures, grep counts
/orchestrate 431, 474, 439, 454, 641, 642   # Settle the duplication-exclusion record, then propagate the bounded-wait contract it gates
/orchestrate 512, 590   # The dead-command-recommendation lint, both claimants together: builtin exemption and /ide reds
/orchestrate 455, 502, 457, 517   # Declare the generated surfaces a dispatch stales, and stop repo content leaking to the store
/orchestrate 618, 338   # Rule on what the system leaves behind: a per-class residue policy and the tracked/ignored split
/orchestrate 438, 479, 491, 492, 559, 580, 581   # Task creation and the backlog/selection surfaces: landing targets, corroboration, one renderer
/orchestrate 480, 513   # Two detectors over the landing-target contract: stranded research, a commit-less plan phase
/orchestrate 563, 583   # Make the cross-repo extension registry usable for deploy enumeration, then surface defaults
/orchestrate 451, 462, 452, 566, 509, 588   # Snapshot the Lean Challenge at plan time, then the baseline-relative and redeploy gate rules
/orchestrate 504, 516, 398, 399, 463, 550, 537   # The Lean compliance checker and its context strand: harvest contract, trust surfaces, probes
/orchestrate 549, 576   # The narrow unusedArguments remedy, then the gate-naming and replay-window record over it
/orchestrate 539, 540, 544, 593, 594, 595, 596   # Settle the pinned Challenge block's authoring rules, then the five plan records quoting them
/orchestrate 390, 481   # Migrate the mis-sited agent-system records, first the seven then the delta accumulated since
/orchestrate 410, 533   # Close the lake-build-guard replay hole at both entry points it is reachable from
/orchestrate 453, 546, 437   # Literature: the degraded-retrieval contract, the zero-result case, and the Zotero export
/orchestrate 383, 384, 342   # The books extension's reconciliation surface; its corpus refactor stays held on an external pin
/orchestrate 456, 421, 529, 530   # Four standalone rulings: /tag's version gate, the telemetry consumer, routing, cslib context
/orchestrate 473, 522, 640, 557   # Documentation and standards conformance: boundary docs, skeletons, census method, one note
```

Why this order:
- - **This is the head because every other batch's gate stage reads it.** A batch that runs while
    the gate set returns a red verdict nobody can attribute gets one of two outcomes: the gate
    blocks work that did nothing wrong, or the operator learns to ignore the gate. Both destroy the
    signal the rest of this list is ordered around, so restoring the verdict precedes everything.

  - **The members are the whole of the currently-known red surface, measured.** `645` holds the one
    substantive defect left of seven Gate 8 findings one full battery filed (six are recorded closed
    in its own provenance section -- read that before spending a dispatch). `560` clears the three
    standing findings that keep `deploy-headless.sh` from reaching `RESULT=landed_verify_clean` at
    all. `629` fixes the two-engine allow-list drop that makes `test-deploy-propagation.sh`
    expected-red BY DESIGN, and `630` writes the roster rows for that suite and
    `test-gate-registry-resolution.sh` so `run-all.sh` stops calling an expected failure NEW --
    that pair is already edged, `630` behind `629`. `631` and `632` each close the single
    unexempted violation gate 29 and gate 4 report repo-wide. `633` deletes a 68KB duplicate deploy
    ledger sitting inside the core source store whose contents disagree with the root ledger a
    resolver is supposed to read.

  - **`632` before `607` is deliberate and preserved from the prior ordering.** `632` makes
    `orchestrator-context-budget.json`'s append-only derivation log stop re-breaking the
    task-reference gate every time the ceiling moves; `607` (one batch below) moves that ceiling
    again. Fixing the recurrence first means the move does not immediately re-open the gate.

  - **The lane is free.** No member declares `__WHOLE_TREE__`, and the only cross-batch overlap is
    `560`'s `lean-plan-compliance-check.sh` against the Lean compliance strand far below, resolved
    by array position rather than an edge.
- - **Each member is a measured way the system stops making progress, not a way it makes wrong
    progress.** That is why they sit above every correctness batch below: a correctness fix lands
    one dispatch at a time, and these three decide whether a dispatch happens at all.

  - `475` is the sharpest: the audit-evidence gate passes the whole verdict as one `--argjson`,
    bypassing the transparent spill `state-write.sh` already implements for caller-supplied values,
    so a large verdict kills the write with `Argument list too long` and **no task can be created**.
    The single writer for `specs/state.json` failing closed on size is a whole-system stop.

  - `613` is an availability defect in the lock layer. `session_liveness()` confirms liveness with
    `kill -0` on a pid that is `pid_source: ancestor-claude` -- the shared process -- so every
    session ever registered from one claude process reads pid-alive forever, and
    `cmd_acquire`'s stale-overlap escalation overrides the 30-minute heartbeat threshold that would
    have recovered it. Observed live: an orphaned `/revise` lock blocked an `/orchestrate` task for
    two full cycles.

  - `514` is the cost side of the same shape. The convergence guard counts `probed_dispatch`, not
    the dispatch set actually emitted, so two byte-identically zero-dispatch cycles incremented
    nothing and the run had to be stopped by operator judgment. Every such cycle is budget spent
    for no work.

  - `574` is here because it is the documentation half of `514`'s subject and shares `task-lock.sh`
    with `613`: the cycle-budget contract describes remaining budget without stating shared-pool
    semantics, which is how an operator mis-reads what a stalled run has left.

  - **No in-batch path overlap carries an unordered collision**: `475` is alone on
    `state-write.sh`, `613` declares no territory at all (see the scope note in the trailing prose),
    and `514`/`574` share only the state-machine document.
- - **One surface, eight defects, and the surface is the handoff itself.** Six of the eight declare
    `orchestrate-cycle-postflight.sh` and its suite -- still the most contended single path in the
    backlog. Batching is the default here precisely because of that overlap, not in spite of it.

  - **`556` leads and an edge was written for it.** `556` and `472` are the same incident
    (`validate-handoff.sh` Check 7 indexing a string-shaped `blockers` element, jq exit 5 escaping
    `set -euo pipefail` as an undocumented crash) filed twice, from opposite ends. `556` owns the
    ruling -- three authorities disagree about the canonical `blockers` shape and it says in its own
    text to settle that FIRST, because the ruling decides which side of the fix is the
    non-conforming one. `472` then conforms the validator, the postflight attribution and the
    authoring instructions to whatever `556` ruled. The two share three declared paths
    (`validate-handoff.sh`, its suite, `orchestrator-handoff-schema.json`), so this is an order a
    record states over real shared territory: **`472` is now declared behind `556`**.

  - **`646` is the same class on the other carrier.** `.return-meta.json`'s status vocabulary has
    no room for terminal outcomes that are legitimate but are not lifecycle-phase names, and all
    four such values emitted across five extensions are rejected by the validator meant to govern
    them. A validator that refuses every legitimate value is indistinguishable, to a caller, from
    one that found a real fault -- the identical failure mode `556` and `472` close on the handoff.

  - **`551`, `519`, `570`, `577`, `609` are the failure-accounting half.** `551` closes a
    stale-handoff detection that has fired across at least twelve distinct records (one of them ten
    times) plus a detection that reached the user with no ledger entry behind it. `519` stops an
    infrastructure transport death being charged as the task's own failure, and `570` -- already
    edged behind it -- stops the stall signal counting commits it cannot attribute to the dispatch
    under judgement. `577` makes a blocker-triggered aux revision consumable by triage, and `609`
    (already edged behind `577`) stops a pending user question charging its own task into
    `failed_tasks` and killing its dependents. A mis-charged failure propagates: it kills dependents
    that were never broken, which is why this sits above the correctness batches rather than among
    them.

  - **The remaining in-batch overlaps were deliberately left unedged.** Five members claim
    `orchestrate-cycle-postflight.sh`; edging all ten unordered pairs would chain defects that are
    genuinely independent, and co-membership is this list's ordering judgment, not graph evidence.
    The admission gate's own `file_scope_collision` deferral serializes them within the batch
    mechanically, and array position states the intended order.
- - **This is the speed batch, and it is placed fourth rather than first for a reason.** Cost work
    is measured against the gate set, so it has to run after the gate set returns an honest verdict
    (batch one) -- otherwise an optimisation is judged against noise. It sits above every
    correctness batch below because the cost it removes is charged to all of them.

  - `607` is already PLANNED and holds two measurements at once: gate 20's orchestrator eager-load
    total over its baseline (`commands/orchestrate.md` plus `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`), which is
    context budget spent on every single dispatch, and the per-gate timeout sensitivity that makes
    gate verdicts load-dependent. `610`, already edged behind it, asks the same per-gate-timeout
    question at full-battery width and adds the dispatch-stall fix.

  - `586` is the standing consumer for the suite and gate wall-clock probes
    (`measure-gate-costs.sh` -> `gate-cost-model.csv`, `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt`), neither of
    which has had anything acting on its output. Its remit is a verdict per suite -- delete,
    optimize, or demote -- which is the only member here that reduces the battery's cost rather
    than its variance. It is PARTIAL, so it resumes rather than starts. `605`, already edged behind
    it, then stops the advisory roster carrying rows for suites that now pass.

  - **Batching these four is forced by territory and serializes to width one.** They share
    `verify-deploy.sh`, `agent-system/extensions/core/scripts/tests/run-all.sh` and `agent-system/extensions/core/scripts/tests/known-failures.txt` three ways over, and both
    `607` and `586` declare `__WHOLE_TREE__`, so the sentinel defer will run them one at a time
    regardless. Shared territory is a reason to batch even at width one; splitting them would mean
    two runs colliding on the same three files with no stated order between them.

  - **Cross-batch note**: `630` (batch one) and `607`/`586`/`605` all claim
    `agent-system/extensions/core/scripts/tests/known-failures.txt`. That overlap is left to array position, since the two batches never
    dispatch concurrently.
- - **`639` leads because it is silent data loss in the evidence base everything downstream reads.**
    `issue-record.sh` accepts `--session` and rejects `--session-id` through its catch-all arm, and
    the script's own prescribed invocation form redirects both streams to `/dev/null`, so a mistyped
    flag writes nothing and says nothing. An empty `issues.jsonl` is then indistinguishable from a
    dispatch that genuinely had nothing to record -- and `/orchestrate`'s conclusion stage treats
    that file as its entire evidence base. Every judgment this list makes about recurrence rests on
    that store being complete.

  - **`477` is the vocabulary the same store is written in**, and it shares
    `context/formats/issue-log.md` with both `639` and `484`. Normalizing the class enum and
    rejecting the aggregate's malformed repeated-flag call before anything else rewrites rows is the
    cheap order.

  - **`484` -> `486` -> `501`/`508` -> `524` is a chain the graph already carries, and it is the
    scope-excursion half of the same concern.** `484` collapses per-path excursion rows into one
    record per drop event, which is what makes the rows readable at all; `486` stops a required
    extension `manifest.json` registration being dropped from a phase commit as an excursion;
    `501` gives the cycle-postflight containment site predicate parity plus a guarded recovery route
    for a dropped path; `508` rules on where shared extension metadata belongs in the allowlist and
    narrows the repo-wide sync tools' writes; `524` rules on the staged-vs-working-tree divergence
    signal and names the partial-stage trap. A dropped path is lost work, so this is functionality,
    not hygiene.

  - **`501` depends on `472`, one batch above.** That is an ordering constraint satisfied by array
    position, not a reason to move either record.
- - **Both failure directions of one mechanism, batched because they are the same files.** Seven
    members over `git-commit-scoped.sh`/`git-commit-phase.sh` and their suites: under-staging loses
    work a dispatch actually did, over-staging commits another session's edits. Neither is
    recoverable by re-running the dispatch, which is why this ranks above the validator and
    composition batches below.

  - **The drop side, rooted at `548`**: `548` harvests a plan's declared contingency files into
    `file_scope` so a legitimately-modified file stops being dropped; `553` (edged behind it) names
    the typst-sync gate as the cause when a refused commit is reported, instead of leaving the
    operator with an unattributed refusal; `598` (also edged behind it) provides the sanctioned
    in-dispatch remedy for a mechanically coupled pair path the V10 containment guard drops. `567`
    ports the deployed-tree containment strip into `git-commit-scoped.sh` so the two commit paths
    stop disagreeing, and `536` adds the source-store-aware commit path plus plan-time registration
    review.

  - **The contamination side, `535` -> `541`**: a phase commit drops its own plan artifact, and
    `git-snapshot.sh --no-revert` artifacts contaminate phase commits with other tasks' files. The
    edge is already carried.

  - **Cross-batch overlap, left to array position**: `484`, `486`, `501`, `508` and `524` (batch
    five) claim `git-commit-scoped.sh` and `git-staging-scope.md` too. Batch five runs first and the
    two never dispatch concurrently, so no edge is asserted between them.
- - **A validator that fails a conforming artifact costs a full dispatch every time it fires**, and
    unlike a missed check it costs that dispatch loudly -- the agent re-does work that was already
    correct. Three of the four members declare `validate-artifact.sh` and its suite, so this is one
    file's worth of false positives.

  - `545` reports a reversed `validate-artifact.sh` invocation as a missing file rather than an
    argument-order fault, which sends the reader after the wrong thing. `564` fixes the Tier
    Justification false positive arising from sentinel path-set membership, and `579` (already edged
    behind it) records the selector's full-path-set aggregation rule in the authoring contract so
    the fix is reachable at plan time rather than only in the script. `575` stops the cross-phase
    ceiling check reading a stop-word as a unit and false-positiving on N-of-M prose.

  - **Placed below the containment batches** because a false failure wastes a dispatch, while a
    containment drop loses its output. Both are real; the loss ranks higher.
- - **What the dispatch body says is what the agent believes.** Four of the six declare
    `orchestrate-build-dispatch.sh` and its suite; the batch is the composition surface itself.

  - `599` gives the batch-gate-deferral directive a narrowing form covering a phase that touches
    only project sources rather than the agent-system deploy tree -- today that directive defers
    work it has no reason to defer, which is throughput. `592`, already edged behind it,
    re-verifies or timestamps a task's recorded starting position at composition time, so a
    dispatch stops being briefed from a stale read.

  - `520` emits deploy ordering in the implement dispatch body, `565` resolves archived prior-art
    paths when composing dispatch and task-description context (today an archived path silently
    resolves to nothing), and `571` invalidates an in-flight dispatch whose `dispatch_seq` has been
    superseded, at consumption time -- a superseded dispatch that still gets consumed is work done
    against a decision already reversed.

  - **`518` sits immediately before `571` on purpose.** `571` is edged behind it, and `518` is the
    propagation record: it states the `blockers[]` admission contract and the
    continuation-on-partial requirement at every handoff-authoring site, across 47 agent files. It
    depends on `472` (batch three), which is where the shape it propagates gets ruled -- propagating
    before the ruling would write the wrong contract into 47 files at once.
- - **A stranded wait is a dispatch that produces nothing and still spends its budget.** Two
    dispatches were stranded by the backgrounded-and-blocked shape, and the lint that exists to
    catch that shape only covers Rule 2. All four members declare
    `context/patterns/bounded-build-waiter.md`.

  - `506` is PLANNED and is the self-inflicted case: the bounded-waiter hook refuses a write whose
    prose documents the very anti-pattern the hook enforces, so the contract cannot be edited
    without an override. Fixing the enforcement before extending it is the cheap order. It declares
    `__WHOLE_TREE__`, so it serializes against the rest of the batch -- which is fine, and the
    reason it leads rather than trails.

  - `542` -> `552` -> `561` is the existing chain: record the launch-side PID-fidelity condition on
    the detach form, extend the lint past Rule 2 to the shape that actually stranded the two
    dispatches, then record the load-sized bound and the diagnostic-preserving output capture.

  - **`641` and `642` are NOT here**, even though they are the same contract's propagation, because
    `641` also depends on `454`, which depends on `439`, which depends on `431`. That chain is one
    batch below; splitting it out keeps this batch dispatchable now instead of blocked on a
    four-deep predecessor.
- - **Every member is a check that exists on paper and does not fire**, which is strictly worse
    than a check that is absent: the absent one is visible in a coverage review, the dead one reads
    as coverage.

  - `521` fixes the agent glob so it matches the `-implement-agent.md` variant -- today whole
    classes of agent file pass a completeness check they were never measured by. `525` repairs the
    always-failing extensions-directory fallback in the task-type detection suite and `510` the
    missing lib dependency in the predispatch-review test fixture; both are suites that cannot
    report a real result at all.

  - `511` -> `523` is the counting half, already edged: require `git grep` rather than plain `grep`
    for scope-hypothesis counts (plain `grep` sweeps a gitignored venv and inflates every count
    derived from it), then make Gate 27's `MISSING_DECLARATION` count call sites instead of
    whole-file substring mentions. `511` and `523` share `shell-script-testing.md`.

  - **Placed below the composition batch** because a dead check costs correctness slowly, while a
    mis-composed dispatch costs it immediately.
- - **One four-deep chain, batched in the order the graph forces.** `431` (PLANNED) records the
    gate-enforced verbatim-duplication exclusion class as durable context, derived from the lint's
    own fragment paths. `474` and `439` both depend on it; `454` depends on `439`; `641` depends on
    `454` and on `561` (batch nine, above); `642` depends on `641`. No member of this chain can be
    pulled forward without pulling the whole chain.

  - **Why it sits here and not with the bounded-waiter batch above**: the content is the same
    contract, but the depth is not. Batch nine's four members are all dispatchable now; these six
    are gated on a record that has to be ruled first. Keeping them apart means the ready work does
    not wait on the gated work, and the ordering constraint between them is expressed by array
    position.

  - `431` declares `__WHOLE_TREE__`, so it serializes against every other claimant in-batch and
    cross-batch alike, including one held by another live session. It leads, so the rest of the
    chain queues behind it anyway.

  - `439` rules on the propagation model, `454` states the result-needed-this-turn criterion for
    choosing the foreground form and names the arrived-but-unconsumed notification as its own wait
    failure shape, `641` re-grounds the documented foreground-wait cap and makes the idiom survive a
    long wait, and `642` re-propagates the amended bullets to the carrying agent contracts and
    reconciles the lint checks. The order is the ruling, then the statement, then the propagation --
    never the reverse.
- - **Batched because they edit the same lint, not because they are both small.** `512` (PLANNED)
    exempts built-in commands from the dead-command-recommendation lint; `590` (RESEARCHED) resolves
    the findings that lint reports for `/ide`. Running them as separate batches would mean two runs
    rewriting one file with no stated order between them.

  - **RE-MEASURE BOTH BEFORE PLANNING.** `590` may already be satisfied in the source store, and
    its declared `file_scope` names the lint one directory above where the file actually sits -- so
    it cannot collide with `512` mechanically even though the two edit the same lint. That
    declaration defect is the reason no edge is written here: there is no measured
    `file_scope_collision` to write one against, and co-membership alone is not evidence of a
    missing graph edge. Fix `590`'s declaration as part of the work.

  - `512` declares `__WHOLE_TREE__`, so the pair serializes to width one regardless.
- - **A generated surface nobody declared is a surface nobody regenerates**, and the stale copy is
    then read as truth by the next dispatch. All four members are about making that surface visible
    at the point it is created.

  - `455` pre-flags the predictable first-run module-invariant failures that wiring a new module
    forces, where the generated-surface knowledge already lives. `502` requires research reports to
    enumerate the generated doc-sync surfaces they touch -- the research-phase counterpart. `517`
    (edged behind `455`) requires a phase commit to regenerate and stage the derived surfaces it
    stales, which is the enforcement end.

  - `457` is here because it is the same leak in the other direction: repo-specific content has
    leaked into the shared agent-system source store, where every consuming repository reads it. It
    is edged behind `455` already and shares `plan-file-scope-harvest.sh` with it.

  - **Below the enforcement batch** because these are contracts to be written rather than checks
    that are currently lying.
- - **A pair, because `338` is the mechanical half of `618`'s ruling.** `618` is a GOAL record: work
    out what leaves files behind in this repository's working tree, uncommitted and un-ignored, and
    produce a per-class disposition verdict -- ignored where the file is runtime state, committed
    where it is durable provenance, never a third pile a human triages by eye. `338` then classifies
    every task-support file as tracked or ignored against that verdict.

  - **This is health, but diagnostic health**, which is why it sits mid-list rather than at the
    head: residue does not break a dispatch, it makes every `git status` read untrustworthy and so
    makes the commit-scope batches above harder to verify. Doing it after those batches land also
    means the census is taken against a tree whose known drop/contamination paths are already fixed,
    rather than against one where they are not.

  - `618` declares no `file_scope` at all -- see the scope note in the trailing prose. Narrow that
    declaration before probing this batch.
- - **The operator-facing surface, batched on real shared territory**: `context/workflows/
    meta-interview.md` is claimed by `438`, `479`, `492` and `581`; `commands/task.md` by `438`,
    `479` and `492`; `context/patterns/backlog-reconciliation.md` by `491`, `492` and `559`;
    `multi-task-creation-standard.md` by `438`, `492` and `559`. Seven records over four shared
    files is a batch by measurement, not by theme.

  - **The order is the graph's**: `438` (dependency-edge rationale conflates semantic and
    serialization grounds, and a semantic edge is filed with no check against landed artifacts) ->
    `479` (every task must name a landing target) -> `492` (corroboration computable, confirm prompt
    gated on it), with `491` (the Pass-2 semantic scorer whose normalization inflates against
    verbose records) ahead of `492` and `580` (AskUserQuestion's real four-option ceiling) ahead of
    `581`. `581` extracts one shared option renderer and adopts it across all four selection
    surfaces, and depends on `580`, `438`, `479` and `492` -- so it is last by necessity.

  - `559` settles the low-specificity shared-path case that produces spurious duplicate-of-open
    verdicts, plus Component 7 under `/orchestrate`.

  - **Placed below the correctness batches** because this is the quality of what gets filed and
    chosen, not whether a filed task can be executed. It is the highest-ranked batch that is not
    about the machinery itself.
- - **Both depend on `479`, immediately above, and on nothing else that is open.** Splitting them
    out of that batch keeps it at seven rather than nine and makes the dependency explicit by array
    position: the contract is stated first, then detected.

  - `480` is the advisory detector for research tasks stranded at RESEARCHED with artifacts but no
    named landing target -- the backlog shape `479`'s gate prevents going forward, applied
    retroactively to what is already filed. `513` mechanically detects a plan phase that closed
    without its own commit.

  - They share `context/contracts/phase-closure.md` with `518` (batch eight), which runs earlier;
    that cross-batch overlap is left to array position.
- - `563` rules between refusing test-fixture registration and pruning on read: the registry at
    `~/.local/share/nvim/neotex-ai/extension-repo-registry.json` held 313 entries of which 311 were
    `/tmp` paths and 2 were real repositories, which makes it unusable as a deploy-enumeration
    source. `583` (already edged behind it) then adds the settings-defaults surface to the loader
    picker.

  - **Both are `neovim`-typed and both edit `lua/neotex/plugins/ai/`**, a subtree no other open
    record in this list claims, so the pair runs without contending against the agent-system work
    above. That independence is why it can sit here rather than competing for a slot near the head:
    it is loader/picker functionality, not orchestration correctness.
- - **One chain, and every edge in it is already carried.** `451` takes the Lean Challenge snapshot
    in the plan phase, where it is still meaningful, instead of leaving it to an implement phase the
    status gate correctly refuses. `462` gives `lean-challenge-snapshot.sh --check` a scope limit so
    a research prototype under `specs/` stops forcing a false ambiguity failure. `452` depends on
    `451` and requires a verification criterion over a repo-wide gate with standing pre-existing
    findings to be baseline-relative rather than absolute; `566` and `509` depend on `452`, and
    `588` on `509`.

  - **`452` is the hinge, and it is the reason this batch is not lower.** An absolute criterion over
    a gate that already carries standing findings is unsatisfiable, so it either blocks a conforming
    dispatch or gets waived -- the same signal-destroying choice batch one exists to remove, one
    level up in the plan contract. `509` then makes a redeploy phase declarable without polluting
    `file_scope` and bars a pre-redeploy phase from asserting a deployed-vs-source drift gate, and
    `588` bars a pre-redeploy step from naming a deploy-tree-resolved subject unless it declares how
    it gets a true read.

  - `566` documents that the `validate-state.sh` cycle check requires `--deep` at every call site
    that specifies it.

  - **Cross-batch overlap, left to array position**: `452`, `509` and `588` claim
    `validate-artifact.sh` alongside batch seven's members, and `plan-format.md` alongside the plan
    authoring batch below. Fourteen open records claim `plan-format.md`; edging on that path would
    merge most of the backlog into one run.
- - **Batched on `lean-plan-compliance-check.sh` and `lean/index-entries.json`**, each claimed
    several ways across these members. `504` reconciles the Goals-block harvester with its documented
    contract and `516` (edged behind it) stops the compliance check failing on not-yet-reached
    end-state deliverables; `537` closes the spot-check's evidence-probe-scoped Goals miss.

  - **The trust-surface half**: `463` states that `lean_goal`'s empty `goals_after` is not evidence
    a declaration elaborates and points step verification at that statement, and `550` (edged behind
    it) probes the Lean LSP index state at dispatch start and propagates the degraded evidence tier
    downstream. A verification step that reads an empty result as a pass is a false green, which is
    why these two rank above the authoring records below.

  - **The context half**: `398` records that a grep for dependents misses rw-site definitional
    unfolding and makes that guidance reachable at plan time; `399` (edged behind it) records three
    measured gotchas -- IO-forced timing harnesses, docstring/`set_option` order, shadowed `decide`.

  - **Cross-batch note**: `560` (batch one) claims `lean-plan-compliance-check.sh` too. It clears a
    deploy-blocking shellcheck finding in that file and runs first; the overlap is resolved by array
    position rather than an edge.
- - `549` gives the Lean `unusedArguments` remedy a narrow route instead of the wholesale
    `runLinter --update` rewrite; `576`, already edged behind it, then records the verification-tier
    gate-naming rule, the Constraints-consumed marker duty, and the build-guard replay window over
    the result.

  - **Kept as its own two-record run rather than folded into the Lean batches on either side.**
    `576` also claims `lean/index-entries.json`, which `398`, `399`, `536`, `539` and `540` claim
    across three different batches; splitting those into separate runs rather than edging them on
    co-membership is the standing treatment for that path.
- - **`539` is the root and everything else here quotes it.** It states the precedence and
    snapshot-prerequisite rules for a Lean plan's pinned Challenge block; `540`, `544` and `595`
    depend on it directly, and `593`-`596` form a further chain among themselves. Eleven in-batch
    path overlaps, all already carried by direct edges.

  - `540` records five measured Lean facts (the `decide`-synthesis working form, the axiom-free
    `maxRecDepth` remedy, the probe guard's total arithmetic, instance synthesis at a coerced
    carrier, structural recursion not reducing by `rfl`). `544` makes a fixture-dependent gate
    statement expressible and mechanically checkable in a Challenge block. `593` requires pinned
    signatures to be measured at plan time, `594` sizes symmetric-pair phases and iteration
    obligations separately, `595` defines Goal Polarity semantics for decision-gate plans, and `596`
    separates generator-written files from hand-edited read-only scope declarations.

  - **`593`-`596` all depend on `599` (batch eight) and `593` on `451` (batch eighteen)**, both of
    which run earlier. Those are ordering constraints satisfied by array position.

  - **Placed here because it is plan-authoring quality, not execution correctness.** Every member
    makes a future plan better; none unblocks a dispatch that is currently stuck.
- - `390` migrates seven mis-sited agent-system tasks out of the consumer repository and retires one
    duplicated upstream; `481`, already edged behind it, rules on and migrates the 32-record delta
    accumulated since that first migration. The order is forced -- `481` is defined relative to
    `390`'s result.

  - **This is backlog siting, not machinery**, so it ranks below everything that changes how a
    dispatch runs. It does matter: a task sited in a repository whose filesystem does not contain
    its declared edit target cannot be executed there at all.
- - `410` gates result sharing on a `pre==post` fingerprint in `lake-build-guard.sh`; `533`, already
    edged behind it, closes the same stale-replay behaviour for the `env lean FILE` entry point. One
    mechanism, two call sites, and the second is only expressible once the first has settled what a
    valid share looks like.

  - **A stale replay is a false green on a build**, which is why this is not lower; it sits here
    rather than higher because the surface is one script in the Lean extension and nothing in the
    core lifecycle reads it.
- - `453` carries the degraded-retrieval signal into the zero-result case, where the briefing drops
    it today and the agent is left to invent a fallback; `546`, already edged behind it, diagnoses
    the zero-result retrieval itself and settles the contract. A briefing that silently reports
    nothing found, when what happened was degraded retrieval, is a false negative the agent cannot
    detect -- the same failure shape as a crashing validator, in a surface only `--lit` dispatches
    read.

  - `437` repairs the Zotero sqlite-reconstruction export path: lost CSL fields and a shrink guard
    calibrated against a corrupt baseline.

  - **Below the core batches because the blast radius is bounded to literature-mode dispatches**,
    which are a minority of runs.
- - `383` adds a `/reconcile` command aggregating `docs-stage.sh` and `book-health.sh --json` drift
    into one report and proposing follow-up tasks; `384`, already edged behind it, then adjudicates
    whether a reconciliation postflight lifecycle hook is warranted and adds it only if the ruling is
    yes. All three members claim `books/manifest.json`, which is why they run together.

  - **`342` is HOLD and is listed as an ordering constraint, not as available work.** The corpus
    refactor waits on an external version stamp reaching `0.1.0` in the consuming repository; the
    lift is an owner action, and `/orchestrate` admits a held record only under an explicit forcing
    flag. It is kept in the batch rather than cut so the territory overlap stays visible.

  - **Last of the extension batches** because nothing in the core lifecycle depends on any of it.
- - **A batch of genuinely independent records, grouped because each is a single ruling with no
    predecessor and no shared territory to serialize against.** This is the one place in the list
    where membership is not a shared-file claim, and it is stated rather than disguised.

  - `456` exempts private npm/Cargo manifests from `/tag`'s version gate -- today that gate is
    unpassable for a private manifest, so the command cannot complete. `421` closes three gaps in
    the telemetry `--meta` evidence consumer. `529` evaluates whether `formal:logic` implement
    routing should resolve to a Lean-capable agent. `530` lands the three agent-system context
    extensions recorded by the cslib omega-automata survey.

  - **Each is small and each is real**; none is on a path another record waits for, which is
    precisely why they rank here rather than higher.
- - **The tail is explicitly the tail.** Every member improves a document; none changes what a
    dispatch does, which is the measure this ordering uses. Stating that plainly is better than
    promoting them on the grounds that they are cheap.

  - `473` (RESEARCHED, edged behind `472` in batch three) strips record-versioning language from the
    boundary-owned architecture docs. `522` fixes report/summary heading-skeleton conformance across
    agents. `640` adds a derived-percentage bug class to the census methodology standard. `557`
    (RESEARCHED) records the half-line test as a Lean context pattern note.

  - `557` carries topic `decidability`, which is not declared in `active_topics` and so renders
    after the curated topics -- a declaration defect worth fixing while the record is open, not a
    reason to reorder it.

**The `__WHOLE_TREE__` claim is the binding constraint on batch width, not fan-out.** A record declaring the sentinel serializes absolutely against every other claimant, in-batch and cross-batch alike, including a claimant owned by another live session. Measured 2026-11-06: a six-record batch landed research and planning for all six in parallel, then implemented only one, because the remaining four queued behind a single claimant and then behind a cross-batch claimant in another session; three were still unimplemented when the convergence guard stopped the run.

**The claimant roster is five: `431`, `506`, `512`, `586` and `607`** (re-measured 2026-11-18; `476` and `585` have landed). Two of the five now sit in one batch by design: `586` and `607` share `verify-deploy.sh`, `agent-system/extensions/core/scripts/tests/run-all.sh` and `agent-system/extensions/core/scripts/tests/known-failures.txt`, so batch four serializes to width one and says so. The other three lead their own batches (`506` batch nine, `431` batch eleven, `512` batch twelve) for the same reason -- a claimant placed first lets the rest of its batch queue behind it instead of colliding with it mid-run. **The head is clear**: no member of batches one, two or three declares the sentinel, so the three highest-priority runs contend only with each other and with whatever a cross-session claimant holds.

**What changed structurally this pass.** Three fully-landed batches were retired. The whole list was re-ordered against the health/functionality/speed rule stated above, which moved four things materially: the verification-substrate work rose from the middle to batch one; a new batch two was assembled from three previously unbatched records that each stop progress outright (`475`, a large audit verdict killing `state-write.sh` with `Argument list too long` so no task can be created; `613`, an orphaned same-process lock that the liveness path can never reap; `514`, a convergence guard counting the probe set instead of the emitted dispatch set) plus `574`, the budget documentation they are read through; the handoff and return-meta validation work was consolidated into one eight-record batch three, since a mis-charged failure kills dependents that were never broken; and the cost batch settled at four, below verdict-truth and above every correctness batch. Eighty-one previously unbatched open records were placed. **121 of 122 open records are now batched**; the single exception is the held email substrate (`498`), which is an owner decision, not available work.

The gate exempts research and plan dispatches (neither regenerates the tree) and defers only implement, so a claimant still researches and plans freely while the lane is occupied.

**Admission-probed only in part, and every probe recorded so far is weaker than it looks.** Each one put only research or plan dispatches in cycle 0, and both phases are exempt from the claim gate and the collision gate alike -- so no probe has yet exercised the implement-wave `file_scope` collisions these batches are ordered around. Treat an unprobed batch as unprobed: probe before committing to one, and check `task-lock.sh session-list` for a live session whose scope overlaps, since a cross-session claimant is invisible to the edge graph. Batch three is the one most worth probing before dispatch: five of its eight members claim `orchestrate-cycle-postflight.sh`, and the batch deliberately relies on the collision gate to serialize them rather than on edges.

**On edge declaration**, three rulings stand:

- **Only a `file_scope_collision` verdict means an edge is missing.** `whole_tree_claim` and `self_modifying` verdicts say so themselves -- *"this is an ORDERING CONSTRAINT, not an exclusion"* -- and resolve in a later cycle unaided. **An edge belongs to a path overlap; a sentinel overlap is left to the sentinel defer.** Declaring an edge between two records whose only shared territory is `__WHOLE_TREE__` asserts a semantic claim neither record supports and chains unrelated strands together for nothing.

- **The exemption is direct-edge only, never transitive, and it is scoped to the batch being dispatched.** A heavily shared path is NOT grounds for edging every record that touches it. Re-measured 2026-11-18, `context/formats/plan-format.md` has fourteen open claimants, `agents/planner-agent.md` nine, `git-commit-scoped.sh` eight, and `orchestrate-cycle-postflight.sh`, `test-git-commit-scoped.sh` and `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` seven each; the edges worth declaring are the ones inside the batch actually being dispatched, and every other overlap is advisory, resolved by array position. The worked example this pass is batch three: five members claim `orchestrate-cycle-postflight.sh` with only two of the ten pairs ordered, and the eight remaining pairs were left to the collision deferral rather than chained, because they are independent defects on one file and co-membership is this list's own judgment, not graph evidence.

- **A transitive order made direct, or an order a record states itself, is the edge class this list writes; a bare sibling overlap is not.** One edge was written this pass: **`472` behind `556`**. The two are the same incident filed twice -- `validate-handoff.sh` Check 7 indexing a string-shaped `blockers` element, jq exiting 5, and `set -euo pipefail` converting that into an undocumented crash a caller cannot tell from a real validation failure. `556` owns the ruling (three authorities disagree about the canonical `blockers` shape, and its own text says to settle that FIRST because the ruling decides which side of the fix is non-conforming); `472` conforms the validator, the postflight attribution and the authoring instructions to it, and `518` then propagates that contract to 47 agent files. The pair shares three declared paths, so this is an order a record states over measured shared territory. The sibling overlaps left unedged include `560`/`504`/`516` on `lean-plan-compliance-check.sh`, `630`/`607`/`586`/`605` on `agent-system/extensions/core/scripts/tests/known-failures.txt`, and `632`/`607` on `orchestrator-context-budget.json` -- each split across batches that never dispatch concurrently. Two older proposals are still held for an owner ruling rather than written: `452` behind `451` and `473` behind `472`.

**Every batch was scanned mechanically this pass for a member listed ahead of an open predecessor, and the list is clean**: across all 27 batches, no member appears in an earlier batch than, or at an earlier position than, any still-open record it depends on. One violation was found and fixed during authoring (`630` ahead of `629` inside batch one). The scan returns silence rather than a clean result in exactly two places -- `613` and `618` declare no territory at all, so no collision scan over them means anything.

**The two held records are not waiting on engineering.** The books-corpus refactor (`342`) waits on an external version stamp reaching `0.1.0` (the consuming repository's own book-convention record still reads a pre-release stamp) and is kept inside batch twenty-five so its territory overlap with `383`/`384` stays visible. The email preference-harvest substrate (`498`) waits on an operator decision about integrating email into the hosted store and is the one open record in no batch. Neither lift is engineering work, and `/orchestrate` admits a held record only under an explicit forcing flag. Nothing depends on either.

**Scopes worth narrowing first.** Re-measured 2026-11-18: **two** open records carry no `file_scope` at all -- `613` and `618` -- down from seven, and that is the entire class, since no open record declares an empty array. Both sit in batches whose other members are narrowly scoped (`613` in batch two with `475`/`514`/`574`, `618` in batch fourteen with `338`), so an admission probe over either batch returns a result that is clean for the wrong reason. **Fix those two declarations before probing.** Two narrower declaration defects remain live: `590` declares its lint one directory above where the file actually sits, so it cannot collide with `512` even though the two edit the same lint -- which is why batch twelve pairs them without an edge; and `557` carries topic `decidability`, undeclared in `active_topics`, so it renders after the curated topics. Of the directory-form declarations that remain, every one is scoped to a single extension subtree -- `342` (three `books/` directories), `384`, `453`, `530` and `544`. None is a whole-corpus discovery scope, and none is a defect.

## Open work

**Core agent system (38)**
```
439 blocked:431     Rule on the propagation model for the bounded-wait agent contract
452 blocked:451     Require a verification criterion over a repo-wide gate with standing pre-exis...
454 blocked:439     State the result-needed-this-turn criterion for choosing the foreground form,...
473 blocked:472     Strip record-versioning language from the boundary-owned architecture docs
474 blocked:431     Repair the broken relative links in agent-frontmatter-standard.md
479 blocked:438     Require every task to name a landing target: a creation-time gate on report-o...
480 blocked:479     Advisory detector for research tasks stranded at RESEARCHED with artifacts bu...
492 blocked:479,491 Make backlog-audit corroboration computable and gate the confirm prompt on it
517 blocked:455     Require a phase commit to regenerate and stage the derived surfaces it stales
523 blocked:511     Make Gate 27 MISSING_DECLARATION count call sites, not whole-file substring m...
524 blocked:484,501 Rule on a staged-vs-working-tree divergence signal for a pathspec commit, and...
566 blocked:452     Document that the validate-state.sh cycle check requires --deep at every call...
579 blocked:564     Record the selector's full-path-set aggregation rule in the Tier Justificatio...
581 blocked:438,479,492,580  Extract one shared AskUserQuestion option renderer and adopt it acro...
588 blocked:509     Bar a pre-redeploy plan step from naming a deploy-tree-resolved subject unles...
605 blocked:586     Flag an advisory known-failures roster row whose named suite now passes
338 ready           Classify every task-support file as tracked or ignored
410 ready           Close the result-sharing replay hole in lake-build-guard.sh: gate sharing on ...
421 ready           Close three gaps in the telemetry --meta evidence consumer
431 ready           Record the gate-enforced verbatim-duplication exclusion class as durable agen...
456 ready           Exempt private npm/Cargo manifests from /tag's version gate
475 ready           Close the audit-evidence gate internal --argjson hole: a large verdict dies w...
491 ready           Fix the Pass-2 semantic scorer whose normalization inflates against verbose c...
502 ready           Require research reports to enumerate generated doc-sync surfaces
506 ready           Stop the bounded-waiter hook refusing a write whose prose documents the anti-...
519 ready           Infra exempt transport error dispatch deaths
520 ready           Emit deploy ordering in implement dispatch body
521 ready           Fix the agent glob to match the -implement-agent.md variant
525 ready           Repair the always-failing extensions-directory fallback in the task-type dete...
564 ready           Fix validate-artifact.sh Tier Justification false positive from sentinel path...
565 ready           Resolve archived prior-art paths when composing dispatch and task-description...
574 ready           Correct the cycle-budget contract to state shared-pool semantics wherever rem...
575 ready           Stop the cross-phase ceiling check reading a stop-word as a unit and false-po...
580 ready           Correct the interactive-selection threshold model to AskUserQuestion's real f...
590 ready           Resolve the /ide dead-command-recommendation findings
613 ready           session_liveness_same_process_orphan_lock
618 ready           working_tree_residue_disposition_policy
646 ready           return_meta_terminal_status_vocabulary
```

**Extensions (7)**
```
342 HOLD            Refactor the books extension's context corpus against the settled convention:...
498 HOLD            Replace the email preference harvest tally substrate
384 blocked:383     Adjudicate whether a books reconciliation postflight lifecycle hook is warran...
457 blocked:455     Repo-specific content has leaked into the shared agent-system source store
383 ready           Add a /reconcile command to the books extension: aggregate docs-stage.sh and ...
522 ready           Fix report/summary heading-skeleton conformance across agents
563 ready           Make the extension repo registry usable for deploy enumeration: rule between ...
```

**Literature (2)**
```
437 ready           Repair the Zotero sqlite-reconstruction export path: lost CSL fields and a sh...
453 ready           Carry the degraded-retrieval signal into the zero-result case, where the brie...
```

**Neovim (1)**
```
583 blocked:563     Add a settings-defaults surface to the agent system loader picker
```

**File scope lifecycle (7)**
```
484 blocked:477     Collapse per-path scope excursion issue rows into one record per drop event
486 blocked:484     Stop a required extension manifest.json registration being dropped from a pha...
501 blocked:472,484,486  Give the cycle-postflight containment site predicate parity and a guarde...
508 blocked:486     Rule on where shared extension metadata belongs in the containment allowlist,...
509 blocked:452     Make a redeploy phase declarable without polluting file_scope, and bar a pre-...
455 ready           Pre-flag the predictable first-run module-invariant failures that wiring a ne...
567 ready           Port the deployed-tree containment strip into git-commit-scoped.sh
```

**Lean extension (7)**
```
399 blocked:398     Record three measured lean4 gotchas: IO-forced timing harnesses, docstring/se...
462 blocked:451     Give lean-challenge-snapshot.sh --check a scope limit so a research prototype...
516 blocked:504     Stop the Lean plan compliance check failing on not-yet-reached end-state deli...
398 ready           Record that a grep for dependents misses rw-site definitional unfolding, and ...
451 ready           Take the Lean Challenge snapshot in the plan phase, where it is still meaning...
463 ready           State that lean_goal's empty goals_after is not evidence a declaration elabor...
504 ready           Reconcile the Lean Goals-block harvester with its documented contract
```

**Orchestrator (6)**
```
472 blocked:556     Stop validate-handoff.sh aborting on a string-shaped blockers array, and stop...
513 blocked:479     Mechanically detect a plan phase that closed without its own commit
518 blocked:472     State the blockers[] admission contract and continuation-on-partial requireme...
610 blocked:607     full_gate_verification_ceiling_and_stall
477 ready           Normalize issue-log class vocabulary and reject the aggregate's malformed rep...
514 ready           Convergence guard blind to zero-dispatch cycles
```

**Agent system (52)**
```
481 blocked:390     Rule on and migrate the 32-record mis-sited agent-system task delta accumulat...
533 blocked:410     lake-build-guard replays stale result for env lean FILE
540 blocked:539     Record five measured lean4 facts: the decide-synthesis working form, the axio...
541 blocked:535     Stop git-snapshot.sh --no-revert artifacts from contaminating phase commits w...
544 blocked:539     Make a fixture-dependent Lean gate statement expressible and mechanically che...
546 blocked:453     Diagnose the zero-result literature retrieval and settle the degraded-signal ...
550 blocked:463     Probe the Lean LSP index state at dispatch start and propagate the degraded e...
552 blocked:542     Extend the bounded-waiter lint beyond Rule 2 to the backgrounded-and-blocked ...
553 blocked:548     Name the typst-sync gate as the cause when git-commit-scoped.sh reports a ref...
561 blocked:552     Record the load-sized bound and the diagnostic-preserving output capture on t...
570 blocked:519     Stop the stall signal firing on commits it cannot attribute to the dispatch u...
571 blocked:518     Invalidate an in-flight dispatch whose dispatch_seq has been superseded, at c...
576 blocked:549     Record the Lean verification-tier gate-naming rule, the Constraints-consumed ...
592 blocked:599     Re-verify or timestamp a task recorded starting position at dispatch composition
593 blocked:451,599 Require pinned Lean Challenge signatures to be measured at plan time
594 blocked:593,599 Size symmetric-pair phases and iteration obligations separately
595 blocked:539,593,594,599  Define Goal Polarity semantics for decision-gate plans
596 blocked:593,594,595,599  Separate generator-written files from hand-edited read-only scope de...
598 blocked:548     Provide a sanctioned in-dispatch remedy for a mechanically coupled pair path ...
609 blocked:577     Stop a pending user question from charging its own task into failed_tasks and...
630 blocked:629     Give test-deploy-propagation.sh and test-gate-registry-resolution.sh declared...
641 blocked:454,561 Re-ground the documented foreground-wait cap and make the bounded-waiter idio...
642 blocked:641     Re-propagate the amended bounded-wait contract bullets to the carrying agent ...
390 ready           Migrate seven mis-sited agent-system tasks out of BimodalLogic and retire one...
438 ready           Dependency edges conflate semantic and serialization rationale, and a semanti...
510 ready           Fix a missing lib dependency in the predispatch-review test fixture
511 ready           Require git grep, not plain grep, for scope-hypothesis counts
512 ready           Exempt built-in commands from the dead-command-recommendation lint
529 ready           Evaluate whether formal:logic implement routing should resolve to a Lean-capa...
530 ready           Land the three agent-system context extensions recorded by the cslib omega-au...
535 ready           Carve a task's own specs/ artifacts out of git-commit-phase.sh's containment ...
536 ready           Source-store-aware commit path and plan-time registration-description review
537 ready           Plan-compliance spot-check misses evidence-probe-scoped Goals
539 ready           State the precedence and snapshot-prerequisite rules for a lean plan's pinned...
542 ready           Record the launch-side PID-fidelity condition on the bounded-waiter detach form
545 ready           Report a reversed validate-artifact.sh invocation as an argument-order fault,...
548 ready           Harvest a plan's declared contingency files into file_scope, and stop the con...
549 ready           Give the Lean unusedArguments remedy a narrow route instead of the wholesale ...
551 ready           Close the recurring stale-handoff defect and find out why the return-meta sch...
556 ready           Fix validate-handoff.sh crash-as-false-negative and settle the canonical bloc...
559 ready           Stop one low-specificity shared path from producing duplicate-of-open, and se...
560 ready           Clear the three standing verify-deploy findings blocking a clean nvim deploy
577 ready           Make a blocker-triggered aux plan-revision consumable by triage, and stop the...
599 ready           Give the batch-gate-deferral directive a narrowing form that covers a phase t...
607 ready           Resolve the gate 20 orchestrator context-budget overage and the per-gate time...
629 ready           Fix the two-engine defect: scan_all_artifacts' sync_scan allow-list post-filt...
631 ready           Replace test-typescript-verify.sh's fixed-depth REPO_ROOT walk with a boundar...
632 ready           Stop orchestrator-context-budget.json's derivation log from re-breaking the t...
633 ready           Resolve the stray duplicate .claude-extensions.json sitting inside the core e...
639 ready           Make issue-record.sh failures visible instead of silently losing the evidence...
640 ready           Add a derived-percentage bug class to the census methodology standard
645 ready           repair_seven_failing_gate8_suites
```

**Decidability (1)**
```
557 ready           Record the half-line test as a lean4 context pattern note
```

**Uncategorized (1)**
```
586 PARTIAL         Stand up the suite and gate wall-clock cost consumer: delete, optimize, or de...
```

## Checks before and after every call

- `orchestrate-cycle-plan.sh --dry-run --state-file specs/state.json <tasks>` — space-separated.
  Admits what you expect; `md5sum specs/state.json` unchanged.
- `validate-state.sh --deep` — measure before your work too; today's baseline is 0 failed, 8 warnings (2026-11-11).
- `tests/run-all.sh --jobs 4` — read the `EXPECTED`/`NEW` split and the roster, not the tally; read
  the exit code directly, never through `tail`/`head`. Baseline 2026-11-11: **178 passed, 7
  failed (5 expected, 2 NEW), 2 skipped, 187 total**; the 2 skipped were an exec-bit regression
  since repaired, and both pass standalone, so a fresh run should read 180 passed / 0 skipped.
  **Read the skipped count too** — it is not in the `EXPECTED`/`NEW` split and a skip is silent.
  **Re-run every `NEW` row in isolation before treating it as a finding** — both NEW rows in that
  run were green standalone. **Do not write a tracked file while the battery runs**: a suite
  asserting over the live tree false-fails.
- `verify-deploy.sh --skip-slow` — before and after, and compare. **Never concurrently with the
  battery.** A standing red is not permission to ignore a new one.
- A completion postflight refused with exit 6 self-clears on the next redeploy checkpoint, but the
  promotion pass only sees the current invocation's `task_numbers`; a task refused in one run is
  invisible to later runs. `reconcile-task-status.sh <N> <session>` promotes it by hand, and only
  once the source store is fresh.
- To tell a working dispatch from a stranded one, read artifact mtimes and live child processes.
  Absent `.orchestrator-handoff.json` is NOT a stall signal — research never writes one.
- **A record batched against an in-flight task's scope burns the rest of the invocation.** It
  re-defers every cycle and the convergence guard halts the whole batch after 3 zero-dispatch
  cycles (measured 2026-11-05: one record deferred against a since-archived in-flight task for
  cycles 3-5). The sibling
  records still complete; the deferred one simply never dispatches. Probe with `--dry-run` or
  `orchestrate-suggest-next-batch.sh --next-batch` first rather than discovering it mid-run.
- Edges go through `state-write.sh`, acyclicity confirmed afterwards by `validate-state.sh --deep`.
  `--depends-on-add` cannot reach a `not_started` task, and there is no edge-removal flag at all.
- If a dead owner holds `specs/.gate-lock`, release it by its own token
  (`task-lock.sh gate-release <token>`). Gate 8 now traps `INT`/`TERM`/`HUP`, so only `SIGKILL`
  leaks it, self-healing after 1800 s.

## Settled decisions (do not re-litigate)

1. **Batch of one.** One engine; single-task is a batch of one. Team mode deleted; hard mode kept, per-invocation.
2. **The orchestrator never asks and never decides.** Only an agent-surfaced `user_decision` reaches the user, once, at cycle end. `blocking: false` proceeds on the agent's recommendation.
3. **Research-first is the default** for a fresh task; `--fast` restores planner-first.
4. **`--dry-run` prints the plan it would dispatch.** No separate dry-run report.
5. **No fixed consumer validation gates.** The checks above are recommended, not blocking.
6. **A linear chain of small tasks serializing on one file is one task with phases** — at creation time, and applied late when it was not.
7. **`file_scope` warnings are live input.** In-batch collisions block, cross-batch are advisory. Decision 17 does not weaken this: an *unordered* overlapping pair shares a wave and writes concurrently.
8. **Rule before mechanism** for the vimtex hazard.
9. **Skeleton plans terminate through the completion-claim gate.** No `pr_ready` outside `type=pr`.
10. **No third automated deploy-trigger site.** Exactly two: `command-gate-out.sh` + `orchestrate-cycle-plan.sh`, per `test-lint-deploy-caller-wrap.sh`.
11. **One grant mechanism.** A single-use token bound to action, remote, branch and sha, minted only where the harness can prove the user typed it. Nothing the model writes is a grant. PR/MR creation and `/merge` stay user-only.
12. **A grant may authorize a plain push of the default branch.** Every force form on the default branch, bare `--force` anywhere, and all bulk/deletion refspecs stay excluded, checked before any grant lookup.
13. **`known-failures.txt` is the only known-failing list.** Advisory; never changes which suites run. Never keep a prose copy elsewhere. A `needs-owner` row is a known gap owed a follow-up task. **Shell suites only** — plenary Lua specs have no baseline at all.
14. **One shared working tree, always.** Per-dispatch `git worktree` isolation removed, not narrowed. Safety rests on `file_scope`, edges and the five contention inputs; build contention is closed by refusing to co-schedule two build-heavy implement tasks. Cost was not the reason and must not be cited as it. Record: `specs/decisions/worktree-isolation-removal-verdict.md`.
15. **Gate 8's deployed-tree coverage is knowingly reduced** on wall-clock grounds: the redeploy checkpoint runs `--skip-slow`, so suites resolving from the *deployed* tree are unverified against a fresh deploy — 52 of 91 narrow core suites (57.1%, CARRIED-UNVERIFIED 2026-11-05), classified not excluded. The record that owned the narrower fix has landed; re-measure the ratio before citing it again.
16. **A systemic cost is filed as one standing task against a probe's output**, not a stream of point defects. Duplication, dead code and slow tests never break anything, so defect-driven intake cannot see them. **`script-inventory.sh` has no standing consumer since its own landed** (re-measured 2026-11-09) — file a new one before the next systemic cost needs somewhere to go.
17. **An unordered territory overlap is resolved by adding the edge, not by separating the pair** (owner ruling). Width 1 is a correct outcome; the property defended is collision visibility and ordering, never wall-clock. A "never with" note is not an acceptable rendering, and a bare exclusion must never stand in for an edge nobody added. Carve-outs: (a) an owner-blocked predecessor that cannot progress — separate and state why; (b) breadth — narrow the `file_scope` instead, except where decision 19 applies.
18. **Settings drift is repaired by making the merge self-healing, never by a migration script** (owner ruling). Hook entries dedupe by *identity* — the `hooks/NAME.sh` invoked, plus event and type. Mandatory carve-out: a command not recognizable as a `.claude/hooks/*.sh` invocation is never matched, moved or deduped. Consequences: (a) a hook registration must live in a fragment surface, since one living only in install-once `root-files/settings.json` is reachable by no resync; (b) the repair for a deploy predating the fix is `rm .claude/settings.json` then reload — `--wipe` restores its own snapshot as the merge base and reintroduces the staleness.
19. **A whole-corpus record runs alone, and its coarse `file_scope` is not a defect to narrow** (owner ruling). Where the territory is directory roots spanning the corpus because the work does, decision 17(b) has nothing to narrow to. Its overlap warnings are correct output: they are what identifies it as a bottleneck.
20. **A near-duplicate record is folded, not merely ordered** (owner ruling). The survivor absorbs the other's text **verbatim**, every edge is re-pointed **before** archiving, and the folded record names the survivor and the grounds. A record whose obligation a landed artifact already discharges is abandoned citing that artifact, not left open as a reminder.

## Standing rules

1. **Agent-system defects get filed here.** A fix in a consuming repo's `.claude/` is wiped on reload.
2. **`.claude/**` is a deploy artifact.** Edit `agent-system/extensions/**`, then resync. `settings.json` and `settings.local.json` are **install-once** — copied only when absent; put hook registrations in a fragment surface (decision 18).
3. **`TODO.md` is generated from `state.json`.** Edit `description` via `state-write.sh`, then `generate-todo.sh`. Same for this file's counts and rosters — generate them.
4. **Propose, then apply, across repos.**
5. **Verify by execution, not by reading.** Re-measure before acting. *CARRIED-UNVERIFIED* figures must be re-derived.
6. **The lead never reads a report, plan, summary, description or context file during the loop.**
7. **This file describes the current plan only.** No revision history, no pass numbers.
8. **A scope cut justified by an unverified premise is not a scope cut.** Test the premise before dropping the work it would make unnecessary.
9. **A dispatch premise can go stale between creation and dispatch.** Measured repeatedly: three of five research dispatches found their premise partly wrong (2026-10-08); a record's entire figure pair had moved and its gate now passed (2026-11-03); two Gate state entries here were resolved by unrelated work within a day (2026-11-04). Re-derive first; report the correction rather than implementing against it.
10. **A redundancy census is re-derived, never remembered.** Fan-out, unordered-overlap counts and duplicate readings all change with every edge and every closure. Compute from `state.json` plus `scripts/lib/file-scope-overlap.sh` with transitive closure as the ordering test.

## Unfiled observations (none worth a task yet)

- **An archived record's cost premise can be contradicted by later measurement.** The record
  that rejected deploying before implement-phase postflight did so because "the cost it removes
  is already small and self-resolving", reasoning from a 2-task batch; it is archived, so its
  verdict stands unless reopened. Measured since: the completion-deploy gate refused 4 times
  across 3 tasks (2026-11-04), then both implement dispatches in a 3-task batch (2026-11-05),
  each costing one extra cycle and one `orchestration paused` commit. Two independent runs,
  roughly one extra cycle per meta task that touches `agent-system/extensions/**`. Re-asking that
  record's question is duplication; challenging its premise with the frequency data is not. Owner
  call, unfiled.
- **A shell suite committed without its exec bit is skipped, not failed, and nothing detects it.**
  Measured 2026-11-11: two suites were committed mode 644 on 2026-11-10 and `run-all.sh` reported
  both as `[SKIP] not executable (exec-bit regression?)`, counting them in its skipped column
  rather than its failures — 41 assertions that had never run. Restoring the bit was a one-line
  `chmod +x` and both pass (21 passed / 0 failed and 20 passed / 0 failed). The gap is
  structural, not instance-specific: `known-failures.txt` cannot carry a skip (decision 13 scopes
  it to failing suites), the discovery predicate names the condition in its own message without
  failing on it, and a skipped suite is invisible in the `EXPECTED`/`NEW` split the battery is
  read by. A gate that fails on any non-zero skip count, or a creation-time mode check, would
  close it. (`test-orchestrate-cycle-plan.sh`'s previously uncharacterized budget failure is
  resolved: it passed in the same run.)
- **A record's `file_scope` can be wrong or go stale, and nothing detects it.** Re-confirmed
  2026-11-11: `590` declares
  `agent-system/extensions/core/scripts/lint-dead-command-recommendations.sh`, which does not
  exist — the `lint/` path segment is missing — so its real collision with `512` over that lint is
  invisible to the admission gate, and a wrong path is indistinguishable from a path the task will
  create. The detection gap is untouched. `plan-file-scope-harvest.sh` widens a scope at plan
  postflight but never prunes a path that has since vanished, and no check compares a non-terminal
  record's declared scope against the filesystem (`file_scope` is documented as descriptive and not
  filesystem-validated, which is the design, not the gap). Cheap probe: for every non-terminal
  record, test each non-glob, non-directory entry for existence and report the misses — strictly
  advisory, since a scope legitimately names files a task will create, but a miss on a path whose
  *sibling directory* exists is a strong typo signal and would have caught (a).
- **Nothing represents "this record's output constrains that record's design" except an edge.**
  A record whose `file_scope` names only its own `specs/` directory is invisible to overlap
  detection however much its verdict gates. Self-correcting once a plan lands —
  `plan-file-scope-harvest.sh` widens the scope at plan postflight — so the exposure is the
  window between creation and plan.
- **A dispatched agent can end its turn with a backgrounded command pending**, leaving no handoff
  and no return metadata; nothing auto-detects "stopped without returns". **Two states look
  alike**: an agent waiting on its own live child still takes tool rounds, so a message recovers
  it; a stranded agent takes none, so recovery is stop, postflight, re-dispatch at the same
  `dispatch_seq`. Check for a live child first. Detector: `dispatch-strand-probe.sh`.
- **`roadmap-integration.sh --regenerate` cannot refresh an authored Open-work label, and silently
  pinned twenty stale ones.** Measured 2026-11-11: every open record now carries a `title` (0
  missing out of 137, re-measured directly against `state.json`), yet this file's Open work block
  still rendered `project_name` slugs for twenty of them — `sweep_task_support_file_tracked_or_ignored`
  where the title reads "Classify every task-support file as tracked or ignored". The cause is the
  retention parser: an authored line "wins verbatim, no truncation", and `.title // .project_name`
  is consulted only for a record with no authored line at all, so a label authored while the
  record had no title is never revisited. The remedy applied by hand was to delete the twenty
  lines and re-run `--regenerate`, which re-rendered all of them from `.title`. **Nothing detects
  this**, and the same mechanism pins any other authored annotation whose underlying record has
  moved on. Also relevant to the record making this file generated: a retention parser that
  cannot tell a deliberate override from a stale one is what that record has to replace, not
  inherit.
- **`orchestrate-predispatch-review.sh` Class B tests for a literal-null `title`, not an absent
  key.** There are zero literal nulls, which is why it correctly reports 0 findings even when the
  absent-key count is high. Any record filed against title coverage must target the absent-key
  case, or widen Class B's predicate to cover both. The creation-time gap that refills the set is
  still unowned, even though the current count is 0.
- **Neither `/todo` nor `/review` wires the roadmap generator to its own command.** `--prune` and
  `--regenerate` are still run by hand. Note 436 retires `/review`, so whatever wires
  `--regenerate` should wire it to the survivor.
- **`roadmap-integration.sh --prune` misparses a Run line whose trailing comment is 2 spaces away**
  (needs >=3). Every Run line here is authored with three for that reason. Fail-safe (retains,
  warns) but depends on authored whitespace. Normalize the separator *and* fix the predicate.
- **`plan-file-scope-harvest.sh` silently under-harvests** on three measured plan shapes: a
  Territory Contract table instead of the field, a trailing italic on the label, and a glob entry.
  One repair moved a plan from 56 to 123 paths. Every miss is silent, and an under-harvested scope
  is what drops real work from a phase commit.
- **An unowned Lua spec failure**: `manifest_spec.lua:124`, invalid `merge_targets` type expected
  `false` got `true` (CARRIED-UNVERIFIED 2026-10-17). `known-failures.txt` cannot carry it (shell
  only); the coverage gap — Lua specs have no baseline at all — is the larger half.
- **13 of 14 phase-heading-owning implementation agents never invoke `update-phase-status.sh`**;
  the heartbeat reaches them only via the dispatch boundary. Lint Check I records the gap
  (CARRIED-UNVERIFIED 2026-10-17).
- **Nothing represents a cross-repository prerequisite.** A task gated on another repo reads
  `ready` here. The held books record is in exactly that state, so the gap is live.
- **Nothing prevents a vault operation leaving edges on renumbered tasks.** `parent_task` and
  `dependencies` are handled in the renumber path; nothing validates the result.
- **A rendered `**Goal**:` line in `TODO.md` cannot survive regeneration** and fails validation
  while present; `generate-todo.sh` never reads `active_goal`, so the displayed goal stays blank.
- **A loosely-scoped `subagent_type: "fork"` inherits the parent's entire mandate.** Mitigation in
  `core/docs/fork-patterns.md`; recorded because it is easy to re-introduce.
- The write-time task-reference hook fires on scratchpad files; its filter could exempt `/tmp/**`.
- **A completed record's headline outcome can be unobservable in the tree, and nothing checks.**
  Re-measured 2026-11-11, unchanged from the first observation: the record that retired the memory
  extension is `completed` and archived, and its declared `file_scope` names
  `agent-system/extensions/memory/` plus fourteen files beneath it — yet that directory still
  exists with its full `commands/ context/ data/ scripts/ skills/` tree, `memory` is still one of
  nine registered extensions in `.claude-extensions.json`, and the deployed `.claude/CLAUDE.md`
  still carries a `## Memory Extension` section. The mid-flight explanation offered at first
  observation has not borne out across a second measurement, and an open record now depends on
  those files existing: `590`'s `file_scope` declares
  `agent-system/extensions/memory/context/project/memory/memory-setup.md` and
  `memory-troubleshooting.md`. Resolve the contradiction — either the retirement is incomplete or
  its scope overstated what it would delete — before filing anything, and note that `590` must
  land against whichever answer holds. The generalizable gap, independent of this instance:
  postflight verifies phase completion, not that a record's *stated deletions* actually landed, so
  a retirement record can close with its target still in place.
- **Two topics are not meaningfully distinguishable.** `core-agent-system` (50 records) and
  `agent-system` (50) together carry 100 of the 137 open records (re-measured 2026-11-11), and no
  document states a boundary between them. Every record filed into either is a coin flip, which
  degrades every topic-grouped rendering. Two further topics — `repo-hygiene` (1) and
  `decidability` (1) — are not declared in `active_topics` at all, so the generator warns and
  appends them after the curated blocks, and 3 records (584, 585, 586) carry no topic and render
  under Uncategorized. Needs a documented boundary or a merge, plus a declaration pass on the
  stragglers; owner call, unfiled.
