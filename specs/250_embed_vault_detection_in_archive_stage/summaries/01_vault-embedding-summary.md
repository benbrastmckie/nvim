# Implementation Summary: Task #250

**Completed**: 2026-03-19
**Duration**: ~45 minutes

## Changes Made

Embedded vault detection as a mandatory sub-step within Stage 10 (ArchiveTasks) of skill-todo, with CRITICAL annotation and unconditional bash output. Removed redundant vault stages 11-15 and renumbered remaining stages.

### Root Cause Addressed

LLM stage-skipping behavior caused vault detection (separate stages 11-15) to be bypassed during /todo execution. The fix consolidates vault logic as sub-steps within the archive stage, making the operations mandatory rather than appearing optional to the model.

### Key Implementation Details

1. **Embedded vault check as sub-step 9** with:
   - `**CRITICAL: ALWAYS EXECUTE - DO NOT SKIP**` annotation
   - Unconditional bash output for both vault-needed and vault-not-needed cases
   - Clear decision logic directing to sub-steps or next stage

2. **Vault operations as sub-steps 9.1-9.4**:
   - 9.1: VaultConfirmation - user approval with renumbering preview
   - 9.2: CreateVault - directory creation and archive movement
   - 9.3: RenumberTasks - task number updates across state files
   - 9.4: ResetState - numbering reset and vault history tracking

3. **Pre-commit safety net** in Stage 15 (GitCommit):
   - Blocks commits if vault threshold exceeded but vault not performed
   - Clear error message directing back to Stage 10 sub-step 9

4. **Stage reduction**: 21 stages -> 16 stages

## Files Modified

- `.claude/scripts/check-vault-threshold.sh` - Created standalone vault check script (utility, may be removed)
- `.claude/skills/skill-todo/SKILL.md` - Modified skill with embedded vault detection:
  - Stage 10 expanded with sub-steps 9.1-9.4 and checkpoint attribute
  - Stages 11-15 (DetectVaultThreshold through ResetState) deleted
  - Stages 16-21 renumbered to 11-16
  - Pre-commit safety net added to Stage 15 (GitCommit)

## Verification

- Stage count: 16 (confirmed via grep)
- Stage IDs: Consecutive 1-16 (verified)
- CRITICAL annotation: Present at line 358
- Sub-steps 9.1-9.4: All present in Stage 10
- Pre-commit safety net: Present in Stage 15 at line 783
- No references to old stage numbers 17-21: Verified
- Check script: Tested successfully (exit code 0 for normal case)

## Notes

- The standalone script `check-vault-threshold.sh` was created per plan but the vault check is now embedded inline in the SKILL.md. The script remains as a utility that could be used for testing or external checks.
- This implementation follows the research findings from todo.md section 5.8 and Anthropic skills guide patterns for forcing model attention via unconditional bash output.
- Defense-in-depth is provided by the pre-commit safety net, which catches any case where the model still skips the vault check despite the mandatory annotations.
