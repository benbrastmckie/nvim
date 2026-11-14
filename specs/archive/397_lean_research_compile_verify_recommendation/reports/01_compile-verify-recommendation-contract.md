# Research Report: Task #397

**Task**: 397 - lean research compile-verify recommendation contract
**Started**: 2026-11-11T21:00:00Z
**Completed**: 2026-11-11T21:12:00Z
**Effort**: small (prose-only contract addition, no tool-grant or script changes)
**Dependencies**: None
**Sources/Inputs**:
- `agent-system/extensions/lean/agents/lean-research-agent.md` (407 lines)
- `agent-system/extensions/lean/context/project/lean4/agents/lean-research-flow.md` (186 lines)
- `agent-system/extensions/lean/context/contracts/lean4-reference-grounding.md` (H3 override)
- `agent-system/extensions/lean/context/contracts/lean4-adversarial-verification.md` (H4 parity copy)
- `agent-system/extensions/lean/manifest.json` (`hard_contracts.lean4` block)
- `agent-system/extensions/lean/index-entries.json` (line_count entry for the flow file)
- `agent-system/extensions/core/context/guides/hard-mode-routing.md`
- `agent-system/extensions/cslib/agents/cslib-research-agent.md` (cross-domain "Reuse Check
  Protocol" structural precedent — read only, out of file scope)
- `.claude/context/formats/report-format.md`
**Artifacts**: - `specs/397_lean_research_compile_verify_recommendation/reports/01_compile-verify-recommendation-contract.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary
- Adopt trigger **(a)** from the dispatch's three candidates: a recommendation must be
  compile-verified before being written up only when it (i) names a concrete artifact to be
  added/landed AND (ii) an existing compiled gate, predicate, `#eval`, or decision procedure
  already determines whether that artifact is accepted. (b) and (c) are rejected below.
- The gate belongs in the **always-on** contract (`lean-research-agent.md`'s "Research
  Constraints for Lean Tasks" section), not a hard-mode-only file — both because the cited
  failure was COSTLY (per the dispatch's own weighing instruction) and because the structural
  premise of a hard-mode-only placement does not hold: see the factual correction below.
- **Factual correction to the dispatch's own file scope**: `agents/lean-research-hard-agent.md`
  does not exist anywhere in the deployed or source-store tree. Lean's `--hard` dispatches
  resolve the *same* `lean-research-agent.md` body as standard mode; hard-mode-specific duties
  are injected as separate contract files (`lean4-reference-grounding.md`,
  `lean4-adversarial-verification.md`) via the manifest's `hard_contracts.lean4` block, not via a
  second agent file. This is corroborated independently by three sources (manifest, hard-mode
  routing guide, filesystem absence) — see Findings. The file scope must drop this filename.
- The report-template precedent to extend is real and verified: `lean-research-agent.md`'s own
  Stage 1 report skeleton already carries `## Tactic Survey Results` with a `Result` column
  (pass/fail), but `lean-research-flow.md`'s parallel Stage 5 template has no such section at
  all — the two files have already drifted on exactly this kind of evidence-shape extension,
  which is itself evidence for editing both files together rather than the agent file alone.
- Recommended mechanism: extend the existing `### Recommendations` bullet format with a
  per-recommendation evidence tag (`[VERIFIED: PASS/FAIL — method]` or
  `[No compiled gate applicable]`), not a new standalone table — the Tactic Survey Results
  table's one-row-per-(goal,tactic) shape doesn't fit a one-row-per-recommendation attestation.

## Context & Scope
Scope is the always-on-vs-hard-mode placement and the exact trigger wording for a new research
contract clause: a recommended artifact whose acceptance an existing compiled predicate decides
must be compile-verified before the recommendation is written, with the negative case requiring
a revised recommendation (not silence). File scope per the dispatch: `lean-research-agent.md`,
`lean-research-flow.md`, `index-entries.json`, and (conditionally) `lean-research-hard-agent.md`.
Out of scope (per dispatch): Zero-Debt Policy content, Literature Extraction Protocol, Tactic
Discovery Survey Protocol (beyond reusing its evidence shape), the agent's tool grant, and all
implementation-side files (sibling record's territory).

## Findings

### Codebase Patterns

- **The structural precedent cited by the dispatch is real.** `lean-research-agent.md:105-119`
  carries "### Zero-Debt Policy Compliance" with explicit **FORBIDDEN Recommendations** (4 items)
  and **REQUIRED Approach** (4 items) lists, including item 3: "If no sorry-free approach is
  found: Document this clearly and recommend marking task [BLOCKED] for user review." This is
  the exact shape — a contract with teeth, plus a non-silent failure path — that the new clause
  should mirror.
- **The tool grant already suffices**, confirming the dispatch's point (3). `lean-research-agent.md`'s
  "### Build Tools" (line ~58) grants detached `lake build`; "### Lean MCP Tools" grants
  `lean_run_code`, `lean_multi_attempt`, `lean_build`, etc. No tool-grant change is needed to
  add a compile-check obligation.
- **The evidence-shape precedent is real but file-local, not shared.** `lean-research-agent.md`'s
  Stage 1 report skeleton (lines 234-291) includes `## Tactic Survey Results` with columns `Goal
  | Tactic | Result | Premises/Config` and `Result` values of `success`/`fail` — i.e. "a
  recommendation backed by a measured result recorded in the report" is an established shape.
  **However**, `lean-research-flow.md`'s own Stage 5 report template (lines 85-118) has no
  Tactic Survey Results section at all, and no evidence-bearing section beyond a bare
  `## Recommendations` / `1. {Prioritized recommendations}`. The two files have already drifted
  on this exact axis. This directly answers the dispatch's "WHETHER lean-research-flow.md IS THE
  PRIMARY EDIT TARGET" question: it is not that one file is primary and the other derivative —
  both files currently carry independent copies of the report skeleton, and they have already
  diverged once on the same kind of change this task is making. Editing only the agent file
  would be the second time this divergence happens on the same clause type.
- **`lean-research-flow.md` is loaded for the same agent/task_type as the agent file itself.**
  `index-entries.json`'s entry for `project/lean4/agents/lean-research-flow.md` declares
  `"load_when": {"agents": ["lean-research-agent"], "task_types": ["lean4"]}` and
  `"line_count": 186` (verified current: `wc -l` on the live file also returns 186). Any edit to
  this file's line count must be reflected here or the index entry goes stale — this is the
  exact hazard the dispatch's FILE SCOPE note flags.

### Factual Correction: No `lean-research-hard-agent.md` Exists

The dispatch's "ALSO TO DECIDE" and "FILE SCOPE" sections both reference
`agents/lean-research-hard-agent.md` as a real file whose contents might need reconciling with
an always-on clause. This does not hold, confirmed independently three ways:

1. **Filesystem**: `find . -iname "*lean-research-hard*"` returns nothing under
   `agent-system/` or the deployed `.claude/` tree. The only hits anywhere in the repository are
   inside an *archived* task directory (`specs/vault/01-vault/archive/675_lean4_extension_hard_mode_variants/`),
   i.e. a past research/plan/summary record about hard-mode variants — not a live agent file.
2. **Manifest**: `agent-system/extensions/lean/manifest.json` declares `routing_agents.lean4 =
   "lean-research-agent"` for both operations (no separate hard-mode row), and a
   `hard_contracts.lean4` array of **contract file names**
   (`replace:anti-analysis.md:lean4-anti-analysis.md`,
   `replace:reference-grounding.md:lean4-reference-grounding.md`,
   `replace:adversarial-verification.md:lean4-adversarial-verification.md`,
   `lean4-context-hygiene.md`, `lean4-sorry-discipline.md`) — a contract-injection list, not an
   agent-name list.
3. **Architecture doc**: `agent-system/extensions/core/context/guides/hard-mode-routing.md`
   states explicitly: "`routing_agents_hard` — the former agent-level ladder this document used
   to describe in full — is retired... There is no `-hard`-suffixed agent name anywhere in the
   source store any more." It further states CLAUDE.md's own "Hard Mode" section already
   documents this ("`--hard` dispatches the SAME agent as standard mode").

**Conclusion**: `--hard` for `task_type: lean4` dispatches the identical `lean-research-agent.md`
body as standard mode. The only hard-mode-specific *content* lives in
`lean4-reference-grounding.md` (H3 override) and `lean4-adversarial-verification.md` (H4 parity
copy), which are additive/replacing contract files injected into the same dispatch prompt — never
a second agent body to keep "mutually consistent" with the first. This means the dispatch's
"WHETHER THE GATE IS ALWAYS-ON OR HARD-MODE-ONLY" question has only two real placement options:
(i) always-on, in `lean-research-agent.md` itself (and `lean-research-flow.md` for consistency),
or (ii) hard-mode-only, added to `lean4-reference-grounding.md` and/or
`lean4-adversarial-verification.md`. There is no third option of "a hard-agent file" to narrow
out of file scope at plan time — it should be dropped from file scope now, as a correction, not
deferred as a live option.

### External Resources

- `lean4-reference-grounding.md`'s "Sorry-Inventory Cross-Reference" section already establishes
  a `Status` column with values `transcribed | pending | sorry | blocked` that must stay
  synchronized with a downstream artifact (the implementation agent's `sorry_inventory`). This is
  a second, independent precedent (alongside Tactic Survey Results) for "a status value recorded
  in the report that a downstream phase consumes mechanically" — reinforcing that extending an
  existing report-table/field convention, rather than inventing a new mechanism, is the
  established pattern in this file family.
- `lean4-adversarial-verification.md`'s "Claim Verification Bar" (4 required elements: claim
  stated verbatim, concrete source or tested counterexample, verification method named,
  confidence tag) is the closest existing *general* evidentiary bar, but it is scoped to claims
  about Mathlib/literature facts, not to "will this concrete artifact be accepted by an existing
  compiled gate" — a materially different question (a prediction about a decision procedure's
  output on a not-yet-landed artifact, not a claim about an already-established fact). The new
  clause is a sibling bar, not a restatement of this one, and should not be merged into it.
- `cslib-agents/cslib-research-agent.md`'s "Reuse Check Protocol... before recommending any new
  definitions" (out of file scope, read for cross-domain comparison only) confirms the general
  shape — "run a check before recommending X" stated as a MUST DO item — is already used
  elsewhere in this agent family for a different mechanical precondition (reuse-search rather
  than compile-verification). No action needed; cited only as corroboration that this kind of
  clause is idiomatic to this agent-file family, not a novel pattern being introduced.

## Decisions

1. **Trigger wording — adopt (a), reject (b) and (c)** (per the dispatch's three candidates):
   - **(a) adopted**: "Recommendation names a concrete artifact to be added/landed AND an
     existing compiled gate, predicate, `#eval`, or decision procedure determines whether it is
     accepted." Both conjuncts are checkable without judgment: "names a concrete artifact" means
     the recommendation gives a specific identifier/definition/theorem-row to add (not a general
     strategy or direction), and "an existing compiled gate... determines whether it is
     accepted" means the researcher has already found — not hypothesized — a Decidable/Bool
     predicate, `#eval`, inventory-row classifier, or lake-build target in the *current* codebase
     that the artifact must pass. This exactly reproduces the cited failure's shape (certA as a
     C36 Tier-2 inventory row, gated by the existing `c36Sliced` predicate).
   - **(b) rejected**: "Any recommendation whose correctness is decidable by a bounded mechanical
     check the agent can already run" is the "ruinous… naive reading" the dispatch itself warns
     against, just restated one level down — nearly any claim about an existing codebase is
     "decidable by a bounded check" (does this lemma exist? does this file build? does this
     tactic close this goal?) if "bounded" is read generously, and the clause gives the agent no
     way to tell generous from abusive without judgment. It fails the dispatch's own bar: "stated
     in terms an agent can apply without judgement calls."
   - **(c) rejected**: "Only the report's PRIMARY recommendation... must carry a mechanical
     result" is orthogonal to the actual defect axis. Primariness and gate-existence are
     independent: a report's primary recommendation may have no compiled gate at all (e.g. "use
     induction instead of case split" — a strategy, not a landable artifact), in which case (c)
     would force a check with nothing to check against; conversely a *secondary* recommendation
     could carry exactly the certA-shaped defect and escape (c) entirely. (c) also does not match
     the cited entry, where the defective recommendation happened to be "recommendation 1" only
     incidentally — nothing in the failure mode depended on primacy.

2. **Placement — always-on, in `lean-research-agent.md`'s "## Research Constraints for Lean
   Tasks" section**, as a new subsection sibling to "### Zero-Debt Policy Compliance" (e.g.
   "### Compile-Verify-Before-Recommend"), mirroring its FORBIDDEN/REQUIRED two-list shape:
   - Rejected: hard-mode-only placement (in `lean4-reference-grounding.md` or
     `lean4-adversarial-verification.md`). Two independent reasons: (i) the dispatch's own
     weighing instruction — "the cited entry records a COSTLY outcome, which argues for
     always-on" — and the cited failure occurred in a standard (non-`--hard`) dispatch, so a
     hard-mode-only gate would not have caught it; (ii) the structural premise for hard-mode-only
     placement (an existing hard-agent file to hold it) does not exist, per the Factual
     Correction above — building the hard-mode-only option from scratch is strictly more work
     than extending the always-on file that is already loaded on every dispatch.
   - This decision does **not** forbid a *stronger* hard-mode overlay later (e.g.
     `lean4-adversarial-verification.md` could require a second independent verification method
     for the same check under `--hard`) — it only settles that the baseline obligation is
     always-on. No such overlay is being added now; it is out of scope per the dispatch's "NOT IN
     SCOPE" list (no change to tool grants or the hard variant's file inventory beyond what's
     needed for consistency, and nothing in NOT IN SCOPE forecloses a future overlay).

3. **File-scope correction**: drop `agent-system/extensions/lean/agents/lean-research-hard-agent.md`
   from the plan's file scope entirely — it does not exist and the always-on decision above makes
   it moot regardless. The plan's actual file scope is: `lean-research-agent.md`,
   `lean-research-flow.md`, `index-entries.json` (line_count update for the flow file, since its
   edit changes its line count from 186).

4. **Failing-check obligation**: mirror Zero-Debt item 3's non-silent-failure shape. On a FAIL
   result: (a) report the compiled result (method + outcome) inline on the recommendation, (b)
   do not suppress or drop the recommendation — replace it with a revised recommendation that
   addresses the gate's actual requirement (as the cited entry's plan phase did: a slab-carrying
   certA variant plus a decision gate), and (c) only if no revised recommendation can be
   constructed, fall back to Zero-Debt item 3's existing pattern: document the finding plainly
   and recommend the task be marked `[BLOCKED]` for review, rather than silently omitting the
   recommendation.

