# Roadmap

*Forward-only: what remains, in what order, and the checks that gate each step. Finished work is
removed, not archived here — it lives in git history, task summaries and `specs/archive/`. Task
detail lives in `specs/TODO.md`; this file carries only ordering, gates and rulings. Measured
2026-10-13. Gate-state figures below carry their own inline measurement dates and were not
re-run today — only task counts, `## Open work`, and `## Next`'s ordering were refreshed, against
the task set left after today's `/todo` archival of 39 completed tasks.*

## Goal

`/orchestrate` is the only lifecycle entry point, and the orchestrator is token-cheap by
construction: it delegates, reads back compact verdicts, and asks the user only when a decision is
genuinely the user's.

`MAX_TASKS` is 8, enforced in `commands/orchestrate.md`. `orchestrate-cycle-plan.sh` itself accepts
any count, so a dry-run over more than 8 is not evidence a call will run them.

**35 open tasks**, none completed and awaiting `/todo` archival (39 archived today). Both counts
and every wave membership are derived, never transcribed: `generate-task-order.sh --print` for
ordering, `roadmap-integration.sh --regenerate`/`--prune` for the `## Open work` roster and the
coverage appendix. A hand-maintained count here goes stale within one run.

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

Each call is a single `/orchestrate` invocation; intra-batch edges sequence members into waves
(Settled decision 17), so a call that serializes to width 1 is correct. Re-ordered 2026-10-13
after today's `/todo` archival removed every task the prior order led with (371, 372, 373, 302,
347, 251, 318, 354, 281, 304 are all now completed). Essentiality drove this pass, not just
dependency edges: a defect that silently masks or corrupts *other* tasks' results outranks any
feature work, so those move to the top even though nothing blocks on them. Not `--dry-run`
verified.

```
/orchestrate 389                            # TOP: unblocks every future final-phase gate criterion
/orchestrate 388                            # roadmap prune() silently drops an active task - no edge
/orchestrate 382                            # evidenced git-stash foreign-pop data-loss guard
/orchestrate 381                            # evidenced stale-derived-artifact postflight containment
/orchestrate 394                            # file_scope containment chokepoint, scoped commit
/orchestrate 395                            # surface a failed per-cycle commit into task status
/orchestrate 393                            # propagate modified_files to 10 of 14 silent agents
/orchestrate 391                            # close the cross-repo task-siting hole first
/orchestrate 390                            # then migrate the 7 tasks 391 would have caught
/orchestrate 379, 380                       # archive-state validation, archival un-tracking warning
/orchestrate 378                            # reviser-agent handoff contract contradiction
/orchestrate 170, 328                       # ambient-host isolation audit, then the deep refactor
/orchestrate 338, 360                       # support-file tracked/ignored sweep, mark validation
/orchestrate 376                            # lean detach-then-await mandate
/orchestrate 385                            # zero-lean-goals plan shape (spans lean + core format)
/orchestrate 396                            # phase-commit-on-full-build + plan-anchor guidance
/orchestrate 275, 274                       # the queue, then next-admissible-batch suggestion
/orchestrate 387                            # whole-tree-regen admission gate
/orchestrate 282                            # record-versioning write-time hook
/orchestrate 312, 313                       # backlog reconciliation, then the batch-proposal lint
/orchestrate 22                             # opencode freeze
/orchestrate 362                            # non-destructive history-read discipline, point of use
/orchestrate 386                            # git-snapshot --no-revert gets a stderr reason
/orchestrate 29, 369                        # .mcp.json generation, then the orphan sweep
/orchestrate 350, 359                       # approvals follow-through
/orchestrate 383, 384                       # books /reconcile command, then its lifecycle-hook ruling
```

Why this order:

- **389 through 393 first — seven calls, each its own line, none batched together.** All seven
  are substrate-correctness defects: a passing result from any *other* task's final gate, commit,
  or agent dispatch is not trustworthy until these land, so they outrank every dependency-driven
  or feature task below regardless of what blocks what. 389 is explicitly load-bearing for every
  future plan's final-phase criterion (a masked gate failure is indistinguishable from a real
  one). 388 is the same failure class in this file's own tooling — a silent active-task drop from
  `## Next` — found while regenerating this very section today. 382 and 381 are each evidenced
  against a real consumer-repo incident, not argued. **394 and 395 both declare
  `git-staging-scope.md` in `file_scope` with no edge between them — never batch them together,
  run each alone.** 393 touches ten implementation agents directly; see the 362 note below for
  why it cannot ride with 362 either.
