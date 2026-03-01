# Implementation Plan: Task #99

- **Task**: 99 - review_agent_systems_core_extensions
- **Status**: [NOT STARTED]
- **Effort**: 12-16 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Design and implement a core + extensions architecture for the .claude/ agent system. The research identified 22 general-purpose features present in ProofChecker and Theory but missing from nvim, plus a need for an extension registry that allows domain-specific feature packs (Lean, LaTeX, Logic, etc.) to be loaded on demand. The end state is that any .claude/ system can be expressed as "core + activated extensions", managed through `<leader>ac` in Neovim.

### Research Integration

The research report (`research-001.md`) compared three .claude/ systems and categorized all differences into core infrastructure (Category A), domain extensions (Category B), and project-specific items (Category C). This plan addresses all Category A items across 6 phases, and creates the extension framework for Category B items.

## Goals & Non-Goals

**Goals**:
- Add all 22 identified missing core context files to nvim/.claude/
- Create an extension manifest schema and registry system
- Implement symlink-based extension activation/deactivation
- Create a Neovim extension pack (extracting current neovim-specific components)
- Create a Lean extension pack template (demonstrating the pattern)
- Integrate extension management with `<leader>ac` keybinding
- Maintain full backward compatibility with existing nvim/.claude/ workflows

**Non-Goals**:
- Migrating ProofChecker or Theory to use the new extension system (separate task)
- Creating all possible extension packs (only Neovim and Lean as examples)
- Building a GUI or web interface for extension management
- Implementing automatic extension auto-detection based on project files (future enhancement)
- Rewriting existing commands or skills (only adding missing infrastructure)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Symlink complexity causes tool failures | High | Medium | Validate all symlinks with a verification script; test activation/deactivation cycle before finalizing |
| Extension dependency cycles block activation | Medium | Low | Enforce DAG ordering in registry; validate at activation time with topological sort |
| Adding 22 context files bloats agent context loading | Medium | Medium | Add files to index.json with proper load_when filters; agents only load what they need |
| Extension switching breaks active tasks | High | Medium | Warn when deactivating extension with active tasks in that language |
| index.json becomes stale after extension toggle | High | High | Auto-regenerate index.json on every activation/deactivation via the management script |
| Backward compatibility broken during refactoring | High | Low | Phase 1 is purely additive; extraction into extensions happens in later phases with validation |

## Implementation Phases

### Phase 1: Core Reference Documentation [NOT STARTED]

**Goal**: Add the 6 high-priority reference documentation files identified as missing from nvim core context. These are pure additions that improve agent effectiveness without changing any existing behavior.

**Tasks**:
- [ ] Create `context/core/reference/command-reference.md` - Full command reference with all flags and modes (adapt from ProofChecker)
- [ ] Create `context/core/reference/state-json-schema.md` - Complete state.json schema documentation
- [ ] Create `context/core/reference/error-recovery-procedures.md` - Detailed recovery procedures for all error types
- [ ] Create `context/core/reference/skill-agent-mapping.md` - Skill-to-agent mapping quick reference
- [ ] Create `context/core/reference/artifact-templates.md` - Template collection for all artifact types
- [ ] Create `context/core/formats/metadata-quick-ref.md` - Condensed metadata schema reference
- [ ] Update `context/index.json` with entries for all 6 new files

**Timing**: 2 hours

**Files to create/modify**:
- `.claude/context/core/reference/command-reference.md` - new file
- `.claude/context/core/reference/state-json-schema.md` - new file
- `.claude/context/core/reference/error-recovery-procedures.md` - new file
- `.claude/context/core/reference/skill-agent-mapping.md` - new file
- `.claude/context/core/reference/artifact-templates.md` - new file
- `.claude/context/core/formats/metadata-quick-ref.md` - new file
- `.claude/context/index.json` - update with new entries

**Verification**:
- All 6 files exist and contain substantive content adapted from ProofChecker
- Each file is registered in index.json with appropriate load_when conditions
- Existing agent behavior is unchanged (no regressions)

---

### Phase 2: Progress, Recovery, and Utility Infrastructure [NOT STARTED]

**Goal**: Add the 12 remaining missing core context files covering progress tracking, recovery infrastructure, utility improvements, and MCP resilience patterns.

**Tasks**:
- [ ] Create `context/core/formats/progress-file.md` - Phase-level progress tracking format
- [ ] Create `context/core/formats/handoff-artifact.md` - Context exhaustion recovery via handoff documents
- [ ] Create `context/core/formats/debug-report-format.md` - Debug hypothesis-analysis-resolution cycle format
- [ ] Create `context/core/formats/changelog-format.md` - CHANGE_LOG.md structure for permanent work history
- [ ] Create `context/core/utils/index-query.md` - Programmatic index.json query patterns with jq
- [ ] Create `context/core/standards/git-staging-scope.md` - Per-agent git staging scopes
- [ ] Create `context/core/templates/context-knowledge-template.md` - Knowledge extraction template for research
- [ ] Create `context/core/patterns/mcp-tool-recovery.md` - Defensive MCP tool failure recovery patterns
- [ ] Create `context/core/patterns/blocked-mcp-tools.md` - Blocked MCP tool reference template
- [ ] Create `context/core/patterns/roadmap-reflection-pattern.md` - Prevents recommending documented dead ends
- [ ] Port `scripts/generate-context-index.sh` from ProofChecker
- [ ] Port `scripts/update-plan-status.sh` from ProofChecker
- [ ] Update `context/index.json` with entries for all new context files

