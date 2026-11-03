# Roadmap

*Forward-only: what remains, in what order, and the checks that gate each step. Finished work is
removed, not archived here — it lives in git history, task summaries and `specs/archive/`. Task
detail lives in `specs/TODO.md`; this file carries only ordering, gates and rulings. Every figure
carries the date it was measured; a figure without one is generated from `specs/state.json`.
Re-derive before relying on any of them (Standing rule 5). Last measured 2026-11-03.*

## Goal

`/orchestrate` is the only lifecycle entry point, and the orchestrator is token-cheap by
construction: it delegates, reads back compact verdicts, and asks the user only when a decision is
genuinely the user's.

`MAX_TASKS` is 8, enforced in `commands/orchestrate.md`. `orchestrate-cycle-plan.sh` itself accepts
any count, so a dry-run over more than 8 is not evidence a call will run them.

**60 open tasks** (measured 2026-11-03): nine dependency waves, queued across the eleven calls
below. One is on hold; **nothing is mid-dispatch** — the one record that read `researching` was a
dispatch stranded since 2026-10-08, recovered by hand (see Gate state). **35 completed and
awaiting `/todo` archival** — the archival pass is the cheapest next action by a wide margin, and
it is the one thing on this page that nothing else is waiting for.
Both counts and every wave membership are derived, never transcribed:
`generate-task-order.sh --print` for ordering, `roadmap-integration.sh --regenerate`/`--prune`
for the `## Open work` roster and the coverage appendix. A hand-maintained count here goes stale
within one run.

**The backlog's shape, measured 2026-11-03 and the reason the order below is what it is.** Two
records are whole-corpus: the consolidation record declares 126 `file_scope` entries (directory
roots, plus `.claude/` itself) and the deleted-command reword declares 83. Between them they
overlap 32 and 31 distinct non-terminal records respectively, which is every remaining
`validate-state.sh` warning on this backlog. Eleven records declare the consolidation record as a
dependency. Nothing else in the backlog is a bottleneck of that size, so the order below is read
off those two records and the four chains that genuinely serialize on one file each.

## Gate state

- **The gate registry carries 24 gates.** Gate 24 is the dead-command-recommendation lint
  (`lint-dead-command-recommendations.sh`), live and green. The next numbered gate to be added
  is **25**.
- **`verify-deploy.sh --skip-slow`: 6 of 36 checks failed, measured 2026-11-03** — and four of
  those six are not gate failures. Gates 3, 4, 6 and 10 were each killed on their own 30-60s
  timeout while the full shell battery ran concurrently on the same host; that is self-inflicted
  contention, the same shape Settled decision 15's wall-clock note already covers. Read this run
  as two real reds and four contention artifacts, and re-measure at quiet load before treating
  any of the four as a finding. Wall clock for the whole `--skip-slow` pass under that contention:
  **2m08s real against 10m35s user**, which is the gate-level concurrency and shellcheck
  parallelization working as designed, not a quiet-host figure.
- **Real red 1 — Gate 5 (manifest-driven parity) reports 8 findings, all un-redeployed source-store
  drift.** `scripts/lib/project-number-inuse.sh` is missing from the deployed tree entirely, and
  `context/reference/state-management-schema.md`, `scripts/state-write.sh` and four `state-write`
  test suites differ in content from source. This is the documented "a source-store commit
  without a resync is itself a red gate" condition, not a defect in any gate's subject. A resync
  clears it; nothing here needs a task.
- **Real red 2 — Gate 18 (task-lookup adoption lint) reports 5 violations, and they are NEW and
  unowned.** All five are in `scripts/test-state-write-concurrency.sh` (lines 646, 787, 789, 819,
  820), introduced by the landed allocation-bound work and committed — the file is clean, so this
  is not in-flight drift. Every one is a fixture assertion against a synthetic state file inside a
  test suite, not a real task lookup, so what is wrong is the lint's exemption set, not the suite.
  No open task covers it. See the first unfiled observation.
- **Gate 20 (orchestrator context budget) PASSES, and that retires a premise.** Measured
  2026-11-03: eager load **65,312 B against a baseline of 66,800 B**, under budget, with no
  volatile-file hits. The 988 B overage the eager-load-drift record was filed against (67,088 B
  against 66,100 B) does not reproduce — both the measured figure and the baseline have moved
  since. `known-failures.txt`'s third row still carries the old pair. Re-derive that record's
  premise before dispatching it; Standing rule 9 is the rule this is an instance of.
- **Gates 21-24 all pass**: hook-registration path lint, shellcheck at `-S warning` (zero
  findings), directory-pathspec boundary lint, dead-command-recommendation lint.
- **`tests/run-all.sh --jobs 4`: 153 passed, 9 failed (2 expected, 7 NEW), 0 skipped, 162 total**
  (measured 2026-11-03). Read the split, not the tally — and read this roster with its causes,
  because none of the seven NEW failures is a defect in its own subject:
  `test-validate-state.sh` (71/1, isolated) fails one fixture that invokes the **deployed**
  `state-write.sh --allocate-into`, which is stale — the deployed copy differs from source and
  `lib/project-number-inuse.sh` is absent from the deploy entirely, both confirmed by direct
  `diff`/`ls`. `test-update-task-status.sh` passes **63/0 in isolation** and failed only inside the
  battery, so it is a contention artifact; `test-git-commit-phase.sh` likewise passes **19/0 in
  isolation**. Every one of the seven was re-run in isolation and classified; the two bullets
  below give the breakdown.
  **The 7-NEW figure is therefore not a quality signal about this backlog; it is one redeploy
  obligation plus battery contention, and it will mislead anyone who reads the tally alone.**
