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

Priority is **fan-out**: how many other open records a record transitively gates. It is not
urgency or effort, it changes with every edge and closure, and it is re-derived, never remembered
(standing rule 10). Re-derive with `generate-task-order.sh --print`.

**The head of this list is set by instruction, not by fan-out.** An operator asked for `543`,
`547` and `638` to be prioritized, and the three lead it as one run together with `534` --
`543`'s own still-open predecessor, admitted as an ordering constraint rather than cut. A fourth
number in that request, `34`, resolves to no open record (in the vault it was a completed
statusline record), so nothing was substituted for it. A multi-task run is still live as this is
written -- started 2026-11-16 07:50, with `476`, `586`, `572` and `607` still open in it and
`505`, `568`, `584` and `585` landed -- so every batch it touches keeps its membership and its
relative order; this pass re-measured their prose and nothing else.

Re-derived 2026-11-16 over the 135 open records. **The backlog is broad and shallow**: depth is
5 waves, the waves run 78 / 36 / 13 / 6 / 2, and **78 of 135 records have no open predecessor**.
The widest gate is still `599` at 5 direct dependents (592-596, all batched behind it in one
run); then `476`, `479` and `543` at 4, and `451`, `472`, `484` and `539` at 3. **Fan-out does
not discriminate between candidates, so it does not choose the order**; what moved the list this
pass was an unbatched cluster, not a gate.

**The verification substrate is now three runs, all batched.** The Gate 8 roster run
(`476` and the records behind it) owns what the suites report. A five-record sweep below it owns
the single, already-diagnosed findings one full battery filed together. A new pair below that
(`607`, `610`) owns what a full battery costs under concurrent load, alongside `572` in the
`verify-deploy.sh` lane near the head. `test-orchestrate-cycle-postflight.sh` remains the most
contended single path in the backlog at ten open claimants (re-measured 2026-11-16), five of
them batched: `624` and `476` in the Gate 8 run, `534` and `543` in the prioritized head, `609`
in its tail.

**The renderer is sound and all three of its callers are wired.** `## Next` and `## Open work`
are rendered wholly from `state.json`'s `roadmap_batches` / `roadmap_notes` entries by
`roadmap-integration.sh`, which makes no judgment calls. A batch naming only terminal members
now drops out of the rendering entirely -- its `/orchestrate` line and its `Why this order:`
bullet alike (measured this pass against the covering-suite sweep, whose only member `584` had
landed) -- so retiring one by hand is tidiness, not correctness. That batch was retired this
pass. `/todo` and `/review` reach `--regenerate` behind the shared preflight classifier, and
`/orchestrate`'s conclusion stage has its own script, `orchestrate-conclusion-roadmap.sh`, which
`skill-orchestrate` names and a dedicated suite covers.

```
/orchestrate 527, 628, 635, 636, 627, 637   # Sapience per-repo activation: its enabling blocker, three surface defects, and the close-out
/orchestrate 476, 624, 586, 604, 605   # Gate 8's residual roster, its two lints and the defect recorder, serialized on one suite
/orchestrate 577, 609   # The failure-accounting chain's tail, held behind the prioritized head both members depend on
/orchestrate 629, 630, 631, 632, 633   # Five already-diagnosed findings one full battery filed: two gate hits, a roster gap, two defects
/orchestrate 607, 610   # Per-gate timeout and gate 20 ceiling first, then the load-adaptive gate 8 and dispatch-stall fix
/orchestrate 512   # whole-tree claimant: runs alone -- RE-MEASURE FIRST, Gate 24 passes
/orchestrate 590   # RE-MEASURE FIRST: may already be satisfied in the source store; its declared lint path is wrong
/orchestrate 580, 491, 479, 492   # the operator-facing selection surface
/orchestrate 438, 581   # Pair 581 with its one unbatched predecessor so the shared renderer is reachable at all
/orchestrate 398, 399, 451, 462, 504, 516, 463   # Close the lean extension's own strand: three short chains over its context and scripts
/orchestrate 539, 540, 544   # Settle the pinned Challenge block's precedence rules, then the two records that quote them
/orchestrate 549, 576   # The narrow unusedArguments remedy, then the gate-naming and replay-window record over it
/orchestrate 599, 592, 593, 594, 595, 596   # Open the widest gate in the backlog and drain all five records it blocks, in one ordered run
```

Why this order:
- - **The order is forced, not chosen.** `534` -> `543` -> `547` -> `638` is a single linear chain
    already carried by `dependencies[]`, and every adjacent pair shares real territory:
    `534`/`543` over `orchestrate-cycle-postflight.sh` and its suite, `543`/`547` over
    `docs/architecture/orchestrate-state-machine.md`, `547`/`638` over `orchestrate-cycle-plan.sh`
    and `test-orchestrate-cycle-plan.sh`. Array position is not what sequences this run; the graph
    is.

  - **`534` is here as an ordering constraint, not as a fourth priority.** The request named `543`,
    `547` and `638`. `543` declares `534` as a predecessor and `534` is still open, so admitting
    the three without it would mean dispatching `543` against an unmet dependency. It leads the run
    rather than being cut from it.

  - **What unites the four is the handoff, not the file.** Each is a defect in what `/orchestrate`
    hands the NEXT dispatch: `534` writes a detail-free blocking issue entry on a partial, `543`
    hands down an error count whose provenance the resumer is never told to distrust, `547` writes
    the blocker-research aux carrier on instruction alone and admits an implement round for a task
    owed a plan revision, and `638` scopes that admitted round to the first heading that merely
    parses as open rather than to the first ENTERABLE phase. Fixing any one of them leaves the next
    dispatch misinformed by the others.

  - **`638` names this pairing itself.** Its own territory note, settled at creation, records that
    `547` also writes `orchestrate-cycle-plan.sh`, that the two mechanisms differ (admission of an
    implement round versus selection of a phase within an admitted one), and that they are good
    batch-mates in that order. The edge was declared then; nothing new is asserted here.

  - **The lane is free, and one declaration is worth noticing before probing.** None of the four
    declares `__WHOLE_TREE__`, so the run contends only with itself and with whatever a
    cross-session claimant holds. `638` declares `specs/TODO.md` and `specs/state.json` alongside
    its four real targets, which collides it advisorily with the two migration records that declare
    the same pair; no member of this run declares either, so nothing in-batch is affected.

  - **`638` renders detached from this chain in the wave table and is not detached from it.** Its
    `topic` is `core-agent-system` while the other three are `agent-system`, and
    `generate-task-order.sh` groups by topic before it indents by edge, so `638` prints as a root
    under its own heading. The edge behind `547` is present, verified directly in `dependencies[]`.
