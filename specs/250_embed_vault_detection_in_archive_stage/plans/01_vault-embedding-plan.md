# Implementation Plan: Task #250

- **Task**: 250 - Embed vault detection as inline check within skill-todo archive stage
- **Status**: [IMPLEMENTING]
- **Effort**: 2-3 hours
- **Dependencies**: None
- **Research Inputs**:
  - [01_vault-embedding-strategy.md](../reports/01_vault-embedding-strategy.md)
  - [02_team-research.md](../reports/02_team-research.md)
- **Artifacts**: plans/01_vault-embedding-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan addresses LLM stage-skipping behavior that caused vault detection (Stages 11-15) to be bypassed during /todo execution. The root cause is that separate stages with "skip if..." conditionals appear optional to the model. Research from both internal patterns (todo.md section 5.8) and external sources (Anthropic skills guide) converged on the same solution: embed vault detection as mandatory sub-steps within Stage 10 (ArchiveTasks) with unconditional bash output, then remove the now-redundant vault stages.

### Research Integration

Key findings integrated from both research reports:
- **F1**: Prompt instructions are suggestions; bash output creates mandatory context
- **F2**: Sub-steps within a stage are more reliable than separate stages (eliminates skip opportunities)
- **F3**: todo.md already implements vault correctly as subsection 5.8 - SKILL.md failed to mirror this
- **F4**: Unconditional output (both vault-needed and vault-not-needed cases) prevents "nothing output = step passed" reasoning
- **F5**: Pre-commit safety net provides defense-in-depth

## Goals & Non-Goals

**Goals**:
- Embed vault threshold detection as mandatory sub-step 9 within Stage 10
- Use CRITICAL annotation and unconditional bash output to force model attention
- Consolidate vault operations (confirmation, creation, renumbering, reset) as sub-steps 9.1-9.4
- Add pre-commit safety net in GitCommit stage
- Remove redundant vault stages 11-15, renumber remaining stages to 11-16
- Reduce SKILL.md from 21 stages to 16 stages

**Non-Goals**:
- Full stage consolidation (merging detection stages 3-4, reference stages 5-6, etc.) - deferred to future task
- Adding checkpoint tags to all stages - separate enhancement
- Testing with actual vault threshold (requires 1000+ tasks)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Embedded sub-steps still skipped | High | Medium | CRITICAL annotation + unconditional bash output + pre-commit safety net |
| Stage renumbering breaks references | Medium | Low | Update all references atomically in single phase |
| Pre-commit validation too strict | Low | Low | Only blocks when threshold exceeded AND vault not performed |
| Bash script errors | Medium | Low | Test script logic manually before embedding |

## Implementation Phases

### Phase 1: Create check-vault-threshold.sh script [COMPLETED]

**Goal**: Create standalone bash script for vault threshold detection with unconditional output

**Tasks**:
- [ ] Create `.claude/scripts/check-vault-threshold.sh`
- [ ] Read next_project_number from specs/state.json
- [ ] Output status for BOTH vault-needed and vault-not-needed cases
- [ ] Return exit code 0 for normal, 1 for vault threshold exceeded
- [ ] Make script executable

**Timing**: 15 minutes

**Files to modify**:
- `.claude/scripts/check-vault-threshold.sh` - Create new file

**Verification**:
- Script runs without error when sourced
- Outputs "Vault check: next_project_number=N (threshold: 1000)" for normal case
- Outputs "VAULT THRESHOLD EXCEEDED" banner for threshold case

---

### Phase 2: Embed vault check as sub-step 9 in Stage 10 [COMPLETED]

**Goal**: Replace TRANSITION directive with inline mandatory vault detection

**Tasks**:
- [ ] Find step 9 (current TRANSITION directive) in Stage 10 ArchiveTasks
- [ ] Replace with sub-step 9 "Vault Threshold Check (MANDATORY)"
- [ ] Add `**CRITICAL: ALWAYS EXECUTE - DO NOT SKIP**` annotation
- [ ] Embed bash block that calls check-vault-threshold.sh with unconditional output
- [ ] Add decision logic: "If output shows threshold exceeded, proceed to sub-step 9.1"

**Timing**: 20 minutes

**Files to modify**:
- `.claude/skills/skill-todo/SKILL.md` - Modify Stage 10 step 9

**Verification**:
- Stage 10 now contains sub-step 9 with CRITICAL annotation
- Bash block is embedded inline (not referencing external script)
- Both vault-needed and vault-not-needed paths have explicit output

---

### Phase 3: Move vault sub-operations as sub-steps 9.1-9.4 [COMPLETED]

**Goal**: Consolidate vault operations from Stages 12-15 into Stage 10 sub-steps

**Tasks**:
- [ ] Add sub-step 9.1: VaultConfirmation - copy content from Stage 12
- [ ] Add sub-step 9.2: CreateVault - copy content from Stage 13
- [ ] Add sub-step 9.3: RenumberTasks - copy content from Stage 14
- [ ] Add sub-step 9.4: ResetState - copy content from Stage 15
- [ ] Adjust variable references (vault_needed, vault_approved) for inline context
- [ ] Add "If vault_approved=false, skip to Stage 11" after sub-step 9.1

