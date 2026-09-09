# MCP Tools Guide for Lean 4 Development

## Overview

This guide describes the lean-lsp-mcp tools available for Lean 4 development in Claude Code. These tools are accessed directly via MCP (Model Context Protocol) with the `mcp__lean-lsp__*` prefix.

The `lean-lsp` MCP server provides four capability groups:

| Capability | Tools |
|------------|-------|
| Goal state inspection | `lean_goal`, `lean_minimal_hypotheses`, `lean_term_goal` |
| Proof search | `lean_state_search`, `lean_hammer_premise`, `lean_multi_attempt` |
| Mathlib lookup | `lean_loogle`, `lean_leansearch`, `lean_leanfinder`, `lean_local_search` |
| Code actions and diagnostics | `lean_code_actions`, `lean_hover_info`, `lean_build`, `lean_verify` |

### CRITICAL: Blocked Tools - DO NOT USE

**NEVER call these tools directly.** They have known bugs that cause incorrect behavior.

| Tool | Bug | Alternative |
|------|-----|-------------|
| `lean_diagnostic_messages` | lean-lsp-mcp #118 | `lean_goal` or `lake build` |
| `lean_file_outline` | lean-lsp-mcp #115 | `Read` + `lean_hover_info` |

## Configuration

The server is registered in user-scope `~/.claude.json` (never in a project-scoped `.mcp.json` or
in any settings file) by `lean/scripts/setup-lean-mcp.sh`, which writes an entry shaped like this:

```json
{
  "mcpServers": {
    "lean-lsp": {
      "type": "stdio",
      "command": "uvx",
      "args": ["lean-lsp-mcp"],
      "env": {
        "LEAN_LOG_LEVEL": "WARNING",
        "LEAN_PROJECT_PATH": "/path/to/project"
      }
    }
  }
}
```

No wrapper script is involved: `command` is `uvx` (a package runner resolved on `PATH`), and the
only per-project value is carried by the `LEAN_PROJECT_PATH` environment variable. See
[MCP Server Ownership](../../../../../core/context/patterns/mcp-server-ownership.md)'s recorded
invariant — a server's `command` must never resolve inside any repository's own `.claude/`
deploy tree.

User scope is required rather than project-scoped `.mcp.json` because project-scoped servers
require an interactive approval prompt that a subagent cannot satisfy. Tool permissions are
granted separately, by a `mcp__lean-lsp__*` wildcard in this extension's own
`settings-fragment.json`. See
[MCP Server Ownership](../../../../../core/context/patterns/mcp-server-ownership.md) for the
full registration/permission split.

## Available Tools

### Core Tools (No Rate Limit)

#### lean_goal
**Purpose**: Get proof state at a position. MOST IMPORTANT tool.

**Usage**:
- Omit `column` to see `goals_before` (line start) and `goals_after` (line end)
- Shows how the tactic transforms the state
- "no goals" = proof complete

```
Parameters:
- file_path: Absolute path to Lean file
- line: Line number (1-indexed)
- column: Column (1-indexed, optional)
```

#### lean_hover_info
**Purpose**: Get type signature and documentation for a symbol.

#### lean_completions
**Purpose**: Get IDE autocompletions.

#### lean_multi_attempt
**Purpose**: Try multiple tactics without modifying file.

#### lean_local_search
**Purpose**: Fast local search to verify declarations exist.

#### lean_minimal_hypotheses
**Purpose**: Return only the hypotheses relevant to the goal at a position, instead of the
full local context returned by a raw `lean_goal` call.

**When to prefer over `lean_goal`**: whenever the full local hypothesis list is not needed —
e.g., deciding the next tactic, summarizing state in the transcript, or checking a single
hypothesis' shape. Prefer this over `lean_goal`'s local-context dump for hypothesis pruning.

**Role in hypothesis pruning**: this is the primary tool for the hypothesis-pruning clause
of `@.claude/extensions/lean/context/contracts/context-hygiene.md` — carry forward only
hypotheses the planned tactic references, not the full local context.

```
Parameters:
- file_path: Absolute path to Lean file
- line: Line number (1-indexed)
- column: Column (1-indexed, optional)
```

#### lean_build
**Purpose**: Build the Lean project and restart LSP.

### Search Tools (Rate Limited)

| Tool | Rate | Purpose |
|------|------|---------|
| `lean_leansearch` | 3/30s | Natural language search |
| `lean_loogle` | 3/30s | Type pattern search |
| `lean_leanfinder` | 10/30s | Semantic search |
| `lean_state_search` | 3/30s | Goal -> closing lemmas |
| `lean_hammer_premise` | 3/30s | Goal -> simp/aesop hints |

## Search Decision Tree

```
1. "Does X exist locally?" -> lean_local_search
2. "I need a lemma that says X" -> lean_leansearch
3. "Find lemma with type pattern" -> lean_loogle
4. "What's the Lean name for concept X?" -> lean_leanfinder
5. "What closes this goal?" -> lean_state_search
6. "What to feed simp?" -> lean_hammer_premise
```

After finding a name:
1. `lean_local_search` to verify it exists
2. `lean_hover_info` for full signature

## Proof Development Workflow

### Implementation Pattern

```
1. Write initial code structure
2. Check lean_goal for proof state
3. Apply tactics
4. Check lean_goal to confirm progress
5. Iterate until "no goals"
6. Verify with lake build
```

### Common Effective Tactics

- `simp [lemma1, lemma2]`
- `ring`, `omega` (arithmetic)
- `aesop` (automated reasoning)
- `exact h`, `apply lemma`
- `constructor`, `cases`, `induction`

## Rate Limit Management

### Best Practices
1. Use `lean_local_search` first (no limit)
2. Batch searches when possible
3. Cache found theorem names for reuse
4. Use lean_leanfinder for more queries (higher limit)