- - **`585` landed; the lane is now two records on one path, ordered by the graph.** `572` and
    `591` both declare `agent-system/extensions/core/scripts/verify-deploy.sh`, and `591` carries a
    direct edge on `572` (its edge on `585` is now satisfied). `572` is mid-research inside the
    live multi-task run and `591` is researched, so the overlap fires only at implement -- an
    admission probe run today returns 0 deferred for the pair and means nothing.

  - **The concurrent-load pair two batches below is a neighbour, not a member, and is not edged to
    `572`.** `572` and `610` share `verify-deploy.sh` and `context/contracts/batch-gate-stage.md`
    and both ask what a full battery should cost under concurrency, but `572`'s research report
    deliberately scopes itself away from rebuilding the `.gate-lock` lease, which is exactly
    `610`'s third research question. They divide the territory rather than sequencing it, so array
    position resolves the overlap and the two runs never dispatch concurrently.

  - **`verify-deploy.sh` has five open claimants** (re-measured 2026-11-16): `572` and `591` here,
    `527` in the sapience batch directly below, and `607` and `610` in the concurrent-load pair.
    Per the standing ruling, no clique is backfilled across that path.

  - **Two further cross-batch overlaps, both advisory, both resolved by array position.** `591`
    collides with `492` on `commands/errors.md`, and that run sits below. `572` is one of fifteen
    claimants on `agent-system/extensions/core/context/formats/plan-format.md`, among them `504`
    and `516` in the lean strand and five members of the `599` run, all below.
- the sapience extension's per-repo activation surface, which converges on nothing today

  - **The strand has grown from two records to five, and it now has a close-out.** The previous
    reading held `628` (five loaded repositories still grant eleven `mcp__sapience__*` tools where
    the merge source grants seven read-shaped ones, because the merge engine is additive-only and
    structurally cannot retract) and `627` (a `~/.claude.json` per-project registration for a
    directory that no longer exists, which the registration hook cannot reap -- its project-root
    detection needs a reachable `.claude-extensions.json`, finds none, emits `{}` and exits 0 before
    the removal branch). Three more have been filed since: `635` (the postflight tagged write is
    prose-only at the `[IMPLEMENTING]` -> `[COMPLETED]` transition and fires intermittently -- one
    recent orchestration completed two tasks across 13 transcripts with no
    `sapience-remember.sh --subject` invocation anywhere), `636` (machine-wide vendor hooks the
    extension's own documentation asserts cannot exist, plus a transcript-capture opt-in list
    unconnected to extension activation), and `637`, the researched close-out that measures the
    whole surface and whose own seed audit found no tagged note written anywhere after Nov 13.

  - **`527` is in this batch as `628`'s enabling mechanism, not because its subject is sapience.**
    Its topic is `core-agent-system` and its territory is core lint plus `verify-deploy.sh`. It is
    here because it settles the same deployed-set-vs-merge-source convergence problem for hook
    registrations that `628` has to settle for permission grants, and the edge `628` behind `527` is
    already declared and is what actually orders them. Co-membership only keeps the blocker
    SCHEDULED: leaving a ready blocker uncovered while batching its dependent is exactly what
    strands a record indefinitely.

  - **`637` closes the batch because the graph says so, and its edge set is its own, not inherited.**
    It depends on `628`, `635` and `636`, which puts it in wave 3 and makes this batch drain in
    three waves. It takes NO edge to `627`, and that is a measured decision rather than an omission:
    `637`'s own description enumerates its overlaps as `635`, `636` and `628`, and `636` names `627`
    explicitly as "related but distinct -- do not duplicate". The reaper is a sibling in cause, not
    in sequence.

  - **Five of this batch's six members declare no territory at all, and for this batch that is a
    live hazard rather than a hygiene note.** `627`, `628`, `635`, `636` and `637` were all created
    through Create Task Mode, which sets no `file_scope`, so an admission probe over this batch
    returns a clean result that means nothing. All five will edit
    `agent-system/extensions/sapience/**`; `628` additionally edits the core merge engine where it
    may well meet `527`, and `635` says outright that its call site may live under
    `agent-system/extensions/core/**`. **Declare territory on all five before dispatching this
    batch**, or the probe cannot tell you anything about the overlap it exists to find.

  - **`527` carries this batch's one visible contended path, and array position is what resolves
    it.** `verify-deploy.sh` has seven open claimants; three are the lane directly above, which is
    the reason this batch sits below it rather than at the head. Cross-batch overlap is advisory; no
    edge is written across that boundary.
