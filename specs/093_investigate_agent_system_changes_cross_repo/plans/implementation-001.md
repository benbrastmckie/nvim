# Implementation Plan: Task #93

- **Task**: 93 - investigate_agent_system_changes_cross_repo
- **Status**: [NOT STARTED]
- **Effort**: 17-26 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Date**: 2026-02-24

## Overview

This plan implements five prioritized features identified from the ProofChecker and Logos/Theory agent systems. The implementation is organized to maximize standalone value per phase, with optional Team Mode as a separate phase due to its experimental flag requirement. Context Index Schema (P2) provides high value without experimental features and is positioned early. Smaller features (P3, P4, P5) are grouped for efficiency.

### Research Integration

Key findings from research-001.md:
- Team Mode requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` environment variable
- Context Index Schema enables jq-based context discovery without hardcoded file lists
- Model enforcement is low-effort with clear rationale (Opus for complex reasoning)
- Blocked tool documentation prevents agents from using buggy MCP tools
- Domain research agent enhancements improve context gap detection

## Goals & Non-Goals

**Goals**:
- Convert context index from markdown to machine-readable JSON with schema
- Enable dynamic context discovery via jq queries
- Add model field to agent frontmatter for explicit model selection
- Document blocked MCP tools centrally and in relevant agents
- Enhance research agents with context extension recommendations
- Optionally implement Team Mode for parallel agent execution

**Non-Goals**:
- Implementing Lean-specific features (lake-repair skill)
- Migrating to different orchestration architecture
- Changing existing command interfaces
- Requiring Team Mode for standard operations (graceful degradation required)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Team Mode experimental flag may break in future Claude versions | High | Medium | Implement graceful degradation; make team skills optional |
| Context index.json maintenance overhead | Medium | Medium | Create validation script; integrate with pre-commit hooks |
| Model field changes if Claude model names evolve | Low | Medium | Use abstract names (opus, sonnet) not specific versions |
| Blocked tool list becomes stale | Low | Medium | Include last-verified date; periodic review in /review |

## Implementation Phases

### Phase 1: Context Index Schema Foundation [NOT STARTED]

**Goal**: Convert index.md to machine-readable index.json with JSON Schema for automated context discovery.

**Tasks**:
- [ ] Create JSON Schema definition at `.claude/context/index.schema.json`
- [ ] Design entry structure: path, domain, subdomain, topics, keywords, summary
- [ ] Add agent-aware loading: `load_when.agents[]` field
- [ ] Add budget-aware loading: `line_count` field
- [ ] Convert existing index.md entries to index.json format
- [ ] Validate all paths in index.json exist

**Timing**: 4-6 hours

**Files to modify**:
- `.claude/context/index.schema.json` - Create (JSON Schema definition)
- `.claude/context/index.json` - Create (populated index)
- `.claude/context/index.md` - Preserve for reference (add deprecation note)

**Verification**:
- JSON validates against schema
- All paths in index.json resolve to existing files
- `jq` queries return expected results for sample queries:
  - Query by domain: `jq '.entries[] | select(.domain == "neovim")' index.json`
  - Query by agent: `jq '.entries[] | select(.load_when.agents[] == "neovim-research-agent")' index.json`

---

### Phase 2: Agent Context Discovery Integration [NOT STARTED]

**Goal**: Update agents to use index.json for dynamic context discovery instead of hardcoded file lists.

**Tasks**:
- [ ] Create jq query patterns document at `.claude/context/core/patterns/context-discovery.md`
- [ ] Update neovim-research-agent to use index.json queries
- [ ] Update general-research-agent to use index.json queries
- [ ] Update planner-agent with context discovery examples
- [ ] Test context loading with sample queries

**Timing**: 2-3 hours

**Files to modify**:
- `.claude/context/core/patterns/context-discovery.md` - Create (jq patterns)
- `.claude/agents/neovim-research-agent.md` - Update context loading section
- `.claude/agents/general-research-agent.md` - Update context loading section
- `.claude/agents/planner-agent.md` - Add context discovery reference

**Verification**:
- Agents can discover relevant context files via index.json
- No hardcoded file lists remain in updated agents
- Context loading respects budget constraints (line_count field)

---

### Phase 3: Model Enforcement and Blocked Tools [NOT STARTED]

**Goal**: Add model field to agent frontmatter and document blocked MCP tools.

**Tasks**:
- [ ] Add `model:` field to agent frontmatter specification
- [ ] Update agents that benefit from specific models (research agents -> opus)
- [ ] Create `.claude/context/core/patterns/blocked-mcp-tools.md` with central reference
- [ ] Add "BLOCKED TOOLS" section to agents using MCP tools
- [ ] Document model selection rationale in agent comments

**Timing**: 2-4 hours

**Files to modify**:
- `.claude/docs/reference/standards/agent-frontmatter-standard.md` - Update (add model field)
- `.claude/agents/neovim-research-agent.md` - Add model field
- `.claude/agents/general-research-agent.md` - Add model field
- `.claude/context/core/patterns/blocked-mcp-tools.md` - Create
- `.claude/CLAUDE.md` - Add model enforcement section (if not present)

**Verification**:
- Agent frontmatter includes valid model field
- Blocked tools document exists with clear table format
- All agents using MCP tools have BLOCKED TOOLS section if applicable

---

### Phase 4: Research Agent Enhancements [NOT STARTED]

**Goal**: Enhance research agents with context extension recommendations and automatic context gap detection.

**Tasks**:
- [ ] Add "Context Extension Recommendations" section template to research report format
- [ ] Update neovim-research-agent with context gap detection logic
- [ ] Add optional task creation for identified context gaps (disabled for meta tasks)
- [ ] Update research report template in artifact-formats.md
- [ ] Test context gap detection with sample research scenario

**Timing**: 2-4 hours

**Files to modify**:
- `.claude/rules/artifact-formats.md` - Add Context Extension Recommendations section
- `.claude/agents/neovim-research-agent.md` - Add context gap detection
- `.claude/agents/general-research-agent.md` - Add context gap detection
- `.claude/context/core/formats/research-report-format.md` - Update template

**Verification**:
- Research reports include Context Extension Recommendations section
- Context gaps are identified based on missing documentation patterns
- Task creation for gaps is disabled for meta tasks

---

### Phase 5: Team Mode Skills (Optional) [NOT STARTED]

**Goal**: Implement team-based parallel execution with wave-based orchestration.

**Note**: This phase requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` environment variable and uses approximately 5x tokens compared to single-agent execution. Skip this phase if experimental features are not acceptable.

