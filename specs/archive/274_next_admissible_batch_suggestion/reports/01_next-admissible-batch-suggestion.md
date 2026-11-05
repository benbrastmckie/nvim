# Research Report: Task #274

- **Task**: 274 - Next-admissible-batch suggestion and alternatives-on-conflict, both computed by
  invoking the real admission script
- **Started**: 2026-11-04T16:04:00Z
- **Completed**: 2026-11-04T17:10:00Z
- **Effort**: ~6-8 hours (estimated for the implementation phase; this report covers research only)
- **Dependencies**: 165 (completed), 272 (completed, transitively redundant via 275), 273
  (completed), 275 (completed), 344 (completed)
- **Sources/Inputs**: Codebase exploration (`agent-system/extensions/core/scripts/*.sh`,
  `context/patterns/*.md`, `context/contracts/conclusion-stage.md`,
  `docs/architecture/batch-admit-schema.md`), git history of dependency tasks' completion
  summaries, `specs/state.json`, `specs/ROADMAP.md`
- **Artifacts**: `specs/274_next_admissible_batch_suggestion/reports/01_next-admissible-batch-suggestion.md`
- **Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- All five declared dependencies (165, 272, 273, 275, 344) are `completed`. The task is fully
  unblocked and ready for planning; no dependency needs to be dropped.