- - **`568` landed in the live run, and `476` has committed its final phase but not its
    postflight.** `git log` carries `task 476: complete implementation`, while `state.json` still
    reads `implementing` and the live session still lists it. Until its postflight lands, `624`,
    `586` and `605` stay blocked behind it; re-read its status before dispatching this run rather
    than trusting either surface alone.

  - **`624` is here because it declares the suite this batch is serialized on.** It declares
    exactly `agent-system/extensions/core/scripts/system-defect-record.sh` and
    `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`, and appending
    assertions to a suite whose roster verdict `476` owns is sequenced by that verdict. Its edge
    on `476` is direct, as the collision-scan exemption requires (direct-edge only, never
    transitive).

  - **Every declared overlap inside this batch is edged, re-verified 2026-11-16.** `476`/`624` on
    the postflight suite; `476`/`586` on `scripts/tests/run-all.sh` and
    `test-gate-cache-equivalence.sh`; `476`/`605` and `586`/`605` on `run-all.sh` and
    `known-failures.txt`; `604`/`605` on `context/standards/shell-script-testing.md`. Nothing is
    missing.

  - **`test-orchestrate-cycle-postflight.sh` has ten open claimants, and this batch deliberately
    does not own all of it.** `624` and `476` are here; `534` and `543` lead the prioritized head and
    `609` sits in its tail, and array position resolves both boundaries; `472`, `501`, `519`, `551`
    and `570` are unbatched. Do NOT backfill a ten-way clique.

  - **`known-failures.txt` has five open claimants**: `476`, `586` and `605` here, `630` in the
    sweep batch below, and `607` in the concurrent-load pair below that. Both outside claimants were
    placed after this run so that `476`'s roster rewrite lands first.

  - **`476`'s title overstates it.** The title still says seven suites; the roster last re-measured
    2026-11-11 was five, with one since owned and landed by `568`. **Re-measure before sizing** --
    that measurement was not re-run this pass.

  - **Declaration hygiene inside this batch is clean.** Seven open records carry no `file_scope`
    (`613`, `618`, `627`, `628`, `635`, `636`, `637`) and none is here, so an admission probe over
    this batch's implement wave reports a real result.
- - **Split from the head deliberately, not cut.** `577` and `609` are the same failure-accounting
    chain and keep every edge they had: `577` behind `543` and `547`; `609` behind `534`, `543`,
    `547` and `577`. They sit here rather than in the prioritized run because the request did not
    name them, and because a six-record serial run is the shape this list has already measured as
    landing one implement rather than six.

  - **The one real overlap left unedged is `638` against `577`**, over `orchestrate-cycle-plan.sh`
    and `test-orchestrate-cycle-plan.sh`. Neither depends on the other and no transitive order
    separates them, so the only available justification for an edge would be co-membership -- which
    they no longer even have, now that the two sit in separate runs that never dispatch
    concurrently. Array position resolves it, exactly as the standing ruling below requires.

  - **`609` waits on everything above it**, the whole prioritized head included, so it cannot run
    earlier whatever this list says. Its own two-path overlap with `577` (`skill-orchestrate`'s
    SKILL.md and the state-machine document) is carried by a direct edge.
- - **Five small records filed together from one full `verify-deploy.sh` run, each already
    diagnosed.** `629` is the `sync_scan` allow-list post-filter that drops manifest-declared
    entries, which `test-deploy-propagation.sh` pins red by design; `630` gives that suite and
    `test-gate-registry-resolution.sh` the roster rows they lack; `631` is gate 29's only violation;
    `632` is gate 4's only unexempted occurrence, and a recurring one; `633` is an untracked,
    divergent 68KB copy of the root ledger sitting inside the core source store. None needs design,
    and together they take the battery's standing reds down to the ones larger records own.

  - **One in-batch order, semantic and already edged: `630` behind `629`.** No pair of members
    shares a declared path (checked mechanically this pass), so no serialization edge is missing. `629` is a `neovim` record (it edits
    `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`) and routes accordingly; the
    rest are `meta`.

  - **Below the Gate 8 run on purpose.** `630` writes `known-failures.txt`, which `476` is
    rewriting; array position lets the roster verdict land first.

  - **Above the concurrent-load pair on purpose.** `632` and `607` both declare
    `context/config/orchestrator-context-budget.json`, and one of `607`'s two remedies is
    re-baselining the gate 20 ceiling -- a ceiling move is exactly the event that re-breaks the
    derivation log `632` fixes. Landing `632` first means `607` cannot reintroduce the finding.
    This is a sibling overlap with no order either record states, so it is resolved by position,
    not edged.

  - **Re-measure `633` before acting.** The root `.claude-extensions.json` it compares against
    currently carries uncommitted local modifications, so the recorded diff may not be the diff
    that exists.
