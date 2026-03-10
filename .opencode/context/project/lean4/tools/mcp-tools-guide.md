# MCP Tools Guide for Lean 4 Development

## Overview

This guide describes the lean-lsp-mcp tools available for Lean 4 development in Claude Code. These tools are accessed directly via MCP (Model Context Protocol) with the `mcp__lean-lsp__*` prefix.

### CRITICAL: Blocked Tools - DO NOT USE

**NEVER call these tools directly.** They have known bugs that cause incorrect behavior.

| Tool | Bug | Alternative |
|------|-----|-------------|
| `lean_diagnostic_messages` | lean-lsp-mcp #118 | `lean_goal` or `lake build` |
| `lean_file_outline` | lean-lsp-mcp #115 | `Read` + `lean_hover_info` |

## Configuration

The MCP server is configured in `.mcp.json`:

```json
{
  "mcpServers": {
    "lean-lsp": {
      "type": "stdio",
      "command": "uvx",
      "args": ["lean-lsp-mcp"],
      "env": {
        "LEAN_PROJECT_PATH": "/path/to/project"
      }
    }
  }
}
```

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
