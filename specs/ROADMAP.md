# Roadmap

*Forward-only: what remains, in what order, and the gates. Finished work is removed, not archived
here. Task detail lives in `specs/TODO.md`; this file carries ordering, gates and rulings only.
Figures carry the date measured. Last measured 2026-11-09.*

## Goal

`/orchestrate` is the only lifecycle entry point, and it is token-cheap by construction: delegate,
read back compact verdicts, ask the user only when a decision is genuinely the user's. `MAX_TASKS`
is 8, enforced in `commands/orchestrate.md`.

Counts and rosters are generated (`generate-task-order.sh --print`,
`roadmap-integration.sh --regenerate`, `orchestrate-suggest-next-batch.sh --next-batch`). Never
transcribe one here. As of 2026-11-09: **126 open (1 held), 3 completed awaiting `/todo`
archival**.

## Gate state

Measured 2026-11-05 unless marked.

- **Gate 8 is red: 8 shell suites**, tracked by record 476 (whose title still says seven). The
  roster measured on 2026-11-05 by a full batch-level run: `test-gate-cache-equivalence.sh`,
  `test-gate-lock.sh`, `test-orchestrate-cycle-postflight.sh`,
  `test-orchestrate-predispatch-review.sh`, `test-orchestrate-unwind-dispatch.sh`,
  `test-postflight-deploy-gate.sh`, `test-redeploy-checkpoint-promotion.sh`,
  `test-verify-deploy-context-budget.sh`. Two more (`test-skill-base-lifecycle.sh`,
  `test-verify-deploy-gate-selection.sh`) and one gate-3 finding did not reproduce on the
  confirmation re-run, so the roster is not stable run-to-run — re-measure before sizing 476.
  A standing red Gate 8 destroys the signal value of the full gate for every later task, which is
  the real cost.
- **Gate 16 is red** (2026-11-04): `routing_hard`/`routing_agents_hard` still declared. Record 444
  owns it and corrects the premise — **three** extensions declare the key (books, cslib, lean),
  and `hard_contracts` exists in no manifest yet.
- **Gate 20 passes on 80 B.** Eager load 66,720 B against baseline 66,800 B; per-file margins 4 B
  (`commands/orchestrate.md`, 21,496/21,500) and 307 B (`skills/skill-orchestrate/SKILL.md`,
  24,693/25,000). The 1,488 B of total headroom recorded on 2026-11-04 is gone: merging one
  extension's `EXTENSION.md` into `.claude/CLAUDE.md` consumed it, and that merge had to be
  trimmed from 44 lines to 28 mid-implementation to land under the baseline at all. **Any new
  extension carrying a CLAUDE.md merge target now re-fires this gate.** Prefer a relocation trim
  over another ceiling move; both ceilings moved on 2026-11-04.
- **Gate 24 is red: 2 findings** (2026-11-06, deterministic — a lint, not a contended suite).
  `memory-setup.md:93` and `memory-troubleshooting.md:34` each correctly recommend the Claude Code
  built-in `/ide`, which the lint cannot recognise: it derives its valid-command set solely by
  enumerating `agent-system/extensions/*/commands/<name>.md`, so a host-provided built-in is
  flagged forever. Record 512 owns the exemption mechanism (its plan adopts a `builtin-cmd-ok`
  inline marker, following the `task-ref-ok`/`version-ok` idiom, so no command-name allowlist is
  introduced) but its `file_scope` covers only the lint script and its suite — not the two prose
  lines. **Those two lines are now unowned** (re-measured 2026-11-09): the whole-corpus reword
  that declared `memory-setup.md` and `memory-troubleshooting.md` has landed without altering
  either line, so the territory conflict that once blocked 512 from marking them is gone and no
  open record claims them. 512 alone still leaves this gate red. Either widen 512's scope to
  those two files or file a record for them.
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