- - **`607`'s second question is `610`'s fourth, asked narrowly.** `607` asks whether per-gate
    timeouts should scale with concurrency or simply rise; `610` asks whether per-gate bounds should
    scale with measured host load, as part of the timing, concurrency and enforcement mechanics its
    own scope boundary claims. `607` is planned and narrower, and the two also share
    `verify-deploy.sh`, `gate-registry.data` and `skills/skill-orchestrate/SKILL.md`. **Edge written
    this pass: `610` behind `607`**, so `610` builds on a settled per-gate bound instead of
    re-litigating it.

  - **`610` names its own predecessor and nothing carried it.** Its territory note says to
    sequence `476` first if both are live, because a faster or sharded gate 8 changes the surface
    `476` works against. **Edge written this pass: `610` behind `476`.**

  - **`607` is a whole-tree claimant inside the live multi-task run**, so `610` waits on it
    regardless; the edge records why, not merely when.

  - **`610`'s research cannot run inside a loaded batch.** Its deliverable is a full-battery
    wall-clock baseline taken with no other dispatch live, as the control. Dispatch its research
    alone, or accept that the baseline must be re-taken.

  - **Two neighbours, neither edged.** `572` (two batches above) divides this territory with `610`
    rather than sequencing it -- see the lane's rationale. `454` owns the agent-side wait-discipline
    prose in `bounded-build-waiter.md` and `external-process-wait.md`; `610` declares neither path
    today, so reconcile by hand if its plan adds them.
- whole-tree claimant: runs alone -- RE-MEASURE FIRST, Gate 24 passes

  - **The Gate 24 pair is held pending a re-measure, not ordered.** The gate passed when last
    measured on 2026-11-11, so neither `512` nor `590` has a confirmed live finding and **neither
    should be sized until re-measured**. This pass did not re-run the gate; treat the 2026-11-11
    reading as the latest, not as current.

  - **The two cannot see each other, and that is a declaration defect rather than independence.**
    Both edit the same lint, but `590` declares it directly under the core extension's `scripts/`
    directory, a path re-confirmed absent from disk on 2026-11-15, while the file actually lives one
    level further down under `scripts/lint/`, which is what `512` declares. The collision scan
    therefore sees no overlap between them at all. They are ordered here by array position only, and
    `590`'s declaration should be corrected before either is dispatched.

  - **If both survive the re-measure the ordering still holds.** `512` owns the exemption mechanism
    (a `builtin-cmd-ok` inline marker, following the `task-ref-ok`/`version-ok` idiom) and is a
    claimant, so it runs alone; `590` can only mark prose once that marker exists.

  - **`512`'s own `file_scope` additionally declares two deployed `.claude/scripts/**` paths**, which
    the source-store boundary rule says are a disposable deploy artifact and never an edit target --
    harmless to the overlap predicate, wrong as a declaration.
- RE-MEASURE FIRST: may already be satisfied in the source store; its declared lint path is absent from disk (re-confirmed 2026-11-15) and must be corrected to the `scripts/lint/` form before dispatch.
- the operator-facing selection surface

  - **The operator-surface objective is unchanged, and runs after the substrate.** `580` is the
    prerequisite for `581` and constrains `492`'s prompt design, because a confirm gate already
    using three options cannot simply grow a fourth set of per-verdict fold actions. `491` precedes
    `492` by a declared edge, and `492`'s own precondition requires re-measuring against the
    corrected scorer before its consumer edits -- do not dispatch `492` expecting its full scope to
    survive that re-measurement. `479` joins the run because `581` needs it and it is ready; it
    collides with `492` on `commands/task.md` and `context/workflows/meta-interview.md`, so `492` is
    edged behind `479` and the member order above places `479` ahead of it.

  - **No edge is missing inside this batch.** Re-measured 2026-11-15: every declared path overlap
    among the four is already carried by a direct edge.

  - **Three cross-batch overlaps worth knowing before dispatch.** `492` shares `commands/errors.md`
    with `591` (the verify-deploy lane, which runs first). More consequentially, both `479` and `492`
    share `commands/task.md` and `context/workflows/meta-interview.md` with `438`, which runs in the
    pair directly BELOW this one -- so this run dispatches first and the collision never fires. That
    is array position doing its job; no edge is written across the boundary.

  - **`581` runs last by construction**, paired with `438` in the batch below: it declares three
    paths `492` also declares (`context/workflows/meta-interview.md`, `skills/skill-fix-it/SKILL.md`,
    `skills/skill-spawn/SKILL.md`) plus `context/standards/interactive-selection.md` which `580`
    declares, and its four edges exist to serialize rather than exclude.
- the selection surface's last two records: the authoring-time edge check, then the shared option renderer

  - **`438` is READY, and all six of its declared predecessors are closed.** `312`, `313`, `401`,
    `446`, `458` and `500` are archived or completed, re-verified 2026-11-15. `581` sits in wave 3.

  - **Without `438` scheduled, `581` is stranded permanently, and that is why this pair exists.**
    `581` carries four edges: `580`, `479` and `492` all sit in the operator-surface run directly
    above, while `438` sat in no run at all. A record whose last predecessor is in no batch is not
    waiting -- it is unreachable. Pairing the two is the whole content of this batch.

  - **`438`'s overlap with the run above is real and is deliberately left UNEDGED.** `438` shares
    `commands/task.md` and `context/workflows/meta-interview.md` with `479`, and those two plus
    `docs/reference/standards/multi-task-creation-standard.md` with `492`. That is a genuine
    `file_scope_collision`, but it is a CROSS-batch one: the operator-surface run dispatches first,
    so the pair never contends concurrently, and array position resolves it without asserting a
    semantic dependency neither record's own description supports. `438` is an authoring-time
    semantic check on declared edge rationale; `479` is a landing-target gate on task creation.
    Neither presupposes the other, and co-membership would have been the only argument for the edge
    -- which is not an argument.

  - **The in-batch pair is already edged.** `438` and `581` share
    `context/workflows/meta-interview.md`, and `581` already depends on `438`. No edge is missing.

  - **Four further advisory overlaps on `438`.** `commands/revise.md` with `503`;
    `multi-task-creation-standard.md` with `558` and `559`;
    `agent-system/extensions/core/scripts/update-task-status.sh` with `568` (the Gate 8 run above)
    and `598`. None is batched with it.
