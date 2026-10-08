# Roadmap

*Forward-only: what remains, in what order, and the checks that gate each step. Finished work is
removed, not archived here — it lives in git history, task summaries and `specs/archive/`. Task
detail lives in `specs/TODO.md`; this file carries only ordering, gates and rulings. Measured
2026-10-08.*

## Goal

`/orchestrate` is the only lifecycle entry point, and the orchestrator is token-cheap by
construction: it delegates, reads back compact verdicts, and asks the user only when a decision is
genuinely the user's.

`MAX_TASKS` is 8, enforced in `commands/orchestrate.md`. `orchestrate-cycle-plan.sh` itself accepts
any count, so a dry-run over more than 8 is not evidence a call will run them.

**40 open tasks** (plus 7 completed awaiting `/todo` archival: 271, 272, 306, 351, 352, 353, 366).
Wave 1 holds 25, of which 21 are freely dispatchable — the remainder are 342 (held), 349
(externally blocked), and 273/275/368 currently in research. Waves 2-4 hold 15. Derive this with
`generate-task-order.sh --print`, never by hand; `306`'s generator now exists to replace the
hand-count that used to live here.

## Gate state

- **The five-known-red-suites era is over.** `known-failures.txt` carries **one** row today:
  `test-run-all-parallel.sh`, intermittent, accepted on its own rejected-alternatives record. 351,
  352 and 353 each removed their own row. Measured directly:
  `test-gate-out-repair-reporting.sh` is 21 passed / 0 failed / exit 0 standalone, so the two
  concurrent reports of it failing during this session's heavy load were load artifacts, not the
  deterministic defect they were taken for.
- **Gate 8's exit code is NOT re-measured today** and must be before "all gates green" is claimed.
  The structural blocker is gone, but gate 8 still consumes `run-all.sh`'s bare exit code rather
  than the `EXPECTED`/`NEW` split (Settled decision 13), so one intermittent red still reads as a
  failed gate. Budget ~10 min for a full `verify-deploy.sh`; a 540s cap gets SIGTERMed mid-run, and
  `--skip-slow` exits 0 without ever seeing this gate.
- **Figures below are carried, not re-measured on 2026-10-08** — re-derive before relying on them
  (Standing rule 5):
  - `verify-deploy.sh` was 33/34 PASS with gate 8 the lone survivor.
  - Gate 8 was 92 suites and ~70% of a full run (14m1.5s sequential vs 6m47.4s at `--jobs auto`);
    366's acceptance proof re-measured the battery at **123 suites**, so the 92 figure is stale.
  - `validate-state.sh --deep` was 17 passed / 0 failed / 6 warnings.
  - The orchestrator eager-context budget was at 65950 B of 65950 B — **no headroom**. 272's
    Phase 8 found and fixed a gate-20 overage, so this number moved; re-measure before adding any
    orchestrator-surface text.
- **366 landed suite-level selection**, measured: a 5-file selection ran 32 suites in 375,669 ms
  against the full 123-suite sweep's 760,286 ms (~49% of wall-clock), byte-identical across all 32
  overlapping suites. `--only SUITE[,SUITE]` is opt-in; Gate 8's own full sweep is unchanged.
- **Consumer repos were all 8 STALE at last measurement (2026-10-03).** If work touches a consumer,
  run `check-consumer-freshness.sh` here and `deploy-headless.sh` **there** first; this repo never
  pushes into a consumer. One consumer (`Philosophy/Papers/PossibleWorlds`) was repaired by hand on
  2026-10-07; the other seven were not measured since.
- **`--skip-slow` hides doc-sync pin failures.** `test-runtime-file-tracking.sh` Case 3 only runs
  under the full gate set, so a `--skip-slow` pass is not evidence the pins hold. Measured instance
  of Settled decision 15.

## Next

Each call is a single `/orchestrate` invocation; intra-batch edges sequence members into waves
(Settled decision 17), so a call that serializes to width 1 is correct. Both batches below were
`--dry-run` verified on 2026-10-08.

```
/orchestrate 367, 303, 355                  # the rest of the in-flight chain's dependents
/orchestrate 284, 363, 345, 335, 354        # excursion gate, git-safety checklist, no-op spin
/orchestrate 22, 295, 296, 360, 362         # hygiene, keymap descs, doc discipline
/orchestrate 280, 311, 344                  # 344's own dogfood constraint — never run it alone
/orchestrate 251, 299, 302, 318, 319, 338   # probe, concurrency detection, gate wiring
/orchestrate 347                            # free once THIS session's registry entry is released
/orchestrate 274                            # last of its own prerequisite chain
```

