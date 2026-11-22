# Research Report: Task #463

**Task**: 463 - State that lean_goal's empty goals_after is not evidence a declaration elaborates
**Started**: 2026-11-22T00:00:00Z
**Completed**: 2026-11-22T00:00:00Z
**Effort**: small (context-only change; no scripts/hooks)
**Dependencies**: `lean_tier_vocabulary_to_build_scope_mapping` (confirmed already landed — see Findings)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/lean/` (source store; live file contents, re-verified at research time)
- No web search needed — this is a closed-corpus documentation-consistency question
**Artifacts**:
- `specs/463_lean_goal_empty_goals_trust_surface/reports/01_lean-goal-trust-surface.md` (this report)
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- The exact false claim is a one-line bullet: `agent-system/extensions/lean/context/project/lean4/tools/mcp-tools-guide.md` line 85, `- "no goals" = proof complete`, under the `#### lean_goal` heading (lines 79-92). This is the sharpest root-cause location — sharper than the `goals_before`/`goals_after` bullet the dispatch cited — because it states the false equivalence directly, not just the absence of a caveat.
- Siting decision: **candidate (a)** — state the trust-surface caveat inside `mcp-tools-guide.md`'s `#### lean_goal` section, replacing/extending the line-85 bullet. `metadata-trust-surfaces.md` (candidate b) is thematically a kernel/environment-extension trust document (measured against toolchain v4.31.0 internals: `IO.Ref` registries, `meta`-import gating, `_native.*` axioms) — a different genre from an MCP tool's own output semantics, despite the dispatch's correct observation that it already carries a structurally parallel "empty X is not evidence of Y" sentence (§3/§7, about `meta_imports`). `mcp-tools-guide.md` is where every other `lean_goal`-specific usage note already lives, so a reader who looks up `lean_goal` finds the caveat right there rather than needing a pointer two files away.
- The cheaper-than-full-build check that covers the unknown-constant case is **already named** in the flow document: `lean_verify` on the declaration's fully qualified name, already paired with `lean_goal` at Stage 4B item 5 and in the REPEAT loop (step d). The gap is not a missing tool — it's that nothing explains *why* the pairing is load-bearing rather than optional belt-and-suspenders. Mechanism: Lean's elaborator recovers from a term-elaboration error (e.g. an unknown identifier in a closing `exact`/`apply`) by inserting a synthetic `sorryAx` placeholder rather than leaving the declaration incomplete — this is the same mechanism `context/contracts/lean4-anti-analysis.md:90-91` and `context/project/lean4/standards/proof-debt-policy.md:37` already rely on elsewhere in this corpus (`#print axioms` showing `sorryAx`). `lean_verify`'s "axiom check" (per its consistent description across `README.md:63`, `rules/lean4.md:23`, `agents/lean-implementation-agent.md:89`) surfaces that synthetic axiom even though no literal `sorry` token appears in the source — exactly the detection `lean_goal`'s goal-state-only view cannot provide.
- `lean_diagnostic_messages` is explicitly **not** a candidate: it is globally BLOCKED in this same extension (`mcp-tools-guide.md` lines 20-22, `blocked-mcp-tools.md`, `mcp-fallback-table.md` lines 26/30-39) for an unrelated resource-contention/known-bug reason. Naming it as the "instead" check would silently reintroduce a tool this corpus already forbids calling directly.
- No conflict with the landed `lean_phase_commit_full_build_and_plan_anchor` ruling: the tier table (lines 88-93 of `lean-implementation-flow.md`) already gates phase-end on the full build only, and this task's caveat operates strictly *between* those commit boundaries, at step granularity — it does not touch Stage 4C/4D.
- `index-entries.json` does **not** join scope under siting (a): the planned edit only extends an existing bullet under an existing heading in a file whose indexed `summary` ("Lean LSP MCP server tools reference") remains accurate; `line_count` drift is handled by a separate generator script (`generate-context-line-counts.sh`), not a hand-maintained field this task must touch.

## Context & Scope

Researched whether and where to add a documented trust-surface caveat for `lean_goal`'s empty
`goals_after` output, and what cheaper-than-full-build check should be named as the per-step
replacement/complement, without reopening the already-landed phase-commit-gates-on-full-build
ruling and without touching a deployed `.claude/` tree (all paths below are under the source
store, `agent-system/extensions/lean/`, resolved via `.claude-extensions.json`'s
`extensions.lean.source_dir`).

Scope is deliberately narrow per the dispatch's NON-GOALS: no change to phase-commit gating, no
general `mcp-tools-guide.md` reconciliation against the live MCP tool set, no new
scripts/hooks/linters.

