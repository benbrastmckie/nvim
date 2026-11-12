# Research Report: Task #602

**Task**: 602 - Improve the conclusion stage's next-batch proposal quality
**Started**: 2026-11-12T00:00:00Z
**Completed**: 2026-11-12T00:00:00Z
**Effort**: medium-large (four distinct defects, one script rewrite, one contract/template update,
one test companion)
**Dependencies**: None (`dependencies: []`); see Territory/Batching finding below for the
non-dependency coordination this task still owes
**Sources/Inputs**: Codebase (`agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh`,
`orchestrate-batch-admit.sh`, `roadmap-integration.sh`, `context/contracts/conclusion-stage.md`,
`context/patterns/orchestrate-batch-results-template.md`, `context/patterns/batch-orchestration-guardrails.md`,
`scripts/tests/test-orchestrate-suggest-next-batch.sh`), `specs/state.json`/`specs/TODO.md`
(open-task territory search)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Defects 1-3 (pair sequences pre-empt the joint batch; one suggestion with no options; edges
  proposed but never written) are all confirmed live in
  `agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh` exactly as the dispatch
  describes, read line-by-line in `suggest_from_pool()` / `propose_edge_for_pair()`. The fix for
  all three lives in that one script plus the Step 7 invocation in `conclusion-stage.md` and its
  rendering contract in `orchestrate-batch-results-template.md`.
- **Defect 4's premise is now moot, measured live.** `roadmap-integration.sh --prune` is no
  longer "built and working but excluded" — it is a **deprecated alias for `--regenerate`**
  (`mode_prune()` reassigns `MODE="regenerate"` and calls `mode_regenerate` directly), because
  `--regenerate` now renders `## Next` and `## Open work` **wholly from `specs/state.json`** (per
  that script's own header and `mode_regenerate`'s body), so a terminal task can never be
  rendered into the file in the first place and there is nothing left to prune. This is a
  downstream effect of the already-completed `roadmap_generator_stage_layout_and_silent_abort`
  work and task 603's recent "regenerate wholly from state" migration (see git log). The required
  action for Defect 4 is therefore the "reasoned no" branch the dispatch itself sanctions: record
  that the original exclusion ruling needs no revisiting because its premise (terminal cruft
  accumulating) no longer exists, and optionally correct `conclusion-stage.md` Step 5's comment
  (which still cites the old "D3: removes content outright" framing) to state the current reason
  instead.
- **The Territory Note's "three other open records" is stale by one.** Task 391
  (`agent_system_task_siting_and_target_root`) — the "agent-system task siting" record the note
  names — **completed and archived 2026-11-11** (one day before this dispatch). Searching
  `specs/state.json` live for every non-terminal task declaring
  `agent-system/extensions/core/context/contracts/conclusion-stage.md` in `file_scope` turns up
  exactly **two** others: task 558 (`conclusion-stage filing phrasing`, not_started) and task 562
  (`conclusion stage drops null-resolution issue-log entries`, not_started). Per
  `batch-orchestration-guardrails.md` Rule 1, these edit different sections of the same file
  (558: siting/phrasing convention; 562: "The Filter Predicate"; 602: Step 7/next-batch
  suggestion), so the required disposition is still BATCH or an explicit serializing edge — never
  exclusion — just against a two-task territory group, not three.
- The verdict schema fields needed to detect an `in_batch file_scope_collision` pair
  (`decision`, `defer_reason`, `collision_scope`, `colliding_task_number`) are already fully
  documented in `orchestrate-batch-admit.sh`'s header and already consumed correctly by
  `suggest_from_pool()`; no admission-predicate changes are needed anywhere in this task.
- `MAX_PROBE_INVOCATIONS=20` is a single shared counter across every probe call this script makes
  in one invocation (shrink-retry rounds in both Mode A/B, plus every `propose_edge_for_pair()`
  re-probe under `--write-edges`). Rendering several batch options multiplies probe consumption,
  so Defect 2's "decide how many options" must be sized against that shared budget explicitly
  (see Risks below).

