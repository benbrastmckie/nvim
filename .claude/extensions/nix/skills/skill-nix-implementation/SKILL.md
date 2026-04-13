---
name: skill-nix-implementation
description: Implement Nix configuration changes from plans. Invoke for nix implementation tasks.
allowed-tools: Task, Bash, Edit, Read, Write
---

# Nix Implementation Skill

Thin wrapper that delegates Nix configuration implementation to `nix-implementation-agent` subagent.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns,
this skill handles all postflight operations (status update, artifact linking, git commit) before returning.
This eliminates the "continue" prompt issue between skill return and orchestrator.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/formats/return-metadata-file.md` - Metadata file schema
- Path: `.claude/context/patterns/postflight-control.md` - Marker file protocol
- Path: `.claude/context/patterns/file-metadata-exchange.md` - File I/O helpers
- Path: `.claude/context/patterns/jq-escaping-workarounds.md` - jq escaping patterns (Issue #1132)

Note: This skill is a thin wrapper with internal postflight. Context is loaded by the delegated agent.

## Trigger Conditions

This skill activates when:
- Task type is "nix"
- /implement command targets a Nix task
- NixOS modules, Home Manager configs, or flake changes need to be created using Nix

---

## Execution

### 0. Preflight Status Update

Before delegating to the subagent, update task status to "implementing".

**Update state.json**:
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "implementing" \
   --arg sid "$session_id" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    session_id: $sid,
    started: $ts
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

**Update TODO.md**: Use Edit tool to change status marker from `[PLANNED]` to `[IMPLEMENTING]`.

**Update plan file** (if exists): Update the Status field in plan metadata:
```bash
# Find latest plan file
plan_file=$(ls -1 "specs/${padded_num}_${project_name}/plans/"*.md 2>/dev/null | sort -V | tail -1)
if [ -n "$plan_file" ] && [ -f "$plan_file" ]; then
    sed -i "s/^\- \*\*Status\*\*: \[.*\]$/- **Status**: [IMPLEMENTING]/" "$plan_file"
fi
```

**Create Postflight Marker**:
```bash
# Ensure task directory exists
mkdir -p "specs/${padded_num}_${project_name}"

cat > "specs/${padded_num}_${project_name}/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-nix-implementation",
  "task_number": ${task_number},
  "operation": "implement",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "stop_hook_active": false
}
EOF
```

---

### 1. Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- Task status must allow implementation (planned, implementing, partial)

```bash
# Lookup task
task_data=$(jq -r --arg num "$task_number" \
  '.active_projects[] | select(.project_number == ($num | tonumber))' \
  specs/state.json)

# Validate exists
if [ -z "$task_data" ]; then
  return error "Task $task_number not found"
fi

# Extract fields
task_type=$(echo "$task_data" | jq -r '.task_type // "general"')
status=$(echo "$task_data" | jq -r '.status')
project_name=$(echo "$task_data" | jq -r '.project_name')
description=$(echo "$task_data" | jq -r '.description // ""')

# Validate language
if [ "$task_type" != "nix" ]; then
  return error "Task $task_number is not a Nix task"
fi

# Validate status
if [ "$status" = "completed" ]; then
  return error "Task already completed"
fi
```

### 2. Context Preparation

Prepare delegation context:

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "implement", "skill-nix-implementation"],
  "timeout": 3600,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "nix"
  },
  "plan_path": "specs/{NNN}_{SLUG}/plans/MM_{short-slug}.md",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

### 3. Invoke Subagent

**CRITICAL**: You MUST use the **Task** tool to spawn the subagent.

The `agent` field in this skill's frontmatter specifies the target: `nix-implementation-agent`

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "nix-implementation-agent"
  - prompt: [Include task_context, delegation_context, plan_path]
  - description: "Execute Nix implementation for task {N}"
```

**DO NOT** use `Skill(nix-implementation-agent)` - this will FAIL.
Agents live in `.claude/agents/`, not `.claude/skills/`.
The Skill tool can only invoke skills from `.claude/skills/`.

The subagent will:
- Load Nix-specific context files (style guide, module patterns, etc.)
- Create/modify .nix files (flake.nix, modules, home.nix, etc.)
- Execute verification (nix flake check, nixos-rebuild build)
- Use MCP-NixOS for package/option validation (when available)
- Create implementation summary
- Write metadata to `specs/{NNN}_{SLUG}/.return-meta.json`
- Return a brief text summary (NOT JSON)

### 3a. Validate Subagent Return Format

**IMPORTANT**: Check if subagent accidentally returned JSON to console (v1 pattern) instead of writing to file (v2 pattern).

If the subagent's text return parses as valid JSON, log a warning:

```bash
# Check if subagent return looks like JSON (starts with { and is valid JSON)
subagent_return="$SUBAGENT_TEXT_RETURN"
if echo "$subagent_return" | grep -q '^{' && echo "$subagent_return" | jq empty 2>/dev/null; then
    echo "WARNING: Subagent returned JSON to console instead of writing metadata file."
    echo "This indicates the agent may have outdated instructions (v1 pattern instead of v2)."
    echo "The skill will continue by reading the metadata file, but this should be fixed."
fi
```

This validation:
- Does NOT fail the operation (continues to read metadata file)
- Logs a warning for debugging
- Indicates the subagent instructions need updating
- Allows graceful handling of mixed v1/v2 agents

### 3b. Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Task tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding to postflight. Use the schema from
`return-metadata-file.md` with status value "implemented".

If you DID use the Task tool, skip this stage -- the subagent already wrote the metadata.

