# Implementation Plan: Task #109

- **Task**: 109 - Make agent system portable for new repos
- **Status**: [NOT STARTED]
- **Effort**: 1.5-2 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-002.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md
- **Type**: meta
- **Lean Intent**: false

**Version**: 002
**Created**: 2026-03-02
**Language**: meta
**Revision Note**: User clarified they use neovim in every repo, so ALL neovim skills/agents should be copied. Only the CLAUDE.md and project-overview.md should not announce "this is a neovim project" when loaded elsewhere.

## Overview

Make the `.claude/` agent system portable by updating only the documentation layer (CLAUDE.md and project-overview mechanism) while KEEPING all neovim-specific skills, agents, and rules intact. The user uses neovim for editing in every repository, so neovim tooling should be universally available. The goal is simply to avoid the documentation announcing "Neovim Configuration Management System" when the agent system is copied to a non-neovim project like ModelBuilder.

### Key Insight (Revision v002)

The original plan misunderstood the goal. The user wants:
1. **KEEP**: All neovim skills, agents, rules, context files (used everywhere)
2. **CHANGE**: Only CLAUDE.md title/header and project-overview.md approach

This is a documentation-only change, not a structural separation of neovim content.

### Research Integration

From research-001.md:
- Sync mechanism copies everything (no filtering) - this is CORRECT behavior for the revised goal
- CLAUDE.md has 13 neovim-specific references - most can STAY (skill mappings, rules), only header/title needs change
- project-overview.md is neovim-specific - needs replacement with a generation mechanism

## Goals & Non-Goals

**Goals**:
- Change CLAUDE.md title from "Neovim Configuration Management System" to generic "Agent System"
- Create a project-overview.md generation mechanism so each repo can have project-appropriate documentation
- Keep all neovim skills/agents/rules intact and copyable
- Ensure a clean first-run experience when agent system is loaded in a new repo

**Non-Goals**:
- Moving or removing any neovim-specific skills, agents, or rules (KEEP THEM ALL)
- Removing neovim entries from routing tables or mappings (keep neovim as a supported language)
- Creating a generic agent-system.md (not needed - CLAUDE.md serves this role)
- Modifying sync.lua (it already works correctly)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Generic CLAUDE.md loses useful project context | Low | Medium | Link to project-overview.md for project-specific info |
| project-overview.md not generated in new repos | Medium | Medium | Create update-project.md with clear guidance; CLAUDE.md links to it |
| Existing neovim workflows break | None | None | No functional changes - only documentation layer |

## Implementation Phases

### Phase 1: Update CLAUDE.md Header [COMPLETED]

**Goal**: Make CLAUDE.md title and header generic while preserving all content.

**Tasks**:
- [ ] Change title from "Neovim Configuration Management System" to "Agent System"
- [ ] Change subtitle to generic description
- [ ] Update Project Structure section to be generic (link to project-overview.md for specifics)
- [ ] Keep ALL other sections unchanged (skill mappings, rules, routing - all stay as-is)

**Timing**: 30 minutes

**Files to modify**:
- `.claude/CLAUDE.md` - Title, header, and Project Structure section only

**Steps**:
1. Change line 1: "# Neovim Configuration Management System" → "# Agent System"
2. Change line 3: "Task management and agent orchestration for Neovim configuration maintenance" → "Task management and agent orchestration for project development"
3. Replace Project Structure section (lines 12-27) with:
   - Generic structure showing .claude/ and specs/ directories
   - Note: "Project-specific structure documented in `.claude/context/project/repo/project-overview.md`"
   - Note: "If project-overview.md doesn't exist, see `.claude/context/project/repo/update-project.md` for guidance"
