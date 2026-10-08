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

**48 open tasks**: 24 dispatchable (one of them, 365, in flight), 23 blocked by an in-repo edge,
1 externally blocked (349, with 350 behind it), 1 held (342). If that stops matching `state.json`,
this file has drifted — it is hand-derived until **306** makes it generated.

## Gate state

- **A full `verify-deploy.sh` run is 33 of 34 checks PASS, 1 FAIL** (measured today, ~10 min —
  budget for it, a 540s cap gets SIGTERMed mid-run). The redeploy that landed 364 moved the
  standing baseline from 7 pre-existing findings to this 1, with 0 newly introduced. The survivor
  is **gate 8, `tests/run-all.sh` exit 1**, i.e. the five known-red shell suites owned by **351**,
  **352** and **353** — nothing unowned is hiding behind it. Note the posture mismatch: gate 8
  consumes the bare exit code, not the `EXPECTED`/`NEW` split, so **the deploy suite reads red
  until those three land** no matter how well a suite is annotated. Consistent with Settled
  decision 13, but it means "all gates green" is unreachable meanwhile. `--skip-slow` exits 0 and
  cannot see this gate.
- **Blocking hooks no longer fail open on a bare `cd`.** Every source-store hook registration now
  resolves `"$CLAUDE_PROJECT_DIR"/.claude/hooks/x.sh`, and the merge path is self-healing (Settled
  decision 18), so an ordinary resync repairs a stale deploy instead of duplicating it. Measured on
  this repo's own deploy: 21 CWD-relative registrations to 0, 21 correct, 23 total, no per-event
  duplicates, `env` and `permissions` byte-identical. **365** gates it against reintroduction.
- **The orchestrator eager-context budget has NO headroom left**: 65950 B against a 65950 B
  baseline — **re-measured today** by gate 20 of the full run, identical to the 361 figure. The
  next orchestrator-surface addition must compact first; there is no slack to spend.
  `commands/orchestrate.md` 20440 B / 21000 B; `skills/skill-orchestrate/SKILL.md` 21121 B / 21500 B.
- **`validate-state.sh --deep`**: 17 passed, 0 failed, **6** warnings — re-measured today,
  unchanged: 328's missing `file_scope` key, 349's empty array, the visibility summary reporting
  both, and three glob-shaped entries on 342 that collision detection cannot see. Treat any *new*
  warning, and any failure, as real.
- **Gate 8 (`tests/run-all.sh`) is 92 suites and ~70% of a full `verify-deploy.sh` run** (*timings
  carried, not re-measured*: 14m1.5s sequential vs 6m47.4s at `--jobs auto`). It concludes under
  `--jobs 4`; a sequential run on a loaded host does not finish in a sane budget. **366** adds
  suite-level selection, **368** stops plans from demanding the full battery at a non-final phase.
- **Five shell suites are knowingly red**, all in `known-failures.txt` with reasons:
  `test-orchestrate-cycle-plan.sh` (**351**), `test-gate-out-repair-reporting.sh` (**352**),
  `test-lint-json-channel-discipline.sh` and `test-typst-element-lint.sh` (**353**), and
  `test-run-all-parallel.sh` (intermittent, accepted). Read the `EXPECTED`/`NEW` split, not the
  tally — a NEW failure is yours. **`known-failures.txt` covers shell suites only**; see the
  unowned Lua spec failure under Unfiled observations.
- **`--skip-slow` hides doc-sync pin failures.** `test-runtime-file-tracking.sh` Case 3 only runs
  under the full gate set, so a `--skip-slow` pass is not evidence the pins hold. Measured instance
  of Settled decision 15.
- **Consumer repos were all 8 STALE at last measurement (2026-10-03).** If work touches a consumer,
  run `check-consumer-freshness.sh` here and `deploy-headless.sh` **there** first; this repo never
  pushes into a consumer. One consumer (`Philosophy/Papers/PossibleWorlds`) was repaired by hand on
  2026-10-07; the other seven were not measured since.

## Next

Highest value first, ordered for stability: finish the in-flight hook work, then repair the
orchestrator's own live regressions, then build the end-of-orchestration wrap-up contract, then cut
dispatch cost. Each call is a single `/orchestrate` invocation; intra-batch edges sequence the
members into waves (Settled decision 17), so a call that serializes to width 1 is correct.

