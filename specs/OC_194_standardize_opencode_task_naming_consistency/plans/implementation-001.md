# Implementation Plan: Task OC_194

- **Task**: OC_194 - Standardize OpenCode task naming consistency
- **Status**: [COMPLETED]
- **Effort**: 3-4 hours
- **Dependencies**: None
- **Research Inputs**: specs/OC_194_standardize_opencode_task_naming_consistency/reports/research-001.md, research-002.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

---

## Overview

This implementation plan standardizes OpenCode task naming by ensuring all task creation paths use the `OC_` prefix consistently. The inconsistency was identified where tasks 192-193 used plain numbers (e.g., `192_slug/`, `### 192. Title`) while task 194 used the OC_ prefix (e.g., `OC_194_slug/`, `### OC_194. Title`).

The root cause is that different code paths (`/task` command, `/meta` command, and various skills) use different naming patterns. This plan updates all task creation paths to use `OC_` prefix consistently while maintaining backwards compatibility.

### Research Integration

Key findings from research reports:
- **32 locations** in the codebase reference task naming patterns
- **5+ files** create task directories without `OC_` prefix
- **2 files** create task directories WITH `OC_` prefix (the /task command and related)
- Documentation already specifies `OC_` prefix as the standard
- Existing backwards compatibility parsing already handles both formats (e.g., skill-todo/SKILL.md uses `"###%s+(OC_)?(%d+)%\."`)

---

## Goals & Non-Goals

**Goals**:
- Standardize ALL task creation paths to use `OC_` prefix for directories (`specs/OC_NNN_slug/`)
- Standardize ALL task creation paths to use `OC_` prefix for TODO.md headers (`### OC_N. Title`)
- Maintain backwards compatibility so commands accept both `OC_N` and `N` formats
- Update documentation and examples to reflect the standard
- Ensure extension skills follow the same pattern

**Non-Goals**:
- Renaming existing task directories (backwards compatibility maintained)
- Changing internal state.json storage (keeps plain integers)
- Modifying command argument parsing (already handles both formats)
- Breaking existing task references or links

---

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking existing task references | High | Low | Maintain backwards compatibility in all parsers; grep for `"(OC_)?` patterns to ensure dual support |
| Path mismatches between skills creating directories | Medium | Medium | Systematic update of ALL `mkdir.*specs` patterns; verification script to check consistency |
| Extension skills missed during update | Medium | High | Systematic glob search across all `extensions/*/` directories; create checklist |
| Meta-builder-agent TODO format regression | High | Low | Careful line-by-line review; specific test for `/meta` command |
| User confusion during transition | Low | Low | Clear changelog entry; existing tasks remain functional |

---

## Implementation Phases

### Phase 1: Fix Core Skills (.opencode/skills/) [COMPLETED]

**Goal**: Update the three core skills to use `OC_` prefix in directory creation

**Tasks**:
- [ ] Update `.opencode/skills/skill-researcher/SKILL.md`:
  - Line 93: Change `mkdir -p "specs/${padded_num}_${project_name}"` to `mkdir -p "specs/OC_${padded_num}_${project_name}"`
  - Line 163: Update metadata_file path from `specs/${padded_num}_` to use same pattern
  - Update delegation context example (line 127): Change `specs/{NNN}_{SLUG}` to `specs/OC_{NNN}_{SLUG}`
  - Update Stage 10 cleanup paths: Change all rm -f paths to `specs/OC_${padded_num}_`
  - Update all summary examples to show `OC_` format

- [ ] Update `.opencode/skills/skill-planner/SKILL.md`:
  - Line 99: Change `mkdir -p "specs/${padded_num}_${project_name}"` to `mkdir -p "specs/OC_${padded_num}_${project_name}"`
  - Line 170: Update metadata_file path
  - Update delegation context (line 133): Change `specs/{NNN}_{SLUG}` to `specs/OC_{NNN}_{SLUG}`
  - Update Stage 10 cleanup paths
  - Update all summary examples

- [ ] Update `.opencode/skills/skill-implementer/SKILL.md`:
  - Line 105: Change `mkdir -p "specs/${padded_num}_${project_name}"` to `mkdir -p "specs/OC_${padded_num}_${project_name}"`
  - Line 200: Update metadata_file path
  - Update delegation context (line 138-139): Change paths to use `OC_{NNN}_{SLUG}`
  - Update Stage 10 cleanup paths (lines 339-341)
  - Update all summary examples

**Timing**: 45 minutes

