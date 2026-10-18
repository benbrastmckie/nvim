# Roadmap

*Forward-only: what remains, in what order, and the checks that gate each step. Finished work is
removed, not archived here — it lives in git history, task summaries and `specs/archive/`. Task
detail lives in `specs/TODO.md`; this file carries only ordering, gates and rulings. Every figure
carries the date it was measured; a figure without one is generated from `specs/state.json`.
Re-derive before relying on any of them (Standing rule 5).*

## Goal

`/orchestrate` is the only lifecycle entry point, and the orchestrator is token-cheap by
construction: it delegates, reads back compact verdicts, and asks the user only when a decision is
genuinely the user's.

`MAX_TASKS` is 8, enforced in `commands/orchestrate.md`. `orchestrate-cycle-plan.sh` itself accepts
any count, so a dry-run over more than 8 is not evidence a call will run them.

**57 open tasks** (measured 2026-10-17): queued across the five numbered batches below, the two
priority calls ahead of them, and the coverage appendix; two mid-dispatch, one on hold. **21
completed and awaiting `/todo` archival** — large enough that the archival pass is now the
cheapest next action, and large enough that a hand-read of `## Open work` will mislead until it
runs.
Both counts and every wave membership are derived, never transcribed:
`generate-task-order.sh --print` for ordering, `roadmap-integration.sh --regenerate`/`--prune`
for the `## Open work` roster and the coverage appendix. A hand-maintained count here goes stale
within one run.

## Gate state

- **`known-failures.txt` carries one row**: `test-run-all-parallel.sh`, intermittent, accepted on
  its own rejected-alternatives record. It is advisory by construction and never changes which
  suites run (Settled decision 13).
- **Gate 22 is the shellcheck gate; Gate 23 is live too.** `lint-shellcheck.sh` lints every
  `*.sh` under `agent-system/extensions/` at `-S warning` (zero findings across 388 scripts as of
  2026-10-15, and an unresolvable `shellcheck` binary is a named exit 70, never a silent skip).
  It now runs a one-process-per-file worker pool, `SHELLCHECK_JOBS` defaulting to 8: measured
  39.5-45.5s against 76.8-136.4s forced sequential, a 1.8-3x win, with the finding set proven
  byte-identical to the pre-parallelization script on both the real corpus and a seeded SC2155
  fixture. Gate 23 is `lint-directory-pathspec-boundary.sh --verbose`. The registry carries 23
  gates; the next numbered gate to be added is **24**.
- **Gate 8's exit code still reads one intermittent red as a failed gate**: it consumes
  `run-all.sh`'s bare exit code rather than the `EXPECTED`/`NEW` split (Settled decision 13).
- **A full `verify-deploy.sh` fits inside a 540s bounded wait only on a quiet host, and a batch
  gate stage should not be budgeted that way.** 540s held on an idle host (measured 2026-10-15,
  load 1.58, explicit TARGET, no `--skip-slow`) with gate-level concurrency and shellcheck
  parallelization in place. Every measurement taken under real contention has exceeded it: 790s
  mid-task, over 650s on a run that needed two retries, and **1632s measured 2026-10-17** for
  the once-per-invocation batch gate closing an eight-task run — three consecutive bounded waits
  before the writer exited. Budget a batch-level gate at three bounded waits, not one; 540s is a
  property of a quiet host, not of the gate set.
- **That same run returned 0 findings, clean.** Read it with its two qualifications: it was taken
  *after* a redeploy, and a pre-redeploy run earlier the same day returned 5 of 37 checks failed,
  all attributed to accumulating un-redeployed source-store drift rather than to any gate's
  subject. The gate20 eager-load overage (~988B over baseline) that the earlier figure included
  did not reproduce post-redeploy; it is tracked independently by task 417 and is not assumed
  resolved.
- **`run-all.sh`'s full battery hits 4 pre-existing test-infrastructure bugs** unrelated to any
  open task's subject, evidenced in the shellcheck-gate plan's `#### Reasoned Exclusions` record.
  Expect them; they are not yours.
