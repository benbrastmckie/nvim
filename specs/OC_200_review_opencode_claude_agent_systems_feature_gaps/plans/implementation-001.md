# Implementation Plan: Review .opencode/ and .claude/ Agent Systems for Feature Gaps and Improvements

- **Task**: OC_200 - review_opencode_claude_agent_systems_feature_gaps
- **Status**: [NOT STARTED]
- **Effort**: 14 hours
- **Dependencies**: None
- **Research Inputs**: specs/OC_200_review_opencode_claude_agent_systems_feature_gaps/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan addresses the comprehensive feature gap analysis between the .opencode/ and .claude/ agent systems. The implementation focuses on standardizing naming conventions, porting missing features, and improving documentation across both systems to ensure a consistent user experience and reduce maintenance overhead.

### Research Integration

This plan integrates findings from research-001.md which identified:
- **Critical naming inconsistency**: .opencode uses `research-{NNN}.md` vs .claude's `MM_{short-slug}.md`
- **6 unique .opencode commands**: Including /convert, /learn, /tag, /lake, /lean, /fix
- **Advanced /fix-it in .claude**: More feature-complete than .opencode's basic /fix
- **3 missing agent types in .claude**: atomic-task-numberer, git-workflow-manager, task-executor
- **Documentation gaps**: Poor extension development guides, no context index schema docs

## Goals & Non-Goals

**Goals**:
- Standardize artifact naming conventions between both systems
- Achieve feature parity for /fix-it command between systems
- Port high-value commands (/convert) from .opencode to .claude/
- Improve documentation completeness and consistency
- Add missing agent types to .claude/ system
- Document extension merge process and context index format

**Non-Goals**:
- Full consolidation of both systems into one (out of scope)
- Removing or deprecating either system
- Changing MCP server configurations (document only)
- Refactoring working code for style consistency only

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Naming convention changes break existing tooling | High | Medium | Create migration guide; maintain backward compatibility during transition |
| skill-fix replacement causes command failures | Medium | Medium | Test /fix command thoroughly before deployment; keep backup of working version |
| Agent type additions introduce bugs | Medium | Low | Test new agents in isolated environment; verify agent metadata files |
| Documentation changes become outdated | Low | High | Include documentation review in future task templates |
| Phase dependencies cause delays | Medium | Low | Build in buffer time; parallelize independent phases where possible |

## Implementation Phases

### Phase 1: Artifact Naming Convention Standardization [NOT STARTED]

**Goal**: Align .opencode/ artifact naming with .claude/ convention (`MM_{short-slug}.md`)

**Tasks**:
- [ ] Update `.opencode/rules/artifact-formats.md` to use .claude naming pattern
- [ ] Update `.opencode/skills/skill-researcher/SKILL.md` to reference new naming convention
- [ ] Update `.opencode/skills/skill-planner/SKILL.md` with correct artifact paths
- [ ] Update `.opencode/AGENTS.md` task artifact documentation
- [ ] Search for other files referencing `research-{NNN}.md` pattern and update them
- [ ] Create migration notes in `.opencode/docs/migrations/artifact-naming-v2.md`

**Timing**: 2 hours

**Files to modify**:
- `.opencode/rules/artifact-formats.md` - Update naming convention documentation
- `.opencode/skills/skill-researcher/SKILL.md` - Update artifact path references
- `.opencode/skills/skill-planner/SKILL.md` - Update plan file naming
- `.opencode/AGENTS.md` - Update task artifact documentation

**Verification**:
- Grep for old naming pattern (`research-\d+`) returns no results in .opencode/
- All skill files reference consistent naming convention
- Migration guide exists and is accurate

---

### Phase 2: /fix-it Feature Parity [NOT STARTED]

**Goal**: Replace .opencode's basic skill-fix with advanced skill-fix-it pattern