**Files to modify**:
- `.opencode/skills/skill-researcher/SKILL.md`
- `.opencode/skills/skill-planner/SKILL.md`
- `.opencode/skills/skill-implementer/SKILL.md`

**Verification**:
- [ ] Grep each file for `${padded_num}_` without `OC_` prefix - should return 0 results
- [ ] Verify examples show `OC_` format: `grep -n "OC_.*${padded_num}" SKILL.md`

---

### Phase 2: Fix Core Skills (.claude/skills/) [COMPLETED]

**Goal**: Mirror changes in .claude directory (if skills exist there)

**Tasks**:
- [ ] Update `.claude/skills/skill-researcher/SKILL.md` with same changes as Phase 1
- [ ] Update `.claude/skills/skill-planner/SKILL.md` with same changes as Phase 1
- [ ] Update `.claude/skills/skill-implementer/SKILL.md` with same changes as Phase 1

**Timing**: 30 minutes

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md`
- `.claude/skills/skill-planner/SKILL.md`
- `.claude/skills/skill-implementer/SKILL.md`

**Verification**:
- [ ] Run same grep verification as Phase 1
- [ ] Diff against .opencode versions to ensure consistency

---

### Phase 3: Fix Agent Templates (.opencode/agent/subagents/) [COMPLETED]

**Goal**: Update agent template files to use `OC_` prefix

**Tasks**:
- [ ] Update `.opencode/agent/subagents/general-research-agent.md`:
  - Line 110: Change `mkdir -p "specs/{NNN}_{SLUG}"` to `mkdir -p "specs/OC_{NNN}_{SLUG}"`
  - Line 152: Update example output path: `specs/{NNN}_{SLUG}/reports/` to `specs/OC_{NNN}_{SLUG}/reports/`
  - Search for all `{NNN}` patterns and add `OC_` prefix where referring to directory names

- [ ] Update `.opencode/agent/subagents/planner-agent.md`:
  - Line 75: Change `mkdir -p "specs/{NNN}_{SLUG}"` to `mkdir -p "specs/OC_{NNN}_{SLUG}"`
  - Line 186: Change `mkdir -p specs/{NNN}_{SLUG}/plans/` to `mkdir -p specs/OC_{NNN}_{SLUG}/plans/`
  - Update metadata file path in examples

- [ ] Update `.opencode/agent/subagents/general-implementation-agent.md`:
  - Line 68: Change `mkdir -p "specs/{NNN}_{SLUG}"` to `mkdir -p "specs/OC_{NNN}_{SLUG}"`
  - Update all path examples in documentation

**Timing**: 30 minutes

**Files to modify**:
- `.opencode/agent/subagents/general-research-agent.md`
- `.opencode/agent/subagents/planner-agent.md`
- `.opencode/agent/subagents/general-implementation-agent.md`

**Verification**:
- [ ] Grep for `"specs/{NNN}"` without `OC_` - should return 0 results
- [ ] Verify all path examples show `OC_{NNN}` pattern

---

### Phase 4: Fix Agent Templates (.claude/agents/) [COMPLETED]

**Goal**: Mirror agent template changes in .claude directory

**Tasks**:
- [ ] Update `.claude/agents/general-research-agent.md` with same changes as Phase 3
- [ ] Update `.claude/agents/planner-agent.md` with same changes as Phase 3
- [ ] Update `.claude/agents/general-implementation-agent.md` with same changes as Phase 3

**Timing**: 20 minutes

**Files to modify**:
- `.claude/agents/general-research-agent.md`
- `.claude/agents/planner-agent.md`
- `.claude/agents/general-implementation-agent.md`

**Verification**:
- [ ] Run same grep verification as Phase 3

---

### Phase 5: Fix Meta Builder Agent [COMPLETED]

**Goal**: Update the `/meta` command's agent to use `OC_` prefix for TODO headers

**Tasks**:
- [ ] Update `.claude/agents/meta-builder-agent.md`:
  - Line 532: Change TODO.md format from `### {N}. {Title}` to `### OC_{N}. {Title}`
  - Line 563: Change Python f-string from `f"""### {task_num}. {task['title']}"""` to `f"""### OC_{task_num}. {task['title']}"""`
  - Search for all examples showing directory naming and update to `OC_{NNN}_` format
  - Lines 874, 876: Update example from `037_` to `OC_037_`

**Timing**: 20 minutes

**Files to modify**:
- `.claude/agents/meta-builder-agent.md`

**Verification**:
- [ ] Verify TODO.md format shows `OC_{N}.` pattern
- [ ] Verify all directory examples show `OC_` prefix

