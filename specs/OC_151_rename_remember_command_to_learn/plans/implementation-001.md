# Implementation Plan: Task #151

- **Task**: 151 - rename_remember_command_to_learn
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: specs/OC_151_rename_remember_command_to_learn/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: .opencode/context/core/formats/plan-format.md, .opencode/context/core/standards/status-markers.md, .opencode/context/core/standards/documentation-standards.md, .opencode/context/core/standards/task-management.md
- **Type**: meta
- **Lean Intent**: false

---

## Overview

This implementation plan details the atomic rename of the `/remember` command to `/learn` throughout the OpenCode system. Based on research findings, this involves updating 47+ distinct references across 14+ files. Following the successful precedent from OC_142, we will implement a clean-break rename with NO backward compatibility aliases.

### Research Integration

The research report (research-001.md) identified all critical files requiring updates:

1. **Core Files**: Skill directory, SKILL.md metadata, command definition
2. **Documentation**: Usage guides, README files, troubleshooting docs
3. **Index Files**: Skills registry, commands list, docs navigation
4. **References**: Memory system documentation, examples

**Key Finding**: This is a clean-break rename scenario. No aliases or backward compatibility should be maintained, consistent with OC_142 precedent.

---

## Goals & Non-Goals

**Goals**:
- Rename skill directory from `skill-remember/` to `skill-learn/`
- Update all SKILL.md metadata and examples
- Rename command file from `remember.md` to `learn.md`
- Update all documentation references from `/remember` to `/learn`
- Update all index and navigation files
- Ensure system functions correctly after rename