Why this order:

- **367, 303, 355 — the remainder of the in-flight chain.** 273, 275 and 368 were absorbed into the
  run that completed 271/272/306/366 and are in research as of 2026-10-08; 303 (gated on 271) and
  355 (gated on 272) are now free, and 367 heads the batch because it is the diagnosis of why the
  exit-6 promotion is unreliable. 367 defers behind any lower-numbered self-modifying candidate in
  its own batch, so expect it to take a later cycle unless run with `--allow-self-modifying`.
- **284 → 335** — 335 promotes the `file_scope` excursion advisory into a staging-time gate; 284
  first exempts a task's own directory so the signal is visible rather than buried.
- **345 → 354** — bound the no-op spin to a single-writer contract, then rule on whether the
  local-gate prohibition covers awaiting a dispatched subagent.
- **363** — the post-incident checklist: what to check after a destructive-git event on a shared
  tree, uncommitted pre-session state first.
- **280, 311 and 344 stay in one call** — 344's own dogfood constraint, not a convenience. It
  carries batching-by-default to the point of use and mechanizes the edge backfill that is still a
  hand `state-write.sh` call.
- **347** — deferred by a `manifest.json` overlap, but note *what* now defers it: as of 2026-10-08
  the reason is the live orchestration session's own registry entry covering a completed-but-
  registered task's scope, reported as `liveness: pid-alive`. That is 272's new honest-liveness
  gating working correctly, not a dependency. It clears when the session releases; no edge needed.
- **274** — the next-admissible-batch suggestion, behind the deepest chain on this list (272, 273,
  275, 344). Its prerequisites are ordered ahead of it so it becomes reachable rather than parked.

**349 and 350 are out of the near-term set** despite 349 reading `ready`. 349's prerequisite is the
approval mechanism in Logos/Verification under the slug `owner_labeled_agent_assisted_approvals`
(`not_started` when checked 2026-10-07), and 350 depends on 349. No dependency edge can express a
cross-repo prerequisite. Check that slug before dispatching either.

**342's hold**: every dependency is satisfied; the hold stands on the version stamp alone. The
consuming repository's `books/book-convention.md` line 4 reads `0.1.0-pre`, reset by owner ruling of
2026-10-06 because the review it waited on had shipped prematurely. Lift when that line reads
`0.1.0` — owner action, never an agent's. Nothing depends on 342, so queuing it parks no other work.

**An edge onto an archived task number is satisfied, not a block.** Such edges resolve as *archived
(satisfied)* in `orchestrate-predispatch-review.sh`. The hazard is a hand-derived count mistaking
them for blockers — which is why the counts above are generated, not transcribed.

## Open work

Generated view: `generate-task-order.sh --print`. Detail: `TODO.md`. The per-task roster is no
longer transcribed here — it drifted every time it was, and 306's generator exists to end that.
Read the waves from the generator and the blockers from `state.json`.

The one thing worth stating that the generator cannot: **342 is `HOLD` and 349/350 are externally
blocked**, so a wave-1 membership for any of the three is not a dispatch signal.

## Checks before and after every call

- `orchestrate-cycle-plan.sh --dry-run --state-file specs/state.json <tasks>` — **space-separated**.
  Admits what you expect; `md5sum specs/state.json` unchanged. Research and plan dispatches are
  exempt from the self-modifying defer, so overlap only serializes at implement time.
- `validate-state.sh --deep` — compare against the carried 6-warning baseline above.
- `tests/run-all.sh --jobs 4` — read the failure roster and the `EXPECTED`/`NEW` split, not the
  tally; read the exit code directly, never through `tail`/`head`. `--fail-on-new` makes it a gate.
  `--only SUITE[,SUITE]` narrows it (366) — opt-in, and never a substitute for the final gate.
- `verify-deploy.sh --skip-slow` — measure *before* your work as well as after, and compare. A
  standing red is not permission to ignore a new one. A self-modifying task is not finished until
  `.claude/` is resynced, and a resync whose verify is red is reported, not silently accepted.
