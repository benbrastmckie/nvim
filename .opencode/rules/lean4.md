---
paths: "**/*.lean"
---

# Lean 4 Development Rules

## CRITICAL: Blocked MCP Tools

**DO NOT call**: `lean_diagnostic_messages` (hangs), `lean_file_outline` (unreliable)

Use `lean_goal` + `lake build` instead.

## Essential MCP Tools

| Tool | Purpose |
|------|---------|
| `lean_goal` | Proof state at position - MOST IMPORTANT |
| `lean_hover_info` | Type signatures + docs |
| `lean_completions` | IDE autocomplete |
| `lean_local_search` | Fast local declaration search |

## Search Tools (Rate Limited)

| Tool | Rate | Query Style |
|------|------|-------------|
| `lean_leansearch` | 3/30s | Natural language |
| `lean_loogle` | 3/30s | Type pattern |
| `lean_leanfinder` | 10/30s | Semantic concept |
| `lean_state_search` | 3/30s | Goal -> closing lemmas |
| `lean_hammer_premise` | 3/30s | Goal -> simp/aesop hints |

## Search Decision Tree

1. "Does X exist locally?" -> `lean_local_search`
2. "Lemma that says X" -> `lean_leansearch`
3. "Type pattern match" -> `lean_loogle`
4. "Lean name for concept" -> `lean_leanfinder`
5. "What closes this goal?" -> `lean_state_search`

## Workflow Pattern

1. After finding name: `lean_local_search` -> verify, `lean_hover_info` -> signature
2. During proof: `lean_goal` constantly, `lean_multi_attempt` test tactics, `lake build`
3. After editing: `lake build`, `lean_goal`

## Common Tactics

Automation: `simp`, `aesop`, `omega`, `ring`, `decide`
Structure: `intro`, `apply`, `exact`, `constructor`, `cases`, `induction`
Rewriting: `rw`, `simp only`, `conv`

## Build Commands

`lake build` | `lake build Module.Name` | `lake clean && lake build`