## Context & Scope

This is a `meta` task editing the agent-system source store
(`agent-system/extensions/core/**`, never the deployed `.claude/**` tree — confirmed via
`.claude-extensions.json`'s `core.source_dir` resolving to
`/home/benjamin/.config/nvim/agent-system/extensions/core`). The task improves the
`/orchestrate` conclusion stage's Step 7 ("Suggest next batch") so that an orchestration run ends
with actionable output: a joint batch suggestion that coexists with (not is replaced by) any
collision-pair sequences, several labelled batch options instead of one, an actual edge-write
path gated by approval, and a settled ruling on whether the roadmap should be pruned as well as
regenerated.

Four files form the executable core of the defect:
`agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh` (748 lines, the script
under repair), `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` (the admission
predicate this script must keep calling, never re-deriving), `agent-system/extensions/core/context/contracts/conclusion-stage.md`
(the Step 5/Step 7 caller contract), and `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md`
(the render contract for the `**Suggested next batch**:` line). A companion test file,
`agent-system/extensions/core/scripts/tests/test-orchestrate-suggest-next-batch.sh` (379 lines),
already exists and is already registered in `manifest.json`; this task extends it rather than
creating a new one.

## Findings

### Codebase Patterns

**Defect 1 — root cause confirmed exactly as described.** In `suggest_from_pool()`
(`orchestrate-suggest-next-batch.sh:587-671`), each round:
1. Probes the current `remaining` candidate set via `probe_candidate_set()`.
2. Runs the "edge-proposing pass" (lines 612-636): for every `defer` verdict whose
   `defer_reason == "file_scope_collision"` and `collision_scope == "in_batch"`, it calls
   `propose_edge_for_pair()` and adds **both** members of the pair to `handled_pair_members[]`.
3. Buckets the remaining verdicts (lines 638-654), explicitly skipping anything in
   `handled_pair_members[]`.
4. Only renders the plain joint `/orchestrate a, b, c` line (lines 656-665) when **both**
   `dropped_other` and `handled_pair_members` are empty for that round — i.e., only when a round
   has zero collisions and zero other defers at all.

When the first round's selected set is entirely collision pairs (the measured 8-candidates/4-pairs
case), `handled_pair_members` consumes the whole set, `next_remaining` is empty, the `while`
loop exits on its own guard (`${#remaining[@]} -gt 0`), and the function falls through to
`[ "$any_sequence_rendered" = true ] && return 0` (line 669) — reporting success having never
reached the joint-batch branch even once. This confirms the dispatch's root-cause claim precisely;
nothing in the description overstates the defect.

**Defect 2 — confirmed.** `mode_next_batch()` (lines 675-692) and `mode_alternatives()`
(lines 698-738) each call `suggest_from_pool()` exactly once and `exit 0` immediately after. There
is no loop over "selection doctrine" variants (shared territory / topic cohesion / graph width —
the three criteria `select_candidates()` already implements as Pass 1/2/3, lines 412-456) to
produce multiple labelled options; whichever single candidate set `select_candidates()` orders
first is the only one ever probed.

**Defect 3 — confirmed, and the remedy path already exists end-to-end.**
`propose_edge_for_pair()` (lines 533-576) always prints the `--depends-on-add` command (line 552).
Lines 555-574 show the `--write-edges` branch is already fully built: it calls
`update-task-status.sh` for real, re-probes via the shared `probe_candidate_set()`, and renders
the flip to `admit` via `render_verdict_evidence()`. The gap is purely at the **caller** level:
`conclusion-stage.md`'s Step 7 (lines 373-391) invokes
`orchestrate-suggest-next-batch.sh --next-batch --session-id "$session_id"` with no
`--write-edges`, and the step is documented as "INFORMATIONAL" with no `AskUserQuestion` gate at
all. Fixing Defect 3 means adding a gate to Step 7 (mirroring the existing per-channel gate
pattern Steps 3/4a already use) and conditionally re-invoking with `--write-edges` on approval —
not touching the script's own already-correct `--write-edges` implementation.

