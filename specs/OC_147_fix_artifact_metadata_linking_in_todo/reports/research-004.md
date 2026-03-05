# Research Report: OC_147 - Fix Artifact Metadata Linking in TODO.md

**Task**: OC_147 - Fix artifact metadata linking in TODO.md  
**Started**: 2026-03-05T00:00:00Z  
**Completed**: 2026-03-05T01:30:00Z  
**Effort**: 4 hours  
**Dependencies**: None  
**Sources/Inputs**: 
- .claude/skills/skill-researcher/SKILL.md (lines 158-251)
- .claude/skills/skill-planner/SKILL.md (lines 165-258)
- .opencode/skills/skill-researcher/SKILL.md
- .opencode/skills/skill-planner/SKILL.md
- .opencode/skills/skill-implementer/SKILL.md
- .opencode/context/core/patterns/file-metadata-exchange.md
- .opencode/context/core/patterns/postflight-control.md
- .opencode/context/core/patterns/jq-escaping-workarounds.md
- specs/state.json (current state)
- specs/TODO.md (current state)
- All orphaned .return-meta.json files (5 found)

**Artifacts**: 
- This report: specs/OC_147_fix_artifact_metadata_linking_in_todo/reports/research-004.md

**Standards**: report-format.md

---

## Executive Summary

After running `/plan 147`, the plan was created successfully BUT postflight operations failed to execute. This confirms the same systemic issue affects BOTH skill-researcher AND skill-planner in the .opencode/ system.

**Key Findings**:
1. **.claude/ skills have COMPLETE postflight implementations** (Stages 6-11 with detailed bash commands)
2. **.opencode/ skills have HIGH-LEVEL descriptions only** (Stages 1-4 with no executable details)
3. **5 orphaned .return-meta.json files** exist, indicating multiple tasks weren't properly processed
4. **The problem is structural**: .opencode/ skills describe WHAT to do but not HOW to do it
5. **No commits were made** for recent tasks because postflight git commit stage is missing executable instructions

**Recommended Approach**:
Update .opencode/ skills (skill-researcher, skill-planner, and potentially others) with detailed postflight implementations following the .claude/ pattern, including:
- Stage 5: Parse Subagent Return (Read Metadata File)
- Stage 6: Update Task Status (state.json + TODO.md)
- Stage 7: Link Artifacts (jq patterns with escaping workarounds)
- Stage 8: Git Commit
- Stage 9: Cleanup (remove marker and metadata files)

---

## Context & Scope

### Problem Statement
When workflow commands (`/research`, `/plan`, `/implement`) complete:
- Artifacts ARE created by subagents (reports, plans, summaries)
- `.return-meta.json` files ARE written by subagents
- BUT: state.json status is NOT updated (stays at "researching"/"planning")
- BUT: TODO.md artifact links are NOT added
- BUT: No git commits are made
- BUT: `.return-meta.json` files are NOT cleaned up

### Scope of Research
1. Compare .claude/ vs .opencode/ postflight implementations side-by-side
2. Identify ALL skills needing postflight fixes
3. Document exact missing steps for each skill
4. Count orphaned metadata files as evidence
5. Analyze why commits aren't happening
6. Recommend systemic fix approach

---

## Findings

### Finding 1: Side-by-Side Comparison - .claude/ vs .opencode/

| Stage | .claude/skill-researcher | .opencode/skill-researcher |
|-------|-------------------------|---------------------------|
| **Stage 1** | Input Validation (bash commands) | Load Context (description only) |
| **Stage 2** | Preflight Status Update (jq commands) | Preflight (description only) |
| **Stage 3** | Create Postflight Marker (bash heredoc) | Delegate (description only) |
| **Stage 4** | Prepare Delegation Context (JSON template) | Postflight (description only) |
| **Stage 5** | Invoke Subagent (Task tool details) | — |
| **Stage 6** | **Parse Subagent Return** (read metadata file, jq validation) | — |
| **Stage 7** | **Update Task Status** (state.json jq, TODO.md Edit) | — |
| **Stage 8** | **Link Artifacts** (two-step jq pattern, TODO.md update) | — |
| **Stage 9** | **Git Commit** (git add, git commit with session ID) | — |
| **Stage 10** | **Cleanup** (rm marker and metadata files) | — |
| **Stage 11** | Return Brief Summary | — |

