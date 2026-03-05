# Research Report: Knowledge Capture System (OC_142)

## Executive Summary

This research analyzes the implementation requirements for integrating three knowledge capture features: (1) renaming /learn to /fix, (2) adding task mode to /remember for artifact review, and (3) enhancing /todo with CHANGE_LOG.md integration and memory harvest suggestions.

**Key Finding**: All three features are modifications to existing commands in the .opencode/ system. The /remember command is already implemented from OC_136 with checkbox-based confirmation. The primary work involves architectural alignment and feature expansion rather than ground-up development.

---

## Current System State

### 1. /learn Command Analysis

**Current Implementation**: `.opencode/commands/learn.md`
- **Purpose**: Scan codebase for FIX:/NOTE:/TODO: tags and create tasks
- **Delegate**: `skill-learn` (direct execution)
- **Status**: Fully operational

**Current Workflow**:
```
1. Parse paths argument (optional)
2. Delegate to skill-learn
3. Scan for tags (FIX:/NOTE:/TODO:)
4. Interactive selection via checkboxes
5. Create tasks in TODO.md and state.json
```

**Key Components**:
- Command spec at: `.opencode/commands/learn.md` (95 lines)
- Skill at: `.opencode/skills/skill-learn/SKILL.md` (48 lines)
- Interactive checkbox pattern already implemented

**Proposed Change**: Rename to /fix to better reflect purpose (scanning FIX: tags specifically)

---

### 2. /remember Command Analysis

**Current Implementation**: `.opencode/commands/remember.md`
- **Purpose**: Add memories to vault with interactive checkbox confirmation
- **Delegate**: `skill-remember` (direct execution)
- **Status**: Fully implemented from OC_136

**Current Workflow**:
```
1. Parse input (text or file path)
2. Generate unique memory ID (MEM-YYYY-MM-DD-NNN)
3. Create entry from template
4. Search for similar memories
5. Present checkbox confirmation dialog
6. Execute selected actions (add/update/edit/skip)
7. Commit changes to git
```

**Key Components**:
- Command spec: `.opencode/commands/remember.md` (95 lines)
- Skill: `.opencode/skills/skill-remember/SKILL.md` (208 lines)
- Memory vault: `.opencode/memory/` (Obsidian-compatible)
- Template: `.opencode/memory/30-Templates/memory-template.md`
- Usage docs: `.opencode/docs/remember-usage.md` (191 lines)

**Memory Vault Structure**:
```
.opencode/memory/
├── .obsidian/           # Obsidian config (gitignored)
├── 00-Inbox/           # Quick capture
├── 10-Memories/        # Stored entries
├── 20-Indices/         # Navigation
├── 30-Templates/       # Templates
└── README.md           # Documentation
```

**Proposed Enhancement**: Add task mode for artifact review with interactive classification

**Artifact Review Mode Requirements**:
- Parse task directory structure
- Identify artifacts (research reports, plans, summaries)
- Extract key learnings from each artifact
- Present classification options via checkboxes:
  - Pattern/Convention discovered
  - Best practice identified
  - Mistake to avoid
  - Tool/technique learned
  - Architecture insight
  - Skip
- Convert selected learnings to memories
- Update CHANGE_LOG.md with memory references

---

### 3. /todo Command Analysis

**Current Implementation**: `.opencode/commands/todo.md`
- **Purpose**: Archive completed and abandoned tasks
- **Delegate**: None (direct execution in command)
- **Status**: Operational but missing CHANGE_LOG.md integration

**Current Workflow**:
```
1. Scan for archivable tasks (completed/abandoned)
2. Detect orphaned directories
3. Detect misplaced directories
4. Scan roadmap for task references
5. Scan meta tasks for README.md suggestions
6. Interactive prompts for decisions
7. Archive tasks (update state files)
8. Update roadmap annotations
9. Apply README.md suggestions
10. Git commit
```

**Key Components**:
- Command spec: `.opencode/commands/todo.md` (278 lines)
- No separate skill (logic embedded in command)
- Note: `skill-todo` directory exists but is EMPTY

**Missing Feature**: CHANGE_LOG.md Integration

**Current /todo Outputs**:
- Updates archive/state.json
- Updates active state.json
- Updates TODO.md
- Moves directories to specs/archive/
- Updates ROAD_MAP.md annotations
- Applies README.md suggestions

