# Implementation Plan: Review .opencode/ and .claude/ Agent Systems for Feature Gaps and Improvements

- **Task**: OC_200 - review_opencode_claude_agent_systems_feature_gaps
- **Status**: [COMPLETED]
- **Effort**: 10 hours (revised from 12 hours)
- **Dependencies**: Task OC_199 - naming convention migration (dependency note: artifact naming conventions will be handled by task 199)
- **Research Inputs**: 
  - specs/OC_200_review_opencode_claude_agent_systems_feature_gaps/reports/research-001.md
  - specs/OC_200_review_opencode_claude_agent_systems_feature_gaps/reports/research-002.md
- **Artifacts**: plans/implementation-003.md (this file)
- **Standards**:
  - .opencode/context/core/formats/plan-format.md
  - .opencode/context/core/standards/status-markers.md
  - .opencode/context/core/standards/documentation-standards.md
  - .opencode/context/core/standards/task-management.md
- **Type**: meta
- **Lean Intent**: false
- **Plan Version**: 3
- **Previous Version**: plans/implementation-002.md

## Overview

This plan addresses the comprehensive feature gap analysis between the .opencode/ and .claude/ agent systems. The implementation focuses on standardizing command naming (especially the `/fix` to `/fix-it` command), porting missing skills (skill-tag, skill-todo), and improving documentation across both systems.

**Key Revision from v2**: Artifact naming convention work has been removed from this plan as it is being handled by task 199 (see `specs/199_complete_summary_naming_migration_fix_validation_globs/plans/01_naming-convention-migration.md`). This reduces scope and eliminates duplicate work.

**Key Revision from v1**: Research-002 revealed that extension commands are already synchronized between systems, eliminating the need to port `/convert`. The focus shifts to skill-level parity and command naming standardization.

### Research Integration

This plan integrates findings from both research reports:

**From research-001.md**:
- Critical naming inconsistency between systems
- 6 unique .opencode commands originally identified
- Advanced /fix-it in .claude vs basic /fix in .opencode
- Documentation gaps in context index and extension development

