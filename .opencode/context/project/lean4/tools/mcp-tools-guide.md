# MCP Tools Guide for Lean 4 Development

## Overview

This guide describes the lean-lsp-mcp tools available for Lean 4 development in OpenCode. These tools are accessed directly via MCP (Model Context Protocol) with the `mcp__lean-lsp__*` prefix.

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

**Note**: Ensure `LEAN_PROJECT_PATH` points to the correct project root.

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

#### lean_diagnostic_messages
**Purpose**: Get compiler errors, warnings, and info messages.

**Usage**:
- Check after every edit
- "no goals to be solved" = remove tactics
- Filter by line range or declaration name

```
Parameters:
- file_path: Absolute path to Lean file
- start_line: Filter from line (optional)
- end_line: Filter to line (optional)
- declaration_name: Filter to declaration (optional, slower)
```

#### lean_hover_info
**Purpose**: Get type signature and documentation for a symbol.

**Usage**:
- Column must be at START of identifier
- Essential for understanding APIs

```
Parameters:
- file_path: Absolute path to Lean file
- line: Line number (1-indexed)
- column: Column at START of identifier (1-indexed)
```

#### lean_completions
**Purpose**: Get IDE autocompletions.

**Usage**:
- Use on INCOMPLETE code (after `.` or partial name)

```
Parameters:
- file_path: Absolute path to Lean file
- line: Line number (1-indexed)
- column: Column number (1-indexed)
- max_completions: Max completions (default: 32)
```

#### lean_multi_attempt
**Purpose**: Try multiple tactics without modifying file.

**Usage**:
- Returns goal state for each tactic
- Recommend trying 3+ tactics at once

```
Parameters:
- file_path: Absolute path to Lean file
- line: Line number (1-indexed)
- snippets: Array of tactics to try, e.g., ["simp", "ring", "omega"]
```

#### lean_local_search
**Purpose**: Fast local search to verify declarations exist.

**Usage**:
- Use BEFORE trying a lemma name
- No rate limit, very fast

```
Parameters:
- query: Declaration name or prefix
- limit: Max matches (default: 10)
- project_root: Project root (optional, inferred if omitted)
```

#### lean_file_outline
**Purpose**: Get imports and declarations with type signatures.

**Usage**:
- Token-efficient file skeleton
- Good for understanding file structure

```
Parameters:
- file_path: Absolute path to Lean file
```

#### lean_term_goal
**Purpose**: Get the expected type at a position.

```
Parameters:
- file_path: Absolute path to Lean file
- line: Line number (1-indexed)
- column: Column (optional, defaults to end of line)
```

#### lean_declaration_file
**Purpose**: Get file where a symbol is declared.

**Usage**:
- Symbol must be present in file first
- Use sparingly (large output)

```
Parameters:
- file_path: Absolute path to Lean file
- symbol: Symbol (case sensitive, must be in file)
```

#### lean_run_code
**Purpose**: Run a code snippet and return diagnostics.

**Usage**:
- Must include all imports
- Use rarely

```
Parameters:
- code: Self-contained Lean code with imports
```

#### lean_build
**Purpose**: Build the Lean project and restart LSP.

**Usage**:
- Use only if needed (e.g., new imports)
- SLOW!

```
Parameters:
- lean_project_path: Path to Lean project (optional)
- clean: Run lake clean first (default: false, slow)
- output_lines: Return last N lines of build log (default: 20)
```

### Search Tools (Rate Limited)

#### lean_leansearch (3 req/30s)
**Purpose**: Search Mathlib via leansearch.net using natural language.

**Examples**:
- "sum of two even numbers is even"
- "Cauchy-Schwarz inequality"
- `{f : A → B} (hf : Injective f) : ∃ g, LeftInverse g f`

```
Parameters:
- query: Natural language or Lean term query
- num_results: Max results (default: 5)
```

#### lean_loogle (3 req/30s)
**Purpose**: Search Mathlib by type signature via loogle.lean-lang.org.

**Examples**:
- `Real.sin`
- `"comm"`
- `(?a → ?b) → List ?a → List ?b`
- `_ * (_ ^ _)`
- `|- _ < _ → _ + 1 < _ + 1`

```
Parameters:
- query: Type pattern, constant, or name substring
- num_results: Max results (default: 8)
```

#### lean_leanfinder (10 req/30s)
**Purpose**: Semantic search by mathematical meaning via Lean Finder.

**Examples**:
- "commutativity of addition on natural numbers"
- "I have h : n < m and need n + 1 < m + 1"
- Proof state text

```
Parameters:
- query: Mathematical concept or proof state
- num_results: Max results (default: 5)
```

