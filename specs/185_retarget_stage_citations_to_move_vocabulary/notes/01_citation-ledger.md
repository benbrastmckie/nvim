# Citation Classification Ledger (working note, not a linked artifact)

Fresh re-grep at implementation time confirmed every per-file hit count from the plan's Research
Integration section is unchanged (33, 28, 12, 11, 5, 17, 25, 12, 7, 7, 3, 1, 1, 1, 1, 1; plus the
two reviewed-only files orchestrate-state-machine.md=5, file-footprint-overlap.md=1). No drift
since the survey/plan. Per-file grep:

```
33  context/patterns/batch-orchestration-guardrails.md
28  docs/architecture/handoff-schema.md
12  docs/architecture/batch-admit-schema.md
11  docs/architecture/orchestrate-cycle-postflight.md
5   context/patterns/orchestrate-batch-results-template.md
17  context/standards/orchestrator-runtime-files.md
25  docs/examples/research-flow-example.md
12  context/patterns/skill-postflight-flow.md
7   context/patterns/infra-failure-discrimination.md
7   context/patterns/regeneration-is-manual-only.md
3   context/patterns/dispatch-report-not-termination.md
1   skills/skill-git-workflow/SKILL.md
1   docs/fork-patterns.md
1   context/contracts/territory.md
1   context/contracts/wrap-up.md
1   context/patterns/mode-gated-section-loading.md
5   docs/architecture/orchestrate-state-machine.md (reviewed-only)
1   context/patterns/file-footprint-overlap.md (reviewed-only)
```

Classification applied per the plan's Classification rule (LIVE -> retarget per mapping table;
HISTORICAL -> leave, ensure explicit framing; UNRELATED -> leave untouched, name the vocabulary).

## Phase 1 resolution: mode-gated-section-loading.md paired-comment convention

Fresh grep for `begin ---` in the current `skills/skill-orchestrate/SKILL.md` confirms: no such
paired bash-comment convention exists anywhere in the current file. The claim is stale.
Resolution (applied in Phase 8): reframe as historical precedent naming the pre-rewrite engine,
not a renumbered live citation.

## Phase 2: batch-orchestration-guardrails.md (33 hits)