- the lean extension's own strand; ordered late on the two most contended paths in the backlog

  - **Three edged chains plus one independent, and every edge already exists.** `399` behind `398`
    (both declare `agent-system/extensions/lean/index-entries.json`); `462` behind `451` (both
    declare `lean-challenge-snapshot.sh`, its test, and `challenge-snapshot.md`); `516` behind `504`
    (both declare `lean-plan-compliance-check.sh`, its test, and `plan-format.md`). `463` shares no
    declared path with any of the other six. Re-measured 2026-11-15: **no edge is missing inside
    this batch.** It dispatches as two waves -- `398`, `451`, `463`, `504`, then `399`, `462`, `516`
    -- on the edges already in the graph, and the member order above groups each chain with its own
    dependent.

  - **It runs late because its two densest paths are the most contended files on the board.**
    `agent-system/extensions/core/context/formats/plan-format.md` has fifteen open claimants; `504`
    and `516` are two of them, and eight of the other thirteen are now batched -- `572` in the
    verify-deploy lane above, and `599` plus its four plan-authoring dependents in the run at the
    foot of this list. `agent-system/extensions/lean/index-entries.json` has six: `398`, `399`,
    `539`, `540` and `576` (the next two batches) and the unbatched `536`. Cross-batch overlap is
    advisory, and array position is what resolves it. **Do not backfill edges across those
    claimants** -- the edges worth declaring are the ones inside the batch being dispatched.

  - **This batch now precedes rather than follows the Lean-facing plan-authoring records, and that
    is the one ordering change here.** `593` declares an edge to `451`, so the plan-format run at
    the foot of this list is reachable only once this batch has landed. Three narrower cross-batch
    overlaps carry into sizing: `451` shares `agent-system/extensions/lean/rules/plan-compliance.md`
    with `452`, `539` and `593`, and `orchestrate-cycle-plan.sh` with `514`, `547` and `577`; `451`
    and `462` share `lean-challenge-snapshot.sh` and its test with `544`; `504` and `516` share
    `lean-plan-compliance-check.sh` and its test with `560`, `593` and `595`; `516` shares
    `lean-implementation-agent.md` with `472`, `518` and `537`. Of those, `539`, `544`, `593` and
    `595` are batched below; the rest are unbatched. All advisory.
- the Challenge-block authoring records: one ruling, two dependents that cannot be written before it

  - **This is a star, not a chain, and the centre was unbatched.** `539` states the precedence and
    snapshot-prerequisite rules for a lean plan's pinned Challenge block; `540` (five measured lean4
    facts) and `544` (a fixture-dependent gate statement made expressible and mechanically checkable
    in a Challenge block) both depend on it and on nothing else. `539` also has a third dependent,
    `595`, in the plan-format run at the foot of this list -- which is the reason this batch sits
    above it rather than below.

  - **Why it is not in the lean-extension batch above.** All three records name Lean, but their
    territory is Challenge-block and plan-authoring content under the `agent-system` topic, not the
    extension's own scripts and context corpus. `539` does share
    `agent-system/extensions/lean/index-entries.json` with `398` and `399` above and
    `agent-system/extensions/lean/rules/plan-compliance.md` with `451` above; both are cross-batch,
    advisory, and resolved by that batch running first.

  - **One in-batch overlap, already edged, and one deliberate split.** `539`/`540` share
    `index-entries.json` and the edge exists. `576` was NOT admitted to this batch even though it
    declares the same `index-entries.json` as `539` and `540`: it is `549`'s dependent, not `539`'s,
    and admitting it would have left two unedged in-batch overlaps whose only available justification
    was co-membership. It runs in the pair directly below instead, where its one real edge orders it.
- the second Lean plan-authoring pair, split out of the Challenge-block star above on measured grounds

  - **A two-record chain, fully edged, and it exists as its own run for a stated reason.** `549`
    gives the Lean `unusedArguments` remedy a narrow route instead of the wholesale
    `runLinter --update` rewrite; `576` records the verification-tier gate-naming rule, the
    Constraints-consumed marker duty and the build-guard replay window on top of it. `576` depends
    on `549` and the two share
    `agent-system/extensions/lean/context/project/lean4/patterns/plan-authoring-gate-collisions.md`,
    so the one overlap is edged.

  - **It is separate from the batch above because merging them would have cost two unjustifiable
    edges.** `576` declares `agent-system/extensions/lean/index-entries.json`, which `539` and `540`
    also declare, with no edge in either direction and no transitive order between them -- `576` sits
    behind `549`, not behind `539`. Writing those two edges would have asserted an ordering neither
    record's description supports, on co-membership alone; splitting the run resolves the same
    collision by array position instead. `536` is a third unbatched claimant of that file; same
    disposition.
