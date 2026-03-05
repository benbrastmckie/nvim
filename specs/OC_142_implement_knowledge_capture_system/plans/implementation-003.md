# Implementation Plan: Task #142

- **Task**: 142 - Implement Knowledge Capture System
- **Status**: [NOT STARTED]
- **Effort**: 16 hours
- **Dependencies**: OC_143 (fix metadata delegation) - MUST complete first
- **Research Inputs**: specs/OC_142_implement_knowledge_capture_system/reports/research-002.md
- **Artifacts**: plans/implementation-003.md (this file)
- **Standards**: .opencode/context/core/formats/plan-format.md, .opencode/context/core/standards/status-markers.md, .opencode/context/core/standards/documentation-standards.md, .opencode/context/core/standards/task-management.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan implements a comprehensive knowledge capture system with three integrated features: (1) renaming /learn to /fix for clearer semantics using a clean-break approach with NO backwards compatibility, (2) adding task mode to /remember for automated artifact review with interactive classification, and (3) enhancing /todo with automatic CHANGE_LOG.md updates and memory harvest suggestions. The implementation follows a dependency-first approach, waiting for OC_143 completion before proceeding with core feature development.

### Research Integration

Research findings indicate NONE of the three planned enhancements are implemented:
- /learn still exists as learn.md, needs rename to fix.md
- /remember has no task mode capability, no --task parsing
- /todo has EMPTY skill directory, needs full extraction
- No CHANGE_LOG.md exists anywhere
- Memory vault exists but is empty

Critical dependency: OC_143 must complete first to avoid conflicts with metadata delegation fixes.

Recommended order: Wait for OC_143 -> Create skill-todo -> Rename /learn (clean-break) -> Add /remember task mode -> Integration testing.

## Goals & Non-Goals

**Goals**:
- Rename /learn command to /fix with updated semantics
- Add task mode to /remember with artifact review and 5-category classification
- Create skill-todo infrastructure with full logic extraction from todo.md
- Implement automatic CHANGE_LOG.md updates in todo.md
- Add memory harvest suggestions to /todo completion flow
- Complete atomic rename of /learn to /fix with NO backwards compatibility (clean-break approach)

**Non-Goals**:
- Backwards compatibility or aliases for /learn (clean-break approach)
- Rewriting core metadata delegation (handled by OC_143)
- Creating new memory vault structure (use existing)
- Changing /remember text or file input modes
- Adding non-knowledge-capture features to /todo
- Implementing automatic memory harvesting (only suggestions)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| OC_143 not completed before start | High | Medium | Phase 1 blocks until OC_143 is done; verify status before proceeding |
| Muscle memory breakage from /learn removal | Medium | High | Accept as clean-break cost; clear documentation in CHANGE_LOG.md and announcements |
| Incomplete reference updates break system | High | Low | Comprehensive grep sweep + verification checklist; test all dependent commands |
| /remember task mode complexity | Medium | Medium | Start with simple file listing, add classification incrementally |
| skill-todo extraction scope creep | Medium | Medium | Strict boundary: only todo.md logic, no other command changes |
| Memory vault schema conflicts | Low | Low | Use existing vault structure, only add new memory type for task insights |

## Implementation Phases

### Phase 1: OC_143 Dependency Verification [COMPLETED]

**Goal**: Ensure OC_143 is completed before proceeding

**Tasks**:
- [x] Check OC_143 status in specs/state.json or via /task command
- [x] Verify metadata delegation fixes are merged
- [x] Review OC_143 changes to understand any impact on this task
- [x] If OC_143 incomplete: document block and wait
- [x] If OC_143 complete: proceed to Phase 2

**Completion Notes**: OC_143 verified as completed (status: "completed" in state.json line 23). Ready to proceed.

**Timing**: 0.5 hours (verification only, may extend if waiting)

**Rollback**: None needed (no changes made)

### Phase 2: Create skill-todo Infrastructure [COMPLETED]

**Goal**: Extract todo.md logic into dedicated skill with CHANGE_LOG.md support

**Tasks**:
- [x] Read .opencode/commands/todo.md (278 lines) to understand current embedded logic
- [x] Analyze todo.md workflow and identify delegation points
- [x] Create .opencode/skills/skill-todo/SKILL.md following skill-template.md
- [x] Add CHANGE_LOG.md management functions:
  - [x] Create specs/CHANGE_LOG.md if not exists
  - [x] Add entry format: date, task, type, description
  - [x] Implement auto-append on task status changes
