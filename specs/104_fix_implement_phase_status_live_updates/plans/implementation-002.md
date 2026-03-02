# Implementation Plan: Task #104

- **Task**: 104 - Fix /implement phase status live updates
- **Version**: 002 (revised)
- **Status**: [NOT STARTED]
- **Effort**: 3-4 hours
- **Dependencies**: None
- **Research Inputs**: [research-002.md](../reports/research-002.md), [research-003.md](../reports/research-003.md)
- **Artifacts**: plans/implementation-002.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This revised plan incorporates findings from research-003.md, which examined the ProofChecker `.claude/` system. The key architectural improvement is a **centralized helper script** for plan-level status updates instead of distributed sed patterns in each skill. This provides single-point maintenance, built-in verification, and idempotency checking.

**Architecture (Two-Domain Separation)**:
| Domain | Location | Who Updates | How Updated |
|--------|----------|-------------|-------------|
| Plan-level | `- **Status**: [STATUS]` (metadata) | Skills (preflight/postflight) | Centralized `update-plan-status.sh` |
| Phase-level | `### Phase N: Name [STATUS]` (heading) | Agents (Stage 4 loop) | Edit tool with exact heading match |

**Key Changes from v001**:
- **New Phase 1**: Create centralized `update-plan-status.sh` helper script
- **Simplified Phases 2-3**: Skills call the helper script instead of inline sed
- **Retained Phase 5-6**: Agent instructions and verification remain essential

## Goals & Non-Goals

**Goals**:
- Create a centralized, testable plan status update script
- Eliminate distributed sed patterns across 4 skills and 1 command
- Enforce heading-only phase status through agent instructions
- Maintain backward compatibility with existing dual-status plans

**Non-Goals**:
- Changing `[IMPLEMENTING]` to `[IN PROGRESS]` at plan level (research-003 recommends against due to 20+ file impact and semantic confusion with phase-level `[IN PROGRESS]`)
- Migrating existing plans to remove their stale per-phase `**Status**:` lines

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Script not found during skill execution | High | Low | Use PROJECT_DIR-relative path; verify script exists at skill preflight |
| Old plans have per-phase `**Status**:` lines | Low | High | After template fix, only one `**Status**:` line will exist; legacy plans have stale lines that are harmless |
| Script fails silently | Medium | Low | Script outputs the updated file path on success, empty on failure; skills can check return |

## Implementation Phases

### Phase 1: Create Centralized Plan Status Script [NOT STARTED]

**Goal**: Create `.claude/scripts/update-plan-status.sh` to handle all plan-level status updates from a single location.

**Estimated effort**: 1 hour

**Files to create**:
- `.claude/scripts/update-plan-status.sh` - New centralized helper script

**Script Requirements**:
1. Accept arguments: `$1` = task_number, `$2` = project_name, `$3` = target_status
2. Discover plan file: `specs/${padded_num}_${project_name}/plans/implementation-*.md` (latest version)
3. Map status strings: `IMPLEMENTING`, `COMPLETED`, `PARTIAL`, `NOT STARTED`
4. Idempotency: Skip if already at target status
5. Update: Use first-match sed to update only the plan-level `- **Status**: [...]` line
6. Verify: Confirm the update succeeded, output the file path on success

