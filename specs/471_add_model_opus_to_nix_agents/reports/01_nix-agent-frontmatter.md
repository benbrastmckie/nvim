# Research Report: Task #471

**Task**: 471 - add_model_opus_to_nix_agents
**Started**: 2026-04-16T00:00:00Z
**Completed**: 2026-04-16T00:05:00Z
**Effort**: Trivial (< 5 minutes)
**Dependencies**: None
**Sources/Inputs**: Codebase (agent files, frontmatter standard)
**Artifacts**: - specs/471_add_model_opus_to_nix_agents/reports/01_nix-agent-frontmatter.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Both nix agent files (deployed copies and extension source copies) are missing `model: opus` in their YAML frontmatter
- The agent-frontmatter-standard explicitly requires all extension agents to declare `model: opus`
- Four files need identical one-line additions: add `model: opus` after the `description:` field in each frontmatter block

## Context & Scope

The task is a consistency fix. All other research/implementation agents (`general-research-agent`, `general-implementation-agent`, `planner-agent`, `neovim-research-agent`, etc.) already have `model: opus` in their YAML frontmatter. The two nix agents were created without this field, which is functionally harmless (the system defaults to Opus anyway) but inconsistent with the documented standard.

## Findings

### Codebase Patterns

**Files missing `model: opus`** (all 4 files need the change):

| File | Current Frontmatter | Required Change |
|------|---------------------|-----------------|
| `.claude/agents/nix-research-agent.md` | `name`, `description` only | Add `model: opus` |
| `.claude/agents/nix-implementation-agent.md` | `name`, `description` only | Add `model: opus` |
| `.claude/extensions/nix/agents/nix-research-agent.md` | `name`, `description` only | Add `model: opus` |
| `.claude/extensions/nix/agents/nix-implementation-agent.md` | `name`, `description` only | Add `model: opus` |

**Current frontmatter in all 4 files** (identical structure):
```yaml
---
name: nix-{role}-agent
description: {description text}
---
```

**Required frontmatter** (after change):
```yaml
---
name: nix-{role}-agent
description: {description text}
model: opus
---
```

**Reference: `general-research-agent.md`** already has the correct structure:
```yaml
---
name: general-research-agent
description: Research general tasks using web search and codebase exploration
model: opus
---
```

### Standard Compliance

From `.claude/docs/reference/standards/agent-frontmatter-standard.md`:

> **All agents default to Opus.** All 7 core agents and all extension agents declare `model: opus` in their frontmatter. This provides the highest reasoning quality as the baseline.

The standard also states under Usage Guidelines:
> **Use `model: opus` for**: All core agents (research, planning, implementation, coordination) and all extension agents (domain-specific research and implementation)

### Extension vs Deployed Copies

The nix extension maintains source agent files in `.claude/extensions/nix/agents/` which are synced to `.claude/agents/` during extension loading. Both the source copies and the deployed copies must be updated to ensure the fix persists across extension reloads.

### Exact Edits Required

**File 1**: `/home/benjamin/.config/nvim/.claude/agents/nix-research-agent.md`
- Location: Line 3, after `description: Research NixOS and Home Manager configuration tasks`
- Add: `model: opus`

**File 2**: `/home/benjamin/.config/nvim/.claude/agents/nix-implementation-agent.md`
- Location: Line 3, after `description: Implement Nix configuration changes from plans`
- Add: `model: opus`

**File 3**: `/home/benjamin/.config/nvim/.claude/extensions/nix/agents/nix-research-agent.md`
- Location: Line 3, after `description: Research NixOS and Home Manager configuration tasks`
- Add: `model: opus`

**File 4**: `/home/benjamin/.config/nvim/.claude/extensions/nix/agents/nix-implementation-agent.md`
- Location: Line 3, after `description: Implement Nix configuration changes from plans`
- Add: `model: opus`

## Decisions

- All 4 files must be updated (2 deployed copies + 2 extension source copies)
- The `model: opus` line should be placed after `description:` and before the closing `---` to match the pattern used by all other agents
- No other changes are required to any file

## Risks & Mitigations

- **Risk**: Updating only the deployed copies but not the extension source. If the extension is reloaded, the fix would be lost.
  - **Mitigation**: Update all 4 files in the same operation.
- **Risk**: None otherwise - this is a purely additive, non-breaking change.

## Appendix

### Files Examined
- `/home/benjamin/.config/nvim/.claude/agents/nix-research-agent.md` - lines 1-4
- `/home/benjamin/.config/nvim/.claude/agents/nix-implementation-agent.md` - lines 1-4
- `/home/benjamin/.config/nvim/.claude/agents/general-research-agent.md` - lines 1-5 (reference)
- `/home/benjamin/.config/nvim/.claude/extensions/nix/agents/nix-research-agent.md` - lines 1-4
- `/home/benjamin/.config/nvim/.claude/extensions/nix/agents/nix-implementation-agent.md` - lines 1-4
- `/home/benjamin/.config/nvim/.claude/docs/reference/standards/agent-frontmatter-standard.md` - full file