5. **Recording mechanism — extend the `### Recommendations` bullet, not a new table.** The
   Tactic Survey Results precedent is a *survey* shape: many (goal, tactic) pairs surveyed
   broadly, most not load-bearing. The compile-verify obligation is the opposite shape: a small
   number of recommendations, each individually load-bearing, each needing exactly one
   pass/fail/not-applicable tag. Recommended inline format (for the plan phase to finalize
   verbatim wording on):
   ```
   ## Recommendations
   1. {recommendation text} [VERIFIED: PASS — <method, e.g. "#eval c36Sliced on certA via lean_run_code">]
   2. {recommendation text} [VERIFIED: FAIL — <method>; revised to: {revised recommendation}]
   3. {recommendation text} [No compiled gate applicable]
   ```
   This directly satisfies the dispatch's "WHERE THE RESULT IS RECORDED" requirement: a passed
   check, a failed-and-revised check, and a recommendation the trigger does not reach are three
   visually distinct tags on the same line — never indistinguishable by omission. Both
   `lean-research-agent.md`'s Stage 1 skeleton and `lean-research-flow.md`'s Stage 5 skeleton
   need this same tag convention added to their `## Recommendations` / `### Recommendations`
   blocks, per Decision 2's consistency requirement.

## Recommendations

1. Add a "### Compile-Verify-Before-Recommend" subsection to `lean-research-agent.md`'s
   "## Research Constraints for Lean Tasks" (sibling to "### Zero-Debt Policy Compliance"),
   stating trigger (a) verbatim, the FAIL obligation (report + revise, Zero-Debt-item-3 fallback
   to `[BLOCKED]`), and explicitly recording the rejection of triggers (b) and (c) with reasons —
   per Decisions 1 and 4.
