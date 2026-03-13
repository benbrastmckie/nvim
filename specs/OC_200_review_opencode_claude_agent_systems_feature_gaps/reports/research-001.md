# Research Report: Task #OC_200

**Task**: OC_200 - Review .opencode/ and .claude/ agent systems for feature gaps and improvements
**Started**: 2026-03-13T11:45:00Z
**Completed**: 2026-03-13T12:30:00Z
**Effort**: 4 hours
**Dependencies**: None
**Sources/Inputs**: Codebase exploration, manifest comparison, documentation audit
**Artifacts**: - path to this report
**Standards**: report-format.md

---

## Executive Summary

This comprehensive review compared the `.opencode/` and `.claude/` agent systems side-by-side to identify feature gaps, documentation inconsistencies, and improvement opportunities. Both systems share a common architectural foundation but have diverged in several important ways.

### Key Findings:
1. **Feature Gaps**: 6 commands/features exist in .opencode but not in .claude
2. **Naming Inconsistencies**: Artifact naming conventions differ between systems  
3. **Documentation Gaps**: Some advanced features are poorly documented
4. **Agent Structure**: Different approaches to agent organization
5. **Extension System**: Merge targets differ between systems
6. **MCP Server Configuration**: Different MCP servers and configurations

### Recommended Priority:
- **High**: Align artifact naming conventions, sync /fix-it features
- **Medium**: Port /convert command to .claude, document skill-tag
- **Low**: Consolidate agent directory structures

---

## System Comparison

### 1. Directory Structure Comparison