---

### Phase 6: Fix Extension Skills (.opencode/extensions/) [COMPLETED]

**Goal**: Update all extension skills to use `OC_` prefix

**Tasks**:
For each extension skill identified in research:
- [ ] Update `.opencode/extensions/web/skills/skill-web-research/SKILL.md`:
  - Line 81: Change `mkdir -p "specs/${padded_num}_${project_name}"` to include `OC_` prefix
  
- [ ] Update `.opencode/extensions/web/skills/skill-web-implementation/SKILL.md`:
  - Line 67: Change to `OC_${padded_num}`

- [ ] Update `.opencode/extensions/nvim/skills/skill-neovim-research/SKILL.md`:
  - Line 82: Change to `OC_${padded_num}`

- [ ] Update `.opencode/extensions/nvim/skills/skill-neovim-implementation/SKILL.md`:
  - Line 92: Change to `OC_${padded_num}`

- [ ] Update `.opencode/extensions/nix/skills/skill-nix-research/SKILL.md`:
  - Line 81: Change to `OC_${padded_num}` (note: currently uses `task_number` - should use `padded_num`)

- [ ] Update `.opencode/extensions/nix/skills/skill-nix-implementation/SKILL.md`:
  - Line 67: Change to `OC_${padded_num}`

- [ ] Update `.opencode/extensions/lean/skills/skill-lean-research/SKILL.md`
- [ ] Update `.opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md`
- [ ] Update `.opencode/extensions/typst/skills/skill-typst-research/SKILL.md`
- [ ] Update `.opencode/extensions/typst/skills/skill-typst-implementation/SKILL.md`
- [ ] Update `.opencode/extensions/latex/skills/skill-latex-research/SKILL.md`
- [ ] Update `.opencode/extensions/latex/skills/skill-latex-implementation/SKILL.md`
- [ ] Update `.opencode/extensions/python/skills/skill-python-research/SKILL.md`
- [ ] Update `.opencode/extensions/python/skills/skill-python-implementation/SKILL.md`
- [ ] Update `.opencode/extensions/formal/skills/skill-formal-research/SKILL.md`
- [ ] Update `.opencode/extensions/formal/skills/skill-math-research/SKILL.md`
- [ ] Update `.opencode/extensions/formal/skills/skill-logic-research/SKILL.md`
- [ ] Update `.opencode/extensions/formal/skills/skill-physics-research/SKILL.md`
- [ ] Update `.opencode/extensions/epidemiology/skills/skill-epidemiology-research/SKILL.md`
- [ ] Update `.opencode/extensions/epidemiology/skills/skill-epidemiology-implementation/SKILL.md`
- [ ] Update `.opencode/extensions/z3/skills/skill-z3-research/SKILL.md`
- [ ] Update `.opencode/extensions/z3/skills/skill-z3-implementation/SKILL.md`

**Timing**: 60 minutes

**Files to modify**: All extension SKILL.md files (approximately 20+ files)

**Verification**:
- [ ] Run: `grep -r "mkdir.*specs/\${padded_num}" .opencode/extensions/ --include="SKILL.md" | grep -v "OC_"` should return nothing

---

### Phase 7: Fix Extension Skills (.claude/extensions/) [COMPLETED]

**Goal**: Mirror extension skill changes in .claude directory

**Tasks**:
- [ ] Apply same changes from Phase 6 to all `.claude/extensions/*/skills/*/` files

**Timing**: 30 minutes

**Files to modify**: All extension SKILL.md files in .claude (approximately 20+ files)

**Verification**:
- [ ] Run: `grep -r "mkdir.*specs/\${padded_num}" .claude/extensions/ --include="SKILL.md" | grep -v "OC_"` should return nothing

---

### Phase 8: Fix Extension Agents (.opencode/extensions/) [COMPLETED]

**Goal**: Update all extension agent templates

**Tasks**:
- [ ] Update `.opencode/extensions/web/agents/web-research-agent.md`:
  - Line 132: Change `mkdir -p "specs/{NNN}_{SLUG}"` to `mkdir -p "specs/OC_{NNN}_{SLUG}"`
  
- [ ] Update `.opencode/extensions/web/agents/web-implementation-agent.md`:
  - Line 99: Same change

- [ ] Update `.opencode/extensions/nvim/agents/neovim-research-agent.md`:
  - Line 108: Same change

- [ ] Update `.opencode/extensions/nvim/agents/neovim-implementation-agent.md`:
  - Line 61: Same change

