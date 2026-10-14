# Roadmap

*Forward-only: what remains, in what order, and the checks that gate each step. Finished work is
removed, not archived here — it lives in git history, task summaries and `specs/archive/`. Task
detail lives in `specs/TODO.md`; this file carries only ordering, gates and rulings. Measured
2026-10-14. Gate-state figures below carry their own inline measurement dates and were not
re-run today — only task counts, `## Open work`, and `## Next`'s batch grouping were refreshed,
the latter against the live `file_scope` overlap predicate.*

## Goal

`/orchestrate` is the only lifecycle entry point, and the orchestrator is token-cheap by
construction: it delegates, reads back compact verdicts, and asks the user only when a decision is
genuinely the user's.

`MAX_TASKS` is 8, enforced in `commands/orchestrate.md`. `orchestrate-cycle-plan.sh` itself accepts
any count, so a dry-run over more than 8 is not evidence a call will run them.

**38 open tasks** (37 dispatchable, one on hold), none completed and awaiting `/todo` archival.
Both counts and every wave membership are derived, never transcribed:
`generate-task-order.sh --print` for ordering, `roadmap-integration.sh --regenerate`/`--prune`
for the `## Open work` roster and the coverage appendix. A hand-maintained count here goes stale
within one run.

## Gate state

- **`known-failures.txt` carries one row**: `test-run-all-parallel.sh`, intermittent, accepted on
  its own rejected-alternatives record. It is advisory by construction and never changes which
  suites run (Settled decision 13).
- **Gate 22 is the shellcheck gate; Gate 23 is now live too.** `lint-shellcheck.sh` lints every
  `*.sh` under `agent-system/extensions/` at `-S warning` (zero findings across 361 scripts as of
  2026-10-09, and an unresolvable `shellcheck` binary is a named exit 70, never a silent skip).
  318 landed Gate 23 (`lint-directory-pathspec-boundary.sh --verbose`), confirmed registered in
  `verify-deploy.sh` today. The next numbered gate to be added is **24**.
- **Gate 8's exit code still reads one intermittent red as a failed gate**: it consumes
  `run-all.sh`'s bare exit code rather than the `EXPECTED`/`NEW` split (Settled decision 13).
  Budget ~10 min for a full `verify-deploy.sh`; a 540s cap gets SIGTERMed mid-run.
- **`verify-deploy.sh` carries one standing finding** (measured 2026-10-09 as a pre/post redeploy
  baseline: 1 pre-existing, 0 newly introduced). It is a real problem, not an accepted state.
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
width 1 (Settled decision 17). Six batches cover all 37 non-held open tasks. Re-derived
2026-10-14 from `scripts/lib/file-scope-overlap.sh`'s own overlap predicate over every
non-terminal `file_scope` — 31 overlapping pairs, not hand-guessed — and from the 13 serializing
edges added for this pass. Waves below come from `generate-task-order.sh --print`; the batch
membership is authored. **All six `--dry-run` verified 2026-10-14**: each admits with 0 deferred,
0 blocked and "this cycle would proceed", `md5sum specs/state.json` unchanged across all six.

```
/orchestrate 389,388,382,381,379,380,386         # substrate correctness, territory-clean
/orchestrate 393,394,395,350,359,362,376,396     # agent contracts + commit staging
/orchestrate 170,275,338,274,378,387,313,328     # orchestrate machinery, one chain
/orchestrate 397,398,399,385                     # lean research contract + gotchas
/orchestrate 22,29,369,391,390                   # extension loader, then task siting
/orchestrate 282,312,360,383,384                 # record-versioning, marks, books reconcile
```

Why these batches:

- **Batch 1 leads on essentiality, and is the only one with no internal territory to serialize.**
  All seven declare `file_scope` that provably overlaps none of the others, so wave 1 takes the
  whole batch. 389 is load-bearing for every future plan's final-phase criterion (a masked gate
  failure is indistinguishable from a real one); 388 is the same failure class in this file's own
  tooling — `prune_next_body()` silently drops an active task from the Run lines below; 382 and
  381 are each evidenced against a real consumer-repo incident. **Caveat that bites here:** 381,
  382, 388 and 389 all declare no `file_scope` at all, and in-batch absent scope is *blocking*
  (`absent_file_scope` defer), so the implement phase serializes them one per cycle regardless of
  the clean wave-1 width. `backfill-file-scope.sh` is the remedy; it is not a batching problem.
