# Implementation Plan: Task #219

- **Task**: 219 - incorporate_proofchecker_docs_and_patterns
- **Status**: [COMPLETE]
- **Effort**: 3-4 hours
- **Dependencies**: None
- **Research Inputs**: [01_proofchecker-integration.md](../reports/01_proofchecker-integration.md)
- **Artifacts**: plans/02_implementation-plan.md (this file)
- **Standards**:
  - .claude/context/core/formats/plan-format.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta

## Overview

This plan incorporates missing documentation, patterns, format schemas, and commands from ProofChecker's `.claude/` system into the nvim agent system. The goal is to make the nvim system more complete and portable across both GitHub and GitLab repositories. Key additions include: state-json-schema.md, skill-agent-mapping.md, mcp-tool-recovery.md (generalized), handoff-artifact.md, progress-file.md, blocked-mcp-tools.md (lean extension), and a unified /merge command with platform auto-detection.

### Research Integration

The research report identified 6 key documentation files to port from ProofChecker:
- blocked-mcp-tools.md (lean-specific, goes to extension)
- state-json-schema.md (comprehensive schema reference)
- mcp-tool-recovery.md (MCP AbortError recovery patterns)
- handoff-artifact.md (context exhaustion handoff schema)
- progress-file.md (phase progress tracking schema)
- /merge command (GitLab-only in source, needs GitHub support)

Additionally, skill-agent-mapping.md will be created as a new reference document based on CLAUDE.md tables.

## Goals & Non-Goals

**Goals**:
- Create `context/core/reference/` directory for schema documentation
- Port and adapt state-json-schema.md with nvim-appropriate generalizations
- Create skill-agent-mapping.md reference document
- Port mcp-tool-recovery.md with generalized patterns (Lean-specific fallbacks to extension)
- Port handoff-artifact.md and progress-file.md for team mode support
- Add blocked-mcp-tools.md to lean extension context
- Create unified /merge command with GitHub/GitLab auto-detection
- Update index.json with all new context entries

**Non-Goals**:
- Porting early-metadata-pattern.md (already exists in nvim)
- Modifying existing context files beyond index.json updates
- Adding Enterprise GitHub/GitLab URL patterns (out of scope for initial implementation)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| gh/glab CLI not installed | /merge fails | Medium | Check CLI availability and provide install instructions |
| Mixed remote URLs | Platform detection fails | Low | Use origin by default, document --remote flag for future |
| index.json schema mismatch | Validation errors | Low | Review existing nvim index.json structure before adding |
| Lean extension not loaded | blocked-mcp-tools.md unreachable | Low | Place in extension context; document in extension manifest |

## Implementation Phases

### Phase 1: Create Directory Structure [COMPLETED]

**Goal**: Establish the new `core/reference/` directory for schema documentation

**Tasks**:
- [ ] Create `context/core/reference/` directory
- [ ] Create README.md for the new directory explaining its purpose

**Timing**: 5 minutes

**Files to modify**:
- `.claude/context/core/reference/` - New directory
- `.claude/context/core/reference/README.md` - Purpose documentation

**Verification**:
- Directory exists at `.claude/context/core/reference/`
- README.md explains the directory contains schema and reference documentation

---

### Phase 2: Port Schema Documentation [COMPLETED]

**Goal**: Create state-json-schema.md and skill-agent-mapping.md reference documents

**Tasks**:
- [ ] Read ProofChecker's state-json-schema.md for structure reference
- [ ] Create state-json-schema.md with generalizations:
  - Remove ProofChecker-specific repository_health fields (sorry_count, axiom_count, build_errors)
  - Generalize language enum (remove "lean", keep "general", "meta", "markdown", add extension placeholder)
  - Keep all status values, artifact schema, completion fields
  - Update examples to use nvim-appropriate slugs
- [ ] Create skill-agent-mapping.md based on CLAUDE.md tables:
  - Core skill-to-agent mappings
  - Extension skill loading mechanism
  - Agent model preferences
  - Team mode skill routing