**Timing**: 30 minutes

**Files to modify**:
- `.claude/skills/skill-todo/SKILL.md` - Expand Stage 10 with sub-steps 9.1-9.4

**Verification**:
- All vault operation logic is now within Stage 10
- Sub-steps reference each other correctly
- User confirmation flow preserved in sub-step 9.1

---

### Phase 4: Add checkpoint to Stage 10 [COMPLETED]

**Goal**: Add completion criteria using checkpoint pattern

**Tasks**:
- [ ] Add checkpoint attribute to Stage 10 closing tag
- [ ] Define completion criteria: "vault_check_complete output present, all archive operations logged"
- [ ] Add checkpoint comment after sub-step 9.4

**Timing**: 10 minutes

**Files to modify**:
- `.claude/skills/skill-todo/SKILL.md` - Add checkpoint to Stage 10

**Verification**:
- Stage 10 has checkpoint defining completion criteria
- Checkpoint is placed after all sub-steps

---

### Phase 5: Add pre-commit safety net to GitCommit stage [COMPLETED]

**Goal**: Block commits if vault threshold exceeded but vault not performed

**Tasks**:
- [ ] Find Stage 20 (GitCommit) in SKILL.md
- [ ] Add pre-commit validation bash block before `git add -A`
- [ ] Check if next_project_number > 1000 AND vault_count unchanged
- [ ] Exit with error message if validation fails
- [ ] Add clear guidance to return to Stage 10 vault sub-steps

**Timing**: 15 minutes

**Files to modify**:
- `.claude/skills/skill-todo/SKILL.md` - Modify Stage 20 (will become Stage 15 after renumbering)

**Verification**:
- GitCommit stage has pre-commit validation block
- Error message clearly indicates vault operation required
- Validation uses correct state.json fields

---

### Phase 6: Remove redundant vault stages 11-15 and renumber [COMPLETED]

**Goal**: Remove now-redundant vault stages and renumber remaining stages

**Tasks**:
- [ ] Delete Stage 11 (DetectVaultThreshold) - logic moved to Stage 10 sub-step 9
- [ ] Delete Stage 12 (VaultConfirmation) - logic moved to sub-step 9.1
- [ ] Delete Stage 13 (CreateVault) - logic moved to sub-step 9.2
- [ ] Delete Stage 14 (RenumberTasks) - logic moved to sub-step 9.3
- [ ] Delete Stage 15 (ResetState) - logic moved to sub-step 9.4
- [ ] Renumber Stage 16 -> Stage 11 (UpdateRoadmap)
- [ ] Renumber Stage 17 -> Stage 12 (UpdateREADME)
- [ ] Renumber Stage 18 -> Stage 13 (UpdateChangelog)
- [ ] Renumber Stage 19 -> Stage 14 (CreateMemories)
- [ ] Renumber Stage 20 -> Stage 15 (GitCommit)
- [ ] Renumber Stage 21 -> Stage 16 (OutputResults)
- [ ] Update any cross-stage references within the file

**Timing**: 20 minutes

**Files to modify**:
- `.claude/skills/skill-todo/SKILL.md` - Remove stages, renumber remaining

**Verification**:
- SKILL.md has exactly 16 stages (reduced from 21)
- Stage IDs are consecutive 1-16
- No dangling references to old stage numbers
- Total line count reduced appropriately

---

### Phase 7: Verification and testing [COMPLETED]

**Goal**: Verify the implementation is correct and complete

**Tasks**:
- [ ] Read modified SKILL.md and verify structure
- [ ] Verify Stage 10 contains all vault sub-steps (9, 9.1, 9.2, 9.3, 9.4)
- [ ] Verify CRITICAL annotation is present on sub-step 9
- [ ] Verify pre-commit safety net is in Stage 15 (GitCommit)
- [ ] Verify stage count is 16
- [ ] Check for any remaining references to old stage numbers (11-21 should not exist except as renumbered)

**Timing**: 10 minutes

**Files to modify**:
- None (verification only)

**Verification**:
- All checks pass
- SKILL.md is well-formed
- Implementation matches research recommendations

---

## Testing & Validation

- [ ] Read final SKILL.md and verify 16 stages
- [ ] Verify Stage 10 sub-step 9 has CRITICAL annotation
- [ ] Verify bash output is unconditional (both paths produce output)
- [ ] Verify Stage 15 (GitCommit) has pre-commit validation
- [ ] Grep for references to stages 17-21 (should find none)
- [ ] Grep for "skip if vault_needed" at stage level (should find none)

## Artifacts & Outputs

- `.claude/scripts/check-vault-threshold.sh` - Standalone vault check script
- `.claude/skills/skill-todo/SKILL.md` - Modified skill with embedded vault detection

## Rollback/Contingency

If the implementation causes issues:
1. Revert SKILL.md to previous version via git
2. The original 21-stage structure will be restored
3. Vault detection will revert to separate Stage 11
4. Delete check-vault-threshold.sh if created

Git provides clean rollback path since all changes are in tracked files.
