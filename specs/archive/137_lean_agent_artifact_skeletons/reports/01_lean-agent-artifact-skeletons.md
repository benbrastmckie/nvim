# Research Report: Task #137

**Task**: 137 - Lean agent artifact skeletons
**Started**: 2026-09-03T00:00:00Z
**Completed**: 2026-09-03T00:00:00Z
**Effort**: 1-2 hours (agent-file edits only, no runtime code)
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/{core,lean,formal}/agents/*.md, extensions/core/scripts/validate-artifact.sh, extensions/core/context/formats/{report,summary}-format.md)
**Artifacts**: - path to this report
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- Confirmed the dispatch's root-cause claim by direct transcription of
  `extensions/core/scripts/validate-artifact.sh` lines 19-44: `REPORT_METADATA` = Task, Started,
  Completed, Effort, Dependencies, Sources/Inputs, Artifacts, Standards; `REPORT_SECTIONS` =
  Executive Summary, Context & Scope, Findings, Decisions, Recommendations; `SUMMARY_METADATA` =
  Task, Status, Started, Completed, Artifacts, Standards; `SUMMARY_SECTIONS` = Overview, What
  Changed, Decisions, Impacts, Follow-ups, References (a required minimum, not an exhaustive
  whitelist). Section matching is `grep -qE "^##+ ${section}"` (any heading depth, prefix match)
  and metadata matching is `grep -qF "**${field}**:"` (literal substring anywhere in the file).
- `lean-implementation-agent.md` and `lean-research-agent.md` (the plain, non-hard variants) are
  **worse than the dispatch description implies**: they don't merely lack a *skeleton* — they
  lack any *stage* that instructs writing the artifact at all. `lean-implementation-agent.md`
  references the summary's path only inside a metadata JSON example (as if the file already
  exists) and never links `summary-format.md` in Context References. `lean-research-agent.md`
  jumps straight from Stage 0 to "Write Final Metadata" with no report-writing stage and never
  links `report-format.md`.
- `lean-implementation-hard-agent.md` and `lean-research-hard-agent.md` are intermediate: both
  reference the correct format doc in Context References, and both have a named stage ("Stage 7:
  Create Implementation Summary", "Stage 6: Create Research Report"), but neither stage carries
  an inline metadata+section skeleton. The hard implementation stage is a bare content bullet
  list; the hard research stage only lists sections "not in base report" — presupposing a base
  skeleton that does not exist anywhere in the lean extension.
- **New finding beyond the dispatch's named candidates**: the sweep in work item (c) turned up a
  second, independent defect family in `extensions/formal/agents/` — all four research agents
  there (`formal-research-agent.md`, `logic-research-agent.md`, `math-research-agent.md`,
  `physics-research-agent.md`) *do* carry an inline report skeleton, but every one of them is
  missing the same 4-5 `REPORT_METADATA` fields (Effort, Dependencies, Sources/Inputs, Artifacts,
  and — except logic's Context-References mention — Standards) and the entire `## Decisions`
  required section. This is a distinct defect shape from the lean gap (skeleton present but
  incomplete, vs. skeleton absent) and was not named in the dispatch's "known candidates" list,
  which only mentioned lean's hard variants and "the formal extension's research agents"
  generically.
- Recommended approach: (1) add a full inline skeleton to `lean-implementation-agent.md` as a new
  named stage (there is no existing stage to amend), modelled verbatim on
  `general-implementation-agent.md:481-529`, including the bracketed-Status vocabulary sentence;
  (2) add a full inline skeleton to `lean-research-agent.md` as a new named stage, modelled on
  `general-research-agent.md:277-321`; (3) amend (not replace) the existing Stage 7/Stage 6 in
  the two hard agents to carry the same full skeletons, preserving their documented
  lean/hard-specific additions (sorry inventory, plan deviations from inline annotations, the
  "Adversarial Self-Verification" / "Literature Proof Structure" / "Tactic Survey Results" extra
  sections and the Tier-1 lemma-mapping-table requirement); (4) amend all four formal-domain
  report skeletons to add the missing metadata fields and the `## Decisions` section, preserving
  each agent's domain-specific extra sections (Domain Analysis, Mathlib Theorems, Context File
  Review, Appendix, etc.).

## Context & Scope

Scope: locate and characterize every agent-file artifact-skeleton gap between (a) what
`validate-artifact.sh` actually requires for `report` and `summary` artifact types and (b) what
each lean-extension and formal-extension agent file instructs an agent to write, then recommend
where and how to add or amend inline skeletons. Out of scope by explicit dispatch instruction:
weakening `validate-artifact.sh`'s required-section lists (a non-goal; task 136 is separately
tightening that validator). Also out of scope: writing the actual edits — this is the research
phase; a plan (`/plan 137`) and implementation (`/implement 137`) come next.

Constraint carried from the dispatch: transcribe the authoritative field/section lists directly
from the validator script rather than retyping from the dispatch description (done above,
verified against `extensions/core/scripts/validate-artifact.sh:19-44` and cross-checked against
`extensions/core/context/formats/{report,summary}-format.md`'s own "Example Skeleton" sections,
which match the validator's arrays exactly).

## Findings

### Codebase Patterns — the two working reference skeletons

**`general-implementation-agent.md:465-529` (Stage 6: Create Implementation Summary)** is the
model to copy for lean's summary gap. It states explicitly: "This block is the authoritative
shape of a summary artifact... The metadata header below is mandatory and MUST NOT be
abbreviated, reordered, or partially omitted — every bullet is a field the validator checks by
name," followed by the bracketed-Status vocabulary sentence the dispatch calls out by name:
"Use `**Status**: [COMPLETED]` when every plan phase is done, `**Status**: [IN PROGRESS]` on a
partial run, or `**Status**: [BLOCKED]` when blocked, matching `summary-format.md`'s declared
vocabulary." The fenced skeleton itself carries all six `SUMMARY_METADATA` fields (Task, Status,
Started, Completed, Artifacts, Standards) and all six `SUMMARY_SECTIONS` headings (Overview, What
Changed, Decisions, Plan Deviations [optional but included], Verification [extra], Impacts,
Follow-ups, References) as literal `##` headings.

**`general-research-agent.md:267-321` (Stage 6: Create Research Report)** is the model for
lean's report gap. Its fenced skeleton carries all eight `REPORT_METADATA` fields (Task, Started,
Completed, Effort, Dependencies, Sources/Inputs, Artifacts, Standards) as `**Field**:` lines and
all five `REPORT_SECTIONS` headings (Executive Summary, Context & Scope, Findings, Decisions,
Recommendations — the last two nested as `##`/`###` under Findings in one case, which the
validator's prefix-match tolerates) plus two extra sections (Risks & Mitigations, Context
Extension Recommendations, Appendix).

### Lean Extension — per-file gap characterization

| File | Format doc in Context References? | Named write stage exists? | Inline skeleton present? | Verdict |
|---|---|---|---|---|
| `lean-implementation-agent.md` | No (only `return-metadata-file.md`, `phase-closure.md`, `pre-edit-gate.md`, `long-builds.md`) | **No** — jumps from Stage 0 (`:121`) straight to "Final Verification Stage" (`:149`); the only mention of the summary path is inside the metadata-JSON example at `:244` (`"path": "specs/{NNN}_{SLUG}/summaries/..."`), presented as if the file already exists | No | **Worst gap**: no instruction anywhere in the file tells the agent to actually author the summary content. Confirmed via full-file grep for `summaries/`, `Implementation Summary`, `write.*summary`, `Create.*[Ss]ummary` — the only hit is the path-only JSON example. |
| `lean-research-agent.md` | No (only `return-metadata-file.md`) | **No** — jumps from Stage 0 (`:208`) straight to "Write Final Metadata" (`:236`); the only report-shaped content in the file is the domain-specific "## Tactic Survey Results" subsection template (`:199`), not a full report skeleton | No | **Worst gap**, symmetric to implementation: confirmed via dispatch's own grep (report-format / `## Findings` / `## Executive Summary` / `**Task**:` — zero hits) and independently re-confirmed here. |
| `lean-implementation-hard-agent.md` | Yes — `@.claude/context/formats/summary-format.md` at `:36` | Yes — "Stage 7: Create Implementation Summary" (`:405-414`) | **No** — the stage is four bullet points ("Phases executed", "Theorems/lemmas proved", "Final verification results", "Sorry inventory (if non-empty)", "Plan deviations (from inline checklist annotations)") with no metadata header, no `**Status**:` vocabulary sentence, and no `##` section headings at all | Incomplete per dispatch item (d): "amend, don't replace" — the domain-specific content list (theorems proved, sorry inventory) is exactly right and should be preserved, but it needs to be wrapped in the full metadata+section skeleton. |
| `lean-research-hard-agent.md` | Yes — `@.claude/context/formats/report-format.md` at `:37` | Yes — "Stage 6: Create Research Report" (`:260-271`) | **No** — the stage lists "Required additional sections (not in base report)": `## Adversarial Self-Verification`, `## Literature Proof Structure` (Tier 1 only), `## Tactic Survey Results`, plus a Tier-1 5-column lemma-mapping-table requirement in `## Findings` — but never defines what "base report" means inline. Since `lean-research-agent.md` (the presumed base) itself has no skeleton, this stage's "additional" framing is presupposing a skeleton that does not exist anywhere in the extension. | Incomplete in the same way as the hard implementation agent, plus a structural dependency on a nonexistent base. The Tier-1/adversarial-verification additions are domain-valuable and must be preserved. |

Both hard agents' Context References already correctly point at the authoritative format docs —
the gap is narrower than the plain agents' (which don't even link the doc), but functionally
still fails the acceptance criterion: an agent handed only the agent file (not required to
independently re-derive the skeleton from a separately-loaded format doc) does not reliably
produce a conforming artifact, which is exactly the failure mode observed on BimodalLogic task
507.

### Formal Extension — sweep result (new finding, item (c))

The dispatch named "the formal extension's research agents" as a candidate to check, without
assuming defectiveness. All four agents in `agent-system/extensions/formal/agents/` were
checked — `formal-research-agent.md`, `logic-research-agent.md`, `math-research-agent.md`,
`physics-research-agent.md` (there is no formal-extension implementation agent; the directory
contains only these four research agents). Unlike lean, **all four already have an inline report
skeleton** (Stage 4 or Stage 5, each with a fenced `# Research Report: Task #{N}` block), so the
"missing template" root cause does not apply here — the templates exist. But every one of the
four skeletons is independently incomplete against `REPORT_METADATA`/`REPORT_SECTIONS`:

```
formal-research-agent.md  (Stage 4, :145-185): MISSING Effort, Dependencies, Sources/Inputs,
                                                 Artifacts, Standards, Decisions section
logic-research-agent.md   (Stage 5, :221-269): MISSING Effort, Dependencies, Sources/Inputs,
                                                 Artifacts, Decisions section
                                                 (Standards happens to appear elsewhere in the
                                                 agent file's Context References line, but not
                                                 inside the skeleton itself, so a produced report
                                                 would still lack it)
math-research-agent.md    (Stage 5, :210-254): MISSING Effort, Dependencies, Sources/Inputs,
                                                 Artifacts, Standards, Decisions section
physics-research-agent.md (Stage 5, :204-248): MISSING Effort, Dependencies, Sources/Inputs,
                                                 Artifacts, Standards, Decisions section
```

Verified mechanically: `grep -qF "**Effort**"` etc. against each skeleton's containing file, and
`grep -qE "^##+ Decisions"` for the section. `logic-research-agent.md`'s file-wide `**Standards**:`
hit is a red herring — it comes from that agent's own Context References bullet line (`:89`,
inside the agent-authoring text, not the fenced report template), so a report an agent actually
produces from this skeleton would still omit the field. All four skeletons do carry a
`### Recommendations` heading nested under `## Findings`, which the validator's prefix-match
(`^##+ Recommendations`) accepts, so `Recommendations` is the one required section already
satisfied everywhere. `Context & Scope` is present in the three domain agents (logic, math,
physics) but absent from `formal-research-agent.md` itself, which uses `## Domain Analysis`
instead — a different section serving a similar purpose but not satisfying the literal-heading
check.

This is a **distinct defect shape** from the lean gap: skeleton present but incomplete (missing
5 of 8 metadata fields and 1 of 5 sections, consistently across all four files — strongly
suggesting they were copy-pasted from a common ancestor template that itself predates the current
`REPORT_METADATA`/`REPORT_SECTIONS` arrays, or diverged from them over time), rather than
skeleton wholly absent. The recommended fix is the same style of amendment as the lean hard
agents: add the five missing metadata lines and the `## Decisions` section to each of the four
existing fenced skeletons, without disturbing their domain-specific sections (`## Domain
Analysis`, `### Mathlib Theorems`, `### Context File Review`, `## Appendix`, cross-domain
synthesis, etc.).

### Recommendations

1. **`lean-implementation-agent.md`**: insert a new stage (e.g. renumber or insert as "Stage X:
   Create Implementation Summary") before the "Final Verification Stage" heading, carrying the
   full `general-implementation-agent.md:481-529` skeleton verbatim (metadata header incl. the
   bracketed-Status vocabulary sentence, all six `SUMMARY_SECTIONS` headings), adapted only where
   lean-specific content is needed (sorry inventory, theorems proved, build/verification result
   fields — these can live inside `## What Changed` / `## Verification` rather than as new
   top-level sections, keeping the six required headings intact). Also add
   `@.claude/context/formats/summary-format.md` to Context References.
2. **`lean-research-agent.md`**: insert a new stage before "Write Final Metadata" carrying the
   full `general-research-agent.md:277-321` skeleton verbatim, with the existing "## Tactic
   Survey Results" content folded in as a subsection of `## Findings` (or kept as its own
   optional extra section, consistent with `SUMMARY_SECTIONS_OPTIONAL`'s "required minimum, not
   exhaustive whitelist" semantics — the validator never penalizes extra sections). Also add
   `@.claude/context/formats/report-format.md` to Context References.
3. **`lean-implementation-hard-agent.md`** Stage 7: amend in place — wrap the existing four
   content bullets inside the full metadata+section skeleton, keeping the bracketed-Status
   sentence and preserving the hard-specific bullets (sorry inventory, plan deviations from
   inline checklist annotations) inside their natural homes (`## Plan Deviations`, `##
   Verification`/`## What Changed`).
4. **`lean-research-hard-agent.md`** Stage 6: amend in place — since the "base report" it refers
   to will now exist (per recommendation 2 above), either (a) explicitly state "inherits the full
   skeleton from lean-research-agent.md's Stage N" and keep listing only the additional
   sections, or (b) inline the full skeleton again for self-containedness with the additional
   sections appended. Given agents are dispatched with only their own file loaded (no cross-agent
   file reads implied by the dispatch model), (b) is safer for the same reason
   `general-research-agent.md`/`general-implementation-agent.md` inline their own skeletons
   rather than pointing at each other.
5. **Formal extension (new, from the sweep)**: for each of the four files, add the five missing
   `**Field**:` metadata lines and a `## Decisions` section to the existing fenced skeleton,
   without removing or restructuring the domain-specific sections already present. This is a
   smaller, mechanical edit than the lean work (skeleton exists; only add missing lines/section)
   but should be captured in the same plan since it was surfaced by this task's own sweep
   obligation (work item (c)) and is otherwise unowned — no other open task names it.
6. Per the dispatch's acceptance criteria, plan the verification step as an actual end-to-end
   lean-language task dispatch (not a hand-written fixture) whose resulting summary and report
   are run through `validate-artifact.sh <path> summary` / `... report` with zero errors and zero
   `[FIXED]` auto-repairs, and confirm the edits are made in `agent-system/extensions/lean/` /
   `agent-system/extensions/formal/` (the source store) and survive a redeploy — `.claude/` is a
   disposable deploy artifact per `.claude/rules/source-store-deploy-boundary.md`.

## Decisions

- Transcribed `REPORT_METADATA`/`REPORT_SECTIONS`/`SUMMARY_METADATA`/`SUMMARY_SECTIONS` directly
  from `validate-artifact.sh:19-44` rather than from the dispatch description, per the dispatch's
  explicit instruction; confirmed they match `report-format.md`/`summary-format.md`'s own
  "Example Skeleton" sections.
- Treated the formal-extension incompleteness found during the item-(c) sweep as in-scope for
  this task rather than a separate task: the dispatch explicitly asked the sweep to "report what
  was checked and what was found, including negatives," and named "the formal extension's
  research agents" as a candidate; a real, evidenced defect there is exactly the kind of finding
  that instruction was designed to surface, not a scope-creep item to defer.
- Did not treat `lean-implementation-hard-agent.md` / `lean-research-hard-agent.md`'s existing
  (incomplete) stages as needing replacement — per work item (d), the plan should amend them, and
  their lean/hard-specific content (sorry inventory, plan-deviation annotations, adversarial
  verification, Tier-1 lemma table) is valuable and must survive the amendment.
- Did not evaluate or propose changes to `validate-artifact.sh` itself — this is an explicit
  non-goal, and task 136 owns tightening that script separately.

## Risks & Mitigations

- **Risk**: hand-editing four formal-agent skeletons plus two lean skeletons plus two lean-hard
  stages in one implementation pass risks drifting them out of sync with each other or with the
  `general-*` reference skeletons over time. **Mitigation**: the plan should note the copy source
  (`general-implementation-agent.md:481-529` / `general-research-agent.md:277-321`) explicitly in
  each edited file as a comment or cross-reference, matching the existing convention already used
  elsewhere in this codebase for shared templates (e.g. `return-meta-artifacts-template.md`
  cross-references in the lean hard agents).
- **Risk**: the acceptance criterion requires demonstrating the fix "on a real dispatch," which
  means the plan must include an actual `/orchestrate` (or `/research`+`/plan`+`/implement`) run
  against a lean-type task after the agent-file edits land — this has cost and requires a
  suitable lean task to exist or be created. **Mitigation**: the plan should either reuse an
  existing pending lean task or explicitly account for creating a minimal throwaway one for
  verification purposes.
- **Risk**: editing `.claude/agents/*.md` directly instead of the source store would be silently
  wiped on next regeneration (per `source-store-deploy-boundary.md`). **Mitigation**: this report
  and the resulting plan name `agent-system/extensions/{lean,formal}/agents/*.md` as the only
  correct edit targets throughout; the acceptance criterion's "confirm the fix survives
  regeneration" step directly guards against this.
- **Risk**: none of task 136's (separate) validator-tightening work was inspected here beyond
  confirming it's out of scope; if 136 lands first and changes required-field/-section arrays,
  the skeletons proposed here could go stale before this task's plan is executed. **Mitigation**:
  flag this as a sequencing note for the planner — re-check `validate-artifact.sh:19-44` for
  drift immediately before implementing, not just during this research pass.

## Context Extension Recommendations

- **Topic**: agent-file artifact skeletons as a documented pattern.
- **Gap**: there is no context file stating "every terminus-writing agent must inline a full,
  validator-matching skeleton in its own file rather than only linking the format doc" as a
  general principle — it exists only implicitly, as a pattern followed by `general-*` agents and
  violated by the lean/formal agents examined here.
- **Recommendation**: consider adding a short guideline to
  `.claude/docs/guides/creating-extensions.md` (or wherever extension-agent authoring conventions
  live) stating this inline-skeleton requirement, so future extensions don't reproduce the same
  gap. Not proposed as part of this task's own plan (which is scoped to fixing the existing lean
  and formal agents), but worth a follow-up meta task.

## Appendix

- Search queries / commands used: `grep -n` sweeps of `agent-system/extensions/{core,lean,formal}/agents/*.md`
  for stage headings, format-doc references, and required-field/-section literals; `sed -n`
  line-range reads of `validate-artifact.sh:1-180`, `general-implementation-agent.md:465-539`,
  `general-research-agent.md` (full file), `lean-implementation-agent.md` (full file, particular
  focus on :120-284, :340-373), `lean-implementation-hard-agent.md:400-443`,
  `lean-research-agent.md:205-320`, `lean-research-hard-agent.md:255-320`,
  `formal-research-agent.md:140-215` (full skeleton + metadata stage), `logic-research-agent.md:221-270`;
  mechanical per-field `grep -qF`/`grep -qE` checks against all four formal-domain agent files.
- References: `agent-system/extensions/core/scripts/validate-artifact.sh`,
  `agent-system/extensions/core/context/formats/report-format.md`,
  `agent-system/extensions/core/context/formats/summary-format.md`,
  `agent-system/extensions/core/agents/general-implementation-agent.md`,
  `agent-system/extensions/core/agents/general-research-agent.md`,
  `agent-system/extensions/lean/agents/lean-implementation-agent.md`,
  `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md`,
  `agent-system/extensions/lean/agents/lean-research-agent.md`,
  `agent-system/extensions/lean/agents/lean-research-hard-agent.md`,
  `agent-system/extensions/formal/agents/{formal,logic,math,physics}-research-agent.md`.
