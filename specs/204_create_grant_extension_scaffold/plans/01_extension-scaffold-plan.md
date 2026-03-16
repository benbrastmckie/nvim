# Implementation Plan: Task #204

- **Task**: 204 - Create grant extension scaffold with manifest.json
- **Status**: [COMPLETED]
- **Effort**: 2-3 hours
- **Dependencies**: None
- **Research Inputs**: [01_extension-scaffold-patterns.md](../reports/01_extension-scaffold-patterns.md), [02_grant-best-practices.md](../reports/02_grant-best-practices.md)
- **Artifacts**: plans/01_extension-scaffold-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Create the grant/ extension directory structure following established extension patterns from nvim, lean, and filetypes extensions. The scaffold includes manifest.json with full extension metadata, EXTENSION.md for CLAUDE.md injection, index-entries.json for context discovery, and placeholder directories for future agent, skill, command, and context files. This foundation enables downstream tasks (205-208) to add specific components.

### Research Integration

Integrated patterns from 01_extension-scaffold-patterns.md:
- Canonical extension directory structure with 9 standard components
- manifest.json schema with required fields (name, version, description, language, dependencies, provides, merge_targets, mcp_servers)
- index-entries.json entry schema with load_when conditions
- EXTENSION.md standard sections and formatting

Integrated requirements from 02_grant-best-practices.md:
- Context structure supporting progressive loading stages (research, drafting, review)
- Template priorities: budget and impact statement templates highest priority
- Funder-specific guide pattern for modular funder support

## Goals & Non-Goals

**Goals**:
- Create complete grant/ extension directory structure matching existing extension patterns
- Implement manifest.json with all required fields and correct provides arrays
- Create EXTENSION.md with language routing and skill-agent mapping tables
- Create index-entries.json with initial README entry and proper load_when conditions
- Create placeholder files for downstream task dependencies