- [ ] Update `.opencode/extensions/nix/agents/nix-research-agent.md`:
  - Line 218: Same change

- [ ] Update `.opencode/extensions/nix/agents/nix-implementation-agent.md`:
  - Line 82: Same change

- [ ] Update `.opencode/extensions/lean/agents/lean-research-agent.md`:
  - Line 107: Change `mkdir -p "specs/{N}_{SLUG}"` to `mkdir -p "specs/OC_{NNN}_{SLUG}"`

- [ ] Update `.opencode/extensions/lean/agents/lean-implementation-agent.md`:
  - Line 95: Same change

- [ ] Update `.opencode/extensions/formal/agents/formal-research-agent.md`:
  - Line 82: Same change

- [ ] Update `.opencode/extensions/formal/agents/math-research-agent.md`:
  - Line 127: Same change

- [ ] Update `.opencode/extensions/formal/agents/logic-research-agent.md`:
  - Line 123: Same change

**Timing**: 30 minutes

**Files to modify**: All extension agent .md files (approximately 12+ files)

**Verification**:
- [ ] Run: `grep -r "mkdir.*specs/{NNN}" .opencode/extensions/ --include="*.md" | grep -v "OC_"` should return nothing

---

### Phase 9: Fix Extension Agents (.claude/extensions/) [COMPLETED]

**Goal**: Mirror extension agent changes in .claude directory

**Tasks**:
- [ ] Apply same changes from Phase 8 to all `.claude/extensions/*/agents/*` files

**Timing**: 20 minutes

**Files to modify**: All extension agent .md files in .claude

**Verification**:
- [ ] Run: `grep -r "mkdir.*specs/{NNN}" .claude/extensions/ --include="*.md" | grep -v "OC_"` should return nothing

---

### Phase 10: Update Context Documentation [COMPLETED]

**Goal**: Update context files that document task naming patterns

**Tasks**:
- [ ] Update `.opencode/context/core/formats/return-metadata-file.md`:
  - Line 143, 173: Change `mkdir -p "specs/${task_number}_${task_slug}"` to `mkdir -p "specs/OC_${padded_num}_${task_slug}"`

- [ ] Update `.opencode/context/core/patterns/metadata-file-return.md`:
  - Line 98-99: Same change

- [ ] Update `.opencode/context/core/patterns/file-metadata-exchange.md`:
  - Line 39: Same change

- [ ] Update `.opencode/context/core/patterns/early-metadata-pattern.md`:
  - Line 218: Change `mkdir -p "specs/{NNN}_{SLUG}"` to `mkdir -p "specs/OC_{NNN}_{SLUG}"`

- [ ] Update `.opencode/context/core/patterns/postflight-control.md`:
  - Lines 71, 137: Change `mkdir -p "specs/${task_number}_${project_name}"` to `mkdir -p "specs/OC_${padded_num}_${project_name}"`

- [ ] Update `.opencode/rules/state-management.md`:
  - Line 232: Change `mkdir -p "specs/${task_num}_${slug}/reports"` to `mkdir -p "specs/OC_${padded_num}_${slug}/reports"`

- [ ] Mirror all above changes in `.claude/context/` counterparts

**Timing**: 30 minutes

**Files to modify**: Approximately 10-15 context files in both .opencode and .claude

**Verification**:
- [ ] Grep for remaining `specs/${task_number}` patterns without `OC_`

---

### Phase 11: Verification and Testing [COMPLETED]

**Goal**: Verify all changes work correctly and maintain backwards compatibility

**Tasks**:
- [ ] Create comprehensive grep script to verify no plain patterns remain:
  ```bash
  # Should all return empty
  grep -r "mkdir.*specs/\${padded_num}" .opencode/ .claude/ --include="*.md" | grep -v "OC_"
  grep -r "mkdir.*specs/{NNN}" .opencode/ .claude/ --include="*.md" | grep -v "OC_"
  grep -r "specs/\${task_number}" .opencode/ .claude/ --include="*.md" | grep -v "OC_"
  ```

- [ ] Verify backwards compatibility:
  - [ ] Check skill-todo/SKILL.md still uses `"###%s+(OC_)?(%d+)%\."` pattern
  - [ ] Check commands/task.md still strips `OC_` prefix for state.json lookups
  - [ ] Document that existing tasks (192, 193, etc.) remain functional