**Defect 4 — premise dissolved, measured live.** Read in full
(`agent-system/extensions/core/scripts/roadmap-integration.sh:1-22` and `:800-847`):

```
#   roadmap-integration.sh --prune [--dry-run]        DEPRECATED alias for --regenerate: a file
#                                                      rendered from live state accumulates no
#                                                      terminal cruft, so there is nothing left
#                                                      for a separate prune pass to remove
...
mode_prune() {
  echo "NOTE: --prune is deprecated: a file rendered from live state accumulates no terminal cruft; running --regenerate instead." >&2
  MODE="regenerate"
  mode_regenerate
}
```

`mode_regenerate` renders `## Next` and `## Open work` **wholly** from `roadmap_batches`/
`roadmap_notes`/`active_projects` (confirmed by the header's own "there is no retention parser
anywhere in this script: nothing here reads authored content back out of the file it is about to
overwrite" and by `PRUNED_COUNT=0` being hard-coded in `mode_regenerate`'s body). A terminal task
is therefore never rendered into the file at all — there is no "terminal cruft" state to clear.
This is consistent with the git history visible at session start (`8f4bb947d task 603 phase 7:
migrate ## Next's authored judgment into roadmap_batches/roadmap_notes and regenerate
specs/ROADMAP.md wholly from state`), which post-dates whatever version of the script Defect 4's
description was written against. The dispatch's framing ("if the conclusion is to keep the
exclusion, record that as the outcome with its grounds — a reasoned no is a valid completion") is
exactly the applicable outcome here, just for a different reason than originally anticipated: not
"the original caution still outweighs the need" but "the need itself no longer exists."

### Admission-Predicate Boundary (confirmed respected by the existing script)

`orchestrate-batch-admit.sh`'s header (read at lines ~108-294) fully documents the verdict schema
fields `suggest_from_pool()` already consumes without re-deriving: `decision` (`"admit"`/
`"defer"`, never `"fail"`), `defer_reason` (closed set including `"file_scope_collision"`),
`collision_scope` (`"in_batch"` vs. cross-batch), `colliding_task_number`, `overlapping_path`,
and `corroborated_by`. Every one of these is read via `jq -r` directly off the NDJSON stream in
the existing script (lines 618-632); there is no local overlap/collision re-implementation to
find or remove. This task's "WHAT THIS TASK IS NOT" guardrail is therefore trivially satisfiable
by leaving `probe_candidate_set()` and its NDJSON-reading call sites exactly as they are and only
adding a **loop** over them (for multiple options) and a **gate** around the existing
`--write-edges` call (for Defect 3) — no new field, no new overlap check.

### Probe-Budget Interaction (Defect 2 sizing constraint)

`MAX_PROBE_INVOCATIONS=20` (line 237) is one counter shared by **every** call to
`probe_candidate_set()` within a single script invocation: each shrink-retry round in
`suggest_from_pool()`, and each `--write-edges` re-probe inside `propose_edge_for_pair()`. On a
dense backlog (the measured case had 4 collision pairs in round 1 alone, each consuming one probe
via the edge-proposing pass plus the round's own probe), a small number of rounds can already use
a meaningful fraction of the 20-probe budget. Rendering "several distinct admissible batch
options" (Defect 2) means running `select_candidates()`'s doctrine variants (territory-mandatory
group vs. topic-cohesion group vs. a wider graph-width set) as **separate** candidate pools, each
needing its own `suggest_from_pool()`-style shrink loop — i.e., each option can itself consume
several probes before stabilizing. The existing cap-reached message
(`"Alternatives/batch search stopped: ... MAX_PROBE_INVOCATIONS=${MAX_PROBE_INVOCATIONS} ..."`,
line 605) already renders explicitly on exhaustion; the implementer's job is to make sure that
same explicit message still fires if a multi-option render exhausts the shared cap partway
through, rather than silently truncating the option list.

### Territory / Batching Finding (re-verify at dispatch, not frozen here)

Live `specs/state.json` query for every non-terminal task whose `file_scope` names
`agent-system/extensions/core/context/contracts/conclusion-stage.md`:

| Task | Status | Title | Section touched |
|------|--------|-------|------------------|
| 558 | not_started | Require task descriptions to request a proposal packet instead of instructing a dispatch to file tasks | siting/phrasing convention (where the task-filing-phrasing rule should live) |
| 562 | not_started | conclusion stage drops null-resolution issue-log entries | "The Filter Predicate" |
| 602 | researching (this task) | Improve the conclusion stage's next-batch proposal quality | "## The Executable Stage Body" Step 7 (and Step 5's `--prune` comment) |

