# Implementation Plan: Task #295

**Task**: 295 - Fix .memory/README.md OpenCode references
**Generated**: 2026-03-26
**Phase count**: 1

---

## Phase 1: Fix OpenCode references [NOT STARTED]

**File**: `.memory/README.md`

| Line | Change | Details |
|------|--------|---------|
| 1 | `OpenCode` -> `Claude Code` | Title |
| 3 | `OpenCode` -> `Claude Code` | Description |
| 7 | `OpenCode` -> `Claude Code` | Purpose section |
| 12 | `.opencode/memory/` -> `.memory/` | Directory structure path |
| 22-23 | Keep `/learn` command | Valid command in memory extension |
| 49 | `.opencode/memory/` -> `.memory/` | MCP setup instructions |
| 54 | `.opencode/docs/memory-setup.md` -> `.claude/extensions/memory/context/project/memory/memory-setup.md` | Setup reference |

**Verification**: Grep for `opencode` and `OpenCode` in `.memory/README.md` -- expect zero matches after edits.