- [ ] Test task creation (manual verification):
  - [ ] Create a test task via `/task "Test OC prefix standardization"`
  - [ ] Verify directory is created as `specs/OC_NNN_test_*/`
  - [ ] Verify TODO.md shows `### OC_N. Test OC prefix standardization`
  - [ ] Verify `/research N` works (without OC_ prefix)
  - [ ] Verify `/research OC_N` works (with OC_ prefix)

- [ ] Create verification report documenting:
  - Total files modified
  - Patterns changed
  - Backwards compatibility maintained
  - Test results

**Timing**: 30 minutes

**Verification**:
- [ ] All grep commands return empty (no plain patterns)
- [ ] Test task created with correct `OC_` prefix
- [ ] Commands accept both `N` and `OC_N` formats

---

## Testing & Validation

### Pre-Implementation Baseline
- [ ] Run grep commands to count current patterns
- [ ] Document existing task 192, 193, 194 directory structures

### Per-Phase Validation
- [ ] After each phase, run grep to verify changes
- [ ] Check for any syntax errors or broken references

### Post-Implementation Validation
- [ ] Create test task and verify directory naming
- [ ] Test backwards compatibility with existing tasks
- [ ] Verify commands work with both `N` and `OC_N` formats

### Regression Testing
- [ ] Run `/task --sync` to ensure TODO.md and state.json sync works
- [ ] Verify existing tasks can still be researched/planned/implemented

---

## Artifacts & Outputs

- Modified skill files (20+ files across core and extensions)
- Modified agent templates (15+ files)
- Modified context documentation (10+ files)
- Verification report
- Test task confirming standardization works

---

## Rollback/Contingency

If issues are discovered:

1. **Immediate Rollback**: All changes are in SKILL.md and agent files only - revert via git
2. **Partial Rollback**: If only certain extensions have issues, revert those specific files
3. **Contingency**: If standardization causes unforeseen issues, document the specific problem locations and adjust plan

**Rollback Command**:
```bash
git checkout -- .opencode/skills/ .opencode/agents/ .opencode/extensions/ \
                .claude/skills/ .claude/agents/ .claude/extensions/ \
                .opencode/context/ .claude/context/
```

---

## Summary Checklist

### Core Changes
- [ ] skill-researcher/SKILL.md (both .opencode and .claude)
- [ ] skill-planner/SKILL.md (both .opencode and .claude)
- [ ] skill-implementer/SKILL.md (both .opencode and .claude)

### Agent Templates
- [ ] general-research-agent.md (both directories)
- [ ] planner-agent.md (both directories)
- [ ] general-implementation-agent.md (both directories)
- [ ] meta-builder-agent.md (.claude only)

### Extension Skills (Both .opencode and .claude)
- [ ] web/*-research/SKILL.md, *-implementation/SKILL.md
- [ ] nvim/*-research/SKILL.md, *-implementation/SKILL.md
- [ ] nix/*-research/SKILL.md, *-implementation/SKILL.md
- [ ] lean/*-research/SKILL.md, *-implementation/SKILL.md
- [ ] typst/*-research/SKILL.md, *-implementation/SKILL.md
- [ ] latex/*-research/SKILL.md, *-implementation/SKILL.md
- [ ] python/*-research/SKILL.md, *-implementation/SKILL.md
- [ ] formal/*-research/SKILL.md (formal, math, logic, physics)
- [ ] epidemiology/*-research/SKILL.md, *-implementation/SKILL.md
- [ ] z3/*-research/SKILL.md, *-implementation/SKILL.md

### Extension Agents (Both .opencode and .claude)
- [ ] web/*-research-agent.md, *-implementation-agent.md
- [ ] nvim/*-research-agent.md, *-implementation-agent.md
- [ ] nix/*-research-agent.md, *-implementation-agent.md
- [ ] lean/*-research-agent.md, *-implementation-agent.md
- [ ] formal/*-research-agent.md (formal, math, logic)

### Context Documentation
- [ ] return-metadata-file.md
- [ ] metadata-file-return.md
- [ ] file-metadata-exchange.md
- [ ] early-metadata-pattern.md
- [ ] postflight-control.md
- [ ] state-management.md (rules)

---

## Notes

- **No changes needed to**: `commands/task.md` - Already uses `OC_` prefix correctly
- **No changes needed to**: Command argument parsing - Already strips `OC_` prefix for backwards compatibility
- **No changes needed to**: `skill-todo/SKILL.md` parsing - Already handles both formats
- **State storage unchanged**: state.json continues to use plain integers

**Total estimated effort**: 3-4 hours across 11 phases
**Estimated file modifications**: 60-70 files
**Risk level**: Low to Medium (changes are mechanical but numerous)