**Script Template**:
```bash
#!/usr/bin/env bash
# update-plan-status.sh - Centralized plan-level status update
# Usage: .claude/scripts/update-plan-status.sh TASK_NUMBER PROJECT_NAME STATUS
#
# STATUS values: IMPLEMENTING, COMPLETED, PARTIAL, NOT_STARTED
# Outputs: Updated plan file path on success, empty on failure/no-op

set -euo pipefail

task_number="${1:-}"
project_name="${2:-}"
new_status="${3:-}"

# Validate inputs
if [[ -z "$task_number" || -z "$project_name" || -z "$new_status" ]]; then
    echo "Usage: $0 TASK_NUMBER PROJECT_NAME STATUS" >&2
    exit 1
fi

# Normalize status
case "$new_status" in
    IMPLEMENTING|implementing) new_status="IMPLEMENTING" ;;
    COMPLETED|completed) new_status="COMPLETED" ;;
    PARTIAL|partial) new_status="PARTIAL" ;;
    NOT_STARTED|not_started) new_status="NOT STARTED" ;;
    *) echo "Unknown status: $new_status" >&2; exit 1 ;;
esac

# Find plan file (padded directory)
padded_num=$(printf "%03d" "$task_number")
plan_dir="specs/${padded_num}_${project_name}/plans"

if [[ ! -d "$plan_dir" ]]; then
    # Try unpadded (legacy)
    plan_dir="specs/${task_number}_${project_name}/plans"
fi

if [[ ! -d "$plan_dir" ]]; then
    echo "Plan directory not found for task $task_number" >&2
    exit 1
fi

# Get latest plan file
plan_file=$(ls -t "$plan_dir"/implementation-*.md 2>/dev/null | head -1)
if [[ -z "$plan_file" ]]; then
    echo "No plan file found in $plan_dir" >&2
    exit 1
fi

# Check current status (idempotency)
current_status=$(grep -m1 "^- \*\*Status\*\*:" "$plan_file" | sed 's/.*\[\([^]]*\)\].*/\1/' || echo "")
if [[ "$current_status" == "$new_status" ]]; then
    # Already at target, no-op
    exit 0
fi

# Update plan-level status (first match only)
sed -i "0,/^- \*\*Status\*\*: \[.*\]/{s/^- \*\*Status\*\*: \[.*\]$/- **Status**: [${new_status}]/}" "$plan_file"

# Verify update
updated_status=$(grep -m1 "^- \*\*Status\*\*:" "$plan_file" | sed 's/.*\[\([^]]*\)\].*/\1/' || echo "")
if [[ "$updated_status" == "$new_status" ]]; then
    echo "$plan_file"
else
    echo "Failed to update status in $plan_file" >&2
    exit 1
fi
```

**Verification**:
- Script is executable: `chmod +x .claude/scripts/update-plan-status.sh`
- Test with sample plan: creates test file, runs script, verifies only plan-level status changed
- Test idempotency: running twice outputs nothing on second run

---

### Phase 2: Fix Plan Templates [NOT STARTED]

**Goal**: Align artifact-formats.md with plan-format.md so new plans have heading-only phase status.

**Estimated effort**: 0.5 hours

**Files to modify**:
- `.claude/rules/artifact-formats.md` - Remove per-phase `**Status**: [NOT STARTED]`, add `[NOT STARTED]` to heading

**Steps**:
1. Read `.claude/rules/artifact-formats.md` and locate the phase template (around line 95)
2. Change `### Phase 1: {Name}` to `### Phase 1: {Name} [NOT STARTED]`
3. Remove the `**Status**: [NOT STARTED]` line beneath it
4. Verify planner-agent.md already uses heading-only format (it should)

**Verification**:
- `grep -A2 "### Phase 1:" .claude/rules/artifact-formats.md` shows heading with `[NOT STARTED]`, no `**Status**:` line following

---

### Phase 3: Update Skills to Use Centralized Script [NOT STARTED]

**Goal**: Replace distributed sed patterns in all 4 implementation skills with calls to the centralized script.

**Estimated effort**: 1 hour

**Files to modify**:
- `.claude/skills/skill-implementer/SKILL.md` - Preflight and postflight
- `.claude/skills/skill-neovim-implementation/SKILL.md` - Preflight and postflight
- `.claude/skills/skill-latex-implementation/SKILL.md` - Preflight and postflight
- `.claude/skills/skill-typst-implementation/SKILL.md` - Preflight and postflight

**Steps for each skill**:

1. **Preflight (Stage 2)**: Replace sed commands with script call
   ```bash
   # Before (distributed sed):
   sed -i "s/^\- \*\*Status\*\*: \[.*\]$/- **Status**: [IMPLEMENTING]/" "$plan_file"

   # After (centralized script):
   .claude/scripts/update-plan-status.sh "$task_number" "$project_name" "IMPLEMENTING"
   ```

2. **Postflight COMPLETED (Stage 7)**: Replace sed commands with script call
   ```bash
   # Before:
   sed -i 's/^\- \*\*Status\*\*: \[.*\]$/- **Status**: [COMPLETED]/' "$plan_file"

   # After:
   .claude/scripts/update-plan-status.sh "$task_number" "$project_name" "COMPLETED"
   ```

3. **Postflight PARTIAL (Stage 7)**: Replace sed commands with script call
   ```bash
   # Before:
   sed -i 's/^\- \*\*Status\*\*: \[.*\]$/- **Status**: [PARTIAL]/' "$plan_file"

   # After:
   .claude/scripts/update-plan-status.sh "$task_number" "$project_name" "PARTIAL"
   ```

**Verification**:
- `grep -c "update-plan-status.sh" .claude/skills/skill-*/SKILL.md` shows 4 skills use the script
- `grep "sed.*Status.*IMPLEMENTING" .claude/skills/` returns empty (no remaining distributed sed)

---

### Phase 4: Update Command GATE OUT [NOT STARTED]

**Goal**: Replace the /implement command's defensive sed with a call to the centralized script.

**Estimated effort**: 0.25 hours

**Files to modify**:
- `.claude/commands/implement.md` - GATE OUT section

**Steps**:
1. Locate GATE OUT (CHECKPOINT 2) defensive status correction (around lines 140-145)
2. Replace sed commands with script call:
   ```bash
   # Before:
   sed -i 's/^\- \*\*Status\*\*: \[.*\]$/- **Status**: [COMPLETED]/' "$plan_file"

   # After:
   .claude/scripts/update-plan-status.sh "$task_number" "$project_name" "COMPLETED"
   ```

**Verification**:
- `grep "update-plan-status.sh" .claude/commands/implement.md` shows script usage
- No remaining `sed.*Status.*COMPLETED` patterns in implement.md

---

### Phase 5: Clarify Agent Phase Status Instructions [NOT STARTED]

**Goal**: Update all 4 implementation agents to provide explicit Edit tool patterns for phase heading status.

**Estimated effort**: 0.75 hours

**Files to modify**:
- `.claude/agents/general-implementation-agent.md` - Stage 4 sections A and D
- `.claude/agents/neovim-implementation-agent.md` - Stage 4 sections A and D
- `.claude/agents/latex-implementation-agent.md` - Stage 4 sections A and D
- `.claude/agents/typst-implementation-agent.md` - Stage 4 sections A and D

**Steps for each agent**:

1. **Section A (Mark Phase In Progress)**: Replace ambiguous instruction:
   ```markdown
   **A. Mark Phase In Progress**
   Edit plan file heading to show the phase is active.
   Use the Edit tool with:
   - old_string: `### Phase {P}: {Phase Name} [NOT STARTED]`
   - new_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`

   Phase status lives ONLY in the heading. Do NOT add or edit a separate `**Status**:` line per phase.
   ```