**Timing**: 45 minutes

**Files to modify**:
- `.claude/context/core/reference/state-json-schema.md` - Complete state.json schema reference (~120 lines)
- `.claude/context/core/reference/skill-agent-mapping.md` - Skill routing reference (~80 lines)

**Verification**:
- Both files contain complete field specifications
- Examples are nvim-appropriate (no Lean-specific references)
- Cross-references to state-management.md rule are present

---

### Phase 3: Port Pattern Documentation [COMPLETED]

**Goal**: Create generalized mcp-tool-recovery.md pattern

**Tasks**:
- [ ] Read ProofChecker's mcp-tool-recovery.md for structure
- [ ] Create generalized version in core/patterns/:
  - Keep error types and recovery strategy pattern
  - Keep logging format and state machine
  - Remove Lean-specific tool fallback table
  - Add placeholder for extension-specific fallbacks
- [ ] Create lean extension fallback table file at extensions/lean/context/project/lean4/patterns/mcp-fallback-table.md

**Timing**: 30 minutes

**Files to modify**:
- `.claude/context/core/patterns/mcp-tool-recovery.md` - Generalized MCP recovery (~150 lines)
- `.claude/extensions/lean/context/project/lean4/patterns/mcp-fallback-table.md` - Lean-specific fallbacks (~60 lines)

**Verification**:
- Core pattern has no Lean-specific content
- Lean extension file contains tool-specific fallback table
- Both files cross-reference each other

---

### Phase 4: Port Format Documentation [COMPLETED]

**Goal**: Create handoff-artifact.md and progress-file.md for team mode support

**Tasks**:
- [ ] Read ProofChecker's handoff-artifact.md
- [ ] Create handoff-artifact.md in core/formats/:
  - Keep generic handoff document template
  - Generalize examples (remove Lean-specific references)
  - Keep directory structure, section guidelines, integration patterns
  - Add reference to team-orchestration.md pattern
- [ ] Read ProofChecker's progress-file.md
- [ ] Create progress-file.md in core/formats/:
  - Keep schema and field specifications
  - Generalize examples
  - Keep lifecycle diagram and integration with handoff
  - Update related documentation paths

**Timing**: 30 minutes

**Files to modify**:
- `.claude/context/core/formats/handoff-artifact.md` - Handoff schema (~180 lines)
- `.claude/context/core/formats/progress-file.md` - Progress tracking schema (~230 lines)

**Verification**:
- Both files have no language-specific references
- Cross-references to team-orchestration.md are present
- Schema examples are complete

---

### Phase 5: Update Lean Extension [COMPLETED]

**Goal**: Add blocked-mcp-tools.md to lean extension context

**Tasks**:
- [ ] Create tools directory if needed at extensions/lean/context/project/lean4/tools/
- [ ] Read ProofChecker's blocked-mcp-tools.md
- [ ] Create blocked-mcp-tools.md adapted for extension structure:
  - Keep tool blocking information (lean_diagnostic_messages, lean_file_outline)
  - Update paths to use extension structure
  - Update unblocking procedure references