**Critical Difference**:
- **.claude/**: 311 lines with executable bash/jq commands for all postflight stages
- **.opencode/**: 90 lines with only high-level descriptions, NO executable commands

### Finding 2: Detailed Postflight Steps Missing in .opencode/

#### Stage 6: Parse Subagent Return (MISSING in .opencode/)

**.claude/ implementation** (lines 158-174):
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

**.opencode/ status**: Only says "Read metadata file and update state + TODO" - no executable code.

#### Stage 7: Update Task Status (MISSING in .opencode/)

**.claude/ implementation** (lines 178-196):
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "researched" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    researched: $ts
  }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

**.opencode/ status**: Only says "Update state + TODO" - no jq commands provided.

#### Stage 8: Link Artifacts (MISSING in .opencode/)

**.claude/ implementation** (lines 199-225) - TWO-STEP jq pattern to avoid Issue #1132:
```bash
# Step 1: Filter out existing research artifacts
jq '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
    [(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "research" | not)]' \
  specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json

# Step 2: Add new research artifact
jq --arg path "$artifact_path" \
   --arg type "$artifact_type" \
   --arg summary "$artifact_summary" \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
  specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

**.opencode/ status**: Only says "Link research artifact" - no jq patterns provided.

#### Stage 9: Git Commit (MISSING in .opencode/)

**.claude/ implementation** (lines 228-239):
```bash
git add -A
git commit -m "task ${task_number}: complete research

Session: ${session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

**.opencode/ status**: Only says "Changes committed" - no git commands provided.

#### Stage 10: Cleanup (MISSING in .opencode/)

**.claude/ implementation** (lines 243-251):
```bash
rm -f "specs/${padded_num}_${project_name}/.postflight-pending"
rm -f "specs/${padded_num}_${project_name}/.postflight-loop-guard"
rm -f "specs/${padded_num}_${project_name}/.return-meta.json"
```

**.opencode/ status**: Only says "Clean up marker and metadata files" - no rm commands.

### Finding 3: Complete List of Skills Needing Fixes

| Skill | Has Detailed Postflight? | Status | Priority |
|-------|------------------------|--------|----------|
| skill-researcher | NO | High-level only | **CRITICAL** |
| skill-planner | NO | High-level only | **CRITICAL** |
| skill-implementer | PARTIAL | References patterns but no executable code | **HIGH** |
| skill-meta | NO | High-level only | **HIGH** |
| skill-neovim-research | PARTIAL | References patterns but no executable code | MEDIUM |
| skill-neovim-implementation | PARTIAL | References patterns but no executable code | MEDIUM |
| skill-remember | N/A | Direct execution (no subagent) | None |
| skill-learn | N/A | Direct execution (no subagent) | None |
| skill-refresh | N/A | Direct execution (no subagent) | None |
| skill-git-workflow | N/A | Direct execution (no subagent) | None |
| skill-status-sync | N/A | Direct execution (no subagent) | None |
| skill-orchestrator | N/A | Routing only (no subagent) | None |

**Summary**: 
- **4 skills need fixes** (skill-researcher, skill-planner, skill-implementer, skill-meta)
- **2 skills may need fixes** (skill-neovim-research, skill-neovim-implementation)
- **6 skills are direct execution** (no subagent delegation, no postflight needed)

### Finding 4: Orphaned .return-meta.json Files (Evidence of Failures)

Found **5 orphaned metadata files** that weren't cleaned up:

| Task | Status in File | Status in state.json | Artifacts in File | Artifacts in state.json | Issue |
|------|---------------|---------------------|-------------------|------------------------|-------|
| OC_147 | planned | **researched** | plan | research only | **Status mismatch!** |
| OC_146_research | researched | researched | research | research | **File not cleaned up** |
| OC_146_subagent | researched | researched | 2 research | 0 | **Artifacts not linked!** |
| 128 | planned | completed | plan | 4 artifacts | **Old file not cleaned** |
| 129 | planned | completed | plan | 4 artifacts | **Old file not cleaned** |

**Key Evidence**:
1. **OC_147**: `.return-meta.json` shows "planned" with plan artifact, but state.json shows "researched" with only research artifact - postflight didn't update state.json!
2. **OC_146_subagent**: Metadata file has 2 research artifacts, state.json has 0 - postflight artifact linking failed!
3. **Files not cleaned up**: All 5 files still exist when they should have been deleted after postflight

### Finding 5: Why Commits Aren't Happening

The git commit stage is **completely missing executable instructions** in .opencode/ skills:

**.claude/ has explicit commit commands**:
```bash
git add -A
git commit -m "task ${task_number}: complete research

Session: ${session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

**.opencode/ only has descriptions**:
- "Link research artifact and commit"
- "Changes committed"

Without executable git commands, no commits are made.

### Finding 6: Context Pattern Differences

**.claude/ skills** use:
- Explicit context file paths in frontmatter comments
- Detailed bash/jq code blocks for every stage
- Error handling with specific logging

**.opencode/ skills** use:
- `<context_injection>` XML blocks with variable names
- High-level stage descriptions only
- References to patterns like `{file_metadata}` and `{jq_workarounds}` but no executable code

**The Problem**: The .opencode/ pattern assumes the skill will load context files and execute patterns, but doesn't provide the actual executable commands to do so.

---

## Decisions

### Decision 1: Fix Approach - Add Detailed Postflight Stages

**Decision**: Update .opencode/ skills with detailed postflight implementations following the .claude/ pattern, adapted for the .opencode/ context injection system.

**Rationale**:
- The .claude/ pattern is proven to work (evidenced by commits in git log)
- The .opencode/ high-level descriptions are insufficient for execution
- Need to bridge the gap between "reference patterns" and "execute patterns"

### Decision 2: Skills to Fix - Priority Order

**Priority 1 (Critical)**:
1. skill-researcher - Currently broken, affects all research tasks
2. skill-planner - Currently broken, affects all planning tasks

**Priority 2 (High)**:
3. skill-implementer - May work partially, but needs verification
4. skill-meta - Affects meta task creation

**Priority 3 (Medium)**:
5. skill-neovim-research - Neovim-specific research
6. skill-neovim-implementation - Neovim-specific implementation

### Decision 3: Pattern for .opencode/ Postflight

**Decision**: Create a hybrid approach that:
1. Loads context files via `<context_injection>` (existing pattern)
2. Provides executable bash/jq commands in code blocks (new addition)
3. References injected context variables like `{file_metadata}` for configuration
4. Uses `{jq_workarounds}` patterns for artifact manipulation

**Example Structure**:
```markdown
### Stage 4: Postflight

Read metadata file and update state + TODO.

**Load Context**:
- Read `{file_metadata}` for metadata file handling patterns
- Read `{jq_workarounds}` for safe jq commands

**Execute Postflight**:

```bash
# Read metadata file
metadata_file="specs/${task_number}_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    # Extract fields using patterns from {file_metadata}
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    # ... etc
fi
```
```

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Adding postflight breaks existing functionality | Medium | High | Test with dry-run first, verify against .claude/ pattern |
| jq escaping issues (Issue #1132) | High | Medium | Use two-step jq pattern from {jq_workarounds} |
| Context injection variables not resolving | Medium | High | Test with actual context file reads |
| Git commit failures | Low | Low | Make commits non-blocking as in .claude/ |
| Marker file cleanup failures | Medium | Low | Add verification step before cleanup |
| Inconsistent TODO.md format updates | Medium | Medium | Use Edit tool with exact string matching |

---

## Recommendations

### Immediate Actions (OC_147 Implementation)

1. **Update skill-researcher/SKILL.md**:
   - Add Stage 5: Parse Subagent Return (read .return-meta.json)
   - Add Stage 6: Update Task Status (state.json jq commands)
   - Add Stage 7: Link Artifacts (two-step jq pattern)
   - Add Stage 8: Git Commit (git add, git commit)
   - Add Stage 9: Cleanup (rm marker and metadata files)

2. **Update skill-planner/SKILL.md**:
   - Same stages as skill-researcher, adapted for "planned" status
   - Use plan artifact type instead of research

3. **Verify skill-implementer/SKILL.md**:
   - Check if postflight is actually working
   - Add detailed stages if missing

4. **Clean up orphaned .return-meta.json files**:
   - Process any pending postflight operations
   - Delete files after verification

### Systemic Improvements

1. **Create reusable postflight scripts**:
   - `.opencode/scripts/postflight-research.sh`
   - `.opencode/scripts/postflight-plan.sh`
   - `.opencode/scripts/postflight-implement.sh`
   - Skills can call these scripts instead of inline commands

2. **Add postflight verification to skill-refresh**:
   - Detect orphaned .return-meta.json files
   - Report tasks that need manual postflight completion

3. **Document the postflight pattern**:
   - Add to context-loading-best-practices.md
   - Include examples of complete postflight implementations

4. **Add tests for postflight operations**:
   - Verify state.json updates
   - Verify TODO.md updates
   - Verify artifact linking
   - Verify git commits
   - Verify cleanup

---

## Appendix: Complete Postflight Stage Template

Based on .claude/ patterns, here is the complete postflight implementation that should be added to .opencode/ skills:

### Stage 5: Parse Subagent Return

```bash
# Derive metadata file path
metadata_file="specs/${task_number}_${project_name}/.return-meta.json"

# Validate and read metadata file
if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
    session_id_from_meta=$(jq -r '.metadata.session_id // ""' "$metadata_file")
else
    echo "Error: Invalid or missing metadata file at $metadata_file"
    status="failed"
fi
```

### Stage 6: Update Task Status

```bash
if [ "$status" = "researched" ] || [ "$status" = "planned" ] || [ "$status" = "completed" ]; then
    # Update state.json
    jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       --arg status "$status" \
      '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
        status: $status,
        last_updated: $ts,
        '$status': $ts
      }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
    
    # Update TODO.md status marker using Edit tool
    # Change [RESEARCHING]/[PLANNING]/[IMPLEMENTING] to [RESEARCHED]/[PLANNED]/[COMPLETED]
fi
```

### Stage 7: Link Artifacts

```bash
if [ -n "$artifact_path" ]; then
    # Step 1: Filter out existing artifacts of same type (use "| not" pattern)
    jq '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
        [(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "'$artifact_type'" | not)]' \
      specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json

    # Step 2: Add new artifact
    jq --arg path "$artifact_path" \
       --arg type "$artifact_type" \
       --arg summary "$artifact_summary" \
      '(.active_projects[] | select(.project_number == '$task_number')).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
      specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
fi

# Update TODO.md with artifact link
# Add: - **Research**: [research-{NNN}.md]({artifact_path})
# Or:  - **Plan**: [implementation-{NNN}.md]({artifact_path})
```

### Stage 8: Git Commit

```bash
# Stage all changes
git add -A

# Create commit with session ID
git commit -m "task ${task_number}: complete ${status}

Session: ${session_id}

Co-Authored-By: OpenCode <noreply@opencode.ai>"
```

### Stage 9: Cleanup

```bash
# Remove marker files
rm -f "specs/${task_number}_${project_name}/.postflight-pending"
rm -f "specs/${task_number}_${project_name}/.postflight-loop-guard"

# Remove metadata file
rm -f "$metadata_file"
```

---

## Summary

The root cause of the artifact metadata linking issue is that .opencode/ skills lack detailed postflight implementations. While .claude/ skills have 11 stages with executable bash/jq commands, .opencode/ skills only have 4 high-level stages with descriptions.

**The fix requires adding Stages 5-9** to skill-researcher and skill-planner (and potentially other skills) with:
1. Metadata file reading and validation
2. state.json status updates with jq
3. TODO.md status updates with Edit tool
4. Artifact linking with two-step jq pattern
5. Git commits with session IDs
6. Cleanup of marker and metadata files

**Evidence**: 5 orphaned .return-meta.json files prove postflight isn't executing properly.

**Impact**: Without this fix, all workflow commands will continue to:
- Leave status at "researching"/"planning" instead of updating to "researched"/"planned"
- Not link artifacts in TODO.md
- Not make git commits
- Leave orphaned metadata files