```
/orchestrate 365             # in flight; the lint that gates the hook-path fix
/orchestrate 351, 352, 353   # three waves in ONE call; the only route to a green gate 8
/orchestrate 271, 306, 273   # end-of-orchestration wrap-up contract; two waves; runnable today
/orchestrate 272, 355        # two waves; 272 first (shared orchestrate-cycle-plan.sh)
/orchestrate 275             # 274 prerequisite; gated on 272 alone
/orchestrate 280, 311, 344   # two waves; 344's own dogfood constraint — never run it alone
/orchestrate 274             # the next-batch suggestion; last of its own prerequisite chain
/orchestrate 366, 368        # two waves; test-efficiency mechanism, then the planning guidance
/orchestrate 367             # independent; why the exit-6 promotion is unreliable
/orchestrate 347             # newly unblocked by 364; self-matching process-name waiters
/orchestrate 363             # completes the shared-tree git-safety set
/orchestrate 284, 335        # two waves; the file_scope excursion gate
/orchestrate 345, 354        # two waves
```

Why this order:

- **365** — in flight. Its scope grew on 2026-10-07 from a path-shape lint to twelve acceptance
  criteria, after two defects escaped the original pattern: a registration present only in
  install-once `root-files/settings.json` is unreachable by any resync, and a relative hook path
  that does not contain `.claude/` evades a `.claude/`-anchored pattern entirely. The live instance
  of the second was a `SessionStart` registration of `scripts/claude-ready-signal.sh`, a script that
  existed nowhere and had been failing silently behind its own `2>/dev/null || echo '{}'`. Both are
  now gated.
- **351, 352, 353 — one call, and the highest-value call on this list.** These three are the
  *entire* remaining content of the one failing `verify-deploy` check: gate 8 consumes
  `run-all.sh`'s bare exit code, so while any of the five known-red suites is red the deploy suite
  reads red and "all gates green" is unreachable. Clearing all three is the only route to a green
  gate 8.
  - **351** is the substantive defect: the `IDENTICAL DISPATCH HALT` is implemented but never
    fires — a repeat-identical dispatch is issued anyway, the dispatch file is not backed out, the
    task lock stays held, and the counters still advance. A live orchestrator regression that
    wastes budget and strands locks. Also gates **272** and **355**.
  - **352** (validate-artifact fix counters) and **353** (two typst lint defects) are independent
    of 351 and of each other in substance. **Their dependency edges are territory serializations,
    not work dependencies** — all three declare the single shared
    `scripts/tests/known-failures.txt`, where each removes its own row. Recorded in 352's and
    353's own descriptions so a future reader does not mistake the chain for a work order or try
    to optimize it away: dropping the edges does not parallelize the group, it converts a clean
    serialization into an in-batch `file_scope` collision that admission blocks.
  - **Do not combine them into one task.** 353 is `task_type: typst` while 351 and 352 are `meta`,
    and task_type drives agent routing — one task cannot route two ways. Their subjects are
    unrelated, their topics differ, and a merged `file_scope` would span ten entries across the
    core and typst extensions, widening the collision surface against the rest of the backlog. The
    settled decision about a linear chain becoming one phased task is aimed at tasks whose
    *subject* is the shared file; here the shared file is one line of incidental bookkeeping each.