- **Consumer repos were all 8 STALE at last measurement (2026-10-03)**, except
  `Philosophy/Papers/PossibleWorlds`, repaired by hand on 2026-10-07. If work touches a consumer,
  run `check-consumer-freshness.sh` here and `deploy-headless.sh` **there** first; this repo never
  pushes into a consumer.
- **`--skip-slow` hides real failures** — `test-runtime-file-tracking.sh` Case 3 and Gate 8 both
  go unseen, so a `--skip-slow` pass is not evidence the doc-sync pins hold. Measured instance of
  Settled decision 15.
- Every figure above was measured on the date stated. Re-derive before relying on it
  (Standing rule 5).

## Next

Each call is a single `/orchestrate` invocation, and batching is the default, not a throughput
optimization: a collision is only checkable by the admission layers when both tasks are in the
same invocation, so related tasks are batched even when intra-batch edges serialize them to
width 1 (Settled decision 17). The Run lines below are authored groupings; the task counts and
the coverage appendix under them are generated, so read those for current totals rather than
transcribing a count into this paragraph. Overlap groupings come
from `scripts/lib/file-scope-overlap.sh`'s own overlap predicate over every non-terminal
`file_scope`, never hand-guessed; waves come from `generate-task-order.sh --print`. The batch
membership is authored, and the ordering principle is stated once: **a task that gates every
other task's verification outranks a task that gates only its own subject.**

```
/orchestrate 275, 338, 274, 378, 387, 313, 328   # orchestrate machinery, one chain
/orchestrate 22,29,369,391,390,400,402,421       # loader chain, task siting, then the evidence consumer
/orchestrate 397,398,399,385,412,408,410         # lean research contract, tier mapping, build guard
/orchestrate 282,312,360,383,384,401,407,409     # record-versioning, marks, books, cross-repo, admission
/orchestrate 413,414,415,416,417,418,419,420     # gate-framework follow-ups -- run LAST, after 421
```

**Two priority calls run ahead of the numbered batches below.** The numbered groupings were
authored before the 422-439 defect and follow-up cluster existed, so those tasks reach this file
only through the generated coverage appendix — which is now eight wide and therefore a full call's
worth of work the authored groupings do not account for. Until the groupings are re-derived over
every non-terminal `file_scope`, dispatch these first:

```
/orchestrate 434                              # dead-command lint; coarse file_scope, so solo
/orchestrate 425, 400, 427, 428, 426, 422, 423   # bookkeeping defects observed in live runs
```

- **434 runs solo deliberately.** Its `file_scope` is 23 entries of directory roots
  (`core/context/`, `core/docs/`, `core/agents/`, `books/agents/`), which overlaps most of the
  backlog; batching it would serialize its partners to no purpose. It is also first because its
  lint is the enumerator for 435's remaining work.
- **425's ordering constraint is discharged, and the defect it names is now observed, not
  predicted.** The containment chokepoint landed first, and the feared coupling did not
  materialize: it was built drop-and-warn and fail-open, so exit 7 never refuses and no
  postflight commit was blocked. What remains is the narrower original defect — engine-written
  state files are still dropped from postflight commits as excursions. Measured 2026-10-17: a
  postflight dropped `specs/TODO.md` on a real run, recovered only because a later regeneration
  committed it. 425 is now a correctness-of-staging task with no ordering prerequisite.
- **Three further edges are owed before that second call is dispatched**, each an unordered
  territory overlap that Settled decision 17 requires be ordered rather than separated:
  `425 -> 426` on `orchestrate-cycle-postflight.sh`, `427 -> 426` on `handoff-schema.md`, and
  `422 -> 423` on `known-failures.txt`.
- **428 declares no `file_scope` at all**, so its collisions are invisible to the admission
  layers; declare one before it is batched.

**Dry-run state: no batch below is dry-run verified.** Every grouping here is derived from the
overlap predicate, not from an executed admission pass. Re-derive with
`/orchestrate <batch> --dry-run` before relying on any grouping (Standing rule 5).

