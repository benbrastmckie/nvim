# Lean Hard Mode

Activate with the `--hard` flag on `/orchestrate --research`, `--plan`, or `--implement` for lean4 tasks.
Hard mode is per-invocation only — there is no sticky state.

## When to Use `--hard` for lean4

1. Research previously returned "Mathlib likely has this" without finding the lemma
2. Implementation dispatches produced analysis-heavy output without proof progress
3. Task involves faithful transcription from a paper or proof sketch
4. Three or more dispatches without completing a phase

## Routing (hard mode)

`--hard` dispatches the SAME standard agents as standard mode — there is no separate
`-hard`-suffixed skill or agent any more:

| Language | --hard Research | --hard Implement | --hard Plan |
|----------|-----------------|------------------|-------------|
| `lean4` | `skill-lean-research` / `lean-research-agent` | `skill-lean-implementation` / `lean-implementation-agent` | `planner-agent` (standard, direct dispatch; see note below) |

The behavioral difference between standard and hard mode is provided entirely by
manifest.json's `hard_contracts.lean4` block, which injects the contracts below into the
dispatch prompt as a `<hard-mode-contracts>` list — see
`context/guides/manifest-routing-schema.md`'s "The `hard_contracts` Block" section for the
mechanism and "Override Contract Placement Convention" subsection for the domain-prefixed
basename convention these override files follow.

**Note**: `/orchestrate --plan --hard` for lean4 tasks falls back to the standard `planner-agent` (direct
dispatch) — core's own standalone hard-mode planner is deleted, and no lean4-specific hard-mode
planner has ever existed to fall back to instead. No lean4-specific planner hard agent is needed
— the standard planner already handles lean4 phase sizing, hard mode or not.

## Behavioral Contracts Added by Hard Mode

- **H2 (lean4)**: Formal proof line bar — first sorry-free lemma within 30% of tool calls
  (`lean4-anti-analysis.md`, `replace:`s core's generic `anti-analysis.md`)
- **H3 (lean4)**: 5-column lemma mapping table for literature-backed tasks
  (`lean4-reference-grounding.md`, `replace:`s core's generic `reference-grounding.md`)
- **H4**: Adversarial self-verification pass in every research dispatch
  (`lean4-adversarial-verification.md`, `replace:`s core's generic `adversarial-verification.md`)
- **H9**: Sorry inventory tracking, the Zero-Debt policy, and single-phase-focus
  (`lean4-sorry-discipline.md`, additive — no core counterpart)
- **Goal-state context hygiene**: targeted `lean_goal` queries, bounded file reads, hypothesis
  pruning (`lean4-context-hygiene.md`, additive — no core counterpart; also reused by cslib's
  `--hard` dispatches as a deliberate cross-extension dependency)

(H5 divergence-audit mode and the standalone 5-column-mapping research elaboration previously
attributed to a separate `lean-research-hard-agent` body are covered by core's generic H3/H5
contracts plus the lean4 H3 override above; no lean4-specific H5 override exists.)

## Contract Override Files

Resolved per domain via `hard_contracts.lean4` (manifest.json), never loaded unconditionally at
agent spawn (`on_demand: true`, empty `load_when.agents` in `index-entries.json` — the
`hard_contracts` dispatch block is the sole loader):

- `context/contracts/lean4-anti-analysis.md` — H2 lean4 override
- `context/contracts/lean4-reference-grounding.md` — H3 lean4 override
- `context/contracts/lean4-adversarial-verification.md` — H4 lean4 parity
- `context/contracts/lean4-context-hygiene.md` — context discipline clauses (additive)
- `context/contracts/lean4-sorry-discipline.md` — sorry-inventory lifecycle, Zero-Debt policy,
  single-phase-focus (additive)

All five deploy to the shared `context/contracts/` directory via lean's own
`provides.context: ["contracts"]` declaration, under domain-prefixed basenames so they never
collide with core's own generic files at the same shared path.

## Related Documentation

- [Lean Research Flow](../agents/lean-research-flow.md) — standard-mode research execution flow
- [Lean Implementation Flow](../agents/lean-implementation-flow.md) — standard-mode implementation flow
- [Proof Debt Policy](../standards/proof-debt-policy.md) — sorry and axiom policy backing H9
- [Literature Fidelity Policy](../standards/literature-fidelity-policy.md) — source-following rules backing H3