**Timing**: 2-3 hours

**Files to create/modify**:
- `.claude/context/core/formats/progress-file.md` - new file
- `.claude/context/core/formats/handoff-artifact.md` - new file
- `.claude/context/core/formats/debug-report-format.md` - new file
- `.claude/context/core/formats/changelog-format.md` - new file
- `.claude/context/core/utils/index-query.md` - new file
- `.claude/context/core/standards/git-staging-scope.md` - new file
- `.claude/context/core/templates/context-knowledge-template.md` - new file
- `.claude/context/core/patterns/mcp-tool-recovery.md` - new file
- `.claude/context/core/patterns/blocked-mcp-tools.md` - new file
- `.claude/context/core/patterns/roadmap-reflection-pattern.md` - new file
- `.claude/scripts/generate-context-index.sh` - new file (ported)
- `.claude/scripts/update-plan-status.sh` - new file (ported)
- `.claude/context/index.json` - update with new entries

**Verification**:
- All 10 context files exist with substantive content
- Both scripts are executable and produce correct output
- index.json validates successfully with `validate-context-index.sh`

---

### Phase 3: Team Orchestration Skills [NOT STARTED]

**Goal**: Port the 3 team orchestration skills from ProofChecker and their supporting context files. These enable multi-agent parallel execution and are general-purpose infrastructure.

**Tasks**:
- [ ] Create `skills/skill-team-research/SKILL.md` - Parallel multi-agent research orchestration
- [ ] Create `skills/skill-team-plan/SKILL.md` - Parallel multi-agent planning orchestration
- [ ] Create `skills/skill-team-implement/SKILL.md` - Parallel multi-agent implementation with debug cycles
- [ ] Create `context/core/formats/team-metadata-extension.md` - Team result schema for multi-agent coordination
- [ ] Create `context/core/patterns/team-orchestration.md` - Wave-based multi-agent coordination patterns
- [ ] Update `context/index.json` with team context file entries
- [ ] Update CLAUDE.md Skill-to-Agent Mapping table with team skills

**Timing**: 2-3 hours

**Files to create/modify**:
- `.claude/skills/skill-team-research/SKILL.md` - new file
- `.claude/skills/skill-team-plan/SKILL.md` - new file
- `.claude/skills/skill-team-implement/SKILL.md` - new file
- `.claude/context/core/formats/team-metadata-extension.md` - new file
- `.claude/context/core/patterns/team-orchestration.md` - new file
- `.claude/context/index.json` - update
- `.claude/CLAUDE.md` - update Skill-to-Agent Mapping table

**Verification**:
- All 3 skill directories exist with valid SKILL.md files
- Both context files contain substantive patterns
- CLAUDE.md Skill-to-Agent Mapping table includes team skills
- Skill files follow established SKILL.md format (frontmatter, description, execution flow)

---

### Phase 4: Extension Architecture Framework [NOT STARTED]

**Goal**: Create the extension registry system, manifest schema, and management script that enables domain-specific feature packs to be loaded on demand. This is the core architectural addition.

**Tasks**:
- [ ] Design and create `extensions/` directory structure
- [ ] Create `extensions/registry.json` - Extension registry with active/inactive status tracking
- [ ] Create `extensions/manifest-schema.json` - JSON schema for extension manifest validation
- [ ] Create `extensions/README.md` - Extension system documentation
- [ ] Create `scripts/manage-extensions.sh` - Shell script for activate, deactivate, list, validate operations
- [ ] Create `scripts/validate-extensions.sh` - Symlink and manifest validation
- [ ] Document extension lifecycle in `docs/guides/extension-management.md`

**Timing**: 2-3 hours

**Files to create/modify**:
- `.claude/extensions/registry.json` - new file
- `.claude/extensions/manifest-schema.json` - new file
- `.claude/extensions/README.md` - new file
- `.claude/scripts/manage-extensions.sh` - new file
- `.claude/scripts/validate-extensions.sh` - new file
- `.claude/docs/guides/extension-management.md` - new file

**Verification**:
- `manage-extensions.sh` correctly lists, activates, and deactivates extensions
- `validate-extensions.sh` detects broken symlinks and invalid manifests
- Registry tracks extension state correctly across activate/deactivate cycles
- Running activate followed by deactivate leaves the system in its original state

---

### Phase 5: Create Extension Packs [NOT STARTED]

**Goal**: Create the Neovim extension pack (extracting existing domain-specific components) and a Lean extension pack template. These serve as reference implementations for the extension system.

