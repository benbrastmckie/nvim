# Research Report: Task #643

**Task**: 643 - Align /orchestrate's conclusion-stage next-batch suggestion with the authored roadmap ordering, or render both so the divergence is visible
**Started**: 2026-11-17T00:00:00Z
**Completed**: 2026-11-17T00:00:00Z
**Effort**: medium (single-file behavioral change plus test-suite extension; no new scripts)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh`,
  `scripts/orchestrate-batch-admit.sh`, `scripts/roadmap-integration.sh`,
  `scripts/tests/test-orchestrate-suggest-next-batch.sh`,
  `context/schemas/state-schema.json`, `context/contracts/conclusion-stage.md`,
  `context/patterns/batch-orchestration-guardrails.md`,
  `context/patterns/orchestrate-batch-results-template.md`
- Live corpus: `specs/state.json` (`.roadmap_batches`, `.active_projects`)
**Artifacts**:
- path: specs/643_next_batch_suggestion_ignores_roadmap_ordering/reports/01_roadmap_aware_suggester.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Confirmed the dispatch's own diagnosis mechanically: `orchestrate-suggest-next-batch.sh`
  contains zero references to `roadmap_batches`/`roadmap_notes`/`ROADMAP`, and its three
  selection-doctrine criteria (`select_candidates_for_criterion` territory/topic/width) all sort
  the ready pool ascending by `project_number` and truncate to `MAX_TASKS=8` — an age bias, not a
  readiness disagreement, exactly as the dispatch states.
- `orchestrate-batch-admit.sh` checks file-scope collision and self-modification hazard only; it
  has no readiness/dependency notion. Readiness (non-terminal, not
  hold/implementing/blocked/partial, every dependency completed) is a separate, local predicate
  already implemented once in the suggester as `build_ready_pool()`, and separately in
  `roadmap-integration.sh`'s own terminal-member filtering inside `render_next()` — the second
  of which is the exact precedent to reuse for a roadmap-batch candidate source.
- Recommend **Candidate direction (a)**: walk `roadmap_batches` in authored array order, filter
  each batch's `task_ids` to its currently-ready members (reusing `build_ready_pool()`'s per-task
  readiness predicate, mirroring `render_next()`'s "omit terminal, render still-live members
  only" precedent), skip a batch that filters to empty without spending a probe invocation, and
  probe the first non-empty filtered batch through the existing, unmodified
  `suggest_from_candidates()` / `probe_candidate_set()` machinery — never a second admissibility
  predicate. Fall back to the existing three mechanical options only when no authored batch
  survives filtering+probing, with an explicit stated reason (discharges the ACCEPTANCE
  criterion's either/or framing and folds Direction (b)'s "make the divergence visible" goal into
  the fallback message rather than rendering two parallel surfaces every time).
- Verified this rule against the LIVE `specs/state.json` corpus (not the dispatch's now-stale
  snapshot): walking the 15 live `roadmap_batches` entries in order and readiness-filtering each
  shows the first four authored batches (the prioritized four-task run, the verify-deploy.sh
  lane, the sapience strand, the Gate 8 roster run) all filter to **empty** — every member of
  each is currently mid-lifecycle (implementing/blocked) or otherwise not ready — and the fifth
  batch (`577, 609`, "the failure-accounting chain's tail") is the first to filter non-empty,
  to the singleton `[577]` (`609` itself filters out: its own rationale states it depends on
  the whole prioritized head). This confirms the proposed walk-and-filter rule is cheap (4 empty
  skips cost zero probe invocations) and produces a sane, non-degenerate first candidate on real
  data, though a solo task rather than a multi-task batch at this particular live moment — a
  property of the corpus right now, not a defect in the rule.
- No prior decision record rules the two surfaces (suggester vs. roadmap) deliberately decoupled;
  the nearest closed record only preserved the suggester's *mechanical* selection
  byte-identical and never considered `roadmap_batches` as an input. Nothing settled is
  overturned by coupling them.

## Context & Scope

Researched how to make `/orchestrate`'s conclusion-stage Step 7 next-batch suggestion consult
the authored `roadmap_batches` ordering in `specs/state.json` (the same array
`roadmap-integration.sh` renders into `specs/ROADMAP.md`'s `## Next` section) instead of
recommending a structurally roadmap-blind, ascending-task-number-biased set. Scope: the
candidate-selection layer only, inside `agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh`'s
Mode A (`mode_next_batch()`), its test suite, and the render-shape documentation that names its
output cases. Explicitly out of scope (per the dispatch's binding constraint): re-deriving or
forking the file-scope collision predicate — admissibility stays sourced exclusively from
`orchestrate-batch-admit.sh`.

## Findings

### Codebase Patterns

**The suggester's structure is friendly to this change.** `mode_next_batch()` already composes
independent candidate-selection passes (`select_candidates_for_criterion`) and hands each one,
unmodified, to the single shared probe+render engine `suggest_from_candidates()` ->
`run_candidate_round()` -> `probe_candidate_set()` -> `orchestrate-batch-admit.sh`. A
roadmap-batch candidate source is a FOURTH way to produce a candidate list for that same engine —
no new probing, rendering, edge-proposing, or collision logic is needed; only a new *source* of
candidate lists.

**Readiness filtering has an exact precedent to copy, not invent.** `roadmap-integration.sh`'s
`render_next()` already states the behavior this task needs for roadmap batches at render time:
"A batch all of whose task_ids members are now terminal is omitted entirely; a batch with a mix
of terminal and non-terminal members renders its still-live members only" (`roadmap-integration.sh:454-455`).
The suggester needs the same operation but with a STRICTER readiness bar than mere
non-terminality — it must also exclude hold/implementing/blocked/partial members and members with
an incomplete dependency, exactly the three extra conditions `build_ready_pool()` already checks
(`orchestrate-suggest-next-batch.sh:303-336`). The clean implementation is: factor
`build_ready_pool()`'s per-task readiness test into a reusable associative "is-ready" set (built
once), use it both to emit the existing flat ready-pool list AND to filter each roadmap batch's
`task_ids` down to its ready members — no new readiness logic, one readiness computation shared
by both consumers.

