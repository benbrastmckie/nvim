# Roadmap retained prose

Retained verbatim by migrate-roadmap-to-milestones.sh on 2026-11-20 from `/home/benjamin/.config/nvim/specs/ROADMAP.md` and its state file. Nothing in this file is rendered into the roadmap.

## (preamble)

*Forward-only: what remains, in what order, and the gates. Finished work is removed, not archived
here. Task detail lives in `specs/TODO.md`; this file carries ordering, gates and rulings only.
Figures carry the date measured. Last measured 2026-11-11.*

## Gate state

Every bullet carries its own measurement date. A CARRIED-UNVERIFIED figure must be re-derived
before it is cited (standing rule 5).

- **Gate 8 is red: 5 declared suites**, re-measured 2026-11-11 by a full
  `tests/run-all.sh --jobs 4`: **178 passed, 7 failed (5 expected, 2 NEW), 2 skipped, 187
  total**. The declared roster is `test-double-loading-check.sh`,
  `test-gate-cache-equivalence.sh`, `test-lint-unit-integration-boundary.sh`,
  `test-orchestrate-cycle-postflight.sh`, `test-verify-deploy-context-budget.sh`. The four
  records that accounted for most of the earlier red have all landed, and none of their failures
  was about what the suites test — a hardcoded repo-root walk-up depth across five suites, a
  missing `lib/project-number-inuse.sh` dependency-copy line in three fixtures, and two
  single-assertion failures the first of those had already closed. `568` owns
  `test-orchestrate-cycle-postflight.sh` (25 of 304 assertions, status-name and
  `persisted_status` drift, confirmed pre-existing); `test-double-loading-check.sh` (case 5
  bucket-classification) and `test-lint-unit-integration-boundary.sh` (6 violations across 170
  discovered suites, suites with no `suite-classification.data` row) are both needs-owner.
  `476` owns the residue and **must be re-measured, not sized** — its title still says seven, and
  the roster has never been stable run-to-run. A standing red Gate 8 destroys the signal value of
  the full gate for every later task, which is the real cost.
- **Two roster claims this re-measure overturned.** (a) **`test-gate-lock.sh` now passes** — it
  was the undeclared failure (red, no `known-failures.txt` row) and is off the roster. (b)
  **`test-verify-deploy-context-budget.sh` is red again and declared EXPECTED**, so its row is
  *not* stale and *must not* be removed; the earlier reading that gate 24 passing retired the
  row's condition was wrong. The roster now also carries one genuinely stale row:
  **`test-run-all-parallel.sh` has a row and passes**, which is exactly the instance `605` exists
  to flag.