- **271 → 306 → 273 — the end-of-orchestration wrap-up contract, and new capability placed this
  high at the user's explicit direction.** This is what "when an orchestration completes, have the
  cleanup already prepared" actually requires. **273** adds a distinct post-postflight stage that
  aggregates every dispatched subagent's errors-and-follow-ups contribution — research, plan,
  implement and aux alike — then proposes three *separately approved* channels (fix directly now;
  file follow-up tasks as `parent_task` children; route agent-system changes to /meta, which still
  only files tasks), and closes by updating this roadmap and committing its own output through
  `git-commit-scoped.sh`. It was amended on 2026-10-07 to absorb all three of those last elements
  rather than spawn siblings for them, which makes it the largest open orchestrator task; its
  planning phase is directed to phase aggressively and to say so immediately if it wants
  `/task --expand`.
  - **Two waves, and runnable today.** {271, 306} then {273}: 271 and 306 both have empty
    dependency lists, and 273's two remaining edges (184, 329) are archived-satisfied. **271**
    first because channel (c) files follow-ups as `parent_task` children and would otherwise
    write a field nothing reads. **306** because the roadmap update must *consume* 306's
    regenerate/prune modes, never reimplement them — the edge also serializes a shared footprint
    the overlap predicate cannot see, since 306 declares `scripts/roadmap-integration.sh` while the
    only source copy sits under `scripts/deprecated/`.
  - **Stated plainly so the rationale is not read as drift**: this cluster is *new capability*
    ordered ahead of already-queued regression work (366/368, 367, 347, 363) because the user
    asked for it on 2026-10-07, not because its defect pressure outranks theirs.
  - 273 still carries the unresolved reconciliation with **184**'s "do NOT auto-create tasks: the
    report is the handoff and the user files them with /task" ruling. That needs a written verdict
    before planning; the amendment deliberately did not settle it.
- **366 → 368, 367** — measured: the orchestrator's own checkpoints were fixed to stop re-running
  the 92-suite battery, but *every dispatched implementation agent still re-runs it at its own
  phase gates against the identical tree*. 366 adds selection, 368 stops plans demanding `full` at
  a non-final phase, 367 removes the refused-completion round trip. Neither 366 nor 368 may weaken
  the final gate.
- **347** — unblocked by 364 landing. Its own hook registration depended on the path-shape fix
  being settled first.
- **363** — the post-incident checklist. 361 corrected the rule and the guard; this records what to
  check after a destructive-git event on a shared tree, uncommitted pre-session state first.
- **284 → 335** — 335 promotes the `file_scope` excursion advisory into a staging-time gate; 284
  first exempts a task's own directory so the signal is visible rather than buried. A live instance
  landed on 2026-10-07: 364 reported `merge.lua`/`merge_spec.lua` outside its declared scope, after
  the strategy changed mid-task. Advisory only, correctly no gate effect.
- **369** — the deploy can add and change but cannot **delete**. A merge-target entry removed from
  the source store survives in every deployed repo: the merge visits only what the fragments still
  provide, install-once never recopies, and an entry that was never in a fragment has no tracked
  record to unmerge. Live instance in this repo's own `.claude/settings.json` line 21 — a
  `scripts/claude-ready-signal.sh` registration whose source entry 364 deleted, pointing at a
  script that exists nowhere. Severity is low (a silent no-op) but the class is not. Extends
  `merge.lua:755`'s existing `remove_orphaned_index_entries` pattern rather than inventing one,
  and resolves the identity-notion divergence 365's research recorded as accepted-not-reconciled.
  Edged behind 29 (hence 22) because all three write `merge.lua`/`init.lua` — Settled decision 17:
  order the overlap, never separate it.
- **272** — the heartbeat never fires; an implementation agent sat silent for ~5h40m while the
  harness still reported it `running`. It is a structural deadlock, not a missing probe:
  `stall_suspected` is computed only *after* a dispatch returns, while Move 3 forbids postflight
  until every Move 2 call completes. The Move 3 precondition itself needs amending. **355 was
  edged onto it on 2026-10-07**: both declare `orchestrate-cycle-plan.sh` and both were gated only
  on 351, so clearing 351 would have left them an unordered overlap that admission blocks. 272
  first, because it changes how a dispatch is observed and 355 reads that script afterwards.
- **344** — carries batching-by-default to the point of use and mechanizes the edge backfill that
  is still a hand `state-write.sh` call. **Run it with 280 and 311 in one invocation** — its own
  dogfood constraint, not a convenience.
- **274 pulled forward, with its prerequisite chain ordered ahead of it.** 274 is the component the
  user named last — "saying what batch of tasks to orchestrate next" — and it sits behind the
  deepest chain on this list: 272, 273, 275 and 344, with 344 itself behind 280 and 311. Rather
  than leave the suggestion unreachable at the back of the queue, its prerequisites are ordered to
  reach it sooner: 272/355, then **275** (gated on 272 alone), then 280/311/344, then 274 itself.
  Its 273 edge is satisfied by the wrap-up cluster above, so nothing here runs twice. **280, 311
  and 344 stay in one call** — 344's own dogfood constraint, unchanged by the reordering. Same
  caveat as the cluster: this is a deliberate user-directed pull-forward, not a reassessment of
  366/368's or 367's value.