- the plan-authoring strand behind `599`: the backlog's widest gate, which until this pass was in no batch at all

  - **This is the one place fan-out actually said something, and the list was not acting on it.**
    `599` (give the batch-gate-deferral directive a narrowing form for a phase touching only project
    sources) is the widest gate in the backlog at five direct dependents -- `592`, `593`, `594`,
    `595`, `596` -- it is ready, and neither it nor any of the five was batched. Its own predecessor
    is closed, so nothing was holding it except absence from this list.

  - **It runs at the foot because two of its members reach outside it, and both predecessors are
    scheduled above.** `593` depends on `451`, in the lean-extension strand; `595` depends on `539`,
    in the Challenge-block star. Both of those batches now precede this one, which is the whole
    reason this run is placed last rather than first. Dispatch order inside the batch is `599` and
    `592`, then `593`, then `594`, then `595`, then `596` -- five waves on edges already in the
    graph.

  - **Eleven in-batch overlaps, all now edged; three edges were written this pass and none changed
    the order.** `593`/`595`, `593`/`596` and `594`/`596` overlapped on
    `agent-system/extensions/core/context/formats/plan-format.md` (and `593`/`595` additionally on
    `lean-plan-compliance-check.sh` and its test) with no direct edge, while the chain
    `593` -> `594` -> `595` -> `596` already forced every one of those orders transitively. The three
    edges make them direct so the collision-scan exemption fires, which it does not do transitively;
    the wave table is unchanged at 82 / 36 / 15 / 5 / 2 after the writes, which is the check that
    they asserted nothing new.

  - **`plan-format.md` is the densest path in the backlog at fifteen open claimants, and this batch
    owns five of them.** The other ten are `452`, `504`, `509`, `516`, `548`, `566`, `572`, `575`,
    `579` and `588`; `504`, `516` and `572` are batched above, and the remaining seven are not. Do
    NOT backfill a fifteen-way clique: cross-batch overlap is advisory and array position resolves
    it.

  - **Two further cross-batch overlaps.** `592` and `599` share `orchestrate-build-dispatch.sh` with
    the unbatched `558`; `593` and `595` share `lean-plan-compliance-check.sh` with `504` and `516`
    above and with the unbatched `560`. Both advisory.

**The `__WHOLE_TREE__` claim is the binding constraint on batch width, not fan-out.** A record
declaring the sentinel serializes absolutely against every other claimant, in-batch and
cross-batch alike, including a claimant owned by another live session. Measured 2026-11-06: a
six-record batch landed research and planning for all six in parallel, then implemented only one,
because the remaining four queued behind a single claimant and then behind a cross-batch claimant
in another session; three were still unimplemented when the convergence guard stopped the run.

**The claimant roster is five: `431`, `476`, `506`, `512` and `607`** (re-measured 2026-11-16:
`585` landed, and `476` declares the sentinel too). The sentinel remains the binding constraint
on batch width rather than fan-out or edges. Batch claimants one at a time and group the
non-claimants freely around them. Two claimants, `476` and `607`, sit inside the live multi-task
run, so every other claimant's implement wave defers until that run releases them. **The lane is
free for the head**: no member of the prioritized run declares the sentinel, so its four contend
only with each other and with whatever a cross-session claimant holds.

**What changed structurally this pass: the verification-cost cluster was batched, and one landed
batch was retired.** `607` and `610` -- the only two `verify-deploy.sh` claimants in no batch,
asking the same per-gate-timeout question at two widths -- now run as a pair, placed below the
Gate 8 run that `610` itself says must land first. The five records filed together from one full
battery (`629`-`633`) now run as one sweep between the two, placed so `632` lands before `607`
can move the context-budget ceiling again. The covering-suite sweep's batch was retired because
`584` landed. Every other batch keeps its membership and relative order; the Gate 8 run and the
`verify-deploy.sh` lane had their prose re-measured.

The gate exempts research and plan dispatches (neither regenerates the tree) and defers only
implement, so a claimant still researches and plans freely while the lane is occupied.

**Admission-probed only in part, and every probe recorded so far is weaker than it looks.** Each
one put only research or plan dispatches in cycle 0, and both phases are exempt from the claim
gate and the collision gate alike -- so no probe has yet exercised the implement-wave
`file_scope` collisions these batches are ordered around. Treat an unprobed batch as unprobed:
probe before committing to one (standing rule 5), and check `task-lock.sh session-list` for a
live session whose scope overlaps, since a cross-session claimant is invisible to the edge graph.
Two batches cannot be meaningfully probed at all until their members declare territory -- see the
scope paragraph below.

**On edge declaration**, three rulings stand:

- **Only a `file_scope_collision` verdict means an edge is missing.** `whole_tree_claim` and
  `self_modifying` verdicts say so themselves -- *"this is an ORDERING CONSTRAINT, not an
  exclusion"* -- and resolve in a later cycle unaided. **An edge belongs to a path overlap; a
  sentinel overlap is left to the sentinel defer.** Declaring an edge between two records whose
  only shared territory is `__WHOLE_TREE__` asserts a semantic claim neither record supports and
  chains unrelated strands together for nothing.

- **The exemption is direct-edge only, never transitive, and it is scoped to the batch being
  dispatched.** A pair ordered through an intermediate still collides and still defers, which is
  why `624` is declared behind both `568` and `476` rather than relying on the chain through
  `568`. The converse discipline matters just as much: a heavily shared path is NOT grounds for
  edging every record that touches it. Re-measured 2026-11-16,
  `test-orchestrate-cycle-postflight.sh` has ten open claimants,
  `context/formats/plan-format.md` has fifteen and `verify-deploy.sh` has five; the edges worth
  declaring are the ones inside the batch actually being dispatched, and every other overlap is
  advisory, resolved by array position. `438`'s three-path collision with `492` is the worked
  example: real, measured, and deliberately left unedged because the two sit in adjacent batches
  that never dispatch concurrently.