**Non-Goals**:
- Implementing the grant-agent (Task #205)
- Implementing skill-grant (Task #206)
- Implementing /grant command (Task #207)
- Creating detailed grant writing context files (Task #208)
- MCP server integration (not needed for grant extension)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Directory structure diverges from other extensions | Downstream tasks fail to integrate | Low | Use nvim extension as reference, verify structure matches |
| manifest.json schema incomplete | Extension loader fails | Medium | Validate against lean manifest.json with all optional fields |
| index-entries.json path format wrong | Context discovery fails | Medium | Use canonical project/* paths, test with jq query |
| EXTENSION.md format incompatible | CLAUDE.md injection fails | Low | Follow exact section pattern from nvim/EXTENSION.md |

## Implementation Phases

### Phase 1: Create Directory Structure [COMPLETED]

**Goal**: Establish the complete extension directory hierarchy with all required subdirectories.

**Tasks**:
- [ ] Create `.claude/extensions/grant/` root directory
- [ ] Create subdirectories: agents/, skills/skill-grant/, commands/, context/project/grant/
- [ ] Create context subdirectories: domain/, patterns/, templates/, tools/, standards/
- [ ] Create placeholder .gitkeep files where needed for empty directories

**Timing**: 15 minutes

**Files to create**:
- `.claude/extensions/grant/` (directory)
- `.claude/extensions/grant/agents/` (directory)
- `.claude/extensions/grant/skills/skill-grant/` (directory)
- `.claude/extensions/grant/commands/` (directory)
- `.claude/extensions/grant/context/project/grant/` (directory tree)

**Verification**:
- Directory structure matches canonical pattern from research report
- All required subdirectories exist

---

### Phase 2: Create manifest.json [COMPLETED]

**Goal**: Create the extension metadata file with all required fields and correct structure.

**Tasks**:
- [ ] Create manifest.json with name "grant", version "1.0.0"
- [ ] Set language to "grant" for routing
- [ ] Configure provides arrays for planned components (agents, skills, commands, context)
- [ ] Configure merge_targets for claudemd, index, and opencode_json
- [ ] Set empty mcp_servers object (no MCP requirements)

**Timing**: 20 minutes

**Files to create**:
- `.claude/extensions/grant/manifest.json`

**Verification**:
- JSON is valid (parse with jq)
- All required fields present (name, version, description, language, dependencies, provides, merge_targets, mcp_servers)
- provides.context references "project/grant"
- merge_targets.claudemd.section_id is "extension_grant"

---

### Phase 3: Create EXTENSION.md [COMPLETED]

**Goal**: Create the markdown content that will be injected into CLAUDE.md when extension is loaded.

**Tasks**:
- [ ] Create EXTENSION.md with "## Grant Extension" header
- [ ] Add brief extension description
- [ ] Create Language Routing table with grant language entry
- [ ] Create Skill-Agent Mapping table with skill-grant entry
- [ ] Add Context Imports section with placeholder paths

**Timing**: 20 minutes

**Files to create**:
- `.claude/extensions/grant/EXTENSION.md`

**Verification**:
- Markdown structure matches nvim/EXTENSION.md pattern
- Tables are properly formatted
- Context import paths use @-reference syntax

---

### Phase 4: Create index-entries.json [COMPLETED]

**Goal**: Create initial context index entries for grant extension discovery.

**Tasks**:
- [ ] Create index-entries.json with entries array
- [ ] Add entry for project/grant/README.md with proper metadata
- [ ] Set load_when conditions for languages, agents, and commands
- [ ] Use canonical path format (project/grant/*, not .claude/context/project/grant/*)

**Timing**: 15 minutes

**Files to create**:
- `.claude/extensions/grant/index-entries.json`

**Verification**:
- JSON is valid (parse with jq)
- Paths use canonical format without .claude/context/ prefix
- load_when includes grant language and grant-agent

---

### Phase 5: Create opencode-agents.json [COMPLETED]

**Goal**: Create OpenCode agent configuration for cross-system support.

**Tasks**:
- [ ] Create opencode-agents.json following nvim extension pattern
- [ ] Define grant-agent entry with required fields
- [ ] Include system prompt and model settings

**Timing**: 15 minutes

**Files to create**:
- `.claude/extensions/grant/opencode-agents.json`

**Verification**:
- JSON is valid
- Agent name matches planned grant-agent from manifest.json provides

---

### Phase 6: Create Placeholder Files [COMPLETED]

**Goal**: Create minimal placeholder files for downstream tasks to build upon.

**Tasks**:
- [ ] Create context/project/grant/README.md with domain overview
- [ ] Create agents/.gitkeep (agent file created in Task #205)
- [ ] Create skills/skill-grant/SKILL.md placeholder with frontmatter
- [ ] Create commands/.gitkeep (command file created in Task #207)

**Timing**: 30 minutes

**Files to create**:
- `.claude/extensions/grant/context/project/grant/README.md`
- `.claude/extensions/grant/skills/skill-grant/SKILL.md` (placeholder)

**Verification**:
- README.md provides useful domain overview based on research
- SKILL.md has valid frontmatter with name and description
- Files establish foundation for downstream tasks

---

### Phase 7: Verify Extension Structure [COMPLETED]

**Goal**: Validate the complete extension scaffold matches established patterns.

**Tasks**:
- [ ] Verify all required files exist
- [ ] Validate JSON files parse correctly
- [ ] Compare structure against nvim extension
- [ ] Document any deviations with justification

**Timing**: 15 minutes

**Verification**:
- `ls -la .claude/extensions/grant/` shows all expected files
- `jq '.' manifest.json` succeeds
- `jq '.' index-entries.json` succeeds
- `jq '.' opencode-agents.json` succeeds

---

## Testing & Validation

- [ ] All JSON files parse without errors: `jq '.' <file>`
- [ ] Directory structure matches canonical pattern from research
- [ ] manifest.json contains all required fields
- [ ] index-entries.json paths use canonical format
- [ ] EXTENSION.md follows standard section structure
- [ ] Extension can be listed with extension loader (if available)

## Artifacts & Outputs

- `.claude/extensions/grant/manifest.json` - Extension metadata
- `.claude/extensions/grant/EXTENSION.md` - CLAUDE.md injection content
- `.claude/extensions/grant/index-entries.json` - Context index entries
- `.claude/extensions/grant/opencode-agents.json` - OpenCode agent config
- `.claude/extensions/grant/context/project/grant/README.md` - Domain overview
- `.claude/extensions/grant/skills/skill-grant/SKILL.md` - Skill placeholder
- `specs/204_create_grant_extension_scaffold/summaries/01_extension-scaffold-summary.md` - Implementation summary

## Rollback/Contingency

If extension structure is incorrect or causes loader issues:
1. Remove entire `.claude/extensions/grant/` directory
2. Review error messages from extension loader
3. Compare against working extension (nvim) for structure differences
4. Recreate with corrections

No other system files are modified by this task, so rollback is complete directory removal.
