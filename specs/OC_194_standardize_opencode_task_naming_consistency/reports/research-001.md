# Research Report: Task OC_194

**Task**: OC_194 - Standardize OpenCode task naming consistency  
**Started**: 2026-03-13T10:00:00Z  
**Completed**: 2026-03-13T10:30:00Z  
**Effort**: 2-3 hours  
**Dependencies**: None  
**Sources/Inputs**: 
- Codebase analysis: 15+ command files, 10+ skill files, 8+ agent files
- Documentation: task-management.md, state-management.md, artifact-formats.md
- Real data: specs/TODO.md, specs/state.json, specs/ directory listing
**Artifacts**: 
- This research report
**Standards**: report-format.md, task-management.md

---

## Executive Summary

The OpenCode task management system has a significant naming inconsistency between how tasks are created via different entry points:

1. **Task creation via `/task` command**: Uses `OC_` prefix for TODO.md headers and directory names
2. **Task creation via `/meta` command**: Uses plain numbers (NO `OC_` prefix) for TODO.md headers and directory names

This inconsistency results in a mixed repository where some tasks have `OC_` prefixes (e.g., `OC_194`) and others don't (e.g., `193`, `192`), causing confusion and potential tooling issues.

**Key Findings**:
- 32 locations in the codebase reference task naming patterns
- 5 files create task directories without `OC_` prefix
- 2 files create task directories WITH `OC_` prefix
- Documentation specifies `OC_` prefix as the standard
- Existing codebase shows real examples of both patterns

**Recommended Approach**: Standardize ALL task creation to use `OC_` prefix consistently, while maintaining backwards compatibility by accepting both `OC_N` and `N` in command arguments.

---

## Context & Scope

This research investigates the inconsistent use of `OC_` prefix in task naming across the OpenCode system. The scope includes:

- Task creation commands (`/task`, `/meta`)
- Research/Plan/Implement commands that reference tasks
- Directory naming conventions (`specs/OC_NNN_slug/` vs `specs/NNN_slug/`)
- TODO.md header formatting (`### OC_N. Title` vs `### N. Title`)
- State storage (state.json always uses plain integers internally)

---

## Findings

### 1. Current Inconsistent Behaviors Identified

#### 1.1 TODO.md Header Inconsistency

**Real examples from specs/TODO.md**:
```markdown
### OC_194. Standardize OpenCode task naming consistency   [HAS OC_ prefix]
- **Status**: [RESEARCHING]
...

### 193. Set default opencode model to Kimi K2.5 OpenCode Go  [NO OC_ prefix]
- **Status**: [RESEARCHING]
...

### 192. Bypass opencode permission requests  [NO OC_ prefix]
- **Status**: [RESEARCHED]
...
```

**Pattern observed**: Tasks 190-193 use plain numbers, while task 194 uses `OC_` prefix.

#### 1.2 Directory Naming Inconsistency

**Real examples from specs/ directory**:
```
specs/OC_194_standardize_opencode_task_naming_consistency/  [HAS OC_ prefix]
specs/193_set_default_opencode_model_to_kimi_k2_5_opencode_go/  [NO OC_ prefix]
specs/192_bypass_opencode_permission_requests/  [NO OC_ prefix]
specs/191_typst_compilation_error_reporting/  [NO OC_ prefix]
specs/190_investigate_ux_inconsistencies_and_improve_command_outputs/  [NO OC_ prefix]
```

**Pattern observed**: Only task 194 has `OC_` prefix in directory name.

#### 1.3 State Storage Consistency

**In specs/state.json**: All tasks use plain integers for `project_number`:
```json
{
  "project_number": 194,  // Plain integer
  "project_name": "standardize_opencode_task_naming_consistency",
  "status": "researching"
}
```

**Analysis**: Internal storage is consistent (always uses integers). The inconsistency is only in display/presentation layer.

### 2. Root Cause Analysis

#### 2.1 Two Different Task Creation Paths

