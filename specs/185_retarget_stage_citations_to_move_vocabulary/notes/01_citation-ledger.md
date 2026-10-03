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
