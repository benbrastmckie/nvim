# Roadmap

*Forward-only: what remains, in what order, and the checks that gate each step. Finished work is
removed, not archived here — it lives in git history, task summaries and `specs/archive/`. Task
detail lives in `specs/TODO.md`; this file carries only ordering, gates and rulings. Measured
2026-10-09.*

## Goal

`/orchestrate` is the only lifecycle entry point, and the orchestrator is token-cheap by
construction: it delegates, reads back compact verdicts, and asks the user only when a decision is
genuinely the user's.

`MAX_TASKS` is 8, enforced in `commands/orchestrate.md`. `orchestrate-cycle-plan.sh` itself accepts
any count, so a dry-run over more than 8 is not evidence a call will run them.

**32 open tasks**, and 28 completed awaiting `/todo` archival. Both counts and every wave
membership are derived, never transcribed: `generate-task-order.sh --print` for ordering,
`roadmap-integration.sh --regenerate`/`--prune` for the `## Open work` roster and the coverage
appendix. A hand-maintained count here goes stale within one run.

## Gate state

- **`known-failures.txt` carries one row**: `test-run-all-parallel.sh`, intermittent, accepted on
  its own rejected-alternatives record. It is advisory by construction and never changes which
  suites run (Settled decision 13).
- **Gate 22 is the shellcheck gate.** `lint-shellcheck.sh` lints every `*.sh` under
  `agent-system/extensions/` at `-S warning`; the tree is at **zero findings across 361 scripts**,
  and an unresolvable `shellcheck` binary is a named exit 70, never a silent skip. The next
  numbered gate to be added is therefore **23** — relevant to 318, which was planned against 22.
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
(Settled decision 17), so a call that serializes to width 1 is correct. Ordered by live
dependency edges as of 2026-10-09; not `--dry-run` verified.

```
/orchestrate 371, 372, 373                  # TOP: roadmap/conclusion-stage gaps, all three free
/orchestrate 302, 347                       # staging lease + waiter hook; 302 unblocks 304
/orchestrate 251, 318, 338                  # probe, gate wiring (gate 23 now), support-file sweep
/orchestrate 378, 381, 382                  # dispatch-contract and git-safety hardening
/orchestrate 376, 379, 380                  # lean detach path, archive-state validation, archival
/orchestrate 281, 282                       # record-versioning lint chain, strictly ordered
/orchestrate 275, 274                       # the queue, then next-admissible-batch suggestion
/orchestrate 22, 354, 360, 362              # hygiene, no-op-spin ruling, mark discipline
/orchestrate 350, 359                       # approvals follow-through, now unblocked
/orchestrate 304, 170, 328                  # the deep chain, in its own dependency order
/orchestrate 312, 313                       # gated on 282 and 328; the batch-proposal lint pair
/orchestrate 29, 369                        # .mcp.json generation, then the orphan sweep
```

Why this order:

- **371, 372, 373 first.** All three were filed against machinery this file depends on: 371 teaches
  `roadmap-integration.sh` the stage-based layout and fixes its silent abort, 372 adds the
  conclusion stage's missing report block, and 373 fixes issue-log entries with a null `resolution`
  being permanently invisible to the conclusion stage. 373 is load-bearing for the other two being
  *evidenced* rather than argued — a run that logs 52 entries and surfaces 1 is the live symptom.
- **302 → 304 → 170/328.** 302 is the only open prerequisite 304 still needs; 328 is the standing
  consumer of `script-inventory.sh` (Settled decision 16), so 170 and 318 are ordered ahead of it
  rather than leaving it parked. 347 rides along with 302.
- **318 must claim gate 23, not 22.** The shellcheck gate took 22. Re-derive the number from the
  live `gate_selected` grep at implementation time rather than hardcoding it, and expect to bump
  the same `--only-gate` range literals (five sites, not two).
- **281 → 282 → 312, and 275 → 274.** Strictly ordered by their own edges, so each serializes to
  width 1 — the correct outcome, not a batching failure.
- **350 and 359 are no longer externally blocked.** 350's only prerequisite landed, so the
  `EXT-BLOCKED` authored override that used to sit on both is retired; 359 follows 350 on its own
  edge. No cross-repo check is needed before dispatching either.