Why these batches:

- **Batch 1 is a single chain, and that is the correct shape.** `{275,328} -> {274,338} -> 378
  -> 387 -> 313`, ordering real overlaps on `orchestrator-runtime-files.md` (275/338),
  `skill-orchestrate/SKILL.md` (274/275), `orchestrate-cycle-plan.sh` (378/387) and
  `file-footprint-overlap.md` (313/387). The head edge onto `task-lock.sh` is already satisfied,
  so 275 and 328 open the batch. Width 1 throughout is the defended property, not a failure.

- **Batch 2 is the loader chain with the task-bookkeeping work hung off its tail.** `22 -> 29 ->
  369 -> 391 -> 390` is pre-existing on `init.lua`/`merge.lua` and then on
  `source-store-deploy-boundary-narrative.md`, so the authoring hole closes before the
  mis-sited records are migrated through it. 400 joins at the head (its only edge is onto a
  task completing in flight) and 402 at the tail, where both of its edges — 391 for
  `conclusion-stage.md`, which the two genuinely share, and 400 — are already satisfied.
  Waves: `22,400` -> `29` -> `369` -> `391` -> `390,402`.

- **Batch 3 fills with topic cohesion, not width.** 397 -> 398 -> 399 is a pre-existing chain on
  `lean/index-entries.json`; 385 is territory-clean but shares `topic: lean-extension`, so
  rule 2 puts it in this batch ahead of any off-topic filler.

- **Batch 4 carries what nothing else forces.** 282 -> 312 and 383 -> 384 are pre-existing
  edges; 360 is territory-clean filler. 401 sits here because its single edge is onto 387,
  which batch 1 drains first — it reads `blocked` until then, which is the correct rendering of
  a satisfied-later edge, not an exclusion.

- **Batch 5 is the gate-framework follow-up set, and it must not run before the consolidation
  consumer exists.** All eight are children of the gate-framework refactor, and they are the
  exact population most at risk of being worked blindly: five of them were proposed again by a
  conclusion stage that could not see they already existed. Task 421 retargets `/distill --meta`
  into a dedup-aware, capped, consolidation-biased consumer; running batch 5 before 421 lands
  forfeits the dedup and the cap that make this set safe to drain. Queue it last deliberately,
  and reassess membership after 421 rather than dispatching it as authored here.

**One reasoned non-grouping, not a bare exclusion**: 282 and 313 both declare
`agent-system/extensions/core/manifest.json`, so they are left in different batches (4 and 1). A
registration manifest is the narrowness qualifier's own measured exemplar of a coarse path that
does not, by itself, make every task touching it one mandatory group.

**One coarse declaration worth narrowing before its batch runs**: 390's `specs/state.json` +
`specs/TODO.md` entries (batch 2), which every task in the system writes and which therefore
overlap everything, forcing spurious serialization.

**342's hold**: every dependency is satisfied; the hold stands on the version stamp alone. The
consuming repository's `books/book-convention.md` line 4 reads `0.1.0-pre`, reset by owner ruling of
2026-10-06 because the review it waited on had shipped prematurely. Lift when that line reads
`0.1.0` — owner action, never an agent's. Nothing depends on 342, so queuing it parks no other work.

**An edge onto an archived task number is satisfied, not a block.** Such edges resolve as *archived
(satisfied)* in `orchestrate-predispatch-review.sh`. The hazard is a hand-derived count mistaking
them for blockers — which is why the counts above are generated, not transcribed.
**Coverage appendix (uncovered tasks)**:
```
/orchestrate 429,430,432,433,436,437,438,439
/orchestrate 443,444,445
```

## Open work