Re-derived 2026-11-09 over the 126 open records. The former twin keystones have both landed,
and **446 is now the single widest gate: 23 transitive, 12 direct** — the widest direct gate in
the backlog. Behind it: 448 (17 transitive, 8 direct), 445 (12), 360 (11), 420 (7), 444 (7),
449 (6), 369 (6), 515 (4), 484 (4), 391 (4). One structure now carries most of the backlog —
the file-scope chain 446 -> 448 -> {452, 461, 500, 523} — and the verification spine has
collapsed onto 445 alone. 70 of the 126 open records have no open predecessor.

```
/orchestrate 446, 497   # admission-probed 2026-11-09: both dispatch, no overlap
/orchestrate 420   # resolve or park: blocks 448 by path and 9 claimants by sentinel
/orchestrate 448   # 8 direct dependents; collides with 420 until it clears
/orchestrate 445   # claimant, runs alone; gates 444, 476, 527
/orchestrate 483   # claimant, runs alone
/orchestrate 488   # claimant, runs alone; gates the sapience keystone
/orchestrate 397, 412, 423, 456, 473   # ready, no inbound edges
/orchestrate 360   # needs 446
/orchestrate 444, 449   # need 445 / 360, 444, 445, 446, 448
/orchestrate 450, 487   # need 449
/orchestrate 496   # sapience keystone: needs 360, 449, 450, 487, 488
/orchestrate 498   # needs 496 — the hardest break in the migration
/orchestrate 499   # needs 496, 497, 498 — retires the memory extension
```

Why this order:

- **446 heads the order because it is the widest gate and startable today.** 12 direct
  dependents, 23 transitive, no open predecessor, and no `__WHOLE_TREE__` claim. `446 -> 448 ->
  {452, 461, 500, 523}` is the file-scope chain and nothing needs to precede it. Probed
  2026-11-09: it dispatches, paired with 497.
- **420 is the bottleneck and is not progressing.** Status `implementing` with 18 dispatches
  recorded and 0 of 5 phases closed (last touched 2026-11-08), carrying an 895-line uncommitted
  working-progress patch. It blocks 448 on `test-orchestrate-cycle-plan.sh`, blocks 450 by edge,
  and its sentinel serializes every other claimant behind it. Finish it or park it with a hold;
  parking is the cheaper unblock. Until then, every claimant below defers.
- **497 is the only sapience record with no open predecessor**, so it pairs with 446 for free.
- **The sapience migration is seven waves deep and cannot be captured in one invocation.** The
  six records that retire the memory extension (483, 488, 496, 497, 498, 499) pull in a
  transitive closure of **15 non-terminal records across 7 dependency waves** (measured
  2026-11-09). Against `MAX_TASKS` of 8 this does not error — the guard silently truncates to the
  first eight and runs those, so a single large call drops records with no warning. Waves 5, 6
  and 7 are near-single records (496, then 498, then 499) and three of the 15 declare
  `__WHOLE_TREE__`, so a wide batch spends most of its cycles deferring and the convergence guard
  halts it after 3 zero-dispatch cycles. Run it as the wave-aligned calls above, not as one
  batch. 496 is the keystone — its own description states the rest of the migration depends on
  it — and 498 is the hardest break, blocking retirement.
- **The tail is downstream or leaves.** Reorder or defer freely within it.

**The `__WHOLE_TREE__` claim is the binding constraint on batch width, not fan-out.** A record
declaring the sentinel serializes absolutely against every other claimant, in-batch and
cross-batch alike, including a claimant owned by another live session. Measured 2026-11-06: a
six-record batch landed research and planning for all six in parallel, then implemented only one,
because the remaining four queued behind a single claimant and then behind a cross-batch claimant
in another session; three were still unimplemented when the convergence guard stopped the run.

**The claimant roster has doubled: 369, 420, 431, 445, 459, 483, 488, 505, 506, 512** (ten,
re-measured 2026-11-09, against five on 2026-11-06). All ten are otherwise ready, so the
sentinel — not fan-out and not edges — is what is actually holding the backlog. 420 is the one
holding the lane. Batch claimants one at a time and group the non-claimants freely around them.