**Non-Goals**:
- Do NOT modify archive files (specs/archive/*)
- Do NOT modify CHANGE_LOG.md (historical record)
- Do NOT add backward compatibility aliases
- Do NOT modify existing memory entries in vault
- Do NOT modify git history

---

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Missed reference to old command | Medium | Medium | Pre-implementation grep search, post-implementation verification |
| Broken skill loading | HIGH | Low | Test skill loading immediately after rename |
| User confusion | Low | Medium | Update all documentation atomically before announcing |
| Broken navigation links | Low | Low | Verify all README links after changes |
| Task description files contain references | Low | Medium | Preserve TODO.md and state.json context |

---

## Implementation Phases

### Phase 1: Rename Core Skill Directory and Files [COMPLETED]

**Goal**: Rename the skill directory and update SKILL.md metadata

**Tasks**:
- [ ] Rename `.opencode/skills/skill-remember/` to `skill-learn/`
- [ ] Update `.opencode/skills/skill-learn/SKILL.md` line 2: `name: skill-remember` → `name: skill-learn`
- [ ] Update `.opencode/skills/skill-learn/SKILL.md` line 266: Example `/remember` → `/learn`
- [ ] Update `.opencode/skills/skill-learn/SKILL.md` line 284: Example `/remember` → `/learn`
- [ ] Update `.opencode/skills/skill-learn/README.md`: Update all references and links

**Timing**: 0.5 hours

**Dependencies**: None

**Verification**:
- Skill directory renamed successfully
- SKILL.md loads with correct name field
- Examples in SKILL.md show `/learn`

### Phase 2: Update Command Definition [COMPLETED]

**Goal**: Rename command file and update all internal references

**Tasks**:
- [ ] Rename `.opencode/commands/remember.md` to `learn.md`
- [ ] Update line 5: `# Command: /remember` → `# Command: /learn`
- [ ] Update line 9: `Delegates To: skill-remember` → `Delegates To: skill-learn`
- [ ] Update line 44: skill reference
- [ ] Update line 47: skill reference
- [ ] Update lines 85, 112-113, 123-124, 133: All `/remember` examples → `/learn`

**Timing**: 0.5 hours

**Dependencies**: Phase 1

**Verification**:
- Command file renamed successfully
- All references updated to skill-learn
- All examples show `/learn`

### Phase 3: Update Documentation Files [COMPLETED]

**Goal**: Update all user-facing documentation with new command name

**Tasks**:
- [ ] Rename `.opencode/docs/guides/remember-usage.md` to `learn-usage.md`
- [ ] Update `learn-usage.md` line 1: `# /remember Command Usage Guide` → `# /learn Command Usage Guide`
- [ ] Update `learn-usage.md` lines 8, 13, 19, 24, 29: All examples
- [ ] Update `learn-usage.md` lines 136, 146, 160, 183-185: All command references
- [ ] Update `.opencode/README.md` lines 82-102: Memory system section
- [ ] Update `.opencode/README.md` line 102: Link to usage guide
- [ ] Update `.opencode/memory/README.md` lines 22-24: Usage examples

**Timing**: 1 hour

**Dependencies**: Phase 2

**Verification**:
- All documentation files updated
- No `/remember` references remain in docs
- Links to usage guide work correctly

### Phase 4: Update Index and Navigation Files [COMPLETED]

**Goal**: Update all index files and navigation links

**Tasks**:
- [ ] Update `.opencode/skills/README.md` line 18: `skill-remember` → `skill-learn`
- [ ] ADD entry to `.opencode/commands/README.md`: Create `/learn` listing
- [ ] Update `.opencode/docs/README.md` line 23: `remember-usage.md` → `learn-usage.md`
- [ ] Update `.opencode/docs/guides/README.md` line 23: `remember-usage.md` → `learn-usage.md`

**Timing**: 0.5 hours

**Dependencies**: Phase 3

**Verification**:
- Skills index shows skill-learn
- Commands index includes /learn
- Documentation navigation updated

### Phase 5: Optional Documentation Updates [COMPLETED]

**Goal**: Update low-priority documentation files

**Tasks**:
- [ ] Update `.opencode/docs/examples/knowledge-capture-usage.md` lines 53-55, 60, 92, 114, 202, 250
- [ ] Update `.opencode/docs/guides/memory-troubleshooting.md` lines 43, 70, 87, 138, 236, 250

**Timing**: 0.5 hours

**Dependencies**: Phase 4

**Verification**:
- Optional docs updated
- No broken references remain

### Phase 6: Integration Testing [COMPLETED]

**Goal**: Verify complete system functionality after rename

**Tasks**:
- [ ] Run `grep -r "skill-remember" .opencode/ --include="*.md"` to find any missed references
- [ ] Run `grep -r "/remember" .opencode/ --include="*.md"` to find any missed references
- [ ] Test `/learn "test memory"` command functionality
- [ ] Test `/learn --task 151` task mode functionality
- [ ] Verify skill loads correctly via orchestrator
- [ ] Test all documentation links work correctly
- [ ] Run system health check

**Timing**: 1 hour

**Dependencies**: Phases 1-5

**Verification**:
- Zero references to skill-remember found (excluding archive)
- Zero references to /remember found (excluding archive)
- /learn command works end-to-end
- Memory vault operations work
- All links resolve correctly

---

## Testing & Validation

- [ ] Pre-implementation: Document all files to be modified
- [ ] Phase 1: Verify skill directory rename successful
- [ ] Phase 2: Verify command file rename and references updated
- [ ] Phase 3: Verify all documentation updated
- [ ] Phase 4: Verify all index files updated
- [ ] Phase 5: Verify optional documentation updated
- [ ] Phase 6: Comprehensive grep search for missed references
- [ ] Phase 6: Functional test of /learn command
- [ ] Phase 6: Functional test of /learn --task mode
- [ ] Phase 6: Verify all README links work
- [ ] Phase 6: Verify skill loads via orchestrator

---

## Artifacts & Outputs

- Renamed skill directory: `.opencode/skills/skill-learn/`
- Updated SKILL.md with new name and examples
- Updated skill-learn/README.md
- Renamed command file: `.opencode/commands/learn.md`
- Renamed usage guide: `.opencode/docs/guides/learn-usage.md`
- Updated main README.md memory system section
- Updated memory/README.md
- Updated skills/README.md index
- Updated commands/README.md index
- Updated docs/README.md navigation
- Updated docs/guides/README.md navigation
- Updated optional documentation files

---

## Rollback/Contingency

**If implementation fails during any phase**:

1. **Phase 1 failure**: Simply rename directory back to skill-remember
2. **Phase 2 failure**: Rename command file back to remember.md
3. **Phase 3+ failure**: Use git to revert all changes to affected files

**Contingency procedures**:
- All changes should be committed together atomically if using git
- Keep backup of original files until implementation verified
- If critical error found, revert to original state immediately
- Test thoroughly before marking complete

**Files to preserve (do not modify)**:
- specs/archive/OC_*/**/* (historical records)
- specs/CHANGE_LOG.md (append-only history)
- specs/TODO.md (task context)
- specs/state.json (task state)

---

## Files Not to Modify

The following files should NOT be modified as they are historical records:

| File | Reason |
|------|--------|
| `specs/archive/OC_*/**/*` | Historical task archives |
| `specs/CHANGE_LOG.md` | Append-only change history |
| `specs/TODO.md` | Task context preservation |
| `specs/state.json` | Task state preservation |
| `.git/logs/*` | Immutable git history |
| `.opencode/memory/10-Memories/*.md` | Historical memory entries |

---

## Implementation Notes

### Clean-Break Rename Pattern

This implementation follows the clean-break rename pattern established in OC_142:
- NO backward compatibility aliases
- Atomic rename of all components
- Comprehensive documentation updates
- Users will adapt quickly to the new command name

### Verification Commands

Before marking complete, run these verification commands:

```bash
# Check for any remaining skill-remember references
grep -r "skill-remember" .opencode/ --include="*.md" | grep -v archive | grep -v CHANGE_LOG

# Check for any remaining /remember references
grep -r "/remember" .opencode/ --include="*.md" | grep -v archive | grep -v CHANGE_LOG | grep -v TODO

# Test the command (when implementation is complete)
# /learn "test memory after rename"
# /learn --task 151
```

### Success Criteria

The implementation is complete when:
1. All files listed in the research report are updated
2. No references to `skill-remember` or `/remember` remain (except excluded files)
3. The `/learn` command works correctly
4. All documentation links work correctly
5. The skill loads correctly via orchestrator

---

*Plan created by planner-agent based on research report research-001.md*
*Total estimated effort: 4 hours across 6 phases*