**Core agent system (19)**
```
313 blocked:328,387 Advisory lint for hand-authored /orchestrate batch proposals in ROADMAP.md ph...
338 blocked:275     sweep_task_support_file_tracked_or_ignored
369 blocked:29      Orphan sweep for deployed entries removed from the source store: the deploy a...
421 blocked:402     retarget_distill_meta_as_evidence_consumer
431 blocked:328     Record the gate-enforced verbatim-duplication exclusion class as durable agen...
435 blocked:407     Reword architectural and phase-versus-command prose naming the three deleted ...
282 ready           Write-time PreToolUse hook blocking record-versioning language, registered ba...
328 ready           systematic_script_and_test_corpus_efficiency
360 ready           Validate that every CARRIED-UNVERIFIED mark names a source, as an advisory-on...
410 ready           Close the result-sharing replay hole in lake-build-guard.sh: gate sharing on ...
423 ready           Resolve test-verify-deploy-context-budget.sh's eager-load baseline drift (mea...
429 ready           script_inventory_undercounts_untracked_files
432 ready           reconcile_inverted_gate_cost_dependency_edge
433 ready           revise_plan_for_markdown_corpus_phases
436 ready           Add the /orient executive-orientation command with a read-only scout agent, a...
439 ready           audit_cross_extension_bounded_wait_duplication
443 ready           Evaluate resolving task-ref-ok markers against the full target file in valida...
444 ready           retire_routing_agents_hard_for_hard_contracts
445 ready           gate8_expected_vs_new_failure_distinction
```

**Extensions (5)**
```
342 HOLD            Refactor the books extension's context corpus against the settled convention:...
29 blocked:22       Generate .mcp.json from extension manifests, then register obsidian-memory th...
384 blocked:383     Adjudicate whether a books reconciliation postflight lifecycle hook is warran...
383 ready           Add a /reconcile command to the books extension: aggregate docs-stage.sh and ...
408 ready           Gate the formal extension's mandatory Mathlib-lookup step on an actual Lean t...
```

**Literature (1)**
```
437 ready           Repair the Zotero sqlite-reconstruction export path: lost CSL fields and a sh...
```

**Neovim (1)**
```
22 ready            Freeze .opencode: silence fragment validation spam and record the frozen-mirr...
```

**File scope lifecycle (1)**
```
430 ready           Feed observed-but-undeclared implement paths back into a task declar...
```

**Lean extension (5)**
```
398 blocked:397     Record that a grep for dependents misses rw-site definitional unfolding, and ...
399 blocked:398     Record three measured lean4 gotchas: IO-forced timing harnesses, docstring/se...
385 ready           Define the sanctioned shape for a lean4-typed plan that commits to no theorem...
397 ready           Require a lean research report's recommended compiled artifact to be compile-...
412 ready           lean_tier_vocabulary_to_build_scope_mapping
```

**Orchestrator (9)**
```
274 blocked:275     Next-admissible-batch suggestion and alternatives-on-conflict, both comp...
312 blocked:282     Backlog reconciliation as a required task-creation component: compare every p...
378 blocked:274     Resolve the reviser-agent handoff contract contradiction between skill-orches...
387 blocked:378     Teach the batch admission gate that a whole-tree regeneration phase is an imp...
402 blocked:391     Conclusion stage Step 4c allocates no task number and creates no task directo...
407 blocked:378,387 Derive a task's next artifact round from its existing artifacts instead of de...
409 blocked:378,387,401,407  Advise at admission when a task's declared file_scope already holds ...
275 ready           Per-repo orchestration queue: registered, live, archived on finish, and consu...
428 ready           Enforce and detect planner-agent terminal return-meta write
```

**Agent system (10)**
```
416 IN FLIGHT       reaim_gate_cost_model_input_scoped_invalidation
390 blocked:391     Migrate seven mis-sited agent-system tasks out of BimodalLogic and retire one...
391 blocked:369     Close the target_root authoring hole that files agent-system tasks into the w...
401 blocked:387     Two repositories file against one source store with no cross-repo overlap or ...
415 blocked:414     Record exact-pid process checking as a parallelism-safety suite-authoring sta...
418 blocked:415     Make the lint-fixture-test family subject resolution explicit and self-declaring
414 ready           Enforce the gate verdict-line extraction contract mechanically
419 ready           Extend the state-writer boundary lint to the Python JSON re-serialization cha...
420 ready           Surface a plan-size versus per-run cycle-budget mismatch before a run hits th...
438 ready           Dependency edges conflate semantic and serialization rationale, and a semanti...
```