The gate exempts research and plan dispatches (neither regenerates the tree) and defers only
implement, so a claimant still researches and plans freely while the lane is occupied.
**Unexplained, observed 2026-11-09**: 445 is admitted at `implement` against 420's claim while
369, 483 and 488 are deferred against the same task, reproducibly and independent of batch
ordering, though all four overlap 420 only on the sentinel. Not accounted for by
`orchestrate-batch-admit.sh`'s documented research/plan exemption; worth a record.

**Admission-probed 2026-11-09**: the first call only (`446, 497` — both dispatch at research,
no overlap). The 448 collision with 420 and the deferral of 445/483/488 behind 420's sentinel
were probed the same day. Every later call is derived from edges and sentinels, not from a live
pass: probe with `--dry-run` before committing to one, and check `task-lock.sh session-list` for
a live session whose scope overlaps — a cross-session claimant is invisible to the edge graph.

**Not admission-verified**: every other call. A `MAX_TASKS` trim or a self-modifying defer could
reshape any of them — re-derive with `--dry-run` (standing rule 5), or let
`orchestrate-suggest-next-batch.sh --next-batch` propose a set the real admission script admits.

**The held record** (books corpus refactor): every dependency satisfied; the hold is a version
stamp alone. The consuming repo's `books/book-convention.md` line 4 reads `0.1.0-pre`. Lift when
it reads `0.1.0` — owner action, never an agent's. Nothing depends on it.

**One scope worth narrowing first**: the mis-sited-records migration declares `specs/state.json`
and `specs/TODO.md`, which every task writes, so it overlaps everything.
**Coverage appendix (uncovered tasks)**:
```
/orchestrate 313,338,369,383,410,431,437,453
/orchestrate 459,472,475,477,484,490,491,502
/orchestrate 503,504,505,506,510,511,512,514
/orchestrate 515,519,520,521,522,525,526,528
/orchestrate 529,530,531,532,533,534,535,536
/orchestrate 537,538,539,545,546,548,549,550
/orchestrate 551,554,555,556,557,558,559,560
/orchestrate 562,563,565,567,568
```

## Open work

**Core agent system (46)**
```
421 blocked:402     retarget_distill_meta_as_evidence_consumer
436 blocked:313,458,459  Add the /orient executive-orientation command with a read-only scout age...
439 blocked:431,515 audit_cross_extension_bounded_wait_duplication
444 blocked:445     retire_routing_agents_hard_for_hard_contracts
452 blocked:360,448 Require a verification criterion over a repo-wide gate with ...
454 blocked:439,515 State the result-needed-this-turn criterion for choosing the foreground ...
458 blocked:459     Consolidate the duplicated /todo implementation
461 blocked:448     Rule on and close the V7 refusal of a positive directory pathspe...
474 blocked:431     Repair the broken relative links in agent-frontmatter-standard.md
476 blocked:423,445 Make the seven untracked red Gate 8 shell suites green or declared-expected
479 blocked:360     Require every task to name a landing target: a creation-time gate on report-o...
480 blocked:479     Advisory detector for research tasks stranded at RESEARCHED with artifacts bu...
492 blocked:491     Make backlog-audit corroboration computable and gate the confirm prompt on it
500 blocked:448     Dependency-edge backfill is unreachable for a not-started task
517 blocked:455,515 Require a phase commit to regenerate and stage the derived surfaces it stales
523 blocked:448     Make Gate 27 MISSING_DECLARATION count call sites, not whole-file substring m...
524 blocked:461,484,501  Rule on a staged-vs-working-tree divergence signal for a pathspec commit...
527 blocked:369,445 Assert the deployed hook registration SET matches the merge-source, not only ...
564 blocked:505     Fix validate-artifact.sh Tier Justification false positive from sentinel path...
566 blocked:452     Document that the validate-state.sh cycle check requires --deep at every call...
313 ready           Advisory lint for hand-authored /orchestrate batch proposals in ROADMAP.md ph...
338 ready           sweep_task_support_file_tracked_or_ignored
360 ready           Evidence discipline for report and plan artifacts, in three phases: ...
369 ready           Orphan sweep for deployed entries removed from the source store: the deploy a...
410 ready           Close the result-sharing replay hole in lake-build-guard.sh: gate sharing on ...
423 ready           Resolve test-verify-deploy-context-budget.sh's eager-load baseline drift (mea...
431 ready           Record the gate-enforced verbatim-duplication exclusion class as durable agen...
445 ready           gate8_expected_vs_new_failure_distinction
448 ready           Contain the regression-anchor source-store mutation so a concurrent session c...
456 ready           tag_version_gate_unpassable_for_private_manifest
459 ready           Design cross-record traceability; verdict on CHANGE_LOG retirement
473 ready           Strip record-versioning language from the boundary-owned architecture docs
475 ready           Close the audit-evidence gate internal --argjson hole: a large verdict dies w...
490 ready           Make generate-task-order.sh read active_goal so the field stops being a dead ...
491 ready           Fix the Pass-2 semantic scorer whose normalization inflates against verbose c...
502 ready           research_phase_doc_sync_companion_surface
503 ready           revise_unavailable_to_dispatched_agent
505 ready           Make covering-suite selection resolve a non-core extension's source-store scr...
506 ready           Stop the bounded-waiter hook refusing a write whose prose documents the anti-...
515 ready           Rebase the bounded-wait guidance on the measured foreground-backgrounding cei...
519 ready           Infra exempt transport error dispatch deaths
520 ready           Emit deploy ordering in implement dispatch body
521 ready           check_n_completeness_net_glob_misses_implement_variant
525 ready           Repair the always-failing extensions-directory fallback in the task-type dete...
526 ready           Announce completion and input-needed over TTS from the source store, with a c...
565 ready           Resolve archived prior-art paths when composing dispatch and task-description...
```