**`orchestrate-batch-admit.sh` has no readiness notion at all** — it is purely a file-scope
collision + self-modification-hazard predicate (`orchestrate-batch-admit.sh:1-24`). This confirms
the readiness filter MUST happen locally (as `build_ready_pool()` already does) before a
candidate list is ever handed to the admit predicate; the task description's binding constraint
("admissibility is established ONLY by invoking orchestrate-batch-admit.sh") governs the
collision/self-mod dimension only, not readiness, and the existing mechanical criteria already
rely on exactly this split (`build_ready_pool()` first, `probe_candidate_set()` second). A
roadmap-aware candidate source preserves that split unchanged.

**`roadmap_batches` schema is a direct, position-ordered fit.** Per
`context/schemas/state-schema.json`'s `roadmapBatchEntry` definition: `task_ids` (ordered member
list), `description` (<=100 chars), optional `rationale` and `flags`. "Array position IS the
batch's priority — there is no separate priority field" (schema description on
`roadmap_batches`). This is exactly the ordering signal Cause 1 of the dispatch says is
structurally invisible to the suggester today, and it requires no new field or schema change to
consume — only a new reader.

**The probe-invocation budget (`MAX_PROBE_INVOCATIONS=20`) is already a script-global, shared
counter** (`orchestrate-suggest-next-batch.sh:241-242`) that every probe call increments
regardless of caller. Walking roadmap batches in order and probing each non-empty filtered batch
consumes this same budget — skipping empty-filtered batches without a probe call (confirmed
cheap against the live corpus below) keeps this bounded in the common case, but a state.json with
many roadmap batches whose members are mostly NOT ready could still exhaust the cap before
reaching the mechanical fallback. The existing cap-reached rendering convention
(`run_candidate_round()`'s explicit cap line, `PROBE_CAP_HIT`) already handles "stop and say so
loudly" — the roadmap walk should route through the identical mechanism rather than inventing a
second cap-reached message.

**No prior decision record forecloses this coupling.**
`context/patterns/batch-orchestration-guardrails.md`'s Exclusion Table records only the
self-modification-hazard reachability exclusion for this script (it runs strictly after/outside
admission decisions, so it is exempt from the orchestrator-critical-paths self-modification
list) — it says nothing about roadmap awareness.
`context/contracts/conclusion-stage.md`'s Step 7 records only that the suggester's invocation is
informational and not a fourth approval channel; its single invocation line
(`orchestrate-suggest-next-batch.sh --next-batch --session-id "$session_id"`) is unaffected by
this change — the roadmap-walk logic lives entirely inside the script being invoked, not in the
Step 7 call site. The nearest closed, now-archived record
(`conclusion_stage_next_batch_proposal_quality`) that introduced
`select_candidates_for_criterion` and the three-option render explicitly preserved the net
selection "byte-identical to before" and only touched roadmap INTEGRATION in the sense of the
`--prune`/`--regenerate` equivalence — it never made `roadmap_batches` a selection input. Nothing
settled is overturned.

**Render-shape documentation has one anchor that will need a new case.**
`context/patterns/orchestrate-batch-results-template.md`'s `**Suggested next batch**:` line
(around line 236) is the only place the suggester's output cases (no-suggestible-batch,
colliding-pair sequence, multi-option render, cap-reached) are catalogued for the conclusion
report's consumers; `context/contracts/conclusion-stage.md`'s Step 7 points at this same
template for "the exact render shape." A fifth case ("names an authored roadmap batch" vs. "no
authored batch was admissible, falling back to mechanical selection") belongs here.

### Live-corpus validation of the proposed rule

Simulated the proposed walk-and-filter rule (readiness-filter each `roadmap_batches` entry's
`task_ids` in array order; first non-empty filtered batch is the candidate for probing) against
the CURRENT `specs/state.json` (68-task live ready pool; 15 live `roadmap_batches` entries — note
this is the present corpus, already different from the dispatch's cited 2026-11-16 snapshot,
since this is a live, continuously-regenerated system):

| Batch (authored order) | `task_ids` | Readiness-filtered |
|---|---|---|
| 1. Prioritized four-task run | 534,543,547,638 | **empty** |
| 2. verify-deploy.sh lane | 585,572,591 | **empty** |
| 3. Sapience strand | 527,628,635,636,627,637 | **empty** |
| 4. Gate 8 roster run | 568,476,624,586,604,605 | **empty** |
| 5. Failure-accounting tail | 577,609 | **[577]** |
| 6. Five-finding battery | 629,630,631,632,633 | [629,631,632,633] |
| 7. Gate-timeout pair | 607,610 | [607] |
| 8-15. (later batches) | ... | various non-empty |

The first four authored batches filter to empty because every one of their members is currently
mid-lifecycle (implementing, blocked, or otherwise excluded by `build_ready_pool()`'s
status/dependency checks) — consistent with the dispatch's own account of "a live four-task
orchestration" having just dispatched exactly that first batch. Under the proposed rule, these
four are skipped at **zero probe-invocation cost** (the filter alone determines emptiness,
before any call to `orchestrate-batch-admit.sh`), and batch 5's singleton `[577]` becomes the
first candidate actually probed. This confirms two things: the rule is cheap on a corpus with
several not-yet-ready leading batches, and it does not require every candidate to be a multi-task
"batch" — a filtered-to-one-member authored entry is a valid, probe-worthy candidate like any
other (`suggest_from_candidates()` already accepts a length-1 candidate list). Batch 6's partial
filtering (`630` dropped because its own rationale states a direct dependency on `629`, not yet
completed) demonstrates the `render_next()`-style "mix of terminal/not-ready and live members
renders the live members only" precedent applies cleanly to a mid-sized batch too.

This is a point-in-time measurement of a continuously-mutating corpus (task statuses, and
`roadmap_batches` itself, change between orchestration runs) — it is reported as evidence that
the rule behaves sensibly on real data, not as a claim that batch 5/`[577]` will still be the
first candidate by the time this task is implemented.

## Recommendations

1. **Adopt Direction (a)** (roadmap_batches as primary candidate source) as the fix, not
   Direction (c) (replace the ascending tiebreak with a fan-out signal) and not a parallel,
   always-dual Direction (b) render. Rationale: the ACCEPTANCE criterion's own wording — "a
   conclusion-stage suggestion either names an authored roadmap batch, or states plainly why no
   authored batch was admissible and what it fell back to" — is an either/or contract that
   Direction (a) satisfies directly (success case names the batch; failure case states the
   fallback reason) and Direction (c) cannot satisfy at all (it never names an authored batch,
   roadmap-aware or not). Direction (b)'s goal — making a divergence visible rather than silently
   resolving it in the mechanical surface's favor — is better served by Direction (a)'s explicit
   fallback statement (which IS the divergence, named) than by rendering both surfaces side by
   side on every single invocation, which would restore exactly the "two disjoint lists, which do
   I trust" confusion the dispatch's PROBLEM section describes, just packaged together instead of
   separately.
2. **Implementation shape** (for the plan to size and phase):
   - Factor `build_ready_pool()`'s per-task readiness predicate into a reusable form (an
     associative "is-ready" set built once, consumed both by the existing flat ready-pool
     emission and by a new batch-filtering step) rather than duplicating the readiness jq/shell
     logic a second time.
   - Add a roadmap-walk step inside `mode_next_batch()`, run BEFORE the existing three mechanical
     criteria: read `.roadmap_batches` from `STATE_FILE` (absent/empty -> skip straight to
     mechanical options, no probe spent); for each batch in array order, filter `task_ids` to
     ready members (mirroring `render_next()`'s terminal-member-omission precedent, extended with
     the fuller readiness bar); skip a batch whose filtered set is empty (no probe invocation
     spent, per the live-corpus validation above); probe the first non-empty filtered batch via
     the EXISTING, unmodified `suggest_from_candidates()`.
   - On success (a batch, or a readiness-filtered subset of one, is rendered), stop — do not also
     render the three mechanical options for that invocation (the either/or framing above).
   - On exhausting all `roadmap_batches` entries (every one empty-filtered or probe-exhausted),
     print one explicit, loud line naming how many authored batches were checked and why none was
     admissible, then fall through to the existing three-criterion mechanical render unchanged.
   - Route any cap-reached condition hit during the roadmap walk through the EXISTING
     `PROBE_CAP_HIT`/cap-reached rendering convention in `run_candidate_round()` — never a second,
     differently-worded cap message.
   - Surface the batch's own `description` (and optionally the first line of `rationale`) in the
     rendered output alongside the `/orchestrate <ids>` line, so the operator sees WHY this batch
     was authored, not just which numbers to run.
