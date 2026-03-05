# Implementation Plan: Fix Artifact Metadata Linking in TODO

- **Task**: OC_147 - fix_artifact_metadata_linking_in_todo
- **Status**: [NOT STARTED]
- **Effort**: 4.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/OC_147_fix_artifact_metadata_linking_in_todo/reports/research-005.md
- **Artifacts**: plans/implementation-002.md (this file)
- **Standards**:
  - .opencode/context/core/formats/plan-format.md
  - .opencode/context/core/standards/status-markers.md
  - .opencode/context/core/standards/documentation-standards.md
  - .opencode/context/core/standards/task-management.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Fix the postflight stages in skill-researcher and skill-planner to properly update state.json, link artifacts in TODO.md, make git commits, and cleanup metadata files. The current skills have vague descriptions like "Update state and link artifacts" but lack the actual executable bash/jq commands needed for proper artifact metadata linking.

### Research Integration

This plan integrates findings from research-005.md which identified:
- skill-researcher and skill-planner are MISSING 4 critical context files from context_injection
- Both skills lack 11 specific executable command blocks present in .claude/ reference versions
- The missing commands cover: metadata parsing, state updates, TODO.md updates, artifact linking, git commits, and cleanup

## Goals & Non-Goals

**Goals**:
- Add missing context files to skill-researcher and skill-planner context_injection sections
- Add detailed executable bash/jq commands to postflight stages in both skills
- Ensure status transitions update both state.json and TODO.md
- Implement proper artifact linking with two-step jq patterns
- Add git commit commands with proper session ID formatting
- Add cleanup commands for marker and metadata files