- [x] Add memory harvest suggestion logic:
  - [x] Scan completed task artifacts for insights
  - [x] Suggest memory creation based on key learnings
  - [x] Interactive prompt: "Create memory from this insight?"
- [x] Update todo.md to delegate to skill-todo instead of embedded logic
- [x] Test basic todo operations work via new skill

**Timing**: 5 hours

**Completion Notes**: 
- Created skill-todo/SKILL.md with full execution flow (16 stages)
- Updated todo.md to delegate to skill-todo
- Created initial specs/CHANGE_LOG.md
- Includes memory harvest categories: TECHNIQUE, PATTERN, CONFIG, WORKFLOW, INSIGHT

**Rollback**:
1. Keep original todo.md backup
2. If skill fails, restore embedded logic in todo.md
3. Remove skill-todo directory if extraction fails

### Phase 3: Rename /learn to /fix (Clean-Break) [COMPLETED]

**Goal**: Rename command and skill from /learn to /fix with complete removal - NO backwards compatibility

**CRITICAL**: This phase follows a clean-break approach. The /learn command will be completely removed with NO aliases, NO deprecated fallback, and NO backwards compatibility. All references must be updated atomically.

**Tasks**:
- [x] Pre-flight: grep entire codebase for all /learn references
  - [x] Search .opencode/commands/ for "learn" references
  - [x] Search .opencode/skills/ for "learn" references
  - [x] Search .opencode/ root for "learn" references
  - [x] Document all files requiring updates (create checklist)
- [x] Rename .opencode/commands/learn.md to fix.md
- [x] Update fix.md command specification:
  - [x] Change command name from /learn to /fix
  - [x] Update description to emphasize "fix/correct" semantics
  - [x] Remove ALL references to /learn command
  - [x] Modify examples to show fixing patterns
- [x] Rename .opencode/skills/skill-learn/ to skill-fix/
- [x] Update skill-fix/SKILL.md:
  - [x] Change all /learn references to /fix
  - [x] Update agent metadata and delegation
  - [x] Modify examples for fix context
- [x] Update all internal references (atomically, using the checklist from pre-flight):
  - [x] Update all "learn" in commands directory to "fix"
  - [x] Update all "learn" in skills directory to "fix"
  - [x] Update any hardcoded paths to skill-learn
  - [x] Update documentation references
  - [x] Update any test files or examples
- [x] Delete verification - ensure NO /learn remains:
  - [x] Run grep -r "/learn" .opencode/ to verify complete removal
  - [x] Run grep -r "skill-learn" .opencode/ to verify complete removal
  - [x] Verify no file named learn.md exists in commands/
  - [x] Verify no directory named skill-learn/ exists in skills/
- [x] Test /fix command works correctly
- [x] Verify no broken references remain

**Timing**: 3 hours (includes comprehensive reference sweep)

**Verification Checklist** (MUST complete before proceeding):
- [x] grep -r "/learn" .opencode/ returns NO results
- [x] grep -r "skill-learn" .opencode/ returns NO results
- [x] /fix command responds correctly
- [x] All commands referencing /fix work correctly
- [x] Documentation shows /fix (not /learn)

**Completion Notes**: Clean-break rename complete. All /learn references removed atomically. Files updated: commands/remember.md, commands/README.md, commands/fix.md (new), skills/skill-remember/SKILL.md, skills/skill-fix/SKILL.md (new), docs/guides/user-guide.md, docs/guides/component-selection.md, docs/guides/documentation-audit-checklist.md, README.md. learn.md and skill-learn/ deleted.

**Rollback**:
- Phase 3 is ATOMIC: do NOT attempt partial rollback
- If rollback needed: rename directories back AND restore ALL reference updates
- Must revert ALL files simultaneously to maintain consistency
- Document rollback reason and re-plan from Phase 3 start

### Phase 4: Add Task Mode to /remember [COMPLETED]

**Goal**: Implement --task OC_N mode for artifact review with interactive classification

**Tasks**:
- [x] Read .opencode/commands/remember.md (95 lines) to understand current modes
- [x] Read .opencode/skills/skill-remember/SKILL.md (208 lines) for skill structure
- [x] Design --task argument parsing in remember.md:
  - [x] Add --task OC_N to command specification
  - [x] Document task mode behavior
