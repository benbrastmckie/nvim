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

**48 open tasks**: 22 dispatchable, 0 in flight, 24 blocked by an in-repo edge, 1 externally
blocked (349, with 350 behind it), 1 held (342). If that stops matching `state.json`, this file has
drifted — it is hand-derived until **306** makes it generated.

## Gate state

- **Deploy gates are GREEN**: `verify-deploy.sh --skip-slow` exits 0 — 32 PASS, 0 FAIL, 2m22s
  (measured after 361's redeploy).
- **The orchestrator eager-context budget has NO headroom left**: 65950 B against a 65950 B
  baseline. 361 hit this ceiling mid-implementation and compressed to fit. The next
  orchestrator-surface addition must compact first; there is no slack to spend.
  `commands/orchestrate.md` 20440 B / 21000 B; `skills/skill-orchestrate/SKILL.md` 21121 B / 21500 B.
- **`validate-state.sh --deep`**: 17 passed, 0 failed, **6** warnings — 328's missing `file_scope`
  key, 349's empty array, the visibility summary reporting both, and three glob-shaped entries on
  342 that collision detection cannot see. Treat any *new* warning, and any failure, as real.
- **Gate 8 (`tests/run-all.sh`) is 92 suites and ~70% of a full `verify-deploy.sh` run.** It
  concludes under `--jobs 4`; a sequential run on a loaded host does not finish in a sane budget
  (14m1.5s sequential vs 6m47.4s at `--jobs auto`). **366** adds suite-level selection, **368**
  stops plans from demanding the full battery at a non-final phase.
- **Five suites are knowingly red**, all in `known-failures.txt` with reasons:
  `test-orchestrate-cycle-plan.sh` (**351**), `test-gate-out-repair-reporting.sh` (**352**),
  `test-lint-json-channel-discipline.sh` and `test-typst-element-lint.sh` (**353**), and
  `test-run-all-parallel.sh` (intermittent, accepted). Read the `EXPECTED`/`NEW` split, not the
  tally — a NEW failure is yours.
- **`--skip-slow` hides doc-sync pin failures.** `test-runtime-file-tracking.sh` Case 3 only runs
  under the full gate set, so a `--skip-slow` pass is not evidence the pins hold. Measured instance
  of Settled decision 15.
- **Blocking hooks currently fail OPEN whenever session cwd leaves the repo root.** Every hook is
  registered with a cwd-relative path, so an ordinary `cd` into a subdirectory silently disables
  `guard-destructive-git.sh`, `guard-git-push.sh` and four others. Observed twice on 2026-10-07.
  **364** fixes it, **365** gates it.
- **Consumer repos were all 8 STALE at last measurement (2026-10-03).** If work touches a consumer,
  run `check-consumer-freshness.sh` here and `deploy-headless.sh` **there** first; this repo never
  pushes into a consumer.

## Next

Highest value first. Each call is a single `/orchestrate` invocation; intra-batch edges sequence
the members into waves (Settled decision 17), so a call that serializes to width 1 is correct.

```
/orchestrate 364, 365        # two waves; blocking guards fail open on a bare `cd`
/orchestrate 363             # completes the shared-tree git-safety set
/orchestrate 366, 368        # two waves; test-efficiency mechanism, then the planning guidance
/orchestrate 367             # independent; why the existing auto-promotion does not fire
/orchestrate 284, 335        # two waves; the file_scope excursion gate
/orchestrate 272, 351        # two waves; 351 first
/orchestrate 351, 352, 353   # three waves; 351 MUST be in the call, not merely done first
/orchestrate 280, 311, 344   # two waves; 344's own dogfood constraint — never run it alone
/orchestrate 345, 354        # two waves
```

Why this order:

- **364 → 365** — a cwd-relative hook path makes six bare-registered blocking guards fail open,
  the opposite of the property they are registered bare to guarantee. Reproduced twice on
  2026-10-07 from ordinary navigation. Note two of 364's five scope entries are **install-once**
  (`settings.json`, `settings.local.json` are copied once and never overwritten on resync), so the
  fix cannot reach an existing deploy without the migration step the task now carries.
- **363** — the post-incident checklist. 361 corrected the rule and the guard; this records what to
  check after a destructive-git event on a shared tree, uncommitted pre-session state first.
- **366 → 368, 367** — measured: the orchestrator's own checkpoints were fixed to stop re-running
  the 92-suite battery, but *every dispatched implementation agent still re-runs it at its own
  phase gates against the identical tree*. 366 adds selection, 368 stops plans demanding `full` at
  a non-final phase, 367 removes the refused-completion round trip. Neither 366 nor 368 may weaken
  the final gate.
- **351** — the `IDENTICAL DISPATCH HALT` is implemented but never fires: a repeat-identical
  dispatch is issued anyway, the dispatch file is not backed out, the task lock stays held, and the
  counters still advance. Gates **272**, **352** and **355**.
- **284 → 335** — 335 promotes the `file_scope` excursion advisory into a staging-time gate; 284
  first exempts a task's own directory so the signal is visible rather than buried.
- **272** — the heartbeat never fires; an implementation agent sat silent for ~5h40m while the
  harness still reported it `running`. It is a structural deadlock, not a missing probe:
  `stall_suspected` is computed only *after* a dispatch returns, while Move 3 forbids postflight
  until every Move 2 call completes. The Move 3 precondition itself needs amending.
- **344** — carries batching-by-default to the point of use and mechanizes the edge backfill that
  is still a hand `state-write.sh` call. **Run it with 280 and 311 in one invocation** — its own
  dogfood constraint, not a convenience.
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
271 ready            parent_task edge: schema, validation, TODO rendering
299 ready            detect in-place plan revision concurrent with a live implement dispatch
302 ready            pass --task at commit-staging sites to engage the contended-path lease
311 ready            measured co-scheduling signal replacing static build-heavy family membership
319 ready            surface cross-task claim invalidation when research refutes a filed premise
345 ready            bound the no-op spin to a contract with a single writer
351 ready            IDENTICAL DISPATCH HALT implemented but never fires   <- priority
367 ready            why the existing post-deploy auto-promotion does not fire   <- priority
272 blocked:351      honest session liveness for concurrent same-repo batches   <- priority
273 blocked:271      three-channel conclusion stage with per-channel approval
274 blocked:272,273,275,344  next-admissible-batch suggestion and alternatives-on-conflict
275 blocked:272      per-repo orchestration queue, consumed by admission
303 blocked:271      validate-state.sh default must resolve against the repo, not CWD
304 blocked:273,284,302  one out-of-repo pathspec aborts staging; callers sink nonzero exits
312 blocked:282,344  backlog reconciliation as a required task-creation component
344 blocked:280,311  carry the batching-by-default doctrine to the point of use   <- priority
347 blocked:364      PreToolUse hook blocking self-matching process-name waiters
354 blocked:345      does the local-gate prohibition cover awaiting a dispatched subagent
355 blocked:351      unregistered test script reaches COMPLETED; count-based gate comparison
```

**Core agent system (21)**
```
251 ready            context-corpus reachability probe, then act on dead and overlapping files
280 ready            forbid record-versioning language: rule, exemptions, pattern library
284 ready            exempt a task's own directory from the file_scope excursion advisory   <- priority
306 ready            make ROADMAP.md a generated artifact
318 ready            wire lint-directory-pathspec-boundary.sh in as a numbered gate
338 ready            sweep task support files: tracked or ignored
360 ready            validate that every CARRIED-UNVERIFIED mark names a source
362 ready            teach non-destructive history-read techniques at the point of use
363 ready            post-incident checklist: uncommitted pre-session state checked first   <- priority
364 ready            cwd-relative hook paths make blocking guards fail open   <- priority
366 ready            suite-level selection within Gate 8 (--filter/--only + touched-file map)   <- priority
170 blocked:251,366  isolate shell test suites from ambient host state (memory, timing)
281 blocked:280      repo-wide record-versioning lint, blocking/advisory split
282 blocked:280,281,364  write-time PreToolUse hook blocking record-versioning language
313 blocked:306,328,344  advisory lint for hand-authored batch proposals in ROADMAP blocks
328 blocked:170,303,304,318,366  systematic script and test corpus efficiency
335 blocked:284      promote the file_scope excursion advisory into a staging-time gate   <- priority
352 blocked:351      validate-artifact.sh fix counters neither accumulate nor reset
359 blocked:350      close two agent-contract lint curated-array coverage gaps
365 blocked:364      lint forbidding CWD-relative .claude/ paths in hook registrations
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
  checkpoint. It did not, three times on 2026-10-07; **367** owns the diagnosis. Meanwhile
  `reconcile-task-status.sh <N> <session>` promotes a stranded task by hand — but only once the
  source store is actually fresh, and a *live* dispatch editing the source store keeps it stale.
- **To tell a working dispatch from a stranded one, read artifact mtimes and live child processes.**
  Absence of `.orchestrator-handoff.json` is NOT a stall signal — the research phase never writes
  one in any mode.
- **Never `cd` out of the repo root.** Hooks resolve relative to session cwd, so a `cd` into a
  subdirectory silently disables every blocking guard until **364** lands. Use absolute paths.

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

## Standing rules

1. **Agent-system defects get filed here.** A fix in a consuming repo's `.claude/` is wiped on reload.
2. **`.claude/**` is a deploy artifact.** Edit the source store under `agent-system/extensions/**`,
   then resync. Note `settings.json` and `settings.local.json` are **install-once** — copied only
   when absent, never overwritten by a resync — so a source edit to either reaches fresh deploys only.
3. **`TODO.md` is generated from `state.json`.** Edit `description` via `state-write.sh`, then
   `generate-todo.sh`. A hand edit to `TODO.md` is wiped by the next regeneration.
4. **Propose, then apply, across repos.**
5. **Verify by execution, not by reading.** Every number here was measured the day it was written;
   re-measure before acting on it.
6. **The lead never reads a report, plan, summary, description or context file during the loop.**
7. **This file describes the current plan only.** No revision history, no pass numbers.

## Unfiled observations (none worth a task yet)

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