- **391 before 390.** 391 closes the authoring hole that let agent-system tasks land in the wrong
  repository; running it first means 390's migration isn't immediately undone by a new task
  landing the same way. No file overlap forces this order — it is purely to stop the bleeding
  before mopping the floor.
- **170 → 328.** 328 is the standing consumer of `script-inventory.sh` (Settled decision 16) and
  depends on 170 directly; both of 328's other former prerequisites (304, 318) are now archived
  (satisfied).
- **376, 385, 396 run as three separate calls, not one Lean batch.** 376 and 396 both declare
  `lean-implementation-agent.md` and `lean-implementation-hard-agent.md` in `file_scope` with no
  edge between them.
- **362 cannot batch with 393.** Both declare most of the same implementation-agent files
  (`typst`, `python`, `rust`, `web`, `z3`, `latex`, `cslib` at minimum) in `file_scope`; run 393's
  call (in the TOP tier above) to completion before dispatching 362's.
- **378 cannot batch with 274, 275, or 387.** All four declare `skill-orchestrate/SKILL.md` or
  `orchestrate-cycle-plan.sh` in `file_scope` with no edges connecting them; each gets its own
  call.
- **350 cannot batch with 395.** Both declare `orchestrate-cycle-postflight.sh`; they are already
  far enough apart in this order that the constraint is satisfied by construction, but note it
  before hand-editing this list.
- **383 → 384 and 275 → 274, 312 → 313.** Strictly ordered by their own edges, so each serializes
  to width 1 — the correct outcome, not a batching failure.
- **350 and 359 remain paired on 359's own edge onto 350.**

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
313 blocked:328     Advisory lint for hand-authored /orchestrate batch proposals in ROADMAP.md ph...
328 blocked:170     systematic_script_and_test_corpus_efficiency
359 blocked:350     Close the two measured curated-array coverage gaps in the agent-contract lint...
369 blocked:29      Orphan sweep for deployed entries removed from the source store: the deploy a...
170 ready           Audit and isolate shell test suites from ambient host state (memory and timin...
282 ready           Write-time PreToolUse hook blocking record-versioning language, registered ba...
338 ready           sweep_task_support_file_tracked_or_ignored
360 ready           Validate that every CARRIED-UNVERIFIED mark names a source, as an advisory-on...
376 ready           Lean implementation agents mandate the detach-then-await-notification path co...
379 ready           Make specs/archive/state.json validatable by validate-state.sh
380 ready           Warn that archival un-tracks evidence-gate targets under the moved task direc...
382 ready           Refuse git stash pop/apply of a stash entry the session did not create
386 ready           Give every git-snapshot.sh --no-revert failure path a reason on stderr instea...
```

**Extensions (5)**
```
342 HOLD            Refactor the books extension's context corpus against the settled convention:...
29 blocked:22       Generate .mcp.json from extension manifests, then register obsidian-memory th...
384 blocked:383     Adjudicate whether a books reconciliation postflight lifecycle hook is warran...
350 ready           offer_owner_review_when_approval_needed
383 ready           Add a /reconcile command to the books extension: aggregate docs-stage.sh and ...
```

**Neovim (1)**
```
22 ready            Freeze .opencode: silence fragment validation spam and record the frozen-mirr...
```

**Lean extension (2)**
```
385 ready           Define the sanctioned shape for a lean4-typed plan that commits to no theorem...
396 ready           lean_phase_commit_full_build_and_plan_anchor
```

**Orchestrator (11)**
```
274 blocked:275     Next-admissible-batch suggestion and alternatives-on-conflict, both comp...
312 blocked:282     Backlog reconciliation as a required task-creation component: compare every p...
275 ready           Per-repo orchestration queue: registered, live, archived on finish, and consu...
378 ready           Resolve the reviser-agent handoff contract contradiction between skill-orches...
381 ready           Catch stale derived artifacts at implement postflight and never let containme...
387 ready           Teach the batch admission gate that a whole-tree regeneration phase is an imp...
388 ready           prune_next_body_flag_misparse_drops_active_task
389 ready           verify_deploy_context_budget_fixture_missing_git_add
393 ready           propagate_modified_files_constraint_to_silent_agents
394 ready           file_scope_containment_chokepoint_for_scoped_commit
395 ready           surface_failed_per_cycle_commit_into_task_status
```

**Agent system (3)**
```
362 ready           Teach the non-destructive history-read techniques at the point of use, so an ...
390 ready           Migrate seven mis-sited agent-system tasks out of BimodalLogic and retire one...
391 ready           Close the target_root authoring hole that files agent-system tasks into the w...
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
