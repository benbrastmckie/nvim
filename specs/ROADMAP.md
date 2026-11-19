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

**The order of this list is set by instruction, not by fan-out, and it now carries three instructions rather than two.** Two strands sit at the head because an operator asked for exactly their records to be prioritized, together with anything that genuinely must land before them, and in both cases the prerequisite question was answered by measurement rather than assumed: the ignored-specs mechanism group in batch one, and the branch-and-milestone decision strand in batches two and three. **Which of the two leads was not instructed and is this list's own judgment.** The ignored-specs group goes first because its placement is derivable from the ranking rule below -- a finished task recorded as unfinished on every completing dispatch is simultaneously a progress failure and a verdict-truth failure -- whereas the branch strand's own bullet concedes that nothing in the dependency graph and nothing in its records' text makes it urgent. Everything from batch four down keeps the earlier ordering, which an operator set by asking that the most essential work for agent-system health, functionality and speed lead the list, and which was derived against exactly three questions applied in this order: does the system still make progress at all; does one dispatch hand the next the truth; and what does a run cost. Fan-out -- how many open records a record transitively gates -- is recorded below because it is cheap to re-derive, but it chose no part of this order and must not be read as if it had. Re-derive with `generate-task-order.sh --print`.

**The ranking rule, stated so it can be argued with.** A batch ranks higher when its members decide whether work happens (a write path that refuses, a lock that never reaps, a guard that never converges), or whether a verdict can be trusted (a gate reporting a red nobody can attribute, a validator refusing conforming input, a detection charged to the wrong task, a completion recorded as a partial). It ranks lower when its members improve what a future plan or document says without unblocking anything currently stuck. Cost sits immediately below verdict-truth rather than at the head: an optimisation measured against a red gate set is measured against noise, so batch seven waits on batch four by construction.

Re-derived 2026-11-19 over the 128 open records, and re-verified against `generate-task-order.sh --print` the same day. **The backlog is broad and shallow**: depth is 5 waves, the waves run 70 / 34 / 13 / 8 / 3, and **70 of 128 records have no open predecessor**. The widest gates are `599` at 5 direct open dependents and `479` at 4, then exactly seven records at 3 -- `451`, `472`, `484`, `539`, `593`, `654` and `658` -- then exactly seven more at 2: `431`, `438`, `452`, `455`, `486`, `548` and `594`. Those two sets are complete at their counts, not samples of them; `658` enters the backlog directly into the first of them and `654` rose into it this pass. Every other record with an open dependent has exactly one, and there are 35 of those. **Fan-out does not discriminate between candidates at this shape, so it cannot choose the order** -- with more than half the backlog immediately ready, the binding question is which ready work matters, which is a judgment and not a measurement.

**The verification substrate is not the head, and the displacement is deliberate rather than an oversight.** Batch four holds most of the currently-known red surface, and its own `Why this order:` bullet names, record by record, which of its members still reproduce a red and which do not -- measured 2026-11-19 by running the gates and suites directly rather than inferring from the records. The live reds there are the `.mcp.json` merge defect (5 passed / 2 failed), the three standing findings blocking `RESULT=landed_verify_clean`, the two-engine defect that makes one suite red by design plus the roster rows for it, and one violation that no record's subject owns: a suite added by the orchestration-close work with no row in `suite-classification.data`. Gates 4 and 29 both report clean today, so the two single-violation members are not part of that surface. **Every batch below it -- and now the three above it -- dispatches against a gate verdict an operator has a rational incentive to ignore until it lands**, which is the one cost the head carries and which both head strands' own rationales record in those terms. **Batch seven then owns whether the battery's own numbers are measurable at all**: the host-scoped gate mutex that led it has landed, closing the scope half of the contention problem -- every mutex this system ships resolved under `$PROJECT_ROOT`, so a battery started from a sibling repository was structurally invisible to the single-flight guard -- and the standing suite/gate cost consumer now heads that batch, with the advisory-roster record edged behind it.

**The renderer is sound and all three of its callers are wired.** `## Next` and `## Open work` are rendered wholly from `state.json`'s `roadmap_batches` / `roadmap_notes` entries by `roadmap-integration.sh`, which makes no judgment calls. A batch naming only terminal members drops out of the rendering entirely -- its `/orchestrate` line and its `Why this order:` bullet alike -- so retiring one by hand is tidiness, not correctness. What rendering cannot keep current on its own is the authored prose: a batch that loses a member to completion keeps a `description` and a `Why this order:` bullet written against the larger membership, and that is the one thing a maintenance pass must fix by hand. Batch eight was in exactly that state and was rewritten against its three surviving members, the landed one having been its only consumer-repository member and its only sentinel claimant. `/todo` and `/review` reach `--regenerate` behind the shared preflight classifier, and `/orchestrate`'s conclusion stage has its own script, `orchestrate-conclusion-roadmap.sh`, which `skill-orchestrate` names and a dedicated suite covers. **The scope of that renderer is itself the subject of a head-batch record**: the milestone-schema work in batch two extends generation from these two sections to the entire file, nests batches under ordered milestones, and is required to preserve exactly the judgment/rendering split described here rather than collapse it. That record now also carries a siting question it did not have before -- batch one makes `specs/` ignored by default in a fresh repository, and a wholly-generated reviewer-facing dashboard inside an ignored tree is invisible to the reviewer it exists for.