2. Apply the same subsection (or a cross-reference to it) to `lean-research-flow.md`, and extend
   both files' `## Recommendations` / `### Recommendations` report-skeleton blocks with the
   `[VERIFIED: PASS/FAIL/No compiled gate applicable]` inline tag convention from Decision 5 —
   do not let the two files drift again on this clause as they already have on Tactic Survey
   Results.
3. Update `index-entries.json`'s `lean-research-flow.md` entry's `line_count` in the same commit
   as the flow-file edit, re-measured via `wc -l`, not carried from this report's `186` figure.
4. Place the new subsection in the always-on file only; do not create or reference
   `lean-research-hard-agent.md` anywhere — correct the plan's file scope per Decision 3.
5. Defer the Context Extension Recommendation (hard-mode.md pointer) to a future task; it is
   genuinely useful but outside this task's declared file scope and not required for this
   clause's correctness.

## Risks & Mitigations

- **Risk**: the trigger's "names a concrete artifact" half is itself a judgment call at the
  margin (e.g., is "add a `slab`-carrying variant of certA" concrete enough?). **Mitigation**:
  state the test operationally at plan time as "the recommendation gives (or implies) a specific
  identifier or a fully-specified definition body that would be added to the codebase or an
  inventory/table row" — the cited case clears this bar easily (a named artifact, `certA`, added
  to a named table, the C36 Tier-2 inventory), and the plan should give one or two additional
  worked examples on each side of the line (e.g. "use induction here" clearly does NOT name an
  artifact) rather than leaving the boundary to prose alone.