---

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 3b). Do NOT skip these stages for any reason.

### 4. Parse Subagent Return (Read Metadata File)

Read the metadata file:

```bash
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
    phases_completed=$(jq -r '.metadata.phases_completed // 0' "$metadata_file")
    phases_total=$(jq -r '.metadata.phases_total // 0' "$metadata_file")

    # Extract completion_data fields (if present)
    completion_summary=$(jq -r '.completion_data.completion_summary // ""' "$metadata_file")
    roadmap_items=$(jq -c '.completion_data.roadmap_items // []' "$metadata_file")
else
    echo "Error: Invalid or missing metadata file"
    status="failed"
fi
```

Validate the metadata contains required fields:
- Status is one of: implemented, partial, failed, blocked
- Summary is non-empty and <100 tokens
- Artifacts array present (Nix config files, summary)
- Metadata contains session_id, agent_type, delegation info

### 5. Postflight Status Update

After implementation, update task status based on result.

**If result.status == "implemented"**:

Update state.json to "completed" and add completion_data fields (two-step pattern for Issue #1132):
```bash
# Step 1: Update status and timestamps
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "completed" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    completed: $ts
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

# Step 2: Add completion_summary (always required for completed tasks)
if [ -n "$completion_summary" ]; then
    jq --arg summary "$completion_summary" \
      '(.active_projects[] | select(.project_number == '$task_number')).completion_summary = $summary' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi

# Step 3: Add roadmap_items (if present and non-empty)
if [ "$roadmap_items" != "[]" ] && [ -n "$roadmap_items" ]; then
    jq --argjson items "$roadmap_items" \
      '(.active_projects[] | select(.project_number == '$task_number')).roadmap_items = $items' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi

# Step 4: Filter out existing summary artifacts (use "| not" pattern to avoid != escaping - Issue #1132)
jq '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
    [(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "summary" | not)]' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

# Step 5: Add new summary artifact
jq --arg path "$artifact_path" \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts += [{"path": $path, "type": "summary"}]' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

Update TODO.md:
- Change status marker from `[IMPLEMENTING]` to `[COMPLETED]`
- Add summary artifact link using count-aware format per `.claude/rules/state-management.md` "Artifact Linking Format"

**Update plan file** (if exists): Update the Status field to `[COMPLETED]`:
```bash
plan_file=$(ls -1 "specs/${padded_num}_${project_name}/plans/"*.md 2>/dev/null | sort -V | tail -1)
if [ -n "$plan_file" ] && [ -f "$plan_file" ]; then
    sed -i "s/^\- \*\*Status\*\*: \[.*\]$/- **Status**: [COMPLETED]/" "$plan_file"
fi
```

**If result.status == "partial"**:

Update state.json with resume point (keep status as "implementing"):
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg phase "$completed_phase" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    last_updated: $ts,
    resume_phase: ($phase | tonumber + 1)
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

TODO.md stays as `[IMPLEMENTING]`.

**Update plan file** (if exists): Update the Status field to `[PARTIAL]`:
```bash
plan_file=$(ls -1 "specs/${padded_num}_${project_name}/plans/"*.md 2>/dev/null | sort -V | tail -1)
if [ -n "$plan_file" ] && [ -f "$plan_file" ]; then
    sed -i "s/^\- \*\*Status\*\*: \[.*\]$/- **Status**: [PARTIAL]/" "$plan_file"
fi
```

**On failed**: Do NOT run postflight. Keep status as "implementing" for retry. Do not update plan file (leave as `[IMPLEMENTING]` for retry).

### 6. Git Commit

Commit changes with session ID:

```bash
git add -A
git commit -m "task ${task_number}: complete implementation

Session: ${session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

### 7. Cleanup

Remove marker and metadata files after postflight processing:

```bash
rm -f "specs/${padded_num}_${project_name}/.postflight-pending"
rm -f "specs/${padded_num}_${project_name}/.postflight-loop-guard"
rm -f "specs/${padded_num}_${project_name}/.return-meta.json"
```

### 8. Return Brief Summary

Return a brief text summary (NOT JSON) describing the implementation results.

---

## Return Format

This skill returns a **brief text summary** (NOT JSON). The JSON metadata is written to the file and processed internally.

Example successful return:
```
Nix implementation completed for task 412:
- All 3 phases executed, flake check passes
- Created NixOS module at modules/myservice.nix
- Created summary at specs/412_configure_nginx/summaries/01_nix-module-summary.md
- Status updated to [COMPLETED]
- Changes committed with session sess_1736700000_abc123
```

Example partial return:
```
Nix implementation partially completed for task 412:
- Phases 1-2 of 3 executed
- Phase 3 blocked: attribute 'missingPkg' missing
- Partial summary at specs/412_configure_nginx/summaries/01_nix-module-summary.md
- Status remains [IMPLEMENTING] - run /implement 412 to resume
```

---

## Error Handling

### Input Validation Errors
Return immediately with failed status if task not found, wrong language, or status invalid.

### Subagent Errors
Pass through the subagent's error return verbatim.

### Timeout
Return partial status if subagent times out (default 3600s).

---

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Edit .nix files** - All Nix configuration is done by agent
2. **Run nix build/flake check** - Verification is done by agent
3. **Use MCP-NixOS tools** - Package validation is done by agent
4. **Analyze or grep source** - Analysis is agent work
5. **Write summary/reports** - Artifact creation is agent work

The postflight phase is LIMITED TO:
- Reading agent metadata file
- Updating state.json via jq
- Updating TODO.md status marker via Edit
- Linking artifacts in state.json
- Git commit
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md