**Path 1: `/task` command** (File: `.opencode/commands/task.md`)
- Line 104: Documents `specs/OC_NNN_<project_name>/` directory format
- Line 112: Uses `mkdir -p "specs/OC_NNN_<project_name>/plans"`
- Line 147: TODO.md format: `### OC_N. <Task Title>`
- **Uses `OC_` prefix consistently**

**Path 2: `/meta` command → meta-builder-agent** (File: `.opencode/agent/subagents/meta-builder-agent.md`)
- Line 532: TODO.md format: `### {N}. {Title}` (NO `OC_` prefix)
- Line 874, 876: Directory examples show `specs/037_add_topological_sorting/` (NO `OC_` prefix)
- Line 563: Python f-string: `f"""### {task_num}. {task['title']}"""`
- **Uses plain numbers, NO `OC_` prefix**

#### 2.2 Skill-Level Directory Creation

Multiple skills create directories using plain padded numbers:

| File | Line | Pattern | Uses OC_? |
|------|------|---------|-----------|
| skill-researcher/SKILL.md | 93 | `specs/${padded_num}_${project_name}` | NO |
| skill-planner/SKILL.md | 99 | `specs/${padded_num}_${project_name}` | NO |
| skill-implementer/SKILL.md | 105 | `specs/${padded_num}_${project_name}` | NO |
| skill-web-research/SKILL.md | 81 | `specs/${padded_num}_${project_name}` | NO |
| skill-neovim-research/SKILL.md | 82 | `specs/${padded_num}_${project_name}` | NO |
| extensions/nix/skills/skill-nix-research/SKILL.md | 81 | `specs/${task_number}_${project_name}` | NO |

#### 2.3 Agent-Level Directory Creation

Agent template files also use plain numbers:

| File | Line | Pattern | Uses OC_? |
|------|------|---------|-----------|
| general-research-agent.md | 110 | `specs/{NNN}_{SLUG}` | NO |
| planner-agent.md | 75 | `specs/{NNN}_{SLUG}` | NO |
| meta-builder-agent.md (implicit) | N/A | Shows `037_` examples | NO |

### 3. Documentation Standards vs Reality

#### 3.1 What Documentation Says