- **A transitive order made direct, or an order a record states itself, is the edge class this
  list writes; a bare sibling overlap is not.** Two edges were written this pass, both on `610`.
  `610` behind `476` is an order `610`'s own territory note states. `610` behind `607` orders the
  two members of the new concurrent-load pair, which ask the same per-gate-timeout question at two
  widths and share three paths, narrower record first. The sibling overlaps left unedged are
  `632`/`607` on `context/config/orchestrator-context-budget.json` and `572`/`610` on
  `verify-deploy.sh` and `batch-gate-stage.md`, each split across batches that never dispatch
  concurrently, so array position resolves them. The contrast that earned the rule is `576`,
  which declares the same `index-entries.json` as `539` and `540` with no order between them in
  either direction; those were split into separate runs rather than edged on co-membership alone.
  Two further proposals are still held for an owner ruling rather than written: `452` behind `451`
  and `473` behind `472`.

**Every batch was scanned mechanically for a missing in-batch edge this pass.** Across all
fifteen batches every declared path overlap between two open members of the same batch is
carried by a direct `dependencies[]` edge: three in the prioritized head, five in the Gate 8 run,
eleven in the `599` run, three in the lean strand, two in the selection surface, one in each of
the lane, the tail, the concurrent-load pair and each of the three remaining runs. The sweep batch has no
in-batch path overlap at all. The one place the scan returns silence rather than a clean result
is the sapience batch, whose members largely declare no territory.

**The batch-proposal lint was run against this rendering and its findings are dispositioned, not
merely acknowledged.** `scripts/lint/lint-roadmap-batch-proposals.sh` reports 187 advisory
findings over 15 authored run lines (re-run 2026-11-16): zero of class (c) (no run line over the
8-task cap), zero of class (d) (no cited task resolving to nothing or to a terminal status), 180
of class (a) and 7 of class (f). **Class (a) is the advisory cross-batch-overlap class this list
resolves by array position**, and it cannot be driven to zero by authoring: with fifteen open
claimants on one plan-format file and ten on one test suite, satisfying it would mean merging
most of the backlog into single runs past the 8-task cap. It rose from 172 because two new run
lines now report each other's and their neighbours' members as absent. It was read for the one
thing it can show, an in-batch overlap missing an edge, and by construction it reports only
absent tasks, so the mechanical in-batch scan above is the check that answers it. **Class (f) is
a stale-citation class**; all seven sit in authored-verbatim sections of `specs/ROADMAP.md`
outside `## Next` and `## Open work`, which this list does not render and must not write.

**The two held records are not waiting on engineering.** The books-corpus refactor (`342`) waits
on an external version stamp reaching `0.1.0` (the consuming repository's own book-convention
record still reads a pre-release stamp); the email preference-harvest substrate (`498`) waits on
an operator decision about integrating email into the hosted store. Neither is available work,
both lifts are owner actions, and `/orchestrate` admits a held record only under an explicit
forcing flag. Nothing depends on either.

**Scopes worth narrowing first.** Re-measured 2026-11-16: **seven** open records carry no
`file_scope` at all -- `613`, `618`, `627`, `628`, `635`, `636` and `637`, every one of them
created through Create Task Mode, which sets none -- and that is the entire class, since no open
record declares an empty array. Five of the seven are the sapience run, so an admission probe over
that batch returns a clean result that means nothing. **Fix those declarations before probing
it.** A record with no declared territory is invisible to every collision scan rather than merely
coarse in it. Two narrower declaration defects are live: `590` declares its lint one directory
above where the file actually sits, so it cannot collide with `512` even though the two edit the
same lint; and `638` declares `specs/TODO.md` and `specs/state.json` alongside its four real
targets, which collides it advisorily with the two migration records that declare the same pair
and with nothing else. Of the directory-form declarations that remain, every one is scoped to a
single extension subtree -- `342` (three `books/` directories), `384`, `453`, `530` and `544`.
None is a whole-corpus discovery scope, and none is a defect.
**Coverage appendix (uncovered tasks)**:
```
/orchestrate 338,383,390,410,421,431,437,453
/orchestrate 455,456,472,475,477,484,502,503
/orchestrate 506,510,511,514,519,520,521,522
/orchestrate 523,525,526,529,530,535,536,537
/orchestrate 538,545,548,551,556,557,558,559
/orchestrate 560,563,564,565,567,574,575,613
/orchestrate 618
```

## Open work

