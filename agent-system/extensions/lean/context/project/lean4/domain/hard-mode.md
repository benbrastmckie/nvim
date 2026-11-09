# Lean Hard Mode

Activate with the `--hard` flag on `/orchestrate --research`, `--plan`, or `--implement` for lean4 tasks.
Hard mode is per-invocation only — there is no sticky state.

## When to Use `--hard` for lean4

1. Research previously returned "Mathlib likely has this" without finding the lemma
2. Implementation dispatches produced analysis-heavy output without proof progress
3. Task involves faithful transcription from a paper or proof sketch
4. Three or more dispatches without completing a phase

## Routing (hard mode)

| Language | --hard Research | --hard Implement | --hard Plan |
|----------|-----------------|------------------|-------------|
| `lean4` | `skill-lean-research-hard` | `skill-lean-implementation-hard` | `planner-agent` (standard, direct dispatch; see note below) |

## Skill-Agent Mapping (hard mode)

| Skill | Agent | Model | Purpose |
|-------|-------|-------|---------|
| skill-lean-research-hard | lean-research-hard-agent | opus | H2+H3+H4+H5 hard-mode Lean research |
| skill-lean-implementation-hard | lean-implementation-hard-agent | opus | H2+H9 hard-mode Lean implementation |

**Note**: `/orchestrate --plan --hard` for lean4 tasks falls back to the standard `planner-agent` (direct
dispatch) — core's own standalone hard-mode planner is deleted, and no lean4-specific hard-mode
planner has ever existed to fall back to instead. No lean4-specific planner hard agent is needed
— the standard planner already handles lean4 phase sizing, hard mode or not.

## Behavioral Contracts Added by Hard Mode

- **H2 (lean4)**: Formal proof line bar — first sorry-free lemma within 30% of tool calls
- **H3 (lean4)**: 5-column lemma mapping table for literature-backed tasks
- **H4**: Adversarial self-verification pass in every research dispatch
- **H5**: Divergence audit mode (triggered by "divergence" or "audit" in focus_prompt)
- **H9**: Sorry inventory tracking in every implementation dispatch end

## Contract Override Files

Loaded automatically for hard agents:

- `.claude/extensions/lean/context/contracts/anti-analysis.md` — H2 lean4 override
- `.claude/extensions/lean/context/contracts/reference-grounding.md` — H3 lean4 override
- `.claude/extensions/lean/context/contracts/adversarial-verification.md` — H4 lean4 parity
- `.claude/extensions/lean/context/contracts/context-hygiene.md` — context discipline clauses

## Related Documentation

- [Lean Research Flow](../agents/lean-research-flow.md) — standard-mode research execution flow
- [Lean Implementation Flow](../agents/lean-implementation-flow.md) — standard-mode implementation flow
- [Proof Debt Policy](../standards/proof-debt-policy.md) — sorry and axiom policy backing H9
- [Literature Fidelity Policy](../standards/literature-fidelity-policy.md) — source-following rules backing H3
