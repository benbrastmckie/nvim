# Research Report: Task #328

**Task**: 328 - Systematic top-to-bottom CONSOLIDATION of the shell script AND test corpus
**Started**: 2026-10-16T13:32:06Z
**Completed**: 2026-10-16T14:05:00Z
**Effort**: Large (multi-phase; net-deletion acceptance criterion, not a speedup)
**Dependencies**: Task 170 (completed), Task 411 (completed) — both blockers now discharged
**Sources/Inputs**: `scripts/script-inventory.sh` (fresh run), `specs/state.json`,
`suite-cost-hints.txt`, `shell-script-testing.md`, direct file reads of the five/seven-lint
cluster, `grep`/`comm` duplicate-line measurement, git log
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Both declared blockers are discharged.** Task 170 (`isolate_shell_suites_from_host_state`)
  and task 411 (`refactor_verify_deploy_gate_framework`) both show `status: completed` in
  `specs/state.json`. Nothing in the corpus is blocked on dependency grounds; the plan can
  schedule any phase, tested or untested, without a dependency wait.
- **A large slice of the dispatch's own GAP 2 and COORDINATION content is already done — by a
  different, concurrently-running task (416).** Task 416
  (`reaim_gate_cost_model_input_scoped_invalidation`) lists `328` in its *own* `dependencies`
  array yet is already `status: implementing` with 10 of 13 plan phases `[COMPLETED]`,
  including "Cut the Two Verify-Deploy-Testing Stragglers" and "Re-Derive JOBS_CAP From the True
  Pool" — exactly the GAP 2 deliverables this dispatch names. Re-measured costs for the two
  named stragglers have fallen 87% and 77% respectively (see Findings). The plan must treat
  416's work as a given baseline, not a target, and explicitly resolve the backward-dependency
  anomaly (see Risks).
- **The five-lint cluster is really a seven-script cluster.** Two more lint scripts
  (`lint-hook-registration-paths.sh`, `lint-shellcheck.sh`) now share the identical
  shared-corpus-enumeration call-site block the dispatch flags, confirmed by
  `duplicate_block_peers`. Both lack a paired `test-*.sh` suite — the "first slice" framing
  ("all five already have a paired fixture suite") no longer covers the full peer set
  mechanically found today.
- **The call-site duplication is confirmed live, byte-for-byte, across six lint files.** The
  helper functions themselves (`common_shared_corpus_available`, `common_shared_corpus_files`)
  are correctly defined once in `lib/common.sh` — only the ~12-line *call-site wrapper* around
  them is still copy-pasted, exactly as the dispatch describes.
- **GAP 3 (no selection surface) is now half-resolved.** A change-impact selection library
  (`scripts/lib/suite-selection-lib.sh` + `tests/test-run-all-selection.sh`) already exists,
  mapping a touched file to its suites via basename/grep/full-sweep-escalation strata. It is a
  separate, compose-not-call consumer of `run-all.sh --only`; `run-all.sh` itself still exposes
  only `--quiet/--timings/--jobs/--only/--fail-on-new` — no tag, category, or cost-class
  selection. That remaining gap is real and unclaimed by any in-flight task.
- **GAP 1 (no shared test harness) is fully unaddressed and is the single largest remaining
  target.** Zero suites source a shared assert/fixture library; 121 core suites still duplicate
  harness boilerplate in full.
