# Roadmap

*Forward-only: what remains, in what order, and the gates. Finished work is removed, not archived
here. Task detail lives in `specs/TODO.md`; this file carries ordering, gates and rulings only.
Figures carry the date measured. Last measured 2026-11-03.*

## Goal

`/orchestrate` is the only lifecycle entry point, and it is token-cheap by construction: delegate,
read back compact verdicts, ask the user only when a decision is genuinely the user's.
`MAX_TASKS` is 8, enforced in `commands/orchestrate.md`.

**60 open, 1 held, nothing mid-dispatch. 35 completed awaiting `/todo` archival** — archival is
the cheapest action available and nothing waits on it.

Counts and rosters are generated (`generate-task-order.sh --print`,
`roadmap-integration.sh --regenerate`). Never transcribe one here.

## Gate state

- **Run `deploy-headless.sh` before anything else.** `scripts/lib/project-number-inuse.sh` is in
  the source store and **absent from the deployed tree**, while `state-write.sh:170` sources it
  unconditionally. That one gap is the measured cause of Gate 5's 8 findings *and* 4 of 7 NEW
  suite failures (two suites print the missing path verbatim). One redeploy clears all of it. It
  is the pending resync of already-landed work, not a task.
- **Gate 18 is red and unowned**: 5 violations in `scripts/test-state-write-concurrency.sh`,
  landed and committed. All are fixture assertions against a synthetic state file, so the lint's
  exemption set is wrong, not the suite. Nothing tracks this.
- `verify-deploy.sh --skip-slow` 2026-11-03: **6 of 36 failed** — but 4 are gate timeouts from
  running it concurrently with the battery. Never run the two together; a contended run cannot
  distinguish a slow gate from a failing one.
- `tests/run-all.sh --jobs 4` 2026-11-03: **153 passed, 9 failed (2 expected, 7 NEW)**. All seven
  NEW were re-run in isolation: 4 are the stale deploy, 2 pass alone (contention), and **1 is
  real and unowned** — `test-orchestrate-cycle-plan.sh` fails `budget: at least one of six forced
  runs in a row was refused for budget` in isolation.
- `validate-state.sh --deep` 2026-11-03: **22 passed, 11 warnings, 0 failed**. All 11 warnings are
  coarse `file_scope` on the two whole-corpus records. No missing, null, empty or glob scopes; no
  dangling edges or cycles.
- **Gate 20 passes**: eager load 65,312 B against baseline 66,800 B. The 988 B overage record 423
  was filed against does not reproduce — both figures moved. Re-derive 423 before dispatching it.
- The gate registry carries **24** gates; next to add is **25**.
- **`known-failures.txt` carries three rows**, dispositions differing: one intermittent/accepted,
  one **`needs-owner`** (a known gap owed a follow-up task under decision 13 — none exists), one
  real-defect whose figures Gate 20 has superseded.
- **Unordered territory overlaps: 0.** 107 raw pairs remain; all are a whole-corpus record (not
  narrowable, decision 19) or a registration manifest (standing exemption).
- Corpus: `scripts=237 lines=93,523`, `test_suites=169 test_lines=81,831`,
  `md_files=930 md_lines=230,743`. This is 328's net-deletion baseline.
- CARRIED-UNVERIFIED, re-derive before use: consumer repos all 8 STALE (2026-10-03) except
  `Philosophy/Papers/PossibleWorlds`; a full `verify-deploy.sh` needs three bounded waits under
  contention, not one (2026-10-15/17); `--skip-slow` hides `test-runtime-file-tracking.sh` Case 3
  and Gate 8.

## Next

Priority is **fan-out**: how many of the other 59 records a record transitively gates, measured
2026-11-03 from `specs/state.json`. It is not urgency or effort. Four tiers:

| Tier | Gates | Records |
|------|-------|---------|
| **P0** | 13-26 each | 275, 274, 378, 387, 407, 328 (+429 as 328's instrument) |
| **P1** | 8-12 each | 414, 415, 419, 418, 385, 428, 430 |
| **P2** | 1-7 each | 26 records |
| **P3** | 0 | 21 leaves — deferrable indefinitely without blocking anything |

**The single most important fact on this page: `275` gates 26 of the other 59 records, and it is
ready now** — its research landed and is linked. The chain `275 -> 274 -> 378 -> 387 -> 407` gates
36 records between them. Nothing else comes close, and no amount of leaf work substitutes for it.

**35% of the backlog is leaves.** P3 blocks nothing. If time is short, P0 and P1 are the backlog;
P3 is optional.

```
/orchestrate 282, 312   # OWNER OVERRIDE, runs first: stop the backlog growing duplicates
/orchestrate 275, 274, 378, 387, 407   # P0 keystone: gates 36 of 59 records, width 1 by construction
/orchestrate 429, 328   # P0: fix the measurement instrument, then the consolidation it measures
/orchestrate 414, 415, 419, 418, 445, 444   # P1 verification spine: verify-deploy and shell-script-testing
/orchestrate 385, 397, 398, 399, 428, 430, 401, 409   # P1 tail plus lean research chain, off core territory
/orchestrate 22, 29, 369, 391, 390, 402, 338   # loader chain, task siting, conclusion stage
/orchestrate 435   # whole-corpus reword: alone, per-class and per-site, blanket substitution forbidden
/orchestrate 446, 448, 360, 313, 431, 459, 458   # the consolidation record's consumers
/orchestrate 421, 436, 438, 439, 454, 420, 449, 452   # creation-gate consumers and command surfaces
/orchestrate 450, 451, 455, 457, 453, 408, 410, 412   # P3 bulk, all edges satisfied above
/orchestrate 423, 437, 456, 383, 384   # P3 leaves: nothing depends on any of them
```

Why this order:

- **Call 1 is an owner override of the fan-out ranking, and the override is the point.** Both
  members are P2 by fan-out (3 and 2), so strict ranking buried them at call 8. But fan-out
  measures what a record *unblocks*, not what the backlog *costs*: 312 is the creation-time gate
  that compares a proposed task against every existing record before it is written, and until it
  lands, every call below can add duplicates faster than the calls drain them. The one measurement
  available says the rate is high — of eight proposals a conclusion stage put to the user,
  **five already had open records covering them**, caught only by a hand check. 282 leads because
  312 declares an edge onto it (the bare-registration pattern a blocking hook needs). Nothing else
  gates 312, so this call is dispatchable immediately.
- **Its scope now includes closed records** (owner decision): 380 archived plus 35 completed
  awaiting archival are invisible to an open-only matcher, and the manual convention it replaces
  already checks the archive — at least three open records carry a hand-written "No active or
  archived record covers this". Open-only would have been a regression against current practice.
  Two constraints carried in the records: an open match and a closed match are different verdicts
  (the first actionable on the task graph, the second on the discharging artifact), and a closed
  match must never auto-suppress a proposal, because a concern can legitimately recur after the
  record addressing it closed.
- **Call 2 is the keystone chain and width 1 is the point, not a flaw.** Fan-outs 26/21/20/17/13,
  one territory (orchestrate machinery), pre-existing edges throughout. Run it even though it is
  slow; it unblocks 36 records.
- **Call 3 pairs the instrument with its consumer, under an edge.** `script-inventory.sh`
  enumerates via `git ls-files`, so an unstaged new file is invisible and the running net-deletion
  figure is biased *favourably* — the one direction a net-deletion criterion cannot tolerate. 328's
  own plan carries a hand workaround for this, which is evidence the defect is live. 14 of 328's
  20 phases are unrun; fixing the instrument first is cheap, after is a re-measure. Both declare
  `script-inventory.sh`, so an edge orders them rather than a comment.
- **328 will not finish in one invocation.** 20 phases, 6 terminal, 5-cycle budget. Expect three
  or four invocations; `MAX_CYCLES reached` is not a failure here. It runs with only its
  instrument because its 126 scope entries overlap 32 records (decision 19).
- **Calls 4-5 are the verification layer.** `414 -> 415 -> 445 -> 444` serializes on
  `verify-deploy.sh` and `tests/run-all.sh`; `419 -> 418` on the state-writer lint and
  `shell-script-testing.md`. 419 needs 275, which call 1 drains. Call 4 adds the lean research
  chain, territory-disjoint from core.
- **Call 6 is the loader chain.** `22 -> 29 -> 369 -> 391 -> 390` on `init.lua`/`merge.lua` then
  `source-store-deploy-boundary-narrative.md`, so the authoring hole closes before mis-sited
  records migrate through it. 402 joins at the tail once 391 lands.
- **Call 7 runs the reword alone**: 83 scope entries over 1,628 references in 360 files, with a
  blanket find-and-replace forbidden by the record itself.
- **Call 9 consumes call 1's matcher, and that coupling is the thing to get right.** Two of its
  members (the `/distill --meta` retargeting and the edge-rationale check) depend on the shared
  matcher call 1 builds, and both now carry the cross-reference. The ruling left open there —
  whether consuming it is *mandatory* for a surface rendering *proposals* rather than attempting a
  *creation* — is named in both records, not assumed. The hazard if it is ignored: two
  concern-matchers with two fixtures, which is the duplicate-mechanism outcome the matcher exists
  to prevent, reproduced inside the deduplication machinery.
- **Calls 10-11 are leaves.** Nothing depends on them. Reorder or defer freely.

**Verified mechanically 2026-11-03**: 59 of 60 open records named once each, none over
`MAX_TASKS`, and every record's open blockers land in an earlier call or its own. The omission is
the held record. **Not verified: admission** — no call is dry-run checked, so a `MAX_TASKS` trim
or self-modifying defer could reshape any of them. Re-derive with `--dry-run` (Standing rule 5).

**The held record** (books corpus refactor): every dependency satisfied; the hold is a version
stamp alone. The consuming repo's `books/book-convention.md` line 4 reads `0.1.0-pre`. Lift when
it reads `0.1.0` — owner action, never an agent's. Nothing depends on it.

**One scope worth narrowing first**: the mis-sited-records migration declares `specs/state.json`
and `specs/TODO.md` (call 5), which every task writes, so it overlaps everything.
**Coverage appendix (uncovered tasks)**:
```
/orchestrate 464,466,469,470,473
```

## Open work

**Core agent system (29)**
```
313 blocked:328,387,401  Advisory lint for hand-authored /orchestrate batch proposals in ROADMAP....
328 blocked:429     systematic_script_and_test_corpus_efficiency
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
461 blocked:328,430,435,446,448  Rule on and close the V7 refusal of a positive directory pathspe...
465 blocked:328     check-record-versioning.sh PATH_SCOPE mode reports false-clean on a file pres...
471 blocked:470     Lint the extensions README table against the real extension directory set
474 blocked:431     Repair the broken relative links in agent-frontmatter-standard.md
410 ready           Close the result-sharing replay hole in lake-build-guard.sh: gate sharing on ...
423 ready           Resolve test-verify-deploy-context-budget.sh's eager-load baseline drift (mea...
429 ready           script_inventory_undercounts_untracked_files
456 ready           tag_version_gate_unpassable_for_private_manifest
459 ready           Design cross-record traceability; verdict on CHANGE_LOG retirement
464 ready           Make a plan's per-phase line estimates checkable against a line ceiling the s...
469 ready           Allowlist engine-written infrastructure paths in the file_scope Containment s...
470 ready           Clarify verify-deploy.sh TARGET contract versus its invocation-directory claim
473 ready           Strip record-versioning language from the boundary-owned architecture docs
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

**Lean extension (8)**
```
398 blocked:397     Record that a grep for dependents misses rw-site definitional unfolding, and ...
399 blocked:398     Record three measured lean4 gotchas: IO-forced timing harnesses, docstring/se...
451 blocked:385,420,435  Take the Lean Challenge snapshot in the plan phase, where it is still me...
462 blocked:385,451 Give lean-challenge-snapshot.sh --check a scope limit so a research prototype...
463 blocked:412     State that lean_goal's empty goals_after is not evidence a declaration elabor...
385 ready           Define the sanctioned shape for a lean4-typed plan that commits to no theorem...
397 ready           Require a lean research report's recommended compiled artifact to be compile-...
412 ready           lean_tier_vocabulary_to_build_scope_mapping
```

**Orchestrator (12)**
```
274 blocked:275     Next-admissible-batch suggestion and alternatives-on-conflict, both computed ...
378 blocked:274     Resolve the reviser-agent handoff contract contradiction between skill-orches...
387 blocked:378     Teach the batch admission gate that a whole-tree regeneration phase is an imp...
402 blocked:391     Conclusion stage Step 4c allocates no task number and creates no task directo...
407 blocked:378,387 Derive a task's next artifact round from its existing artifacts instead of de...
409 blocked:378,387,401,407  Advise at admission when a task's declared file_scope already holds ...
428 blocked:378     Enforce and detect planner-agent terminal return-meta write
449 blocked:328,360,407,414,444,445,446,448  Site the Batch Gate Deferral directive where it is r...
450 blocked:274,275,328,360,378,407,420,435,448,449  Require a settled user-decision route to nam...
472 blocked:328,378,428,435  Stop validate-handoff.sh aborting on a string-shaped blockers array,...
275 ready           Per-repo orchestration queue: registered, live, archived on finish, and consu...
466 ready           validate-wiring.sh reports Missing context file for context paths present on ...
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
438 blocked:313,401,446,458  Dependency edges conflate semantic and serialization rationale, ...
414 ready           Enforce the gate verdict-line extraction contract mechanically
```

## Checks before and after every call

- `orchestrate-cycle-plan.sh --dry-run --state-file specs/state.json <tasks>` — space-separated.
  Admits what you expect; `md5sum specs/state.json` unchanged.
- `validate-state.sh --deep` — measure before your work too; today's baseline is 22/11/0.
- `tests/run-all.sh --jobs 4` — read the `EXPECTED`/`NEW` split and the roster, not the tally;
  read the exit code directly, never through `tail`/`head`.
- `verify-deploy.sh --skip-slow` — before and after, and compare. **Never concurrently with the
  battery.** A standing red is not permission to ignore a new one.
- A source-store commit without a resync is itself a red gate.
- A completion postflight refused with exit 6 self-clears on the next redeploy checkpoint, but
  the promotion pass only sees the current invocation's `task_numbers`; a task refused in one run
  is invisible to later runs. `reconcile-task-status.sh <N> <session>` promotes it by hand, and
  only once the source store is fresh.
- To tell a working dispatch from a stranded one, read artifact mtimes and live child processes.
  Absent `.orchestrator-handoff.json` is NOT a stall signal — research never writes one.
- Edges go through `state-write.sh`, acyclicity confirmed afterwards by `validate-state.sh --deep`.
  `update-task-status.sh --depends-on-add` cannot reach a `not_started` task.
- Verify a settings-merge change against a real stale deploy, never a synthetic fixture.

## Settled decisions (do not re-litigate)

1. **Batch of one.** One engine; single-task is a batch of one. Team mode deleted; hard mode kept, per-invocation.
2. **The orchestrator never asks and never decides.** Only an agent-surfaced `user_decision` reaches the user, once, at cycle end. `blocking: false` proceeds on the agent's recommendation.
3. **Research-first is the default** for a fresh task; `--fast` restores planner-first.
4. **`--dry-run` prints the plan it would dispatch.** No separate dry-run report.
5. **No fixed consumer validation gates.** The checks above are recommended, not blocking.
6. **A linear chain of small tasks serializing on one file is one task with phases** — at creation time, and applied late when it was not. The evidence-discipline record is three folded phases for this reason.
7. **`file_scope` warnings are live input.** In-batch collisions block, cross-batch are advisory. Decision 17 does not weaken this: an *unordered* overlapping pair shares a wave and writes concurrently.
8. **Rule before mechanism** for the vimtex hazard.
9. **Skeleton plans terminate through the completion-claim gate.** No `pr_ready` outside `type=pr`.
10. **No third automated deploy-trigger site.** Exactly two: `command-gate-out.sh` + `orchestrate-cycle-plan.sh`, per `test-lint-deploy-caller-wrap.sh`.
11. **One grant mechanism.** A single-use token bound to action, remote, branch and sha, minted only where the harness can prove the user typed it. Nothing the model writes is a grant. PR/MR creation and `/merge` stay user-only.
12. **A grant may authorize a plain push of the default branch.** Every force form on the default branch, bare `--force` anywhere, and all bulk/deletion refspecs stay excluded, checked before any grant lookup.
13. **`known-failures.txt` is the only known-failing list.** Advisory; never changes which suites run. Never keep a prose copy elsewhere. A `needs-owner` row is a known gap owed a follow-up task. **Shell suites only** — plenary Lua specs have no baseline at all.
14. **One shared working tree, always.** Per-dispatch `git worktree` isolation removed, not narrowed. Safety rests on `file_scope`, edges and the five contention inputs; build contention is closed by refusing to co-schedule two build-heavy implement tasks. Cost was not the reason and must not be cited as it. Record: `specs/decisions/worktree-isolation-removal-verdict.md`.
15. **Gate 8's deployed-tree coverage is knowingly reduced** on wall-clock grounds: the redeploy checkpoint runs `--skip-slow`, so suites resolving from the *deployed* tree are unverified against a fresh deploy — 52 of 91 narrow core suites (57.1%), classified not excluded. Narrower fix: 328.
16. **A systemic cost is filed as one standing task against a probe's output**, not a stream of point defects. Duplication, dead code and slow tests never break anything, so defect-driven intake cannot see them. 328 is the standing consumer of `script-inventory.sh`.
17. **An unordered territory overlap is resolved by adding the edge, not by separating the pair** (owner ruling). Width 1 is a correct outcome; the property defended is collision visibility and ordering, never wall-clock. A "never with" note is not an acceptable rendering, and a bare exclusion must never stand in for an edge nobody added. Carve-outs: (a) an owner-blocked predecessor that cannot progress — separate and state why; (b) breadth — narrow the `file_scope` instead, except where decision 19 applies.
18. **Settings drift is repaired by making the merge self-healing, never by a migration script** (owner ruling). Hook entries dedupe by *identity* — the `hooks/NAME.sh` invoked, plus event and type — so a changed command string is replaced in place. Mandatory carve-out: a command not recognizable as a `.claude/hooks/*.sh` invocation is never matched, moved or deduped. Consequences: (a) a hook registration must live in a fragment surface, since one living only in install-once `root-files/settings.json` is reachable by no resync; (b) the repair for a deploy predating the fix is `rm .claude/settings.json` then reload — `--wipe` restores its own snapshot as the merge base and reintroduces the staleness.
19. **A whole-corpus record runs alone, and its coarse `file_scope` is not a defect to narrow** (owner ruling). Where the territory is directory roots spanning the corpus because the work does, decision 17(b) has nothing to narrow to. Its overlap warnings are correct output: they are what identifies it as a bottleneck.
20. **A near-duplicate record is folded, not merely ordered** (owner ruling). The survivor absorbs the other's text **verbatim**, every edge is re-pointed **before** archiving, and the folded record names the survivor and the grounds. A record whose obligation a landed artifact already discharges is abandoned citing that artifact, not left open as a reminder.

## Standing rules

1. **Agent-system defects get filed here.** A fix in a consuming repo's `.claude/` is wiped on reload.
2. **`.claude/**` is a deploy artifact.** Edit `agent-system/extensions/**`, then resync. `settings.json` and `settings.local.json` are **install-once** — copied only when absent; put hook registrations in a fragment surface (decision 18).
3. **`TODO.md` is generated from `state.json`.** Edit `description` via `state-write.sh`, then `generate-todo.sh`. Same for this file's counts and rosters — generate them.
4. **Propose, then apply, across repos.**
5. **Verify by execution, not by reading.** Re-measure before acting. *CARRIED-UNVERIFIED* figures were not re-measured and must be re-derived.
6. **The lead never reads a report, plan, summary, description or context file during the loop.**
7. **This file describes the current plan only.** No revision history, no pass numbers.
8. **A scope cut justified by an unverified premise is not a scope cut.** Test the premise before dropping the work it would make unnecessary.
9. **A dispatch premise can go stale between creation and dispatch.** Measured twice: three of five research dispatches found their premise partly wrong (2026-10-08); a record's entire figure pair had moved and its gate now passes (2026-11-03). Re-derive first; report the correction rather than implementing against it.
10. **A redundancy census is re-derived, never remembered.** Fan-out, unordered-overlap counts and duplicate readings all change with every edge and every closure. Compute from `state.json` plus `scripts/lib/file-scope-overlap.sh` with transitive closure as the ordering test.

## Unfiled observations (none worth a task yet)

- **Gate 18's 5 violations have no owner** — the closest thing here to warranting a record; the gate is red today.
- **`test-orchestrate-cycle-plan.sh`'s budget failure is real and uncharacterized** — reproduces in isolation, no `known-failures.txt` row, no record.
- **328's `status` under-reports**: `planned` while its plan shows 6 of 20 phases terminal. A 20-phase plan against a 5-cycle budget is 420's subject, now measured on a live plan.
- **328 declares `.claude/` in its own `file_scope`** — a disposable deploy artifact Standing rule 2 forbids editing, and a path that overlaps every task.
- **459's `file_scope` names only its own `specs/` directory**, so it is invisible to overlap detection though its verdict gates two records. Nothing represents "this record's output constrains that record's design" except an edge.
- **A research dispatch sat stranded 26 days** — status `researching`, terminal `.return-meta.json` and a finished report on disk, never promoted or linked. Recovered by hand 2026-11-03; a sweep found no second instance. There is no periodic reconciliation, only an on-demand one nobody is scheduled to run.
- **A dispatched agent can end its turn with a backgrounded command pending**, leaving no handoff and no return metadata; nothing auto-detects "stopped without returns" (the re-prompt path triggers off a postflight `failed` verdict, so reaching it costs a recorded failure first). **Two states look alike**: an agent waiting on its own live child still takes tool rounds, so a message recovers it; a stranded agent takes none, so recovery is stop, postflight, re-dispatch at the same `dispatch_seq`. Check for a live child first. 2 of 8 implement dispatches on one run (2026-10-17, CARRIED-UNVERIFIED). Detector: `dispatch-strand-probe.sh`, via `context/patterns/task-lock.md`.
- **A provenance citation can name another record's issue entry.** One record claimed a sibling's entry and asserted "one concern"; they shared only a `dispatch_seq` and severity. Corrected. A false consolidation line is worse than a missing citation — it invites a dispatch to absorb a sibling's work.
- **9 open records carry a literal-null `title`**, so renderers fall back to `project_name`. `orchestrate-predispatch-review.sh` Class B has been seen reporting 0 findings against one; re-read its predicate before filing.
- **`--depends-on-add` cannot reach a `not_started` task** (re-confirmed 2026-11-03) and there is no edge-REMOVAL flag at all. Worth a task: a `map_status()` arm for `not_started` plus an explicit edge-only add/remove.
- **Neither `/todo` nor `/review` wires the roadmap generator to its own command.** `--prune` and `--regenerate` are still run by hand. Note 436 retires `/review`, so whatever wires `--regenerate` should wire it to the survivor.
- **`roadmap-integration.sh --prune` misparses a Run line whose trailing comment is 2 spaces away** (needs >=3). Every Run line here is authored with three for that reason. Fail-safe (retains, warns) but depends on authored whitespace. Normalize the separator *and* fix the predicate.
- **`plan-file-scope-harvest.sh` silently under-harvests** on three measured plan shapes: a Territory Contract table instead of the field, a trailing italic on the label, and a glob entry. One repair moved a plan from 56 to 123 paths. Every miss is silent, and an under-harvested scope is what drops real work from a phase commit.
- **An unowned Lua spec failure**: `manifest_spec.lua:124`, invalid `merge_targets` type expected `false` got `true` (CARRIED-UNVERIFIED 2026-10-17). `known-failures.txt` cannot carry it (shell only); the coverage gap — Lua specs have no baseline at all — is the larger half.
- **13 of 14 phase-heading-owning implementation agents never invoke `update-phase-status.sh`**; the heartbeat reaches them only via the dispatch boundary. Lint Check I records the gap (CARRIED-UNVERIFIED 2026-10-17).
- **Nothing represents a cross-repository prerequisite.** A task gated on another repo reads `ready` here. The held books record is in exactly that state, so the gap is live.
- **Nothing prevents a vault operation leaving edges on renumbered tasks.** `parent_task` and `dependencies` are handled in the renumber path; nothing validates the result.
- **`TODO.md`'s tree view strips punctuation from titles** (the underscore half is fixed).
- **A rendered `**Goal**:` line in `TODO.md` cannot survive regeneration** and fails validation while present; `generate-todo.sh` never reads `active_goal`, so the displayed goal stays blank.
- **A loosely-scoped `subagent_type: "fork"` inherits the parent's entire mandate.** Mitigation in `core/docs/fork-patterns.md`; recorded because it is easy to re-introduce.
- The write-time task-reference hook fires on scratchpad files; its filter could exempt `/tmp/**`.