- [x] Implement task directory parsing in skill-remember:
  - [x] Parse specs/OC_{N}_{SLUG}/ structure
  - [x] Identify artifact files (reports/, plans/, code/, etc.)
  - [x] Generate file listing for review
- [x] Implement interactive classification workflow:
  - [x] Display artifact list with numbers
  - [x] Allow user to select file(s) to review
  - [x] Show file content in chunks for review
  - [x] Present 5 classification categories:
    1. [TECHNIQUE] - Reusable method or approach
    2. [PATTERN] - Design or implementation pattern
    3. [CONFIG] - Configuration or setup knowledge
    4. [WORKFLOW] - Process or procedure
    5. [INSIGHT] - Key learning or understanding
    6. [SKIP] - Not valuable for memory
  - [x] Capture user classification selection
- [x] Create memory from classified content:
  - [x] Extract key insight from artifact
  - [x] Format memory with classification tag
  - [x] Save to memory vault (vault/memories/)
- [x] Update skill-remember/SKILL.md with task mode documentation
- [x] Test task mode with actual task directory

**Timing**: 5 hours

**Completion Notes**: Task mode fully implemented with 6 classification categories (including SKIP). Updated remember.md with --task argument parsing, task mode documentation with workflow and examples. Updated skill-remember/SKILL.md with 10 execution stages including TaskModeScan, TaskModeSelection, TaskModeReview stages. Classification taxonomy: TECHNIQUE, PATTERN, CONFIG, WORKFLOW, INSIGHT, SKIP.

**Rollback**:
1. Revert remember.md to original (remove --task option)
2. Restore skill-remember/SKILL.md to original
3. Remove any test memories created during development

### Phase 5: Integration & Validation [NOT STARTED]

**Goal**: Test all three features work together and fix any issues

**Tasks**:
- [ ] End-to-end test: Create test task via /todo
- [ ] Verify CHANGE_LOG.md auto-updates on task completion
- [ ] Test /fix command works correctly (renamed from /learn, NO /learn fallback)
- [ ] Test /remember task mode with test task artifacts
- [ ] Verify memory harvest suggestions appear in /todo completion
- [ ] Clean-break verification:
  - [ ] Attempt to use /learn - should FAIL (command not found)
  - [ ] Confirm skill-learn directory does NOT exist
  - [ ] Confirm learn.md does NOT exist
  - [ ] Confirm no references to /learn anywhere
- [ ] Test edge cases:
  - [ ] /remember --task with non-existent task number
  - [ ] /todo with no artifacts to harvest
  - [ ] /fix with various input types
- [ ] Cross-feature integration test:
  - [ ] Create task -> Add memory via /remember -> Complete task -> Verify CHANGE_LOG -> Check harvest suggestions
- [ ] Fix any integration bugs found
- [ ] Performance check: Ensure no significant slowdown

**Timing**: 2 hours

**Rollback**:
1. Restore all files to pre-integration state
2. Re-run individual phase rollbacks if needed
3. Document which phase caused integration issue

### Phase 6: Documentation & Examples [NOT STARTED]

**Goal**: Update all documentation and create usage examples

**Tasks**:
- [ ] Update .opencode/commands/README.md:
  - [ ] Change /learn to /fix in command list (NO /learn fallback)
  - [ ] Add /remember task mode description
  - [ ] Document /todo CHANGE_LOG feature
- [ ] Update .opencode/skills/README.md:
  - [ ] Add skill-todo entry
  - [ ] Update skill-learn to skill-fix (NO skill-learn entry)
- [ ] Create example usage for /fix:
  - [ ] Example 1: Fixing a common configuration error
  - [ ] Example 2: Documenting a workaround
- [ ] Create example usage for /remember task mode:
  - [ ] Example: Reviewing a research report and creating memories
- [ ] Update CHANGE_LOG.md with this implementation entry:
  - [ ] Note: /learn renamed to /fix (clean-break, NO backwards compatibility)
- [ ] Add migration notice to CHANGE_LOG.md (muscle memory breakage acknowledged)
- [ ] Verify all internal links work
- [ ] Final documentation review for consistency

**Timing**: 0.5 hours

**Rollback**:
1. Revert documentation files to original state
2. Re-run if issues found