## Findings

### Codebase Patterns

**The false claim's sharpest location** (not previously named in the dispatch's own gap
enumeration, which quoted the `goals_before`/`goals_after` bullet one line above it):

```
agent-system/extensions/lean/context/project/lean4/tools/mcp-tools-guide.md:79-92
#### lean_goal
**Purpose**: Get proof state at a position. MOST IMPORTANT tool.

**Usage**:
- Omit `column` to see `goals_before` (line start) and `goals_after` (line end)
- Shows how the tactic transforms the state
- "no goals" = proof complete          <- line 85, the direct false equivalence
```

**The same claim restated in two surfaces the dispatch's grep did not surface** (its grep was
for an *absence* of a not-evidence caveat, not for *presence* of the claim elsewhere — these are
a different search and a legitimate finding, not a gap in the dispatch):
- `agent-system/extensions/lean/README.md:54` — `` | `lean_goal` | Proof state at a file position ("no goals" = done) | ``
- `agent-system/extensions/lean/agents/lean-implementation-agent.md:753` — `9. Always verify proofs are actually complete ("no goals")`
- `mcp-tools-guide.md:180` itself also restates it in the abstract "Implementation Pattern" block (`5. Iterate until "no goals"`), a pattern already out of scope per NON-GOALS (separate, larger reconciliation work).

These two outside-scope restatements are not this task's edit target (no file_scope was declared
for them), but planning should decide — explicitly, not by default — whether to leave them as
silent potential contradictions of the new canonical statement or add a lightweight pointer to
each. Logged via `issue-record.sh` as a minor documentation finding rather than assumed into
scope.

**Per-step verification already pairs `lean_goal` with `lean_verify`**, confirming the "instead"
check is not missing, only unexplained:
```
agent-system/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md
Stage 4B, item 4 (REPEAT loop), step d (current line ~143):
  "d. After editing, use lean_goal to confirm goal progress; use lean_verify for axiom/sorry check"
Stage 4B, item 5 (current line ~147):
  "5. **Verify step completion** with `lean_goal` (proof state) and `lean_verify` (axiom/sorry
  check); do NOT run `lake build` per-step"
Tier table, `local` row (current line ~91):
  "`lean_goal` plus `lean_verify` per step (already mandated at Stage 4B item 5); ..."
Stage 5 note (current line ~184):
  "Note: Per-step verification uses `lean_goal` + `lean_verify`. Phase-end (Stage 4C) and this
  final stage both require a full `lake build`; neither is a substitute for the other."
```
Line numbers in the dispatch (~L117, ~L151, ~L113) have drifted from current (~L147, ~L184,
~L143) — expected per the dispatch's own "re-derive before editing" note; re-derived here by
direct grep, not assumed.

**`lean_verify`'s description is consistent everywhere it appears** ("Axiom check + source scan;
use fully qualified name"): `README.md:63`, `rules/lean4.md:23,47-48`,
`agents/lean-implementation-agent.md:89,734`. No file in this extension gives `lean_verify` its
own dedicated `####` reference subsection in `mcp-tools-guide.md` (a gap, but one explicitly
covered by the dispatch's "No general reconciliation" NON-GOAL — not this task's problem to fix).

**`lean_diagnostic_messages` is globally blocked**, confirmed in three places:
- `mcp-tools-guide.md:16-22` — "CRITICAL: Blocked Tools - DO NOT USE... known bugs that cause
  incorrect behavior", alternative listed as `lean_goal` or `lake build`.
- `context/project/lean4/tools/blocked-mcp-tools.md:11,16-20`.
- `context/project/lean4/patterns/mcp-fallback-table.md:26,30-39` — explicit "BLOCKED" status,
  "Resource contention issues" as the stated reason.
This rules it out as the dispatch's suggested first candidate for the step-level replacement
check — reusing a globally forbidden tool as the recommended "instead" would be a direct
contradiction the acceptance criteria's own "no contradiction introduced" bar would catch.

**The synthetic-sorry mechanism is already relied on elsewhere in this corpus**, which is why
`lean_verify`'s axiom check is the right named replacement rather than a novel claim invented for
this task:
- `context/contracts/lean4-anti-analysis.md:90-91` — "`#print axioms <decl>` (showing `sorryAx`
  in the axiom list) and/or the `declaration uses 'sorry'` compiler warning" as the way to confirm
  a sorry is real.