- The real admission predicate (`scripts/orchestrate-batch-admit.sh`, v6) is the single source of
  truth this task must invoke, never re-implement. Its collision scan already has exactly the
  property the EDGE-PROPOSING STEP needs: a `dependencies[]` edge in EITHER direction between two
  candidates **excludes them from the collision comparison set entirely** ("A1: dependency-edge
  exemption asymmetry", `orchestrate-batch-admit.sh` lines ~339-351). Adding the edge and
  re-invoking the script is therefore sufficient to flip a colliding pair's verdict from
  `defer`/`file_scope_collision` to `admit` — no new admission logic is needed, only a
  caller-side loop that calls the real script before and after the edge write.
- Task 275 (completed) already built the per-repo orchestration queue (`task-lock.sh
  queue-register/-heartbeat/-finish/-reap/-list/-check`) and wired a **blocking** `queue-check`
  call into `commands/orchestrate.md` (not into `skills/skill-orchestrate/SKILL.md`). This is
  Mode B's trigger point — but it is a genuine **file_scope gap**: the task's declared
  `file_scope` lists `skills/skill-orchestrate/SKILL.md`, not `commands/orchestrate.md`, yet the
  refusal this mode must hook (`task-lock.sh queue-check ... || exit 1`, `commands/orchestrate.md`
  line 221) lives only in the command file. This must be resolved (most likely a one-entry
  `file_scope` widen) before implementation, not discovered mid-phase.
- Task 273 (completed) built the Move 5 conclusion stage with a documented extension point: the
  `### Conclusion` report block in `context/patterns/orchestrate-batch-results-template.md`
  already renders a `### Next Steps` section with a re-run-command line immediately after
  `**Roadmap**: regenerated.`. Mode A's suggestion is a natural new line in that same block —
  no new report section is needed, and no change to `conclusion-stage.md`'s three-channel
  machinery is required (this suggestion is informational, never gated behind an
  `AskUserQuestion` approval, and carries no `issues.jsonl` evidence — it is a fourth,
  independent piece of Move 5 output, structurally like the Roadmap-regenerate step, not a
  fourth channel).
- A superficially similar mechanism already exists and must **not** be confused with this task:
  `scripts/roadmap-integration.sh`'s `render_coverage_appendix()` already groups "ready" tasks by
  dependency wave and emits chunked `/orchestrate N, M, ...` command blocks into
  `specs/ROADMAP.md` — but it does so with **no file_scope check at all**, purely from
  wave/`MAX_TASKS` chunking. That gap is exactly what task 313 (`blocked:328,387,401`, open, not a
  dependency of 274) was filed to validate-but-never-fix, and 313's own description explicitly
  states that *proposing* a machine-derived batch is 274's territory, not 313's. This confirms a
  clean boundary: 274 is the proposer, 313 is (will be) the validator of human-authored
  ROADMAP batches; neither depends on the other, and 274 must not edit `roadmap-integration.sh`.
- `orchestrate-triage-classify.sh` already owns the status→phase-group mapping
  (not_started→research, researched→plan, planned→implement) that the new suggester needs to
  compute `orchestrate-batch-admit.sh --phase-map` correctly when probing a candidate set (phase
  exemption matters for self-modifying candidates). Reuse it; do not re-derive the mapping.
- Direction for the EDGE-PROPOSING STEP's `--depends-on-add` call is a genuine open design
  question, not a default: `multi-task-operations.md` states explicitly "Direction cannot be
  inferred from task numbering," while `batch-orchestration-guardrails.md`'s own rendering
  guidance says to "pick an order and record the serializing edge." These are reconcilable (pick
  *some* order deterministically; never claim the choice reflects a pre-existing truth about
  which task logically precedes the other) but the plan phase must state the chosen convention
  explicitly rather than silently default to "lower number predecessor" as though it were given.

## Context & Scope

This is a research-only dispatch for task 274's first (and so far only) research round. The task
has two modes sharing one predicate:

- **Mode A** (next-batch at conclusion): at the end of every `/orchestrate` invocation, suggest
  the next most natural batch to run in a fresh session, computed so that
  `orchestrate-batch-admit.sh` would actually admit every member together.
- **Mode B** (alternatives on conflict): when an invocation is refused by the queue's blocking
  `queue-check` for conflicting with an in-flight orchestration, suggest nearby candidate sets
  that could run instead, drawn from the orchestration queue (task 275's deliverable).

Both modes share one binding constraint: the admissibility predicate must be established by
**actually invoking** `orchestrate-batch-admit.sh` over candidate sets and reading its v6
verdicts — never by re-implementing or approximating the collision/self-modification/
session-contention logic. An added EDGE-PROPOSING STEP requires that when two otherwise-
suggestible candidates collide on `file_scope`, the suggester add the serializing
`dependencies[]` edge via `update-task-status.sh --depends-on-add` and then suggest the pair as
an ordered sequence, rather than silently dropping the pair.

`file_scope` for this task (from `specs/state.json`):
- `agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-suggest-next-batch.sh` (new)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md`

All edits land in the source store (`agent-system/extensions/core/`), never under `.claude/**`
directly, per `rules/source-store-deploy-boundary.md`.

## Findings

### Dependency status (verified via git log + `specs/state.json`)

All four dependencies named in the dispatch, plus a fifth (`344`, present in `state.json`'s
`dependencies[]` but not individually narrated in the dispatch body) are `completed`:

| Task | What it delivered | Relevance to 274 |
|---|---|---|
| 275 | Per-repo orchestration queue: `task-lock.sh queue-register/-heartbeat/-finish/-reap/-list/-check`, lifecycle `registered→running→finished→archived`, archive-not-delete, liveness via the existing `session_liveness()`, blocking `queue-check` gate wired into `commands/orchestrate.md` | Mode B's alternatives are drawn from `queue-list`'s live entries (each carrying `task_numbers[]`, `file_scope[]`, `orchestration_id`, `command`, liveness fields) |
| 272 | Honest session liveness for concurrent same-repo batches: heartbeat propagation fixes, `held-live` lock state, `file_scope` re-derivation on heartbeat (D3) | Transitively redundant via 275→272, kept deliberately per the dispatch; makes the session registry's `file_scope` a live, non-stale admission input |
| 273 | Move 5 conclusion stage: three gated channels, `orchestrate-conclusion-aggregate.sh`, `conclusion-stage.md`, the `### Conclusion` render block in `orchestrate-batch-results-template.md` | Mode A's suggestion is rendered from this stage's own report, after `**Roadmap**: regenerated.` |
| 165 | v6 admission-posture ruling for absent `file_scope`: split blocking (in-batch) vs. advisory (cross-batch) posture, `absent_scope_advisory`/`designated_absent_candidate` fields | Governs how the suggester must treat a candidate with no declared `file_scope`: advisory only cross-batch, blocking in-batch (converges via the lowest-numbered absent-scope candidate) |
| 344 | Batching-by-default doctrine carried to point of use; shipped `update-task-status.sh --depends-on-add`; **this is the task that appended 274's own EDGE-PROPOSING STEP section** to `specs/state.json`'s description | Supplies the exact primitive (`--depends-on-add`) the edge-proposing step must call |

`275`'s own completion summary states explicitly: *"`orchestrate-batch-admit.sh` was never
touched"* (true of 272 as well) — the admission script's v6 shape, read above, is the final,
settled shape this task must consume.

### The admission predicate's exact mechanics that make the edge-proposing step work

Read directly from `scripts/orchestrate-batch-admit.sh`'s own header comments (not duplicated
here, only cited by line range):

- **Comparison set** (lines ~369-384): for each candidate (when not self-modifying), the
  collision scan compares against every `active_projects` entry whose status is non-terminal,
  excluding the candidate itself, **and excluding any task connected to the candidate by a
  `dependencies[]` edge in EITHER direction** — "an explicit dependency edge already serializes
  that pair."
- **A1 note** (lines ~339-351): this dependency-edge exemption applies *only* to the collision
  dimension, not to the self-modification dimension, and is explained as deliberate (an
  edge-connected pair can never share a same-cycle co-dispatch count in ordinary dispatch, so the
  self-mod branch's exemption would be unreachable dead code).
- **Deferral direction for `file_scope_collision`** (lines ~384+): for an `in_batch` collision,
  the higher-numbered candidate defers only when the lower-numbered peer is *itself* admitted
  this cycle; this is purely a deterministic convergence rule for presenting *which one defers
  when both are still live*, not a claim about dependency direction.

**Consequence for the EDGE-PROPOSING STEP**: adding a `dependencies[]` edge between two
file_scope-colliding candidates (in either direction) is sufficient, by itself, to remove them
from each other's collision comparison set on the next `orchestrate-batch-admit.sh` invocation.
The suggester can therefore literally: (1) probe the candidate set, (2) on an `in_batch`
`file_scope_collision` verdict between two members, call `update-task-status.sh
--depends-on-add` to add the edge, (3) re-probe the same candidate set and observe both verdicts
flip to `admit`. This is a closed loop over the real predicate, never a re-derivation of it.

### `--depends-on-add`'s exact contract (from `update-task-status.sh`)

- Direction: the positional `task_number` argument is the task that **gains** the dependency
  (the dependent); the JSON array lists its new predecessors. Mirrors `dependencies[]`'s own
  field semantics exactly — never inferred from which number is larger.
- Status-no-op restriction: the call's `operation:target_status` must resolve to the task's
  **current** status (a no-op replay), e.g. `postflight N researched SID --depends-on-add=[...]`
  on a task already `researched`. This means the edge-proposing step cannot ride along on an
  unrelated status transition; it issues a dedicated no-op-status call purely to add the edge.
- Mandatory write-time cycle refusal: builds a scratch `state.json` with the candidate edge
  applied and greps `validate-state.sh --deep`'s cycle-verdict line; fails closed if that script
  is missing. The suggester's edge-proposing step does not need to re-check for cycles itself —
  `update-task-status.sh` already refuses a cycle-introducing edge.
- Idempotent (union-merge write): calling it again with an edge that already exists is a safe
  no-op, which matters if Mode A's suggestion logic re-runs across repeated `/orchestrate`
  invocations before the user acts on a prior suggestion.

### Direction-rule tension (open design question, not a default)

`context/patterns/multi-task-operations.md`'s "File Footprint Overlap as a Serialization Edge"
section states plainly: *"Direction cannot be inferred from task numbering... an older,
lower-numbered task routinely depends on a newer one."* `batch-orchestration-guardrails.md`'s
"Rendering an unordered territory overlap in a batch plan" section says the opposite-sounding
thing: a batch plan "**picks an order** and records the serializing edge."

These are reconcilable, not contradictory: the guardrails document is explicit that there is *no
privileged truth* about which of two genuinely unordered, merely-territory-colliding tasks must
run first — picking *some* deterministic order is correct precisely because none is more "true"
than another. The multi-task-operations warning is about never *assuming* that a pre-existing
truth about ordering can be read off the numbers (e.g., "newer task must depend on older").
`orchestrate-predispatch-review.sh`'s existing Class D (a suggestion, never written) already uses
a fixed convention for its rendered "suggested" direction — ascending `project_number` as
predecessor — purely as a deterministic, documented placeholder, not a semantic claim. The plan
phase should pick (and name, in the new script's header) one deterministic convention for the
edge-proposing step's actual write — ascending-number-as-predecessor is the most consistent choice
available (it matches the existing Class D display convention and the self-modification
tie-breaker's own ascending-first convention elsewhere in this script), but the plan must state
this explicitly as a *chosen convention*, not an inferred truth, to avoid contradicting the
multi-task-operations warning.

### Mode A's render point (conclusion stage, already has the slot)

`context/patterns/orchestrate-batch-results-template.md`'s `### Conclusion` block (added by task
273) ends with:
```
**Roadmap**: regenerated (`specs/ROADMAP.md`).
```
immediately followed by `### Next Steps`, whose existing content is a re-run-command line
(`Re-run failed tasks: /orchestrate {failed_task_numbers}`). This is the natural new line for
Mode A: a `**Suggested next batch**: /orchestrate {suggested_task_numbers}` line, placed either
as a new bullet inside `### Conclusion` (parallel to **Roadmap**) or as an added line inside
`### Next Steps` alongside the existing re-run-command convention. `conclusion-stage.md`'s own
"## The Executable Stage Body" documents Steps 1-6 (Aggregate, Classify, Three gates, 4a/4b/4c
execution, Roadmap update, Report); the natural insertion point is a new **Step 7 — Suggest next
batch**, run after Step 5 (Roadmap update) and folded into Step 6 (Report)'s render, since the
suggestion is read-only/informational and carries no approval gate of its own — it is not a
fourth channel, and `conclusion-stage.md`'s "Exactly-One-Channel Rule" and "Hint-Versus-Decision
Rule" do not apply to it (it derives from `state.json`'s dependency/file_scope data, not from
`issues.jsonl`).

### Mode B's trigger point — and the file_scope gap

`commands/orchestrate.md` (not `skills/skill-orchestrate/SKILL.md`) contains the one call site:
```bash
qc_args=("$batch_session_id" "$(IFS=,; echo "${validated_tasks[*]}")")
[ "$ALLOW_SCOPE_COLLISION_FLAG" = "true" ] && qc_args+=(--allow-scope-collision)
bash .claude/scripts/task-lock.sh queue-check "${qc_args[@]}" || exit 1
```
This runs *before* `skill-orchestrate`'s Four-Move Loop even begins (it is in
`commands/orchestrate.md`'s setup section, ahead of the session mint and Pre-Dispatch Review). A
grep across `skills/skill-orchestrate/SKILL.md`, `scripts/orchestrate-cycle-plan.sh`, and
`scripts/orchestrate-predispatch-review.sh` confirms `queue-check` is invoked nowhere else.

**This is a real scope gap against the declared `file_scope`**, which names
`skills/skill-orchestrate/SKILL.md` but not `commands/orchestrate.md`. Mode B's refusal-time hook
necessarily needs one added line in `commands/orchestrate.md` immediately before (or replacing)
that bare `|| exit 1` — something like `|| { bash .claude/scripts/orchestrate-suggest-next-batch.sh
--alternatives ...; exit 1; }`. The touch is small (one line), but it is outside the currently
declared scope and must be resolved explicitly before implementation — either by widening
`file_scope` by this one entry (the established, precedented move; see 273's own Phase 3
mid-task widening) or, if a design is found that keeps the hook entirely inside
`skill-orchestrate/SKILL.md` or the new script's own self-contained logic (none was found during
this research — the refusal is structurally a `commands/orchestrate.md`-level `exit 1`, prior to
any skill invocation), documenting why no widen is needed. Flagging this now, rather than letting
it surface as a mid-phase discovery, is the point of recording it here.

### `queue-check`'s refusal payload (Mode B's input)

`task-lock.sh queue-check` prints a stderr `ABORT:` line naming the conflicting
`orchestration_id`, its covered `task_numbers`, `command`, the overlapping path, the colliding
candidate task number, and the conflicting entry's `liveness_reason`, then exits 1. It answers
only "may this invocation start" — it has no notion of alternatives (confirmed in the dispatch
text and in the script itself: `cmd_queue_check` returns on first hit, no candidate-set search).
`cmd_queue_list` is the read-only enumeration primitive (`task-lock.sh queue-list [--archived]`),
emitting one NDJSON line per live entry with `task_numbers[]`, `file_scope[]`,
`orchestration_id`, `command`, `state`, plus computed `live`/`liveness_reason`. Mode B's
alternatives search is therefore: parse the `ABORT:` conflict (or independently call
`queue-list` to see what is live), then search the *rest* of `state.json`'s ready-task pool for a
candidate set disjoint from every live queue entry's `file_scope` — verified the same way as
Mode A, by invoking `orchestrate-batch-admit.sh` over the candidate set (the script's own
cross-batch comparison already includes every non-terminal task regardless of queue membership,
but the queue is the ADDITIONAL input naming which of those non-terminal tasks are *currently
being worked on by a live session*, which `orchestrate-batch-admit.sh`'s `session_active` defer
reason already surfaces per-candidate when `--session-id` is supplied).

### Candidate-pool construction (readiness, distinct from admission)

Readiness ("is this task's own dependency graph clear") and admission ("does this task's
`file_scope` collide with another currently-non-terminal task") are two different, independently
already-computed concepts in this codebase, and only the second is covered by the "never
re-implement the predicate" binding constraint:

- `scripts/lib/task-classification-lib.sh`'s `is_terminal_status()` (completed/abandoned/expanded,
  case-insensitive) is the shared terminal-status primitive, already extracted as a sourceable
  library function and used by `orchestrate-cycle-plan.sh`. The new suggester should source this
  library rather than re-testing status strings inline.
- `scripts/roadmap-integration.sh`'s own `status_token()` function computes a `ready` token:
  non-`hold`/`implementing`/`blocked`/`partial`, and every entry in `dependencies[]` that is
  *also* still present in `active_projects` (i.e., still non-terminal) is empty (a completed/
  archived dependency naturally drops out of `active_projects`, so it reads as resolved). This
  function is **private to `roadmap-integration.sh`** (not a sourced library), and that script is
  **not** in 274's `file_scope`. The suggester should independently compute the equivalent small
  readiness predicate (a handful of jq lines: terminal-status exclusion via the library above,
  plus "every `dependencies[]` entry is either absent from `active_projects` or itself has status
  `completed`") rather than widen scope into `roadmap-integration.sh` to reuse its private
  function. This is not a violation of the binding constraint — the constraint targets the
  file_scope **collision** predicate (which absolutely must only ever come from
  `orchestrate-batch-admit.sh`), not the much simpler, already-multiply-implemented
  dependency-readiness predicate.
- `scripts/orchestrate-triage-classify.sh` owns the status→phase-group mapping
  (not_started→research, researched→plan, planned→implement — confirmed from its own header
  comment). The suggester must invoke this script (not re-derive the mapping) to build the
  `--phase-map` argument `orchestrate-batch-admit.sh` accepts, so that a research/plan-phase
  self-modifying candidate in the suggested batch is correctly phase-exempted from the
  self-modification defer, matching how `orchestrate-cycle-plan.sh` and
  `orchestrate-predispatch-review.sh` already use `--phase-map`.

### Selection doctrine already specified (reuse, do not re-derive)

`context/patterns/batch-orchestration-guardrails.md`'s "Batching Is the Default" section already
specifies the full selection doctrine the suggester must apply when choosing *which* ready tasks
to group into one proposed batch, ranked **territory > topic > graph shape (width)**:

1. Shared (narrow) `file_scope` overlap between two ready candidates is mandatory to batch
   together (this is exactly the EDGE-PROPOSING STEP's trigger condition when no edge exists yet).
2. Once territory-mandatory members are included, fill remaining slots (up to `MAX_TASKS=8`)
   with same-`topic` dispatch-safe candidates before any off-topic filler.
3. Among remaining ties, prefer widening wave 1 (no in-batch dependency edge) over extending an
   existing chain, but always include a dependent whose sole prerequisite is already in the
   batch.
4. `MAX_TASKS=8` truncation precedence: list territory-mandatory members first so a trim to 8
   never splits a mandatory group off the end.

This doctrine is prose/selection guidance, not itself an executable admission check — the
suggester still must verify the resulting proposed set by actually invoking
`orchestrate-batch-admit.sh`, since a doctrine-correct selection and an admission-script-correct
selection are not guaranteed identical in every corner case (e.g., a `session_active` defer from a
live foreign session the doctrine has no visibility into at all).

### A pre-existing, unrelated, and unsound lookalike mechanism (do not touch; do not confuse)

`scripts/roadmap-integration.sh`'s `render_coverage_appendix()` (used by both `--print` and
`--regenerate`) already groups every `status_token()=="ready"` task by dependency wave and emits
chunked ```/orchestrate N, M, ...``` command blocks (chunked at `$MAX_TASKS` per wave) into the
"Coverage appendix" of `specs/ROADMAP.md`. This function has **no file_scope-collision check at
all** — it would happily group two colliding ready tasks into the same emitted `/orchestrate`
line. This is a real, pre-existing soundness gap, but it is **not in 274's `file_scope`** and
**not this task's problem to fix**: task 313 (`Advisory lint for hand-authored /orchestrate batch
proposals in ROADMAP.md`, status `blocked:328,387,401` in `specs/ROADMAP.md`, open, not a
dependency of 274) is the task that will validate (never author or rank) exactly this kind of
hand-authored-or-generated batch block. 313's own description states explicitly: *"Machine-derived
batch SELECTION is the territory of the next-admissible-batch suggestion task (topic
orchestrator)... Copy that task's binding constraint as precedent."* This confirms a clean,
intentional division of labor with no dependency edge needed in either direction: 274 proposes
(machine-derived, admission-script-verified, surfaced at `/orchestrate`'s own conclusion/refusal
points); 313 validates (advisory lint on whatever ends up hand-typed or regenerated into
`ROADMAP.md`). The research/plan phase should explicitly note this boundary so a future reader
does not conflate the two or attempt to route 274's suggestion logic through
`roadmap-integration.sh`.

### Self-modification hazard: does the new script need to be a declared critical path?

`context/reference/orchestrator-critical-paths.json` lists nine orchestrator-critical paths,
gated by the two-conjunctive-test rule in `batch-orchestration-guardrails.md` ("Self-Modification
Hazard" section): **reachability** (read/executed on the multi-task batch-dispatch decision path)
and **decision-relevance** (a defect silently produces a wrong admission/wave/lock/completion
decision). Neither `scripts/orchestrate-conclusion-aggregate.sh` (273's own Move 5 script) nor
`context/contracts/conclusion-stage.md` appears anywhere in that critical-paths file — confirmed
by direct grep. This is a load-bearing precedent: Move 5 (and, by the same reasoning, Mode A's
suggestion step and Mode B's refusal-time suggestion step) runs **strictly after** (Mode A) or
**independently of** (Mode B, which fires at a pre-dispatch refusal, before any admission decision
for *this* invocation has anything left to decide) the actual admission/wave/lock/completion
decisions for the current invocation — a defect in the new suggester script could produce a *bad
suggestion* for a *future* invocation, but cannot silently corrupt *this* invocation's own
dispatch decision. Under the same two-test analysis task 165's completed work already applied to
the rest of this script family, `orchestrate-suggest-next-batch.sh` fails reachability on the
MT-dispatch decision path and should **not** be added to
`context/reference/orchestrator-critical-paths.json` — consistent with (if not an explicit
precedent-setting discussion of) how `orchestrate-conclusion-aggregate.sh` was treated. The plan
phase should state this conclusion explicitly in the new script's own header comment (mirroring
how other scripts in this family document their self-mod status), since neither Move 5 script
currently carries that explicit self-mod disposition anywhere in writing — a minor documentation
gap worth closing opportunistically, not a blocker.

### Verdict-schema documentation touch (`docs/architecture/batch-admit-schema.md`)

This file's "Read by" consumer list (near the top of the document) currently names
`skill-orchestrate/SKILL.md` Move 1, `orchestrate-cycle-plan.sh`, and
`orchestrate-predispatch-review.sh` as the schema's three consumers, each described by what it
does with the verdicts (the sole executing gate; a `--dry-run` report composer; an
advisory-report composer that re-presents verdicts without re-deriving the predicate). The new
suggester is a **fourth consumer of the identical kind** as the third (a report composer that
re-presents verdicts and suggests, but never writes, an admission outcome) — except it also
*does* write one thing (the serializing edge) through `update-task-status.sh`, strictly outside
the verdict schema itself. Per this task's explicit "Respect the existing verdict schema and its
consumers... rather than extending the schema" instruction, the correct edit here is: add the
suggester to the "Read by" list with a one-line description, same as the existing three rows;
make **no** change to "## Complete JSON Schema," "## Field Definitions," or any versioned field —
this task's own acceptance criterion ("no copy of the admission predicate exists anywhere in the
new code") is reinforced, not contradicted, by also leaving the schema itself untouched.

## Decisions

- The suggester is new, standalone machinery (`orchestrate-suggest-next-batch.sh`) — it is not a
  new mode on `roadmap-integration.sh`, and it must not edit that script or
  `render_coverage_appendix()`. The two mechanisms (313's future validator and 274's proposer)
  are deliberately disjoint per 313's own description; no dependency edge is needed between 274
  and 313 in either direction.
- The admissibility check for both Mode A and Mode B is performed exclusively by shelling out to
  `orchestrate-batch-admit.sh` over the candidate set under consideration (with `--invocation-count`
  set to that candidate set's own size, a `--session-id` forwarded from the caller, and a
  `--phase-map` derived by calling `orchestrate-triage-classify.sh`, never hand-computed). No
  collision/self-modification/session-contention logic is reimplemented locally.
- Candidate-pool readiness (non-terminal status, all `dependencies[]` entries resolved) is
  computed locally in the new script via a small, independent jq predicate (sourcing
  `task-classification-lib.sh`'s `is_terminal_status()` for the terminal-status half) — this is
  explicitly NOT the predicate the binding constraint protects, and duplicating this tiny,
  already-multiply-implemented readiness check (it already exists independently in
  `orchestrate-cycle-plan.sh`'s `eligible_tasks` loop and in `roadmap-integration.sh`'s
  `status_token()`) is the lower-scope-creep choice versus widening `file_scope` into either of
  those files to share it.
- The EDGE-PROPOSING STEP calls `update-task-status.sh --depends-on-add` with a no-op
  `operation:target_status` pair matching the dependent candidate's current status, using a fixed,
  documented direction convention (ascending `project_number` as predecessor, pending the plan
  phase's explicit confirmation) — never inferring direction from the numbers as if it reflected
  a pre-existing truth, per `multi-task-operations.md`'s explicit warning, but rather picking a
  deterministic order per `batch-orchestration-guardrails.md`'s own rendering guidance.
- Mode A's suggestion is rendered as new content inside the existing `### Conclusion` block
  (`orchestrate-batch-results-template.md`) / Step 6 of `conclusion-stage.md`'s executable body —
  it is not a fourth gated channel, carries no `AskUserQuestion` approval, and is not derived from
  `issues.jsonl`.
- `docs/architecture/batch-admit-schema.md`'s only required edit is a new "Read by" consumer-list
  entry naming the new script; no schema version bump, no new/changed field.
- `orchestrate-suggest-next-batch.sh` is **not** added to
  `context/reference/orchestrator-critical-paths.json` — it fails the reachability test under the
  same two-conjunctive-test analysis already applied to the rest of the admission-script family,
  consistent with `orchestrate-conclusion-aggregate.sh`'s precedent (absent from that file).

## Recommendations

1. **Resolve the `commands/orchestrate.md` scope gap before implementation begins.** Mode B's
   hook point is structurally in `commands/orchestrate.md`'s `queue-check ... || exit 1` line,
   which is outside the task's declared `file_scope`. Widen `file_scope` by exactly this one
   entry (via the standard mid-task widening convention already used by sibling tasks in this
   family) rather than discovering it mid-phase or attempting an awkward SKILL.md-only
   workaround that does not actually reach the refusal site.
2. **Design `orchestrate-suggest-next-batch.sh` with two explicit CLI modes** mirroring the two
   task modes (e.g. `--next-batch` for Mode A, called once from the conclusion stage's Step 7;
   `--alternatives` for Mode B, called from `commands/orchestrate.md`'s `queue-check` failure
   branch) sharing one internal candidate-admission-probe function, so the "one predicate, two
   triggers" framing in the dispatch is reflected directly in the script's own structure.
3. **Reuse, never fork**: source `task-classification-lib.sh` for terminal-status checks, shell
   out to `orchestrate-triage-classify.sh` for phase-group derivation, and shell out to
   `orchestrate-batch-admit.sh` for every admissibility probe (both before and after any
   edge-proposing write). Do not source `scripts/lib/file-scope-overlap.sh`'s overlap jq defs
   directly in the new script — unlike task 313's lint, this task has no need to compute overlap
   itself at all, since every overlap fact it needs already comes back as a structured
   `orchestrate-batch-admit.sh` verdict field (`defer_reason`, `collision_scope`,
   `colliding_task_number`, `overlapping_path`).
4. **Build the fixture fleet around the acceptance criteria literally**: (a) a clean multi-task
   ready set that `orchestrate-batch-admit.sh` admits wholesale (demonstrating Mode A's happy
   path); (b) a fixture pair with colliding `file_scope` and no existing edge, demonstrating the
   pair does NOT appear in a joint (unordered) suggestion before the edge-proposing step runs,
   and DOES appear as an explicit ordered sequence after it runs (the edge-proposing step's own
   acceptance case); (c) a Mode B fixture where a live queue entry's `file_scope` collides with
   every member of the "obvious" next batch, forcing the alternatives search to surface a
   different, disjoint candidate set; (d) a fixture with an absent-`file_scope` candidate,
   exercising the 165 advisory/blocking split; (e) a fixture exceeding `MAX_TASKS=8`, exercising
   the truncation-precedence rule (territory-mandatory members never split off the end).
5. **Write the new script's header comment with an explicit self-modification-hazard
   disposition** (reachability/decision-relevance verdict: excluded, and why), closing the
   documentation gap this research found in both Move 5 scripts, as a low-cost opportunistic fix
   alongside the main deliverable — not a separate task.
6. **State the chosen edge-direction convention explicitly** in the new script's header and in
   `docs/architecture/batch-admit-schema.md`'s new consumer-list line, naming it as a
   deterministic rendering choice (ascending `project_number` as predecessor, matching the
   existing `orchestrate-predispatch-review.sh` Class D display convention), not an inferred
   truth about dependency direction — avoiding any appearance of contradicting
   `multi-task-operations.md`'s direction-cannot-be-inferred warning.
7. **Keep the suggestion read-only with respect to `conclusion-stage.md`'s approval machinery.**
   Mode A's output needs no `--record-approval`/`--check-approval` gate — it is informational,
   like the Roadmap-regenerate line it sits beside, not a fourth channel requiring
   `AskUserQuestion`.

## Risks & Mitigations

- **Risk**: a naive implementation re-derives collision logic locally "for speed," drifting from
  `orchestrate-batch-admit.sh` over time. **Mitigation**: the fixture fleet (recommendation 4)
  should include a regression case asserting the new script's own source contains no
  `file-scope-overlap` jq defs and no hand-rolled path-prefix comparison — grep-provable, the
  same style of self-check task 165's own summary used for its "no copy of the admission
  predicate" acceptance line.
- **Risk**: the `commands/orchestrate.md` scope gap (Finding above) is discovered only during
  implementation, forcing an unplanned mid-phase `file_scope` widen under time pressure.
  **Mitigation**: resolve it explicitly in the plan's Phase 1 (declared scope correction) before
  any code is written, per Recommendation 1.
- **Risk**: Mode B's "alternatives" search, if unbounded, could probe a combinatorially large
  number of candidate subsets. **Mitigation**: bound the search to a small, clearly-stated
  neighborhood (e.g., ready tasks not currently covered by any live queue entry, filtered by the
  same topic/territory doctrine used for Mode A, capped at a small number of probe calls) — this
  is a plan-phase sizing decision, not resolved here, but the risk should be named explicitly in
  the plan so it is not an afterthought.
- **Risk**: a suggested batch that was admissible at suggestion time becomes inadmissible by the
  time the user actually runs it (a new task was created, a lock was acquired, a queue entry
  changed) between orchestrations in two separate sessions. **Mitigation**: this is inherent to
  any advisory suggestion against a live system and is explicitly accepted — the real admission
  check at actual dispatch time (already live, owned by 165/272/275) remains the sole source of
  truth; the suggester's claim is only ever "this was admissible when suggested," never a
  guarantee. State this limitation plainly in the rendered suggestion text itself (e.g., "verified
  against the current queue/registry; re-run to re-verify before acting").

## Context Extension Recommendations

- **Topic**: self-modification-hazard disposition for Move 5 scripts.
  **Gap**: `batch-orchestration-guardrails.md`'s Inclusion/Exclusion Table for
  `orchestrator-critical-paths.json` predates Move 5 (task 273) and has never been explicitly
  re-applied to `orchestrate-conclusion-aggregate.sh` or (prospectively) to
  `orchestrate-suggest-next-batch.sh`; the absence from the critical-paths file is correct by this
  research's own two-test analysis, but it is not written down anywhere as a considered
  conclusion for either script.
  **Recommendation**: when this task's plan phase drafts the new script's header, also add one
  row (or a short dated note) to `batch-orchestration-guardrails.md`'s Exclusion Table explicitly
  covering both Move 5 scripts together, closing this documentation gap for `conclusion-aggregate.sh`
  opportunistically alongside the new script's own entry.

## Appendix

### Search queries / exploration performed

- `jq` queries against `specs/state.json` for tasks 274, 275, 272, 273, 165, 344 (status,
  dependencies, file_scope, description).
- `git log --oneline --all | grep "task N:"` and `git show <commit>:<path>` against each
  dependency's completion summary (165, 272, 273, 275, 344) to recover their deliverables after
  vault archival removed their `specs/{N}_*/` directories from the working tree.
- Direct reads of `scripts/orchestrate-batch-admit.sh` (header comments, verdict schema, A1 note,
  comparison-set definition, deferral-direction rule), `scripts/task-lock.sh` (queue-* subcommand
  bodies), `scripts/update-task-status.sh` (`--depends-on-add` contract), `scripts/orchestrate-
  predispatch-review.sh` (Class D suggestion logic), `commands/orchestrate.md` (queue-check call
  site), `skills/skill-orchestrate/SKILL.md` (queue-register call site, absence of queue-check),
  `context/contracts/conclusion-stage.md` (full executable stage body), `context/patterns/
  orchestrate-batch-results-template.md` (`### Conclusion` render block),
  `docs/architecture/batch-admit-schema.md` (header, consumer list, Version History),
  `context/patterns/batch-orchestration-guardrails.md` (dominance rule, self-modification
  inclusion/exclusion tables), `context/patterns/multi-task-operations.md` (§13, direction-rule
  note), `scripts/roadmap-integration.sh` (`status_token`, `render_coverage_appendix`),
  `scripts/lib/task-classification-lib.sh` (`is_terminal_status`),
  `context/reference/orchestrator-critical-paths.json`.
- `grep` across the repo for `next.admissible.batch`/`suggest.*batch` to confirm no pre-existing
  implementation beyond the Class D "suggested, never written" edge note and
  `roadmap-integration.sh`'s unrelated coverage appendix.
- Cross-referenced `specs/ROADMAP.md`'s "Open work" block for task 313's description, confirming
  the proposer/validator division of labor and the absence of any dependency edge between 274 and
  313.

### Key file paths referenced (all under `agent-system/extensions/core/` unless noted)

- `scripts/orchestrate-batch-admit.sh`
- `scripts/task-lock.sh`
- `scripts/update-task-status.sh`
- `scripts/orchestrate-predispatch-review.sh`
- `scripts/orchestrate-cycle-plan.sh`
- `scripts/orchestrate-triage-classify.sh`
- `scripts/roadmap-integration.sh`
- `scripts/lib/task-classification-lib.sh`
- `commands/orchestrate.md`
- `skills/skill-orchestrate/SKILL.md`
- `context/contracts/conclusion-stage.md`
- `context/patterns/orchestrate-batch-results-template.md`
- `context/patterns/batch-orchestration-guardrails.md`
- `context/patterns/multi-task-operations.md`
- `docs/architecture/batch-admit-schema.md`
- `context/reference/orchestrator-critical-paths.json`
- `specs/state.json`, `specs/ROADMAP.md` (repo root)
