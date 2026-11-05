# Roadmap

*Forward-only: what remains, in what order, and the gates. Finished work is removed, not archived
here. Task detail lives in `specs/TODO.md`; this file carries ordering, gates and rulings only.
Figures carry the date measured. Last measured 2026-11-04.*

## Goal

`/orchestrate` is the only lifecycle entry point, and it is token-cheap by construction: delegate,
read back compact verdicts, ask the user only when a decision is genuinely the user's. `MAX_TASKS`
is 8, enforced in `commands/orchestrate.md`.

Counts and rosters are generated (`generate-task-order.sh --print`,
`roadmap-integration.sh --regenerate`, `orchestrate-suggest-next-batch.sh --next-batch`). Never
transcribe one here. As of 2026-11-04: **72 open (1 held), 44 completed awaiting `/todo`
archival** — archival is the cheapest action available and nothing waits on it.

## Gate state

Measured 2026-11-04 unless marked.

- **Gate 8 is red: 7 shell suites**, tracked by record 476. Five were proven to fail identically
  on unmodified `master` via `git stash push`; two are `EXPECTED`-baselined by `run-all.sh`
  itself. A standing red Gate 8 destroys the signal value of the full gate for every later task,
  which is the real cost.
- **Gate 16 is red**: `routing_hard`/`routing_agents_hard` still declared. Record 444 owns it and
  corrects the premise — **three** extensions declare the key (books, cslib, lean), and
  `hard_contracts` exists in no manifest yet.
- **Gate 20 passes**, with no durable headroom: eager load 65,312 B against baseline 66,800 B, but
  the per-file margins are 4 B (`commands/orchestrate.md`, 21,496/21,500) and 307 B
  (`skills/skill-orchestrate/SKILL.md`, 24,693/25,000). Any ordinary addition to either re-fires
  the gate. Prefer a relocation trim over another ceiling move; both ceilings moved on 2026-11-04.
- **`validate-state.sh --deep`: 0 failed, 13 warnings.** Every warning is coarse `file_scope` on a
  whole-corpus record (decision 19 — correct output, not a defect). No missing, null, empty or
  glob scopes; no dangling edges or cycles.
- **Never run `verify-deploy.sh` concurrently with the battery.** A contended run cannot
  distinguish a slow gate from a failing one; four gate timeouts were misread this way on
  2026-11-03.
- A source-store commit without a resync is itself a red gate.

## Next

Priority is **fan-out**: how many other open records a record transitively gates. It is not
urgency or effort, it changes with every edge and closure, and it is re-derived, never remembered
(standing rule 10). Re-derive with `generate-task-order.sh --print`.

Two measured keystones dominate: **328 directly gates 14 open records**, **435 gates 8**. Nothing
else is close.

```
/orchestrate 429, 328   # P0: fix the measurement instrument, then the consolidation it measures
/orchestrate 435   # whole-corpus reword: alone, per-class and per-site, blanket substitution forbidden
/orchestrate 385, 397, 423, 469, 470   # lean keystone plus narrow core; admission-probed 2026-11-04
/orchestrate 410, 412, 456, 464, 466, 473   # ready, no inbound edges
/orchestrate 414, 415, 445, 444, 419, 418   # verification spine: verify-deploy and shell-script-testing
/orchestrate 428, 430, 401, 409   # orchestrator tail
/orchestrate 22, 29, 369, 391, 390, 402, 338   # loader chain, task siting, conclusion stage
/orchestrate 446, 448, 360, 313, 431, 459, 458   # the consolidation record's consumers
/orchestrate 475, 476, 477, 478   # audit-gate hole, red Gate 8, class vocabulary, lint Check J
/orchestrate 398, 399, 463, 465, 471, 472, 474   # lean research chain tail, plus 328/431/470 consumers
/orchestrate 421, 436, 438, 439, 454, 420, 449, 452   # creation-gate consumers and command surfaces
/orchestrate 450, 451, 455, 457, 453, 461, 462, 479   # edges satisfied above
/orchestrate 480, 481, 408, 437, 383, 384   # leaves and tail: nothing further depends on them
```