- **Batch 2 is one territory component, drained in dependency order.** 350 is the hub: it shares
  `books-implementation-agent.md` with 359, 362 and 393, and `orchestrate-cycle-postflight.sh`
  with 395. 394/395 share `git-staging-scope.md`; 376/396/393 share the Lean implementation
  agents. Waves: `393,394` -> `376,395` -> `350,396` -> `359` -> `362`. The three remaining
  substrate essentials (393, 394, 395) all land in wave 1-2, so essentiality survives the
  grouping.
- **Batch 3 is a six-wave single chain, and that is the correct shape.** `170 -> {275,328}
  -> {274,338} -> 378 -> 387 -> 313`. Five of its six edges were added this pass to order real
  overlaps: `task-lock.sh` (170/275), `orchestrator-runtime-files.md` (275/338),
  `skill-orchestrate/SKILL.md` (274/275), `orchestrate-cycle-plan.sh` (378/387) and
  `file-footprint-overlap.md` (313/387). Width 1 throughout is the defended property, not a
  failure.
- **Batch 4 fills with topic cohesion, not width.** 397 -> 398 -> 399 is a pre-existing chain on
  `lean/index-entries.json`; 385 is territory-clean but shares `topic: lean-extension`, so rule 2
  puts it in this batch ahead of any off-topic filler.
- **Batch 5 is the Lua extension-loader chain plus the siting pair.** `22 -> 29 -> 369` already
  existed on `init.lua`/`merge.lua`; 391 was edged onto 369 for
  `source-store-deploy-boundary-narrative.md`, and 390 onto 391 so the authoring hole closes
  before the seven mis-sited records are migrated through it.
- **Batch 6 carries what nothing else forces.** 282 -> 312 and 383 -> 384 are pre-existing edges;
  360 is territory-clean filler.

Two cross-batch territory cuts, both deliberate and both minimal:

- **350 shares `skill-orchestrate/SKILL.md` with 274, 275 and 378** (batch 3) while living in
  batch 2 with its four other overlaps. Keeping it with the SKILL.md clique instead would cut
  four relations rather than one.
- **376 shares `lean-research-agent.md` and `lean-research-hard-agent.md` with 397** (batch 4)
  while living in batch 2 on its Lean-implementation-agent overlap with 393 and 396.

The narrow-overlap component these cuts split spans 16 tasks, so under `MAX_TASKS=8` at least
one cut is unavoidable. Among the splits that fit the cap, this one keeps 350 together with four
of its five overlaps, and keeps the three substrate essentials (393, 394, 395) in one early
batch; moving 394 into batch 3 instead would trade the `lean-research-agent.md` cut for a
`git-staging-scope.md` cut and split those essentials apart. Cross-batch collision visibility is
lost for exactly the two relations named above, stated here rather than left silent, per the cap
rule's own requirement.

**One reasoned non-grouping, not a bare exclusion**: 282 and 313 both declare
`agent-system/extensions/core/manifest.json`, so they are left in different batches (6 and 3). A
registration manifest is the narrowness qualifier's own measured exemplar of a coarse path that
does not, by itself, make every task touching it one mandatory group.

**342's hold**: every dependency is satisfied; the hold stands on the version stamp alone. The
consuming repository's `books/book-convention.md` line 4 reads `0.1.0-pre`, reset by owner ruling of
2026-10-06 because the review it waited on had shipped prematurely. Lift when that line reads
`0.1.0` — owner action, never an agent's. Nothing depends on 342, so queuing it parks no other work.

**An edge onto an archived task number is satisfied, not a block.** Such edges resolve as *archived
(satisfied)* in `orchestrate-predispatch-review.sh`. The hazard is a hand-derived count mistaking
them for blockers — which is why the counts above are generated, not transcribed.

## Open work