**Extensions (11)**
```
342 HOLD            Refactor the books extension's context corpus against the settled convention:...
384 blocked:383     Adjudicate whether a books reconciliation postflight lifecycle hook is warran...
457 blocked:455     Repo-specific content has leaked into the shared agent-system source store
496 blocked:360,449,450,487,488  Add per-repo storage and injection to the sapience extension
498 blocked:496     Replace the email preference harvest tally substrate
499 blocked:496,497,498  Retarget the store-coupled distill sub-modes and retire the memory exten...
383 ready           Add a /reconcile command to the books extension: aggregate docs-stage.sh and ...
483 ready           Document that an extension lifecycle hook can never fire without a declared t...
497 ready           Promote the three vault-independent distill telemetry sub-modes into core
522 ready           report_summary_skeleton_conformance_across_extensions
563 ready           Make the extension repo registry usable for deploy enumeration: rule between ...
```

**Literature (2)**
```
437 ready           Repair the Zotero sqlite-reconstruction export path: lost CSL fields and a sh...
453 ready           Carry the degraded-retrieval signal into the zero-result case, where the brie...
```

**File scope lifecycle (8)**
```
455 blocked:448     Pre-flag the predictable first-run module-invariant failures that wi...
486 blocked:484     Stop a required extension manifest.json registration being dropped from ...
501 blocked:448,461,472,476,484,486  Give the cycle-postflight containment site predi...
508 blocked:486     Rule on where shared extension metadata belongs in the containment allowlist,...
509 blocked:452     Make a redeploy phase declarable without polluting file_scope, and bar a pre-...
484 ready           Collapse per-path scope excursion issue rows into one record per drop event
567 ready           port_containment_strip_to_git_commit_scoped
568 ready           repair_orchestrate_cycle_postflight_suite
```

**Lean extension (9)**
```
398 blocked:397     Record that a grep for dependents misses rw-site definitional unfolding, and ...
399 blocked:398     Record three measured lean4 gotchas: IO-forced timing harnesses, docstring/se...
451 blocked:420     Take the Lean Challenge snapshot in the plan phase, where it is still me...
462 blocked:451     Give lean-challenge-snapshot.sh --check a scope limit so a research prototype...
463 blocked:412     State that lean_goal's empty goals_after is not evidence a declaration elabor...
516 blocked:504,515 Stop the Lean plan compliance check failing on not-yet-reached end-state...
397 ready           Require a lean research report's recommended compiled artifact to be compile-...
412 ready           lean_tier_vocabulary_to_build_scope_mapping
504 ready           lean_goals_block_harvest_contract
```

