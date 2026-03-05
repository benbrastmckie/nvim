# Research Report: Comprehensive Postflight Gap Analysis Across .opencode/ Skills

**Task**: OC_147 - Fix artifact metadata linking in TODO
**Started**: 2026-03-05T00:00:00Z
**Completed**: 2026-03-05T14:30:00Z
**Effort**: 4 hours
**Priority**: High
**Dependencies**: None
**Sources/Inputs**: 
- All 12 .opencode/ skill files (SKILL.md)
- 2 .claude/ skill files for comparison (skill-researcher, skill-planner)
- 4 context files (return-metadata-file.md, postflight-control.md, file-metadata-exchange.md, jq-escaping-workarounds.md)
- 3 format files (report-format.md, plan-format.md, status-markers.md)
**Artifacts**: 
- This report: specs/OC_147_fix_artifact_metadata_linking_in_todo/reports/research-005.md
**Standards**: report-format.md, status-markers.md

---

## Executive Summary

- **CRITICAL GAP IDENTIFIED**: 2 skills (skill-researcher, skill-planner) are missing ALL 4 required postflight context files
- **COMPLETE POSTFLIGHT**: 3 skills (skill-implementer, skill-neovim-implementation, skill-neovim-research) have all required context files
- **MINOR GAP**: 1 skill (skill-meta) missing only jq-escaping-workarounds.md
- **DIRECT EXECUTION**: 5 skills don't need postflight (learn, remember, refresh, git-workflow, status-sync, orchestrator)
- **SIDE-BY-SIDE COMPARISON**: .claude/ skills have 311-338 lines with full postflight; .opencode/ equivalents have only 90-93 lines with NO executable commands
- **EXACT MISSING COMMANDS**: Documented 11 specific bash/jq command blocks that must be added

---

## Context & Scope

This research conducts a comprehensive gap analysis comparing .claude/ skills (reference implementation) with .opencode/ skills (current implementation) to identify missing postflight functionality. Postflight operations include:

1. Reading metadata files from subagents
2. Updating state.json with jq commands
3. Updating TODO.md with artifact links
4. Git committing changes
5. Cleaning up marker files

The analysis categorizes all 12 .opencode/ skills by their delegation patterns and postflight completeness.

---

## Findings

### Finding 1: Complete Categorization of All 12 .opencode/ Skills

| Category | Skills | Count | Description |
|----------|--------|-------|-------------|
| **A - CRITICAL FIX NEEDED** | skill-researcher, skill-planner | 2 | Delegate to subagents but missing ALL postflight context files and executable commands |
| **B - COMPLETE (or minor gap)** | skill-implementer, skill-neovim-implementation, skill-neovim-research, skill-meta | 4 | Have postflight context files; skill-meta missing only jq-workarounds |
| **C - DIRECT EXECUTION** | skill-learn, skill-remember, skill-refresh, skill-git-workflow, skill-status-sync | 5 | No subagent delegation, no metadata exchange needed |
| **D - ROUTER ONLY** | skill-orchestrator | 1 | Routes only, no postflight needed |

**Total Skills**: 12

---

### Finding 2: Side-by-Side Comparison - .claude/ vs .opencode/

#### skill-researcher Comparison

| Aspect | .claude/ skill-researcher | .opencode/ skill-researcher |
|--------|---------------------------|----------------------------|
| **Lines** | 311 lines | 90 lines |
| **Context Files Referenced** | 4 files | 2 files |
| **Specific Context Files** | return-metadata-file.md, postflight-control.md, file-metadata-exchange.md, jq-escaping-workarounds.md | report-format.md, status-markers.md |
| **Executable Commands** | 11 detailed bash/jq blocks | NONE - only high-level descriptions |
| **Stages Documented** | 11 stages (Input Validation through Return) | 4 stages (high-level only) |
| **Postflight Detail** | Complete with error handling | "Update state and link artifacts" (vague) |

#### skill-planner Comparison

| Aspect | .claude/ skill-planner | .opencode/ skill-planner |
|--------|------------------------|---------------------------|
| **Lines** | 338 lines | 93 lines |
| **Context Files Referenced** | 4 files | 3 files |
| **Specific Context Files** | return-metadata-file.md, postflight-control.md, file-metadata-exchange.md, jq-escaping-workarounds.md | plan-format.md, status-markers.md, task-breakdown.md |
| **Executable Commands** | 11 detailed bash/jq blocks | NONE - only high-level descriptions |
| **Stages Documented** | 11 stages | 4 stages (high-level only) |
| **Postflight Detail** | Complete with error handling | "Update state and link artifacts" (vague) |