3. **Test-suite additions** to `scripts/tests/test-orchestrate-suggest-next-batch.sh`, using its
   existing `build_scratch()`/`add_task()` scratch-tree pattern plus a new small helper to set
   `.roadmap_batches` on the scratch `state.json` via `jq`:
   - A clean roadmap batch, all members ready, no collision -> renders the roadmap batch, names
     its description, consumes exactly one probe invocation, and the three mechanical options are
     NOT also rendered.
   - **Absent `roadmap_batches` key** (ACCEPTANCE explicitly names this path) -> silently skips
     the roadmap walk (zero probes spent on it) and falls through to the existing mechanical
     render unchanged.
   - **Empty `roadmap_batches: []`** (ACCEPTANCE explicitly names this path too, distinct from
     absent) -> same fallback behavior.
   - Every batch's filtered set is empty (all members not ready) across 2+ authored batches ->
     explicit "no authored batch was admissible" line naming the batches checked, then
     mechanical fallback renders as today.
   - A batch with an internal file_scope collision -> the EXISTING ordered-sequence /
     `propose_edge_for_pair()` rendering fires exactly as it does today for a mechanical
     candidate set (no new collision-handling code path — same `suggest_from_candidates()` call).
   - A batch whose filtered set is a non-empty PROPER subset of its authored `task_ids` (one
     member not ready) -> the rendered suggestion correctly omits the not-ready member,
     mirroring `render_next()`'s own documented behavior.
   - First authored batch empty-filtered or fully deferred, second batch admissible -> second
     batch renders; the first's skip is visible in the output (not silently absorbed).