Task 391 (`agent_system_task_siting_and_target_root`), the record the dispatch's Territory Note
names as the third co-declarer, is **completed and archived**
(`specs/archive/391_agent_system_task_siting_and_target_root/`, started 2026-11-11T18:24:36Z) —
one day before this dispatch (`dispatch_start_ts` corresponds to 2026-11-12). It no longer
declares `conclusion-stage.md` as an open file_scope entry. The guardrails' Rule 1 default move
(batch, or serialize with an explicit `dependencies[]` edge — never exclude) still applies, just
to a two-task group (558, 562) rather than three. This should be re-confirmed once more at actual
plan/dispatch time, since state can change between research and dispatch, per this task's own
"Decide at dispatch time, not here" instruction.

## Recommendations

1. **Defect 1/2 fix, single composed change in `suggest_from_pool()`**: stop treating
   `handled_pair_members` as removed-from-consideration for the *joint-batch render*, only for the
   *next probe round's candidate set*. Concretely: after the edge-proposing pass runs and renders
   sequence lines, if `next_remaining` (the admitted, non-paired members) is non-empty, render a
   joint `/orchestrate ...` line for `next_remaining` **in addition to** the sequence lines,
   rather than only on a no-collision round. This directly satisfies the acceptance criterion
   ("A fixture pool whose selected candidates are all collision pairs renders at least one joint
   batch line IN ADDITION to the pair sequences") without touching the admission probe itself.
2. **Defect 2, options**: wrap the existing single-pool call in a small outer loop over
   `select_candidates()`'s three doctrine groups (territory-mandatory, topic-cohesion, remaining
   graph-width pool), rendering each as its own labelled option with its own evidence, while
   feeding all three through the one shared `probe_candidate_set()`/`MAX_PROBE_INVOCATIONS`
   counter. Decide and record a concrete option count (e.g. up to 3, one per doctrine criterion)
   rather than leaving it open-ended.
3. **Defect 3 fix**: add an `AskUserQuestion` gate to Step 7 in `conclusion-stage.md` (and its
   execution in the orchestrate lead), presenting the proposed edges from a first,
   non-`--write-edges` run; on approval, re-invoke with `--write-edges` (or thread an
   already-decided flag through one invocation) and fold the resulting re-probe evidence into the
   report. A declined approval must leave `specs/state.json` byte-identical — i.e., the default
   (no `--write-edges`) code path must never run when declined.