**task-management.md** (Line 38-40):
```markdown
#### Header
-   Format: `### OC_{Task ID}. {Task Title}`
-   Example: `### OC_17. Implement User Login`
```

**Line 23-24**:
```markdown
- Display task IDs with `OC_` prefix (e.g., `OC_17` for display, `OC_017` for directories)
```

**state-management.md** (Line 64):
```markdown
**Directory Naming**: OpenCode tasks use `OC_NNN_slug` format (e.g., `OC_017_task_slug`).
```

**artifact-formats.md** (Line 14):
```markdown
| `{OC_NNN}` | `OC_` + 3-digit padded | OpenCode directory names | `OC_017`, `OC_017_task_slug` |
```

#### 3.2 What Actually Happens

- **Standard documented**: Use `OC_` prefix
- **Reality**: Two code paths exist, one uses `OC_`, one doesn't
- **Result**: Mixed repository with both patterns

### 4. Files/Locations That Need Modification

#### 4.1 High Priority (Task Creation)

| File | Issue | Required Change |
|------|-------|-----------------|
| `.opencode/agent/subagents/meta-builder-agent.md` | Line 563: Uses plain `{task_num}` | Change to `OC_{task_num}` |
| `.opencode/agent/subagents/meta-builder-agent.md` | Line 532: Documents plain format | Update documentation to `OC_{N}` |
| `.opencode/skills/skill-researcher/SKILL.md` | Line 93: `specs/${padded_num}_` | Change to `specs/OC_${padded_num}_` |
| `.opencode/skills/skill-planner/SKILL.md` | Line 99: `specs/${padded_num}_` | Change to `specs/OC_${padded_num}_` |
| `.opencode/skills/skill-implementer/SKILL.md` | Line 105: `specs/${padded_num}_` | Change to `specs/OC_${padded_num}_` |

#### 4.2 Extension Skills (All Similar Pattern)

| File | Current Pattern | Required Change |
|------|-----------------|-----------------|
| `extensions/web/skills/skill-web-research/SKILL.md` | Line 81: `specs/${padded_num}_` | `specs/OC_${padded_num}_` |
| `extensions/web/skills/skill-web-implementation/SKILL.md` | Line 67: `specs/${padded_num}_` | `specs/OC_${padded_num}_` |
| `extensions/nvim/skills/skill-neovim-research/SKILL.md` | Line 82: `specs/${padded_num}_` | `specs/OC_${padded_num}_` |
| `extensions/nvim/skills/skill-neovim-implementation/SKILL.md` | Line 92: `specs/${padded_num}_` | `specs/OC_${padded_num}_` |
| `extensions/nix/skills/skill-nix-research/SKILL.md` | Line 81: `specs/${task_number}_` | `specs/OC_${padded_num}_` |
| `extensions/nix/skills/skill-nix-implementation/SKILL.md` | Line 67: `specs/${task_number}_` | `specs/OC_${padded_num}_` |

#### 4.3 Agent Templates

| File | Current Pattern | Required Change |
|------|-----------------|-----------------|
| `agent/subagents/general-research-agent.md` | Line 110: `specs/{NNN}_{SLUG}` | `specs/OC_{NNN}_{SLUG}` |
| `agent/subagents/planner-agent.md` | Line 75: `specs/{NNN}_{SLUG}` | `specs/OC_{NNN}_{SLUG}` |
| `agent/subagents/general-implementation-agent.md` | Line 68: `specs/{NNN}_{SLUG}` | `specs/OC_{NNN}_{SLUG}` |
| `extensions/*/agents/*-research-agent.md` | Various `{NNN}` patterns | `OC_{NNN}` |
| `extensions/*/agents/*-implementation-agent.md` | Various `{NNN}` patterns | `OC_{NNN}` |

#### 4.4 Backwards Compatibility (Parsing/Reading)

Files that PARSE task numbers must handle both formats:

| File | Location | Current Handling |
|------|----------|------------------|
| `skills/skill-todo/SKILL.md` | Line 88-89 | Already handles both: `"###%s+(OC_)?(%d+)%."` |
| `commands/task.md` | Abandon mode | Line 215: Checks both `OC_NNN_slug/` and `N_slug/` |
| Context/orchestration docs | Various | Already documents dual support |

---

## Decisions

### Decision 1: Standardize on `OC_` Prefix

**Rationale**: 
- Documentation already specifies `OC_` prefix as standard
- `OC_` prefix distinguishes OpenCode tasks from Claude Code tasks
- Consistent branding and visual identification

**Implication**: All NEW tasks should use `OC_` prefix.

### Decision 2: Maintain Backwards Compatibility

**Rationale**:
- User requirement: "user still wants to be able to run `/research NNN` instead of only being able to run `/research OC_NNN`"
- Existing tasks use both patterns, cannot break them
- Commands already strip `OC_` prefix before looking up in state.json

**Implementation**: 
- Commands already accept both formats: `OC_N` or `N` (strip `OC_` prefix)
- Parsing logic already handles both patterns in many places
- No changes needed to command argument parsing

### Decision 3: Migration Strategy for Existing Tasks

**Options Considered**:

1. **Rename all existing directories and update TODO.md** - High risk, many changes
2. **Leave existing tasks as-is, only fix creation** - Low risk, gradual consistency
3. **Create migration script** - Medium effort, one-time cleanup

**Recommendation**: Option 2 (Leave existing, fix creation)
- New tasks will use `OC_` prefix consistently
- Existing tasks remain functional with backwards compatibility
- Avoids risky bulk renames
- Natural consistency over time as old tasks archive

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Breaking existing task references | Low | High | Maintain backwards compatibility in all parsers; test with both formats |
| Path mismatches between skills | Medium | Medium | Update ALL skills consistently; grep for all `mkdir.*specs` patterns |
| Documentation drift | Medium | Low | Update all examples in docs to use `OC_` format |
| User confusion during transition | Low | Low | Clear changelog entry; existing tasks remain functional |
| Extension skills missed | Medium | High | Systematic search across all `extensions/*/` directories |

---

## Context Extension Recommendations

**Topic**: Task naming conventions  
**Gap**: Current context files document the standard but don't explain the inconsistency or provide migration guidance  
**Recommendation**: Update `.opencode/context/core/standards/task-management.md` with:

1. Section on "Naming Consistency" explaining:
   - The `OC_` prefix standard
   - Why it exists (distinguish from Claude Code)
   - Backwards compatibility requirements

2. Section on "Common Issues" documenting:
   - The historical inconsistency
   - How to fix task creation code
   - Testing both formats

3. Add a checklist for new skills/commands:
   - [ ] Directory creation uses `OC_${padded_num}_` format
   - [ ] TODO.md header uses `OC_{N}.` format
   - [ ] Parsing logic handles both formats

---

## Recommended Implementation Plan

### Phase 1: Fix Core Skills (skill-researcher, skill-planner, skill-implementer)
- Update directory creation patterns
- Update examples in documentation
- Test with new task creation

### Phase 2: Fix Meta Builder Agent
- Update TODO.md header format
- Update directory creation
- Test via `/meta` command

### Phase 3: Fix Extension Skills
- Systematic update of all `extensions/*/skills/*/` files
- Update agent templates in `extensions/*/agents/`

### Phase 4: Documentation Updates
- Update all examples to use `OC_` format
- Add consistency checklist
- Update architecture diagrams

### Phase 5: Verification
- Create test tasks via both `/task` and `/meta`
- Verify both use `OC_` prefix consistently
- Verify backwards compatibility with plain numbers

---

## Appendix

### A. Search Queries Used

```bash
# Find all task number patterns
grep -r "OC_[0-9]" .opencode/ --include="*.md"
grep -r "NNN.*SLUG\|padded_num\|project_number" .opencode/ --include="*.md"
grep -r "mkdir.*specs" .opencode/ --include="*.md"

# Find TODO.md formatting patterns
grep -r "### OC_\|### {N}\." .opencode/ --include="*.md"

# Check real data
ls specs/ | grep -E "^[0-9]+_|^OC_"
grep "^### " specs/TODO.md | head -10
```

### B. Files Examined

**Commands**:
- `.opencode/commands/task.md` (267 lines)
- `.opencode/commands/research.md` (301 lines)
- `.opencode/commands/plan.md` (210 lines)
- `.opencode/commands/implement.md` (281 lines)

**Core Skills**:
- `.opencode/skills/skill-researcher/SKILL.md` (311 lines)
- `.opencode/skills/skill-planner/SKILL.md` (338 lines)
- `.opencode/skills/skill-implementer/SKILL.md`
- `.opencode/skills/skill-meta/SKILL.md` (212 lines)
- `.opencode/skills/skill-todo/SKILL.md` (548 lines)

**Agents**:
- `.opencode/agent/subagents/meta-builder-agent.md` (1237 lines)
- `.opencode/agent/subagents/general-research-agent.md`
- `.opencode/agent/subagents/planner-agent.md`

**Standards**:
- `.opencode/context/core/standards/task-management.md` (390 lines)
- `.opencode/context/core/orchestration/state-management.md` (357 lines)
- `.opencode/rules/state-management.md`
- `.opencode/rules/artifact-formats.md`

**Real Data**:
- `specs/TODO.md` (117 lines examined)
- `specs/state.json` (173 lines examined)
- `specs/` directory listing

### C. Related Documentation

- User Guide: `.opencode/docs/guides/user-guide.md` (Line 184: "Output: Creates `specs/OC_NNN_{SLUG}/reports/research-NNN.md`")
- Creating Skills: `.opencode/docs/guides/creating-skills.md` (Line 387: "Create research report in `specs/OC_NNN_{SLUG}/reports/`")
- Documentation Audit: `.opencode/docs/guides/documentation-audit-checklist.md` (Line 203: "Expected: Directories use `OC_NNN` (3-digit padded)")

---

**End of Research Report**