- **312 and 313 last of the open set.** 313 is the advisory lint for hand-authored `/orchestrate`
  batch proposals in this very file — it closes the loop that every hand edit to the Run lines
  above reopens.

**342's hold**: every dependency is satisfied; the hold stands on the version stamp alone. The
consuming repository's `books/book-convention.md` line 4 reads `0.1.0-pre`, reset by owner ruling of
2026-10-06 because the review it waited on had shipped prematurely. Lift when that line reads
`0.1.0` — owner action, never an agent's. Nothing depends on 342, so queuing it parks no other work.

**An edge onto an archived task number is satisfied, not a block.** Such edges resolve as *archived
(satisfied)* in `orchestrate-predispatch-review.sh`. The hazard is a hand-derived count mistaking
them for blockers — which is why the counts above are generated, not transcribed.

## Open work

**Core agent system (16)**
```
170 blocked:251     Audit and isolate shell test suites from ambient host state (memory and timin...
282 blocked:281     Write-time PreToolUse hook blocking record-versioning language, registered ba...
313 blocked:328     Advisory lint for hand-authored /orchestrate batch proposals in ROADMAP.md ph...
328 blocked:170,304,318  systematic_script_and_test_corpus_efficiency
359 blocked:350     Close the two measured curated-array coverage gaps in the agent-contract lint...
369 blocked:29      Orphan sweep for deployed entries removed from the source store: the deploy a...
251 ready           Context-corpus reachability probe (filename, directory, index.json), then act...
281 ready           Repo-wide record-versioning lint with a blocking/advisory tier split, driven ...
318 ready           Wire lint-directory-pathspec-boundary.sh into verify-deploy.sh as a numbered ...
338 ready           sweep_task_support_file_tracked_or_ignored
354 ready           Rule on whether the local-gate backgrounding prohibition must also cover wait...
360 ready           Validate that every CARRIED-UNVERIFIED mark names a source, as an advisory-on...
376 ready           Lean implementation agents mandate the detach-then-await-notification path co...
379 ready           Make specs/archive/state.json validatable by validate-state.sh
380 ready           Warn that archival un-tracks evidence-gate targets under the moved task direc...
382 ready           Refuse git stash pop/apply of a stash entry the session did not create
```

**Extensions (3)**
```
342 HOLD            Refactor the books extension's context corpus against the settled convention:...
29 blocked:22       Generate .mcp.json from extension manifests, then register obsidian-memory th...
350 ready           offer_owner_review_when_approval_needed
```

**Neovim (1)**
```
22 ready            Freeze .opencode: silence fragment validation spam and record the frozen-mirr...
```

**Orchestrator (11)**
```
274 blocked:275     Next-admissible-batch suggestion and alternatives-on-conflict, both comp...
304 blocked:302     Stop one out-of-repository pathspec entry from aborting staging for every val...
312 blocked:282     Backlog reconciliation as a required task-creation component: compare every p...
275 ready           Per-repo orchestration queue: registered, live, archived on finish, and consu...
302 ready           Pass --task at commit-staging sites to engage the contended-path lease, and r...
347 ready           PreToolUse Bash hook blocking self-matching process-name waiters, registered ...
371 ready           Teach roadmap-integration.sh the stage-based ROADMAP layout and fix its silen...
372 ready           Add the conclusion stage missing report block and name its roadmap-generator ...
373 ready           Issue-log entries with a null resolution are permanently invisible to the con...
378 ready           Resolve the reviser-agent handoff contract contradiction between skill-orches...
381 ready           Catch stale derived artifacts at implement postflight and never let containme...
```

**Agent system (1)**
```
362 ready           Teach the non-destructive history-read techniques at the point of use, so an ...
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
- **Neither `/todo` nor `/review` wires the roadmap generator's modes to its own command.** 371 and
  372 cover the generator's layout handling and the conclusion stage's own caller naming; the
  `/todo`→`--prune` and `/review`→`--regenerate` wiring is still nobody's. Both modes are run by
  hand today.
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