## Checks before and after every call

- `orchestrate-cycle-plan.sh --dry-run --state-file specs/state.json <tasks>` — **space-separated**.
  Admits what you expect; `md5sum specs/state.json` unchanged. Research and plan dispatches are
  exempt from the self-modifying defer, so overlap only serializes at implement time.
- `validate-state.sh --deep` — measure it *before* your work too; the warning count is the
  baseline you compare against, and it is not carried here.
- `tests/run-all.sh --jobs 4` — read the failure roster and the `EXPECTED`/`NEW` split, not the
  tally; read the exit code directly, never through `tail`/`head`. `--fail-on-new` makes it a gate.
  `--only SUITE[,SUITE]` narrows it — opt-in, and never a substitute for the final gate.
- `verify-deploy.sh --skip-slow` — measure *before* your work as well as after, and compare. A
  standing red is not permission to ignore a new one. A self-modifying task is not finished until
  `.claude/` is resynced, and a resync whose verify is red is reported, not silently accepted.
- **A source-store commit without a resync is itself a red gate** — `check-extension-docs.sh`
  reports it as `deployed script content drift`.
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
  one in any mode. A long quiet stretch during a final phase is usually the ten-minute full gate.
- **Verify a settings-merge change against a real stale deploy, not a synthetic fixture.** A
  fixture reconstructed from memory cannot show the duplicate-append shape that an actual
  install-once file in the field carries.

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
   creation time.
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
    suites (57.1%), classified rather than excluded. Narrower fix: **328**.
16. **A systemic cost is filed as one standing task against a probe's output, not a stream of point
    defects.** Duplication, dead code and slow tests never break anything, so defect-driven intake
    cannot see them. 328 is the standing consumer of `script-inventory.sh`.
17. **A batch may carry dependency edges between its own members, and an unordered territory overlap
    is resolved by adding the edge, not by separating the pair** (owner ruling). Serializing to
    width 1 is a correct outcome: the property defended is collision visibility and correct ordering,
    never wall-clock. Binding consequences: a **"never with" note is not an acceptable rendering** of
    an overlap — pick an order and record the edge; and a bare exclusion must never stand in for an
    edge that was simply not added. **Two carve-outs.** (a) *Owner-blocked predecessor*: if the
    would-be predecessor cannot progress — held, owner-gated, or `PARTIAL` behind something no task
    can unblock — separation is correct and the reason is stated. Check what depends on the target
    before edging onto it. (b) *Breadth*: a coarse shared path can make rule 1 demand a group larger
    than `MAX_TASKS=8`, which the cap then silently trims; there, narrow the `file_scope` instead.
    The doctrine is carried at the point of use. An edge added by hand via `state-write.sh` has
    its acyclicity confirmed by `validate-state.sh --deep`.
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

## Standing rules

1. **Agent-system defects get filed here.** A fix in a consuming repo's `.claude/` is wiped on reload.
2. **`.claude/**` is a deploy artifact.** Edit the source store under `agent-system/extensions/**`,
   then resync. Note `settings.json` and `settings.local.json` are **install-once** — copied only
   when absent, never overwritten by a resync. A source edit to either reaches fresh deploys only;
   for hook registrations, put them in a fragment surface so the merge can reach them (Settled
   decision 18).
3. **`TODO.md` is generated from `state.json`.** Edit `description` via `state-write.sh`, then
   `generate-todo.sh`. A hand edit to `TODO.md` is wiped by the next regeneration. The same now
   applies to this file's own counts and rosters — generate them.