Why this order:

- **Call 1 pairs the instrument with its consumer, under an edge.** `script-inventory.sh`
  enumerates via `git ls-files`, so an unstaged new file is invisible and the running net-deletion
  figure is biased *favourably* — the one direction a net-deletion criterion cannot tolerate.
  Fixing the instrument first is cheap; after is a re-measure. Both declare `script-inventory.sh`,
  so an edge orders them rather than a comment.
- **328 will not finish in one invocation.** 20 phases, 6 terminal, 5-cycle budget; expect three
  or four. `MAX_CYCLES reached` is not a failure here. It runs with only its instrument because
  its 126 scope entries overlap most of the backlog (decision 19) — every narrow core and lean
  record probed on 2026-11-04 came back carrying an idle-overlap advisory against it. Anything run
  before it churns ground it is planned to consolidate.
- **Call 3 is admission-verified**, not merely authored: 385, 397, 423 and 469 all `admit`; 470
  defers one cycle behind 469 on the self-modification ordering constraint, which is automatic
  sequencing, not an exclusion. 385 is the lean keystone (gates 451 and 462); 423 attacks the
  standing-red Gate 8.
- **Call 5 is the verification layer.** `414 -> 415 -> 445 -> 444` serializes on
  `verify-deploy.sh` and `tests/run-all.sh`; `419 -> 418` on the state-writer lint and
  `shell-script-testing.md`.
- **Call 7 is the loader chain.** `22 -> 29 -> 369 -> 391 -> 390` on `init.lua`/`merge.lua` then
  `source-store-deploy-boundary-narrative.md`, so the authoring hole closes before mis-sited
  records migrate through it. 402 joins at the tail once 391 lands.
- **Calls 10-13 are downstream or leaves.** Reorder or defer freely within them.

**Not admission-verified**: every call except call 1 and call 3. A `MAX_TASKS` trim or a
self-modifying defer could reshape any of them — re-derive with `--dry-run` (standing rule 5), or
let `orchestrate-suggest-next-batch.sh --next-batch` propose a set the real admission script
actually admits.

**The held record** (books corpus refactor): every dependency satisfied; the hold is a version
stamp alone. The consuming repo's `books/book-convention.md` line 4 reads `0.1.0-pre`. Lift when
it reads `0.1.0` — owner action, never an agent's. Nothing depends on it.

**One scope worth narrowing first**: the mis-sited-records migration declares `specs/state.json`
and `specs/TODO.md`, which every task writes, so it overlaps everything.
**Coverage appendix (uncovered tasks)**:
```
/orchestrate 482
```

## Open work

**Core agent system (33)**
```
328 IN FLIGHT       systematic_script_and_test_corpus_efficiency
313 blocked:328,401 Advisory lint for hand-authored /orchestrate batch proposals in ROADMAP.md ph...
360 blocked:328,385,428,446  Evidence discipline for report and plan artifacts, in three phases: ...
369 blocked:29      Orphan sweep for deployed entries removed from the source store: the deploy a...
421 blocked:402     retarget_distill_meta_as_evidence_consumer
431 blocked:328     Record the gate-enforced verbatim-duplication exclusion class as durable agen...
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
475 blocked:435     Close the audit-evidence gate internal --argjson hole: a large verdict dies w...
476 blocked:423,445 Make the seven untracked red Gate 8 shell suites green or declared-expected
479 blocked:360     Require every task to name a landing target: a creation-time gate on report-o...
480 blocked:479     Advisory detector for research tasks stranded at RESEARCHED with artifacts bu...
338 ready           sweep_task_support_file_tracked_or_ignored
410 ready           Close the result-sharing replay hole in lake-build-guard.sh: gate sharing on ...
423 ready           Resolve test-verify-deploy-context-budget.sh's eager-load baseline drift (mea...
435 ready           Reword architectural and phase-versus-command prose naming the three deleted ...
456 ready           tag_version_gate_unpassable_for_private_manifest
459 ready           Design cross-record traceability; verdict on CHANGE_LOG retirement
464 ready           Make a plan's per-phase line estimates checkable against a line ceiling the s...
469 ready           Allowlist engine-written infrastructure paths in the file_scope Containment s...
470 ready           Clarify verify-deploy.sh TARGET contract versus its invocation-directory claim
473 ready           Strip record-versioning language from the boundary-owned architecture docs
478 ready           Make lint Check J fail on a missing handoff-writer section instead of skippin...
```