4. **Defect 4 disposition**: record the "reasoned no" outcome for the original exclusion ruling —
   not because the original caution still holds, but because `--prune` no longer does anything
   `--regenerate` doesn't already do. Update `conclusion-stage.md` Step 5's comment (currently
   "Per this task's D3: `--prune` is deliberately out of scope... it removes content outright, a
   stronger unattended action than an idempotent regenerate") to state the current fact instead
   of the stale D3 rationale, since that rationale is no longer true of the live script.
5. **Batching**: batch this task with 558 and 562 (or add an explicit serializing
   `dependencies[]` edge if parallel dispatch is judged unsafe for some other reason found at plan
   time), per `batch-orchestration-guardrails.md` Rule 1 — never exclude them from the orchestration
   despite sharing `conclusion-stage.md`.
6. **Template update**: `orchestrate-batch-results-template.md`'s `**Suggested next batch**:` line
   currently documents the *old* (defective) either/or behavior ("A colliding pair renders as its
   own ordered-sequence line ... instead of a plain joint list"). This sentence must be rewritten
   to describe the additive behavior once Defect 1 is fixed, and extended to describe the
   multi-option render from Defect 2, or a future reader will treat the old documented behavior as
   the spec.

## Decisions

- No admission-predicate or overlap-comparison code is added anywhere in this task; every
  overlap/collision fact continues to arrive as a field on an `orchestrate-batch-admit.sh`
  verdict, per the script's own binding constraint (disposition (a) in its header) and this
  task's own "WHAT THIS TASK IS NOT" guardrail.
- Defect 4 is resolved as a documentation/ruling update, not a code change to
  `roadmap-integration.sh` itself: `--prune` already is what the dispatch asked the conclusion
  stage to adopt (an idempotent, state-driven render), just under the `--regenerate` name: `--prune`
  is a no-op alias for exactly that. No new roadmap-script flag is needed.

## Risks & Mitigations

- **Risk**: rendering multiple batch options could blow the shared `MAX_PROBE_INVOCATIONS=20`
  budget on a dense ready pool (the measured 138-task pool had 4 collision pairs in round one
  alone). **Mitigation**: keep the existing cap-reached message wired to fire the moment the
  shared counter is exhausted mid-multi-option-render, exactly as it already does for a single
  option, and cap the option count itself (recommendation 2) rather than letting doctrine variants
  multiply unboundedly.
- **Risk**: a `--write-edges` gate added at Step 7 could be miswired to fire on a *different*
  channel's approval (violating the conclusion stage's load-bearing "no channel fires on another
  channel's approval" invariant). **Mitigation**: Step 7 is explicitly documented as
  INFORMATIONAL/no-gate today; adding a gate here must get its own dedicated ledger entry via
  `orchestrate-conclusion-aggregate.sh --record-approval`/`--check-approval` (or an equivalent
  dedicated mechanism), never reusing channel (a)'s "channel a" ledger key.
- **Risk**: the territory finding above (391 completed, only 558/562 remain) could itself go
  stale again before dispatch. **Mitigation**: the dispatch's own instruction ("Decide at dispatch
  time, not here") already covers this; the plan/implementation phase should re-run the same
  `file_scope` query against the then-live `specs/state.json` rather than trusting this report's
  snapshot.

## Context Extension Recommendations

- **Topic**: `roadmap-integration.sh --prune`'s deprecation.
- **Gap**: nothing in `context/patterns/roadmap-update.md` (the roadmap generator's caller
  contract, referenced from `conclusion-stage.md`'s "Roadmap Generator Caller Status" section)
  currently states that `--prune` is a deprecated no-op alias for `--regenerate`. A future reader
  investigating "should the conclusion stage prune" will hit the same stale premise this task
  started from.
- **Recommendation**: add one sentence to `context/patterns/roadmap-update.md` noting the
  `--prune`/`--regenerate` equivalence and pointing at `roadmap-integration.sh`'s own header as
  the source of truth, so the next reader doesn't have to re-derive it from the script.

## Appendix

- Search queries used: `grep -rn "conclusion-stage.md" specs/TODO.md`; `jq` queries against
  `specs/state.json` for non-terminal tasks declaring `conclusion-stage.md` in `file_scope`; `find
  specs/archive -iname '*391*'` to confirm task 391's completion; `grep -n "prune"
  agent-system/extensions/core/scripts/roadmap-integration.sh`.
- Key files read in full or substantially: `orchestrate-suggest-next-batch.sh` (748 lines, read
  whole), `context/contracts/conclusion-stage.md` (405 lines, read whole),
  `roadmap-integration.sh` (header + lines 800-847), `orchestrate-batch-admit.sh` (header verdict
  schema section), `orchestrate-batch-results-template.md` (Conclusion block section),
  `batch-orchestration-guardrails.md` (Rule 1 section), `test-orchestrate-suggest-next-batch.sh`
  (header/resolution section).