- **Corpus size has net-shrunk since the dispatch's own 2026-10-15 snapshot**, from organic work
  elsewhere (`orchestrate-cycle-plan.sh` 2,794 lines now vs 3,026 at the probe's founding; task
  416's straggler cuts): 232 non-test scripts / 90,472 lines today vs the dispatch's cited 243 /
  94,916. This shrinkage is NOT attributable to this task and must not be credited toward its
  net-deletion target — the target's baseline must be re-captured at the plan's own Phase 1
  start, not borrowed from the dispatch's now-stale figures.
- **Recommended net-deletion target, informed by the above**: hold the dispatch's -10,000
  non-test-line floor for production script, and add an explicit test-corpus floor (the GAP 1
  harness extraction, scoped realistically against 121 suites' worth of reimplemented
  boilerplate) as a second, separately-tracked net figure, since production-script and
  test-script lines are different populations and conflating them in one running total would
  hide a tradeoff (e.g. extracting a harness could temporarily add lines to the new lib file
  before suites are migrated off their own copies).

## Context & Scope

Researched: the current (2026-10-16) state of the shell-script and test corpus under
`agent-system/extensions/**` against the figures the dispatch cites from a 2026-10-15 snapshot,
with specific attention to (a) whether the two declared blockers (170, 411) are actually
discharged, (b) whether the "first slice" (five-lint cluster) framing still holds mechanically,
(c) whether the three named remaining clusters and three test-corpus gaps still hold as
described, and (d) whether any concurrently in-flight task has already changed the ground this
dispatch stands on. Not researched in depth: a full line-by-line design for the shared-harness
extraction or the gate-registry declarative format (left for the planning phase); typst/
literature-search internals beyond the probe's own structural duplicate-block counts.

## Findings

### Codebase Patterns

**Dependency status (both discharged).**
```
170: completed - isolate_shell_suites_from_host_state
411: completed - refactor_verify_deploy_gate_framework
```
Per `specs/state.json`. The dispatch's framing ("170 blocks only the untested-script phases; 411
owns files this task will touch") was written while both were still open; both are now closed.
No phase of this task's plan needs to wait on either for dependency reasons. The remaining
question is pure sequencing/overlap with files 411 touched, not a dependency block.

**Fresh `script-inventory.sh` run, 2026-10-16T13:33:18Z** (root: this repo, load average 1.01
1-min at measurement time — under the dispatch's load<2 discipline for structural counts;
*timing* figures below are separately sourced from `suite-cost-hints.txt`, not re-measured live,
and should be re-verified on a confirmed-quiet host before being used as a plan baseline):

```
candidate_count:            232   (dispatch cited 243 twelve days ago)
total non-test lines:    90,472   (dispatch cited 94,916)
zero_caller_count:             0
untested_count:              175
duplicate_block_script_count: 66
```

The corpus is smaller today than the dispatch's own snapshot, not larger — net organic
shrinkage of ~4,444 lines in one day, from work unrelated to this task (task 416's straggler
cuts, and continued hand-trimming of `orchestrate-cycle-plan.sh`, now 2,794 lines vs the 3,026
line figure recorded when `script-inventory.sh` was first built, and vs the dispatch's own
implicit baseline). **This shrinkage must not be credited toward this task's net-deletion
target** — the plan should capture its own Phase-1-start baseline via a fresh probe run rather
than reusing either the dispatch's number or this report's number, both of which will be stale
by the time implementation starts.

**Five-lint cluster is mechanically a seven-script cluster.** Re-measured line counts match the
dispatch almost exactly (confirming the cluster itself is stable even as the wider corpus
shrinks):

```
lint-scoped-commit-boundary.sh         668 lines  dup_blocks=94  peers=6
lint-task-lookup-adoption.sh           592 lines  dup_blocks=95  peers=6
lint-state-writer-boundary.sh          369 lines  dup_blocks=103 peers=6
lint-branch-gated-sections.sh          398 lines  dup_blocks=66  peers=6
lint-directory-pathspec-boundary.sh    381 lines  dup_blocks=73  peers=6
                                      -----
                                      2,408 lines  (dispatch's cited total, exact match)
```

But each of the five lists **six** `duplicate_block_peers`, not four. The sixth and seventh
members of the peer set:

```
lint-hook-registration-paths.sh   614 lines  dup_blocks=52  has_test=false
lint-shellcheck.sh                296 lines  dup_blocks=30  has_test=false
```

Both share the literal byte-identical shared-corpus-enumeration call-site block (verified by
direct `grep -n -A8`), and both lack a paired `test-lint-<name>.sh` suite. The dispatch's framing
— "all five already have a paired fixture suite... task 170's constraint does not bind this
slice" — is true for the five explicitly named, but the duplicate-block relation the dispatch's
own probe surfaces is not scoped to those five; a plan that extracts the shared block "once" and
stops at five will still leave the identical pattern live in two more files. The plan should
decide explicitly whether to (a) extract for all seven and write characterization tests first
for the two untested ones (now unblocked, since 170 is complete and suites are no longer
host-state-dependent — this is ordinary pre-refactor practice, not a dependency wait), or (b)
scope the first slice strictly to the five named and leave the two extra as a named follow-on
phase. Either is defensible; leaving it unstated is not.

**The call-site block itself, confirmed still duplicated verbatim across all six
`common_shared_corpus_available`-referencing lint files** (direct read, not just the probe's
duplicate-block heuristic):

```
lint-state-writer-boundary.sh:262     if [[ ${#SCAN_PATHS[@]} -eq 1 ]] && ... common_shared_corpus_available; then
lint-scoped-commit-boundary.sh:352    if [[ ${#SCAN_PATHS[@]} -eq 1 ]] && ... common_shared_corpus_available; then
lint-shellcheck.sh:139                if [[ ${#SCAN_PATHS[@]} -eq 0 ]] && common_shared_corpus_available; then
lint-task-lookup-adoption.sh:226      if [[ "$SCAN_MODE" == "source-store" ]] && ... common_shared_corpus_available; then
lint-hook-registration-paths.sh:370   if [[ ${#SCAN_PATHS[@]} -eq 1 ]] && ... common_shared_corpus_available; then
lint-directory-pathspec-boundary.sh:235 if [[ ${#SCAN_PATHS[@]} -eq 1 ]] && ... common_shared_corpus_available; then
```

The underlying helper functions (`common_shared_corpus_available`, `common_shared_corpus_files`)
ARE already correctly extracted to one definition each in `lib/common.sh` — this already
happened (likely as part of 411's "Shared Corpus Enumeration" phase). What remains duplicated is
the ~7-12 line *call-site wrapper* (the `if`/comment/`while read`/`done` dispatch around the
helper call), which differs slightly per file (loop body, glob patterns) but shares its
structural skeleton verbatim across at least four of the six. The dispatch's framing ("it
removed duplicate EXECUTION by adding duplicate SOURCE... extracting that block is part of this
slice") is confirmed current and actionable.

**Shared-skeleton duplication beyond the one named block, spot-checked**: `comm -12` on sorted,
comment-and-blank-stripped unique lines between `lint-scoped-commit-boundary.sh` and
`lint-task-lookup-adoption.sh` returns 112 shared lines — consistent with the dispatch's
115-132-line range (natural variance since the cluster's content is not frozen). This confirms
the "roughly a third of each file is a shared skeleton" claim is still live, not a one-time
historical measurement.

**Remaining named clusters, re-measured, essentially unchanged from the dispatch**:
```
install-extension.sh        300 lines  dup_blocks=35  peers=1   (dispatch: 299L/33)
uninstall-extension.sh      243 lines  dup_blocks=35  peers=1   (dispatch: 237L/33)
typst/chapter-quality-check.sh  763 lines  dup_blocks=44  peers=1  (dispatch: 754L/44)
typst/typst-element-lint.sh    370 lines  dup_blocks=44  peers=1  (dispatch: 372L/44)
literature/literature-search.sh 1,634 lines dup_blocks=172 peers=0 (dispatch: 1,635L/172)
```
All four clusters are structurally stable; small line deltas are normal drift, not a sign the
underlying defect has moved. Re-run the probe again immediately before acting on any of these
per the dispatch's own instruction — this report is itself a snapshot.

**Gate registry**: 23 gate rows in `gate-registry.data` (TAB-separated, 9 fields: id, name,
invoke, dependencies, requires_source_store, timeout_s, cost_class, serialized, input_corpus),
not the "100 gate-registry rows" the dispatch cites — that figure likely predates 411's
consolidation to the declarative format, or counted a different unit (e.g. total gate
invocations across pre-refactor copy-pasted blocks rather than post-refactor registry rows). The
declarative registry itself is a 411 deliverable and is now the steady state; no action needed
here, but the plan should not cite the dispatch's "100" figure as current.

**Markdown/context volume**, re-measured and essentially matching the dispatch: 943 markdown
files / 230,736 lines (dispatch: 928 / ~229,000), 594 context files (dispatch: 590), 21 rules
(dispatch: 21, exact match). This volume is named by the dispatch as "separately, not previously
tracked" and is not acted on by this task's first slice, but the plan should state explicitly
whether markdown/context consolidation is in scope at all (the dispatch's acceptance criterion
is framed around "corpus size" generally, but every concrete cluster and gap it names is shell
script or test shell — recommend the plan scope markdown/context explicitly OUT unless a
specific duplicate-block finding emerges, to avoid an unbounded second front).

### Test-Corpus Shape (re-measured against the dispatch's three named gaps)

**Volume**: 155 test suites repo-wide today (dispatch: 145, +7% in one day — continued drift,
consistent with the dispatch's own point that growth outpaces point-fix filing). 121 suites
under `extensions/core/scripts/tests/` (dispatch: 118). Core test lines: 60,852 (dispatch:
59,069) against 68,701 core production lines (dispatch: 67,375) — ratio 0.886:1, essentially
unchanged from the dispatch's cited 0.88:1. The ratio claim is the more durable finding; the raw
counts will keep drifting and should be re-measured at plan time, not cited from this report.

**GAP 1 — no shared test harness: confirmed still fully present, zero movement.**
```
find agent-system/extensions -iname "test-*.sh" -path "*/lib/*"   -> (none)
find agent-system/extensions -iname "assert-*.sh"                 -> (none)
grep -rl "^pass()\|^fail()\|^assert" .../lib/                      -> (none)
```
No shared harness exists anywhere in the corpus. This remains, by volume, the single largest
unclaimed extract-a-lib target — larger than the five/seven-lint cluster, and not touched by any
in-flight task identified in this research (416's scope is cost-model/caching, not harness
extraction; its own test additions, e.g. `test-gate-cache-equivalence.sh`, still hand-roll their
own assert helpers).

**GAP 2 — no unit/integration distinction: STALE. Already substantially addressed by a
concurrently in-flight task.** `suite-cost-hints.txt` is now a 153-row, 1,402.17s pool (up from
the dispatch's cited 147-row/1,016.6s — both the hint pool's own header comment and this
research's direct read confirm the supersession explicitly: "superseding the 147-row/1,016.6s
figure this header once cited"). The two named stragglers have been re-measured far below their
dispatch-cited cost:
```
test-verify-deploy-context-budget.sh     30,962ms  (dispatch cited 228,595ms -- down 87%)
test-verify-deploy-gate-selection.sh     36,823ms  (dispatch cited 160,340ms -- down 77%)
```
The new pool straggler is `test-gate-cache-equivalence.sh` at 543,000ms — a suite that did not
exist in the dispatch's snapshot, added by task 416's own "Per-Gate Equivalence and
Seeded-Violation Proof for the Skip Path" phase. `JOBS_CAP` has also already been re-derived (416
Phase 10, `[COMPLETED]`) and is documented in `run-all.sh`'s own header as re-derived against the
true 1,402.17s pool, explicitly citing the dispatch's old 1,016.6s figure as superseded.

This is not scope creep by this research — it is a direct read of task 416's state:
`specs/state.json` shows `416: implementing`, with its plan's Phase 1 ("Harden
measure-gate-costs.sh Against Mid-Run Contention"), Phase 6 ("Fixture-Corpus Shellcheck
Acceptance and Complete Hint Coverage"), Phase 8 ("Cut the Two Verify-Deploy-Testing
Stragglers"), and Phase 10 ("Re-Derive JOBS_CAP From the True Pool") all `[COMPLETED]` — each one
a verbatim match to an item in this dispatch's own COORDINATION paragraph list ("hardening
measure-gate-costs.sh against mid-run contention", "re-deriving JOBS_CAP from the true... pool",
"fixture-corpus shellcheck acceptance plus complete hint coverage", and the two-straggler cut).
Three phases remain `[NOT STARTED]` in 416's plan: Phase 11 ("Gate 3 — Decide on the
Post-Invalidation Measurement"), Phase 12 ("Gate 8's Serialized Isolation — Decide on Evidence"),
Phase 13 ("Redeploy, Full-Gate Correctness, and the Measured Before/After") — these map to the
dispatch's remaining two coordination items ("gate 3 as the binding floor once gate 8 drops" and
"re-examining gate 8's serialized isolation").

**No cost-per-assertion probe exists yet** (`grep -rl "cost-per-assertion\|cost_per_assertion"`
returns nothing) — this remains a genuine, unclaimed deliverable of this task, independent of
416's work. The "build the expensive deployed-tree fixture ONCE per run" consolidation (101
`deploy-headless.sh` invocations named by the dispatch) is likewise not addressed by 416's scope
(gate-cache/invalidation, not test fixture sharing) and remains open. Corpus-wide heavyweight-op
counts, re-measured against the dispatch's figures:
```
test files invoking deploy-headless.sh: 17 files   (dispatch cited 101 invocations -- different unit: file count vs invocation count, re-derive consistently before using either figure)
test files invoking verify-deploy.sh:   24 files   (dispatch cited 31 invocations)
test files invoking run-all.sh:         16 files   (dispatch cited 24 invocations)
git init total:   39   (dispatch: 37)
mktemp -d total: 270   (dispatch: 266)
```
The file-count vs invocation-count unit mismatch between this measurement and the dispatch's own
is worth flagging explicitly for the plan: re-derive both counts the same way (grep -c for
invocations, grep -l for files) before citing either as a baseline, since this report's spot
numbers and the dispatch's spot numbers are not directly comparable as written.

**GAP 3 — no selection surface: PARTIALLY addressed.** `run-all.sh` itself still exposes exactly
`--quiet / --timings / --jobs / --only / --fail-on-new` — confirmed by direct grep, no new flags
since the dispatch. However, a **separate, already-built** change-impact selection library now
exists: `scripts/lib/suite-selection-lib.sh` (documented in
`context/standards/shell-script-testing.md`'s "Mapping a touched file to its suite" section,
with its own regression suite `tests/test-run-all-selection.sh`). It maps a touched source file
to the suites that cover it via three strata (strict basename pairing, grep-based reference
lookup, and a mandatory full-sweep escalation on zero hits) and composes with, rather than
modifies, `run-all.sh --only`. Measured there: a representative 5-file touched set resolved to
32 of 123 suites and ran in ~49.4% of full-sweep wall-clock, with an explicit honest caveat that
pulling in the corpus's single most expensive suite can dominate a selection's savings.

This closes the "change-impact selection" half of GAP 3 but **not** the tag/category/cost-class
half — the dispatch's "Selection by class, tag and cost class should sit on top of the existing
flags" is still fully open and unclaimed by 416 or any other identified in-flight task.

### External Resources

Not applicable — this is a pure in-repo consolidation task with no external-library or API
research surface. No web search was performed; all findings above are direct codebase
measurement.

## Decisions

- **Treat both declared blockers (170, 411) as discharged.** The plan should not carry forward
  the dispatch's "170 blocks only untested-script phases" framing as a live constraint — it is
  historically accurate but no longer binding. State it as resolved context, not an open
  dependency.
- **Scope the "first slice" to the mechanically-discovered seven-script peer set, not the
  dispatch's named five**, with an explicit per-script plan decision: extract the shared
  call-site block for all seven, and precede the edit to the two untested members
  (`lint-hook-registration-paths.sh`, `lint-shellcheck.sh`) with a characterization test. This is
  no longer blocked by task 170 (it is complete), so "wait on 170" cannot be the reason to defer
  these two — if they are deferred, the plan must give a different, explicit reason.
- **Do not re-target GAP 2's named stragglers.** Task 416 has already cut them by 87%/77% and
  re-derived `JOBS_CAP`; re-deriving a plan phase against the dispatch's now-stale 228s/160s
  figures would duplicate completed work. The plan should instead (a) adopt 416's completed
  phases as the current baseline, (b) explicitly decide whether to absorb, wait for, or
  independently pursue 416's three remaining phases (11, 12, 13 — gate 3 floor, gate 8 isolation,
  final redeploy/measurement), mirroring the dispatch's own "resolve the overlap deliberately"
  instruction, and (c) scope its own GAP-2-adjacent work to what 416 has NOT claimed: the
  cost-per-assertion probe addition and the "build the fixture once, lend read-only" consolidation
  of the ~17-24 files still constructing heavyweight fixtures per-suite.
