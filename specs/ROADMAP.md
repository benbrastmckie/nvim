# Roadmap

*Forward-only: what remains, in what order, and the checks that gate each step. Finished work is
removed, not archived here — it lives in git history, task summaries and `specs/archive/`. Task
detail lives in `specs/TODO.md`; this file carries only ordering, gates and rulings. Measured
2026-10-07.*

## Goal

`/orchestrate` is the only lifecycle entry point, and the orchestrator is token-cheap by
construction: it delegates, reads back compact verdicts, and asks the user only when a decision is
genuinely the user's.

`MAX_TASKS` is 8, enforced in `commands/orchestrate.md`. `orchestrate-cycle-plan.sh` itself accepts
any count, so a dry-run over more than 8 is not evidence a call will run them.

**40 open tasks**: 20 ready, 19 blocked, 1 held. If that stops matching `state.json`, this file has
drifted — it is hand-derived until **306** makes it generated.

## Gate state

- **Deploy gates are GREEN**: `verify-deploy.sh --skip-slow` returns PASS, 33 checks, 0 failures,
  and `check-extension-docs.sh` exits 0 with 0 FAIL rows (both measured 2026-10-07 after resync).
  `check-extension-docs.sh` was red twice the same day — twice from an unregistered
  `scripts/tests/test-*.sh` missing its `provides.scripts` line, once from source/deploy drift after
  a source-store commit without a resync. **355** owns the escape.
- **The orchestrator context budget is tight but under.** Eager load 65628 B against a 65950 B
  baseline (322 B of headroom), `commands/orchestrate.md` 20440 B / 21000 B, and
  `skills/skill-orchestrate/SKILL.md` 21121 B / 21500 B — that last ceiling was raised from 20000 B
  on 2026-10-07 after a necessary addition breached it, with compaction applied first. Expect the
  next orchestrator-surface addition to need compaction rather than another ceiling move.
- **`validate-state.sh --deep`**: 17 passed, 0 failed, **6** warnings — 328's missing `file_scope`
  key, 349's empty array, the visibility summary reporting both, and **three** glob-shaped entries
  on 342 that collision detection cannot see. Treat any *new* warning, and any failure, as real.
- **Gate 8 (`tests/run-all.sh`) spans every extension and is slow but DOES conclude** under
  `--jobs 4` inside a ~560 s budget (measured 2026-10-07). A sequential run does not. Earlier
  roadmap text called it "not reliably runnable inside a dispatch"; the measured position is
  narrower — pass `--jobs 4` and allow the budget, or expect the 4-5x sequential cost. Flakiness
  and host coupling are owned by **170**, runtime by **328**.
- **Five suites are knowingly red**, all in `known-failures.txt` with reasons:
  `test-orchestrate-cycle-plan.sh` (**351**), `test-gate-out-repair-reporting.sh` (**352**),
  `test-lint-json-channel-discipline.sh` and `test-typst-element-lint.sh` (**353**), and
  `test-run-all-parallel.sh` (intermittent, accepted). Read the `EXPECTED`/`NEW` split, not the
  tally — a NEW failure is yours.
- **`--skip-slow` hides doc-sync pin failures.** `test-runtime-file-tracking.sh` Case 3 only runs
  under the full gate set. A `--skip-slow` pass is not evidence the pins hold; run
  `tests/run-all.sh` before trusting a green on any task that edits a lib with a doc-sync pin.
  This is the measured instance of Settled decision 15.
- **Consumer repos were all 8 STALE at last measurement (2026-10-03).** If work touches a consumer,
  run `check-consumer-freshness.sh` here and `deploy-headless.sh` **there** first; this repo never
  pushes into a consumer.

## Next

The priority set is **351, 355, 349, 345, 302**, then the standing **280/311/344** group.

**A batch may carry dependency edges between its own members, and should.** Wave dispatch
re-derives eligibility every cycle from the batch's own `dependency_graph`, so an edge between two
members sequences them inside one invocation instead of excluding either. A batch that serializes
to width 1 is a correct batch. The calls below are grouped by what belongs together, not by what can
run concurrently — see Settled decision 17.