4. **Documentation updates**: add the new case to
   `context/patterns/orchestrate-batch-results-template.md`'s `**Suggested next batch**:` section
   (the fifth render case named above); no change needed to
   `context/contracts/conclusion-stage.md`'s Step 7 invocation line itself, since the call site
   is unchanged — only the invoked script's internal behavior changes, and `roadmap_batches`
   already lives inside the same `specs/state.json` Step 7's own text already cites as this
   step's sole input ("it derives from `specs/state.json`").

## Decisions

- **Primary candidate direction: (a).** Rejected (b) as an always-on parallel render (restores
  dual-surface confusion) and (c) as insufficient (never satisfies the "names an authored
  roadmap batch" half of ACCEPTANCE). (b)'s spirit is preserved as the fallback-explanation
  message, not as a standing dual render.
- **Readiness filtering is local, pre-probe, and reuses two existing precedents rather than
  inventing a third**: `build_ready_pool()`'s fuller readiness bar (status + dependency
  completion) and `render_next()`'s "omit terminal, render still-live members only" convention
  for a mixed batch. No new readiness semantics are introduced.
- **A roadmap batch that succeeds suppresses the mechanical three-option render for that
  invocation**; the mechanical render remains the fallback path, used only when no authored batch
  survives filtering + probing.