- **342** — held, not liftable by an agent. See the hold note below.

**349 and 350 are out of the near-term set** despite 349 reading `ready`. 349's description records
a cross-repository prerequisite — the approval mechanism it drives lives in Logos/Verification under
the slug `owner_labeled_agent_assisted_approvals`, `not_started` when checked 2026-10-07 — and 350
depends on 349. No dependency edge can express this, since task numbers do not carry across repos.
Check that slug before dispatching either.

**An edge onto an archived task number is satisfied, not a block.** 14 such edges across 9 open
tasks resolve as *archived (satisfied)* in `orchestrate-predispatch-review.sh`. The live hazard is
that a hand-derived file like this one miscounts them as blockers — **306** removes it.

## Open work

One line per task; detail in `TODO.md`. `blocked:N` means N is the open blocker.
`EXT-BLOCKED` means a prerequisite in ANOTHER repository that no in-repo edge can express.

**Orchestrator (19)**
```
271 ready            parent_task edge: schema, validation, TODO rendering   <- priority
299 ready            detect in-place plan revision concurrent with a live implement dispatch
302 ready            pass --task at commit-staging sites to engage the contended-path lease
311 ready            measured co-scheduling signal replacing static build-heavy family membership
319 ready            surface cross-task claim invalidation when research refutes a filed premise
345 ready            bound the no-op spin to a contract with a single writer
347 ready            PreToolUse hook blocking self-matching process-name waiters   <- newly ready
351 ready            IDENTICAL DISPATCH HALT implemented but never fires   <- priority
367 ready            why the exit-6 post-deploy promotion is unreliable   <- priority
272 blocked:351      honest session liveness for concurrent same-repo batches   <- priority
273 blocked:271,306  three-channel conclusion stage with per-channel approval   <- priority
274 blocked:272,273,275,344  next-admissible-batch suggestion and alternatives-on-conflict
275 blocked:272      per-repo orchestration queue, consumed by admission
303 blocked:271      validate-state.sh default must resolve against the repo, not CWD
304 blocked:273,284,302  one out-of-repo pathspec aborts staging; callers sink nonzero exits
312 blocked:282,344  backlog reconciliation as a required task-creation component
344 blocked:280,311  carry the batching-by-default doctrine to the point of use   <- priority
354 blocked:345      does the local-gate prohibition cover awaiting a dispatched subagent
355 blocked:272,351  unregistered test script reaches COMPLETED; count-based gate comparison
```

**Core agent system (21)**
```
251 ready            context-corpus reachability probe, then act on dead and overlapping files
280 ready            forbid record-versioning language: rule, exemptions, pattern library
284 ready            exempt a task's own directory from the file_scope excursion advisory   <- priority
306 ready            make ROADMAP.md a generated artifact   <- priority
318 ready            wire lint-directory-pathspec-boundary.sh in as a numbered gate
338 ready            sweep task support files: tracked or ignored
360 ready            validate that every CARRIED-UNVERIFIED mark names a source
362 ready            teach non-destructive history-read techniques at the point of use
363 ready            post-incident checklist: uncommitted pre-session state checked first   <- priority
366 ready            suite-level selection within Gate 8 (--filter/--only + touched-file map)   <- priority
365 IN FLIGHT        lint forbidding relative paths in hook registrations (12 criteria)
369 blocked:29,365   orphan sweep: the deploy adds and changes but cannot delete
170 blocked:251,366  isolate shell test suites from ambient host state (memory, timing)
281 blocked:280      repo-wide record-versioning lint, blocking/advisory split
282 blocked:280,281  write-time PreToolUse hook blocking record-versioning language
313 blocked:306,328,344  advisory lint for hand-authored batch proposals in ROADMAP blocks
328 blocked:170,303,304,318,366  systematic script and test corpus efficiency
335 blocked:284      promote the file_scope excursion advisory into a staging-time gate   <- priority
352 blocked:351      validate-artifact.sh fix counters neither accumulate nor reset
359 blocked:350      close two agent-contract lint curated-array coverage gaps
368 blocked:366      non-final-phase `full` verification tier must justify itself   <- priority
```