- **THE SINGLE HIGHEST-VALUE ACTION ON THIS PAGE IS A REDEPLOY, and that is measured, not a
  judgment call.** `agent-system/extensions/core/scripts/lib/project-number-inuse.sh` exists in
  the source store and is **absent from the deployed `.claude/` tree**, while `state-write.sh`
  line 170 sources it unconditionally. Four of the seven NEW suite failures name that exact path
  in their own failure text, because their fixtures copy the deployed tree:
  `test-orchestrate-predispatch-review.sh` (32/2) and `test-orchestrate-unwind-dispatch.sh` both
  print `.claude/scripts/lib/project-number-inuse.sh: No such file or directory` verbatim;
  `test-orchestrate-cycle-postflight.sh` fails 8 assertions that are all "status did not advance"
  or "artifact was not linked", which is exactly what a `state-write.sh` that cannot source its
  library produces; and `test-validate-state.sh`'s fixture (g) invokes the deployed
  `state-write.sh --allocate-into` and gets `rc=3`. Gate 5's 8 findings are the same cause seen
  from the other side. **One `deploy-headless.sh` run is expected to clear one gate and four
  suites.** It is the pending postflight of the landed allocation-bound work, and it was not run
  from here because it is a whole-tree regeneration belonging to whoever owns that work — but
  nothing should be dispatched against this gate state until it happens, or every phase
  verification inherits a red it did not cause.
- **Exactly one of the seven NEW failures is explained by neither the stale deploy nor contention.**
  `test-orchestrate-cycle-plan.sh` reports 372 passed / 1 failed in isolation, the one failure
  being `budget: at least one of six forced runs in a row was refused for budget`. It reproduced
  outside the battery, so it is not contention. It is unowned and uncharacterized — no
  `known-failures.txt` row and no open record covers it. Characterize it before reading any
  cycle-plan budget assertion as sound.
- **`known-failures.txt` carries three rows, not one** (measured 2026-11-03), and their
  dispositions differ: `test-run-all-parallel.sh` (intermittent, accepted on its own
  rejected-alternatives record); `test-gate-cache-equivalence.sh` (load-sensitive, **`needs-owner`**
  — Settled decision 13 says such a row is a known gap that gets a follow-up task, and no open
  task owns it); and `test-verify-deploy-context-budget.sh` (real-defect, whose figures gate 20
  has now superseded, above). The file stays advisory by construction and never changes which
  suites run (Settled decision 13).
- **Corpus size, from `verify-deploy.sh`'s own probe, measured 2026-11-03**: `scripts=237`,
  `lines=93,523`; `test_suites=169`, `test_lines=81,831`; `md_files=930`, `md_lines=230,743`.
  This is the population the consolidation record's net-deletion floor is measured against — and
  the instrument that measures it is biased favourably until the untracked-enumeration record
  lands. That is why that record leads the order below.
