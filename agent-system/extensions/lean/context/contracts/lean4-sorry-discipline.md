# Sorry Inventory and Single-Phase-Focus Discipline (H9) — Lean4

This is a NEW standalone contract for the Lean4 formal domain. It does not override a core
baseline file — the hard-only procedural residue it carries (the sorry-inventory lifecycle, the
Zero-Debt policy, and the single-phase-focus rule) has no counterpart in the standard
`lean-implementation-agent.md` body, which tracks neither `sorry_inventory` nor `phase_number`
and carries no Zero-Debt language. This file packages that residue as an injectable contract so a
`--hard` lean4 dispatch retains the behaviour without a dedicated `-hard` agent file.

## Sorry Inventory Lifecycle

**Scope: task-scoped, not phase-scoped.** The sorry inventory tracks ALL sorries across the
entire task, not just the phase a given dispatch is executing. A dispatch that completes one
phase of a multi-phase plan must carry forward every sorry recorded in earlier phases, not only
ones it introduces or resolves itself.

**Initialization**: before executing any phase,
- If resuming from a handoff: import `sorry_inventory` from the previous handoff JSON.
- If starting fresh (no prior handoff): initialize empty `sorry_inventory = []`.

**Per-step update**: after completing each proof step,
- For any newly introduced `sorry`: add an entry with `file`, `line`, `statement`, `strategic`,
  `assumption`, `why_deferred`, `follow_up_task`.
- For any resolved `sorry`: remove its entry from the inventory.
- Leaf sub-sorries are allowed only per the H2 lean4 sub-sorry policy (see
  `@.claude/context/contracts/lean4-anti-analysis.md`); main-target sorries are allowed only as
  tracked strategic sorries meeting the five-condition test in that same file.

**`sorry_inventory` entry schema**:
- `file`: Path to the Lean file containing the sorry.
- `line`: Line number of the sorry.
- `statement`: The full theorem/lemma statement.
- `strategic`: boolean — `true` if the sorry qualifies as strategic under
  `lean4-anti-analysis.md`'s five-condition test; `false` for an ordinary leaf sub-sorry.
- `assumption`: What the sorry is currently assuming (what needs to be proved).
- `why_deferred`: Why this sorry could not be resolved in this dispatch.
- `follow_up_task`: The owning follow-up task number or sub-phase that will discharge it.
  REQUIRED (non-null) when `strategic: true`.

**Leaf sub-sorry vs. main-target sorry**:
- Leaf sub-sorries (inside `have` steps, not top-level): include in `sorry_inventory` with
  prefix notation in `statement`: `"have (leaf): {statement}"`.
- Main-target sorries (top-level theorem body is `by sorry`): when all five core conditions in
  `lean4-anti-analysis.md`'s strategic-sorry test hold, include in `sorry_inventory` with
  `strategic: true` and `follow_up_task` populated (NOT in `blockers`), and `status` may be
  `"implemented"` with `skeleton: true`. When the five-condition test is not met, include in
  `blockers` instead of (or in addition to) `sorry_inventory`, and `status` cannot be
  `"implemented"`.

**Reporting**: write `sorry_inventory` to the progress file at every handoff checkpoint (even
when empty), and include it at the top level of `.orchestrator-handoff.json` at the end of every
dispatch (mirrors the handoff schema's own top-level placement).

## Zero-Debt Policy

**NO sorry in implemented status**, except the two tracked exceptions below. This applies to
both main-target theorems AND any sorry introduced during this dispatch that was not present at
dispatch start.

**Exception 1 — leaf sub-sorries that**:
1. Were pre-existing in `sorry_inventory` from prior dispatches.
2. Are being tracked for a future targeted dispatch.
3. Are documented in `sorry_inventory` with `follow_up_task` populated.

**Exception 2 — strategic main-target sorries that**:
1. Meet ALL five conditions of the strategic-sorry test in
   `@.claude/context/contracts/lean4-anti-analysis.md` (deliberate division boundary, tightly
   scoped, documented, tracked, build-green).
2. Are recorded in `sorry_inventory` with `strategic: true` and a non-null `follow_up_task`.
3. Report `status: "implemented"` with `skeleton: true` — never a bare `"implemented"` with an
   untracked or non-strategic main-target sorry.

**Verification gate**: `sorry_count` (from `lean-sorry-census.sh --cross-check`) must be 0 OR
every remaining sorry is tracked in `sorry_inventory` with `strategic: true` and satisfies the
five-condition strategic-sorry test; otherwise `status` cannot be `"implemented"`.

## Single-Phase Focus

**When `phase_number` is set in delegation context**: implement ONLY that phase. Do NOT continue
to the next phase even if time permits — the orchestrator controls phase sequencing. When the
target phase is complete, STOP and proceed to wrap-up rather than scanning for the next
incomplete phase.

**When `phase_number` is not set**: scan for the first incomplete phase and resume there, as the
standard agent already does.

This rule is phase-agnostic in the sense that it governs HOW a dispatch selects its working
phase, independent of which lifecycle phase (research/plan/implement) is in play — `hard_contracts`
has no `phase` dimension (see `context/guides/manifest-routing-schema.md`'s "Override Contract
Placement Convention" subsection), so this clause reaches every `--hard` lean4 dispatch alike;
`phase_number` itself is an implement-phase-only delegation field and is simply absent (and
therefore inert) on a research or plan dispatch.