- `context/project/lean4/standards/proof-debt-policy.md:37` — "The `^axiom ` grep is a textual
  match on one source form. It does not see `sorryAx`, axioms reached transitively through
  imports, or axioms `native_decide` introduces" — i.e. this corpus already distinguishes a
  textual/source-scan check from an axiom-profile check, which is exactly the two-part
  description ("Axiom check + source scan") `lean_verify` itself carries.
An elaboration error inside a tactic term (unknown identifier, type mismatch) is recovered by
Lean's elaborator via a synthetic `sorryAx`-backed placeholder so that the enclosing top-level
command still completes and the file's later declarations remain elaborable — the same mechanism
that makes an *unsolved-goal* sorry detectable by axiom profile even when no literal `sorry`
token is present. This specific causal claim (synthetic-sorry insertion on a term-elaboration
error) is standard, well-established Lean 4 elaborator behavior but was not independently
re-derived against the live toolchain in this research pass (no Lean build was run) — flagged
below as a one-line sanity check worth running once, cheaply, before or during implementation,
analogous to how `metadata-trust-surfaces.md`'s own claims are each tagged "measured" against a
specific toolchain version.

**Index scope check**: `index-entries.json` entries for the two files in question
(`mcp-tools-guide.md` at line ~305, `lean-implementation-flow.md` at line ~406) carry `summary`
fields ("Lean LSP MCP server tools reference", "Lean implementation agent execution flow")
unaffected by the proposed edits — neither file's topic changes. `line_count` fields exist in
these entries but are regenerated by `agent-system/extensions/core/scripts/generate-context-line-counts.sh`,
not hand-maintained, so a line-count drift from this edit does not itself trigger the
"summary changed" conditional-scope clause. `metadata-trust-surfaces.md`'s own entry (line ~862)
is untouched under siting (a).

### External Resources

Not applicable — this is a closed-corpus internal-consistency task (no web research performed,
per Search Priority: local codebase first, and the question resolves entirely within the local
corpus).

## Recommendations

1. **Site the statement in `mcp-tools-guide.md`**, replacing the line-85 bullet
   (`- "no goals" = proof complete`) with a corrected claim plus the trust-surface caveat and the
   named replacement/complement check, in the `#### lean_goal` section. Suggested shape (planning
   may refine wording, not the substance):
   - Keep "no goals" meaning no goals remain open at that position.
   - State explicitly: this is not evidence the declaration elaborates — an elaboration error
     (e.g. an unknown identifier in a closing term) can still leave `goals_after` empty, because
     Lean's elaborator recovers via a synthetic `sorryAx` placeholder rather than leaving the
     goal open.
   - Name the cheaper-than-full-build check: pair with `lean_verify` on the declaration's fully
     qualified name — its axiom check surfaces the synthetic `sorryAx` even when no literal
     `sorry` appears in the source.
   - Carry the measured incident as the motivating example (CARRIED-UNVERIFIED in this
     repository, per the dispatch's own framing — it originates in a different repository's issue
     log).
2. **Point, do not restate, from `lean-implementation-flow.md`.** Edit Stage 4B item 5's line
   (current ~L147: "**Verify step completion** with `lean_goal` ... and `lean_verify` ...") to
   add a short pointer to `mcp-tools-guide.md`'s `lean_goal` section explaining *why* both tools
   are required at that step, rather than duplicating the explanation. The REPEAT-loop step d
   (~L143) and the Stage 5 note (~L184) already name both tools together and already say
   "neither is a substitute for the other" (Stage 5) — leave those as lighter touches or
   unedited; only the Stage 4B item 5 line is the one the acceptance criteria singles out as "the
   flow document's step-verification line."
3. **Do not touch `metadata-trust-surfaces.md`.** It is a different-genre document (kernel/
   environment-extension internals on a pinned toolchain version); forcing this MCP-tool caveat
   into it would be a thematic mismatch, not a reuse of an existing pattern, despite the
   structural parallel the dispatch correctly noticed.
4. **Flag, do not silently fix, the two outside-scope restatements** (`README.md:54`,
   `agents/lean-implementation-agent.md:753`). Recorded as a minor documentation issue via
   `issue-record.sh` during this research pass; planning should make an explicit in/out-of-scope
   call on these rather than leaving them as an unconsidered gap.