| Component | .opencode/ | .claude/ | Status |
|-----------|-----------|----------|--------|
| **Root README** | README.md (285 lines) | README.md (1055 lines) | .claude more detailed |
| **Quick Reference** | AGENTS.md (165 lines) | CLAUDE.md (241 lines) | Both present |
| **Commands/** | 12 commands | 11 commands | .opencode has +1 |
| **Skills/** | 13 skills | 9 skills | .opencode has +4 |
| **Agents/** | agent/orchestrator.md + subagents/ | agents/*.md (4 files) | Different structure |
| **Rules/** | 6 rules | 5 rules | .opencode has +1 |
| **Scripts/** | 18 scripts | 16 scripts | .opencode has +2 |
| **Context/** | context/ with index.json | context/ with index.json | Identical |
| **Extensions/** | 13 extensions | 13 extensions | Identical |

### 2. Command Comparison

#### Commands Unique to .opencode/:

| Command | Description | Priority to Port |
|---------|-------------|------------------|
| `/convert` | File format conversion (PDF/DOCX to Markdown, etc.) | High |
| `/fix` | Scan for FIX:/NOTE:/TODO: tags (basic version) | Deprecated (use /fix-it) |
| `/learn` | Add memories to vault with interactive confirmation | Medium |
| `/tag` | Semantic version tagging for CI/CD | Medium |
| `/lake` | Lean 4 build with auto-repair | Extension-specific |
| `/lean` | Lean toolchain management | Extension-specific |

#### Commands Unique to .claude/:

| Command | Description | Notes |
|---------|-------------|-------|
| `/fix-it` | Advanced tag scanning with topic grouping | More advanced than .opencode's /fix |

#### Command Differences:

| Command | .opencode Version | .claude Version | Difference |
|---------|------------------|-----------------|------------|
| `/fix` vs `/fix-it` | Basic tag scanning | Advanced with topic grouping, QUESTION: support | .claude more advanced |

### 3. Skill Comparison

#### Skills in .opencode/ only:

| Skill | Purpose | Recommendation |
|-------|---------|----------------|
| skill-tag | Semantic versioning tags | Port to .claude/ for web extension |
| skill-learn | Memory vault integration | Consider for .claude/ |
| skill-fix | Basic tag scanning | Deprecated, use skill-fix-it |
| skill-todo | Direct execution | Already exists in .claude |

#### Skills in .claude/ only:

| Skill | Purpose | Notes |
|-------|---------|-------|
| skill-fix-it | Advanced tag scanning | More feature-complete |

### 4. Agent Structure Differences

#### .opencode/ Approach:
```
agent/
├── orchestrator.md          # Thin wrapper pattern
├── README.md
└── subagents/
    ├── atomic-task-numberer.md
    ├── general-implementation-agent.md
    ├── general-research-agent.md
    ├── git-workflow-manager.md
    ├── meta-builder-agent.md
    ├── planner-agent.md
    ├── README.md
    └── task-executor.md
```

#### .claude/ Approach:
```
agents/
├── general-implementation-agent.md
├── general-research-agent.md
├── meta-builder-agent.md
└── planner-agent.md
```

**Gap**: .claude/ is missing:
- `atomic-task-numberer-agent` (exists in .opencode/agent/subagents/)
- `git-workflow-manager-agent` (exists in .opencode/agent/subagents/)
- `task-executor-agent` (exists in .opencode/agent/subagents/)

### 5. Artifact Naming Convention Gap

**Critical Inconsistency**:

| System | Research Report | Implementation Plan | Summary |
|--------|-----------------|---------------------|---------|
| .opencode/ | `research-{NNN}.md` | `implementation-{NNN}.md` | `implementation-summary-{DATE}.md` |
| .claude/ | `MM_{short-slug}.md` | `MM_{short-slug}.md` | `MM_{short-slug}-summary.md` |

**Example**:
- .opencode: `specs/OC_200_review_opencode/reports/research-200.md`
- .claude: `specs/OC_200_review_opencode/reports/01_review-findings.md`

**Impact**: This inconsistency causes confusion when working across both systems and breaks tooling that expects consistent paths.

### 6. Extension Manifest Differences

#### Merge Targets Comparison:

| Extension | .opencode/ merge_targets | .claude/ merge_targets |
|-----------|--------------------------|------------------------|
| All | `opencode_md` -> `.opencode/AGENTS.md` | `claudemd` -> `.claude/CLAUDE.md` |
| Settings | `settings` -> `.opencode/settings.local.json` | `settings` -> `.claude/settings.local.json` |
| Index | `index` -> `.opencode/context/index.json` | `index` -> `.claude/context/index.json` |
| Unique | None | `opencode_json` -> `opencode.json` |

**Gap**: .claude/ extensions generate `opencode.json` files that don't exist in .opencode/ system.

### 7. Settings and MCP Server Gaps

#### MCP Servers in .opencode/ only:

| Server | Purpose | Recommendation |
|--------|---------|----------------|
| mcp__astro-docs__* | Astro framework documentation | Port if web extension used |
| mcp__context7__* | Context7 knowledge base | Consider for .claude/ |
| mcp__playwright__* | Browser automation | Port if web testing needed |

#### MCP Servers in .claude/ only:

| Server | Purpose | Notes |
|--------|---------|-------|
| @anthropic-ai/obsidian-claude-code-mcp | Different memory server | Uses different port (22360 vs 27124) |

### 8. Documentation Quality Gaps

#### .opencode/ Documentation Strengths:
- Better organized command documentation
- Clear skill-to-agent mapping tables
- Extension registration process well documented

#### .claude/ Documentation Strengths:
- More comprehensive architecture documentation (README.md: 1055 lines)
- Better explanation of forked subagent pattern
- Detailed delegation safety documentation
- Model enforcement documentation

#### Documentation Gaps:

1. **skill-tag**: Not documented in CLAUDE.md skill-to-agent mapping
2. **Multi-task creation standard**: Exists in .claude/ but not referenced in .opencode/
3. **Context index format**: No documentation on index.json schema in either system
4. **Extension merge process**: Poorly documented in both systems

### 9. Rules Comparison

| Rule | .opencode/ | .claude/ | Gap |
|------|-----------|----------|-----|
| artifact-formats.md | 3282 bytes | 6202 bytes | .claude more detailed |
| error-handling.md | 3538 bytes | 4803 bytes | .claude more detailed |
| git-workflow.md | 3915 bytes | 3785 bytes | Comparable |
| state-management.md | 8744 bytes | 10402 bytes | .claude more detailed |
| workflows.md | 6176 bytes | 6044 bytes | Comparable |
| README.md | 636 bytes | N/A | .opencode only |

### 10. Hooks Comparison

#### Hooks in .opencode/ only:
None - all hooks exist in both systems.

#### Hooks Comparison:
Both systems have identical hooks:
- `log-session.sh`
- `post-command.sh`
- `subagent-postflight.sh`
- `tts-notify.sh`
- `validate-state-sync.sh`
- `wezterm-clear-status.sh`
- `wezterm-clear-task-number.sh`
- `wezterm-notify.sh`
- `wezterm-task-number.sh`

---

## Feature Gap Analysis

### High Priority Gaps

#### 1. Artifact Naming Convention Inconsistency
**Location**: Both systems
**Gap**: Different naming patterns for research reports and plans
**Impact**: Tooling confusion, broken workflows
**Recommendation**: Standardize on .claude/ convention (`MM_{short-slug}.md`)

#### 2. Missing /convert Command in .claude/
**Location**: `.claude/commands/`
**Gap**: File format conversion not available
**Impact**: Cannot convert PDF/DOCX to Markdown in .claude/ system
**Recommendation**: Port `/convert` command from filetypes extension

#### 3. skill-fix vs skill-fix-it Divergence
**Location**: `.opencode/skills/skill-fix/` vs `.claude/skills/skill-fix-it/`
**Gap**: .opencode/ has older version without topic grouping
**Impact**: Inconsistent user experience
**Recommendation**: Update .opencode/ to use skill-fix-it pattern

### Medium Priority Gaps

#### 4. Missing skill-tag in .claude/
**Location**: `.claude/skills/`
**Gap**: Semantic versioning tag creation not available
**Impact**: Web projects can't use /tag command
**Recommendation**: Port skill-tag for web extension users

#### 5. Missing /learn Command in .claude/
**Location**: `.claude/commands/`
**Gap**: Memory vault integration not available
**Impact**: Knowledge capture workflow unavailable
**Recommendation**: Port /learn and skill-memory integration

#### 6. Agent Directory Structure Divergence
**Location**: `agent/` vs `agents/`
**Gap**: Different organizational patterns
**Impact**: Maintenance overhead, confusion
**Recommendation**: Consider consolidating to single pattern

### Low Priority Gaps

#### 7. Missing opencode.json Generation in .opencode/
**Location**: Extension manifests
**Gap**: .claude/ extensions generate opencode.json files
**Impact**: Unknown purpose of these files
**Recommendation**: Investigate if opencode.json is needed

#### 8. Documentation Inconsistencies
**Location**: README.md files
**Gap**: Different levels of detail
**Impact**: User confusion
**Recommendation**: Create common documentation templates

---

## Improvement Recommendations

### Priority 1: Critical (Immediate Action)

1. **Standardize Artifact Naming**
   - File: `.opencode/rules/artifact-formats.md`
   - Change: Update to use `MM_{short-slug}.md` format
   - Impact: Aligns with .claude/ system

2. **Port /convert Command**
   - Source: `.opencode/extensions/filetypes/commands/convert.md`
   - Target: `.claude/extensions/filetypes/commands/convert.md`
   - Impact: Enables file conversion in .claude/ system

3. **Replace skill-fix with skill-fix-it in .opencode/**
   - Action: Remove skill-fix, add skill-fix-it
   - Update: `/fix` command to call skill-fix-it
   - Impact: Consistent tag scanning experience

### Priority 2: Important (Next Sprint)

4. **Add skill-tag to .claude/**
   - Source: `.opencode/skills/skill-tag/`
   - Target: `.claude/skills/skill-tag/`
   - Impact: Enables semantic versioning in .claude/

5. **Document skill-tag in AGENTS.md**
   - File: `.opencode/AGENTS.md`
   - Add: skill-tag to skill-to-agent mapping table
   - Note: Mark as "user-only"

6. **Add Context Index Documentation**
   - Create: `.claude/context/README.md`
   - Document: index.json schema, query patterns
   - Impact: Better developer experience

### Priority 3: Nice to Have (Future)

7. **Consolidate Agent Directory Structure**
   - Option A: Move .opencode/ to `agents/` pattern
   - Option B: Document why different patterns exist
   - Impact: Reduced maintenance overhead

8. **Create Common Extension Template**
   - File: `.claude/docs/templates/extension-template.md`
   - Include: manifest.json, EXTENSION.md, index-entries.json
   - Impact: Easier extension creation

9. **Document Extension Merge Process**
   - Create: `.claude/docs/guides/extension-merge-process.md`
   - Document: How merge_targets work
   - Impact: Better contributor experience

---

## Specific File Locations for Improvements

### Files to Modify:

| File | Change | Priority |
|------|--------|----------|
| `.opencode/rules/artifact-formats.md` | Update naming convention | High |
| `.opencode/AGENTS.md` | Add skill-tag documentation | High |
| `.claude/extensions/filetypes/commands/convert.md` | Create new | High |
| `.opencode/skills/skill-fix/` | Replace with skill-fix-it | High |
| `.claude/skills/skill-tag/SKILL.md` | Create new | Medium |
| `.claude/commands/tag.md` | Create new | Medium |
| `.claude/context/README.md` | Create documentation | Medium |
| `.opencode/agent/subagents/README.md` | Document structure | Low |
| `.claude/agents/README.md` | Create documentation | Low |

---

## Risk Assessment

### Low Risk Changes:
- Documentation updates
- Adding skill-tag to .claude/
- Creating README files

### Medium Risk Changes:
- Updating artifact naming conventions (may break existing tooling)
- Replacing skill-fix with skill-fix-it

### High Risk Changes:
- Consolidating agent directory structures (breaking change)

### Mitigation Strategies:
1. Create migration guide for artifact naming changes
2. Maintain backward compatibility for skill-fix during transition
3. Test all commands after changes

---

## Context Extension Recommendations

Based on research, the following context documentation gaps were identified:

1. **Context Index Schema**: No documentation on index.json format
2. **Extension Development Guide**: No guide for creating new extensions
3. **Agent Architecture Patterns**: Missing documentation on thin wrapper vs full agent patterns
4. **MCP Server Integration**: No guide for adding MCP servers
5. **Testing Guidelines**: No documentation on testing skills and commands

**Recommendation**: Create context files for each of these topics in `.claude/context/core/guides/`.

---

## Appendix: Detailed File Comparison

### skill-researcher Differences:
```diff
# Artifact path conventions
-.opencode: specs/OC_{NNN}_{SLUG}/reports/research-{NNN}.md
+.claude: specs/OC_{NNN}_{SLUG}/reports/MM_{short-slug}.md

# Temp file locations
-.opencode: /tmp/state.json
+.claude: specs/tmp/state.json
```

### Extension Manifest merge_targets:
```diff
# .opencode uses:
- "opencode_md": { "target": ".opencode/AGENTS.md" }

# .claude uses:
+ "claudemd": { "target": ".claude/CLAUDE.md" }
+ "opencode_json": { "target": "opencode.json" }
```

### Settings MCP Servers:
```diff
# .opencode has:
- "mcp__astro-docs__*"
- "mcp__context7__*"
- "mcp__playwright__*"

# .claude has:
+ "model": "sonnet"
```

---

## Next Steps

1. **Immediate**: Create task for artifact naming standardization
2. **This Week**: Port /convert command to .claude/
3. **Next Sprint**: Consolidate skill-fix implementations
4. **Future**: Consider full system consolidation

---

**Report Prepared By**: general-research-agent
**Review Status**: Complete
**Confidence Level**: High (based on comprehensive file analysis)