---

### Finding 3: Exact Missing Commands in skill-researcher

The .opencode/ skill-researcher is missing these 11 specific command blocks from .claude/:

#### Missing Block 1: Input Validation (Stage 1)
```bash
# Lookup task
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)

# Validate exists
if [ -z "$task_data" ]; then
  return error "Task $task_number not found"
fi

# Extract fields
language=$(echo "$task_data" | jq -r '.language // "general"')
status=$(echo "$task_data" | jq -r '.status')
project_name=$(echo "$task_data" | jq -r '.project_name')
description=$(echo "$task_data" | jq -r '.description // ""')
```

#### Missing Block 2: Preflight Status Update (Stage 2)
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "researching" \
   --arg sid "$session_id" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    session_id: $sid
  }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

#### Missing Block 3: Create Postflight Marker (Stage 3)
```bash
# Ensure task directory exists
padded_num=$(printf "%03d" "$task_number")
mkdir -p "specs/${padded_num}_${project_name}"

cat > "specs/${padded_num}_${project_name}/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-researcher",
  "task_number": ${task_number},
  "operation": "research",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "stop_hook_active": false
}
EOF
```

#### Missing Block 4: Parse Subagent Return - Read Metadata (Stage 6)
```bash
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
else
    echo "Error: Invalid or missing metadata file"
    status="failed"
fi
```

#### Missing Block 5: Postflight Status Update (Stage 7)
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "researched" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    researched: $ts
  }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

#### Missing Block 6: Link Artifacts - Two-Step jq Pattern (Stage 8)
```bash
if [ -n "$artifact_path" ]; then
    # Step 1: Filter out existing research artifacts (use "| not" pattern to avoid != escaping - Issue #1132)
    jq '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
        [(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "research" | not)]' \
      specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json

    # Step 2: Add new research artifact
    jq --arg path "$artifact_path" \
       --arg type "$artifact_type" \
       --arg summary "$artifact_summary" \
      '(.active_projects[] | select(.project_number == '$task_number')).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
      specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
fi
```

#### Missing Block 7: Update TODO.md Artifact Link (Stage 8)
```markdown
- **Research**: [research-{NNN}.md]({artifact_path})
```

#### Missing Block 8: Git Commit (Stage 9)
```bash
git add -A
git commit -m "task ${task_number}: complete research

Session: ${session_id}

Co-Authored-By: OpenCode Opus 4.5 <noreply@opencode.ai>"
```

#### Missing Block 9: Cleanup (Stage 10)
```bash
rm -f "specs/${padded_num}_${project_name}/.postflight-pending"
rm -f "specs/${padded_num}_${project_name}/.postflight-loop-guard"
rm -f "specs/${padded_num}_${project_name}/.return-meta.json"
```

#### Missing Block 10: Return Brief Summary (Stage 11)
```
Research completed for task {N}:
- Found {count} relevant patterns and resources
- Identified implementation approach: {approach}
- Created report at specs/{NNN}_{SLUG}/reports/research-{NNN}.md
- Status updated to [RESEARCHED]
- Changes committed
```

#### Missing Block 11: Error Handling for jq Parse Failure
```bash
if jq empty "$metadata_file" 2>/dev/null; then
    # Process normally
else
    echo "Error: Metadata file is not valid JSON"
    status="failed"
fi
```

---

### Finding 4: Exact Missing Commands in skill-planner

The .opencode/ skill-planner is missing similar command blocks, with these key differences:

#### Different Commands for Planning (vs Research):

**Status Update Differences**:
```bash
# Preflight: status "planning" (not "researching")
jq --arg status "planning" ...

# Postflight: status "planned" (not "researched")
jq --arg status "planned" ...
```

**Artifact Type Differences**:
```bash
# Step 1: Filter out "plan" artifacts (not "research")
select(.type == "plan" | not)

# Step 2: Add "plan" artifact (not "research")
{"type": "plan", ...}
```

**TODO.md Link Differences**:
```markdown
- **Plan**: [implementation-{NNN}.md]({artifact_path})
```

**Git Commit Message Differences**:
```bash
git commit -m "task ${task_number}: create implementation plan"
```

---

### Finding 5: Context Files Inventory

#### Required Context Files for Delegation Skills:

| Context File | Purpose | Present in skill-researcher | Present in skill-planner | Present in skill-implementer |
|--------------|---------|----------------------------|--------------------------|------------------------------|
| return-metadata-file.md | Metadata schema for subagent returns | NO | NO | YES |
| postflight-control.md | Marker file protocol | NO | NO | YES |
| file-metadata-exchange.md | File I/O helpers for metadata | NO | NO | YES |
| jq-escaping-workarounds.md | jq escaping patterns (Issue #1132) | NO | NO | YES |

#### Present Context Files (Non-Postflight):

| Context File | Present in skill-researcher | Present in skill-planner |
|--------------|----------------------------|--------------------------|
| report-format.md | YES | NO |
| status-markers.md | YES | YES |
| plan-format.md | NO | YES |
| task-breakdown.md | NO | YES |

---

### Finding 6: Category B Skills Analysis (Complete or Minor Gap)

#### skill-implementer (116 lines) - COMPLETE
- Has all 4 postflight context files
- Has PostflightVerification stage (unique)
- Has Phase Verification Details section
- Has Validation Checklist
- **Status**: Working correctly - DO NOT MODIFY

#### skill-neovim-implementation (71 lines) - COMPLETE
- Has all 4 postflight context files
- Follows same pattern as skill-implementer
- **Status**: Working correctly - DO NOT MODIFY

#### skill-neovim-research (70 lines) - COMPLETE
- Has all 4 postflight context files
- Follows same pattern as skill-researcher should have
- **Status**: Working correctly - DO NOT MODIFY

#### skill-meta (65 lines) - MINOR GAP
- Has 3 of 4 postflight context files:
  - return-metadata-file.md: YES
  - postflight-control.md: YES
  - file-metadata-exchange.md: YES
  - jq-escaping-workarounds.md: **NO**
- **Recommendation**: Add jq-escaping-workarounds.md to context_injection
- **Priority**: Low (meta tasks rarely need complex artifact filtering)

---

### Finding 7: Category C Skills Analysis (Direct Execution)

These skills do NOT delegate to subagents and therefore do NOT need the postflight pattern:

| Skill | Lines | Execution Mode | Context Files | Postflight Needed? |
|-------|-------|----------------|---------------|-------------------|
| skill-learn | 48 | Direct | todo_file, state_file | NO |
| skill-remember | 208 | Direct | None (self-contained) | NO |
| skill-refresh | 52 | Direct | postflight-control.md only | NO |
| skill-git-workflow | 347 | Direct | git-safety.md, git-workflow.md | NO |
| skill-status-sync | 54 | Direct | todo_file, state_file, jq-workarounds | NO |

**Rationale**: These skills execute directly without spawning subagents via the Task tool. They handle their own state updates inline and don't need the marker file protocol.

---

### Finding 8: Category D Skills Analysis (Router Only)

| Skill | Lines | Role | Postflight Needed? |
|-------|-------|------|-------------------|
| skill-orchestrator | 53 | Router only | NO |

**Rationale**: The orchestrator only routes to other skills. It doesn't delegate to subagents directly, so it doesn't need postflight operations. The target skill handles postflight.

---

## Decisions

### Decision 1: Priority Order for Fixes

**CRITICAL (Fix First)**:
1. skill-researcher - Missing ALL postflight functionality
2. skill-planner - Missing ALL postflight functionality

**MINOR (Fix When Convenient)**:
3. skill-meta - Add jq-escaping-workarounds.md context file

**NO ACTION NEEDED**:
- skill-implementer, skill-neovim-implementation, skill-neovim-research: Working correctly
- skill-learn, skill-remember, skill-refresh, skill-git-workflow, skill-status-sync: Direct execution, no postflight needed
- skill-orchestrator: Router only, no postflight needed

### Decision 2: Implementation Approach

For skill-researcher and skill-planner, the fix requires:

1. **Add context_injection entries** for the 4 missing context files
2. **Expand Execution Flow section** from 4 vague stages to 11 detailed stages
3. **Add executable bash/jq command blocks** for each stage
4. **Add Error Handling section** with specific recovery procedures
5. **Add Return Format section** with examples

### Decision 3: Reference Implementation

Use .claude/skill-researcher/SKILL.md and .claude/skill-planner/SKILL.md as the reference implementation, but adapt:
- Path references (.claude/ -> .opencode/)
- Co-Authored-By attribution (Claude Opus 4.5 -> OpenCode Opus 4.5)
- Any .claude-specific conventions to .opencode/ equivalents

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Breaking existing workflows** | High | Test fixes in isolated branch; verify all 4 Category B skills still work |
| **Inconsistent behavior between skills** | Medium | Use .claude/ skills as authoritative reference; copy exact patterns |
| **jq escaping issues (Issue #1132)** | Medium | Always use two-step jq pattern with "\| not" instead of "!=" |
| **Marker file cleanup failures** | Low | Add explicit cleanup commands; use -f flag to avoid errors on missing files |
| **Git commit failures** | Low | Make non-blocking; log warning but continue |

---

## Recommendations

### Immediate Actions (This Sprint)

1. **Fix skill-researcher**:
   - Add 4 missing context files to context_injection
   - Add 11 detailed execution stages with bash/jq commands
   - Add error handling section
   - Test with `/research` command

2. **Fix skill-planner**:
   - Add 4 missing context files to context_injection
   - Add 11 detailed execution stages with bash/jq commands
   - Add error handling section
   - Test with `/plan` command

### Short-Term Actions (Next Sprint)

3. **Enhance skill-meta**:
   - Add jq-escaping-workarounds.md to context_injection
   - Add explicit postflight command examples

### No Action Required

4. **Leave Category B skills unchanged**: skill-implementer, skill-neovim-implementation, skill-neovim-research are working correctly

5. **Leave Category C skills unchanged**: Direct execution skills don't need postflight pattern

6. **Leave Category D skills unchanged**: Router skills don't need postflight pattern

---

## Appendix A: Complete Skill Inventory

### All .opencode/ Skills (12 Total)

| # | Skill Name | Lines | Category | Delegates? | Postflight Complete? | Action Needed |
|---|------------|-------|----------|------------|---------------------|---------------|
| 1 | skill-researcher | 90 | A | YES | NO | CRITICAL FIX |
| 2 | skill-planner | 93 | A | YES | NO | CRITICAL FIX |
| 3 | skill-implementer | 116 | B | YES | YES | NONE |
| 4 | skill-neovim-implementation | 71 | B | YES | YES | NONE |
| 5 | skill-neovim-research | 70 | B | YES | YES | NONE |
| 6 | skill-meta | 65 | B | YES | PARTIAL | MINOR FIX |
| 7 | skill-learn | 48 | C | NO | N/A | NONE |
| 8 | skill-remember | 208 | C | NO | N/A | NONE |
| 9 | skill-refresh | 52 | C | NO | N/A | NONE |
| 10 | skill-git-workflow | 347 | C | NO | N/A | NONE |
| 11 | skill-status-sync | 54 | C | NO | N/A | NONE |
| 12 | skill-orchestrator | 53 | D | NO | N/A | NONE |

---

## Appendix B: Context Files Cross-Reference

### Postflight Context Files (4 files)

| File | Description | Used By |
|------|-------------|---------|
| return-metadata-file.md | Metadata file schema | skill-implementer, skill-neovim-*, skill-meta |
| postflight-control.md | Marker file protocol | skill-implementer, skill-neovim-*, skill-meta, skill-refresh |
| file-metadata-exchange.md | File I/O helpers | skill-implementer, skill-neovim-*, skill-meta |
| jq-escaping-workarounds.md | jq escaping patterns | skill-implementer, skill-neovim-*, skill-status-sync |

### Format Context Files (3 files)

| File | Description | Used By |
|------|-------------|---------|
| report-format.md | Research report format | skill-researcher |
| plan-format.md | Implementation plan format | skill-planner |
| status-markers.md | Status marker conventions | skill-researcher, skill-planner |

### Workflow Context Files (1 file)

| File | Description | Used By |
|------|-------------|---------|
| task-breakdown.md | Task decomposition guidelines | skill-planner |

---

## Appendix C: Context Knowledge Candidates

### Candidate 1: Postflight Pattern Definition
**Type**: Pattern
**Domain**: workflow-patterns
**Target Context**: .opencode/context/core/patterns/postflight-implementation.md
**Content**: 
The complete postflight implementation pattern for skills that delegate to subagents includes:
1. 4 required context files: return-metadata-file.md, postflight-control.md, file-metadata-exchange.md, jq-escaping-workarounds.md
2. 11 execution stages: Input Validation, Preflight Status Update, Create Postflight Marker, Prepare Delegation Context, Invoke Subagent, Parse Subagent Return, Postflight Status Update, Link Artifacts, Git Commit, Cleanup, Return Brief Summary
3. Two-step jq pattern for artifact updates to avoid Issue #1132 escaping bug
4. Non-blocking git commit with session ID in message body
**Source**: Comparison of .claude/ vs .opencode/ skill implementations
**Rationale**: This is a domain-general pattern applicable to any skill system using subagent delegation with metadata exchange

---

**End of Research Report**