- **Risk**: scope creep at implementation time back toward trigger (b) — "while I'm in here, let
  me also require checking X" for a recommendation that doesn't name a landable artifact.
  **Mitigation**: the plan should state the rejected triggers (b) and (c) explicitly in the
  contract text itself (as the Zero-Debt section states its FORBIDDEN list explicitly), not just
  in this report, so a future editor sees the rejection reasoning in place rather than
  re-deriving or silently drifting toward (b).
- **Risk**: `index-entries.json`'s `line_count: 186` for `lean-research-flow.md` goes stale the
  moment the new Recommendations tag convention is added to that file, if the plan or
  implementation phase forgets the companion index update. **Mitigation**: the plan should make
  the `index-entries.json` edit an explicit, separately-verifiable step (re-run `wc -l` after the
  flow-file edit and update the entry in the same commit), not an incidental side effect.

## Context Extension Recommendations
- **Topic**: Lean extension hard-mode file inventory.
- **Gap**: nothing in `agent-system/extensions/lean/`'s own context documents the "no
  `-hard`-suffixed agent file for lean4; hard-mode content lives in the H3/H4 contract overrides"
  fact locally — it currently has to be reconstructed from the core extension's
  `hard-mode-routing.md` plus the manifest, which this research round had to do from scratch.
  Stale references to a nonexistent `lean-research-hard-agent.md` (as seen in this dispatch's own
  provenance text) are therefore easy to keep producing.