**Missing Output**: CHANGE_LOG.md updates with:
- Task completion entries
- Memory harvest suggestions
- Pattern/convention discoveries

---

## Architecture Analysis

### Command-Skill-Agent Pattern

All three commands follow the OpenCode delegation pattern:

```
Command (Layer 2) → Skill (Direct Execution) → Operations
```

**Current State**:
- /learn: Command → skill-learn ✓
- /remember: Command → skill-remember ✓
- /todo: Command (embedded logic) → NO SKILL ✗

**Recommended Architecture**:
```
/learn (to be /fix):  Command → skill-learn (rename only)
/remember:           Command → skill-remember (add task mode)
/todo:               Command → skill-todo (create + enhance)
```

### Interactive Checkbox Pattern

Both /learn and /remember use the same interactive checkbox pattern:

```lua
-- From skill-learn and skill-remember
AskUserQuestion with multiSelect:
  - Present options with checkboxes
  - Allow multiple selections
  - Handle "skip" as cancel
  - Execute based on selections
```

**Reusable Component**: This pattern should be extracted and reused for:
- /fix tag selection (existing)
- /remember memory actions (existing)
- /remember task artifact classification (new)
- /todo memory harvest suggestions (new)

---

## Feature Integration Requirements

### Feature 1: Rename /learn to /fix

**Scope**: Minimal - primarily naming change

**Required Changes**:
1. Rename file: `.opencode/commands/learn.md` → `.opencode/commands/fix.md`
2. Update command description to emphasize FIX: tags
3. Update skill name references: `skill-learn` → `skill-fix`
4. Rename directory: `.opencode/skills/skill-learn/` → `.opencode/skills/skill-fix/`
5. Update all references in documentation

**Effort**: Low (1 hour)
**Risk**: Low (straightforward rename)

---

### Feature 2: Add Task Mode to /remember

**Scope**: Medium - new workflow mode

**Command Syntax Options**:
```bash
/remember --task OC_136          # Review specific task
/remember --task                 # Review current directory task
/remember /path/to/task/dir     # Review task at path
```

**Required Changes**:

1. **Update Command Spec** (`.opencode/commands/remember.md`):
   - Add `--task` argument parsing
   - Detect task mode vs text/file mode
   - Delegate to skill-remember with mode flag

2. **Update Skill** (`.opencode/skills/skill-remember/SKILL.md`):
   - Add Stage 0: Mode Detection
   - Add new stages for task mode:
     - Stage A: Parse task directory structure
     - Stage B: Read artifacts (research reports, plans, summaries)
     - Stage C: Extract key learnings using AI analysis
     - Stage D: Present classification checkboxes
     - Stage E: Convert selected learnings to memories
     - Stage F: Update CHANGE_LOG.md with references

3. **Classification Categories**:
   - Pattern/Convention discovered
   - Best practice identified
   - Mistake to avoid
   - Tool/technique learned
   - Architecture insight
   - Skip

4. **Artifact Analysis Strategy**:
   - Research reports: Extract findings, root causes, recommendations
   - Plans: Extract implementation strategies, phase breakdowns
   - Summaries: Extract completion summaries, lessons learned
   - Code changes: Extract pattern examples (via git diff)

**Effort**: Medium (4-6 hours)
**Risk**: Medium (requires AI analysis integration)

---

### Feature 3: Enhance /todo with CHANGE_LOG.md Integration

**Scope**: Medium - new output format + skill creation

**Required Changes**:

1. **Create skill-todo** (NEW):
   - Currently empty directory exists
   - Create `.opencode/skills/skill-todo/SKILL.md`
   - Move embedded logic from command to skill
   - Add CHANGE_LOG.md generation stage

2. **CHANGE_LOG.md Format** (based on OpenAgentsControl example):
   ```markdown
   # Changelog
   
   All notable changes to this project will be documented in this file.
   
   ## [Unreleased]
   
   ## [DATE] - Task Archive
   
   ### Knowledge Captured
   - Memory: MEM-YYYY-MM-DD-NNN - Description (from task OC_N)
   - Memory: MEM-YYYY-MM-DD-NNN - Description (from task OC_N)
   
   ### Tasks Completed
   - OC_N: Task name (summary)
   
   ### Patterns Discovered
   - Pattern: Description (from OC_N)
   
   ### Tool/Technique Learned
   - Tool: Description (from OC_N)
   ```