- **Treat the net-deletion baseline as re-capturable, not inheritable.** Neither this report's
  measurements nor the dispatch's 2026-10-15 figures should be cited as the Phase-1 starting
  baseline for the running net-insertions-minus-deletions figure; the plan's first phase must run
  `script-inventory.sh` fresh (plus a parallel test-line count) at its own start and declare that
  as the floor against which every subsequent phase's net is measured.
- **Keep markdown/context/rules volume explicitly out of scope** unless a specific duplicate
  finding emerges during implementation; the dispatch's concrete evidence (clusters, gaps,
  probe) is entirely shell/test-shell, and folding in an open-ended markdown pass risks diluting
  the net-deletion target with an unbounded second front.
- **Track production-script and test-script net-deletion as two separate running figures**, not
  one blended total, since a harness extraction will plausibly show a transient net-positive in
  one population (new `lib/` file) before migrations bring the other population's total down —
  collapsing them into one number could mask that tradeoff mid-task, which is exactly the failure
  mode the dispatch's own verify-deploy 36:1 insert-to-delete anecdote warns against.

## Recommendations

1. **Phase ordering**: (a) seven-script lint call-site extraction with characterization tests for
   the two untested members; (b) shared test harness extraction (GAP 1) — the single largest
   unclaimed target by volume, independent of 416; (c) install/uninstall-extension mutual-pair
   dedup; (d) typst chapter-quality-check/typst-element-lint mutual-pair dedup; (e)
   literature-search.sh self-internal dedup; (f) standing corpus-size probe (one cheap line,
   riding an existing gate, per the dispatch's own constraint) plus the cost-per-assertion
   addition; (g) fixture-sharing consolidation for the remaining heavyweight-spawning test files
   not already addressed by 416; (h) tag/category/cost-class selection surface on top of
   `run-all.sh`'s existing flags, composing with the already-built `suite-selection-lib.sh`
   rather than replacing it.
2. **Coordinate explicitly with task 416** before starting any phase touching
   `tests/run-all.sh`, `suite-cost-hints.txt`, `measure-gate-costs.sh`,
   `shell-script-testing.md`, or either straggler suite — re-check 416's live status
   immediately before that phase, since it may have advanced past Phase 10 by the time this
   task reaches implementation.
3. **Re-run `script-inventory.sh` (and an equivalent test-line/suite-count probe) at the start of
   implementation**, not from this report, to set the authoritative net-deletion baseline.
4. **Verify host load < 2 (ideally a 1/5/15-min average, not just 1-min) before taking any timing
   measurement** used in the plan or its acceptance evidence, per the dispatch's measurement-
   discipline paragraph and `measure-gate-costs.sh`'s known blind spot (start-only load sampling).
5. **State per-phase, explicitly, whether that phase's targets are already covered by a paired
   test** (the dispatch's own instruction) — this report shows the answer is not uniformly yes
   even within the "first slice," so this must be a literal per-script checklist in the plan,
   not a one-line cluster-level claim.

## Risks & Mitigations

- **Backward/out-of-order dependency: task 416 lists 328 as a dependency yet is already 10/13
  phases implemented**, ahead of 328 even reaching a plan. Risk: 328's plan could duplicate or
  conflict with 416's remaining phases (11-13) or its already-landed changes to shared files
  (`run-all.sh`, `suite-cost-hints.txt`, `shell-script-testing.md`, `measure-gate-costs.sh`).
  Mitigation: the plan must read 416's live plan/summary status immediately before touching any
  shared file, and explicitly decide absorb/wait/parallel-independent for each of 416's three
  remaining phases rather than silently re-deriving work 416 has already done. This ordering
  anomaly is also worth a separate issue-log entry for the orchestration system itself (recorded
  below), independent of this task's own scope.
- **Drift invalidates cited figures quickly** — demonstrated twice in this research alone (the
  dispatch's own 30% twelve-day drift claim, and a further ~1-day shift in test-suite count,
  `suite-cost-hints.txt` pool size, and two major straggler costs). Mitigation: the plan must
  treat every number in this report, and in the dispatch, as provisional and re-measure
  immediately before each phase, exactly as both documents already instruct.
- **Net-deletion target gaming**: a phase could show a locally-positive net line count while
  claiming it is "the cheapest route to a later negative net" without evidence, repeating the
  verify-deploy 36:1 insert/delete anecdote the dispatch itself cites as the motivating failure.
  Mitigation: require a measured per-phase net figure (not a refactor count) in every phase's
  completion evidence, as the dispatch's acceptance criterion already demands — the plan should
  make this a literal phase-closing checklist item.
- **Unbounded markdown/context scope creep**: the dispatch names markdown/context volume as
  "separately, not previously tracked" without a concrete action item. Mitigation: explicit
  out-of-scope statement in the plan (see Decisions) unless a specific finding emerges.

## Context Extension Recommendations

- **Topic**: cross-task overlap detection during planning.
- **Gap**: nothing in the current planning/research tooling flags that a dependency's own
  dependent (here, 416 depending on 328) is already substantially implemented ahead of this
  task's plan — this research only surfaced it by manually reading 416's plan-phase headings and
  `run-all.sh`'s own header comments, which is not a mechanical check any script performs today.
- **Recommendation**: consider a lightweight pre-plan check (or an `/orchestrate` pre-dispatch
  review addition) that, for a task with an unusually broad `file_scope` like this one, greps
  `active_projects[].file_scope` for overlap against tasks that list the current task number as
  their own dependency, and surfaces any such task's current phase-completion state. Not scoped
  for this task to build; flagged here as a standing-process gap this research incidentally
  exposed.

## Appendix

### Search queries / commands used

- `jq '.active_projects[] | select(.project_number==170 or .project_number==411)' specs/state.json`
- `bash .claude/scripts/script-inventory.sh` (fresh run, 2026-10-16T13:33:18Z, 1-min load 1.01)
- `jq` queries against the probe's `scripts[]`/`ranking[]`/`summary` for the five/seven-lint
  cluster, install/uninstall-extension, typst pair, literature-search.sh
- `grep -n -A8 "common_shared_corpus_available"` across all six peer lint files
- `comm -12` on sorted, comment/blank-stripped unique lines,
  `lint-scoped-commit-boundary.sh` vs `lint-task-lookup-adoption.sh`
- `find`/`wc`/`grep -rl` for shared-test-harness absence (GAP 1), heavyweight-spawn counts
  (GAP 2), and `run-all.sh` flag enumeration (GAP 3)
- Direct read of `agent-system/extensions/core/context/standards/shell-script-testing.md`'s
  "Mapping a touched file to its suite" section
- Direct read of `specs/416_reaim_gate_cost_model_input_scoped_invalidation/plans/01_*.md` phase
  headings and `specs/state.json`'s entry for task 416
- `jq` lookups confirming tasks 270, 307, 308 are `abandoned` (clean supersession)

### References

- `agent-system/extensions/core/scripts/script-inventory.sh` (the standing probe this task
  consumes)
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt`
- `agent-system/extensions/core/context/standards/shell-script-testing.md`
- `agent-system/extensions/core/scripts/gate-registry.data`
- `specs/416_reaim_gate_cost_model_input_scoped_invalidation/plans/01_input-scoped-gate-invalidation.md`