**Tasks**:
- [ ] Create team orchestration pattern document `.claude/context/core/patterns/team-orchestration.md`
- [ ] Create team metadata extension format `.claude/context/core/formats/team-metadata-extension.md`
- [ ] Create team wave helpers `.claude/utils/team-wave-helpers.md`
- [ ] Implement `skill-team-research` with 2-4 research teammates
- [ ] Implement `skill-team-plan` with 2-3 planning teammates
- [ ] Implement `skill-team-implement` with parallel phase execution
- [ ] Add `--team` flag to `/research`, `/plan`, `/implement` commands
- [ ] Implement graceful degradation when teams unavailable

**Timing**: 8-12 hours

**Files to create**:
- `.claude/context/core/patterns/team-orchestration.md` - Wave coordination patterns
- `.claude/context/core/formats/team-metadata-extension.md` - Team result schema
- `.claude/utils/team-wave-helpers.md` - Reusable wave patterns
- `.claude/skills/skill-team-research/SKILL.md` - Team research skill
- `.claude/skills/skill-team-plan/SKILL.md` - Team planning skill
- `.claude/skills/skill-team-implement/SKILL.md` - Team implementation skill

**Files to modify**:
- `.claude/commands/research.md` - Add --team flag
- `.claude/commands/plan.md` - Add --team flag
- `.claude/commands/implement.md` - Add --team flag
- `.claude/CLAUDE.md` - Add Skill-to-Agent mappings for team skills

**Verification**:
- Team skills spawn teammates correctly with experimental flag enabled
- Wave-based execution completes research/plan/implement cycles
- Graceful degradation to single-agent when teams unavailable
- Conflict detection works during synthesis phase
- Run-scoped artifact naming prevents collisions

---

### Phase 6: Documentation and Validation [NOT STARTED]

**Goal**: Update documentation and create validation scripts for new features.

**Tasks**:
- [ ] Update CLAUDE.md with new features summary
- [ ] Create index.json validation script
- [ ] Add validation to pre-commit hooks (optional)
- [ ] Update README.md files in affected directories
- [ ] Create migration guide for index.md -> index.json

**Timing**: 1-2 hours

**Files to modify**:
- `.claude/CLAUDE.md` - Update with new features
- `.claude/scripts/validate-context-index.sh` - Create
- `.claude/docs/guides/development/context-index-migration.md` - Create
- `.claude/README.md` - Update if needed

**Verification**:
- CLAUDE.md accurately reflects new capabilities
- Validation script catches invalid index.json entries
- Migration guide is clear and actionable

## Testing & Validation

- [ ] JSON Schema validates index.json
- [ ] All index.json paths resolve to existing files
- [ ] jq queries return expected results
- [ ] Agents successfully discover context via index.json
- [ ] Model field is recognized in agent frontmatter
- [ ] Blocked tools documentation is accessible
- [ ] Research reports include context extension recommendations
- [ ] (If Phase 5) Team skills execute with experimental flag
- [ ] (If Phase 5) Graceful degradation works without flag

## Artifacts & Outputs

- `.claude/context/index.schema.json` - JSON Schema for context index
- `.claude/context/index.json` - Machine-readable context index
- `.claude/context/core/patterns/context-discovery.md` - jq query patterns
- `.claude/context/core/patterns/blocked-mcp-tools.md` - Blocked tool reference
- `.claude/scripts/validate-context-index.sh` - Validation script
- `.claude/docs/guides/development/context-index-migration.md` - Migration guide
- (Phase 5) Team skills and supporting documentation
- `specs/093_investigate_agent_system_changes_cross_repo/summaries/implementation-summary-YYYYMMDD.md` - Final summary

## Rollback/Contingency

### Per-Phase Rollback

**Phase 1-2**: Remove index.json and index.schema.json; restore index.md as primary
**Phase 3**: Remove model field from frontmatter; remove blocked-mcp-tools.md
**Phase 4**: Remove Context Extension Recommendations section from templates
**Phase 5**: Remove team skills entirely; commands work without --team flag
**Phase 6**: Restore previous CLAUDE.md; remove validation script

### Full Rollback

If significant issues arise:
1. Revert all .claude/ changes via git
2. Keep index.md as-is
3. Document issues in error report for future attempt

### Partial Implementation

Phases 1-4 can be implemented independently of Phase 5 (Team Mode).
Phase 5 is explicitly optional and can be deferred or skipped entirely.