4. **Propose, then apply, across repos.**
5. **Verify by execution, not by reading.** Every number here was measured the day it was written;
   re-measure before acting on it. Figures explicitly marked *carried* were not re-measured on the
   stated date and must be re-derived before they are relied on.
6. **The lead never reads a report, plan, summary, description or context file during the loop.**
7. **This file describes the current plan only.** No revision history, no pass numbers.
8. **A scope cut justified by an unverified premise is not a scope cut.** Two were taken and
   reversed on 2026-10-07 — "a reload repairs deployed repos" and "the fragment merge reaches every
   registration" — each disproved by a field test minutes later. Test the premise before dropping
   the work it would make unnecessary.
9. **A dispatch premise can go stale between task creation and dispatch.** Measured on
   2026-10-08: three of five research dispatches found their own premise partly wrong — a named
   script already deprecated, a producer inventory over-counted, a field list matching no version
   of the live file. Re-derive the premise first; report the correction rather than implementing
   against it. A plan that re-measures and reproduces its research figures exactly (2026-10-09)
   is the cheap confirmation this rule asks for, not a redundant step.

## Unfiled observations (none worth a task yet)

- **An unowned Lua spec failure**: `manifest validate should reject manifest with invalid
  merge_targets type` fails at `lua/neotex/plugins/ai/claude/extensions/manifest_spec.lua:124`
  (expected `false`, got `true`). Confirmed pre-existing. No open task addresses it, and
  `known-failures.txt` cannot carry it (shell suites only — Settled decision 13). The coverage gap
  — plenary Lua specs have no known-failing baseline at all — is the more significant half.
- **`update-task-status.sh --depends-on-add` cannot reach a `not_started` task**, which is most
  of the backlog. Its STATUS-NO-OP RESTRICTION requires `operation:target_status` to resolve to
  the task's current status, and `map_status()` has no pair resolving to `not_started` — so the
  sanctioned edge-backfill primitive refuses (exit 1, naming the condition) for exactly the tasks
  an unordered territory overlap is most likely to involve. Compounding it: there is no
  edge-REMOVAL flag at all — `--depends-on-add` has no counterpart, so dropping an edge also goes
  through `state-write.sh` (done 2026-10-17 for one task). Hand-added and hand-removed edges have
  their acyclicity confirmed by `validate-state.sh --deep`, the path Settled decision 17 already
  sanctions. Worth a task: a `map_status()` arm for `not_started` plus an explicit edge-only
  add/remove operation.
- **Neither `/todo` nor `/review` wires the roadmap generator's modes to its own command.** The
  generator's stage-based layout handling and the conclusion stage's own caller naming are done;
  the `/todo`→`--prune` and `/review`→`--regenerate` wiring itself is still nobody's — this
  review ran `--regenerate` by hand, once, per explicit request, not as a standing wire-up. Both
  modes are still run by hand otherwise.
- **13 of 14 phase-heading-owning implementation agents never invoke `update-phase-status.sh`**, so
  the heartbeat reaches them only because it is pulsed at the dispatch boundary instead. An
  advisory lint (Check I) records the residual per-agent gap; the per-extension migration is an
  open follow-up.
- **A dispatched agent can end its turn with a backgrounded command still pending**, leaving the
  dispatch stopped with no handoff and no return metadata. Nothing auto-detects "stopped without
  returns": the stall re-prompt path triggers off a postflight `failed` verdict, so reaching it
  costs the task a recorded failure first. Observed on a `general-implementation-agent`, which
  makes it broader than the Lean-agent scope that `bounded-build-waiter.md`'s contract and
  `lint-agent-contracts.sh`'s Check K now cover. **Two states that look alike and are not**
  (measured 2026-10-15): an agent *waiting on its own live background child* still takes tool
  rounds, so a direct message does drain and does recover it — two dispatches were recovered
  that way in one run, each having finished its work but never written its handoff. A *stranded*
  agent with no live child takes no rounds, so a message cannot reach it; recovery there is stop
  the agent, run postflight, then re-dispatch at the same `dispatch_seq`. Check for a live child
  before choosing. **Re-measured 2026-10-17 across an eight-task run: two of eight implement
  dispatches stalled this way** (both `general-implementation-agent`, both having committed every
  phase but the last and written none of the three closing artifacts), and both recovered fully on
  one re-prompt each that forbade background waits. The costs are what make this worth a task
  rather than a note: each stall burned a `failed` verdict and a `HANDOFF_STALE_OR_ABSENT` defect
  row before the recovery path opened, and the postflight detector only fires because commits
  landed in the dispatch window — an agent that stalls *before* its first commit presents as an
  ordinary failure with no stall signal at all. Frequency at 2-in-8 is high enough that the
  re-prompt should be automatic, not operator-driven. See
  `context/patterns/task-lock.md`'s "`held-live` Interpretation Is Context-Dependent, Not
  Universal" subsection for the mechanical detector (`dispatch-strand-probe.sh`) and its three
  consumers.