**Core agent system (42)**
```
476 IN FLIGHT       Make the seven untracked red Gate 8 shell suites green or declared-expected
439 blocked:431     Rule on the propagation model for the bounded-wait agent contract
452 blocked:451     Require a verification criterion over a repo-wide gate with standing pre-exis...
454 blocked:439     State the result-needed-this-turn criterion for choosing the foreground form,...
473 blocked:472     Strip record-versioning language from the boundary-owned architecture docs
474 blocked:431     Repair the broken relative links in agent-frontmatter-standard.md
479 blocked:438     Require every task to name a landing target: a creation-time gate on report-o...
480 blocked:479     Advisory detector for research tasks stranded at RESEARCHED with artifacts bu...
492 blocked:479,491 Make backlog-audit corroboration computable and gate the confirm prompt on it
517 blocked:455     Require a phase commit to regenerate and stage the derived surfaces it stales
524 blocked:484,501 Rule on a staged-vs-working-tree divergence signal for a pathspec commit, and...
566 blocked:452     Document that the validate-state.sh cycle check requires --deep at every call...
579 blocked:564     Record the selector's full-path-set aggregation rule in the Tier Justificatio...
581 blocked:438,479,492,580  Extract one shared AskUserQuestion option renderer and adopt it acro...
588 blocked:509     Bar a pre-redeploy plan step from naming a deploy-tree-resolved subject unles...
605 blocked:476,586,604  Flag an advisory known-failures roster row whose named suite now passes
338 ready           Classify every task-support file as tracked or ignored
410 ready           Close the result-sharing replay hole in lake-build-guard.sh: gate sharing on ...
421 ready           Close three gaps in the telemetry --meta evidence consumer
431 ready           Record the gate-enforced verbatim-duplication exclusion class as durable agen...
456 ready           Exempt private npm/Cargo manifests from /tag's version gate
475 ready           Close the audit-evidence gate internal --argjson hole: a large verdict dies w...
491 ready           Fix the Pass-2 semantic scorer whose normalization inflates against verbose c...
502 ready           Require research reports to enumerate generated doc-sync surfaces
503 ready           Document /revise's unavailability to a dispatched agent
506 ready           Stop the bounded-waiter hook refusing a write whose prose documents the anti-...
519 ready           Infra exempt transport error dispatch deaths
520 ready           Emit deploy ordering in implement dispatch body
521 ready           Fix the agent glob to match the -implement-agent.md variant
523 ready           Make Gate 27 MISSING_DECLARATION count call sites, not whole-file substring m...
525 ready           Repair the always-failing extensions-directory fallback in the task-type dete...
526 ready           Announce completion and input-needed over TTS from the source store, with a c...
527 ready           Assert the deployed hook registration SET matches the merge-source, not only ...
564 ready           Fix validate-artifact.sh Tier Justification false positive from sentinel path...
565 ready           Resolve archived prior-art paths when composing dispatch and task-description...
574 ready           Correct the cycle-budget contract to state shared-pool semantics wherever rem...
575 ready           Stop the cross-phase ceiling check reading a stop-word as a unit and false-po...
580 ready           Correct the interactive-selection threshold model to AskUserQuestion's real f...
590 ready           Resolve the /ide dead-command-recommendation findings
604 ready           Lint-time detector for drifted test-fixture dependency declarations, in both ...
613 ready           session_liveness_same_process_orphan_lock
618 ready           working_tree_residue_disposition_policy
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
486 blocked:484     Stop a required extension manifest.json registration being dropped from a pha...
501 blocked:472,476,484,486  Give the cycle-postflight containment site predicate parity and a gu...
508 blocked:486     Rule on where shared extension metadata belongs in the containment allowlist,...
509 blocked:452     Make a redeploy phase declarable without polluting file_scope, and bar a pre-...
455 ready           Pre-flag the predictable first-run module-invariant failures that wiring a ne...
484 ready           Collapse per-path scope excursion issue rows into one record per drop event
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

**Orchestrator (7)**
```
513 blocked:479     Mechanically detect a plan phase that closed without its own commit
518 blocked:472     State the blockers[] admission contract and continuation-on-partial requireme...
610 blocked:476,607 full_gate_verification_ceiling_and_stall
624 blocked:476     defect_record_unresolvable_in_deploy_consumer
472 ready           Stop validate-handoff.sh aborting on a string-shaped blockers array, and stop...
477 ready           Normalize issue-log class vocabulary and reject the aggregate's malformed rep...
514 ready           Convergence guard blind to zero-dispatch cycles
```

**Agent system (49)**
```
481 blocked:390     Rule on and migrate the 32-record mis-sited agent-system task delta accumulat...
533 blocked:410     lake-build-guard replays stale result for env lean FILE
540 blocked:539     Record five measured lean4 facts: the decide-synthesis working form, the axio...
541 blocked:535     Stop git-snapshot.sh --no-revert artifacts from contaminating phase commits w...
542 blocked:538     Record the launch-side PID-fidelity condition on the bounded-waiter detach form
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
538 ready           Bounded in-file block edits: index and assert, never string-splice
539 ready           State the precedence and snapshot-prerequisite rules for a lean plan's pinned...
545 ready           Report a reversed validate-artifact.sh invocation as an argument-order fault,...
548 ready           Harvest a plan's declared contingency files into file_scope, and stop the con...
549 ready           Give the Lean unusedArguments remedy a narrow route instead of the wholesale ...
551 ready           Close the recurring stale-handoff defect and find out why the return-meta sch...
556 ready           Fix validate-handoff.sh crash-as-false-negative and settle the canonical bloc...
558 ready           Require task descriptions to request a proposal packet instead of instructing...
559 ready           Stop one low-specificity shared path from producing duplicate-of-open, and se...
560 ready           Clear the three standing verify-deploy findings blocking a clean nvim deploy
577 ready           Make a blocker-triggered aux plan-revision consumable by triage, and stop the...
599 ready           Give the batch-gate-deferral directive a narrowing form that covers a phase t...
607 ready           Resolve the gate 20 orchestrator context-budget overage and the per-gate time...
629 ready           Fix the two-engine defect: scan_all_artifacts' sync_scan allow-list post-filt...
631 ready           Replace test-typescript-verify.sh's fixed-depth REPO_ROOT walk with a boundar...
632 ready           Stop orchestrator-context-budget.json's derivation log from re-breaking the t...
633 ready           Resolve the stray duplicate .claude-extensions.json sitting inside the core e...
```

**Sapience (5)**
```
628 blocked:527     retract_sapience_write_tool_grants
637 blocked:628,635,636  make_sapience_extension_fully_functional
627 ready           reap_orphan_sapience_mcp_registrations
635 ready           Enforce the sapience postflight wrapup write at task completion
636 ready           Close sapience activation-surface scoping gaps: vendor user-level hooks, capt...
```

**Decidability (1)**
```
557 ready           Record the half-line test as a lean4 context pattern note
```

**Uncategorized (1)**
```
586 blocked:476     Stand up the suite and gate wall-clock cost consumer: delete, optimize, or de...
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