**Orchestrator (10)**
```
402 blocked:391     Conclusion stage Step 4c allocates no task number and creates no task directo...
449 blocked:360,444,445,448  Site the Batch Gate Deferral directive where it is read ...
450 blocked:360,420,448,449  Require a settled user-decision route to name the obligation...
487 blocked:449     Stop the identical-dispatch convergence guard halting a task whose previous c...
507 blocked:420     Re-adjudicate the declined pre-postflight-sweep deploy trigger against a meas...
513 blocked:449,479 Mechanically detect a plan phase that closed without its own commit
518 blocked:472     State the blockers[] admission contract and continuation-on-partial requireme...
472 ready           Stop validate-handoff.sh aborting on a string-shaped blockers array, and...
477 ready           Normalize issue-log class vocabulary and reject the aggregate's malformed rep...
514 ready           Convergence guard blind to zero-dispatch cycles
```

**Agent system (41)**
```
420 IN FLIGHT       Surface a plan-size versus per-run cycle-budget mismatch before a run hits th...
390 blocked:391     Migrate seven mis-sited agent-system tasks out of BimodalLogic and retire one...
391 blocked:369     Close the target_root authoring hole that files agent-system tasks into the w...
438 blocked:313,458 Dependency edges conflate semantic and serialization rationale, and ...
481 blocked:390     Rule on and migrate the 32-record mis-sited agent-system task delta accumulat...
540 blocked:539     Record the decide-synthesis working form, the axiom-free maxRecDepth remedy, ...
541 blocked:535     Stop git-snapshot.sh --no-revert artifacts from contaminating phase commits w...
542 blocked:538     Record the launch-side PID-fidelity condition on the bounded-waiter detach form
543 blocked:534     Tell the re-prompted dispatch to distrust the error count it inherited from t...
544 blocked:539     Make a fixture-dependent Lean gate statement expressible and mechanically che...
547 blocked:543     Confirm the blocker-research aux carrier landed, and refuse an implement re-d...
552 blocked:542     Extend the bounded-waiter lint beyond Rule 2 to the backgrounded-and-blocked ...
553 blocked:548     Name the typst-sync gate as the cause when git-commit-scoped.sh reports a ref...
561 blocked:552     Record the load-sized bound and the diagnostic-preserving output capture on t...
488 ready           Adjudicate where MCP write-tool permission grants belong: repo-scoped extensi...
510 ready           predispatch_review_test_temp_lib_incomplete
511 ready           enumeration_grep_sweeps_gitignored_venv
512 ready           builtin_command_exemption_for_dead_command_lint
529 ready           Evaluate whether formal:logic implement routing should resolve to a Lean-capa...
530 ready           Land the three agent-system context extensions recorded by the cslib omega-au...
532 ready           Rule on whether ROADMAP.md is authored-only and make roadmap-integration.sh r...
533 ready           lake-build-guard replays stale result for env lean FILE
534 ready           postflight writes detail-free blocking issue entry on partial returns
535 ready           Carve a task's own specs/ artifacts out of git-commit-phase.sh's containment ...
536 ready           Source-store-aware commit path and plan-time registration-description review
537 ready           Plan-compliance spot-check misses evidence-probe-scoped Goals
538 ready           Bounded in-file block edits: index and assert, never string-splice
539 ready           State the precedence and snapshot-prerequisite rules for a lean plan's pinned...
545 ready           Report a reversed validate-artifact.sh invocation as an argument-order fault,...
546 ready           Diagnose the zero-result literature retrieval and settle the degraded-signal ...
548 ready           Harvest a plan's declared contingency files into file_scope, and stop the con...
549 ready           Give the Lean unusedArguments remedy a narrow route instead of the wholesale ...
550 ready           Probe the Lean LSP index state at dispatch start and propagate the degraded e...
551 ready           Close the recurring stale-handoff defect and find out why the return-meta sch...
554 ready           file_scope containment drops external source-store paths from phase commits
555 ready           Test sweep permanently red where the source store is external
556 ready           Fix validate-handoff.sh crash-as-false-negative and settle the canonical bloc...
558 ready           Require task descriptions to request a proposal packet instead of instructing...
559 ready           Stop one low-specificity shared path from producing duplicate-of-open, and se...
560 ready           Clear the three standing verify-deploy findings blocking a clean nvim deploy
562 ready           conclusion stage drops null-resolution issue-log entries
```

