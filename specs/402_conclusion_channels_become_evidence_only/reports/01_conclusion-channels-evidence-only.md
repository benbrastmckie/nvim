# Research Report: Task #402

**Task**: 402 - Conclusion stage Step 4c allocates no task number and creates no task directories
**Started**: 2026-11-11T21:09:00Z
**Completed**: 2026-11-11T21:40:00Z
**Effort**: small
**Dependencies**: 391, 400 (both already landed — see Findings)
**Sources/Inputs**: Codebase (agent-system/extensions/core/**, agent-system/extensions/memory/**), specs/state.json
**Artifacts**: - specs/402_conclusion_channels_become_evidence_only/reports/01_conclusion-channels-evidence-only.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Channels (b) and (c) in `context/contracts/conclusion-stage.md` Steps 4b/4c must stop
  dispatching `meta-builder-agent`/writing `specs/state.json` and instead append a durable
  classification record. The existing store that fits with no feedback-loop hazard and no schema
  invention is `specs/events.jsonl` via `scripts/events-append.sh` — not `issues.jsonl`.
- `issues.jsonl` cannot host the classification record: the conclusion stage's own filter
  predicate (`resolution` `open`/`worked_around`/null) and "Review Happens Only At This Stage"
  contract mean any new line written back into a task's `issues.jsonl` by the stage itself would
  be re-aggregated and re-classified on the *next* invocation, creating a self-referential loop.
  `events.jsonl` is explicitly outside the stage's own read-set (`issues.jsonl` is its sole
  evidence base), so recording there creates no such loop.
- `events.jsonl` already has an exact structural precedent for this shape of record:
  `push_grant_issued`/`push_grant_consumed` (`category: "milestone"`, rich structured `detail`,
  no deviation/blocker semantics). No schema revision is needed — `event_type` and `checkpoint`
  are open strings, `detail` is `additionalProperties: true`.
- The deliberate batch consumer this task defers to is **already filed as task 421**
  (`retarget_distill_meta_as_evidence_consumer`), which independently plans to re-run
  `orchestrate-conclusion-aggregate.sh --aggregate` directly over `issues.jsonl` for its own
  classification pass. This task's events.jsonl record is a durable audit trail of *this run's*
  judgment, not something task 421 is required to consume verbatim — the two tasks are
  compatible, not coupled.
- The approval-gate question the dispatch leaves implicit — does recording still need its own
  `AskUserQuestion`? — resolves cleanly from the contract's own vocabulary: "fire" (the word the
  Approval Ledger section uses throughout) means *executing a consequence* (a fix, a dispatch, a
  task creation). Recording evidence has no consequence to gate, so channels (b)/(c) should
  record unconditionally whenever classification produces ≥1 proposal, with `AskUserQuestion`
  surviving only for channel (a). This is a judgment call for the plan phase to pin, not something
  this report asserts as settled; see Decisions below.
- Five files besides `conclusion-stage.md` transcribe the task-creation design and need
  companion edits: `context/standards/postflight-tool-restrictions.md` (Move 5 tool/commit
  tables), `docs/architecture/orchestrate-state-machine.md` (Move 5 summary prose),
  `context/patterns/orchestrate-batch-results-template.md` (Conclusion block render), and
  `scripts/tests/test-orchestrate-conclusion-aggregate.sh` (cases j and k, which assert the
  *current* dispatch-and-gate shape and will fail against the new design by construction).
  `scripts/orchestrate-conclusion-aggregate.sh` itself needs no change — it never performed
  classification or task creation, only aggregation and the channel-agnostic approval ledger.

## Context & Scope

Researched what currently implements Step 4b (channel (b): agent-system change) and Step 4c
(channel (c): follow-up tasks) in the orchestration conclusion stage, confirmed the two
omissions the dispatch cites (unbound `$new_task_num`, unpopulated `new_task_dir_paths`),
enumerated every consumer that transcribes the task-creation design (so the implementation phase
doesn't strand a stale copy), and researched which existing durable store channels (b)/(c)
should append a classification record to instead of inventing a new file.

Out of scope for this research pass (left for planning): the exact wording of the rewritten
Step 4b/4c prose, the exact commit-grouping for the new evidence-append step, and whether to
split the batch-results-template's three-way vocabulary for (b)/(c) now that they may no longer
be gated.

## Findings

### Codebase Patterns

**The two omissions, confirmed exactly as the dispatch states them**
(`agent-system/extensions/core/context/contracts/conclusion-stage.md:349-372`): Step 4c's
`state-write.sh` call consumes `--argjson num "$new_task_num"` and Step 4c's trailing
`git-commit-scoped.sh` call stages `"${new_task_dir_paths[@]}"` — neither variable is ever bound
in the step. `skills/skill-spawn/SKILL.md`'s Stage 11 (the pattern Step 4c cites as "already
proven") does bind both: it reads and advances `next_project_number` from `specs/state.json` and
creates the task directory before `state-write.sh` runs. Step 4c never transcribed that half.

**`scripts/orchestrate-conclusion-aggregate.sh` is already clean and needs no change.** It
implements exactly three operations — `--aggregate` (grouping, win separation, unknown-class
tally, citation cap), `--record-approval`, `--check-approval` — and dispatches nothing, writes no
task, and has no channel-specific logic beyond validating `--channel` against `a|b|c`. The
per-channel approval ledger (`specs/.orchestration/.conclusion-approval-{session}.json`,
read-merge-write under `flock`) is channel-agnostic by construction. This confirms Required
Change #3 ("the approval ledger ... is load-bearing and verified; keep them ... for the
deliberate consumer") is about *not narrowing* this script's `a|b|c` validation or its ledger
semantics — nothing here currently needs editing to satisfy that requirement; the risk is only
that a later edit pass narrows `--channel` to `a` alone, which must not happen.

**Every consumer that transcribes the task-creation/dispatch design, found by grepping
`agent-system/extensions/core/**` for `new_task_num`, `new_task_dir_paths`, `Step 4c`, `channel
(b)`, `channel (c)`:**

| File | What it transcribes | Edit needed |
|------|---------------------|--------------|
| `context/contracts/conclusion-stage.md` | Steps 4b/4c bodies (the dispatch targets) | Full rewrite of both steps |
| `context/standards/postflight-tool-restrictions.md` | Move 5 "Allowed Tool Surface" table lists `Agent` for channel (b)'s `meta-builder-agent` dispatch and `Bash` for `state-write.sh`/`manage-topics.sh set`/the `GLOBAL_ROOT` resolution (all channel-(b)/(c)-only); Commit Surface table's channel (c) row names `specs/state.json`+`specs/TODO.md`+task dirs | Both tables need the channel-(b)/(c) rows replaced with an `events-append.sh` grant and an `events.jsonl`-only commit row |
| `docs/architecture/orchestrate-state-machine.md` | Move 5 summary prose: "(b) agent-system changes via `meta-builder-agent`, (c) follow-up tasks created as children via `parent_task`" and the four-scope commit-contract sentence | Prose update to match the evidence-only description |
| `context/patterns/orchestrate-batch-results-template.md` | Conclusion block's `{channel_b_outcome}`/`{channel_c_outcome}` rendered as "approved and executed ... names the task(s) it created" / "lists each new child task number" | Required Change #5 — must render what was *recorded*, plus the command that will consume it (`/orchestrate` doesn't name it; name `/distill --meta` or its task-421 successor explicitly once that lands) |
| `scripts/tests/test-orchestrate-conclusion-aggregate.sh` | Case (j) (anti-bypass: asserts `conclusion-stage.md` still contains `collected_answers.confirmed` and `creates TASKS` prose for channel (b)) and Case (k) (gate-intactness: asserts Step 4b's block contains `--check-approval --channel b` and Step 4c's contains `--check-approval --channel c`) | Both cases assert exactly the design being removed and will need rewriting to assert the new evidence-recording shape instead (not merely updated — their premises become false) |
| `agents/meta-builder-agent.md`, `skills/skill-meta/SKILL.md`, `commands/meta.md` | Checked — none reference being called *from* the conclusion stage | No change |
| `context/patterns/topic-assignment-pattern.md` | Checked — its "Mode B: Inherit" caller-location list (`/task --expand`, `/task --recover`, `/spawn`) never named conclusion-stage's Step 4c as a caller | No change |
| `context/patterns/lit-stage4a-flow.md` | Its own `new_task_num` (from `literature-create-setup-task.sh`) is an unrelated literature-setup-task variable, not this stage's | No change (false positive from the initial grep) |

**Case (i)'s commit-scope fixture is also unaffected**: it exercises `git-commit-scoped.sh`'s
general per-channel isolation mechanics using a hypothetical "channel-(c)-shaped"
`specs/state.json`+`specs/TODO.md` pathspec as a generic example, never reading
`conclusion-stage.md`'s actual content. It stays valid regardless of what channel (c) commits
after this change.

### Evidence-Store Design: Why `events.jsonl`, Not `issues.jsonl`, and Not a New File

The dispatch requires recording `class`, `citations[]` (`{task, entry_id}`), `severity_max`,
`suggested_channel_hints[]`, and "the orchestrator's own channel judgment with its override
rationale" — the last two are produced fresh by Step 2's classification judgment and exist
nowhere in `issues.jsonl` today (it only carries the *hint*, `suggested_channel`, not the
*decision*).

Two existing stores were evaluated per the dispatch's own instruction to reuse one of them:

- **`issues.jsonl` (`context/formats/issue-log.md`, writer `scripts/issue-record.sh`)**: hard-
  requires a single task directory per file, so a cross-task-grouped proposal (the central
  reason the aggregation step exists at all — see `conclusion-stage.md`'s "Cross-Task Grouping
  Rule") has no single natural home file. Worse: the conclusion stage's own filter predicate
  reads any `kind: issue|win` entry with `resolution` `open`/`worked_around`/null as a fresh
  candidate. A classification record written back into a cited task's `issues.jsonl` by the
  stage itself would be picked up and re-classified on the *next* invocation unless deliberately
  marked `resolution: fixed_inline` with a `kind` that still satisfies schema validity — a
  workaround that fights the log's own designed semantics rather than fitting it. Rejected.
- **`events.jsonl` (`context/formats/events-format.md`, writer `scripts/events-append.sh`)**:
  nullable `task` (fits cross-task citations, which live in the structured `detail` payload
  instead), open `event_type`/`checkpoint` strings (no schema revision needed), `detail` is
  `"additionalProperties": true` (the full citation list and channel judgment nest here without
  touching `context/schemas/events-schema.json`), and — critically — `events.jsonl` is **not**
  part of `conclusion-stage.md`'s own evidence base (`issues.jsonl` is stated as the sole payload
  source), so a classification record written here is never re-read and re-classified by a later
  invocation of the same stage. **Recommended.**

**Exact existing precedent for this shape of record**: `events-format.md`'s `event_type` table
already documents `push_grant_issued`/`push_grant_consumed` (`category: "milestone"`, `detail`
carrying `remote`/`ref`/`sha`/`force`/`mint_source`/`request_text` or `.../consumer`) — a
structured audit record of a decision, not a deviation or a blocker. This is the right template
to follow: a new `event_type` (e.g. `conclusion_proposal_recorded`), `category: "milestone"`,
`task: null` (citations carry the real per-task linkage inside `detail`), and a `detail` object
shaped like:

```json
{
  "channel": "b",
  "class": "cross-task ownership/territory",
  "citations": [{"task": 313, "entry_id": "iss_..."}, {"task": 397, "entry_id": "iss_..."}],
  "citations_remainder": 0,
  "severity_max": "costly",
  "suggested_channel_hints": ["agent_system"],
  "orchestrator_channel": "b",
  "override_rationale": null
}
```

`override_rationale` is non-null only when `orchestrator_channel` disagrees with
`suggested_channel_hints` (the Hint-Versus-Decision Rule's visible-override requirement), and
this is the field this record durably preserves that `issues.jsonl` never could, since the hint
is write-time and the decision is read-time.

**No new `context/schemas/events-schema.json` revision is required** — `event_type`,
`checkpoint`, and `detail` are already unconstrained for exactly this kind of additive use.

### Deliberate Consumer Is Already Filed (Task 421)

`specs/state.json`'s `project_number: 421`
(`retarget_distill_meta_as_evidence_consumer`, status `not_started`, depends on nothing listed
against 402) is precisely the task the dispatch defers to under "THE DELIBERATE CONSUMER IS A
SEPARATE TASK." Its own description independently states: "`--meta` must additionally ingest
`issues.jsonl` across tasks, reusing `scripts/orchestrate-conclusion-aggregate.sh --aggregate`,
which ALREADY performs the cross-task grouping-by-class ... Consume that aggregator; do not
reimplement its grouping" — i.e. task 421 plans to re-run the *same* aggregation this stage runs,
directly against `issues.jsonl`, for its own independent classification pass, rather than
reading this task's events.jsonl record verbatim. This means 402's events.jsonl record is a
durable, auditable trail of *this run's own judgment* — valuable on its own terms (satisfies the
Verification bullet "the classification and citations are durably recoverable afterward") — but
402 does not need to coordinate its exact schema with 421's consumption mechanics; the two tasks
are independently satisfiable. 402 should not be blocked waiting on 421, and the dispatch already
says so explicitly ("not blocked on the consumer existing").

### The Approval-Gate Question (Not Settled by the Dispatch — Flagged for Planning)

Required Change #1 states channel (a) "already requires its own explicit approval" in a
sentence contrasting it with channels (b)/(c) — the plain reading is that (b)/(c) **no longer
require their own approval gate**, because recording is not an action with a consequence to gate.
This is reinforced by the Overview/Approval-Ledger sections' own vocabulary: every statement of
the invariant ("no channel may fire ... none may fire without one," "deriving a proposal ... is
never, by itself, approval to fire it") uses "fire" to mean *executing a consequence*. Recording
evidence has none, so the invariant is naturally vacuous for (b)/(c) once they stop firing
anything.

Under this reading, Required Change #3's "keep [the ledger] ... for channel (a) and for the
deliberate consumer" is about *not narrowing* `orchestrate-conclusion-aggregate.sh`'s
`--channel a|b|c` validation (so a future consumer, e.g. task 421, can still call
`--record-approval`/`--check-approval --channel b`/`c` itself when it eventually gates its own
task-creation step) — not about conclusion-stage.md's Step 3 continuing to ask the user about
channels (b)/(c) before recording.

This reading is internally consistent and is this report's recommendation, but it is a judgment
call, not a mechanically-verified fact from the dispatch text — the plan phase should state it as
an explicit decision (with the alternative — keep the `AskUserQuestion` gate for (b)/(c) too,
changing only what "yes" does — noted and rejected) rather than silently picking one.

### Scale of the Deletion (Informational, for the "Net Negative Lines" Verification Bullet)

Steps 4b+4c in `conclusion-stage.md` currently span roughly 91 lines
(`### Step 4b` through just before `### Step 5`). A rewritten evidence-recording version of both
steps (gate removed, dispatch/state-write bodies replaced by two `events-append.sh` calls each
with a short illustrative `--detail-json` shape) should land well under half that, giving the
required negative net line count even after accounting for the companion edits to
`postflight-tool-restrictions.md`, `orchestrate-state-machine.md`, and
`orchestrate-batch-results-template.md` (each a net-small prose change, not a net-growth one) and
the test-suite rewrite (replacing, not appending, cases j/k).

## Recommendations

1. Rewrite `conclusion-stage.md` Steps 4b and 4c to each: (a) skip entirely when that channel has
   zero classified proposals (unchanged no-op behavior); (b) when non-empty, call
   `scripts/events-append.sh --event-type conclusion_proposal_recorded --category milestone
   --session "$session_id" --message "..." --detail-json '{...}'` once per classified proposal
   in that channel (or once per channel with an array of proposals in `detail` — plan phase to
   decide which is more query-friendly for task 421's eventual consumption); (c) commit
   `specs/events.jsonl` via `git-commit-scoped.sh`, scoped to that file alone.
2. Remove the `GLOBAL_ROOT`/`target_root` resolution block from Step 4b entirely — it existed
   only to route `meta-builder-agent`'s cross-repo task creation, which no longer happens;
   `events.jsonl` is always the invoking repo's own file.
3. Update `postflight-tool-restrictions.md`'s Move 5 tables (Allowed Tool Surface, Commit
   Surface) and `orchestrate-state-machine.md`'s Move 5 prose to match — see the consumer table
   above for exactly which rows.
4. Update `orchestrate-batch-results-template.md`'s Conclusion block per Required Change #5:
   render `{channel_b_outcome}`/`{channel_c_outcome}` as "recorded ({N} proposals) — see
   `specs/events.jsonl`; consumed by `/distill --meta` (task 421)" or "not recorded — no
   proposals," dropping the approved/declined/not-asked three-way vocabulary for these two
   channels if the no-gate reading above is adopted.
5. Rewrite test cases (j) and (k) in `test-orchestrate-conclusion-aggregate.sh` to assert the new
   shape: (j) should assert `meta-builder-agent.md`'s FORBIDDEN clauses still hold *and* that
   `conclusion-stage.md` no longer contains a channel-(b) `collected_answers.confirmed`/`creates
   TASKS` dispatch (an explicit absence check, inverting the current assertion); (k) should
   assert Step 4a alone still gates on `--check-approval --channel a`, and that Steps 4b/4c
   instead reference `events-append.sh` and not `--check-approval` at all (or, if the plan phase
   keeps a gate for b/c, assert that unchanged — contingent on the Decision above).
6. After the edit, redeploy via `deploy-headless.sh` to `RESULT=landed_verify_clean` per the
   dispatch's own instruction, and report the actual net line count across all touched files
   (must be negative per the dispatch's Verification section).

## Decisions

- **Evidence store**: `specs/events.jsonl` via `scripts/events-append.sh`, new `event_type:
  "conclusion_proposal_recorded"`, `category: "milestone"`. Rejected `issues.jsonl` (feedback-
  loop hazard under the stage's own filter predicate) and a new file (dispatch explicitly
  disfavors it absent a stated reason the existing two can't carry it — events.jsonl can).
- **Approval gate for (b)/(c)**: recommended removal (record unconditionally on ≥1 classified
  proposal), reasoning stated above — **left open for the plan phase to pin explicitly**, not
  decided unilaterally by this research pass.
- **`orchestrate-conclusion-aggregate.sh`**: no change needed; its `a|b|c` channel validation and
  ledger mechanism must not be narrowed (Required Change #3).

## Risks & Mitigations

- **Risk**: narrowing `--channel` validation to `a` alone in the aggregator script while editing
  adjacent code, violating Required Change #3. **Mitigation**: the implementation phase should
  not touch `orchestrate-conclusion-aggregate.sh` at all; this report found no reason to.
- **Risk**: test cases (j)/(k) are deleted rather than rewritten, silently losing coverage of the
  "each channel's execution step references its own channel letter only" gate-intactness
  property for channel (a) (which still needs it). **Mitigation**: rewrite, don't delete — case
  (k)'s channel-(a)-only assertion is still load-bearing.
- **Risk**: `events.jsonl` growth from (b)/(c) recording on every invocation with no per-run cap
  (the dispatch's own motivating complaint about channel proliferation, now shifted to a
  different file). **Mitigation**: this is explicitly the accepted trade — "an evidence store
  that accumulates ... is strictly better than a per-invocation converter with neither [dedup,
  consolidation]" — `events.jsonl`'s own documented gap ("No rotation or archival strategy ...
  flagged for a future task, not solved here") already covers unbounded growth as a known,
  separately-owned concern.

## Context Extension Recommendations

- **Topic**: `events-format.md`'s `event_type` common-values table.
- **Gap**: once implemented, `conclusion_proposal_recorded` should be added as a documented
  common `event_type` value (mirroring the `push_grant_issued`/`push_grant_consumed` rows), so a
  future reader of `events-format.md` finds it without grepping the conclusion-stage contract.
- **Recommendation**: the implementation phase should add this row to
  `context/formats/events-format.md`'s `event_type` table as part of landing the schema, not as a
  separate follow-up — it's a one-line addition to an existing table, not new scope.

## Appendix

- Searches: `grep -rl "new_task_num\|new_task_dir_paths\|Step 4c\|channel (b)\|channel (c)\|channel_b\|channel_c"` across `agent-system/extensions/core`; targeted greps of each hit file's surrounding context; `jq`/`python3 -I` reads of `specs/state.json` for tasks 402 and 421.
- Files read in full or in relevant part: `context/contracts/conclusion-stage.md`,
  `scripts/orchestrate-conclusion-aggregate.sh`, `context/formats/issue-log.md`,
  `context/formats/events-format.md`, `context/schemas/events-schema.json`,
  `scripts/events-append.sh`, `context/standards/postflight-tool-restrictions.md` (Move 5
  section), `docs/architecture/orchestrate-state-machine.md` (Move 5 section),
  `context/patterns/orchestrate-batch-results-template.md` (Conclusion block),
  `scripts/tests/test-orchestrate-conclusion-aggregate.sh` (cases i, j, k),
  `context/standards/git-staging-scope.md` (events.jsonl engine-written-state allowlist),
  `agent-system/extensions/memory/skills/skill-telemetry/SKILL.md` and
  `context/patterns/telemetry-meta-submode.md` (the `--meta`/task-421 consumer side),
  `agent-system/extensions/memory/context/project/memory/distill-usage.md`.