**Tasks**:
- [ ] Create `extensions/neovim/manifest.json` - Neovim extension manifest
- [ ] Populate Neovim extension with references to existing domain components:
  - Skills: `skill-neovim-research`, `skill-neovim-implementation`
  - Agents: `neovim-research-agent`, `neovim-implementation-agent`
  - Rules: `neovim-lua.md`
  - Context: `context/project/neovim/`
- [ ] Create `extensions/lean/manifest.json` - Lean extension manifest (template)
- [ ] Populate Lean extension template with component definitions:
  - Commands: `/lake`, `/lean`
  - Skills: `skill-lean-research`, `skill-lean-implementation`, `skill-lake-repair`, `skill-lean-version`
  - Agents: `lean-research-agent`, `lean-implementation-agent`
  - Rules: `lean4.md`
  - Context: `context/project/lean4/`
  - Scripts: `setup-lean-mcp.sh`, `verify-lean-mcp.sh`
- [ ] Create `extensions/latex/manifest.json` - LaTeX extension manifest
- [ ] Create `extensions/typst/manifest.json` - Typst extension manifest
- [ ] Test activate/deactivate cycle with Neovim extension pack
- [ ] Mark Neovim extension as active by default in registry

**Timing**: 2 hours

**Files to create/modify**:
- `.claude/extensions/neovim/manifest.json` - new file
- `.claude/extensions/lean/manifest.json` - new file (template)
- `.claude/extensions/latex/manifest.json` - new file
- `.claude/extensions/typst/manifest.json` - new file

**Verification**:
- All 4 manifest files pass schema validation
- Neovim extension activates and all symlinks resolve correctly
- Lean extension manifest correctly declares all components from ProofChecker
- Deactivating and reactivating Neovim extension leaves system functional

---

### Phase 6: Neovim Integration and CLAUDE.md Updates [NOT STARTED]

**Goal**: Integrate extension management with the `<leader>ac` keybinding in Neovim and update CLAUDE.md to document the new architecture.

**Tasks**:
- [ ] Create or update Neovim Lua module for `<leader>ac` to include extension management submenu
- [ ] Implement Telescope picker (or vim.ui.select fallback) for extension listing
- [ ] Add toggle action to activate/deactivate extensions from the picker
- [ ] Add extension status display (active/inactive, dependency info)
- [ ] Update `.claude/CLAUDE.md` with:
  - Extension architecture section
  - Extension management commands
  - Updated directory structure showing extensions/
- [ ] Update root `CLAUDE.md` with extension architecture overview
- [ ] Run full validation suite to confirm no regressions

**Timing**: 2 hours

**Files to create/modify**:
- `nvim/lua/neotex/plugins/claude-extensions.lua` or similar - new/modified Lua module
- `.claude/CLAUDE.md` - update with extension documentation
- `CLAUDE.md` (root) - update with extension overview

**Verification**:
- `<leader>ac` opens a picker showing available extensions
- Toggling an extension from the picker runs activate/deactivate correctly
- Extension status is visible in the picker (active/inactive markers)
- CLAUDE.md accurately reflects the new architecture
- All existing commands and workflows continue to function

## Testing & Validation

- [ ] All 22 missing core context files exist and contain substantive content
- [ ] index.json passes validation with all new entries
- [ ] Team orchestration skills follow established SKILL.md format
- [ ] Extension registry correctly tracks active/inactive state
- [ ] Extension activate/deactivate cycle is idempotent (activate-deactivate-activate leaves correct state)
- [ ] Broken symlinks are detected and reported by validation script
- [ ] `<leader>ac` extension picker renders correctly in Neovim
- [ ] No regressions in existing command workflows
- [ ] ProofChecker system can be expressed as "core + lean + logic + math" extensions (design validation)

## Artifacts & Outputs

- 22 new core context files in `.claude/context/core/`
- 3 team orchestration skills in `.claude/skills/`
- 2 utility scripts in `.claude/scripts/`
- Extension framework: registry, schema, management scripts in `.claude/extensions/` and `.claude/scripts/`
- 4 extension pack manifests (neovim, lean, latex, typst)
- 1 Neovim Lua module for extension management
- Updated CLAUDE.md documentation
- Implementation summary at `specs/099_review_agent_systems_core_extensions/summaries/implementation-summary-YYYYMMDD.md`

## Rollback/Contingency

All changes in Phases 1-3 are purely additive (new files only). They can be reverted by deleting the new files and reverting index.json changes.

Phase 4-5 introduces the extension framework as a new directory. Rollback involves removing `.claude/extensions/` and the management scripts. No existing files are modified until Phase 6.

Phase 6 modifies CLAUDE.md and adds Neovim integration. Rollback uses `git checkout` on modified files and removal of new Lua modules.

If the extension architecture proves too complex, a simpler alternative is to maintain separate CLAUDE.md profiles and switch between them, rather than using the symlink-based extension system.