- **Recommendation**: add a one-paragraph pointer inside
  `agent-system/extensions/lean/context/project/lean4/domain/hard-mode.md` (already referenced in
  CLAUDE.md's Lean4 Extension section) stating plainly that lean4 `--hard` reuses
  `lean-research-agent.md`/`lean-implementation-agent.md` unchanged and naming the H3/H4 override
  files by path, so a future researcher or planner does not need to re-derive this from the core
  guide. Not acted on in this report (out of this task's declared file scope).

## Appendix
- Search queries / commands used: `find . -iname "*lean-research-hard*"`,
  `grep -n "Zero-Debt Policy Compliance" -A 60 agent-system/extensions/lean/agents/lean-research-agent.md`,
  `wc -l agent-system/extensions/lean/context/project/lean4/agents/lean-research-flow.md`,
  `grep -n "hard_contracts\|lean" agent-system/extensions/lean/manifest.json`,
  `grep -n "lean-research-flow\|lean-research-agent\|lean-research-hard" agent-system/extensions/lean/index-entries.json`.
- Provenance record consulted: `~/Projects/BimodalLogic` task
  `specs/716_sliced_certificate_liveat_nontermination/issues.jsonl` entry
  `iss_1791910769494_DQ3Vjd` (class `research-gap`, severity COSTLY, phase plan, dispatch_seq 7) —
  cited verbatim in the dispatch file, not independently re-read in this session (external repo).