3. **Memory Harvest Integration**:
   - During task archival, extract completion_summary from state.json
   - Analyze for knowledge worth capturing
   - Present checkbox options:
     - Add to CHANGE_LOG.md
     - Create memory from learnings
     - Update README.md (if meta task)
     - Skip

4. **Update Command Spec**:
   - Delegate to skill-todo
   - Add CHANGE_LOG.md to writes
   - Remove embedded workflow logic

**Effort**: Medium (4-6 hours)
**Risk**: Low-Medium (new skill creation, well-defined scope)

---

## Dependencies and Blockers

### Current Dependencies
- **OC_143**: Fix metadata delegation (REQUIRED)
- **OC_144**: Fix systemic metadata delegation (REQUIRED)

These must be completed first because:
1. /remember task mode needs to write metadata about processed artifacts
2. /todo CHANGE_LOG.md integration needs artifact linking
3. All three features need proper task state management

### No Additional Dependencies
- Memory vault already exists (from OC_136)
- Checkbox pattern already implemented
- CHANGE_LOG.md format established

---

## Implementation Strategy

### Phase 1: Infrastructure (after OC_143/144 complete)
- Verify metadata delegation working
- Test /remember in current state
- Establish CHANGE_LOG.md location and format

### Phase 2: Rename /learn to /fix
- Rename files and directories
- Update all references
- Test functionality preserved

### Phase 3: Create skill-todo
- Extract logic from command
- Create skill structure
- Add CHANGE_LOG.md generation

### Phase 4: Add /remember Task Mode
- Implement artifact scanning
- Add classification checkboxes
- Integrate with CHANGE_LOG.md

### Phase 5: Integration Testing
- Test all three features together
- Verify knowledge flows correctly
- Validate CHANGE_LOG.md updates

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Metadata delegation not working | High | High | Complete OC_143/144 first |
| Task mode AI analysis inaccurate | Medium | Medium | Use structured extraction, validate outputs |
| CHANGE_LOG.md format disagreements | Low | Low | Follow established Keep a Changelog format |
| Breaking existing /learn users | Medium | Low | Provide backward compatibility or clear migration |

---

## Recommendations

### Immediate Actions
1. **WAIT** for OC_143 and OC_144 completion before starting
2. Verify memory vault is functional with current /remember
3. Decide on CHANGE_LOG.md location (root or .opencode/)

### Implementation Order
1. Rename /learn → /fix (lowest risk)
2. Create skill-todo with CHANGE_LOG.md (foundational)
3. Add /remember task mode (highest value)

### Design Decisions Needed
1. **CHANGE_LOG.md location**: Root level or .opencode/ directory?
2. **Task mode syntax**: `--task OC_N` vs `/remember task OC_N` vs other?
3. **Classification taxonomy**: Are the 5 categories sufficient?
4. **Backward compatibility**: Keep /learn as alias or hard rename?

---

## Related Research

### OC_136 Research
- Research-001: Memory management patterns analysis
- Research-002: Delegation chain analysis (led to direct execution pattern)
- Research-003: Obsidian integration advantages/disadvantages
- Research-004: Simplified vault structure design

All research reports available in:
`specs/OC_136_design_and_implement_remember_command_for_intelligent_memory_management/reports/`

### Existing Conventions
- Memory ID format: `MEM-YYYY-MM-DD-NNN`
- Checkbox pattern: `AskUserQuestion` with `multiSelect: true`
- CHANGE_LOG.md format: Keep a Changelog standard
- Git commit format: `memory: add MEM-...` or `todo: archive N tasks`

---

## Conclusion

The knowledge capture system implementation involves three well-scoped feature modifications:

1. **Rename /learn to /fix**: Low effort, primarily naming change
2. **Add task mode to /remember**: Medium effort, leverages existing checkbox pattern
3. **Enhance /todo with CHANGE_LOG.md**: Medium effort, requires new skill creation

**Critical Path**: Complete OC_143 and OC_144 first to ensure metadata delegation is functional.

**Estimated Total Effort**: 10-14 hours across all three features
**Recommended Timeline**: After OC_143/144 complete, implement in 2-3 phases

---

## Next Step

Proceed to `/plan OC_142` to create detailed implementation phases.