```
/orchestrate 351, 355        # two waves: [351] then [355]
/orchestrate 345, 354        # two waves; edge added 2026-10-07 on bounded-build-waiter.md
/orchestrate 349, 350        # two waves; fill 349's empty file_scope FIRST
/orchestrate 284, 302        # one wave
/orchestrate 280, 311, 344   # two waves: [280, 311] then [344]
/orchestrate 352, 353        # two waves; only after 351
```

All six verified with `--dry-run` on 2026-10-07: 0 deferred, 0 blocked, `state.json` unchanged.

Why this order, and what each one unblocks:
- **351** — the orchestrator's own `IDENTICAL DISPATCH HALT` is implemented but never fires. 14 of
  349 assertions fail; a repeat-identical dispatch is issued anyway, the dispatch file is not backed
  out, the task lock stays held, and `dispatch_seq_counter`/`cycle_counts` still advance. The guard
  against burning cycle budget on unchanged work is silently off. Gates **352** and **355**.
- **355** — an unregistered test script can reach `COMPLETED` undetected, which happened. Its
  larger finding is the gate shape: the redeploy checkpoint compares finding *counts*
  (`pre=11 post=2 new=0`) and so passed a batch that introduced a brand-new hard failure, because
  the count fell for unrelated reasons. A count cannot distinguish "fixed nine" from "introduced
  one while fixing ten".
- **349** — `/approve` as one interactive question instead of a terminal round-trip. Unblocked by
  300. **Declares an empty `file_scope`**: fill it before dispatching, or its overlap with every
  other task is unmeasurable, including whether it needs an edge at all. Gates **350**.
- **345** — bound the no-op spin to a contract with a single writer. Unblocked by 343, whose work it
  continues directly. Now gates **354**.
- **302** — pass `--task` at commit-staging sites to engage the contended-path lease. Unblocked by
  300. Gates **304**.
- **344** — carries the batching-by-default doctrine to the point of use, and makes a territory
  overlap produce a serializing edge rather than a separation. Its Item 6 mechanizes the
  edge-backfill that is still a hand `state-write.sh` call. Gates **274**, **312**, **313**.
  **Run it with 280 and 311 in one invocation** — that is its own dogfood constraint, not a
  convenience: filing it to run alone would reproduce the defect it exists to fix.
- **342** — held, and **not liftable by an agent**; see the hold note below.

Scheduling notes:
- **354 follows 345 by declared edge**, added 2026-10-07 after a dry-run showed the pair deferring
  on `context/patterns/bounded-build-waiter.md` with no edge between them. 345 establishes the
  single-writer contract; 354 then rules on its scope. This is the decision-17 move: add the edge,
  do not separate the pair.
- **352 → 353 chain on `known-failures.txt`**, and **355 follows 351** on
  `orchestrate-cycle-plan.sh`. Both edges exist so the set is batchable rather than deferring.
- **Nothing depends on 342**, so queuing it behind anything parks no other work. That check is the
  decision-17 carve-out and must be made before adding an edge onto a held or owner-blocked task.
- **An edge onto an archived task number is satisfied, not a block.** 14 edges across 9 open tasks
  point at numbers absent from `state.json` (127, 165, 184, 206, 215, 250, 263, 265, 285, 322,
  329); `orchestrate-predispatch-review.sh` resolves every one as *archived (satisfied)*. They do
  not freeze work. The live hazard is that a hand-derived file like this one can miscount them as
  blockers — **306** removes it.

Then the unblocking plays, highest leverage first: **284** (frees 335 and feeds 304), **251**
(frees 170, which frees 328), **271** (frees 273 and 303), **280** (frees 281, 282 and 344).

## Open work

One line per task; detail in `TODO.md`. `blocked:N` means N is the open blocker.