4. Keep ALL other sections exactly as-is:
   - Task Management (generic)
   - Language-Based Routing (keep neovim row - it's useful everywhere)
   - Command Reference (generic)
   - State Synchronization (generic)
   - Git Commit Conventions (generic)
   - Skill-to-Agent Mapping (keep neovim skills - they're useful everywhere)
   - Rules References (keep neovim-lua.md reference - useful everywhere)
   - Context Discovery (keep examples as-is)
   - Context Imports (keep neovim imports - they're useful)
   - All remaining sections (generic)

**Verification**:
- CLAUDE.md title is generic (not "Neovim")
- CLAUDE.md subtitle is generic
- All neovim skill/agent/rule references PRESERVED (intentionally)
- Document reads correctly for any project type

---

### Phase 2: Create update-project.md [NOT STARTED]

**Goal**: Create a guidance file that helps generate project-appropriate project-overview.md in new repositories.

**Tasks**:
- [ ] Create `.claude/context/project/repo/update-project.md` with generation guidance
- [ ] Update index.json if needed

**Timing**: 45 minutes

**Files to create**:
- `.claude/context/project/repo/update-project.md` - Guide for generating project-overview.md

**Steps**:
1. Create update-project.md with:
   - Purpose: "Guide for generating project-specific documentation"
   - When to use: "When project-overview.md doesn't exist or doesn't match current project"
   - What to analyze: Project structure, tech stack, entry points, build system, testing patterns
   - Output template: Required sections for project-overview.md
   - Instructions for Claude: How to gather info and generate the file

2. Template sections for project-overview.md:
   - Project Overview (what the project does)
   - Technology Stack (languages, frameworks, tools)
   - Project Structure (directory layout)
   - Entry Points (main files, config locations)
   - Development Workflow (how to build, test, run)
   - Key Patterns (project conventions)
   - Related Documentation (links to project docs)

3. Keep the existing project-overview.md (neovim-specific) as-is - it's correct for THIS repo
   - The new mechanism is for OTHER repos where the agent system gets copied

**Verification**:
- update-project.md exists and is well-formed
- Contains no project-specific content (it's a template/guide)
- Could be used to generate project-overview.md for any project type

---

### Phase 3: Verify Portability [NOT STARTED]

**Goal**: Verify the agent system would work correctly when copied to a new repository.

**Tasks**:
- [ ] Verify CLAUDE.md header is generic
- [ ] Verify update-project.md provides clear guidance
- [ ] Verify all neovim tools still present and functional
- [ ] Verify existing neovim workflows unaffected

**Timing**: 15 minutes

**Files to verify**:
- `.claude/CLAUDE.md` - Generic header, all content preserved
- `.claude/context/project/repo/update-project.md` - Exists, generic
- `.claude/context/project/repo/project-overview.md` - Unchanged (neovim-specific for this repo)
- `.claude/skills/skill-neovim-*` - Still present
- `.claude/agents/neovim-*` - Still present
- `.claude/rules/neovim-lua.md` - Still present

**Steps**:
1. Verify CLAUDE.md changes:
   - Title should NOT contain "Neovim"
   - All neovim skills/agents/rules SHOULD still be referenced (we keep them)

2. Verify update-project.md:
   - File exists
   - Contains template/guidance for generating project-overview.md
   - No hardcoded project-specific content

3. Verify neovim tooling preserved:
   - `ls .claude/skills/skill-neovim*` returns skill-neovim-research, skill-neovim-implementation
   - `ls .claude/agents/neovim*` returns neovim-research-agent, neovim-implementation-agent
   - `.claude/rules/neovim-lua.md` exists

4. Test workflow coherence:
   - Read through CLAUDE.md - should make sense for any project
   - Neovim tools still available when language=neovim tasks are created

**Verification**:
- CLAUDE.md generic but fully functional
- All neovim tooling present and referenced
- update-project.md provides clear path for new repos

## Testing & Validation

- [ ] CLAUDE.md title is "Agent System" (not "Neovim Configuration Management System")
- [ ] CLAUDE.md Project Structure section links to project-overview.md
- [ ] All neovim skills/agents/rules still present and referenced in CLAUDE.md
- [ ] update-project.md exists with generation guidance
- [ ] Existing project-overview.md unchanged (still neovim-specific for this repo)
- [ ] No functional changes to task management workflow

## Artifacts & Outputs

- `.claude/CLAUDE.md` (modified) - Generic header, preserved functionality
- `.claude/context/project/repo/update-project.md` (new) - Project-overview generation guide
- `.claude/context/project/repo/project-overview.md` (unchanged) - Neovim-specific for this repo

## Rollback/Contingency

If changes cause issues:
1. Revert CLAUDE.md title change: `git checkout .claude/CLAUDE.md`
2. update-project.md is additive and causes no conflicts
3. No neovim tooling was removed, so no restoration needed