**Non-Goals**:
- Do NOT modify skills in Category B, C, or D (they work correctly)
- Do NOT change the overall skill architecture or delegation patterns
- Do NOT add new features beyond fixing the existing postflight gaps

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| jq escaping issues (Issue #1132) | High | Medium | Use two-step jq pattern with `\| not` instead of `!=` |
| Breaking existing skill functionality | High | Low | Make additive changes only, preserve existing structure |
| TODO.md edit conflicts | Medium | Low | Use precise Edit tool with unique string matching |
| Git commit failures | Low | Low | Make git commit non-blocking, log failures but continue |

## Implementation Phases

### Phase 1: Add Missing Context Files to skill-researcher [COMPLETED]

**Goal**: Add the 4 missing context files to skill-researcher's context_injection section

**Tasks**:
- [ ] Read current skill-researcher/SKILL.md to verify structure
- [ ] Add `return-metadata-file.md` to context_injection
- [ ] Add `postflight-control.md` to context_injection
- [ ] Add `file-metadata-exchange.md` to context_injection
- [ ] Add `jq-escaping-workarounds.md` to context_injection
- [ ] Verify all 4 files are properly referenced with correct variable names

**Timing**: 45 minutes

**Files Modified**:
- `.opencode/skills/skill-researcher/SKILL.md`

---

### Phase 2: Add Missing Context Files to skill-planner [COMPLETED]

**Goal**: Add the 4 missing context files to skill-planner's context_injection section

**Tasks**:
- [ ] Read current skill-planner/SKILL.md to verify structure
- [ ] Add `return-metadata-file.md` to context_injection
- [ ] Add `postflight-control.md` to context_injection
- [ ] Add `file-metadata-exchange.md` to context_injection
- [ ] Add `jq-escaping-workarounds.md` to context_injection
- [ ] Verify all 4 files are properly referenced with correct variable names

**Timing**: 45 minutes

**Files Modified**:
- `.opencode/skills/skill-planner/SKILL.md`

---

### Phase 3: Add Detailed Postflight Commands to skill-researcher [COMPLETED]

**Goal**: Replace vague postflight descriptions with detailed executable commands

**Tasks**:
- [ ] Add Stage 5: Parse Subagent Return with jq validation commands
- [ ] Add Stage 6: Update Task Status with state.json jq commands
- [ ] Add Stage 6a: Update TODO.md Status with Edit tool commands
- [ ] Add Stage 7: Link Artifacts with two-step jq pattern (filter old, add new)
- [ ] Add Stage 7a: Update TODO.md Artifacts with artifact link format
- [ ] Add Stage 8: Git Commit with git add && git commit commands
- [ ] Add Stage 9: Cleanup with rm commands for marker and metadata files
- [ ] Add Stage 10: Return Brief Summary with example format
- [ ] Add Error Handling section with specific error scenarios

**Timing**: 1.5 hours

**Files Modified**:
- `.opencode/skills/skill-researcher/SKILL.md`

**Key Commands to Add**:
```bash
# Stage 5: Parse Subagent Return
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"
if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
fi

# Stage 6: Update Task Status
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "researched" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    researched: $ts
  }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json

# Stage 7: Link Artifacts (two-step jq pattern)
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

# Stage 8: Git Commit
git add -A
git commit -m "task ${task_number}: complete research

Session: ${session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"

# Stage 9: Cleanup
rm -f "specs/${padded_num}_${project_name}/.postflight-pending"
rm -f "specs/${padded_num}_${project_name}/.postflight-loop-guard"
rm -f "specs/${padded_num}_${project_name}/.return-meta.json"
```

---

### Phase 4: Add Detailed Postflight Commands to skill-planner [COMPLETED]

**Goal**: Replace vague postflight descriptions with detailed executable commands

**Tasks**:
- [ ] Add Stage 5: Parse Subagent Return with jq validation commands
- [ ] Add Stage 6: Update Task Status with state.json jq commands (planned status)
- [ ] Add Stage 6a: Update TODO.md Status with Edit tool commands
- [ ] Add Stage 7: Link Artifacts with two-step jq pattern (filter old plan, add new)
- [ ] Add Stage 7a: Update TODO.md Artifacts with artifact link format
- [ ] Add Stage 8: Git Commit with git add && git commit commands
- [ ] Add Stage 9: Cleanup with rm commands for marker and metadata files
- [ ] Add Stage 10: Return Brief Summary with example format
- [ ] Add Error Handling section with jq parse failure handling

**Timing**: 1.5 hours

**Files Modified**:
- `.opencode/skills/skill-planner/SKILL.md`

**Key Commands to Add**:
```bash
# Stage 6: Update Task Status (planned)
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "planned" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    planned: $ts
  }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json

# Stage 7: Link Artifacts (two-step jq pattern for plans)
# Step 1: Filter out existing plan artifacts
jq '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
    [(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "plan" | not)]' \
  specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json

# Step 2: Add new plan artifact
jq --arg path "$artifact_path" \
   --arg type "$artifact_type" \
   --arg summary "$artifact_summary" \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
  specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json

# Stage 8: Git Commit (plan-specific message)
git add -A
git commit -m "task ${task_number}: create implementation plan

Session: ${session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

### Phase 5: Verification and Testing [NOT STARTED]

**Goal**: Verify the fixes work correctly by testing the updated skills

**Tasks**:
- [ ] Verify skill-researcher SKILL.md has all 4 context files in context_injection
- [ ] Verify skill-planner SKILL.md has all 4 context files in context_injection
- [ ] Verify both skills have detailed Stage 5-10 postflight commands
- [ ] Verify jq commands use `| not` pattern (not `!=`)
- [ ] Verify git commit commands include session ID
- [ ] Verify cleanup commands remove all marker files
- [ ] Create test task and run /research to verify postflight works
- [ ] Run /plan on test task to verify postflight works
- [ ] Verify state.json is updated with correct status
- [ ] Verify TODO.md shows artifact links
- [ ] Verify .return-meta.json is cleaned up after postflight

**Timing**: 1 hour

**Files Modified**:
- None (verification only)

---

## Testing & Validation

- [ ] skill-researcher context_injection includes all 4 missing context files
- [ ] skill-planner context_injection includes all 4 missing context files
- [ ] Both skills have Stage 5: Parse Subagent Return with jq validation
- [ ] Both skills have Stage 6: Update Task Status with state.json jq commands
- [ ] Both skills have Stage 6a: Update TODO.md Status with Edit tool
- [ ] Both skills have Stage 7: Link Artifacts with two-step jq pattern
- [ ] Both skills have Stage 7a: Update TODO.md Artifacts with links
- [ ] Both skills have Stage 8: Git Commit with proper formatting
- [ ] Both skills have Stage 9: Cleanup commands
- [ ] Both skills have Stage 10: Return Brief Summary
- [ ] Both skills have Error Handling sections
- [ ] jq commands use `| not` pattern (not `!=`) to avoid Issue #1132
- [ ] Test /research command updates status to [RESEARCHED] and links artifact
- [ ] Test /plan command updates status to [PLANNED] and links artifact
- [ ] Verify .return-meta.json is deleted after successful postflight
- [ ] Verify git commits include session ID

## Artifacts & Outputs

- `.opencode/skills/skill-researcher/SKILL.md` - Updated with context files and postflight commands
- `.opencode/skills/skill-planner/SKILL.md` - Updated with context files and postflight commands
- `specs/OC_147_fix_artifact_metadata_linking_in_todo/plans/implementation-002.md` - This plan

## Rollback/Contingency

If implementation causes issues:

1. **Immediate Rollback**:
   ```bash
   git checkout HEAD~1 -- .opencode/skills/skill-researcher/SKILL.md
   git checkout HEAD~1 -- .opencode/skills/skill-planner/SKILL.md
   git commit -m "Rollback OC_147: revert skill changes"
   ```

2. **Partial Fix Recovery**:
   - If only one skill has issues, revert just that skill
   - Keep changes to the working skill

3. **Emergency Cleanup**:
   ```bash
   rm -f specs/*/.postflight-pending
   rm -f specs/*/.postflight-loop-guard
   rm -f specs/*/.return-meta.json
   ```

4. **Debug Mode**:
   - Keep .return-meta.json files for debugging by commenting out cleanup stage
   - Check marker files with: `cat specs/*/.postflight-pending | jq .`
