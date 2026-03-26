# Research Report: Task #295

**Task**: 295 - Fix .memory/README.md OpenCode references
**Generated**: 2026-03-25
**Source**: Post-refactor audit of tasks 286-292
**Status**: Researched

---

## Context Summary

**Purpose**: Replace OpenCode system references with Claude Code in .memory/README.md
**Scope**: 7 references in 1 file
**Affected Components**: .memory/README.md
**Domain**: meta
**Language**: meta

## Findings

The `.memory/README.md` was originally created from an OpenCode template and never adapted for the Claude Code system. It consistently references "OpenCode" and `.opencode/` paths.

### File: `.memory/README.md`

| Line | Current Text | Should Be |
|------|-------------|-----------|
| 1 | `# OpenCode Memory Vault` | `# Claude Code Memory Vault` |
| 3 | `...for the OpenCode memory management system.` | `...for the Claude Code memory management system.` |
| 7 | `...the OpenCode system can reference...` | `...the Claude Code system can reference...` |
| 12 | `.opencode/memory/` | `.claude/memory/` (or remove — .memory/ is at project root) |
| 22 | `/learn "text to remember"` | Verify correct Claude Code command syntax |
| 49 | `Open this .opencode/memory/ as a vault` | `Open this .memory/ as a vault` |
| 54 | `.opencode/docs/memory-setup.md` | `.claude/docs/memory-setup.md` |

### Other .memory/ files

Subdirectory READMEs (00-Inbox, 10-Memories, 20-Indices, 30-Templates) have no OpenCode references — only the root README is affected.

## Implementation

Find-and-replace: `OpenCode` -> `Claude Code`, `.opencode/` -> `.claude/` (or correct path). Also verify the `/learn` command reference on line 22 matches actual Claude Code commands.

## Effort Assessment

- **Estimated Effort**: 15 minutes
- **Complexity**: Trivial — text substitutions in 1 file

---

*Generated from post-refactor audit of tasks 286-292.*