- **10 open tasks carry a literal-null `title`** (measured 2026-10-17: 328, 338, 412, 416, 417,
  421, 429, 432, 433, 439), so renderers describe them from `project_name`. The sharper
  half is that `orchestrate-predispatch-review.sh` Class B reported *0 findings* for 328 in a
  2026-10-17 run while 328's `title` was literal null. The gap is therefore not confined to an
  absent key: a literal-null title goes unreported as well. Re-read Class B's predicate before
  filing against it.
- **`TODO.md`'s tree view strips punctuation from titles.** The underscore-deleting half is fixed
  (`parenttask` → `parent_task`); the broader punctuation stripping remains.
- **A rendered `**Goal**:` line in `TODO.md` cannot survive regeneration** and fails validation while
  present. `generate-task-order.sh --goal` writes it; `generate-todo.sh` drops it and never reads
  `active_goal`, so the displayed goal is permanently blank.
- **Nothing represents a cross-repository prerequisite.** A task gated on another repo reads `ready`
  here and can only be caught by reading its description. No open task is in that state today, so
  the gap is currently latent rather than live.
- **No mechanism prevents a vault operation from leaving edges pointing at renumbered tasks**, and
  `validate-state.sh` does not check it. `parent_task` and `dependencies` are both handled in the
  live renumber path (`commands/todo.md` Step 5.7.7); nothing validates the result afterwards.
- `plan-file-scope-harvest.sh` silently under-harvests on at least three plan shapes, each
  measured: a Territory Contract table instead of the field; a trailing italic on the field label
  (`**Files to modify** *(as executed ...)*:`); and a glob entry (`extensions/*/agents/*.md`). A
  2026-10-17 repair of one plan moved it from 56 to 123 harvested paths. Every miss is silent, and
  an under-harvested `file_scope` is what makes a phase commit drop real work.
- **`roadmap-integration.sh --prune` still misparses a Run line whose trailing comment is
  separated by exactly two spaces**, even though the task owning that misparse is closed.
  Measured 2026-10-17: `/orchestrate 425,394,...,423  # bookkeeping defects` had its final id read
  as `423#bookkeepingdefectsobservedinliveruns`, and the whole line was left unchanged with a
  warning — so a terminal task stayed in an authored batch. Widening the separator to three spaces
  made the same line parse and prune correctly, which locates the bug at a `>=3`-space separator
  assumption; every other Run line in this file happens to satisfy it. The failure is fail-safe in
  this direction (retain, not drop) and it warns loudly, but it silently depends on authored
  whitespace. Normalize the separator *and* fix the predicate; a fail-safe parse of a
  machine-maintained line is still a parse that needs the author's cooperation.
- The write-time task-reference hook fires on files in the session scratchpad; its path filter could
  exempt `/tmp/**`.
- **A loosely-scoped `subagent_type: "fork"` inherits the parent's entire task mandate** and can
  autonomously complete unrelated inherited work rather than the narrow action requested. Mitigation
  landed in `core/docs/fork-patterns.md`; recorded because the failure mode is easy to re-introduce.