**Orchestrator (18)**
```
351 ready            IDENTICAL DISPATCH HALT implemented but never fires   <- priority
271 ready            parent_task edge: schema, validation, TODO rendering
272 ready            honest session liveness for concurrent same-repo batches
299 ready            detect in-place plan revision concurrent with a live implement dispatch
302 ready            pass --task at commit-staging sites to engage the contended-path lease   <- priority
311 ready            measured co-scheduling signal replacing static build-heavy family membership
319 ready            surface cross-task claim invalidation when research refutes a filed premise
345 ready            bound the no-op spin to a contract with a single writer   <- priority
347 ready            PreToolUse Bash hook blocking self-matching process-name waiters
273 blocked:271      three-channel conclusion stage with per-channel approval
275 blocked:272      per-repo orchestration queue, consumed by admission
303 blocked:271      validate-state.sh default must resolve against the repo, not CWD
355 blocked:351      unregistered test script reaches COMPLETED; count-based gate comparison   <- priority
344 blocked:280,311  carry the batching-by-default doctrine to the point of use   <- priority
312 blocked:282,344  backlog reconciliation as a required task-creation component
304 blocked:273,284,302        one out-of-repo pathspec aborts staging; callers sink nonzero exits
274 blocked:272,273,275,344    next-admissible-batch suggestion and alternatives-on-conflict
```

**Core agent system (16)**
```
251 ready            context-corpus reachability probe, then act on dead and overlapping files
280 ready            forbid record-versioning language: rule, exemptions, pattern library
284 ready            exempt a task's own directory from the file_scope excursion advisory
306 ready            make ROADMAP.md a generated artifact
318 ready            wire lint-directory-pathspec-boundary.sh in as a numbered gate
336 ready            in-dispatch phase-commit staging: 15 agents, no file_scope check, no lease
338 ready            sweep task support files: tracked or ignored
170 blocked:251      isolate shell test suites from ambient host state (memory, timing)
281 blocked:280      repo-wide record-versioning lint, blocking/advisory split
335 blocked:284      promote the file_scope excursion advisory into a staging-time gate
352 blocked:351      validate-artifact.sh fix counters neither accumulate nor reset
354 blocked:345      does the local-gate prohibition cover awaiting a dispatched subagent
282 blocked:280,281  write-time PreToolUse hook blocking record-versioning language
313 blocked:306,328,344        advisory lint for hand-authored batch proposals in ROADMAP blocks
328 blocked:170,303,304,318    systematic script and test corpus efficiency
```

**Neovim (3)**
```
22  ready            freeze .opencode: silence fragment validation spam, record the policy
295 ready            add desc to 44 keymap.set calls
296 ready            repo hygiene: stale init.lua.backup, project-overview.md, README link
```

**Extensions (6)**
```
349 ready            /approve as one interactive question, not a terminal round-trip   <- priority
350 blocked:349      offer the owner the review path when an approval is needed
353 blocked:352      typst: stderr-into-JSON corruption; presence-vs-density check overlap
29  blocked:22       generate .mcp.json from extension manifests; register obsidian-memory
342 HOLD             books context corpus refactor — see below
```

**342's hold**: every dependency is satisfied (340, 341 completed 2026-10-05; 346 completed
2026-10-07). The hold stands on the version stamp alone, and that is a deliberate deferral rather
than a pending formality: the consuming repository's `books/book-convention.md` line 4 reads
`0.1.0-pre`, having been stamped `0.1.0`, bumped four more times in one day, then **reset to
`0.1.0-pre` by the owner ruling of 2026-10-06** because the review it waited on had shipped
prematurely. Lift when that line reads `0.1.0` — owner action, never an agent's, and never as a
side effect of prioritising the task here. Dispatching it before the stamp lands would refactor the
corpus against a premise the convention record contradicts.

## Checks before and after every call

- `orchestrate-cycle-plan.sh --dry-run --state-file specs/state.json <tasks>` — **space-separated**.
  Admits what you expect; `md5sum specs/state.json` unchanged. Research and plan dispatches are
  exempt from the self-modifying defer, so overlap only serializes at implement time.
- `validate-state.sh --deep` — compare against the 6 known warnings above.
- `tests/run-all.sh --jobs 4` — read the end-of-run failure roster and the `EXPECTED`/`NEW` split,
  not the tally; read the exit code directly, never through `tail`/`head`. `--fail-on-new` makes it
  a gate.
- `verify-deploy.sh --skip-slow` — measure *before* your work as well as after, and compare. Do not
  read a standing red as permission to ignore a new one. A self-modifying task is not finished until
  `.claude/` is resynced, and a resync whose verify is red is reported, not silently accepted.
