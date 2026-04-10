# Lean Extension

Lean 4 theorem prover support with MCP integration for proof assistance. Provides research and implementation agents for Lean/Mathlib work, wired to the `lean-lsp` MCP server for live goal inspection, proof search, and Mathlib lookup.

## Overview

| Command | Purpose |
|---------|---------|
| `/lake` | Lake build management and error handling |
| `/lean` | Lean-specific proof assistance (research, implementation) |

The extension routes `lean4` task types through dedicated research and implementation agents that have access to the `lean-lsp` MCP server and enforce Lean 4 coding conventions.

## Installation

Loaded via `<leader>ac` in Neovim. Once loaded, the `/lake` and `/lean` commands become available and `lean4` becomes a recognized task type.

## MCP Tool Setup

### lean-lsp

The `lean-lsp` MCP server provides live Lean LSP access for agents.

```bash
npx -y lean-lsp-mcp@latest
```

Configured automatically in `manifest.json`. No API key required. The server depends on a working Lean 4 toolchain (installed via `elan`).

**Capabilities** (used by `lean-research-agent` and `lean-implementation-agent`):

| Tool | Purpose |
|------|---------|
| `lean_goal` | Proof state at a file position ("no goals" = done) |
| `lean_diagnostic_messages` | Compiler errors/warnings for a file |
| `lean_hover_info` | Type signature and docstring at position |
| `lean_multi_attempt` | Test tactics at a position without editing |
| `lean_local_search` | Fast search for local declarations |
| `lean_leansearch` | Natural-language Mathlib search |
| `lean_loogle` | Type-pattern Mathlib search |
| `lean_hammer_premise` | Goal-driven premise suggestion |
| `lean_state_search` | Find lemmas that close a goal |
| `lean_verify` | Axiom check and source scan |
| `lean_build` | Rebuild and restart the LSP |

Detailed tool guidance lives in the MCP server's own instructions (loaded automatically by Claude Code when the server is configured).

## Commands

### /lake

Lake build management and error handling.

**Syntax**:
```bash
/lake build                # Build current project
/lake clean                # Clean build artifacts
/lake update               # Update Mathlib dependencies
```

**Delegation**: Routed through `skill-lake-repair` -> `lean-implementation-agent` for build-error repair flows.

### /lean

Lean proof assistance via research and implementation flows.

**Syntax**:
```bash
/research <task>           # Research Lean/Mathlib topic (routes to lean-research-agent)
/plan <task>               # Plan Lean implementation
/implement <task>          # Execute Lean implementation
```

**Delegation**: The standard `/research`, `/plan`, `/implement` commands route to lean-specific skills and agents when the task has `task_type: "lean4"`.

## Architecture

```
lean/
├── manifest.json              # Extension configuration
├── EXTENSION.md               # CLAUDE.md merge content
├── index-entries.json         # Context discovery entries
├── README.md                  # This file
├── settings-fragment.json     # Permission/allowlist merge fragment
│
├── commands/
│   ├── lake.md                # /lake command
│   └── lean.md                # /lean command
│
├── skills/
│   ├── skill-lean-research/   # Research wrapper
│   ├── skill-lean-implementation/ # Implementation wrapper
│   ├── skill-lake-repair/     # Build-error repair
│   └── skill-lean-version/    # Lean version management (direct execution)
│
├── agents/
│   ├── lean-research-agent.md       # Lean/Mathlib research
│   └── lean-implementation-agent.md # Lean proof implementation
│
├── rules/
│   └── lean4.md               # Lean 4 coding conventions (auto-applied)
│
└── context/
    └── project/
        └── lean4/             # Lean 4 domain knowledge and references
```

## Skill-Agent Mapping

| Skill | Agent | Model | Purpose |
|-------|-------|-------|---------|
| skill-lean-research | lean-research-agent | opus | Lean 4 / Mathlib research with MCP |
| skill-lean-implementation | lean-implementation-agent | - | Lean proof implementation with MCP |
| skill-lake-repair | lean-implementation-agent | - | Lake build-error repair loop |
| skill-lean-version | (direct execution) | - | Lean toolchain version management |

## Language Routing

| Task Type | Research Skill | Implementation Skill | Tools |
|-----------|----------------|---------------------|-------|
| `lean4` | skill-lean-research | skill-lean-implementation | WebSearch, WebFetch, Read, Write, Edit, Bash(lake), lean-lsp MCP |

## Workflow

```
/research <task>            (task_type: lean4)
    |
    v
skill-lean-research -> lean-research-agent
    |  (uses lean-lsp MCP for goal state, type lookups, Mathlib search)
    v
specs/{NNN}_{SLUG}/reports/MM_{slug}.md
    |
    v
/plan <task>
    |
    v
specs/{NNN}_{SLUG}/plans/MM_{slug}.md
    |
    v
/implement <task>
    |
    v
skill-lean-implementation -> lean-implementation-agent
    |  (writes .lean files, runs lake build, repairs errors)
    v
specs/{NNN}_{SLUG}/summaries/MM_{slug}-summary.md
```

## Output Artifacts

| Phase | Artifact |
|-------|----------|
| Research | `specs/{NNN}_{SLUG}/reports/MM_{slug}.md` |
| Plan | `specs/{NNN}_{SLUG}/plans/MM_{slug}.md` |
| Implementation | `.lean` source edits plus `specs/{NNN}_{SLUG}/summaries/MM_{slug}-summary.md` |

## Key Patterns

### Lake Build Verification

The implementation agent runs `lake build` after each phase of edits. If the build fails, it captures diagnostics via `lean_diagnostic_messages` and either repairs in place or marks the phase `[PARTIAL]` for resume.

### Proof Search Hierarchy

When searching for a lemma, agents follow the decision tree from the MCP server instructions:
1. `lean_local_search` - local project declarations
2. `lean_leansearch` - natural-language Mathlib search
3. `lean_loogle` - type-pattern search
4. `lean_hammer_premise` - goal-driven premise suggestion
5. `lean_state_search` - closing-lemma search

This ordering minimizes rate-limited external searches.

### Mathlib Conventions

Lean files follow the Mathlib style guide (imports at top, `namespace` blocks, docstrings with `/-!` and `-/`). See `rules/lean4.md` for the enforced conventions.

## Tool Dependencies

| Tool | Purpose | Install |
|------|---------|---------|
| Lean 4 toolchain | Lean compiler and language server | `curl https://elan.lean-lang.org/elan-init.sh -sSf | sh` |
| lake | Lean build tool | Bundled with Lean toolchain |
| lean-lsp-mcp | MCP server for Lean LSP access | `npx -y lean-lsp-mcp@latest` |

## References

- [Lean 4 Documentation](https://leanprover.github.io/lean4/doc/)
- [Mathlib](https://leanprover-community.github.io/mathlib4_docs/)
- [lean-lsp-mcp on npm](https://www.npmjs.com/package/lean-lsp-mcp)
- [Lake build tool](https://github.com/leanprover/lean4/tree/master/src/lake)