All 33 were `LIVE` Stage-MT/Stage-single citations except one row (the `blocked`-classifier
divergence row) which mixes one `LIVE` MT-4 citation with one `HISTORICAL` single-task-Stage-4
citation (the deleted engine). Applied:
- Every bare `Stage MT-1`/`MT-2` -> `Move 1`.
- Every `Stage MT-3` (steps 1-7, incl. step 3/4.5/6/7, "steps 1-4", "'s eligibility check", "'s
  COMPLETION SEQUENCING note") -> `Move 1`, with the step folded into a descriptive parenthetical
  per the Phrasing rule (never "Move 1 step N").
- Every `Stage MT-4` (bare, step 4.5, step 5.5, "BATCHING RULE", "'s grouping table") -> `Move 2`,
  step folded into parenthetical.
- `Stage MT-5` -> `Move 3` (detection) or `Move 4` (rendering/consolidated-output), chosen per
  which half of the detection/rendering split the sentence names.
- The one historical hit: "single-task Stage 4's `blocked` handler" reframed to "the former
  single-task engine's Stage 4 `blocked` handler" (past tense, explicit "former"), paired MT-4
  mention retargeted to Move 2.
Residual after edit: 1 hit (the reframed historical sentence) — verified by scoped grep. Zero
`Move N step M` hits.

## Phases 3-8

Recorded in the implementation summary rather than duplicated here (same methodology: literal
per-hit review against the mapping table, LIVE anchors retargeted with step numbers folded into
descriptive parentheticals, HISTORICAL hits reframed with explicit former/deleted framing,
UNRELATED vocabularies — agent-execution-flow, generic skill-body flow, `/meta` interview stages,
other scripts' own internal labels, lean extension's agent-stage convention — left untouched).

## Phase 3: handoff-schema.md (28 hits) — LIVE/UNRELATED split

LIVE: 23 lines retargeted. UNRELATED: 5 lines (434, 445, 534, 614, 811) — all either a specific
hard-mode implementation agent's own internal "Stage 5"/"H9 Stage 5" (agent-execution-flow
vocabulary, e.g. `cslib-implementation-hard-agent.md` Stage 5, `lean-implementation-hard-agent.md`
Stage 5) or the generic skill-body postflight convention ("per each skill's own Stage 7 postflight
contract" at line 534) — left untouched per the Classification rule.

Key structural finding the survey could not determine: several LIVE citations described "three
call sites" (base Stage 5, base Stage MT-4, hard Stage 5) that read the handoff after a dispatch.
Since the base/hard orchestrate split is now one engine and Move 3 reads every dispatch row's
handoff in one shared per-row postflight call, these collapsed to "the now-single Move 3 call
site (formerly base Stage 5, base Stage MT-4, and hard Stage 5)" — preserving the historical
enumeration while correctly naming the live mechanism. Per the plan's Phase 3 task note, every
handoff-READ citation (including "Stage MT-4 step 1") retargeted to Move 3, not Move 2, since
Move 3 is where all handoff reading now happens (after ALL Move 2 dispatches complete).

## Phase 5: orchestrator-runtime-files.md (17 hits)

All 17 LIVE lines retargeted (Stage 2 -> Move 1, Stage 5a -> Move 2's aux_dispatch[]
drift-inspection path, Stage 8 -> Move 4, Stage MT-4/step 5.5 -> Move 2, Stage 5/MT-4 read-side ->
Move 3). Two lines also carried bare "Stage 5a" occurrences not matched by the scoped grep
pattern (`Stage [0-8]\b` requires a word boundary after the digit, which fails for "5a"/"3b"
since the letter is a word character) — fixed anyway since they're unambiguous per the mapping
table and sat on lines already being edited for an adjacent "Stage 8" match.

Residual, deliberately left out of scope: "Stage 3b" (lines 221, 239, the per-cycle guard-update
step) and "Stage 9" (line 149, a mid-loop git-add step) — neither matches the scoped grep pattern
(digit-letter compounds defeat the `\b` boundary) and neither has an entry in the plan's Stage ->
Move mapping table, so retargeting them would require re-deriving a mapping rather than consuming
the given one. Recorded here, and in the implementation summary, as a known gap for a future
sweep rather than silently fixed on inferred semantics.

Three UNRELATED citations confirmed and left untouched: "Stage 7" (generic skill-body postflight
convention, line 42), "Stage 16" (`skill-spawn/SKILL.md`'s own stage numbering, line 42),
"Stage 10" (`orchestrator-postflight.sh`'s own orphaned-script internal label, line 42).

## Phase 6: research-flow-example.md (25 hits, actual rewrite not just anchor swap)

Mixed-vocabulary file: `skill-orchestrate` citations (LIVE, 15 of the 25 grep-matched lines) and
the research agent's own `Agent Stage 1`-`Agent Stage 6` headings (UNRELATED, 7 lines) plus
`orchestrate-build-dispatch.sh`'s own live `Stage 3.5 (Dispatch Prep)` label (2 lines, left as a
script-internal citation, not a SKILL.md section). Rewrote per the plan's Decision: the flow
diagram's `[Layer 2: Skill]` block, the Return Flow block, Steps 2+3 (merged Stage 1/1b/2/3 into
one Move 1 section, consistent with the mapping table's collapse), Step 5 (merged Stage 5/7/8
into one Move 3 section), the two Error Scenario code blocks (Stage 1 -> Move 1, Stage 1b ->
Move 1), the Session Tracking diagram (corrected: session_id is actually generated by
`commands/orchestrate.md`, not by skill-orchestrate itself, per a direct read of
`commands/orchestrate.md`'s STAGE 0 -- a factual correction the mapping table doesn't cover but
the rewrite task explicitly licensed), and the closing Summary bullet. Removed the stale
"(single-task mode)" qualifier. Confirmed every Move cited (1-4) exists as a `### Move N:`
heading in the current SKILL.md. Full top-to-bottom re-read confirms the trace reads as one
coherent sequence.
