# Implementation Plan: Avoid /tmp Directory Permission Requests in Agent System

- **Task**: 156 - avoid_tmp_directory_permission_requests_in_agent_system
- **Status**: [NOT STARTED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/OC_156_avoid_tmp_directory_permission_requests_in_agent_system/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**:
  - .opencode/context/core/formats/plan-format.md
  - .opencode/context/core/standards/status-markers.md
  - .opencode/context/core/standards/documentation-standards.md
  - .opencode/context/core/standards/task-management.md
  - .opencode/context/core/workflows/task-breakdown.md
- **Type**: markdown
- **Lean Intent**: false

## Overview

This plan addresses the security and permission issues caused by writing temporary files to `/tmp/` when updating `specs/state.json` using `jq`. The solution replaces all `/tmp/state.json` patterns with `specs/tmp/state.json` throughout the `.opencode/` agent system, using a user-owned directory that avoids SELinux, AppArmor, and container permission prompts.

The migration affects 85+ occurrences across 4 priority groups: Core Commands (14), Skills (20+), Context Documentation (35+), and Scripts (9).

### Research Integration

Research report research-001.md identified the problem pattern:
```bash
# Before
jq '...' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json

# After
jq '...' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

The `specs/tmp/` directory already exists and is user-owned, making it the ideal replacement location.

## Goals & Non-Goals

**Goals**:
- Replace all `/tmp/state.json` occurrences with `specs/tmp/state.json` in .opencode/ agent system
- Eliminate permission prompts in SELinux, AppArmor, container, and macOS environments
- Update all 85+ affected locations across 21 files
- Ensure all jq atomic write patterns use the new temporary location
- Verify no `/tmp/state.json` references remain after migration

**Non-Goals**:
- Modifying actual jq logic or state.json structure
- Changing the atomic write pattern itself (still using tmp + mv)
- Adding new functionality beyond path replacement
- Modifying system-wide /tmp usage outside .opencode/
- Creating new temporary directories (specs/tmp/ already exists)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Missing occurrences during grep | Medium | Low | Multi-pass verification with different grep patterns, including `/tmp/state.json` and `> /tmp/` |
| Syntax errors in shell scripts | High | Low | Use sed with dry-run first, verify each file after edit |
| Breaking existing workflows | High | Low | Maintain identical atomic pattern (jq > tmp && mv), only change path |
| specs/tmp/ directory missing | High | Low | Verify directory exists at start, create if needed |
| Race conditions with concurrent access | Low | Low | specs/tmp/ is user-owned like /tmp, same atomic semantics apply |
| Partial migration leaving mixed patterns | Medium | Low | Systematic phase-by-phase approach with verification after each phase |

## Implementation Phases

### Phase 1: Core Commands [COMPLETED]

**Goal**: Update the 4 core command files (14 occurrences total)

**Tasks**:
- [ ] Edit `.opencode/commands/research.md` - 4 occurrences
- [ ] Edit `.opencode/commands/implement.md` - 4 occurrences
- [ ] Edit `.opencode/commands/plan.md` - 4 occurrences
- [ ] Edit `.opencode/commands/task.md` - 2 occurrences
- [ ] Verify each file has no remaining `/tmp/state.json` patterns
- [ ] Run grep to confirm phase 1 completion: `grep -r "/tmp/state.json" .opencode/commands/`

**Timing**: 30 minutes

**Verification**:
- All 4 files updated with `specs/tmp/state.json`
- Grep returns zero results for `/tmp/state.json` in commands/ directory

### Phase 2: Core Skills [COMPLETED]

**Goal**: Update 4 core skill files (12 occurrences total)

**Tasks**:
- [ ] Edit `.opencode/skills/skill-researcher/SKILL.md` - 3 occurrences
- [ ] Edit `.opencode/skills/skill-implementer/SKILL.md` - 4 occurrences
- [ ] Edit `.opencode/skills/skill-planner/SKILL.md` - 3 occurrences
- [ ] Edit `.opencode/skills/skill-task/SKILL.md` - 2 occurrences
- [ ] Verify each file has no remaining `/tmp/state.json` patterns
- [ ] Run grep to confirm phase 2 completion: `grep -r "/tmp/state.json" .opencode/skills/`

**Timing**: 25 minutes

**Verification**:
- All 4 core skill files updated
- Grep returns zero results for `/tmp/state.json` in skills/ directory (core only)

### Phase 3: Extension Skills [NOT STARTED]

**Goal**: Update 4 extension skill files (23+ occurrences total)

**Tasks**:
- [ ] Edit `.opencode/extensions/web/skills/skill-web-implementation/SKILL.md` - 8+ occurrences
- [ ] Edit `.opencode/extensions/web/skills/skill-web-research/SKILL.md` - 4 occurrences
- [ ] Edit `.opencode/extensions/nix/skills/skill-nix-implementation/SKILL.md` - 8+ occurrences
- [ ] Edit `.opencode/extensions/nix/skills/skill-nix-research/SKILL.md` - 3 occurrences
- [ ] Verify each file has no remaining `/tmp/state.json` patterns
- [ ] Run grep to confirm phase 3 completion: `grep -r "/tmp/state.json" .opencode/extensions/`

**Timing**: 35 minutes

**Verification**:
- All 4 extension skill files updated
- Grep returns zero results for `/tmp/state.json` in extensions/ directory

### Phase 4: Context Documentation [NOT STARTED]

**Goal**: Update 6 context documentation files (35+ occurrences total)

**Tasks**:
- [ ] Edit `.opencode/context/core/patterns/inline-status-update.md` - 11 occurrences
- [ ] Edit `.opencode/context/core/patterns/jq-escaping-workarounds.md` - 13 occurrences
- [ ] Edit `.opencode/context/core/patterns/file-metadata-exchange.md` - 2 occurrences
- [ ] Edit `.opencode/context/core/patterns/core-command-execution.sh` - 3 occurrences
- [ ] Edit `.opencode/context/core/orchestration/preflight-pattern.md` - 1 occurrence
- [ ] Edit `.opencode/context/core/orchestration/postflight-pattern.md` - 1 occurrence
- [ ] Verify each file has no remaining `/tmp/state.json` patterns
- [ ] Run grep to confirm phase 4 completion: `grep -r "/tmp/state.json" .opencode/context/`

**Timing**: 40 minutes

**Verification**:
- All 6 context documentation files updated
- Grep returns zero results for `/tmp/state.json` in context/ directory

### Phase 5: Postflight Scripts [NOT STARTED]

**Goal**: Update 3 postflight shell scripts (9 occurrences total)

**Tasks**:
- [ ] Edit `.opencode/scripts/postflight-research.sh` - 3 occurrences
- [ ] Edit `.opencode/scripts/postflight-plan.sh` - 3 occurrences
- [ ] Edit `.opencode/scripts/postflight-implement.sh` - 3 occurrences
- [ ] Verify each file has no remaining `/tmp/state.json` patterns
- [ ] Run grep to confirm phase 5 completion: `grep -r "/tmp/state.json" .opencode/scripts/`
- [ ] Test one script to ensure it still functions correctly with new path

**Timing**: 20 minutes

**Verification**:
- All 3 postflight scripts updated
- Grep returns zero results for `/tmp/state.json` in scripts/ directory
- At least one script tested for basic functionality

### Phase 6: Comprehensive Verification [NOT STARTED]

**Goal**: Ensure no `/tmp/state.json` references remain anywhere in .opencode/

**Tasks**:
- [ ] Run comprehensive grep: `grep -r "/tmp/state.json" .opencode/`
- [ ] Run pattern search for alternative patterns: `grep -rn "> /tmp/" .opencode/ | grep -E "(state\.json|\.json)"`
- [ ] Search for any hardcoded /tmp paths in jq commands: `grep -rn "jq.*> /tmp" .opencode/`
- [ ] Document any remaining occurrences with file paths and line numbers
- [ ] Fix any discovered remaining occurrences

**Timing**: 15 minutes

**Verification**:
- All grep searches return zero results
- No `/tmp/state.json` patterns remain in .opencode/ directory tree
- Document confirming clean state created

### Phase 7: Directory Verification and Testing [NOT STARTED]

**Goal**: Ensure specs/tmp/ directory exists and test the migration

**Tasks**:
- [ ] Verify `specs/tmp/` directory exists: `ls -la specs/tmp/`
- [ ] Create directory if missing: `mkdir -p specs/tmp/`
- [ ] Test jq atomic write pattern with new path:
  ```bash
  echo '{"test": true}' > specs/tmp/test.json
  jq '.test = false' specs/tmp/test.json > specs/tmp/test.json.tmp && mv specs/tmp/test.json.tmp specs/tmp/test.json
  cat specs/tmp/test.json
  rm specs/tmp/test.json
  ```
- [ ] Verify file permissions are correct (user-owned, writable)
- [ ] Document any permission issues

**Timing**: 10 minutes

**Verification**:
- specs/tmp/ directory exists and is user-owned
- Test jq pattern works correctly with new path
- No permission errors during test

### Phase 8: Final Review and State Update [NOT STARTED]

**Goal**: Complete final review and update task state

**Tasks**:
- [ ] Review all modified files for consistency
- [ ] Update specs/TODO.md task status to [COMPLETED]
- [ ] Update specs/state.json with completion timestamp
- [ ] Create summary of changes (files modified, occurrences replaced)
- [ ] Verify implementation plan status markers are correct
- [ ] Create completion summary document in summaries/ directory

**Timing**: 15 minutes

**Verification**:
- specs/TODO.md reflects completed status
- specs/state.json updated with completion information
- Summary document created listing all changes
- All status markers in this plan are correct

## Testing & Validation

- [ ] Phase 1 verification: Zero grep results in commands/ directory
- [ ] Phase 2 verification: Zero grep results in core skills/
- [ ] Phase 3 verification: Zero grep results in extensions/
- [ ] Phase 4 verification: Zero grep results in context/
- [ ] Phase 5 verification: Zero grep results in scripts/
- [ ] Phase 6 verification: Zero grep results in entire .opencode/ tree
- [ ] Directory verification: specs/tmp/ exists and is writable
- [ ] Functional test: jq atomic write pattern works with specs/tmp/ path
- [ ] Script test: At least one postflight script runs without errors
- [ ] Final grep: `grep -r "/tmp/state.json" .opencode/` returns nothing

## Artifacts & Outputs

- plans/implementation-001.md (this file)
- Modified files (21 total):
  - .opencode/commands/research.md
  - .opencode/commands/implement.md
  - .opencode/commands/plan.md
  - .opencode/commands/task.md
  - .opencode/skills/skill-researcher/SKILL.md
  - .opencode/skills/skill-implementer/SKILL.md
  - .opencode/skills/skill-planner/SKILL.md
  - .opencode/skills/skill-task/SKILL.md
  - .opencode/extensions/web/skills/skill-web-implementation/SKILL.md
  - .opencode/extensions/web/skills/skill-web-research/SKILL.md
  - .opencode/extensions/nix/skills/skill-nix-implementation/SKILL.md
  - .opencode/extensions/nix/skills/skill-nix-research/SKILL.md
  - .opencode/context/core/patterns/inline-status-update.md
  - .opencode/context/core/patterns/jq-escaping-workarounds.md
  - .opencode/context/core/patterns/file-metadata-exchange.md
  - .opencode/context/core/patterns/core-command-execution.sh
  - .opencode/context/core/orchestration/preflight-pattern.md
  - .opencode/context/core/orchestration/postflight-pattern.md
  - .opencode/scripts/postflight-research.sh
  - .opencode/scripts/postflight-plan.sh
  - .opencode/scripts/postflight-implement.sh
- summaries/implementation-summary-20260305.md (to be created)

## Rollback/Contingency

**If migration causes issues**:

1. **Immediate rollback**:
   ```bash
   # Use git to revert all changes
   git checkout -- .opencode/
   ```

2. **Partial rollback** (specific file):
   ```bash
   git checkout -- .opencode/commands/research.md
   ```

3. **If specs/tmp/ has issues**:
   - Verify directory ownership: `ls -ld specs/tmp/`
   - Fix permissions: `chmod 755 specs/tmp/`
   - Alternative: Create dedicated tmp directory in .opencode/ instead

4. **Emergency restoration**:
   - All changes are to documentation/command files (no binary changes)
   - Simple text replacement can restore original /tmp/state.json pattern
   - No database or state corruption risk

**Prevention measures**:
- Each phase is independent and can be rolled back separately
- All changes are simple string replacements (low risk)
- Atomic pattern (jq > tmp && mv) is preserved exactly
- Original pattern can be restored via reverse sed if needed