- **A source-store commit without a resync is itself a red gate** — `check-extension-docs.sh`
  reports it as `deployed script content drift`.
- **A completion postflight refused with exit 6 should self-clear on the next cycle's redeploy
  checkpoint.** It is unreliable rather than inert; **367** diagnosed the cause as the promotion
  pass only ever considering the current invocation's own `task_numbers`, so a task refused in one
  run is invisible to any later run that does not re-name it. Meanwhile
  `reconcile-task-status.sh <N> <session>` promotes a stranded task by hand — but only once the
  source store is actually fresh, and a *live* dispatch editing the source store keeps it stale.
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
    `test-lint-deploy-caller-wrap.sh`; `regeneration-is-manual-only.md` still names a stale
    `commands/implement.md` that no longer exists. **367** carries the correction.
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
    *deployed* tree are not verified against a fresh deploy. 366 measured this population at 52 of
    91 narrow core suites (57.1%) and classified rather than excluded them. Narrower fix: **328**.
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
9. **A dispatch premise can go stale between task creation and dispatch.** Three of this session's
   five research dispatches found their own premise partly wrong: a named script already
   deprecated, a producer inventory over-counted, a field list matching no version of the live
   file. Re-derive the premise first; report the correction rather than implementing against it.

## Unfiled observations (none worth a task yet)

- **An unowned Lua spec failure**: `manifest validate should reject manifest with invalid
  merge_targets type` fails at `lua/neotex/plugins/ai/claude/extensions/manifest_spec.lua:124`
  (expected `false`, got `true`). Confirmed pre-existing. No open task addresses it, and
  `known-failures.txt` cannot carry it (shell suites only — Settled decision 13). The coverage gap
  is the more significant half of this observation.
- **306's new `--regenerate`/`--prune` modes have no live caller.** The `/todo`→`--prune` and
  `/review`→`--regenerate` wiring was never completed by its originally-intended dependents
  (folded into 328, which carries no edge onto 306). Needs a wiring follow-up task.
- **13 of 14 phase-heading-owning implementation agents never invoke `update-phase-status.sh`**, so
  the heartbeat reached them not at all before 272 pulsed it at the dispatch boundary instead. 272
  left an advisory lint (Check I) recording the residual per-agent gap; the per-extension migration
  is an open follow-up, deliberately scoped out of 272 (non-blocking decision, 2026-10-08).
- **Four open tasks carry no `title` key** (328, 338, 349, 350), so renderers describe them from
  `project_name`. `orchestrate-predispatch-review.sh` Class B checks only for a *literal null* and
  misses an absent key.
- **`TODO.md`'s tree view strips punctuation from titles.** 271 fixed the underscore-deleting half
  (`parenttask` → `parent_task`); the broader punctuation stripping remains.
- **A rendered `**Goal**:` line in `TODO.md` cannot survive regeneration** and fails validation while
  present. `generate-task-order.sh --goal` writes it; `generate-todo.sh` drops it and never reads
  `active_goal`, so the displayed goal is permanently blank.
- **Nothing represents a cross-repository prerequisite.** A task gated on another repo reads `ready`
  here and can only be caught by reading its description. 349/350 are the live instance; neither
  `validate-state.sh` nor `orchestrate-predispatch-review.sh` can see it.
- **No mechanism prevents a vault operation from leaving edges pointing at renumbered tasks**, and
  `validate-state.sh` does not check it. 271 wired `parent_task` into the live renumber path
  (`commands/todo.md` Step 5.7.7); `dependencies` was already handled, but nothing validates the
  result afterwards.
- **The probe's `inbound_callers` field cannot find dead code** — a script's own `manifest.json`
  entry counts as a caller, so it reports zero zero-caller scripts. `has_test` is a
  filename-convention check and under-reports coverage; 366 found and documented a further
  directory-resolution bug in it. All recorded inside **328**.
- `plan-file-scope-harvest.sh` parses a `**Files to modify**:` field and finds nothing in a plan
  using a Territory Contract table instead.
- The write-time task-reference hook fires on files in the session scratchpad; its path filter could
  exempt `/tmp/**`.
- **A loosely-scoped `subagent_type: "fork"` inherits the parent's entire task mandate** and can
  autonomously complete unrelated inherited work rather than the narrow action requested. Mitigation
  landed in `core/docs/fork-patterns.md`; recorded because the failure mode is easy to re-introduce.