- **Cap-reached handling during the roadmap walk reuses the existing `PROBE_CAP_HIT` /
  cap-reached rendering convention** rather than adding a second cap message.

## Risks & Mitigations

- **Risk**: a `state.json` with many `roadmap_batches` entries whose leading batches are mostly
  not-ready could still consume probe invocations once it reaches batches with non-empty filtered
  sets, potentially exhausting `MAX_PROBE_INVOCATIONS` before reaching the mechanical fallback.
  **Mitigation**: empty-filtered batches cost zero probes (confirmed on the live corpus: 4
  leading empty batches, zero probe cost); only non-empty filtered batches probe. If this proves
  insufficient in practice, a `MAX_ROADMAP_BATCHES_TRIED` cap (mirroring `MAX_BATCH_OPTIONS`'s
  existing pattern) is a cheap, bounded addition — size this only if the plan's own testing shows
  it is needed, not speculatively.
- **Risk**: a `roadmap_batches` entry can reference a `task_id` no longer present in
  `active_projects` at all (archived via a vault operation, or simply stale authoring) rather
  than merely terminal. **Mitigation**: treat "absent from `active_projects`" identically to
  "not ready" in the filter (it already falls out of the same jq lookup `build_ready_pool()`
  uses, which treats an absent dependency as satisfied but an absent CANDIDATE itself should be
  excluded, not silently treated as ready) — confirm this exact edge case gets one of the plan's
  test cases.
- **Risk**: surfacing `description`/`rationale` text in the rendered suggestion could leak
  record-versioning or task-reference language if an authored batch's rationale uses it.
  **Mitigation**: none needed structurally — `roadmap_batches` content is itself `specs/**`
  (task-management metadata), exempt from `no-task-references-in-deliverables.md` and
  `no-record-versioning-in-deliverables.md` per their own stated `specs/**` exemptions; the
  suggester's own stdout is also conclusion-stage reporting, not a deliverable file.

## Context Extension Recommendations

- **Topic**: the relationship between `build_ready_pool()`'s readiness predicate and
  `roadmap-integration.sh`'s terminal-member-filtering in `render_next()`.
- **Gap**: no existing context file states that these are the SAME underlying readiness concept
  applied at two different bars (terminal-only for rendering an authored batch that already
  landed; the fuller non-terminal-and-not-stuck-and-deps-satisfied bar for suggesting a batch to
  run next). A future reader modifying either one in isolation could silently diverge the two.
- **Recommendation**: once this task's implementation lands and factors `build_ready_pool()`'s
  predicate into a reusable shared form, record the shared-readiness-concept relationship in
  `context/patterns/batch-orchestration-guardrails.md` (which already owns this script's
  Exclusion Table entry) rather than leaving it implicit in two scripts' comments only.

## Appendix

- Search queries / commands used: `grep -rn roadmap_batches` over `scripts/` and `context/`;
  full reads of `orchestrate-suggest-next-batch.sh` (1085 lines) and the relevant sections of
  `orchestrate-batch-admit.sh`, `roadmap-integration.sh`, `context/schemas/state-schema.json`,
  `context/contracts/conclusion-stage.md`, `context/patterns/batch-orchestration-guardrails.md`,
  `context/patterns/orchestrate-batch-results-template.md`, and
  `scripts/tests/test-orchestrate-suggest-next-batch.sh`'s scratch-tree helpers; a live jq
  simulation of the proposed readiness-filter-then-walk rule against the current
  `specs/state.json` (68-entry ready pool, 15-entry `roadmap_batches`).
- References: `agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh`,
  `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh`,
  `agent-system/extensions/core/scripts/roadmap-integration.sh`,
  `agent-system/extensions/core/context/schemas/state-schema.json`,
  `agent-system/extensions/core/context/contracts/conclusion-stage.md`,
  `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`,
  `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md`,
  `agent-system/extensions/core/scripts/tests/test-orchestrate-suggest-next-batch.sh`.