5. **Recommend (not required by acceptance) a one-line empirical sanity check** before or during
   implementation: construct a minimal Lean snippet with a closing `exact` referencing an unknown
   identifier, confirm via `lean_verify` (or `#print axioms`) that the enclosing declaration shows
   a `sorryAx`-family axiom. This converts the mechanism claim above from "standard Lean 4
   behavior, not re-derived here" to a measured fact in this repository's own corpus, matching
   the evidentiary bar `metadata-trust-surfaces.md` sets for its own claims. This is optional
   diligence, not a new script/hook (the NON-GOALS bar on tooling is unaffected — this is a
   one-off manual check, not a persisted check).

## Decisions

- Siting: candidate (a), `mcp-tools-guide.md`'s `#### lean_goal` section — not candidate (b).
- Replacement/complement check to name: `lean_verify` on the fully qualified declaration name —
  not `lean_diagnostic_messages` (ruled out: globally blocked elsewhere in this same extension).
- `index-entries.json` does not join this task's scope under the chosen siting.
- The two outside-scope restatements (`README.md`, `lean-implementation-agent.md`) are left as a
  flagged, explicit planning decision rather than silently absorbed into or excluded from scope.

## Risks & Mitigations

- **Risk**: the synthetic-`sorryAx`-on-elaboration-error mechanism, while standard Lean 4
  behavior and consistent with this corpus's own existing statements about `sorryAx` detection,
  was not independently re-derived against the live toolchain in this research pass.
  **Mitigation**: Recommendation 5 above — a cheap, one-off manual sanity check, not a new
  enforcement mechanism, recommended but not gating the acceptance criteria.
- **Risk**: editing the line-85 bullet touches text one line away from the bullet the dispatch
  itself quoted (`goals_before`/`goals_after`, line 83), raising a small chance of an overlapping
  edit if a sibling task also touches this section. **Mitigation**: no sibling in this cycle's
  territory list declares `mcp-tools-guide.md` in its `file_scope` (checked against the dispatch's
  `concurrent_siblings` territory JSON: tasks 398, 451, 504, 537, 549, 557 — none touch this
  file) — low collision risk, but the standard re-read-before-edit discipline from
  `context/contracts/territory.md` still applies at implementation time.
- **Risk**: a pointer-only edit to the flow document's Stage 4B item 5 line could be read as
  weakening the per-step instruction if worded loosely. **Mitigation**: Recommendation 2 keeps
  the instruction to use both tools unchanged; only the *rationale* moves to the pointer target.

## Context Extension Recommendations

- **Topic**: `lean_verify`'s own MCP semantics.
- **Gap**: `mcp-tools-guide.md` has no dedicated `#### lean_verify` reference subsection (unlike
  `lean_goal`, `lean_hover_info`, `lean_completions`, etc.), even though it is one of four tools
  listed in the "Code actions and diagnostics" capability row and is paired with `lean_goal` at
  every per-step verification point in the flow document.
- **Recommendation**: a future, separate task (already covered by the dispatch's own NON-GOALS as
  "general reconciliation... recorded elsewhere as separate, larger work") should add that
  subsection; this task's pointer can then target the dedicated subsection rather than the
  `lean_goal` section's caveat, but that refinement is not required for this task's acceptance.

## Appendix

- Search queries/greps used: `grep -n "goals_after\|goals_before\|lean_goal"` and
  `grep -n "Verify step completion\|lean_goal\|lean_verify\|per-step\|lake build"` over
  `mcp-tools-guide.md` and `lean-implementation-flow.md`; `grep -rn "lean_verify"` and
  `grep -rn "sorryAx\|synthetic sorry\|error recovery\|elaboration error"` across
  `agent-system/extensions/lean/`; `grep -rn "goals_after\|empty goal\|no goals\b" . --include="*.md"`
  for the enumeration-completeness cross-check of the false-claim's other occurrences;
  `jq`/`grep` against `index-entries.json` and `.claude-extensions.json` for scope and
  source-store resolution.
- References: `agent-system/extensions/lean/context/project/lean4/tools/mcp-tools-guide.md`,
  `agent-system/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md`,
  `agent-system/extensions/lean/context/project/lean4/domain/metadata-trust-surfaces.md`,
  `agent-system/extensions/lean/context/project/lean4/tools/blocked-mcp-tools.md`,
  `agent-system/extensions/lean/context/project/lean4/patterns/mcp-fallback-table.md`,
  `agent-system/extensions/lean/context/contracts/lean4-anti-analysis.md`,
  `agent-system/extensions/lean/context/project/lean4/standards/proof-debt-policy.md`,
  `agent-system/extensions/lean/README.md`, `agent-system/extensions/lean/rules/lean4.md`,
  `agent-system/extensions/lean/agents/lean-implementation-agent.md`,
  `agent-system/extensions/lean/index-entries.json`.