2. **Section D (Mark Phase Complete)**: Replace ambiguous instruction:
   ```markdown
   **D. Mark Phase Complete**
   Edit plan file heading to show the phase is finished.
   Use the Edit tool with:
   - old_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`
   - new_string: `### Phase {P}: {Phase Name} [COMPLETED]`

   Phase status lives ONLY in the heading. Do NOT add or edit a separate `**Status**:` line per phase.
   ```

**Verification**:
- All 4 agent files contain explicit `old_string`/`new_string` patterns
- "Phase status lives ONLY in the heading" appears in all 4 agents
- No agent mentions updating a `**Status**:` line for individual phases

---

### Phase 6: Verification and Testing [NOT STARTED]

**Goal**: Validate the complete fix with comprehensive testing.

**Estimated effort**: 0.5 hours

**Steps**:

1. **Test centralized script directly**:
   ```bash
   # Create test plan with dual-status format
   mkdir -p /tmp/specs/104_test/plans
   cat > /tmp/specs/104_test/plans/implementation-001.md << 'EOF'
   # Test Plan
   - **Status**: [NOT STARTED]

   ### Phase 1: Test [NOT STARTED]
   **Status**: [NOT STARTED]

   ### Phase 2: Another [NOT STARTED]
   **Status**: [NOT STARTED]
   EOF

   # Test IMPLEMENTING update
   (cd /tmp && .claude/scripts/update-plan-status.sh 104 test "IMPLEMENTING")
   grep "Status" /tmp/specs/104_test/plans/implementation-001.md
   # Expected: Plan-level shows [IMPLEMENTING], per-phase lines unchanged
   ```

2. **Verify no distributed sed patterns remain**:
   ```bash
   grep -rn 'sed.*Status.*IMPLEMENTING\|sed.*Status.*COMPLETED\|sed.*Status.*PARTIAL' \
     .claude/skills/ .claude/commands/implement.md
   # Expected: empty (all removed)
   ```

3. **Verify script usage in skills**:
   ```bash
   grep -c "update-plan-status.sh" .claude/skills/skill-*/SKILL.md .claude/commands/implement.md
   # Expected: 5 files (4 skills + 1 command)
   ```

4. **Verify artifact-formats.md template**:
   ```bash
   grep -A2 "### Phase 1:" .claude/rules/artifact-formats.md
   # Expected: heading with [NOT STARTED], no **Status**: line
   ```

5. **Verify agent instructions**:
   ```bash
   grep -c "Phase status lives ONLY in the heading" .claude/agents/*-implementation-agent.md
   # Expected: 4 (one per agent)
   ```

## Testing & Validation

- [ ] `update-plan-status.sh` creates successfully and is executable
- [ ] Script updates only plan-level status in test file with dual-status format
- [ ] Script is idempotent (second run returns empty, doesn't modify file)
- [ ] artifact-formats.md template has status in heading only
- [ ] All 4 skill files call `update-plan-status.sh` instead of inline sed
- [ ] implement.md GATE OUT calls `update-plan-status.sh`
- [ ] All 4 agent files have explicit heading-based Edit patterns
- [ ] No distributed `sed.*Status.*IMPLEMENTING|COMPLETED|PARTIAL` patterns remain

## Artifacts & Outputs

- Created `.claude/scripts/update-plan-status.sh` - Centralized plan status helper
- Modified `.claude/rules/artifact-formats.md` - Heading-only phase template
- Modified `.claude/skills/skill-implementer/SKILL.md` - Uses centralized script
- Modified `.claude/skills/skill-neovim-implementation/SKILL.md` - Uses centralized script
- Modified `.claude/skills/skill-latex-implementation/SKILL.md` - Uses centralized script
- Modified `.claude/skills/skill-typst-implementation/SKILL.md` - Uses centralized script
- Modified `.claude/commands/implement.md` - Uses centralized script
- Modified `.claude/agents/general-implementation-agent.md` - Explicit heading status edits
- Modified `.claude/agents/neovim-implementation-agent.md` - Explicit heading status edits
- Modified `.claude/agents/latex-implementation-agent.md` - Explicit heading status edits
- Modified `.claude/agents/typst-implementation-agent.md` - Explicit heading status edits

## Rollback/Contingency

All changes are to markdown instruction files and one new bash script. Rollback via `git checkout`. The centralized script approach is safer than distributed sed because:
1. Single point of change for any future status marker modifications
2. Built-in verification catches failures immediately
3. Idempotency prevents double-updates