- [ ] Update extensions/lean/index-entries.json with new entries:
  - Add blocked-mcp-tools.md entry
  - Add mcp-fallback-table.md entry (from Phase 3)

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/lean/context/project/lean4/tools/blocked-mcp-tools.md` - Blocked tools reference (~66 lines)
- `.claude/extensions/lean/index-entries.json` - Add 2 new entries

**Verification**:
- blocked-mcp-tools.md exists in tools directory
- index-entries.json validates as JSON
- New entries have correct load_when fields

---

### Phase 6: Create /merge Command [COMPLETED]

**Goal**: Create unified /merge command with GitHub/GitLab auto-detection

**Tasks**:
- [ ] Create commands/merge.md with:
  - Platform detection algorithm (git remote URL parsing)
  - CLI availability check (gh/glab)
  - Unified flag interface with platform-specific mapping
  - Error handling for missing CLI tools
  - Draft mode and fill mode support
- [ ] Implement flag mapping table:
  | Unified Flag | gh pr create | glab mr create |
  |--------------|--------------|----------------|
  | `--draft` | `--draft` | `--draft` |
  | `--assignee USER` | `--assignee USER` | `--assignee USER` |
  | `--label LABEL` | `--label LABEL` | `--label LABEL` |
  | `--reviewer USER` | `--reviewer USER` | `--reviewer USER` |
  | `--fill` | `--fill` | `--fill --yes` |
  | `--target BRANCH` | `--base BRANCH` | `--target-branch BRANCH` |
  | `--title TITLE` | `--title TITLE` | `--title TITLE` |
  | `--body BODY` | `--body BODY` | `--description BODY` |

**Timing**: 60 minutes

**Files to modify**:
- `.claude/commands/merge.md` - Unified merge command (~350 lines)

**Verification**:
- Command detects GitHub vs GitLab correctly
- Both gh and glab CLI paths are tested
- Error messages guide users to install missing CLI tools
- Flag mapping table is documented in command

---

### Phase 7: Update index.json [COMPLETED]

**Goal**: Add all new context entries to index.json

**Tasks**:
- [ ] Read current index.json structure
- [ ] Add entries for new core context files:
  - core/reference/state-json-schema.md
  - core/reference/skill-agent-mapping.md
  - core/patterns/mcp-tool-recovery.md
  - core/formats/handoff-artifact.md
  - core/formats/progress-file.md
- [ ] Validate JSON syntax
- [ ] Verify line_count estimates are reasonable

**Timing**: 15 minutes

**Files to modify**:
- `.claude/context/index.json` - Add 5 new entries

**New entries schema**:
```json
{
  "path": "core/reference/state-json-schema.md",
  "domain": "core",
  "subdomain": "reference",
  "topics": ["state", "schema", "json"],
  "keywords": ["state.json", "schema", "projects", "status"],
  "summary": "Complete state.json schema reference with field specifications",
  "line_count": 120,
  "load_when": {
    "commands": ["/task", "/todo", "/implement", "/research"],
    "agents": ["meta-builder-agent"]
  }
}
```

**Verification**:
- index.json validates as JSON
- All 5 new entries present
- load_when fields target appropriate commands/agents
- Line counts are consistent with actual file lengths

---

## Testing & Validation

- [ ] All new files exist at specified paths
- [ ] All new files follow existing content patterns
- [ ] index.json validates without errors: `jq '.' .claude/context/index.json`
- [ ] Lean extension index-entries.json validates: `jq '.' .claude/extensions/lean/index-entries.json`
- [ ] /merge command loads without syntax errors
- [ ] New context files can be loaded via @-references
- [ ] No circular references in cross-links

## Artifacts & Outputs

- `.claude/context/core/reference/README.md`
- `.claude/context/core/reference/state-json-schema.md`
- `.claude/context/core/reference/skill-agent-mapping.md`
- `.claude/context/core/patterns/mcp-tool-recovery.md`
- `.claude/context/core/formats/handoff-artifact.md`
- `.claude/context/core/formats/progress-file.md`
- `.claude/extensions/lean/context/project/lean4/tools/blocked-mcp-tools.md`
- `.claude/extensions/lean/context/project/lean4/patterns/mcp-fallback-table.md`
- `.claude/extensions/lean/index-entries.json` (modified)
- `.claude/commands/merge.md`
- `.claude/context/index.json` (modified)

## Rollback/Contingency

If implementation fails:
1. All new files can be deleted without affecting existing functionality
2. index.json and index-entries.json changes can be reverted via git
3. The /merge command is optional - users can continue using gh/glab directly
4. Team mode features (handoff/progress) degrade gracefully if formats missing