- **A source-store commit without a resync is itself a red gate.** `check-extension-docs.sh` reports
  it as `deployed script content drift`. Observed 2026-10-07.
- A completion postflight refused with **exit 6** needs no action: the Inter-Cycle Redeploy
  Checkpoint promotes the task on the next cycle. For the genuinely stuck case,
  `reconcile-task-status.sh <N> <session>`.
- **To tell a working dispatch from a stranded one, read artifact mtimes and live child processes.**
  Absence of `.orchestrator-handoff.json` is NOT a stall signal — the research phase never writes
  one in any mode. Misreading it as one produced a false stranding diagnosis on 2026-10-07.

## Settled decisions (do not re-litigate)

1. **Batch of one.** One engine; single-task is a batch of one. Team mode is deleted. Hard mode is
   kept in full, per-invocation.
2. **The orchestrator never asks and never decides.** Only an agent-surfaced `user_decision` reaches
   the user, once, at cycle end. A `blocking: false` decision proceeds on the agent's recommendation
   and is surfaced, not prompted.
3. **Research-first is the default** for a fresh task; `--fast` restores planner-first.
4. **`--dry-run` prints the plan it would dispatch.** There is no separate dry-run report.
5. **No fixed consumer validation gates.** The checks above are recommended, not blocking.
6. **A linear chain of small tasks serializing on one file is one task with phases.** Apply at
   creation time.
7. **`file_scope` warnings are live input, not noise.** In-batch collisions block; cross-batch ones
   are advisory. The blocking half is right and is not weakened by decision 17: an *unordered*
   overlapping pair would share a wave and write concurrently, so the refusal is correct. The
   remedy is to order the pair with an edge, not to drop one from the batch.
8. **Rule before mechanism** for the vimtex hazard. Re-file a mechanism task only if the rule proves
   insufficient.
9. **Skeleton plans terminate through the completion-claim gate.** No `pr_ready` routing outside
   `type=pr`.
10. **No third automated deploy-trigger site.** The sanctioned count stays at exactly two.
11. **One grant mechanism.** A push or other blocked git action is authorized by one single-use token
    bound to action, remote, branch and sha, minted only where the harness can prove the user typed
    it. Nothing the model can write is a grant. PR/MR creation and `/merge` stay user-only.
12. **A grant may authorize a plain push of the default branch** (user ruling). Every force form on
    the default branch, bare `--force` anywhere, and all bulk or deletion refspecs stay categorically
    excluded, checked before any grant lookup.
13. **`known-failures.txt` is the only known-failing list.** Advisory by construction; it never
    changes which suites run. Never keep a prose copy elsewhere — that is the drift mechanism. A
    `needs-owner` row is a known gap, not an accepted steady state, and gets a follow-up task.
14. **One shared working tree, always.** Per-dispatch `git worktree` isolation is removed, not
    narrowed. Concurrency safety rests on declared `file_scope`, dependency edges and the five
    contention inputs. Build contention is closed by refusing to co-schedule two build-heavy
    implement tasks in one cycle. Cost was not the reason for removal and must not be cited as it.
    Record: `specs/decisions/worktree-isolation-removal-verdict.md`.
15. **Gate 8's deployed-tree coverage is knowingly reduced** (accepted on wall-clock grounds). The
    redeploy checkpoint runs `--skip-slow`, so the ~40 core suites resolving their subject from the
    *deployed* tree are not verified against a fresh deploy. The narrower fix is in **328**'s scope.
16. **A systemic cost is filed as one standing task against a probe's output, not a stream of point
    defects.** Duplication, dead code and slow tests never break anything, so defect-driven intake
    cannot see them. 328 is the standing consumer of `script-inventory.sh`; 307, 308 and 270 were
    abandoned into it.