**Tasks**:
- [ ] Copy `.claude/skills/skill-fix-it/SKILL.md` to `.opencode/skills/skill-fix-it/SKILL.md`
- [ ] Update `.opencode/commands/fix.md` to call skill-fix-it instead of skill-fix
- [ ] Review skill-fix-it for any .claude-specific references and update for .opencode/
- [ ] Test /fix command to ensure it works with new skill
- [ ] Update `.opencode/AGENTS.md` skill-to-agent mapping table
- [ ] Mark old `.opencode/skills/skill-fix/` as deprecated (add DEPRECATED.md note)

**Timing**: 1.5 hours

**Files to modify**:
- `.opencode/skills/skill-fix-it/SKILL.md` - Create new (copied from .claude/)
- `.opencode/commands/fix.md` - Update to use skill-fix-it
- `.opencode/skills/skill-fix/DEPRECATED.md` - Mark as deprecated
- `.opencode/AGENTS.md` - Update skill mapping

**Verification**:
- `/fix` command runs without errors
- skill-fix-it properly groups tags by topic
- QUESTION: tag type is supported
- Old skill-fix directory has deprecation notice

---

### Phase 3: Port /convert Command to .claude/ [NOT STARTED]

**Goal**: Enable file format conversion in .claude/ system

**Tasks**:
- [ ] Review `.opencode/extensions/filetypes/commands/convert.md` for completeness
- [ ] Copy command file to `.claude/extensions/filetypes/commands/convert.md`
- [ ] Review and update any .opencode-specific paths or references
- [ ] Add /convert command documentation to `.claude/CLAUDE.md` command reference
- [ ] Test /convert command with sample files (PDF, DOCX)
- [ ] Update `.claude/extensions/filetypes/manifest.json` if needed

**Timing**: 1.5 hours

**Files to create/modify**:
- `.claude/extensions/filetypes/commands/convert.md` - Create new command
- `.claude/CLAUDE.md` - Add to command reference table
- `.claude/extensions/filetypes/manifest.json` - Update if command registration needed

**Verification**:
- `/convert` command appears in .claude/ help
- Command successfully converts test files
- Documentation is accurate and complete

---

### Phase 4: Add skill-tag to .claude/ System [NOT STARTED]

**Goal**: Enable semantic versioning tag creation in .claude/

**Tasks**:
- [ ] Copy `.opencode/skills/skill-tag/SKILL.md` to `.claude/skills/skill-tag/SKILL.md`
- [ ] Review for .opencode-specific references and update for .claude/
- [ ] Create `.claude/commands/tag.md` command file
- [ ] Add skill-tag to `.claude/CLAUDE.md` skill-to-agent mapping
- [ ] Update `.claude/README.md` with /tag command documentation
- [ ] Mark skill-tag as "user-only" in documentation

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

---

### Phase 5: Port Missing Agent Types to .claude/ [NOT STARTED]

**Goal**: Add atomic-task-numberer, git-workflow-manager, and task-executor agents to .claude/

**Tasks**:
- [ ] Copy `.opencode/agent/subagents/atomic-task-numberer.md` to `.claude/agents/atomic-task-numberer-agent.md`
- [ ] Copy `.opencode/agent/subagents/git-workflow-manager.md` to `.claude/agents/git-workflow-manager-agent.md`
- [ ] Copy `.opencode/agent/subagents/task-executor.md` to `.claude/agents/task-executor-agent.md`
- [ ] Update agent frontmatter to match .claude/ conventions
- [ ] Update any .opencode-specific references in agent files
- [ ] Add new agents to `.claude/CLAUDE.md` agent documentation

**Timing**: 2 hours

**Files to create**:
- `.claude/agents/atomic-task-numberer-agent.md` - Port from .opencode/
- `.claude/agents/git-workflow-manager-agent.md` - Port from .opencode/
- `.claude/agents/task-executor-agent.md` - Port from .opencode/

**Verification**:
- All 3 agent files exist in .claude/agents/
- Agent frontmatter follows .claude/ conventions
- Agents are documented in CLAUDE.md

---

### Phase 6: Documentation Improvements [NOT STARTED]

**Goal**: Create missing documentation and improve existing documentation