**Neovim (3)**
```
22  ready            freeze .opencode: silence fragment validation spam, record the policy
295 ready            add desc to 44 keymap.set calls
296 ready            repo hygiene: stale init.lua.backup, project-overview.md, README link
```

**Extensions (5)**
```
29  blocked:22       generate .mcp.json from extension manifests; register obsidian-memory
350 blocked:349      offer the owner the review path when an approval is needed (also EXT-BLOCKED)
353 blocked:352      typst: stderr-into-JSON corruption; presence-vs-density check overlap
342 HOLD             books context corpus refactor — see below
349 EXT-BLOCKED      /approve as one interactive question, not a terminal round-trip
```

**342's hold**: every dependency is satisfied. The hold stands on the version stamp alone, and that
is a deliberate deferral: the consuming repository's `books/book-convention.md` line 4 reads
`0.1.0-pre`, having been stamped `0.1.0`, bumped four times in one day, then reset by owner ruling
of 2026-10-06 because the review it waited on had shipped prematurely. Lift when that line reads
`0.1.0` — owner action, never an agent's. Nothing depends on 342, so queuing it behind anything
parks no other work.

## Checks before and after every call

- `orchestrate-cycle-plan.sh --dry-run --state-file specs/state.json <tasks>` — **space-separated**.
  Admits what you expect; `md5sum specs/state.json` unchanged. Research and plan dispatches are
  exempt from the self-modifying defer, so overlap only serializes at implement time.
- `validate-state.sh --deep` — compare against the 6 known warnings above.
- `tests/run-all.sh --jobs 4` — read the failure roster and the `EXPECTED`/`NEW` split, not the
  tally; read the exit code directly, never through `tail`/`head`. `--fail-on-new` makes it a gate.
- `verify-deploy.sh --skip-slow` — measure *before* your work as well as after, and compare. A
  standing red is not permission to ignore a new one. A self-modifying task is not finished until
  `.claude/` is resynced, and a resync whose verify is red is reported, not silently accepted.
- **A source-store commit without a resync is itself a red gate** — `check-extension-docs.sh`
  reports it as `deployed script content drift`.
- A completion postflight refused with **exit 6** should self-clear on the next cycle's redeploy
  checkpoint. It did not, three times on 2026-10-07; it then did on the fourth, promoting 364
  cleanly. So the mechanism is unreliable rather than inert, which is what **367** must diagnose.
  Meanwhile `reconcile-task-status.sh <N> <session>` promotes a stranded task by hand — but only
  once the source store is actually fresh, and a *live* dispatch editing the source store keeps it
  stale.
- **To tell a working dispatch from a stranded one, read artifact mtimes and live child processes.**
  Absence of `.orchestrator-handoff.json` is NOT a stall signal — the research phase never writes
  one in any mode.
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
10. **No third automated deploy-trigger site.** The sanctioned count stays at exactly two. (The prose
    in `regeneration-is-manual-only.md` and `test-lint-deploy-caller-wrap.sh` currently name
    *different* pairs; the lint is the mechanical truth. **367** carries the correction.)
11. **One grant mechanism.** A blocked git action is authorized by one single-use token bound to
    action, remote, branch and sha, minted only where the harness can prove the user typed it.
    Nothing the model can write is a grant. PR/MR creation and `/merge` stay user-only.
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
    *deployed* tree are not verified against a fresh deploy. Narrower fix is in **328**'s scope.
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
    **344 carries this to the point of use**; until it lands the edge is added by hand via
    `state-write.sh`, with acyclicity confirmed by `validate-state.sh --deep`.