**From research-002.md** (Key Updates):
- **Extensions already synchronized**: `/convert` and `/learn` commands exist in both systems with identical content
- **skill-fix must be renamed to skill-fix-it**: Not just a replacement, but a full rename required
- **skill-todo missing from .claude/**: Additional skill gap identified
- **All extension commands at parity**: No extension porting work needed

### Task 199 Dependency

**Task OC_199** (`complete_summary_naming_migration_fix_validation_globs`) is responsible for:
- Standardizing artifact naming conventions across both systems
- Aligning .opencode/ artifact naming with .claude/ convention (`MM_{short-slug}.md`)
- Updating all references to use the new naming pattern
- Creating migration documentation for the naming changes

This plan assumes task 199 will complete the naming convention work, allowing this plan to focus on skill porting and command standardization.

## Goals & Non-Goals

**Goals**:
- Rename `/fix` to `/fix-it` in .opencode/ and port advanced features (command naming only, not artifacts)
- Port skill-tag and skill-todo from .opencode/ to .claude/
- Improve documentation completeness (context index, extension guides)
- Update all references to use standardized command naming
- Add missing agent types to .claude/ system

**Non-Goals**:
- Full consolidation of both systems into one (out of scope)
- Removing or deprecating either system
- Changing MCP server configurations (document only)
- Modifying synchronized extension commands (already at parity)
- Refactoring working code for style consistency only
- **Artifact naming convention standardization** (handled by task 199)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Renaming `/fix` to `/fix-it` breaks muscle memory | Medium | High | Update all documentation; add alias note in AGENTS.md; provide clear migration path |
| Naming convention changes break existing tooling | High | Medium | Create migration guide; maintain backward compatibility during transition |
| skill-fix-it port missing features from .claude/ version | Medium | Medium | Verify all features (topic grouping, QUESTION: support) are preserved |
| Agent type additions introduce bugs | Medium | Low | Test new agents in isolated environment; verify agent metadata files |
| Documentation changes become outdated | Low | High | Include documentation review in future task templates |
| Missing references after rename operations | Medium | Medium | Use grep to find all references before and after changes |
| Dependency on task 199 completion | Medium | Medium | Coordinate with task 199; this plan can proceed with skill porting work independently |

## Implementation Phases

### Phase 1: Rename /fix to /fix-it in .opencode/ [NOT STARTED]

**Goal**: Standardize on `/fix-it` command name across both systems

**Tasks**:
- [ ] Rename `.opencode/commands/fix.md` to `.opencode/commands/fix-it.md`
- [ ] Update command content to reference `/fix-it` instead of `/fix`
- [ ] Rename `.opencode/skills/skill-fix/` to `.opencode/skills/skill-fix-it/`
- [ ] Create new `.opencode/skills/skill-fix-it/SKILL.md` with advanced features from .claude/
- [ ] Ensure topic grouping logic is preserved
- [ ] Ensure QUESTION: tag support is included
- [ ] Ensure dependency handling (learn-it → fix-it) is preserved
- [ ] Update `.opencode/skills/skill-orchestrator/SKILL.md` to reference skill-fix-it
- [ ] Update `.opencode/AGENTS.md` command reference table
- [ ] Add deprecation notice to old skill-fix location (if not fully deleted)
- [ ] Search for any other references to `/fix` or `skill-fix` and update them

**Timing**: 2 hours

**Files to modify**:
- `.opencode/commands/fix.md` → `.opencode/commands/fix-it.md` (rename + update)
- `.opencode/skills/skill-fix/` → `.opencode/skills/skill-fix-it/` (rename)
- `.opencode/skills/skill-fix-it/SKILL.md` - Create with .claude/ content
- `.opencode/skills/skill-orchestrator/SKILL.md` - Update references
- `.opencode/AGENTS.md` - Update command reference

**Verification**:
- `/fix-it` command runs without errors in .opencode/
- Old `/fix` command no longer exists or redirects to `/fix-it`
- skill-fix-it properly groups tags by topic
- QUESTION: tag type is supported
- No references to old `skill-fix` remain in codebase

---

### Phase 2: Port skill-tag to .claude/ System [COMPLETED]

**Goal**: Enable semantic versioning tag creation in .claude/

**Tasks**:
- [ ] Copy `.opencode/skills/skill-tag/SKILL.md` to `.claude/skills/skill-tag/SKILL.md`
- [ ] Review for .opencode-specific references and update for .claude/
- [ ] Create `.claude/commands/tag.md` command file
- [ ] Add skill-tag to `.claude/CLAUDE.md` skill-to-agent mapping
- [ ] Update `.claude/README.md` with /tag command documentation
- [ ] Mark skill-tag as "user-only" in documentation
- [ ] Verify command works with semantic version formats (v1.0.0, etc.)

**Timing**: 1.5 hours

**Files to create/modify**:
- `.claude/skills/skill-tag/SKILL.md` - Create new skill
- `.claude/commands/tag.md` - Create new command
- `.claude/CLAUDE.md` - Add skill-to-agent mapping entry
- `.claude/README.md` - Add command documentation

**Verification**:
- `/tag` command is accessible in .claude/ system
- skill-tag marked as "user-only" in docs
- Command documentation is complete
- Tag creation works with test repository

---

### Phase 3: Port skill-todo to .claude/ System [COMPLETED]

**Goal**: Enable task archiving workflow in .claude/

**Tasks**:
- [ ] Copy `.opencode/skills/skill-todo/SKILL.md` to `.claude/skills/skill-todo/SKILL.md`
- [ ] Review for .opencode-specific references and update for .claude/
- [ ] Create `.claude/commands/todo.md` command file
- [ ] Add skill-todo to `.claude/CLAUDE.md` skill-to-agent mapping
- [ ] Update `.claude/README.md` with /todo command documentation
- [ ] Verify integration with CHANGE_LOG.md workflow

**Timing**: 1.5 hours

**Files to create/modify**:
- `.claude/skills/skill-todo/SKILL.md` - Create new skill
- `.claude/commands/todo.md` - Create new command
- `.claude/CLAUDE.md` - Add skill-to-agent mapping entry
- `.claude/README.md` - Add command documentation

**Verification**:
- `/todo` command is accessible in .claude/ system
- Task archiving workflow functions correctly
- CHANGE_LOG.md updates work as expected
- Command documentation is complete

---

### Phase 4: Port Missing Agent Types to .claude/ [COMPLETED]

**Goal**: Add atomic-task-numberer, git-workflow-manager, and task-executor agents to .claude/

**Tasks**:
- [ ] Copy `.opencode/agent/subagents/atomic-task-numberer.md` to `.claude/agents/atomic-task-numberer-agent.md`
- [ ] Copy `.opencode/agent/subagents/git-workflow-manager.md` to `.claude/agents/git-workflow-manager-agent.md`
- [ ] Copy `.opencode/agent/subagents/task-executor.md` to `.claude/agents/task-executor-agent.md`
- [ ] Update agent frontmatter to match .claude/ conventions
- [ ] Update any .opencode-specific references in agent files
- [ ] Add new agents to `.claude/CLAUDE.md` agent documentation
- [ ] Verify agent files follow .claude/ naming conventions (agents/ not agent/subagents/)

**Timing**: 2 hours

**Files to create**:
- `.claude/agents/atomic-task-numberer-agent.md` - Port from .opencode/
- `.claude/agents/git-workflow-manager-agent.md` - Port from .opencode/
- `.claude/agents/task-executor-agent.md` - Port from .opencode/

**Verification**:
- All 3 agent files exist in .claude/agents/
- Agent frontmatter follows .claude/ conventions
- Agents are documented in CLAUDE.md
- No broken references in agent files

---

### Phase 5: Documentation Improvements [COMPLETED]

**Goal**: Create missing documentation and improve existing documentation

**Tasks**:
- [ ] Create `.claude/context/README.md` with index.json schema documentation
- [ ] Document context index query patterns and examples
- [ ] Create `.claude/context/core/guides/extension-development.md` guide
- [ ] Document extension merge process and merge_targets
- [ ] Update `.opencode/AGENTS.md` to add skill-tag and skill-fix-it documentation
- [ ] Update `.opencode/AGENTS.md` to reflect `/fix` → `/fix-it` rename
- [ ] Create `.claude/agents/README.md` documenting agent structure
- [ ] Update `.opencode/agent/subagents/README.md` if needed
- [ ] Add migration notes for `/fix` → `/fix-it` change

**Timing**: 2.5 hours

**Files to create/modify**:
- `.claude/context/README.md` - New documentation file
- `.claude/context/core/guides/extension-development.md` - New guide
- `.opencode/AGENTS.md` - Add skill-tag and skill-fix-it to skill table
- `.opencode/AGENTS.md` - Update command reference for /fix-it
- `.claude/agents/README.md` - Create agent documentation

**Verification**:
- All new documentation files exist and are non-empty
- index.json schema is documented with examples
- Extension merge process is explained clearly
- skill-tag and skill-fix-it appear in .opencode/AGENTS.md skill table
- `/fix` → `/fix-it` migration path is documented

---

### Phase 6: System Validation and Testing [COMPLETED]

**Goal**: Verify all changes work correctly across both systems

**Tasks**:
- [ ] Run `/fix-it` command in .opencode/ to verify skill-fix-it integration
- [ ] Run `/fix-it` command in .claude/ to verify it still works
- [ ] Test `/tag` command in .claude/ (dry-run mode)
- [ ] Test `/todo` command in .claude/ (dry-run mode)
- [ ] Verify all new agent files load without errors
- [ ] Check that command naming is consistent across all modified files
- [ ] Verify no references to old `/fix` command remain
- [ ] Create summary report of all changes made
- [ ] Update `.claude/CHANGELOG.md` with change summary
- [ ] Verify coordination with task 199 naming changes (no conflicts)

**Timing**: 2.5 hours

**Verification**:
- All commands execute without errors
- All new agent files are properly formatted
- Documentation is accurate and complete
- No broken references or links
- No remaining references to deprecated `skill-fix`

## Testing & Validation

- [ ] `/fix-it` command works in .opencode/ with advanced features (topic grouping, QUESTION:)
- [ ] `/fix-it` command still works in .claude/ (no regression)
- [ ] `/tag` command available and functional in .claude/
- [ ] `/todo` command available and functional in .claude/
- [ ] All 3 new agent types present in .claude/agents/
- [ ] No references to old `/fix` or `skill-fix` remain
- [ ] Documentation complete and accurate
- [ ] No broken internal references
- [ ] All modified skills have valid SKILL.md files
- [ ] Coordination with task 199 verified (no naming conflicts)

## Artifacts & Outputs

- `specs/OC_200_review_opencode_claude_agent_systems_feature_gaps/plans/implementation-003.md` (this file)
- Renamed `.opencode/commands/fix-it.md` (from fix.md)
- New `.opencode/skills/skill-fix-it/SKILL.md` (ported from .claude/)
- New `.claude/skills/skill-tag/SKILL.md`
- New `.claude/commands/tag.md`
- New `.claude/skills/skill-todo/SKILL.md`
- New `.claude/commands/todo.md`
- New `.claude/agents/atomic-task-numberer-agent.md`
- New `.claude/agents/git-workflow-manager-agent.md`
- New `.claude/agents/task-executor-agent.md`
- New `.claude/context/README.md` with index.json schema
- New `.claude/context/core/guides/extension-development.md`
- New `.claude/agents/README.md`
- Updated `.opencode/AGENTS.md` with skill-tag and skill-fix-it documentation
- Updated `.opencode/AGENTS.md` with /fix-it command reference
- Updated `.claude/CLAUDE.md` with new commands and agents
- Updated `.opencode/skills/skill-orchestrator/SKILL.md` with skill-fix-it reference
- Migration guide for `/fix` → `/fix-it` change

## Rollback/Contingency

If any phase fails or causes issues:

1. **skill-fix Rename**: Keep backup of original skill-fix skill; can restore by reverting rename operations
2. **New Commands**: Simply delete created files if not working; no dependencies
3. **New Agents**: Delete agent files if issues found; agents are additive only
4. **Documentation**: Documentation changes are low-risk; can revert individual files

**Note**: Artifact naming convention changes are handled by task 199. Refer to task 199's rollback procedures if naming issues arise.

**Rollback Commands**:
```bash
# Restore from git if needed
git checkout HEAD -- .opencode/commands/fix.md  # Restore old /fix command
git checkout HEAD -- .opencode/skills/skill-fix/

# Remove new files if needed
rm .opencode/commands/fix-it.md
rm -rf .opencode/skills/skill-fix-it/
rm -rf .claude/skills/skill-tag/
rm -rf .claude/skills/skill-todo/
rm .claude/agents/atomic-task-numberer-agent.md
rm .claude/agents/git-workflow-manager-agent.md
rm .claude/agents/task-executor-agent.md
```

## Revision History

### Version 3 (Current)
- **Date**: 2026-03-13
- **Changes**:
  - Removed Phase 1 (artifact naming convention standardization)
  - Added dependency on task OC_199 for naming convention work
  - Renumbered phases (Phase 2→1, 3→2, 4→3, 5→4, 6→5, 7→6)
  - Reduced effort estimate from 12 to 10 hours (removed 2 hours for naming work)
  - Updated Goals to reference task 199
  - Updated Non-Goals to exclude artifact naming work
  - Updated Overview with task 199 dependency note
  - Removed artifact naming-related artifacts from output list
  - Updated rollback section to reference task 199
  - Updated testing section to remove artifact naming verifications

### Version 2
- **Date**: 2026-03-13
- **Status**: Superseded by Version 3
- **Changes**:
  - Integrated research-002 findings
  - Removed Phase 3 (port /convert) - extensions already synchronized
  - Added Phase 4 (port skill-todo) - newly identified gap
  - Renamed Phase 2 to explicitly cover `/fix` → `/fix-it` rename
  - Updated effort estimate from 14 to 12 hours
  - Added detailed task breakdown for rename operations
  - Added verification steps for no remaining `/fix` references
  - Updated risk assessment for rename operation

### Version 1
- **Date**: Original plan creation
- **Status**: Superseded by Version 2

## Post-Implementation

After completing all phases:
1. Update `specs/TODO.md` to mark task as completed
2. Update `specs/state.json` with completion summary
3. Run `/todo` to archive completed task
4. Notify user of completed improvements
5. Archive implementation-002.md (keep for reference)
6. Coordinate with task 199 to ensure naming convention work is complete