- **Both NEW failures are contention artefacts, not defects — measured in the same pass.**
  `test-lake-build-guard.sh` failed one of 51 assertions ("case 3: command-substitution
  mismatch") and `test-roadmap-generation.sh` failed under load; re-run in isolation immediately
  afterwards they returned **51 passed / 0 failed** and **105 passed / 0 failed**. The
  `test-roadmap-generation.sh` failure is self-explaining: it carries a "live-tree isolation"
  assertion over the real `specs/ROADMAP.md`, and this pass was rewriting that file while the
  battery ran. This is a concrete instance of the cost `572` owns — **two of seven failures in a
  full battery run were false** — and the mechanism is cheap to state: a suite asserting over a
  live tracked file false-fails whenever anything else writes it.
- **The re-measure was also blocked before it could start: another live session held
  `specs/.gate-lock` for its own Gate 8.** The lock was correctly held — the registered owner pid
  was dead but its parent `verify-deploy.sh` was alive, so this was contention, not a leak, and
  releasing the token would have been wrong. The `gate-acquire` waiter blocked for over two
  minutes before the lane cleared. The ~11-minute serialization `584` exists to remove is
  therefore observable from an unrelated session, not only from a batch's own run.
- **Gate 16 needs re-measuring** (last measured red 2026-11-04). The record that owned it —
  retiring `routing_hard`/`routing_agents_hard` in favour of `hard_contracts` — has landed, and
  nothing open owns the gate. Do not carry the red forward on this entry's authority; re-run the
  gate before sizing anything against it.
- **Gate 20 passes on 80 B.** Eager load 66,720 B against baseline 66,800 B; per-file margins 4 B
  (`commands/orchestrate.md`, 21,496/21,500) and 307 B (`skills/skill-orchestrate/SKILL.md`,
  24,693/25,000). The 1,488 B of total headroom recorded on 2026-11-04 is gone: merging one
  extension's `EXTENSION.md` into `.claude/CLAUDE.md` consumed it, and that merge had to be
  trimmed from 44 lines to 28 mid-implementation to land under the baseline at all. **Any new
  extension carrying a CLAUDE.md merge target now re-fires this gate.** Prefer a relocation trim
  over another ceiling move; both ceilings moved on 2026-11-04.
- **Gate 24 passes** (re-measured 2026-11-11: 1078 files checked, 752 candidate lines scanned,
  752 exempted, 0 violations). The two findings it once carried were a deployed-tree staleness,
  not a defect in the prose: `memory-setup.md` and `memory-troubleshooting.md` both already
  recommend the Claude Code built-in `/ide` in wording the lint's exemption logic accepts, and a
  redeploy closed the gate. **Neither `512` nor `590` has a live finding to clear, and neither
  should be sized until re-measured.** `590` additionally **declares a path that does not exist**
  (`agent-system/extensions/core/scripts/lint-dead-command-recommendations.sh`, missing the
  `lint/` segment; the file is at `.../scripts/lint/lint-dead-command-recommendations.sh`, which
  `512` declares correctly) — re-confirmed 2026-11-11 — which is why `file-scope-overlap.sh`
  reports the pair clean.
- **`validate-state.sh --deep`: 20 passed, 0 failed, 8 warnings** (re-measured 2026-11-11, after
  the preceding batch landed). No dangling edges, no cycles, no duplicate or glob-shaped
  `file_scope` entries, and TODO.md byte-identical to a regeneration. The warnings are three
  classes: **two** coarse `file_scope` (473's `docs/architecture/` overlapping 11 non-terminal
  records, 518's `lean/agents/` overlapping 5 — decision 19, not a defect); **four** absent-key
  `file_scope` (567, 568 and 607, plus the roll-up line — 3 missing-key out of 137, 0 literal-null,
  0 empty-array), which decision 19 does not cover — 568's is a live dispatch hazard, since the
  admission gate sees none of its collisions; **two** reporting `audit_verdict` (77 records) and
  `audit_override` (36 records) as unknown entry fields, written by the lifecycle but modelled in
  neither `state-schema.json`'s `definitions.projectEntry` nor `KNOWN_ENTRY_FIELDS`. The schema
  gap is the cheapest of the three to close, is still unowned, and grows with every task created.
- **`--deep` is the only call that checks TODO.md sync**, and it caught a desync on 2026-11-09
  the plain call passed. A bare `state-write.sh` leaves TODO.md stale unless it carries
  `--regen-todo` or `generate-todo.sh` follows; the plain `validate-state.sh` reports 11 passed
  and will not notice.
- **Never run `verify-deploy.sh` concurrently with the battery.** A contended run cannot
  distinguish a slow gate from a failing one; four gate timeouts were misread this way on
  2026-11-03.
- A source-store commit without a resync is itself a red gate.

## Checks before and after every call

- `tests/run-all.sh --jobs 4` — read the `EXPECTED`/`NEW` split and the roster, not the tally; read
  the exit code directly, never through `tail`/`head`. Baseline 2026-11-11: **178 passed, 7
  failed (5 expected, 2 NEW), 2 skipped, 187 total**; the 2 skipped were an exec-bit regression
  since repaired, and both pass standalone, so a fresh run should read 180 passed / 0 skipped.
  **Read the skipped count too** — it is not in the `EXPECTED`/`NEW` split and a skip is silent.
  **Re-run every `NEW` row in isolation before treating it as a finding** — both NEW rows in that
  run were green standalone. **Do not write a tracked file while the battery runs**: a suite
  asserting over the live tree false-fails.

- A completion postflight refused with exit 6 self-clears on the next redeploy checkpoint, but the
  promotion pass only sees the current invocation's `task_numbers`; a task refused in one run is
  invisible to later runs. `reconcile-task-status.sh <N> <session>` promotes it by hand, and only
  once the source store is fresh.

- **A record batched against an in-flight task's scope burns the rest of the invocation.** It
  re-defers every cycle and the convergence guard halts the whole batch after 3 zero-dispatch
  cycles (measured 2026-11-05: one record deferred against a since-archived in-flight task for
  cycles 3-5). The sibling
  records still complete; the deferred one simply never dispatches. Probe with `--dry-run` or
  `orchestrate-suggest-next-batch.sh --next-batch` first rather than discovering it mid-run.

## Settled decisions (do not re-litigate)

14. **One shared working tree, always.** Per-dispatch `git worktree` isolation removed, not narrowed. Safety rests on `file_scope`, edges and the five contention inputs; build contention is closed by refusing to co-schedule two build-heavy implement tasks. Cost was not the reason and must not be cited as it. Record: `specs/decisions/worktree-isolation-removal-verdict.md`.

15. **Gate 8's deployed-tree coverage is knowingly reduced** on wall-clock grounds: the redeploy checkpoint runs `--skip-slow`, so suites resolving from the *deployed* tree are unverified against a fresh deploy — 52 of 91 narrow core suites (57.1%, CARRIED-UNVERIFIED 2026-11-05), classified not excluded. The record that owned the narrower fix has landed; re-measure the ratio before citing it again.

16. **A systemic cost is filed as one standing task against a probe's output**, not a stream of point defects. Duplication, dead code and slow tests never break anything, so defect-driven intake cannot see them. **`script-inventory.sh` has no standing consumer since its own landed** (re-measured 2026-11-09) — file a new one before the next systemic cost needs somewhere to go.

17. **An unordered territory overlap is resolved by adding the edge, not by separating the pair** (owner ruling). Width 1 is a correct outcome; the property defended is collision visibility and ordering, never wall-clock. A "never with" note is not an acceptable rendering, and a bare exclusion must never stand in for an edge nobody added. Carve-outs: (a) an owner-blocked predecessor that cannot progress — separate and state why; (b) breadth — narrow the `file_scope` instead, except where decision 19 applies.

18. **Settings drift is repaired by making the merge self-healing, never by a migration script** (owner ruling). Hook entries dedupe by *identity* — the `hooks/NAME.sh` invoked, plus event and type. Mandatory carve-out: a command not recognizable as a `.claude/hooks/*.sh` invocation is never matched, moved or deduped. Consequences: (a) a hook registration must live in a fragment surface, since one living only in install-once `root-files/settings.json` is reachable by no resync; (b) the repair for a deploy predating the fix is `rm .claude/settings.json` then reload — `--wipe` restores its own snapshot as the merge base and reintroduces the staleness.

19. **A whole-corpus record runs alone, and its coarse `file_scope` is not a defect to narrow** (owner ruling). Where the territory is directory roots spanning the corpus because the work does, decision 17(b) has nothing to narrow to. Its overlap warnings are correct output: they are what identifies it as a bottleneck.

20. **A near-duplicate record is folded, not merely ordered** (owner ruling). The survivor absorbs the other's text **verbatim**, every edge is re-pointed **before** archiving, and the folded record names the survivor and the grounds. A record whose obligation a landed artifact already discharges is abandoned citing that artifact, not left open as a reminder.

## Standing rules

9. **A dispatch premise can go stale between creation and dispatch.** Measured repeatedly: three of five research dispatches found their premise partly wrong (2026-10-08); a record's entire figure pair had moved and its gate now passed (2026-11-03); two Gate state entries here were resolved by unrelated work within a day (2026-11-04). Re-derive first; report the correction rather than implementing against it.

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
- **A shell suite committed without its exec bit is skipped, not failed, and nothing detects it.**
  Measured 2026-11-11: two suites were committed mode 644 on 2026-11-10 and `run-all.sh` reported
  both as `[SKIP] not executable (exec-bit regression?)`, counting them in its skipped column
  rather than its failures — 41 assertions that had never run. Restoring the bit was a one-line
  `chmod +x` and both pass (21 passed / 0 failed and 20 passed / 0 failed). The gap is
  structural, not instance-specific: `known-failures.txt` cannot carry a skip (decision 13 scopes
  it to failing suites), the discovery predicate names the condition in its own message without
  failing on it, and a skipped suite is invisible in the `EXPECTED`/`NEW` split the battery is
  read by. A gate that fails on any non-zero skip count, or a creation-time mode check, would
  close it. (`test-orchestrate-cycle-plan.sh`'s previously uncharacterized budget failure is
  resolved: it passed in the same run.)
- **A record's `file_scope` can be wrong or go stale, and nothing detects it.** Re-confirmed
  2026-11-11: `590` declares
  `agent-system/extensions/core/scripts/lint-dead-command-recommendations.sh`, which does not
  exist — the `lint/` path segment is missing — so its real collision with `512` over that lint is
  invisible to the admission gate, and a wrong path is indistinguishable from a path the task will
  create. The detection gap is untouched. `plan-file-scope-harvest.sh` widens a scope at plan
  postflight but never prunes a path that has since vanished, and no check compares a non-terminal
  record's declared scope against the filesystem (`file_scope` is documented as descriptive and not
  filesystem-validated, which is the design, not the gap). Cheap probe: for every non-terminal
  record, test each non-glob, non-directory entry for existence and report the misses — strictly
  advisory, since a scope legitimately names files a task will create, but a miss on a path whose
  *sibling directory* exists is a strong typo signal and would have caught (a).
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
- **`roadmap-integration.sh --regenerate` cannot refresh an authored Open-work label, and silently
  pinned twenty stale ones.** Measured 2026-11-11: every open record now carries a `title` (0
  missing out of 137, re-measured directly against `state.json`), yet this file's Open work block
  still rendered `project_name` slugs for twenty of them — `sweep_task_support_file_tracked_or_ignored`
  where the title reads "Classify every task-support file as tracked or ignored". The cause is the
  retention parser: an authored line "wins verbatim, no truncation", and `.title // .project_name`
  is consulted only for a record with no authored line at all, so a label authored while the
  record had no title is never revisited. The remedy applied by hand was to delete the twenty
  lines and re-run `--regenerate`, which re-rendered all of them from `.title`. **Nothing detects
  this**, and the same mechanism pins any other authored annotation whose underlying record has
  moved on. Also relevant to the record making this file generated: a retention parser that
  cannot tell a deliberate override from a stale one is what that record has to replace, not
  inherit.
- **`orchestrate-predispatch-review.sh` Class B tests for a literal-null `title`, not an absent
  key.** There are zero literal nulls, which is why it correctly reports 0 findings even when the
  absent-key count is high. Any record filed against title coverage must target the absent-key
  case, or widen Class B's predicate to cover both. The creation-time gap that refills the set is
  still unowned, even though the current count is 0.
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
- **A completed record's headline outcome can be unobservable in the tree, and nothing checks.**
  Re-measured 2026-11-11, unchanged from the first observation: the record that retired the memory
  extension is `completed` and archived, and its declared `file_scope` names
  `agent-system/extensions/memory/` plus fourteen files beneath it — yet that directory still
  exists with its full `commands/ context/ data/ scripts/ skills/` tree, `memory` is still one of
  nine registered extensions in `.claude-extensions.json`, and the deployed `.claude/CLAUDE.md`
  still carries a `## Memory Extension` section. The mid-flight explanation offered at first
  observation has not borne out across a second measurement, and an open record now depends on
  those files existing: `590`'s `file_scope` declares
  `agent-system/extensions/memory/context/project/memory/memory-setup.md` and
  `memory-troubleshooting.md`. Resolve the contradiction — either the retirement is incomplete or
  its scope overstated what it would delete — before filing anything, and note that `590` must
  land against whichever answer holds. The generalizable gap, independent of this instance:
  postflight verifies phase completion, not that a record's *stated deletions* actually landed, so
  a retirement record can close with its target still in place.
- **Two topics are not meaningfully distinguishable.** `core-agent-system` (50 records) and
  `agent-system` (50) together carry 100 of the 137 open records (re-measured 2026-11-11), and no
  document states a boundary between them. Every record filed into either is a coin flip, which
  degrades every topic-grouped rendering. Two further topics — `repo-hygiene` (1) and
  `decidability` (1) — are not declared in `active_topics` at all, so the generator warns and
  appends them after the curated blocks, and 3 records (584, 585, 586) carry no topic and render
  under Uncategorized. Needs a documented boundary or a merge, plus a declaration pass on the
  stragglers; owner call, unfiled.

## roadmap_notes.next_preamble

**The order of this list is set by instruction, not by fan-out, and it now carries three instructions rather than two.** Two strands sit at the head because an operator asked for exactly their records to be prioritized, together with anything that genuinely must land before them, and in both cases the prerequisite question was answered by measurement rather than assumed: the ignored-specs mechanism group in batch one, and the branch-and-milestone decision strand in batches two and three. **Which of the two leads was not instructed and is this list's own judgment.** The ignored-specs group goes first because its placement is derivable from the ranking rule below -- a finished task recorded as unfinished on every completing dispatch is simultaneously a progress failure and a verdict-truth failure -- whereas the branch strand's own bullet concedes that nothing in the dependency graph and nothing in its records' text makes it urgent. Everything from batch four down keeps the earlier ordering, which an operator set by asking that the most essential work for agent-system health, functionality and speed lead the list, and which was derived against exactly three questions applied in this order: does the system still make progress at all; does one dispatch hand the next the truth; and what does a run cost. Fan-out -- how many open records a record transitively gates -- is recorded below because it is cheap to re-derive, but it chose no part of this order and must not be read as if it had. Re-derive with `generate-task-order.sh --print`.

**The ranking rule, stated so it can be argued with.** A batch ranks higher when its members decide whether work happens (a write path that refuses, a lock that never reaps, a guard that never converges), or whether a verdict can be trusted (a gate reporting a red nobody can attribute, a validator refusing conforming input, a detection charged to the wrong task, a completion recorded as a partial). It ranks lower when its members improve what a future plan or document says without unblocking anything currently stuck. Cost sits immediately below verdict-truth rather than at the head: an optimisation measured against a red gate set is measured against noise, so batch seven waits on batch four by construction.

Re-derived 2026-11-19 over the 128 open records, and re-verified against `generate-task-order.sh --print` the same day. **The backlog is broad and shallow**: depth is 5 waves, the waves run 70 / 34 / 13 / 8 / 3, and **70 of 128 records have no open predecessor**. The widest gates are `599` at 5 direct open dependents and `479` at 4, then exactly seven records at 3 -- `451`, `472`, `484`, `539`, `593`, `654` and `658` -- then exactly seven more at 2: `431`, `438`, `452`, `455`, `486`, `548` and `594`. Those two sets are complete at their counts, not samples of them; `658` enters the backlog directly into the first of them and `654` rose into it this pass. Every other record with an open dependent has exactly one, and there are 35 of those. **Fan-out does not discriminate between candidates at this shape, so it cannot choose the order** -- with more than half the backlog immediately ready, the binding question is which ready work matters, which is a judgment and not a measurement.

**The verification substrate is not the head, and the displacement is deliberate rather than an oversight.** Batch four holds most of the currently-known red surface, and its own `Why this order:` bullet names, record by record, which of its members still reproduce a red and which do not -- measured 2026-11-19 by running the gates and suites directly rather than inferring from the records. The live reds there are the `.mcp.json` merge defect (5 passed / 2 failed), the three standing findings blocking `RESULT=landed_verify_clean`, the two-engine defect that makes one suite red by design plus the roster rows for it, and one violation that no record's subject owns: a suite added by the orchestration-close work with no row in `suite-classification.data`. Gates 4 and 29 both report clean today, so the two single-violation members are not part of that surface. **Every batch below it -- and now the three above it -- dispatches against a gate verdict an operator has a rational incentive to ignore until it lands**, which is the one cost the head carries and which both head strands' own rationales record in those terms. **Batch seven then owns whether the battery's own numbers are measurable at all**: the host-scoped gate mutex that led it has landed, closing the scope half of the contention problem -- every mutex this system ships resolved under `$PROJECT_ROOT`, so a battery started from a sibling repository was structurally invisible to the single-flight guard -- and the standing suite/gate cost consumer now heads that batch, with the advisory-roster record edged behind it.

**The renderer is sound and all three of its callers are wired.** `## Next` and `## Open work` are rendered wholly from `state.json`'s `roadmap_batches` / `roadmap_notes` entries by `roadmap-integration.sh`, which makes no judgment calls. A batch naming only terminal members drops out of the rendering entirely -- its `/orchestrate` line and its `Why this order:` bullet alike -- so retiring one by hand is tidiness, not correctness. What rendering cannot keep current on its own is the authored prose: a batch that loses a member to completion keeps a `description` and a `Why this order:` bullet written against the larger membership, and that is the one thing a maintenance pass must fix by hand. Batch eight was in exactly that state and was rewritten against its three surviving members, the landed one having been its only consumer-repository member and its only sentinel claimant. `/todo` and `/review` reach `--regenerate` behind the shared preflight classifier, and `/orchestrate`'s conclusion stage has its own script, `orchestrate-conclusion-roadmap.sh`, which `skill-orchestrate` names and a dedicated suite covers. **The scope of that renderer is itself the subject of a head-batch record**: the milestone-schema work in batch two extends generation from these two sections to the entire file, nests batches under ordered milestones, and is required to preserve exactly the judgment/rendering split described here rather than collapse it. That record now also carries a siting question it did not have before -- batch one makes `specs/` ignored by default in a fresh repository, and a wholly-generated reviewer-facing dashboard inside an ignored tree is invisible to the reviewer it exists for.

## roadmap_notes.next_postamble

**The `__WHOLE_TREE__` claim is the binding constraint on batch width, not fan-out.** A record declaring the sentinel serializes absolutely against every other claimant, in-batch and cross-batch alike, including a claimant owned by another live session. Measured 2026-11-06: a six-record batch landed research and planning for all six in parallel, then implemented only one, because the remaining four queued behind a single claimant and then behind a cross-batch claimant in another session; three were still unimplemented when the convergence guard stopped the run.

**The claimant roster is four: `431`, `506`, `512` and `586`** (re-measured 2026-11-19). The wrong-corpus record that had briefly made it five -- its in-flight implement dispatch having added the sentinel to its own `file_scope` -- has completed, so batch eight carries no claimant again. `586` leads batch seven rather than sitting second, because the narrowly-scoped mutex record deliberately placed ahead of it has landed; its one remaining batch-mate is edged behind it anyway, so nothing queues behind the claimant that was not already waiting on it. The other three lead their own batches (`506` batch twelve, `431` batch fourteen, `512` batch fifteen) for the usual reason -- a claimant placed first lets the rest of its batch queue behind it instead of colliding with it mid-run. **The head is clear**: no member of batches one through six declares the sentinel, so those six runs contend only with each other and with whatever a cross-session claimant holds.

**What changed this pass.** The pass was scoped by instruction to the five records filed since the last one -- the ignored-specs mechanism group: a shared gitignore predicate with a non-failure exit code for an all-ignored pathspec, the postflight demotion narrowing, an init default that ignores the specs tree, a durability recommendation, and the documentation reframe that records what the other four built -- with the instruction to seat them alongside the four-record branch-and-milestone strand already at the head. Five things changed. **(1) One batch was added at the head**, holding all five ignored-specs records, and it was placed ABOVE the branch strand rather than beside it; the relative order was this list's judgment, not the instruction's, and the grounds are in the preamble and in that batch's own first bullet. **(2) No dependency edge was written anywhere this pass, and that is a measured finding rather than an omission.** Every candidate was judged and refused on stated grounds: three co-territorial pairs carry an explicit owner ruling of no-edge-in-either-direction (`658`/`618`, `659`/`501`, `660`/`338`), the commit-layer overlap between `658` and the cluster-reconciliation record was refused in both directions, and the roadmap-generation record's inherited siting constraint is a design input rather than an ordering. **(3) Four reading duties were recorded as `roadmap_annotation` entries instead of as edges** -- on `654` (rule on the ignored-specs predicate as a fourteenth cluster member and re-measure the script's refusal paths afterwards), on `656` (say where the review surface lives once `specs/` is ignored by default), and on `618` and `338` (re-read the ignored-specs result rather than assume the evidence and enumeration they were written against). An annotation renders on the record's own `## Open work` line, which is where a dispatched agent will actually meet it. **(4) One batch was cleared of cruft rendering had already hidden**: the validator batch's landed member was removed from its `task_ids`, and its `description` and `Why this order:` text were rewritten against the three survivors, since the authored prose still claimed four members, a wrong-corpus verdict that has shipped, and a sentinel claimant that is gone. **(5) Nothing else moved.** No other batch's membership, order, description or rationale was touched, because the instruction's focus did not reach them and a full sweep found no second batch whose prose had gone stale. **127 of 128 open records are batched**; the single exception is the held email substrate (`498`), which is an owner decision, not available work. **Reconciled afterwards, in a scoped follow-up pass over four committed facts and nothing else.** The head batch was reordered to put the durability research first, by owner ruling, because it builds nothing and may collapse the migration half of the scaffolding record before anyone plans it -- its `description` and its ordering bullet both stated the opposite reason and were rewritten. Two measured scope corrections pinned onto the predicate and the demotion records were carried into that batch's prose: the predicate's blast radius is three production call sites rather than the 95 files that merely reference the commit helper, and the demotion record's history-reader surface is three items rather than six, three of the named six issuing no git read at all. The durability record's over-broad declaration was narrowed to an empty array and the bullet reporting it as a defect now records the resolved state, including that the resulting `empty_array` notice is expected. The verify-deploy batch lost its stray-ledger member to completion and had its `description` and bullets rewritten against six survivors, with the writer half of that same defect -- a loader resolving its load target to the working directory with no root guard -- seated at the head of the loader batch alongside the two other open claimants of the file it edits. No edge was written for it either; the reading duty is an annotation on the registry record. Nothing else moved.

The gate exempts research and plan dispatches (neither regenerates the tree) and defers only implement, so a claimant still researches and plans freely while the lane is occupied.

**Admission-probed only in part, and every probe recorded so far is weaker than it looks.** Each one put only research or plan dispatches in cycle 0, and both phases are exempt from the claim gate and the collision gate alike -- so no probe has yet exercised the implement-wave `file_scope` collisions these batches are ordered around. Treat an unprobed batch as unprobed: probe before committing to one, and check `task-lock.sh session-list` for a live session whose scope overlaps, since a cross-session claimant is invisible to the edge graph. Batch six is the one most worth probing before dispatch: five of its eight members claim `orchestrate-cycle-postflight.sh`, and the batch deliberately relies on the collision gate to serialize them rather than on edges. Batch one is the next most worth probing, for the opposite reason -- its own internal collisions come from directory-form declarations rather than from real shared territory, so a probe there tells you whether to narrow a declaration or to accept a deferred cycle.

**On edge declaration**, three rulings stand:

- **Only a `file_scope_collision` verdict means an edge is missing.** `whole_tree_claim` and `self_modifying` verdicts say so themselves -- *"this is an ORDERING CONSTRAINT, not an exclusion"* -- and resolve in a later cycle unaided. **An edge belongs to a path overlap; a sentinel overlap is left to the sentinel defer.** Declaring an edge between two records whose only shared territory is `__WHOLE_TREE__` asserts a semantic claim neither record supports and chains unrelated strands together for nothing.

- **The exemption is direct-edge only, never transitive, and it is scoped to the batch being dispatched.** A heavily shared path is NOT grounds for edging every record that touches it. Re-measured 2026-11-19 over the 128 open records, `context/formats/plan-format.md` has fourteen open claimants, `git-commit-scoped.sh` eleven, `orchestrate-cycle-postflight.sh` ten, `agents/planner-agent.md` nine, `git-commit-phase.sh` and `test-git-commit-scoped.sh` seven each, `orchestrate-cycle-plan.sh` six and `skills/skill-orchestrate/SKILL.md` five -- the two commit-path surfaces each rose by one this pass, `git-commit-scoped.sh` from the ignored-specs predicate and `orchestrate-cycle-postflight.sh` from the demotion narrowing, which is precisely the kind of increment that must NOT be converted into edges. The edges worth declaring are the ones inside the batch actually being dispatched; every other overlap is advisory, resolved by array position. The standing worked example is batch six: five members claim `orchestrate-cycle-postflight.sh` with only two of the ten pairs ordered, and the eight remaining pairs were left to the collision deferral rather than chained, because they are independent defects on one file and co-membership is this list's own judgment, not graph evidence. A second worked example sits at the head: the branch-aware implementation record claims `git-commit-scoped.sh`, `git-commit-phase.sh`, `orchestrate-cycle-plan.sh` and `orchestrate-cycle-postflight.sh`, which carry twenty-three open co-claimants between them, and not one of those overlaps is edged.

- **A transitive order made direct, or an order a record states itself, is the edge class this list writes; a bare sibling overlap is not.** **The two edges standing at the head are both of the second kind -- an order the records already state about themselves.** First, the branch-aware orchestration record is edged behind the branch-topology ruling. The ruling's own text says of that record that it "calls branch-per-invocation 'settled' and forbids reopening worktree isolation; THIS element supersedes that restriction and may revise that task's description". A record another record holds written authority to revise cannot correctly be implemented before that revision exists, so the edge records an ordering the pair asserts rather than one this list invented. Second, the branch-topology ruling is edged behind the commit-layer cluster reconciliation: the ruling has to solve per-task squash ranges from commit attribution, and the cluster it would be reasoning over is exactly where the attribution defects sit -- unattributed commits charged to the wrong dispatch, snapshot artifacts contaminating phase commits, containment both dropping legitimate paths and carrying foreign ones, and a scoped committer that can only commit in the repository whose deploy tree holds it -- and the reconciliation record is named in the ruling record's own text as the precedent it takes its shape from. **That direction was chosen deliberately and the reverse was considered**: the ruling retains explicit authority to amend the cluster record where its topology verdict reaches that cluster, but that is a revision duty discharged after the fact, not a reason to make a cheap, dependency-free cluster ruling wait on a large ruling-plus-implementation record that is itself gated on the milestone schema. **The same reasoning refused a new edge at the head this pass**, in the same direction and for the same cost: the ignored-specs predicate rewrites `git-commit-scoped.sh`'s drop and exit-code contract and is plainly fourteenth cluster material, but the cluster ruling writes no script at all -- its declared territory is `specs/state.json` and `specs/TODO.md` -- so it collides with nothing mechanically and can rule over a queued change as readily as a landed one. Array position already lands the predicate first; the residue is a reading duty, carried as an annotation on the ruling record rather than as an edge.

- **No edge was written from file-territory overlap, and this pass's sweep behind that refusal covers the new head batch.** The ignored-specs group's 16 file-form declarations touch 27 open records, and its three directory-form declarations (`scripts/lib/`, `context/standards/`, `context/processes/`) inflate that to 42 -- an inflation that is itself the argument against reading territory as evidence. Not one of the 42 is named as a predecessor by any of the group's own text; the three the group does name are the subject of an explicit owner ruling of no-edge, and one of those three (`618`) declares no `file_scope` at all, so it does not even appear in the sweep. The earlier sweep over the branch strand returns the same answer: twenty-three records share territory with it and none is named as a predecessor, and the thirteen commit-layer records that most plausibly gate the branch implementation are precisely the cluster the reconciliation record exists to rule on -- SUBSUMED, NEEDS REVISION, NEEDS EDGE or UNAFFECTED, one ruling each -- so writing those edges here would substitute this list's judgment for that record's deliverable. The sibling overlaps left unedged elsewhere include `560`/`504`/`516` on `lean-plan-compliance-check.sh`, `630`/`586`/`605` on `known-failures.txt`, `645`/`646` on `suite-classification.data`, and five open claimants of `validate-artifact.sh` (`452`, `509`, `545`, `575`, `588`) of which two now sit together in batch eight -- each split across batches that never dispatch concurrently. Two older proposals are still held for an owner ruling rather than written: `452` behind `451` and `473` behind `472`.

**Every batch was scanned mechanically this pass for a member listed ahead of an open predecessor, and the list is clean**: across all 30 batches, no member appears in an earlier batch than, or at an earlier position than, any still-open record it depends on -- zero violations over the 127 batched open records. The scan confirmed the new head batch serializes correctly without help from array position: the predicate and the durability research are wave 1, the postflight narrowing and the init default are wave 2 behind the predicate, and the documentation reframe is wave 3 behind all four, which is why it is last in its batch and must not be promoted -- it carries no gate of its own by design, because its content is undecided until the other four land. The scan also confirmed the branch strand still serializes: the implementation record sits in batch three behind both predecessors, and inside batch two the topology ruling sits behind the two wave-1 records it depends on. The scan returns silence rather than a clean result in exactly two places: `613` and `618` declare no territory at all, so no collision scan over them means anything -- and in `618`'s case that silence now hides a real overlap, since its shared claim on `git-commit-scoped.sh` is asserted only in the head batch's text.

**The two held records are not waiting on engineering.** The books-corpus refactor (`342`) waits on an external version stamp reaching `0.1.0` (the consuming repository's own book-convention record still reads a pre-release stamp) and is kept inside batch twenty-eight so its territory overlap with `383`/`384` stays visible. The email preference-harvest substrate (`498`) waits on an operator decision about integrating email into the hosted store and is the one open record in no batch. Neither lift is engineering work, and `/orchestrate` admits a held record only under an explicit forcing flag. Nothing depends on either.

**Scopes and declarations worth narrowing first.** Re-measured 2026-11-19. **Two open records carry no `file_scope` at all -- `613` and `618` -- and exactly one declares an empty array, `661`, deliberately.** The two missing declarations are the defect: both sit in batches whose other members are narrowly scoped (`613` in batch five with `475`/`514`/`574`, `618` in batch seventeen with `338`), so an admission probe over either batch returns a result that is clean for the wrong reason; `618`'s case is worse than cosmetic, because the head batch asserts a `git-commit-scoped.sh` overlap with it that no scan can see. **Fix those two declarations before probing.** **`661`'s empty array is not one of them and must not be repaired.** It replaced a whole-`context/standards/`-directory declaration that overlapped 23 distinct non-terminal records for no real territory, and the record writes no file under `agent-system/**` by its own contract -- its outputs are a report under its own artifact directory and a drafted durability paragraph -- so `validate-state.sh`'s `empty_array` notice against it is the expected consequence of a correct declaration, not a finding. Reading a standards file is not declaring it, and substituting `context/standards/orchestrator-runtime-files.md` would be no better, since that file already has four other claimants. **One over-broad declaration is left in the head batch**: the predicate record's `agent-system/extensions/core/scripts/lib/`, which the coarse-declaration check reports at 11 distinct non-terminal overlaps (`338`, `508`, `517`, `525`, `535`, `541`, `565`, `632`, `646`, `659`, `660`) -- narrow that one before probing batch one. **A separate one-field defect class is now the largest**: nine open records carry a null `title`, so `## Open work` renders their `project_name` slug instead of a sentence -- `613`, `618`, `645`, `646`, `654`, `655`, `656`, `657` and the newly filed loader root-resolution record, four of them in the head strands where a reader is most likely to look. Filling those nine titles is the cheapest legibility win available in this file. Two narrower declaration defects remain live: `590` declares its lint one directory above where the file actually sits, so it cannot collide with `512` even though the two edit the same lint -- which is why batch fifteen pairs them without an edge; and `557` carries topic `decidability`, undeclared in `active_topics`, so it renders after the curated topics. Of the directory-form declarations that remain elsewhere, every one is scoped to a single extension subtree -- `342` (three `books/` directories), `384`, `453`, `530` and `544` -- none is a whole-corpus discovery scope and none is a defect. And `586` still carries no `topic` at all, so it renders under Uncategorized and `generate-task-order.sh` emits a non-fatal warning about it on every run.

