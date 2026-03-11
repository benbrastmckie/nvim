# Implementation Plan: Task #181

- **Task**: 181 - Fix Website opencode missing agent files
- **Status**: [NOT STARTED]
- **Effort**: 1-2 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, artifact-formats.md
- **Type**: meta
- **Lean Intent**: false
- **Date**: 2026-03-10
- **Feature**: Create 5 missing opencode agent files to fix startup failure in Website repo
- **Estimated Hours**: 1-2 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
- **Research Reports**: [research-001.md](../reports/research-001.md)

## Overview

The Website project at `/home/benjamin/Projects/Logos/Website/` fails to start opencode because `opencode.json` references 5 agent files via `{file:...}` syntax that do not exist. The old agent files were deleted from `.opencode/agents/` during a directory refactoring but 5 of the 11 replacement files were never created in `.opencode/agent/subagents/`. The fix is to extract old agent content from git history, adapt it to the new naming/format conventions, and create the 5 missing files.

### Research Integration

- Old agent content is available via `git show HEAD:.opencode/agents/{old-name}.md`
- Existing agents in the new location (e.g., `general-research-agent.md`) use a standardized frontmatter format with `name:` and `description:` fields
- The old files use a different frontmatter format (with `mode:`, `temperature:`, `tools:` fields) -- the new format should match the existing agents in `agent/subagents/`
- File sizes range from 80-360 lines; document-converter is the largest

## Goals and Non-Goals

**Goals**:
- Create the 5 missing agent files so opencode starts without errors
- Adapt content from old agents to match the new agent file format
- Verify opencode.json validates successfully after creating files

**Non-Goals**:
- Rewriting agent prompts or changing agent behavior
- Modifying opencode.json (references are already correct)
- Committing the changes in the Website repo (user will manage that)

## Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Old agent content in git may be outdated | L | M | Content is functional; update format only |
| New format differs significantly from old | M | L | Reference existing agents (general-research-agent.md) for format |
| opencode.json validation requires specific frontmatter | H | M | Match exact frontmatter fields from existing working agents |

## Implementation Phases

### Phase 1: Extract and Create Agent Files [NOT STARTED]

**Goal**: Create all 5 missing agent files by extracting old content from git history and adapting to the new format.

**Tasks**:
- [ ] Extract old agent content from git history for all 5 agents using `git show HEAD:.opencode/agents/{name}.md`
- [ ] Read an existing agent file (`general-research-agent.md`) to confirm the current frontmatter format
- [ ] Create `web-research-agent.md` adapted from old `web-research.md`
- [ ] Create `web-implementation-agent.md` adapted from old `web-implementation.md`
- [ ] Create `neovim-research-agent.md` adapted from old `neovim-research.md`
- [ ] Create `neovim-implementation-agent.md` adapted from old `neovim-implementation.md`
- [ ] Create `document-converter-agent.md` adapted from old `document-converter.md`

**Timing**: 0.75-1.5 hours

**Files to create**:
- `/home/benjamin/Projects/Logos/Website/.opencode/agent/subagents/web-research-agent.md`
- `/home/benjamin/Projects/Logos/Website/.opencode/agent/subagents/web-implementation-agent.md`
- `/home/benjamin/Projects/Logos/Website/.opencode/agent/subagents/neovim-research-agent.md`
- `/home/benjamin/Projects/Logos/Website/.opencode/agent/subagents/neovim-implementation-agent.md`
- `/home/benjamin/Projects/Logos/Website/.opencode/agent/subagents/document-converter-agent.md`

**Verification**:
- All 5 files exist in `.opencode/agent/subagents/`
- Each file has valid YAML frontmatter with `name:` and `description:` fields
- `ls -la` confirms all files are non-empty

---

### Phase 2: Validate opencode Startup [NOT STARTED]

**Goal**: Confirm opencode starts without file reference errors.

**Tasks**:
- [ ] Run opencode in the Website directory to check for configuration validation errors
- [ ] If validation fails, inspect error messages and fix any remaining issues
- [ ] Confirm all `{file:...}` references in opencode.json resolve successfully

**Timing**: 0.25-0.5 hours

**Verification**:
- opencode starts without "bad file reference" errors
- All 5 new agents are listed/available in the opencode agent roster

## Testing and Validation

- [ ] All 5 agent files exist and are non-empty
- [ ] Each file has valid frontmatter matching existing agent format
- [ ] opencode.json validates without file reference errors
- [ ] opencode starts successfully in `/home/benjamin/Projects/Logos/Website/`

## Artifacts and Outputs

- 5 new agent files in `/home/benjamin/Projects/Logos/Website/.opencode/agent/subagents/`
- This implementation plan

## Rollback/Contingency

If the created agent files cause issues beyond file-not-found errors, the alternative is Option B from the research report: remove the 5 broken agent references from `opencode.json` entirely. This is a simpler but less functional fix that disables the specialized agents.