**Extensions (7)**
```
342 HOLD            Refactor the books extension's context corpus against the settled convention:...
29 blocked:22       Generate .mcp.json from extension manifests, then register obsidian-memory th...
384 blocked:383     Adjudicate whether a books reconciliation postflight lifecycle hook is warran...
457 blocked:446,455 Repo-specific content has leaked into the shared agent-system source store
383 ready           Add a /reconcile command to the books extension: aggregate docs-stage.sh and ...
408 ready           Gate the formal extension's mandatory Mathlib-lookup step on an actual Lean t...
482 ready           create_sapience_extension
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
446 blocked:328,385,430  Close the plan-to-file_scope reconciliation gap and make a containment d...
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

**Orchestrator (8)**
```
402 blocked:391     Conclusion stage Step 4c allocates no task number and creates no task directo...
409 blocked:401     Advise at admission when a task's declared file_scope already holds uncommitt...
449 blocked:328,360,414,444,445,446,448  Site the Batch Gate Deferral directive where it is read ...
450 blocked:328,360,420,435,448,449  Require a settled user-decision route to name the obligation...
472 blocked:328,428,435  Stop validate-handoff.sh aborting on a string-shaped blockers array, and...
428 ready           Enforce and detect planner-agent terminal return-meta write
466 ready           validate-wiring.sh reports Missing context file for context paths present on ...
477 ready           Normalize issue-log class vocabulary and reject the aggregate's malformed rep...
```

**Agent system (10)**
```
390 blocked:391     Migrate seven mis-sited agent-system tasks out of BimodalLogic and retire one...
391 blocked:369     Close the target_root authoring hole that files agent-system tasks into the w...
415 blocked:414     Record exact-pid process checking as a parallelism-safety suite-authoring sta...
418 blocked:415,419 Make the lint-fixture-test family subject resolution explicit and self-declaring
420 blocked:409,418 Surface a plan-size versus per-run cycle-budget mismatch before a run hits th...
438 blocked:313,401,446,458  Dependency edges conflate semantic and serialization rationale, and ...
481 blocked:390     Rule on and migrate the 32-record mis-sited agent-system task delta accumulat...
401 ready           Two repositories file against one source store with no cross-repo overlap or ...
414 ready           Enforce the gate verdict-line extraction contract mechanically
419 ready           Extend the state-writer boundary lint to the Python JSON re-serialization cha...
```

Ready now and unblocked, 2026-11-04: **core** 410, 423, 429, 456, 459, 464, 469, 470, 473, 477,
478; **lean** 385, 397, 412; **orchestrator** 414, 428, 466; **extensions** 383, 408; **literature**
437; **neovim** 22. Newly unblocked by the 2026-11-04 run: 428 (on 378), 435 (on 407).

## Checks before and after every call

- `orchestrate-cycle-plan.sh --dry-run --state-file specs/state.json <tasks>` — space-separated.
  Admits what you expect; `md5sum specs/state.json` unchanged.
- `validate-state.sh --deep` — measure before your work too; today's baseline is 0 failed, 13 warnings.
- `tests/run-all.sh --jobs 4` — read the `EXPECTED`/`NEW` split and the roster, not the tally; read
  the exit code directly, never through `tail`/`head`.
- `verify-deploy.sh --skip-slow` — before and after, and compare. **Never concurrently with the
  battery.** A standing red is not permission to ignore a new one.
- A completion postflight refused with exit 6 self-clears on the next redeploy checkpoint, but the
  promotion pass only sees the current invocation's `task_numbers`; a task refused in one run is
  invisible to later runs. `reconcile-task-status.sh <N> <session>` promotes it by hand, and only
  once the source store is fresh.
- To tell a working dispatch from a stranded one, read artifact mtimes and live child processes.
  Absent `.orchestrator-handoff.json` is NOT a stall signal — research never writes one.
- Edges go through `state-write.sh`, acyclicity confirmed afterwards by `validate-state.sh --deep`.
  `--depends-on-add` cannot reach a `not_started` task, and there is no edge-removal flag at all.
- If a dead owner holds `specs/.gate-lock`, release it by its own token
  (`task-lock.sh gate-release <token>`). Gate 8 now traps `INT`/`TERM`/`HUP`, so only `SIGKILL`
  leaks it, self-healing after 1800 s.

## Settled decisions (do not re-litigate)

1. **Batch of one.** One engine; single-task is a batch of one. Team mode deleted; hard mode kept, per-invocation.
2. **The orchestrator never asks and never decides.** Only an agent-surfaced `user_decision` reaches the user, once, at cycle end. `blocking: false` proceeds on the agent's recommendation.
3. **Research-first is the default** for a fresh task; `--fast` restores planner-first.
4. **`--dry-run` prints the plan it would dispatch.** No separate dry-run report.
5. **No fixed consumer validation gates.** The checks above are recommended, not blocking.
6. **A linear chain of small tasks serializing on one file is one task with phases** — at creation time, and applied late when it was not.
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
18. **Settings drift is repaired by making the merge self-healing, never by a migration script** (owner ruling). Hook entries dedupe by *identity* — the `hooks/NAME.sh` invoked, plus event and type. Mandatory carve-out: a command not recognizable as a `.claude/hooks/*.sh` invocation is never matched, moved or deduped. Consequences: (a) a hook registration must live in a fragment surface, since one living only in install-once `root-files/settings.json` is reachable by no resync; (b) the repair for a deploy predating the fix is `rm .claude/settings.json` then reload — `--wipe` restores its own snapshot as the merge base and reintroduces the staleness.
19. **A whole-corpus record runs alone, and its coarse `file_scope` is not a defect to narrow** (owner ruling). Where the territory is directory roots spanning the corpus because the work does, decision 17(b) has nothing to narrow to. Its overlap warnings are correct output: they are what identifies it as a bottleneck.
20. **A near-duplicate record is folded, not merely ordered** (owner ruling). The survivor absorbs the other's text **verbatim**, every edge is re-pointed **before** archiving, and the folded record names the survivor and the grounds. A record whose obligation a landed artifact already discharges is abandoned citing that artifact, not left open as a reminder.

## Standing rules

1. **Agent-system defects get filed here.** A fix in a consuming repo's `.claude/` is wiped on reload.
2. **`.claude/**` is a deploy artifact.** Edit `agent-system/extensions/**`, then resync. `settings.json` and `settings.local.json` are **install-once** — copied only when absent; put hook registrations in a fragment surface (decision 18).
3. **`TODO.md` is generated from `state.json`.** Edit `description` via `state-write.sh`, then `generate-todo.sh`. Same for this file's counts and rosters — generate them.
4. **Propose, then apply, across repos.**
5. **Verify by execution, not by reading.** Re-measure before acting. *CARRIED-UNVERIFIED* figures must be re-derived.
6. **The lead never reads a report, plan, summary, description or context file during the loop.**
7. **This file describes the current plan only.** No revision history, no pass numbers.
8. **A scope cut justified by an unverified premise is not a scope cut.** Test the premise before dropping the work it would make unnecessary.
9. **A dispatch premise can go stale between creation and dispatch.** Measured repeatedly: three of five research dispatches found their premise partly wrong (2026-10-08); a record's entire figure pair had moved and its gate now passed (2026-11-03); two Gate state entries here were resolved by unrelated work within a day (2026-11-04). Re-derive first; report the correction rather than implementing against it.
10. **A redundancy census is re-derived, never remembered.** Fan-out, unordered-overlap counts and duplicate readings all change with every edge and every closure. Compute from `state.json` plus `scripts/lib/file-scope-overlap.sh` with transitive closure as the ordering test.

## Unfiled observations (none worth a task yet)

- **A completed record's cost premise can be contradicted by later measurement.** Record 442
  rejected deploying before implement-phase postflight because "the cost it removes is already
  small and self-resolving", reasoning from a 2-task batch. A 2026-11-04 run measured the
  completion-deploy gate refusing 4 times across 3 tasks — roughly one extra cycle per meta task.
  Re-asking 442's question is duplication; challenging its premise with the frequency data is not.
  Owner call, unfiled.
- **`test-orchestrate-cycle-plan.sh`'s budget failure is real and uncharacterized** — reproduced in
  isolation, no `known-failures.txt` row, no record.
- **328's `status` under-reports**: `planned` while its plan shows 6 of 20 phases terminal. A
  20-phase plan against a 5-cycle budget is 420's subject.
- **328 declares `.claude/` in its own `file_scope`** — a disposable deploy artifact standing rule 2
  forbids editing — plus trailing-slash whole-directory roots that `validate-state.sh` Check 8
  flags. Worth cleaning as its first phase.
- **459's `file_scope` names only its own `specs/` directory**, so it is invisible to overlap
  detection though its verdict gates two records. Nothing represents "this record's output
  constrains that record's design" except an edge.
- **A dispatched agent can end its turn with a backgrounded command pending**, leaving no handoff
  and no return metadata; nothing auto-detects "stopped without returns". **Two states look
  alike**: an agent waiting on its own live child still takes tool rounds, so a message recovers
  it; a stranded agent takes none, so recovery is stop, postflight, re-dispatch at the same
  `dispatch_seq`. Check for a live child first. Detector: `dispatch-strand-probe.sh`.
- **Open records carry a literal-null `title`**, so renderers fall back to `project_name`
  (including 328, 338, 429, 456). `orchestrate-predispatch-review.sh` Class B has been seen
  reporting 0 findings against one; re-read its predicate before filing.
- **Neither `/todo` nor `/review` wires the roadmap generator to its own command.** `--prune` and
  `--regenerate` are still run by hand. Note 436 retires `/review`, so whatever wires
  `--regenerate` should wire it to the survivor.
- **`roadmap-integration.sh --prune` misparses a Run line whose trailing comment is 2 spaces away**
  (needs >=3). Every Run line here is authored with three for that reason. Fail-safe (retains,
  warns) but depends on authored whitespace. Normalize the separator *and* fix the predicate.
- **`plan-file-scope-harvest.sh` silently under-harvests** on three measured plan shapes: a
  Territory Contract table instead of the field, a trailing italic on the label, and a glob entry.
  One repair moved a plan from 56 to 123 paths. Every miss is silent, and an under-harvested scope
  is what drops real work from a phase commit.
- **An unowned Lua spec failure**: `manifest_spec.lua:124`, invalid `merge_targets` type expected
  `false` got `true` (CARRIED-UNVERIFIED 2026-10-17). `known-failures.txt` cannot carry it (shell
  only); the coverage gap — Lua specs have no baseline at all — is the larger half.
- **13 of 14 phase-heading-owning implementation agents never invoke `update-phase-status.sh`**;
  the heartbeat reaches them only via the dispatch boundary. Lint Check I records the gap
  (CARRIED-UNVERIFIED 2026-10-17).
- **Nothing represents a cross-repository prerequisite.** A task gated on another repo reads
  `ready` here. The held books record is in exactly that state, so the gap is live.
- **Nothing prevents a vault operation leaving edges on renumbered tasks.** `parent_task` and
  `dependencies` are handled in the renumber path; nothing validates the result.
- **A rendered `**Goal**:` line in `TODO.md` cannot survive regeneration** and fails validation
  while present; `generate-todo.sh` never reads `active_goal`, so the displayed goal stays blank.
- **A loosely-scoped `subagent_type: "fork"` inherits the parent's entire mandate.** Mitigation in
  `core/docs/fork-patterns.md`; recorded because it is easy to re-introduce.
- The write-time task-reference hook fires on scratchpad files; its filter could exempt `/tmp/**`.