**Tasks**:
- [ ] Create `.claude/context/README.md` with index.json schema documentation
- [ ] Document context index query patterns and examples
- [ ] Create `.claude/context/core/guides/extension-development.md` guide
- [ ] Document extension merge process and merge_targets
- [ ] Update `.opencode/AGENTS.md` to add skill-tag documentation
- [ ] Create `.claude/agents/README.md` documenting agent structure
- [ ] Update `.opencode/agent/subagents/README.md` if needed

**Timing**: 3 hours

**Files to create/modify**:
- `.claude/context/README.md` - New documentation file
- `.claude/context/core/guides/extension-development.md` - New guide
- `.opencode/AGENTS.md` - Add skill-tag to skill table
- `.claude/agents/README.md` - Create agent documentation

**Verification**:
- All new documentation files exist and are non-empty
- index.json schema is documented with examples
- Extension merge process is explained clearly
- skill-tag appears in .opencode/AGENTS.md skill table

---

### Phase 7: System Validation and Testing [NOT STARTED]

**Goal**: Verify all changes work correctly across both systems

**Tasks**:
- [ ] Run `/fix` command in .opencode/ to verify skill-fix-it integration
- [ ] Test /convert command in .claude/ with sample files
- [ ] Test /tag command in .claude/ (dry-run mode)
- [ ] Verify all new agent files load without errors
- [ ] Check that naming conventions are consistent across all modified files
- [ ] Create summary report of all changes made
- [ ] Update `.claude/CHANGELOG.md` with change summary

**Timing**: 2.5 hours

**Verification**:
- All commands execute without errors
- All new agent files are properly formatted
- Documentation is accurate and complete
- No broken references or links

## Testing & Validation

- [ ] `/fix` command in .opencode/ uses skill-fix-it pattern
- [ ] `/convert` command available and functional in .claude/
- [ ] `/tag` command available in .claude/ system
- [ ] All 3 new agent types present in .claude/agents/
- [ ] Artifact naming convention consistent across both systems
- [ ] Documentation complete and accurate
- [ ] No broken internal references
- [ ] All modified skills have valid SKILL.md files

## Artifacts & Outputs

- `specs/OC_200_review_opencode_claude_agent_systems_feature_gaps/plans/implementation-001.md` (this file)
- Updated `.opencode/rules/artifact-formats.md` with standardized naming
- New `.opencode/skills/skill-fix-it/SKILL.md` (ported from .claude/)
- New `.claude/extensions/filetypes/commands/convert.md`
- New `.claude/skills/skill-tag/SKILL.md`
- New `.claude/commands/tag.md`
- New `.claude/agents/atomic-task-numberer-agent.md`
- New `.claude/agents/git-workflow-manager-agent.md`
- New `.claude/agents/task-executor-agent.md`
- New `.claude/context/README.md` with index.json schema
- New `.claude/context/core/guides/extension-development.md`
- New `.claude/agents/README.md`
- Updated `.opencode/AGENTS.md` with skill-tag documentation
- Updated `.claude/CLAUDE.md` with new commands and agents
- Migration guide at `.opencode/docs/migrations/artifact-naming-v2.md`

## Rollback/Contingency

If any phase fails or causes issues:

1. **Artifact Naming**: Can revert by restoring original `.opencode/rules/artifact-formats.md`; naming convention is documentation-only change
2. **skill-fix Replacement**: Keep backup of original skill-fix skill; can restore by reverting `.opencode/commands/fix.md` to use old skill
3. **New Commands**: Simply delete created files if not working; no dependencies
4. **New Agents**: Delete agent files if issues found; agents are additive only
5. **Documentation**: Documentation changes are low-risk; can revert individual files

**Rollback Command**:
```bash
# Restore from git if needed
git checkout HEAD -- .opencode/rules/artifact-formats.md
git checkout HEAD -- .opencode/commands/fix.md
```

## Post-Implementation

After completing all phases:
1. Update `specs/TODO.md` to mark task as completed
2. Update `specs/state.json` with completion summary
3. Run `/todo` to archive completed task
4. Notify user of completed improvements