17. **A batch may carry dependency edges between its own members, and an unordered territory
    overlap is resolved by adding the edge, not by separating the pair** (owner ruling). Wave
    dispatch re-derives eligibility every cycle from the batch's own `dependency_graph`, so an
    intra-batch edge sequences its two members inside one invocation. Serializing to width 1 is a
    correct outcome: the property defended is collision visibility and correct ordering, never
    wall-clock. Binding consequences: a **"never with" note is not an acceptable rendering** of an
    overlap — pick an order and record the edge; and a bare exclusion must never stand in for an
    edge that was simply not added. **Two carve-outs.** (a) *Owner-blocked predecessor*: if the
    would-be predecessor cannot progress — held, owner-gated, or `PARTIAL` behind something no task
    can unblock — separation is correct and the reason is stated, because an edge would park live
    work behind a permanent stall. Check what depends on the target before edging onto it.
    (b) *Breadth*: a coarse shared path (a manifest, a root gate script, a directory-root scope) can
    make rule 1 demand a group larger than `MAX_TASKS=8`, which the cap then silently trims; there,
    narrow the `file_scope` instead. **344 carries this to the point of use** and mechanizes the
    edge backfill; until it lands, the edge is added by hand via `state-write.sh` and acyclicity
    confirmed with `validate-state.sh --deep`.

## Standing rules

1. **Agent-system defects get filed here.** A fix in a consuming repo's `.claude/` is wiped on reload.
2. **`.claude/**` is a deploy artifact.** Edit the source store under `agent-system/extensions/**`,
   then resync — see the gate note above.
3. **`TODO.md` is generated from `state.json`.** Edit the `description` field via `state-write.sh`,
   then `generate-todo.sh`. A hand edit to `TODO.md` is wiped by the next regeneration — observed
   2026-10-05, losing three task revisions.
4. **Propose, then apply, across repos.**
5. **Verify by execution, not by reading.** Every number here was measured the day it was written;
   re-measure before acting on it.
6. **The lead never reads a report, plan, summary, description or context file during the loop.**
7. **This file describes the current plan only.** No revision history, no pass numbers.

## Unfiled observations (none worth a task yet)

- **Four open tasks carry no `title` key at all** (328, 338, 349, 350), so `TODO.md` and this file
  describe them from `project_name` and `description`. `orchestrate-predispatch-review.sh` Class B
  checks for a *literal null* and does not catch an absent key. Belongs with **306**.
- **`TODO.md`'s tree view strips punctuation from titles**, so a backticked or underscored
  identifier renders as `SKILLVALIDATEFIXES`. The per-task detail section renders correctly.
  Cosmetic; belongs with **306**.
- **A rendered `**Goal**:` line in `TODO.md` cannot survive regeneration and fails validation while
  present.** `generate-task-order.sh --goal` writes it; `generate-todo.sh` drops it and never reads
  `active_goal` from `state.json`. So `active_goal` is write-only and the displayed goal is
  permanently blank. Belongs with **306**.
- **No mechanism prevents a vault operation from leaving edges pointing at renumbered tasks**, and
  `validate-state.sh` does not check it. Today's 14 such edges all resolve as archived-satisfied, so
  nothing is frozen — but the 2026-08-10 reset did freeze 4 tasks until cleared by hand 2026-10-05.
- **The probe's `inbound_callers` field cannot find dead code** — a script's own `manifest.json`
  entry counts as a caller of its basename, so it reports zero zero-caller scripts across 197 files.
  `has_test` is a filename-convention check and under-reports coverage. Both recorded inside **328**
  so they are not mistaken for answers.
- `plan-file-scope-harvest.sh` parses a `**Files to modify**:` field and finds nothing in a plan
  using a Territory Contract table instead. At least one BimodalLogic plan is invisible to it.
- The write-time task-reference hook fires on files in the session scratchpad; its path filter could
  exempt `/tmp/**`.
- The in-scope agent set for a contract rolled across implementation agents is **14** files, not the
  13 a sweep by directory suggests — `founder-implement-agent.md` also edits phase-heading markers.
- **A loosely-scoped `subagent_type: "fork"` inherits the parent's entire task mandate** and can
  autonomously complete unrelated inherited work rather than the narrow action requested — observed
  2026-10-07, where a fork probe produced a whole research deliverable and a premature completion
  message. Mitigation landed in `core/docs/fork-patterns.md`; recorded here because the failure mode
  is easy to re-introduce.