## Testing & Validation

- [ ] All /todo operations work via skill-todo
- [ ] CHANGE_LOG.md auto-updates on task status changes
- [ ] Memory harvest suggestions appear in /todo completion flow
- [ ] /fix command responds correctly (renamed from /learn)
- [ ] NO /learn command exists or works (clean-break verification)
- [ ] NO skill-learn directory exists
- [ ] NO learn.md file exists in commands/
- [ ] ALL /learn references removed from codebase (grep returns empty)
- [ ] /remember --task OC_N parses task directory correctly
- [ ] Artifact review shows all files in task directory
- [ ] Classification taxonomy presents 5 categories + skip
- [ ] Memories created with correct classification tags
- [ ] No broken internal references
- [ ] All examples work as documented
- [ ] Integration test passes (create -> remember -> complete -> verify)

## Artifacts & Outputs

- `.opencode/commands/fix.md` (renamed from learn.md)
- `.opencode/skills/skill-fix/SKILL.md` (renamed and updated)
- `.opencode/skills/skill-todo/SKILL.md` (new)
- `.opencode/skills/skill-todo/todo-agent.lua` (new subagent)
- `.opencode/commands/remember.md` (updated with --task)
- `.opencode/skills/skill-remember/SKILL.md` (updated with task mode)
- `specs/CHANGE_LOG.md` (new)
- `.opencode/commands/todo.md` (updated to delegate to skill)
- Updated README files in commands/ and skills/ (NO /learn references)
- Test memories in vault/memories/

**Removed Artifacts** (clean-break):
- ~~`.opencode/commands/learn.md`~~ DELETED
- ~~`.opencode/skills/skill-learn/`~~ DELETED

## Rollback/Contingency

**Full Rollback Procedure**:
1. Use git to revert all changes: `git checkout -- .opencode/`
2. Remove new files: `rm -rf .opencode/skills/skill-todo/ .opencode/commands/fix.md specs/CHANGE_LOG.md`
3. Restore todo.md embedded logic if needed
4. Verify system returns to original state
5. Document rollback reason and re-plan

**Phase-Specific Rollback Options**:
- Phase 2 only: Restore embedded todo.md logic, remove skill-todo
- Phase 3 (clean-break) only: ATOMIC rollback required - rename fix.md -> learn.md AND skill-fix -> skill-learn AND restore all reference updates simultaneously
- Phase 4 only: Remove --task from remember.md, revert skill-remember

**Contingency Plans**:
- If OC_143 delayed >2 days: Consider starting Phase 2-3 in parallel with coordination
- If /remember task mode too complex: Split into two phases (basic review first, classification second)
- If CHANGE_LOG.md location disputed: Discuss with team, can move to alternate location
- If skill-todo extraction breaks: Maintain embedded logic as fallback
- If clean-break causes too much disruption: Add temporary shim (violation of philosophy, but pragmatic option)

## Implementation Notes

**Design Decisions Applied**:
- CHANGE_LOG.md location: specs/CHANGE_LOG.md (Option A from research)
- Task mode syntax: --task OC_N (Option A from research)
- Classification taxonomy: 5 categories + skip (research recommendation)
- Backward compatibility: NONE - clean-break approach (Option B from research, but enforced strictly)
- skill-todo scope: Full extraction (Option A from research)

**Clean-Break Philosophy**:
This plan explicitly rejects backwards compatibility for the /learn to /fix rename. The reasoning:
1. Muscle memory is re-trainable; /fix is more semantically correct
2. Aliases create technical debt and confusion
3. Clean breaks force complete updates, avoiding partial/inconsistent states
4. The cost is one-time user retraining; the benefit is long-term clarity

**Agent Guidelines**:
- Each phase is self-contained and can be resumed if interrupted
- Test after EACH phase before proceeding
- Document any deviations from plan in task comments
- If stuck on a phase >2 hours, escalate to human
- Maintain git commits between phases for rollback safety
- Phase 3 (clean-break) must be completed atomically - do not commit partial state

**Success Criteria**:
- All three features functional and integrated
- NO /learn command, file, or reference exists anywhere
- /fix works correctly as the only command
- Documentation updated and accurate
- CHANGE_LOG.md contains this implementation entry with clean-break note
- At least one successful end-to-end test completed
- grep for "/learn" returns zero results in .opencode/