**Decidability (1)**
```
557 ready           Record the half-line test as a lean4 context pattern note
```

**Repo hygiene (2)**
```
528 ready           Add purpose-written title fields to task records so TODO.md stops rendering t...
531 ready           Narrow whole-directory file_scope declarations so the admission overlap gate ...
```

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
- **A record batched against an in-flight task's scope burns the rest of the invocation.** It
  re-defers every cycle and the convergence guard halts the whole batch after 3 zero-dispatch
  cycles (measured 2026-11-05: one record deferred against a since-archived in-flight task for
  cycles 3-5). The sibling
  records still complete; the deferred one simply never dispatches. Probe with `--dry-run` or
  `orchestrate-suggest-next-batch.sh --next-batch` first rather than discovering it mid-run.
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
15. **Gate 8's deployed-tree coverage is knowingly reduced** on wall-clock grounds: the redeploy checkpoint runs `--skip-slow`, so suites resolving from the *deployed* tree are unverified against a fresh deploy — 52 of 91 narrow core suites (57.1%, CARRIED-UNVERIFIED 2026-11-05), classified not excluded. The record that owned the narrower fix has landed; re-measure the ratio before citing it again.
16. **A systemic cost is filed as one standing task against a probe's output**, not a stream of point defects. Duplication, dead code and slow tests never break anything, so defect-driven intake cannot see them. **`script-inventory.sh` has no standing consumer since its own landed** (re-measured 2026-11-09) — file a new one before the next systemic cost needs somewhere to go.
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

- **An archived record's cost premise can be contradicted by later measurement.** The record
  that rejected deploying before implement-phase postflight did so because "the cost it removes
  is already small and self-resolving", reasoning from a 2-task batch; it is archived, so its
  verdict stands unless reopened. Measured since: the completion-deploy gate refused 4 times
  across 3 tasks (2026-11-04), then both implement dispatches in a 3-task batch (2026-11-05),
  each costing one extra cycle and one `orchestration paused` commit. Two independent runs,
  roughly one extra cycle per meta task that touches `agent-system/extensions/**`. Re-asking that
  record's question is duplication; challenging its premise with the frequency data is not. Owner
  call, unfiled.
- **`test-orchestrate-cycle-plan.sh`'s budget failure is real and uncharacterized** — reproduced in
  isolation, no `known-failures.txt` row, no record.
- **A 20-phase plan against a 5-cycle budget** is 420's subject. The instance that motivated it
  has landed, so the subject now rests on 420's own 5-phase plan and 18 spent dispatches.
- **Nothing represents "this record's output constrains that record's design" except an edge.**
  A record whose `file_scope` names only its own `specs/` directory is invisible to overlap
  detection however much its verdict gates. Self-correcting once a plan lands —
  `plan-file-scope-harvest.sh` widens the scope at plan postflight — so the exposure is the
  window between creation and plan.
- **A dispatched agent can end its turn with a backgrounded command pending**, leaving no handoff
  and no return metadata; nothing auto-detects "stopped without returns". **Two states look
  alike**: an agent waiting on its own live child still takes tool rounds, so a message recovers
  it; a stranded agent takes none, so recovery is stop, postflight, re-dispatch at the same
  `dispatch_seq`. Check for a live child first. Detector: `dispatch-strand-probe.sh`.
- **Fifteen open records have no `title` key at all**, so renderers fall back to `project_name`
  (338, 412, 421, 439, 444, 445, 456, 502, 503, 504, 510, 511, 512, 521, 522, re-measured
  2026-11-09). **Not a literal null — there are zero of those**, which is why
  `orchestrate-predispatch-review.sh` Class B correctly reports 0 findings: it tests for a
  literal-null field, and an absent key is a different state. Any record filed for this must
  target the absent-key case, or widen Class B's predicate to cover both.
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
