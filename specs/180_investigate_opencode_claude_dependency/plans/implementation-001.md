# Implementation Plan: Task #180

- **Task**: 180 - Fix opencode.json agent path references
- **Status**: [NOT STARTED]
- **Effort**: 0.5-1 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: CLAUDE.md
- **Type**: meta
- **Lean Intent**: false
- **Date**: 2026-03-10
- **Feature**: Fix broken agent file references in Website repo opencode.json
- **Estimated Hours**: 0.5-1 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
- **Research Reports**: [research-001.md](../reports/research-001.md)

## Overview

The Website repository's `opencode.json` references agent files using incorrect paths (`agents/` instead of `agent/subagents/`) and incorrect filenames (missing `-agent` suffix). The agents themselves exist and are installed correctly by extensions. This plan fixes the path references and addresses missing extension dependencies for neovim and document-converter agents.

### Research Integration

Research confirmed the root cause is a path configuration error, not an architectural mismatch. The extension system correctly installs agents to `.opencode/agent/subagents/` with `-agent` suffix filenames. The `opencode.json` was written with incorrect path assumptions.

## Goals and Non-Goals

**Goals**:
- Fix all agent file references in `Website/opencode.json` to use correct paths
- Identify which extensions must be loaded for full agent coverage
- Verify all referenced agents resolve after fixes

**Non-Goals**:
- Modifying the extension loader or agent installation paths
- Creating new agents or extensions
- Changing the opencode agent architecture

## Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Website repo not accessible from nvim config worktree | M | L | Plan provides exact changes; can be applied manually in Website repo |
| Additional broken references beyond agents | L | L | Verify full opencode.json validation after fixes |
| neovim agents not needed in Website repo | L | M | Document as optional; only fix paths for agents that exist |

## Implementation Phases

### Phase 1: Fix Agent Path References in opencode.json [NOT STARTED]

**Goal**: Update all `{file:...}` agent references in `Website/opencode.json` to use the correct `agent/subagents/` path and `-agent` filename suffix.

**Tasks**:
- [ ] Read current `Website/opencode.json` to confirm all agent references
- [ ] Update each agent reference path from `agents/` to `agent/subagents/`
- [ ] Update each agent filename to include `-agent` suffix
- [ ] Handle special cases: `task-planner` -> `planner-agent`, `document-converter` -> conditional on extension
- [ ] For agents requiring unloaded extensions (neovim-*, document-converter), add JSON comments or conditionally remove references

**Timing**: 20 minutes

**Files to modify**:
- `/home/benjamin/Projects/Logos/Website/opencode.json` - Fix all agent `{file:...}` references

**Path corrections**:

| Current Reference | Corrected Reference |
|-------------------|---------------------|
| `{file:.opencode/agents/web-research.md}` | `{file:.opencode/agent/subagents/web-research-agent.md}` |
| `{file:.opencode/agents/web-implementation.md}` | `{file:.opencode/agent/subagents/web-implementation-agent.md}` |
| `{file:.opencode/agents/general-research.md}` | `{file:.opencode/agent/subagents/general-research-agent.md}` |
| `{file:.opencode/agents/general-implementation.md}` | `{file:.opencode/agent/subagents/general-implementation-agent.md}` |
| `{file:.opencode/agents/task-planner.md}` | `{file:.opencode/agent/subagents/planner-agent.md}` |
| `{file:.opencode/agents/meta-builder.md}` | `{file:.opencode/agent/subagents/meta-builder-agent.md}` |
| `{file:.opencode/agents/neovim-research.md}` | `{file:.opencode/agent/subagents/neovim-research-agent.md}` (requires nvim extension) |
| `{file:.opencode/agents/neovim-implementation.md}` | `{file:.opencode/agent/subagents/neovim-implementation-agent.md}` (requires nvim extension) |
| `{file:.opencode/agents/document-converter.md}` | Remove or mark as requiring filetypes extension |

**Verification**:
- Run opencode validation (if available) to confirm no broken file references
- Verify each referenced file exists at the corrected path in the Website repo

---

### Phase 2: Verify and Document Extension Requirements [NOT STARTED]

**Goal**: Confirm which extensions need to be loaded for full agent coverage and document the dependency clearly.

**Tasks**:
- [ ] List extensions currently loaded in Website repo (check `extensions.json`)
- [ ] Verify `web` extension agents exist at corrected paths
- [ ] Verify core agents (general-research, planner, meta-builder) exist at corrected paths
- [ ] Document that `nvim` extension must be loaded for neovim-research-agent and neovim-implementation-agent
- [ ] Document that `filetypes` extension must be loaded for document-converter-agent
- [ ] Update research report with final verification results

**Timing**: 10 minutes

**Files to modify**:
- None (verification only, results documented in implementation summary)

**Verification**:
- All agent files referenced in corrected opencode.json exist on disk
- Extensions.json shows required extensions are loaded (or documented as optional)

## Testing and Validation

- [ ] All corrected `{file:...}` paths resolve to existing agent files
- [ ] opencode.json passes validation without "bad file reference" errors
- [ ] Memory extension loading via `<leader>ao` no longer triggers agent path errors
- [ ] Core agents (web-*, general-*, planner, meta-builder) are all accessible

## Artifacts and Outputs

- Updated `Website/opencode.json` with corrected agent paths
- Implementation summary documenting all changes and extension requirements

## Rollback/Contingency

The original `opencode.json` can be restored via git checkout. Changes are limited to path string replacements in a single file, making rollback trivial.