**Core agent system (13)**
```
313 blocked:328,387 Advisory lint for hand-authored /orchestrate batch proposals in ROADMAP.md ph...
328 blocked:170     systematic_script_and_test_corpus_efficiency
338 blocked:275     sweep_task_support_file_tracked_or_ignored
359 blocked:350     Close the two measured curated-array coverage gaps in the agent-contract lint...
369 blocked:29      Orphan sweep for deployed entries removed from the source store: the deploy a...
376 blocked:393     Lean implementation agents mandate the detach-then-await-notification path co...
170 ready           Audit and isolate shell test suites from ambient host state (memory and timin...
282 ready           Write-time PreToolUse hook blocking record-versioning language, registered ba...
360 ready           Validate that every CARRIED-UNVERIFIED mark names a source, as an advisory-on...
379 ready           Make specs/archive/state.json validatable by validate-state.sh
380 ready           Warn that archival un-tracks evidence-gate targets under the moved task direc...
382 ready           Refuse git stash pop/apply of a stash entry the session did not create
386 ready           Give every git-snapshot.sh --no-revert failure path a reason on stderr instea...
```

**Extensions (5)**
```
342 HOLD            Refactor the books extension's context corpus against the settled convention:...
29 blocked:22       Generate .mcp.json from extension manifests, then register obsidian-memory th...
350 blocked:393,395 offer_owner_review_when_approval_needed
384 blocked:383     Adjudicate whether a books reconciliation postflight lifecycle hook is warran...
383 ready           Add a /reconcile command to the books extension: aggregate docs-stage.sh and ...
```

**Neovim (1)**
```
22 ready            Freeze .opencode: silence fragment validation spam and record the frozen-mirr...
```

**Lean extension (5)**
```
396 blocked:376     lean_phase_commit_full_build_and_plan_anchor
398 blocked:397     Record that a grep for dependents misses rw-site definitional unfolding, and ...
399 blocked:398     Record three measured lean4 gotchas: IO-forced timing harnesses, docstring/se...
385 ready           Define the sanctioned shape for a lean4-typed plan that commits to no theorem...
397 ready           Require a lean research report's recommended compiled artifact to be compile-...
```

**Orchestrator (11)**
```
274 blocked:275     Next-admissible-batch suggestion and alternatives-on-conflict, both comp...
275 blocked:170     Per-repo orchestration queue: registered, live, archived on finish, and consu...
312 blocked:282     Backlog reconciliation as a required task-creation component: compare every p...
378 blocked:274     Resolve the reviser-agent handoff contract contradiction between skill-orches...
387 blocked:378     Teach the batch admission gate that a whole-tree regeneration phase is an imp...
395 blocked:394     surface_failed_per_cycle_commit_into_task_status
381 ready           Catch stale derived artifacts at implement postflight and never let containme...
388 ready           prune_next_body_flag_misparse_drops_active_task
389 ready           verify_deploy_context_budget_fixture_missing_git_add
393 ready           propagate_modified_files_constraint_to_silent_agents
394 ready           file_scope_containment_chokepoint_for_scoped_commit
```

**Agent system (3)**
```
362 blocked:359     Teach the non-destructive history-read techniques at the point of use, so an ...
390 blocked:391     Migrate seven mis-sited agent-system tasks out of BimodalLogic and retire one...
391 blocked:369     Close the target_root authoring hole that files agent-system tasks into the w...
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
  an unordered territory overlap is most likely to involve. The 13 edges added for this pass went
  in via `state-write.sh` with `validate-state.sh --deep` confirming acyclicity, the path Settled
  decision 17 already sanctions for a hand-added edge. Worth a task: either a `map_status()` arm
  for `not_started` or an explicit edge-only operation.
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
  makes it broader than 376's Lean-agent scope. Workaround: re-prompt the agent directly.
- **Three open tasks carry no `title` key** (328, 338, 350), so renderers describe them from
  `project_name`. `orchestrate-predispatch-review.sh` Class B checks only for a *literal null* and
  misses an absent key.
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
- `plan-file-scope-harvest.sh` parses a `**Files to modify**:` field and finds nothing in a plan
  using a Territory Contract table instead.
- The write-time task-reference hook fires on files in the session scratchpad; its path filter could
  exempt `/tmp/**`.
- **A loosely-scoped `subagent_type: "fork"` inherits the parent's entire task mandate** and can
  autonomously complete unrelated inherited work rather than the narrow action requested. Mitigation
  landed in `core/docs/fork-patterns.md`; recorded because the failure mode is easy to re-introduce.