```
/orchestrate 658, 659, 660, 661, 662 --hard   # Make a gitignored specs tree a supported posture: one predicate, no false demotion, then the docs
/orchestrate 654, 656, 657 --hard   # Decide before building: the commit-layer order, the milestone schema, then the topology ruling
/orchestrate 655 --hard   # Build branch-aware orchestration and squash landing once the topology ruling settles its design
/orchestrate 645, 560, 629, 630, 631, 632, 633   # Make verify-deploy's verdict mean something again: the live reds, the roster, two latent gates
/orchestrate 475, 613, 514, 574   # Hard stops: task creation dies on a big verdict, a lock never reaps, a run never converges
/orchestrate 556, 472, 646, 551, 519, 570, 577, 609   # What one dispatch hands the next: settle the handoff/return-meta shapes, fix failure accounting
/orchestrate 586, 605   # Make a full battery's numbers trustworthy: the standing cost verdicts, then one stale roster row
/orchestrate 545, 579, 575   # Two false validator failures, plus the plan-time record of the path-set rule behind one fix
/orchestrate 639, 477, 484, 486, 501, 508, 524   # Evidence integrity: stop losing issue entries, normalize classes, collapse scope-excursion rows
/orchestrate 548, 567, 553, 598, 536, 535, 541   # Commit containment: stop phase commits dropping legitimate files and carrying foreign ones
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
- - **This leads the list, and unlike the strand below it the placement is derivable rather than instructed.** An operator asked for this group and the branch-and-milestone strand to be raised together; which of the two leads was left open, and the ranking rule stated above decides it. `659`'s defect reproduces on EVERY completing dispatch in a repository whose specs tree is ignored: the per-cycle bookkeeping commit can never stage anything, `orchestrate-cycle-postflight.sh`'s commit-landing correction reads the nonzero exit as a failed commit, rewrites a `completed` task to `partial`, amends a commit-failure blocker into the handoff and prints STATUS DEMOTED. That is both of the ranking rule's top classes at once -- the system stops recording progress it has already made, and the next dispatch is handed a status that is false -- and it is measured in two consumer repositories (sf1-engine, sapience-app), not inferred. The strand below is decision-and-data-model work that unblocks a feature nothing is currently stuck behind, and its own bullet concedes it sits where it does by instruction alone.

  - **The five members are one mechanism, not five adjacent fixes, which is why they are one batch.** `658` is the gate: one shared predicate answering whether a given repository's specs tree is gitignored, plus a distinct non-failure exit code for an all-ignored pathspec, modelled on `lib/engine-written-state-paths-lib.sh`'s contract-plus-fail-open-posture style. Everything else consumes that split rather than reimplementing the question -- which matters, because 95 files reference `git-commit-scoped.sh` and a per-call-site workaround would land in all of them. `659` narrows the demotion trigger with it, and narrows rather than removes: a `completed` status nobody committed stays a real hazard when the commit genuinely failed, so the required negative control is the pair -- an ignored tree completes clean, a genuinely failed commit still demotes. `660` makes a fresh repository land with its specs tree ignored and carries the migration guarantee that an already-tracked tree keeps tracking; the global root's own 11,572 tracked specs files are the reference case, and silently untracking them would be a worse defect than the one this group exists to fix. `661` is research-and-recommendation only and dependency-free, so a cycle can pull it forward at any point. `662` records what the four actually built.

  - **The internal order is fully edged, so the batch serialises itself rather than relying on array position.** Re-measured against `generate-task-order.sh --print`: `658` and `661` are wave 1 with no open predecessor; `659` and `660` are wave 2 behind `658`; `662` is wave 3 behind all four. `658` enters the backlog as one of its widest gates at 3 direct open dependents, tied with `654`. Position inside `task_ids` records priority only where the graph leaves a choice: `659` sits ahead of `660` because its own text names itself the group's most consequential behaviour change, and `661` sits behind both because it builds nothing.

  - **`662` is last by design and must not be promoted.** It carries no gate of its own deliberately -- its content is undecided until the predicate, the postflight narrowing, the scaffolding change and the durability recommendation have all landed. Its four edges already hold it in wave 3. Nothing here adds a gate to it and nothing should; its one standing instruction is that the task-reference and record-version exemption standards citing `specs/**` are correct as they stand and are not part of the reframe.

  - **Three co-territorial pairs are held out of this batch by an owner ruling, and not one of them is an edge.** `618` (working-tree residue disposition) and `658` both edit `git-commit-scoped.sh`, and `618`'s Class 1 asks a question overlapping `658`'s own research item (b) -- whether that script drops a tracked-but-gitignore-matching path and reports it non-fatally where nobody reads it. `501` (cycle-postflight containment parity) and `659` both edit `orchestrate-cycle-postflight.sh`. `338` (the tracked-or-ignored sweep) and `660` both edit `init-specs.sh` and `runtime-file-patterns.sh`, and `338` re-sweeps the very enumeration `660`'s scaffolding renders. The owner ruled no edge in either direction in all three cases, and that no pair may ever be co-admitted into one batch. All three counterparts sit well below this batch, so array order already lands this group first -- which is the order `658` and `660` ask for in their own text: whichever lands second must re-read the other's result rather than assume the enumeration or evidence it was written against. **The `618` half of that is invisible to any mechanical scan**: `618` declares no `file_scope` at all, so its overlap with `658` exists only because `658`'s text asserts it, and a collision probe over the two would come back clean for the wrong reason.

  - **The commit-layer overlap with the batch immediately below was judged in both directions and left unedged.** `658` changes `git-commit-scoped.sh`'s drop and exit-code contract; `654` rules on a thirteen-record commit-layer cluster that is substantially that script's open claimant set. No edge was written either way. `654` writes no script -- its declared territory is `specs/state.json` and `specs/TODO.md` -- so there is no mechanical collision, and a ruling can be reached over a queued change as readily as over a landed one. The reverse direction was considered and refused on the precedent recorded below: making a cheap, dependency-free ruling wait on a large implementation inverts the cost for nothing. What the overlap does create is a reading duty, recorded as an annotation on `654` rather than invented as an edge -- `658` postdates `654`'s enumeration and is not among the thirteen slugs it names, so `654` must rule on it as a fourteenth cluster member and must re-measure the script's refusal paths after this batch lands rather than against the contract as it reads today. `567` and `553` are the same shape and get the same refusal: both are cluster members whose ordering is `654`'s own declared deliverable, and writing their edges here would pre-empt a ruling due one batch down.

  - **The milestone-and-roadmap record one batch below inherits a design constraint from this batch, and it is a constraint rather than an edge.** `656` makes the whole of `ROADMAP.md` generated and gives each milestone section a collaboration dashboard carrying progress and git review/approval state -- a reviewer-facing surface that lives at `specs/ROADMAP.md`. `660` makes `specs/` ignored by default in a fresh repository, and `656`'s own final acceptance check regenerates the roadmap of exactly the consumer that already ignores its specs tree. A review dashboard sited inside an ignored tree is invisible to the collaborator it exists for. No edge: `656`'s generator works identically under either posture, and chaining it behind this whole mechanism layer would cost the branch strand its schema for a question `656` can simply answer. The duty is recorded as an annotation on `656` instead -- say where the review surface lives under an ignored specs tree. `662` and `656` touch no file in common and are not edged either; `662`'s surfaces are the rules files, the three process workflows and the state-machine doc, none of which `656` claims.

  - **One declaration defect inside the batch, flagged rather than worked around.** `661` declares the whole `context/standards/` directory, which collides by directory form with `658`'s `git-staging-scope.md` and `660`'s `orchestrator-runtime-files.md`. By its own contract `661` writes nothing under `agent-system/**` -- its outputs are a report and a durability statement drafted for `662` to place -- so that is an over-broad read scope, not real territory. Measured: the group's 16 file-form declarations touch 27 open records, while adding its three directory-form declarations (`scripts/lib/`, `context/standards/`, `context/processes/`) inflates that to 42. Narrow all three before probing this batch; the cost of not doing so is a deferred implement cycle, not a wrong result.
- - **This leads the list by operator instruction, and the instruction is the only thing that puts it here.** Nothing in the dependency graph and nothing in any of these records' own text makes them urgent relative to the verification-substrate batch that previously held the head; what makes them first is that an operator asked for exactly this strand to be prioritized, with prerequisites identified rather than assumed. Recorded so a future pass can argue with the placement instead of inheriting it as if it had been derived.

  - **The three members are the decision-and-data-model layer, not the implementation.** `654` writes no script at all: its deliverables are a ruling per member of a thirteen-record commit-layer cluster (SUBSUMED, NEEDS REVISION, NEEDS EDGE or UNAFFECTED, each with a falsifiable basis), the dependency edges those rulings imply, and a decision record. `656` changes the state schema and the roadmap generator so an ordered milestone layer exists to automate against at all. `657` rules first and implements second, on `654`'s own pattern and naming it as the precedent: its Element 1 is a branch-topology and landing-strategy ruling that writes no script, and only Element 2 builds the milestone automation and review gates on top of `656`'s schema. The one record in this strand that is pure implementation is deliberately held out of this batch -- it is the batch immediately below.

  - **The internal order is fully edged, so the batch serializes itself rather than relying on array position.** Re-measured against `generate-task-order.sh --print` after this pass's two edge writes: `654` and `656` are both wave 1 with no open predecessor and may run concurrently; `657` is wave 2 behind both; the implementation record is wave 3. `656` is the only hard prerequisite of `657`'s Element 2, and `654` of its Element 1; neither edge is co-membership dressed up as graph evidence, and both are stated with their grounds in the edge-declaration rulings in this section's trailing prose.

  - **No other open record is a prerequisite of this strand, and that is a measured finding rather than an omission.** A mechanical scan of all 124 open records' `file_scope` against the strand's declared paths returns twenty-two records sharing territory -- heaviest on `git-commit-scoped.sh`, `git-commit-phase.sh` and `orchestrate-cycle-postflight.sh` -- and not one of them is named as a predecessor by any of this strand's records' own text. Those overlaps stay advisory under the standing direct-edge-only ruling below. The thirteen commit-layer records that most plausibly gate the implementation are precisely the cluster `654` exists to rule on, so writing those edges here would substitute this list's judgment for that record's own deliverable.

  - **The one honest cost of the displacement.** `656` and `657` both land code the gate battery verifies, and the batch now sitting third still holds the live red surface -- a `.mcp.json` merge defect at 5 passed / 2 failed, the three standing findings blocking `RESULT=landed_verify_clean`, and a two-engine defect that makes one suite red by design. An operator who wants a trustworthy verdict over this batch's own output should take that batch early regardless of its position, and nothing about this batch's placement makes that red surface smaller.

  - **`--hard` is authored here for reasons specific to these members, not as a default.** `657`'s Element 1 is required to read two existing decision records, identify the specific measured data-loss mechanism they name, and show why any reinstatement proposal cannot reproduce it -- a reference-grounding obligation rather than a design preference, and re-reaching the recorded verdict is an acceptable outcome while reaching any verdict without reading the evidence is not. `654` must produce a falsifiable ruling per cluster member rather than a recommendation, and must land the edges and description revisions its rulings imply. `656` spans seventeen declared paths, five test suites that pin current behaviour, and a migration carrying a losslessness gate.
- - **Alone in its own invocation on purpose, not for want of batch-mates.** This record spans two orchestration scripts, two commit scripts, one rule file and two standards documents, and it changes a contract every phase commit in every repository flows through; its own text says to expect systematic refactoring rather than a one-file change. More decisively: the batch above holds a ruling with explicit written authority to revise this record's description, including the `BINDING CONSTRAINT, NOT RE-OPENABLE` block that declares branch-per-invocation settled and forbids reopening worktree isolation. Dispatching this record before that ruling lands risks building a design the ruling then withdraws, which is the most expensive failure available here.

  - **Its true prerequisite set is not knowable yet, and that is the second reason it stands alone.** The commit-layer cluster reconciliation in the batch above is asked, in terms, whether source-store commit scoping and the third unpatched containment site are HARD PREREQUISITES for this work. If it rules yes, this record acquires predecessors that currently sit in the commit-containment and dispatch-composition batches further down, and it cannot land in the run its position here implies. That is an ordering constraint for the ruling to discover, never grounds for moving this record out of the strand -- an unmet predecessor orders work, it does not disqualify it from a batch.

  - **A pointer was appended to the record itself this pass, as a second line of defence.** The dependency edge alone would still leave a dispatched agent reading a `not re-openable` constraint and proceeding on it if the ruling record neglected its own revision duty. The appended block names the ruling as a binding input and marks the settled-design premise above it as potentially stale; the substantive revision stays the ruling record's declared deliverable and was not pre-empted here.

  - **The file-territory contention on this record is the heaviest in the backlog and is deliberately left unedged.** Re-measured today, `git-commit-scoped.sh` has ten open claimants and `orchestrate-cycle-postflight.sh` nine, counting this record and the topology ruling; `git-commit-phase.sh` has seven and `orchestrate-cycle-plan.sh` six. This record claims all four. Those overlaps resolve by array position and by the collision deferral, per the direct-edge-only ruling below: chaining ten unrelated defect strands to one feature record asserts a semantic claim none of them supports.

  - **`--hard` is authored for the breadth and for one specific hard problem.** Collapsing a single task's own commit range out of a shared invocation branch has to be solved from commit attribution rather than from assuming contiguity, with `git rebase -i` unavailable in this environment and `guard-destructive-git.sh` barring the obvious shortcuts (no bare amend, no HEAD-moving reset while another writer is live). The retention rules are equally unforgiving: a task ending PARTIAL, BLOCKED or failed must leave its commits on the branch un-squashed while a sibling still lands.
- - **This is the head because every other batch's gate stage reads it.** A batch that runs while
    the gate set returns a red verdict nobody can attribute gets one of two outcomes: the gate
    blocks work that did nothing wrong, or the operator learns to ignore the gate. Both destroy the
    signal the rest of this list is ordered around, so restoring the verdict precedes everything.

  - **Re-measured 2026-11-19 by running the gates and suites directly, the red surface has moved
    under this batch, and the members no longer describe it exactly.** Two members' premises no
    longer reproduce, one member's does, and one red here is owned by no record's subject. Each is
    named below rather than left to a future dispatch to rediscover. The batch keeps its head
    position regardless: what changed is which reds are live, not whether the verdict matters.

  - **Still red, and the measurement is unchanged.** `645`'s `.mcp.json` merge defect runs 5
    passed / 2 failed: assertion C reports a hand-written server entry as `MISSING` after a
    load/regenerate cycle, and assertion E reports the same entry disturbed by a subsequent unload.
    That is a data-loss shape against a user's own file and it is exactly the remaining scope
    `645` declares. `560` still clears the three standing findings that keep `deploy-headless.sh`
    from reaching `RESULT=landed_verify_clean`. `629` still fixes the two-engine allow-list drop
    that makes `test-deploy-propagation.sh` expected-red BY DESIGN, and `630`, already edged behind
    it, still writes the roster rows for that suite and `test-gate-registry-resolution.sh` so
    `run-all.sh` stops calling an expected failure NEW. `633` still deletes a 68KB duplicate deploy
    ledger inside the core source store whose contents disagree with the root ledger a resolver
    reads.

  - **One red here is owned by no open record's SUBJECT, and a dispatch must not treat it as out of
    scope.** `test-lint-unit-integration-boundary.sh` is red at 14 passed / 1 failed, reporting one
    violation: `test-orchestrate-close-status-bind.sh` is discovered under `scripts/tests/` with no
    row in `scripts/tests/suite-classification.data`. That suite was added by the
    orchestration-close battery work, which landed after `645`'s description was written -- so
    `645` records this suite as resolved at 15/0 and instructs an implementer not to re-diagnose
    it. The earlier fix is intact and is not regressed; this is a second, later cause with the same
    symptom. The remedy is a one-line data edit (`basename<TAB>unit|integration<TAB>reason`), and
    `645` already claims the failing suite and already carries "verify-deploy.sh completes its full
    gate set with exit 0" as acceptance criterion 1, which cannot be met while the row is missing.
    No edge is filed to the only other open claimant of `suite-classification.data` (`646`, batch
    three): its subject is the return-meta terminal status vocabulary, it touches that file only
    for its own new suite, and the two batches never dispatch concurrently, so array position
    already resolves the overlap.

  - **`631`'s acceptance criterion is already satisfied in the live tree, which makes it a closure
    candidate rather than a dispatch.** It asks that `lint-test-root-resolution.sh` report 0
    violations; gate 29's lint reports `0 violation(s) across 219 file(s)`, and
    `test-typescript-verify.sh` now resolves its root via `git rev-parse --show-toplevel` rather
    than the fixed-depth walk the record was filed against. Nothing here re-opens it -- that is a
    status question for a backlog pass, not a roadmap ordering judgment -- but it must not be
    carried as a live red.

  - **`632` is no longer a red and is now purely preventive, so its ordering argument has
    dissolved.** Gate 4 reports `PASS: 0 unexempted task-reference occurrences`, and
    `orchestrator-context-budget.json`'s derivation entries now cite dates and the file's own
    rounding convention rather than a task number inline. The ceiling move that used to be the
    recurrence trigger has already happened and did not re-break the gate, so the previous
    "`632` before the ceiling move" ordering no longer applies. What stays open is `632`'s actual
    deliverable: the unmade ruling between exempting the derivation field and changing the house
    style for its entries, so the next move cannot re-break the gate by accident.

  - **Two suites the most recent close battery named as red were re-run this pass and are green.**
    `test-gate-lock.sh` passes 27 / 0, confirming `645`'s own triage of it as lock contention
    rather than a defect -- and, separately, confirming that `653` in batch four extends a green
    suite, which is why the no-edge ruling between those two records stands.
    `test-lint-state-writer-boundary.sh` also passes, matching the load-induced-flake triage filed
    against it during that same battery. Neither needs a record.

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
- - **`586` leads this batch now that the narrowly-scoped mutex record deliberately placed ahead of it has landed.** It resumes from PARTIAL as the standing consumer the cost probes have never had (`measure-gate-costs.sh` -> `gate-cost-model.csv`, `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt`), with a verdict per suite: delete, optimize, or demote. It is the member that reduces the battery's cost rather than its variance.

  - **Why this batch still sits below the verdict-truth batch rather than beside it.** A standing cost consumer fed by a contended host is fed noise, and an optimisation measured against a red gate set is measured against noise a second time. The scope half of the contention problem is closed: every mutex this system ships resolved as `"$PROJECT_ROOT/specs/<name>"` -- `.gate-lock`, `.commit-lock`, `.scope-lock`, `.deploy-lock` alike -- so a battery started from a sibling repository was not merely unserialized but structurally invisible to the single-flight guard, and that is now addressed. The red surface these numbers would be measured against is not, which is exactly why the batch stays here.

  - **`605`, edged behind `586`, then stops the advisory roster carrying rows for suites that now pass.** It must stay last for that reason; the edge is filed and the position follows from it rather than from preference.

  - **Width: the sentinel claimant now leads this batch, a cost it accepts rather than one it overlooked.** `586` declares `__WHOLE_TREE__`, so it serializes absolutely against every other claimant in-batch and cross-batch alike -- but its only batch-mate is edged behind it anyway, so nothing queues behind the claimant that was not already waiting on it. The records that previously led this batch have landed and dropped out of the rendering on their own; the `description` above was rewritten by hand against the two survivors, because that authored prose is the one part rendering cannot keep current.

  - **Cross-batch note**: `586` and `605` share `agent-system/extensions/core/scripts/tests/known-failures.txt` with `630` in batch three. That overlap is left unedged on the usual terms -- three independent rows on one roster file, resolved by array position, since the batches never dispatch concurrently.
- - **A validator that fails a conforming artifact costs a full dispatch every time it fires**, and unlike a missed check it costs that dispatch loudly -- the agent re-does work that was already correct. Two of this batch's three members declare `validate-artifact.sh` and its suite, so the false-failure half of it is one file's worth.

  - **Placed above the evidence-integrity and commit-containment batches.** "A validator refusing conforming input" is verbatim the verdict-truth class the ranking rule at the top of this list puts above everything that merely improves what a later plan or document says. An earlier placement below both was justified as "a false failure wastes a dispatch, while a containment drop loses its output"; that trade is real, but it was applied one batch too far down, because a validator in this state taxes the containment work too.

  - `545` reports a reversed `validate-artifact.sh` invocation as a missing file rather than an argument-order fault, sending the reader after the wrong thing. `575` stops the cross-phase ceiling check reading a stop-word as a unit and false-positiving on N-of-M prose. `579` is the member that is not itself a false failure: it records the selector's full-path-set aggregation rule in the Tier Justification authoring contract, so the sentinel-path-set fix already in service in the script becomes reachable at plan time instead of only in the script. It belongs here because it is the authoring-side half of a fix whose script-side half has landed, and because the record it was edged behind is complete, so it is ready now.

  - **The consumer-repository member of this batch has landed, and with it the batch's only sentinel claimant.** The resolution defect it closed was that `validate-artifact.sh`'s advisory per-phase Tier-Justification scan sourced the DEPLOYED `suite-selection-lib.sh` from its own script directory, so a repository carrying its own copied suite corpus had every phase judged against the agent system's much larger corpus instead of the one its phases actually run against -- costing one plan a dedicated decision explaining four false `__FULL_SWEEP__` warnings purely so a later implementer would not "fix" a correct suite name to silence them. Its implement dispatch had added `__WHOLE_TREE__` to its own `file_scope`; no surviving member declares the sentinel, so this batch contends with nothing.

  - **Five open records claim `validate-artifact.sh` and no edges were filed between any of them.** Beyond the two members here, `452`, `509` and `588` claim it from three other batches. Subject matter is disjoint in every pair; array position and the collision defer handle the overlap, exactly as this backlog already treats broad-prefix declarations on this script and its suite.
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

**The claimant roster is four: `431`, `506`, `512` and `586`** (re-measured 2026-11-19). The wrong-corpus record that had briefly made it five -- its in-flight implement dispatch having added the sentinel to its own `file_scope` -- has completed, so batch eight carries no claimant again. `586` leads batch seven rather than sitting second, because the narrowly-scoped mutex record deliberately placed ahead of it has landed; its one remaining batch-mate is edged behind it anyway, so nothing queues behind the claimant that was not already waiting on it. The other three lead their own batches (`506` batch twelve, `431` batch fourteen, `512` batch fifteen) for the usual reason -- a claimant placed first lets the rest of its batch queue behind it instead of colliding with it mid-run. **The head is clear**: no member of batches one through six declares the sentinel, so those six runs contend only with each other and with whatever a cross-session claimant holds.

**What changed this pass.** The pass was scoped by instruction to the five records filed since the last one -- the ignored-specs mechanism group: a shared gitignore predicate with a non-failure exit code for an all-ignored pathspec, the postflight demotion narrowing, an init default that ignores the specs tree, a durability recommendation, and the documentation reframe that records what the other four built -- with the instruction to seat them alongside the four-record branch-and-milestone strand already at the head. Five things changed. **(1) One batch was added at the head**, holding all five ignored-specs records, and it was placed ABOVE the branch strand rather than beside it; the relative order was this list's judgment, not the instruction's, and the grounds are in the preamble and in that batch's own first bullet. **(2) No dependency edge was written anywhere this pass, and that is a measured finding rather than an omission.** Every candidate was judged and refused on stated grounds: three co-territorial pairs carry an explicit owner ruling of no-edge-in-either-direction (`658`/`618`, `659`/`501`, `660`/`338`), the commit-layer overlap between `658` and the cluster-reconciliation record was refused in both directions, and the roadmap-generation record's inherited siting constraint is a design input rather than an ordering. **(3) Four reading duties were recorded as `roadmap_annotation` entries instead of as edges** -- on `654` (rule on the ignored-specs predicate as a fourteenth cluster member and re-measure the script's refusal paths afterwards), on `656` (say where the review surface lives once `specs/` is ignored by default), and on `618` and `338` (re-read the ignored-specs result rather than assume the evidence and enumeration they were written against). An annotation renders on the record's own `## Open work` line, which is where a dispatched agent will actually meet it. **(4) One batch was cleared of cruft rendering had already hidden**: the validator batch's landed member was removed from its `task_ids`, and its `description` and `Why this order:` text were rewritten against the three survivors, since the authored prose still claimed four members, a wrong-corpus verdict that has shipped, and a sentinel claimant that is gone. **(5) Nothing else moved.** No other batch's membership, order, description or rationale was touched, because the instruction's focus did not reach them and a full sweep found no second batch whose prose had gone stale. **127 of 128 open records are batched**; the single exception is the held email substrate (`498`), which is an owner decision, not available work.

The gate exempts research and plan dispatches (neither regenerates the tree) and defers only implement, so a claimant still researches and plans freely while the lane is occupied.

**Admission-probed only in part, and every probe recorded so far is weaker than it looks.** Each one put only research or plan dispatches in cycle 0, and both phases are exempt from the claim gate and the collision gate alike -- so no probe has yet exercised the implement-wave `file_scope` collisions these batches are ordered around. Treat an unprobed batch as unprobed: probe before committing to one, and check `task-lock.sh session-list` for a live session whose scope overlaps, since a cross-session claimant is invisible to the edge graph. Batch six is the one most worth probing before dispatch: five of its eight members claim `orchestrate-cycle-postflight.sh`, and the batch deliberately relies on the collision gate to serialize them rather than on edges. Batch one is the next most worth probing, for the opposite reason -- its own internal collisions come from directory-form declarations rather than from real shared territory, so a probe there tells you whether to narrow a declaration or to accept a deferred cycle.

**On edge declaration**, three rulings stand:

- **Only a `file_scope_collision` verdict means an edge is missing.** `whole_tree_claim` and `self_modifying` verdicts say so themselves -- *"this is an ORDERING CONSTRAINT, not an exclusion"* -- and resolve in a later cycle unaided. **An edge belongs to a path overlap; a sentinel overlap is left to the sentinel defer.** Declaring an edge between two records whose only shared territory is `__WHOLE_TREE__` asserts a semantic claim neither record supports and chains unrelated strands together for nothing.

- **The exemption is direct-edge only, never transitive, and it is scoped to the batch being dispatched.** A heavily shared path is NOT grounds for edging every record that touches it. Re-measured 2026-11-19 over the 128 open records, `context/formats/plan-format.md` has fourteen open claimants, `git-commit-scoped.sh` eleven, `orchestrate-cycle-postflight.sh` ten, `agents/planner-agent.md` nine, `git-commit-phase.sh` and `test-git-commit-scoped.sh` seven each, `orchestrate-cycle-plan.sh` six and `skills/skill-orchestrate/SKILL.md` five -- the two commit-path surfaces each rose by one this pass, `git-commit-scoped.sh` from the ignored-specs predicate and `orchestrate-cycle-postflight.sh` from the demotion narrowing, which is precisely the kind of increment that must NOT be converted into edges. The edges worth declaring are the ones inside the batch actually being dispatched; every other overlap is advisory, resolved by array position. The standing worked example is batch six: five members claim `orchestrate-cycle-postflight.sh` with only two of the ten pairs ordered, and the eight remaining pairs were left to the collision deferral rather than chained, because they are independent defects on one file and co-membership is this list's own judgment, not graph evidence. A second worked example sits at the head: the branch-aware implementation record claims `git-commit-scoped.sh`, `git-commit-phase.sh`, `orchestrate-cycle-plan.sh` and `orchestrate-cycle-postflight.sh`, which carry twenty-three open co-claimants between them, and not one of those overlaps is edged.

- **A transitive order made direct, or an order a record states itself, is the edge class this list writes; a bare sibling overlap is not.** **The two edges standing at the head are both of the second kind -- an order the records already state about themselves.** First, the branch-aware orchestration record is edged behind the branch-topology ruling. The ruling's own text says of that record that it "calls branch-per-invocation 'settled' and forbids reopening worktree isolation; THIS element supersedes that restriction and may revise that task's description". A record another record holds written authority to revise cannot correctly be implemented before that revision exists, so the edge records an ordering the pair asserts rather than one this list invented. Second, the branch-topology ruling is edged behind the commit-layer cluster reconciliation: the ruling has to solve per-task squash ranges from commit attribution, and the cluster it would be reasoning over is exactly where the attribution defects sit -- unattributed commits charged to the wrong dispatch, snapshot artifacts contaminating phase commits, containment both dropping legitimate paths and carrying foreign ones, and a scoped committer that can only commit in the repository whose deploy tree holds it -- and the reconciliation record is named in the ruling record's own text as the precedent it takes its shape from. **That direction was chosen deliberately and the reverse was considered**: the ruling retains explicit authority to amend the cluster record where its topology verdict reaches that cluster, but that is a revision duty discharged after the fact, not a reason to make a cheap, dependency-free cluster ruling wait on a large ruling-plus-implementation record that is itself gated on the milestone schema. **The same reasoning refused a new edge at the head this pass**, in the same direction and for the same cost: the ignored-specs predicate rewrites `git-commit-scoped.sh`'s drop and exit-code contract and is plainly fourteenth cluster material, but the cluster ruling writes no script at all -- its declared territory is `specs/state.json` and `specs/TODO.md` -- so it collides with nothing mechanically and can rule over a queued change as readily as a landed one. Array position already lands the predicate first; the residue is a reading duty, carried as an annotation on the ruling record rather than as an edge.

- **No edge was written from file-territory overlap, and this pass's sweep behind that refusal covers the new head batch.** The ignored-specs group's 16 file-form declarations touch 27 open records, and its three directory-form declarations (`scripts/lib/`, `context/standards/`, `context/processes/`) inflate that to 42 -- an inflation that is itself the argument against reading territory as evidence. Not one of the 42 is named as a predecessor by any of the group's own text; the three the group does name are the subject of an explicit owner ruling of no-edge, and one of those three (`618`) declares no `file_scope` at all, so it does not even appear in the sweep. The earlier sweep over the branch strand returns the same answer: twenty-three records share territory with it and none is named as a predecessor, and the thirteen commit-layer records that most plausibly gate the branch implementation are precisely the cluster the reconciliation record exists to rule on -- SUBSUMED, NEEDS REVISION, NEEDS EDGE or UNAFFECTED, one ruling each -- so writing those edges here would substitute this list's judgment for that record's deliverable. The sibling overlaps left unedged elsewhere include `560`/`504`/`516` on `lean-plan-compliance-check.sh`, `630`/`586`/`605` on `known-failures.txt`, `645`/`646` on `suite-classification.data`, and five open claimants of `validate-artifact.sh` (`452`, `509`, `545`, `575`, `588`) of which two now sit together in batch eight -- each split across batches that never dispatch concurrently. Two older proposals are still held for an owner ruling rather than written: `452` behind `451` and `473` behind `472`.

**Every batch was scanned mechanically this pass for a member listed ahead of an open predecessor, and the list is clean**: across all 30 batches, no member appears in an earlier batch than, or at an earlier position than, any still-open record it depends on -- zero violations over the 127 batched open records. The scan confirmed the new head batch serializes correctly without help from array position: the predicate and the durability research are wave 1, the postflight narrowing and the init default are wave 2 behind the predicate, and the documentation reframe is wave 3 behind all four, which is why it is last in its batch and must not be promoted -- it carries no gate of its own by design, because its content is undecided until the other four land. The scan also confirmed the branch strand still serializes: the implementation record sits in batch three behind both predecessors, and inside batch two the topology ruling sits behind the two wave-1 records it depends on. The scan returns silence rather than a clean result in exactly two places: `613` and `618` declare no territory at all, so no collision scan over them means anything -- and in `618`'s case that silence now hides a real overlap, since its shared claim on `git-commit-scoped.sh` is asserted only in the head batch's text.

**The two held records are not waiting on engineering.** The books-corpus refactor (`342`) waits on an external version stamp reaching `0.1.0` (the consuming repository's own book-convention record still reads a pre-release stamp) and is kept inside batch twenty-eight so its territory overlap with `383`/`384` stays visible. The email preference-harvest substrate (`498`) waits on an operator decision about integrating email into the hosted store and is the one open record in no batch. Neither lift is engineering work, and `/orchestrate` admits a held record only under an explicit forcing flag. Nothing depends on either.

**Scopes and declarations worth narrowing first.** Re-measured 2026-11-19. **Two open records carry no `file_scope` at all -- `613` and `618` -- and that is the entire class**, since no open record declares an empty array. Both sit in batches whose other members are narrowly scoped (`613` in batch five with `475`/`514`/`574`, `618` in batch seventeen with `338`), so an admission probe over either batch returns a result that is clean for the wrong reason; `618`'s case is now worse than cosmetic, because the head batch asserts a `git-commit-scoped.sh` overlap with it that no scan can see. **Fix those two declarations before probing.** A new over-broad declaration arrived with the head batch: the durability-research record declares the whole `context/standards/` directory while writing nothing under `agent-system/**` by its own contract, so it collides by directory form with two of its own batch-mates for no real territory -- narrow it, along with the predicate record's `scripts/lib/` and the reframe record's `context/processes/`. **A separate one-field defect class is now the largest**: eight open records carry a null `title`, so `## Open work` renders their `project_name` slug instead of a sentence -- `613`, `618`, `645`, `646`, `654`, `655`, `656` and `657`, four of them in the head strands where a reader is most likely to look. Filling those eight titles is the cheapest legibility win available in this file. Two narrower declaration defects remain live: `590` declares its lint one directory above where the file actually sits, so it cannot collide with `512` even though the two edit the same lint -- which is why batch fifteen pairs them without an edge; and `557` carries topic `decidability`, undeclared in `active_topics`, so it renders after the curated topics. Of the directory-form declarations that remain elsewhere, every one is scoped to a single extension subtree -- `342` (three `books/` directories), `384`, `453`, `530` and `544` -- none is a whole-corpus discovery scope and none is a defect. And `586` still carries no `topic` at all, so it renders under Uncategorized and `generate-task-order.sh` emits a non-fatal warning about it on every run.

## Open work

**Core agent system (42)**
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
581 blocked:438,479,492,580  Extract one shared AskUserQuestion option renderer and adopt it acro...
588 blocked:509     Bar a pre-redeploy plan step from naming a deploy-tree-resolved subject unles...
605 blocked:586     Flag an advisory known-failures roster row whose named suite now passes
659 blocked:658     Never demote on ignored specs skip
660 blocked:658     Init specs ignores specs by default
662 blocked:658,659,660,661  Reframe docs for ignored specs default
338 ready           Classify every task-support file as tracked or ignored   <- re-read the ignored-specs scaffolding result before re-sweeping this enumeration; no edge
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
565 ready           Resolve archived prior-art paths when composing dispatch and task-description...
574 ready           Correct the cycle-budget contract to state shared-pool semantics wherever rem...
575 ready           Stop the cross-phase ceiling check reading a stop-word as a unit and false-po...
579 ready           Record the selector's full-path-set aggregation rule in the Tier Justificatio...
580 ready           Correct the interactive-selection threshold model to AskUserQuestion's real f...
590 ready           Resolve the /ide dead-command-recommendation findings
613 ready           session_liveness_same_process_orphan_lock
618 ready           working_tree_residue_disposition_policy   <- re-measure its git-commit-scoped.sh evidence after the ignored-specs predicate lands; no edge
646 ready           return_meta_terminal_status_vocabulary
658 ready           Ignored specs predicate and commit path
661 ready           Unbacked specs durability options
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
501 blocked:472,484,486  Give the cycle-postflight containment site predicate parity and a guarde...   <- never co-admit with the ignored-specs postflight narrowing -- owner ruling, no edge either way
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

**Orchestrator (9)**
```
472 blocked:556     Stop validate-handoff.sh aborting on a string-shaped blockers array, and stop...
513 blocked:479     Mechanically detect a plan phase that closed without its own commit
518 blocked:472     State the blockers[] admission contract and continuation-on-partial requireme...
655 blocked:654,657 branch_aware_orchestration_and_squash_landing
656 blocked:654     milestone_schema_and_generated_roadmap   <- specs/ becomes ignored by default above -- rule where the generated review surface then lives
657 blocked:654,656 branch_topology_ruling_and_milestone_automation
477 ready           Normalize issue-log class vocabulary and reject the aggregate's malformed rep...
514 ready           Convergence guard blind to zero-dispatch cycles
654 ready           reconcile_commit_layer_cluster_and_ordering   <- also rule on the ignored-specs predicate as a fourteenth cluster member, and re-measure after it
```

**Agent system (51)**
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
629 ready           Fix the two-engine defect: scan_all_artifacts' sync_scan allow-list post-filt...
631 ready           Replace test-typescript-verify.sh's fixed-depth REPO_ROOT walk with a boundar...   <- gate 29 reports 0 violations and the fixed-depth walk is already replaced -- confirm before dispatch
632 ready           Stop orchestrator-context-budget.json's derivation log from re-breaking the t...   <- gate 4 is green; what remains is the exemption-vs-house-style ruling, not a live violation
633 ready           Resolve the stray duplicate .claude-extensions.json sitting inside the core e...
639 ready           Make issue-record.sh failures visible instead of silently losing the evidence...
640 ready           Add a derived-percentage bug class to the census methodology standard
645 ready           repair_seven_failing_gate8_suites   <- the unit/integration boundary suite is red again from a later cause its provenance list predates
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