- **`validate-state.sh --deep`: 22 passed, 11 warnings, 0 failed** (measured 2026-11-03, after
  this page's own reconciliation). Every one of the 11 warnings is a coarse `file_scope`
  declaration belonging to one of the three broad records (the consolidation record, the
  deleted-command reword, the regression-anchor containment record). There are no missing, null,
  empty or glob-shaped `file_scope` declarations left, and no dangling edges, cycles or
  self-references.
- **One record's stated provenance named another record's issue entry, and claimed the two were
  one concern.** Found by checking every `iss_*` identifier cited by two open records against the
  logs themselves. The exact-pid process-checking record claimed both the pgrep/leftover-process
  entry and the Python `json.dump` re-serialization entry as its origins, "consolidated here
  because they are one concern" — but the second entry is the state-writer-boundary-lint record's
  subject, correctly cited there. Both sit at `dispatch_seq 6` with severity minor, which is how
  they were conflated. Corrected in the record. Two lessons: a shared `dispatch_seq` and severity
  is not evidence of a shared subject, and a false "these are one concern" line is worse than a
  missing citation because it invites the dispatch to absorb a sibling's work. One other shared
  citation was checked and is correctly authored — a record citing a third entry as corroboration
  for a recurrence, and saying so explicitly.
- **Genuine unordered territory overlaps: zero** (measured 2026-11-03, over every non-terminal
  `file_scope` via `scripts/lib/file-scope-overlap.sh`'s own predicate, with transitive
  dependency closure taken as the ordering test). 107 raw unordered pairs remain, and all 107 are
  accounted for: 96 involve one of the three broad records, whose coarse declarations cannot be
  narrowed because the work genuinely spans the tree (Settled decision 19), and 11 are
  registration-manifest or index-entry pairs, which are the narrowness qualifier's own measured
  exemption. Re-derive this census before trusting it; it changes with every edge added.
- **One research dispatch had been stranded for 26 days, and nothing surfaced it.** The
  orchestration-queue record read `researching` in `state.json` while its own
  `.return-meta.json` carried `status: "researched"` with a complete report linked in it, written
  2026-10-08. The postflight never promoted the task and never linked the artifact, so the record
  read as mid-dispatch and its report was invisible to every renderer. Recovered 2026-11-03 with
  the sanctioned primitive, `reconcile-task-status.sh <N> <session>`, which promoted the status and
  linked the report. A sweep of every other non-terminal record found no second instance. The
  lesson is not the recovery — that worked first try — it is that 26 days passed with a finished
  report and nothing to notice it: there is no periodic reconciliation, only an on-demand one
  nobody is scheduled to run.
- **Consumer repos were all 8 STALE at last measurement (2026-10-03)**, except
  `Philosophy/Papers/PossibleWorlds`, repaired by hand on 2026-10-07. CARRIED-UNVERIFIED: not
  re-measured since. If work touches a consumer, run `check-consumer-freshness.sh` here and
  `deploy-headless.sh` **there** first; this repo never pushes into a consumer.
- **`--skip-slow` hides real failures** — `test-runtime-file-tracking.sh` Case 3 and Gate 8 both
  go unseen, so a `--skip-slow` pass is not evidence the doc-sync pins hold. Measured instance of
  Settled decision 15.
- **A full `verify-deploy.sh` fits inside a 540s bounded wait only on a quiet host, and a batch
  gate stage should not be budgeted that way.** 540s held on an idle host (measured 2026-10-15).
  Every measurement taken under real contention has exceeded it: 790s mid-task, over 650s on a run
  needing two retries, and 1632s for a once-per-invocation batch gate closing an eight-task run —
  three consecutive bounded waits before the writer exited. Budget a batch-level gate at three
  bounded waits, not one. CARRIED-UNVERIFIED from 2026-10-15/17; the 2026-11-03 figure above is a
  `--skip-slow` pass under contention and is not comparable.
- Every figure above was measured on the date stated. Re-derive before relying on it
  (Standing rule 5).

## Next

Each call is a single `/orchestrate` invocation, and batching is the default, not a throughput
optimization: a collision is only checkable by the admission layers when both tasks are in the
same invocation, so related tasks are batched even when intra-batch edges serialize them to
width 1 (Settled decision 17). Overlap groupings come from `scripts/lib/file-scope-overlap.sh`'s
own overlap predicate over every non-terminal `file_scope`, never hand-guessed; waves come from
`generate-task-order.sh --print`. The Run lines are authored; the counts and the coverage appendix
under them are generated, so read those for current totals rather than transcribing a count into
this paragraph.

The ordering principle is stated once: **a task that gates every other task's verification
outranks a task that gates only its own subject.** Two corollaries do the real work here. A record
that fixes a *measurement instrument* outranks every record measured by it. A record whose
`file_scope` spans the corpus runs alone, because batching it serializes its partners to no
purpose (Settled decision 19).

**Before call 1: run `deploy-headless.sh`.** This is not a task and has no record — it is the
pending resync of already-landed work, and Gate state measures it as one gate plus four test
suites currently red for that reason alone. Dispatching before it means every phase in every call
below verifies against a tree whose `state-write.sh` cannot source its own library.

```
/orchestrate 429   # measurement instrument first: the corpus probe cannot see untracked files
/orchestrate 459, 282, 410, 412, 423, 437, 456   # ready, territory-disjoint; the traceability verdict unblocks two
/orchestrate 22, 29, 369, 391, 390, 275, 419   # loader chain, then task siting, then the queue
/orchestrate 414, 415, 418, 445, 444   # verify-deploy and shell-script-testing chain, width 1
/orchestrate 274, 378, 387, 428, 401, 402, 407, 409   # the admission chain, one territory
/orchestrate 328   # whole-corpus consolidation: runs alone, and will not finish in one invocation
/orchestrate 385, 397, 398, 399, 408, 383, 384, 453   # lean, formal, books, literature: off the core territory
/orchestrate 313, 431, 338, 421, 430, 446, 448   # the consolidation record's consumers, now unblocked
/orchestrate 435   # whole-corpus reword: runs alone, per-class and per-site, no blanket substitution
/orchestrate 312, 458, 436, 438, 360, 439, 454   # creation-gate and command-surface work
/orchestrate 455, 457, 449, 451, 452, 420, 450   # the tail: everything whose edges the calls above satisfy
```

Why this order:

- **The measurement instrument goes first, alone.** `script-inventory.sh` enumerates via
  `git ls-files`, so a newly created, unstaged file is invisible to it and the running
  net-deletion figure is biased in the *favourable* direction — it makes a phase look more
  net-negative than it is. That is the one direction of error a net-deletion acceptance criterion
  cannot tolerate. The consolidation record's own landed plan already carries a hand workaround
  for this ("any phase creating a new file must `git add` it before taking the probe's figure"),
  which is evidence the defect is live, not speculative. Fourteen of that record's twenty phases
  are still unrun; fixing the instrument before they execute is cheap, and fixing it after means
  re-measuring them.
- **Call 2 is the ready, disjoint set, and the traceability verdict is its reason for existing.**
  The cross-record traceability record is verdict-first — its deliverable is a recorded design,
  not a mechanism — and it now gates both the `/todo` consolidation and the `/orient` command,
  each of which would otherwise bake in a `CHANGE_LOG.md` behaviour the verdict may retire.
  Everything else in the call is territory-disjoint and ready: the record-versioning write-time
  hook, the build-guard replay hole, the Lean tier-to-build-scope mapping, the eager-load drift
  record (re-derive its premise first — see Gate state), the Zotero export repair, and the `/tag`
  version gate.
- **Call 3 is the loader chain with the queue hung off its tail.** `22 -> 29 -> 369 -> 391 -> 390`
  is pre-existing on `init.lua`/`merge.lua` and then on
  `source-store-deploy-boundary-narrative.md`, so the authoring hole closes before the mis-sited
  records are migrated through it. The orchestration queue joins because its research has already
  landed and it is the nearest thing to in-flight work the backlog has, and the state-writer
  boundary lint sits behind it on `task-lock.md`, which the two genuinely share.
- **Call 4 is a width-1 chain over two files and that is the correct shape.**
  `414 -> 415 -> 445 -> 444` serializes on `verify-deploy.sh` and `tests/run-all.sh`: the verdict
  extraction contract is enforced mechanically before Gate 8's verdict shape changes, and the
  `routing_agents_hard` retirement removes gate 16 last. The fixture-subject record joins on
  `shell-script-testing.md`, behind the exact-pid standard that writes the same file.
- **Call 5 is the admission chain, and its head edge is satisfied by call 3.** The next-batch
  suggestion record waits only on the queue, which call 3 drains; from there
  `378 -> 387 -> {428, 401, 407} -> 409` orders real overlaps on `orchestrate-cycle-plan.sh`,
  `handoff-schema.md` and `file-footprint-overlap.md`. Eight tasks, one territory, width 1 for
  most of it.
- **Call 6 runs the consolidation record alone, and it will not finish in one invocation.** Its
  plan is twenty phases, six of them terminal; the per-run cycle budget is five. That mismatch is
  itself an open record's subject (call 11), which is the honest reading: expect three or four
  invocations here, not one, and do not read a `MAX_CYCLES reached` line as a failure. Running it
  alone is not a throughput choice — its 126 `file_scope` entries overlap 32 other records, so any
  partner serializes behind it for nothing.
- **Call 7 is off the core territory entirely, which is why it can follow the consolidation
  record immediately.** The zero-theorem plan shape, the lean research chain
  (`397 -> 398 -> 399`, pre-existing on `lean/index-entries.json`), the formal extension's
  Mathlib gate, the books reconcile command and its hook adjudication, and the literature
  degraded-retrieval signal. The books corpus refactor is NOT here: it is on hold, and the hold is
  an owner action (below).
- **Call 8 is the consolidation record's consumer set.** All seven declare it as a dependency and
  read `blocked` until call 6 drains, which is the correct rendering of a satisfied-later edge,
  not an exclusion.
- **Call 9 runs the deleted-command reword alone, for the same reason as call 6.** 83 `file_scope`
  entries over 1,628 references in 360 files, and a blanket find-and-replace is explicitly
  forbidden by the record itself — so this is per-class, per-site work that cannot be narrowed and
  must not be rushed.
- **Call 10 is the creation-gate and command-surface work, and its internal order is load-bearing.**
  The backlog-reconciliation component lands before the edge-rationale check that extends the same
  required-component list in the same contract file. The `/todo` consolidation lands before
  `/orient` removes `/review`, because both edit the CLAUDE.md merge source's command table. The
  consolidated evidence-discipline record (three phases over `report-format.md`,
  `plan-format.md` and `validate-artifact.sh`) sits here, as does the bounded-wait inheritance
  ruling and the criterion that depends on it.
- **Call 11 is the tail, not a leftover.** Every member's edges are satisfied by the ten calls
  above: the module-invariant pre-flag and the repo-specific-content extraction behind the
  harvest-script work, the batch-gate-deferral siting behind the whole `verify-deploy.sh` chain,
  the Lean challenge snapshot's move to plan time, the baseline-relative verification criterion,
  the plan-size-versus-cycle-budget surfacing, and the settled-user-decision route check.

**What is verified about the eleven calls above, and what is not.** Verified mechanically on
2026-11-03 against `specs/state.json`: the calls name 59 of the 60 open records, each exactly
once, with no phantom id and no duplicate; the one omission is the held books-corpus refactor,
explained below. Also verified: **for every task in every call, each of its open blockers lands
in an earlier call or in that same call** — no call depends on work queued after it. **Not
verified: admission.** Every grouping is derived from the overlap predicate and the wave table,
not from an executed admission pass, so a `MAX_TASKS` trim or a self-modifying defer could still
reshape any of them. Re-derive with `/orchestrate <batch> --dry-run` before relying on a grouping
(Standing rule 5).

**The books corpus refactor's hold stands on the version stamp alone.** Every dependency is
satisfied. The consuming repository's `books/book-convention.md` line 4 reads `0.1.0-pre`, reset
by owner ruling of 2026-10-06 because the review it waited on had shipped prematurely. Lift when
that line reads `0.1.0` — owner action, never an agent's. Nothing depends on it, so parking it
parks no other work.

**One coarse declaration worth narrowing before its call runs**: the mis-sited-records migration
declares `specs/state.json` and `specs/TODO.md` (call 3), which every task in the system writes
and which therefore overlap everything, forcing spurious serialization. The three broad records'
declarations are a different case and are not narrowable — see Settled decision 19.

**An edge onto an archived task number is satisfied, not a block.** Such edges resolve as *archived
(satisfied)* in `orchestrate-predispatch-review.sh`. The hazard is a hand-derived count mistaking
them for blockers — which is why the counts here are generated, not transcribed.

## Open work

**Core agent system (22)**
```
313 blocked:328,387,401  Advisory lint for hand-authored /orchestrate batch proposals in ROADMAP....
338 blocked:275     sweep_task_support_file_tracked_or_ignored
360 blocked:328,385,407,428,446  Evidence discipline for report and plan artifacts, in three phas...
369 blocked:29      Orphan sweep for deployed entries removed from the source store: the deploy a...
421 blocked:402     retarget_distill_meta_as_evidence_consumer
431 blocked:328     Record the gate-enforced verbatim-duplication exclusion class as durable agen...
435 blocked:407     Reword architectural and phase-versus-command prose naming the three deleted ...
436 blocked:313,458,459  Add the /orient executive-orientation command with a read-only scout age...
439 blocked:431     audit_cross_extension_bounded_wait_duplication
444 blocked:445     retire_routing_agents_hard_for_hard_contracts
445 blocked:414,415 gate8_expected_vs_new_failure_distinction
448 blocked:328,418 Contain the regression-anchor source-store mutation so a concurrent session c...
452 blocked:328,360,385,435,446,448  Require a verification criterion over a repo-wide gate with ...
454 blocked:328,435,439  State the result-needed-this-turn criterion for choosing the foreground ...
458 blocked:459     Consolidate the duplicated /todo implementation
282 ready           Write-time PreToolUse hook blocking record-versioning language, registered ba...
328 ready           systematic_script_and_test_corpus_efficiency
410 ready           Close the result-sharing replay hole in lake-build-guard.sh: gate sharing on ...
423 ready           Resolve test-verify-deploy-context-budget.sh's eager-load baseline drift (mea...
429 ready           script_inventory_undercounts_untracked_files
456 ready           tag_version_gate_unpassable_for_private_manifest
459 ready           Design cross-record traceability; verdict on CHANGE_LOG retirement
```

**Extensions (6)**
```
342 HOLD            Refactor the books extension's context corpus against the settled convention:...
29 blocked:22       Generate .mcp.json from extension manifests, then register obsidian-memory th...
384 blocked:383     Adjudicate whether a books reconciliation postflight lifecycle hook is warran...
457 blocked:446,455 Repo-specific content has leaked into the shared agent-system source store
383 ready           Add a /reconcile command to the books extension: aggregate docs-stage.sh and ...
408 ready           Gate the formal extension's mandatory Mathlib-lookup step on an actual Lean t...
```

**Literature (2)**
```
453 blocked:328     Carry the degraded-retrieval signal into the zero-result case, where the brie...
437 ready           Repair the Zotero sqlite-reconstruction export path: lost CSL fields and a sh...
```

**Neovim (1)**
```
22 ready            Freeze .opencode: silence fragment validation spam and record the frozen-mirr...
```

**File scope lifecycle (3)**
```
430 blocked:428     Feed observed-but-undeclared implement paths back into a task declared file_s...
446 blocked:328,385,407,430  Close the plan-to-file_scope reconciliation gap and make a containme...
455 blocked:328,435,446,448  Pre-flag the predictable first-run module-invariant failures that wi...
```

**Lean extension (6)**
```
398 blocked:397     Record that a grep for dependents misses rw-site definitional unfolding, and ...
399 blocked:398     Record three measured lean4 gotchas: IO-forced timing harnesses, docstring/se...
451 blocked:385,420,435  Take the Lean Challenge snapshot in the plan phase, where it is still me...
385 ready           Define the sanctioned shape for a lean4-typed plan that commits to no theorem...
397 ready           Require a lean research report's recommended compiled artifact to be compile-...
412 ready           lean_tier_vocabulary_to_build_scope_mapping
```

**Orchestrator (11)**
```
274 blocked:275     Next-admissible-batch suggestion and alternatives-on-conflict, both computed ...
312 blocked:282     Backlog reconciliation as a required task-creation component: compare every p...
378 blocked:274     Resolve the reviser-agent handoff contract contradiction between skill-orches...
387 blocked:378     Teach the batch admission gate that a whole-tree regeneration phase is an imp...
402 blocked:391     Conclusion stage Step 4c allocates no task number and creates no task directo...
407 blocked:378,387 Derive a task's next artifact round from its existing artifacts instead of de...
409 blocked:378,387,401,407  Advise at admission when a task's declared file_scope already holds ...
428 blocked:378     Enforce and detect planner-agent terminal return-meta write
449 blocked:328,360,407,414,444,445,446,448  Site the Batch Gate Deferral directive where it is r...
450 blocked:274,275,328,360,378,407,420,435,448,449  Require a settled user-decision route to nam...
275 ready           Per-repo orchestration queue: registered, live, archived on finish, and consu...
```

**Agent system (9)**
```
390 blocked:391     Migrate seven mis-sited agent-system tasks out of BimodalLogic and retire one...
391 blocked:369     Close the target_root authoring hole that files agent-system tasks into the w...
401 blocked:387     Two repositories file against one source store with no cross-repo overlap or ...
415 blocked:414     Record exact-pid process checking as a parallelism-safety suite-authoring sta...
418 blocked:415,419 Make the lint-fixture-test family subject resolution explicit and self-declaring
419 blocked:275     Extend the state-writer boundary lint to the Python JSON re-serialization cha...
420 blocked:409,418 Surface a plan-size versus per-run cycle-budget mismatch before a run hits th...
438 blocked:312,313,401,446,458  Dependency edges conflate semantic and serialization rationale, ...
414 ready           Enforce the gate verdict-line extraction contract mechanically
```

## Checks before and after every call

- `orchestrate-cycle-plan.sh --dry-run --state-file specs/state.json <tasks>` — **space-separated**.
  Admits what you expect; `md5sum specs/state.json` unchanged. Research and plan dispatches are
  exempt from the self-modifying defer, so overlap only serializes at implement time.
- `validate-state.sh --deep` — measure it *before* your work too; the warning count is the
  baseline you compare against. Today's baseline is in Gate state above: 22/11/0.
- `tests/run-all.sh --jobs 4` — read the failure roster and the `EXPECTED`/`NEW` split, not the
  tally; read the exit code directly, never through `tail`/`head`. `--fail-on-new` makes it a gate.
  `--only SUITE[,SUITE]` narrows it — opt-in, and never a substitute for the final gate.
- `verify-deploy.sh --skip-slow` — measure *before* your work as well as after, and compare. A
  standing red is not permission to ignore a new one. **Do not run it concurrently with the shell
  battery**: four of the six reds in this page's own 2026-11-03 measurement are gate timeouts
  caused by exactly that, and a contended run cannot distinguish a slow gate from a failing one.
  A self-modifying task is not finished until `.claude/` is resynced, and a resync whose verify is
  red is reported, not silently accepted.
- **A source-store commit without a resync is itself a red gate** — `check-extension-docs.sh`
  reports it as `deployed script content drift`, and Gate 5 reports it as missing or
  content-differing files. Both are live on this page's own measurement.
- **A completion postflight refused with exit 6 self-clears on the next cycle's redeploy
  checkpoint** — observed working on 2026-10-09, where the checkpoint deployed and promoted the
  refused task without intervention. The residual limit: the promotion pass only considers the
  current invocation's own `task_numbers`, so a task refused in one run is invisible to any later
  run that does not re-name it. `reconcile-task-status.sh <N> <session>` promotes a stranded task
  by hand — but only once the source store is actually fresh, and a *live* dispatch editing the
  source store keeps it stale. Every self-modifying task pays one extra cycle for this by
  construction.
- **To tell a working dispatch from a stranded one, read artifact mtimes and live child processes.**
  Absence of `.orchestrator-handoff.json` is NOT a stall signal — the research phase never writes
  one in any mode. A long quiet stretch during a final phase is usually the full gate.
- **Verify a settings-merge change against a real stale deploy, not a synthetic fixture.** A
  fixture reconstructed from memory cannot show the duplicate-append shape that an actual
  install-once file in the field carries.
- **An edge added or removed by hand goes through `state-write.sh`, and its acyclicity is
  confirmed by `validate-state.sh --deep` afterwards.** `update-task-status.sh --depends-on-add`
  cannot reach a `not_started` task — re-confirmed by direct test on 2026-11-03 — which is most of
  the backlog. Do not reach for the flag first and conclude the edge is impossible.

## Settled decisions (do not re-litigate)

1. **Batch of one.** One engine; single-task is a batch of one. Team mode deleted. Hard mode kept
   in full, per-invocation.
2. **The orchestrator never asks and never decides.** Only an agent-surfaced `user_decision` reaches
   the user, once, at cycle end. A `blocking: false` decision proceeds on the agent's recommendation
   and is surfaced, not prompted.
3. **Research-first is the default** for a fresh task; `--fast` restores planner-first.
4. **`--dry-run` prints the plan it would dispatch.** There is no separate dry-run report.
5. **No fixed consumer validation gates.** The checks above are recommended, not blocking.
6. **A linear chain of small tasks serializing on one file is one task with phases.** Apply at
   creation time — and when it was not applied at creation time, apply it late: the evidence-discipline
   record is three folded phases over `report-format.md`, `plan-format.md` and
   `validate-artifact.sh` for exactly this reason.
7. **`file_scope` warnings are live input, not noise.** In-batch collisions block; cross-batch ones
   are advisory. The blocking half is correct and is not weakened by decision 17 — an *unordered*
   overlapping pair would share a wave and write concurrently. The remedy is to order the pair with
   an edge, not to drop one from the batch.
8. **Rule before mechanism** for the vimtex hazard. Re-file a mechanism task only if the rule proves
   insufficient.
9. **Skeleton plans terminate through the completion-claim gate.** No `pr_ready` routing outside
   `type=pr`.
10. **No third automated deploy-trigger site.** The sanctioned count stays at exactly two. The
    mechanically authoritative pair is `command-gate-out.sh` + `orchestrate-cycle-plan.sh`, per
    `test-lint-deploy-caller-wrap.sh`. `regeneration-is-manual-only.md` names
    `orchestrate-cycle-plan.sh`'s Inter-Cycle Redeploy Checkpoint as the multi-task path's
    sanctioned site.
11. **One grant mechanism.** A blocked git action is authorized by one single-use token bound to
    action, remote, branch and sha, minted only where the harness can prove the user typed it.
    Nothing the model can write is a grant. PR/MR creation and `/merge` stay user-only.
12. **A grant may authorize a plain push of the default branch** (user ruling). Every force form on
    the default branch, bare `--force` anywhere, and all bulk or deletion refspecs stay categorically
    excluded, checked before any grant lookup.
13. **`known-failures.txt` is the only known-failing list.** Advisory by construction; it never
    changes which suites run. Never keep a prose copy elsewhere — that is the drift mechanism. A
    `needs-owner` row is a known gap, not an accepted steady state, and gets a follow-up task.
    **It covers shell suites only**; plenary Lua specs have no known-failing baseline at all.
14. **One shared working tree, always.** Per-dispatch `git worktree` isolation is removed, not
    narrowed. Concurrency safety rests on declared `file_scope`, dependency edges and the five
    contention inputs. Build contention is closed by refusing to co-schedule two build-heavy
    implement tasks in one cycle. Cost was not the reason for removal and must not be cited as it.
    Record: `specs/decisions/worktree-isolation-removal-verdict.md`.
15. **Gate 8's deployed-tree coverage is knowingly reduced** (accepted on wall-clock grounds). The
    redeploy checkpoint runs `--skip-slow`, so the core suites resolving their subject from the
    *deployed* tree are not verified against a fresh deploy — measured at 52 of 91 narrow core
    suites (57.1%), classified rather than excluded. Narrower fix: the consolidation record.
16. **A systemic cost is filed as one standing task against a probe's output, not a stream of point
    defects.** Duplication, dead code and slow tests never break anything, so defect-driven intake
    cannot see them. The consolidation record is the standing consumer of `script-inventory.sh`.
17. **A batch may carry dependency edges between its own members, and an unordered territory overlap
    is resolved by adding the edge, not by separating the pair** (owner ruling). Serializing to
    width 1 is a correct outcome: the property defended is collision visibility and correct ordering,
    never wall-clock. Binding consequences: a **"never with" note is not an acceptable rendering** of
    an overlap — pick an order and record the edge; and a bare exclusion must never stand in for an
    edge that was simply not added. **Two carve-outs.** (a) *Owner-blocked predecessor*: if the
    would-be predecessor cannot progress — held, owner-gated, or `PARTIAL` behind something no task
    can unblock — separation is correct and the reason is stated. Check what depends on the target
    before edging onto it. (b) *Breadth*: a coarse shared path can make rule 1 demand a group larger
    than `MAX_TASKS=8`, which the cap then silently trims; there, narrow the `file_scope` instead —
    except where decision 19 applies. The doctrine is carried at the point of use.
18. **A settings drift is repaired by making the merge self-healing, never by a migration script**
    (owner ruling, 2026-10-07). Hook entries are deduplicated by *identity* — the `hooks/NAME.sh` the
    command invokes, plus its event and type — so a changed command string is **replaced in place**
    rather than appended beside the stale one. Implemented in `merge.lua`'s `hook_identity` /
    `find_hook_match`, with a **mandatory carve-out**: a command not recognizable as a
    `.claude/hooks/*.sh` invocation is never matched, moved or deduped, so a hand-written hook
    survives untouched. Two load-bearing consequences: (a) **a hook registration must appear in a
    fragment surface** (`merge-sources/settings-hooks.json` or an extension's fragment), because a
    registration living only in install-once `root-files/settings.json` is visited by no resync and
    is unreachable by any future correction; (b) the by-hand repair for a deploy predating the fix is
    `rm .claude/settings.json` followed by a reload — install-once copies fresh when the target is
    **absent**, whereas `deploy-headless.sh --wipe` restores its own snapshot as the merge base and
    reintroduces the staleness.
19. **A whole-corpus record runs alone, and its coarse `file_scope` is not a defect to be narrowed**
    (owner ruling, 2026-11-03). Where a record's declared territory is directory roots spanning the
    corpus because the work genuinely spans the corpus — a top-to-bottom consolidation, a per-site
    reword of 1,628 references across 360 files — decision 17(b)'s "narrow the `file_scope`
    instead" has nothing to narrow to. Such a record leads its own call. Batching it serializes its
    partners to no purpose, and the overlap warnings it generates are correct output, not noise:
    they are what tells a reader the record is a bottleneck. Precedent: the dead-command lint ran
    this way deliberately and its scope claim was never the problem.
20. **A near-duplicate record is folded, not merely ordered** (owner ruling, 2026-11-03). When two
    records discharge through the same action, the survivor absorbs the other's text **verbatim**
    rather than in summary, every edge pointing at the folded record is re-pointed at the survivor
    **before** it is archived, and the folded record carries a note naming the survivor and the
    grounds. A record whose obligation a landed artifact already discharges is abandoned with that
    artifact cited, not left open as a reminder. Ordering two records that would write the same
    text twice is the failure mode this rules out.

## Standing rules

1. **Agent-system defects get filed here.** A fix in a consuming repo's `.claude/` is wiped on reload.
2. **`.claude/**` is a deploy artifact.** Edit the source store under `agent-system/extensions/**`,
   then resync. Note `settings.json` and `settings.local.json` are **install-once** — copied only
   when absent, never overwritten by a resync. A source edit to either reaches fresh deploys only;
   for hook registrations, put them in a fragment surface so the merge can reach them (Settled
   decision 18).
3. **`TODO.md` is generated from `state.json`.** Edit `description` via `state-write.sh`, then
   `generate-todo.sh`. A hand edit to `TODO.md` is wiped by the next regeneration. The same applies
   to this file's own counts and rosters — generate them with `roadmap-integration.sh`.
4. **Propose, then apply, across repos.**
5. **Verify by execution, not by reading.** Every number here was measured the day it was written;
   re-measure before acting on it. Figures explicitly marked *CARRIED-UNVERIFIED* were not
   re-measured on the stated date and must be re-derived before they are relied on.
6. **The lead never reads a report, plan, summary, description or context file during the loop.**
7. **This file describes the current plan only.** No revision history, no pass numbers.
8. **A scope cut justified by an unverified premise is not a scope cut.** Two were taken and
   reversed on 2026-10-07 — "a reload repairs deployed repos" and "the fragment merge reaches every
   registration" — each disproved by a field test minutes later. Test the premise before dropping
   the work it would make unnecessary.
9. **A dispatch premise can go stale between task creation and dispatch.** Measured on
   2026-10-08: three of five research dispatches found their own premise partly wrong. Measured
   again on 2026-11-03, where the eager-load-drift record's entire figure pair had moved out from
   under it and a gate it was filed against now passes. Re-derive the premise first; report the
   correction rather than implementing against it.
10. **A redundancy census is re-derived, never remembered.** The unordered-overlap count, the
    dependents-of count and the duplicate-subject reading all change with every edge added and
    every record closed. Compute them from `specs/state.json` plus
    `scripts/lib/file-scope-overlap.sh` with transitive dependency closure as the ordering test;
    a remembered figure is wrong by the next dispatch.

## Unfiled observations (none worth a task yet)

- **Gate 18's five new violations have no owner.** All five are fixture assertions in
  `scripts/test-state-write-concurrency.sh`, landed by the allocation-bound work and committed, and
  the lint has no exemption for an assertion against a synthetic state file. The fix is an
  exemption class in `lint-task-lookup-adoption.sh`, not a rewrite of the suite. This is the one
  item here closest to warranting a task: the gate is red today and nothing is tracking it.
- **The consolidation record's `status` under-reports its progress, and its plan is budget-infeasible
  in one invocation.** `state.json` carries `planned` while its plan shows 6 of 20 phases terminal;
  20 phases against a 5-cycle per-run budget means three or four invocations minimum. The second
  half is exactly the plan-size-versus-cycle-budget record's subject, now measured on a live plan
  rather than inferred.
- **The consolidation record declares `.claude/` in its own `file_scope`.** `.claude/` is a
  gitignored, disposable deploy artifact that Standing rule 2 forbids editing, and declaring it
  makes the record overlap literally every task in the system. Whatever the entry was meant to
  express, it is not an edit target.
- **The traceability record's `file_scope` names only its own `specs/` directory**, so it is
  invisible to overlap detection even though its verdict now gates two other records. A
  verdict-first record with no file territory is a real shape; the gap is that nothing represents
  "this record's output constrains that record's design" except a dependency edge.
- **An unowned Lua spec failure**: `manifest validate should reject manifest with invalid
  merge_targets type` fails at `lua/neotex/plugins/ai/claude/extensions/manifest_spec.lua:124`
  (expected `false`, got `true`). CARRIED-UNVERIFIED from 2026-10-17. No open task addresses it, and
  `known-failures.txt` cannot carry it (shell suites only — Settled decision 13). The coverage gap
  — plenary Lua specs have no known-failing baseline at all — is the more significant half.
- **`update-task-status.sh --depends-on-add` cannot reach a `not_started` task**, which is most
  of the backlog. Re-confirmed by direct test on 2026-11-03: the flag's STATUS-NO-OP RESTRICTION
  requires `operation:target_status` to resolve to the task's current status, and `map_status()`
  has no pair resolving to `not_started`, so it refuses with exit 1 naming the condition.
  Compounding it: there is still no edge-REMOVAL flag at all. Every edge added in this page's own
  reconciliation went through `state-write.sh` instead, with acyclicity confirmed afterwards by
  `validate-state.sh --deep` — the path Settled decision 17 already sanctions. Worth a task: a
  `map_status()` arm for `not_started` plus an explicit edge-only add/remove operation.
- **Neither `/todo` nor `/review` wires the roadmap generator's modes to its own command.** The
  generator's stage-based layout handling and the conclusion stage's own caller naming are done;
  the `/todo`→`--prune` and `/review`→`--regenerate` wiring itself is still nobody's. Both modes
  are still run by hand. Note this interacts with the `/orient` record, which retires `/review`
  altogether — whatever wires `--regenerate` should wire it to the surviving command.
- **13 of 14 phase-heading-owning implementation agents never invoke `update-phase-status.sh`**, so
  the heartbeat reaches them only because it is pulsed at the dispatch boundary instead. An
  advisory lint (Check I) records the residual per-agent gap; the per-extension migration is an
  open follow-up. CARRIED-UNVERIFIED from 2026-10-17.
- **A dispatched agent can end its turn with a backgrounded command still pending**, leaving the
  dispatch stopped with no handoff and no return metadata. Nothing auto-detects "stopped without
  returns": the stall re-prompt path triggers off a postflight `failed` verdict, so reaching it
  costs the task a recorded failure first. **Two states that look alike and are not**: an agent
  *waiting on its own live background child* still takes tool rounds, so a direct message does
  drain and does recover it. A *stranded* agent with no live child takes no rounds, so a message
  cannot reach it; recovery there is stop the agent, run postflight, then re-dispatch at the same
  `dispatch_seq`. Check for a live child before choosing. Measured at 2 of 8 implement dispatches
  on one eight-task run (2026-10-17, CARRIED-UNVERIFIED since), both recovered on one re-prompt
  each that forbade background waits. Frequency that high is why the re-prompt should be automatic,
  not operator-driven — and the 26-day stranding recorded under Gate state is the same failure
  class surviving far longer than a run: there, the agent *did* write its terminal return metadata
  and the postflight simply never consumed it, which no re-prompt would have caught. See
  `context/patterns/task-lock.md`'s "`held-live` Interpretation Is Context-Dependent, Not
  Universal" subsection for the mechanical detector (`dispatch-strand-probe.sh`) and its three
  consumers.
- **9 open tasks carry a literal-null `title`** (measured 2026-11-03), so renderers describe them
  from `project_name`. The sharper half is that `orchestrate-predispatch-review.sh` Class B has
  been observed reporting *0 findings* for a task whose `title` was literal null — so the gap is
  not confined to an absent key. Re-read Class B's predicate before filing against it.
- **`TODO.md`'s tree view strips punctuation from titles.** The underscore-deleting half is fixed
  (`parenttask` → `parent_task`); the broader punctuation stripping remains.
- **A rendered `**Goal**:` line in `TODO.md` cannot survive regeneration** and fails validation while
  present. `generate-task-order.sh --goal` writes it; `generate-todo.sh` drops it and never reads
  `active_goal`, so the displayed goal is permanently blank.
- **Nothing represents a cross-repository prerequisite.** A task gated on another repo reads `ready`
  here and can only be caught by reading its description. The books corpus refactor is in exactly
  that state today — its hold rests on a version stamp in a consuming repository — so the gap is
  live, not latent.
- **No mechanism prevents a vault operation from leaving edges pointing at renumbered tasks**, and
  `validate-state.sh` does not check it. `parent_task` and `dependencies` are both handled in the
  live renumber path (`commands/todo.md` Step 5.7.7); nothing validates the result afterwards.
- `plan-file-scope-harvest.sh` silently under-harvests on at least three plan shapes, each
  measured: a Territory Contract table instead of the field; a trailing italic on the field label
  (`**Files to modify** *(as executed ...)*:`); and a glob entry (`extensions/*/agents/*.md`). A
  2026-10-17 repair of one plan moved it from 56 to 123 harvested paths. Every miss is silent, and
  an under-harvested `file_scope` is what makes a phase commit drop real work.
- **`roadmap-integration.sh --prune` misparses a Run line whose trailing comment is separated by
  exactly two spaces**, reading the final id as `423#bookkeepingdefectsobservedinliveruns` and
  leaving the whole line unchanged with a warning. Widening the separator to three spaces makes
  the same line parse correctly, which locates the bug at a `>=3`-space separator assumption.
  Every Run line in this file is authored with three spaces for that reason. The failure is
  fail-safe in this direction (retain, not drop) and it warns loudly, but it silently depends on
  authored whitespace. Normalize the separator *and* fix the predicate; a fail-safe parse of a
  machine-maintained line is still a parse that needs the author's cooperation.
- The write-time task-reference hook fires on files in the session scratchpad; its path filter could
  exempt `/tmp/**`.
- **A loosely-scoped `subagent_type: "fork"` inherits the parent's entire task mandate** and can
  autonomously complete unrelated inherited work rather than the narrow action requested. Mitigation
  landed in `core/docs/fork-patterns.md`; recorded because the failure mode is easy to re-introduce.