18. **A settings drift is repaired by making the merge self-healing, never by a migration script**
    (owner ruling, 2026-10-07). Hook entries are deduplicated by *identity* — the `hooks/NAME.sh` the
    command invokes, plus its event and type — so a changed command string is **replaced in place**
    rather than appended beside the stale one. Implemented in `merge.lua`'s `hook_identity` /
    `find_hook_match`, used by both `merge_hook_event_array` and `normalize_hook_event_array`, with a
    **mandatory carve-out**: a command not recognizable as a `.claude/hooks/*.sh` invocation is never
    matched, moved or deduped, so a hand-written hook survives untouched. Two consequences, both
    load-bearing: (a) **a hook registration must appear in a fragment surface**
    (`merge-sources/settings-hooks.json` or an extension's fragment), because a registration living
    only in install-once `root-files/settings.json` is visited by no resync and is therefore
    unreachable by this or any future correction; (b) the by-hand repair for a deploy predating the
    fix is `rm .claude/settings.json` followed by a reload — install-once copies fresh when the
    target is **absent**, whereas `deploy-headless.sh --wipe` restores its own snapshot as the merge
    base and reintroduces the staleness. Two approaches were tried and rejected before this one: a
    migration script (unnecessary once the merge converges) and a picker repair action (same).

## Standing rules

1. **Agent-system defects get filed here.** A fix in a consuming repo's `.claude/` is wiped on reload.
2. **`.claude/**` is a deploy artifact.** Edit the source store under `agent-system/extensions/**`,
   then resync. Note `settings.json` and `settings.local.json` are **install-once** — copied only
   when absent, never overwritten by a resync. A source edit to either reaches fresh deploys only;
   for hook registrations, put them in a fragment surface so the merge can reach them (Settled
   decision 18).
3. **`TODO.md` is generated from `state.json`.** Edit `description` via `state-write.sh`, then
   `generate-todo.sh`. A hand edit to `TODO.md` is wiped by the next regeneration.
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

## Unfiled observations (none worth a task yet)

- **An unowned Lua spec failure**: `manifest validate should reject manifest with invalid
  merge_targets type` fails at `lua/neotex/plugins/ai/claude/extensions/manifest_spec.lua:124`
  (expected `false`, got `true`). Confirmed pre-existing — `manifest.lua` and `manifest_spec.lua`
  are byte-identical to their pre-364 state and no 364 commit touched either. No open task addresses
  it, and `known-failures.txt` cannot carry it: that manifest is keyed to shell suites discovered by
  `run-all.sh`, so **plenary Lua specs have no known-failing baseline at all**. The gap in coverage
  is the more significant half of this observation.
- **Four open tasks carry no `title` key** (328, 338, 349, 350), so this file and `TODO.md` describe
  them from `project_name`. `orchestrate-predispatch-review.sh` Class B checks only for a *literal
  null* and misses an absent key. Belongs with **306**.
- **`TODO.md`'s tree view strips punctuation from titles**, rendering a backticked identifier as
  `SKILLVALIDATEFIXES`. The per-task detail section is correct. Cosmetic; belongs with **306**.
- **A rendered `**Goal**:` line in `TODO.md` cannot survive regeneration** and fails validation while
  present. `generate-task-order.sh --goal` writes it; `generate-todo.sh` drops it and never reads
  `active_goal`, so the displayed goal is permanently blank. Belongs with **306**.
- **Nothing represents a cross-repository prerequisite.** A task gated on another repo reads `ready`
  here and can only be caught by reading its description. 349/350 are the live instance; neither
  `validate-state.sh` nor `orchestrate-predispatch-review.sh` can see it.
- **No mechanism prevents a vault operation from leaving edges pointing at renumbered tasks**, and
  `validate-state.sh` does not check it. Today's 14 such edges all resolve archived-satisfied, but
  the 2026-08-10 reset froze 4 tasks until cleared by hand.
- **The probe's `inbound_callers` field cannot find dead code** — a script's own `manifest.json`
  entry counts as a caller, so it reports zero zero-caller scripts across 197 files. `has_test` is a
  filename-convention check and under-reports coverage. Both recorded inside **328**.
- `plan-file-scope-harvest.sh` parses a `**Files to modify**:` field and finds nothing in a plan
  using a Territory Contract table instead.
- The write-time task-reference hook fires on files in the session scratchpad; its path filter could
  exempt `/tmp/**`.
- **A loosely-scoped `subagent_type: "fork"` inherits the parent's entire task mandate** and can
  autonomously complete unrelated inherited work rather than the narrow action requested — observed
  2026-10-07. Mitigation landed in `core/docs/fork-patterns.md`; recorded because the failure mode is
  easy to re-introduce.