#### lean_state_search (3 req/30s)
**Purpose**: Find lemmas to close the goal at a position.

**Usage**:
- Searches premise-search.com
- Best for goal-directed search

```
Parameters:
- file_path: Absolute path to Lean file
- line: Line number (1-indexed)
- column: Column number (1-indexed)
- num_results: Max results (default: 5)
```

#### lean_hammer_premise (3 req/30s)
**Purpose**: Get premise suggestions for automation tactics.

**Usage**:
- Returns lemma names to try with `simp only [...]`, `aesop`, or as hints

```
Parameters:
- file_path: Absolute path to Lean file
- line: Line number (1-indexed)
- column: Column number (1-indexed)
- num_results: Max results (default: 32)
```

## Search Decision Tree

```
1. "Does X exist locally?" → lean_local_search
2. "I need a lemma that says X" → lean_leansearch
3. "Find lemma with type pattern" → lean_loogle
4. "What's the Lean name for concept X?" → lean_leanfinder
5. "What closes this goal?" → lean_state_search
6. "What to feed simp?" → lean_hammer_premise
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
4. Check lean_diagnostic_messages for errors
5. Iterate until "no goals"
6. Verify with lake build
```

### Tactic Selection with lean_multi_attempt

Try multiple tactics efficiently:
```
lean_multi_attempt with snippets: ["simp", "ring", "omega", "aesop"]
```

Common effective tactics:
- `simp [lemma1, lemma2]`
- `ring`, `omega` (arithmetic)
- `aesop` (automated reasoning)
- `exact h`, `apply lemma`
- `constructor`, `cases`, `induction`

## Error Handling

### Check isError Field

Tool responses include `isError`:
- `true` = failure (timeout/LSP error)
- `false` with `[]` = no results found (not an error)

### Common Issues

**Proof Stuck**:
1. Use `lean_multi_attempt` with varied tactics
2. Use `lean_state_search` to find closing lemmas
3. Use `lean_hammer_premise` for simp hints
4. Try different proof approach

**Type Mismatch**:
1. Use `lean_hover_info` to check types
2. Add explicit type annotations
3. Look for conversion lemmas

**Missing Import**:
1. Use `lean_local_search` to verify name
2. Add required import
3. Use `lean_build` to rebuild

### Fallback Strategies

If MCP tools unavailable:
- **Core tools** → Use `lake build` for compilation verification
- **Search tools** → Use web search for Mathlib queries

## Rate Limit Management

### Limits by Tool
| Tool | Rate Limit |
|------|------------|
| lean_leansearch | 3 req/30s |
| lean_loogle | 3 req/30s |
| lean_leanfinder | 10 req/30s |
| lean_state_search | 3 req/30s |
| lean_hammer_premise | 3 req/30s |

### Best Practices
1. Use `lean_local_search` first (no limit)
2. Batch searches when possible
3. Cache found theorem names for reuse
4. Use lean_leanfinder for more queries (higher limit)

## Skill Integration

### skill-lean-implementation
Uses core tools for proof development:
- `lean_goal` - Check proof state
- `lean_diagnostic_messages` - Verify compilation
- `lean_hover_info` - Check types
- `lean_completions` - Get completions
- `lean_multi_attempt` - Try tactics
- `lean_local_search` - Verify names
- `lean_state_search` - Find closing lemmas
- `lean_hammer_premise` - Get simp hints

### skill-lean-research
Uses search tools for theorem discovery:
- `lean_leansearch` - Natural language search
- `lean_loogle` - Type pattern search
- `lean_leanfinder` - Semantic search
- `lean_local_search` - Local project search
- `lean_hover_info` - Get signatures
- `lean_state_search` - Goal-directed search
- `lean_hammer_premise` - Premise suggestions

## Quick Reference

### Most Used Tools

| Task | Tool |
|------|------|
| Check proof state | `lean_goal` |
| Check for errors | `lean_diagnostic_messages` |
| Get type info | `lean_hover_info` |
| Try multiple tactics | `lean_multi_attempt` |
| Verify name exists | `lean_local_search` |
| Find theorem (natural language) | `lean_leansearch` |
| Find theorem (type pattern) | `lean_loogle` |
| Find lemma to close goal | `lean_state_search` |

### Tool Invocation Format

In OpenCode, tools are called directly:
```
mcp__lean-lsp__lean_goal
mcp__lean-lsp__lean_diagnostic_messages
mcp__lean-lsp__lean_hover_info
... etc
```

## Version

**Version**: 2.0.0
**Last Updated**: 2026-01-10
**Platform**: OpenCode (migrated from OpenCode)
