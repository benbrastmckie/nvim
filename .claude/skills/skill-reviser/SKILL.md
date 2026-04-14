---
name: skill-reviser
description: Thin wrapper that delegates plan revision to reviser-agent subagent. Invoke for /revise command.
allowed-tools: Task, Bash, Edit, Read, Write, Glob, Grep
model: opus
---

# Reviser Skill

Thin wrapper that delegates plan revision to `reviser-agent` subagent.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns,
this skill handles all postflight operations (status update, artifact linking, git commit) before returning.
This eliminates the "continue" prompt issue between skill return and orchestrator.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/formats/return-metadata-file.md` - Metadata file schema
- Path: `.claude/context/patterns/postflight-control.md` - Marker file protocol
- Path: `.claude/context/patterns/file-metadata-exchange.md` - File I/O helpers
- Path: `.claude/context/patterns/jq-escaping-workarounds.md` - jq escaping patterns (Issue #1132)
- Path: `.claude/context/formats/plan-format.md` - Plan file format specification

Note: This skill is a thin wrapper with internal postflight. Context is loaded by the delegated agent.

## Trigger Conditions

This skill activates when:
- `/revise` command is invoked
- Task exists in state.json

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json

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
task_type=$(echo "$task_data" | jq -r '.task_type // "general"')
status=$(echo "$task_data" | jq -r '.status')
project_name=$(echo "$task_data" | jq -r '.project_name')
description=$(echo "$task_data" | jq -r '.description // ""')
```

**No status-based ABORT rules.** The skill works regardless of task status. Routing is determined by plan file existence, not status.

---

### Stage 2: Preflight

No intermediate "revising" status is needed for revision. The task transitions directly to "planned" on success (via postflight). Skip preflight status update.

**Rationale**: Unlike `/plan` which sets "planning" as an intermediate status, `/revise` is lightweight enough that an intermediate status adds no value. The postflight script handles the final status update.

---

### Stage 3: Create Postflight Marker

Create the marker file to prevent premature termination:

```bash
# Ensure task directory exists
padded_num=$(printf "%03d" "$task_number")
mkdir -p "specs/${padded_num}_${project_name}"

cat > "specs/${padded_num}_${project_name}/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-reviser",
  "task_number": ${task_number},
  "operation": "revise",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "stop_hook_active": false
}
EOF
```

---

### Stage 3a: Calculate Artifact Number

Read `next_artifact_number` from state.json and use (current-1) since revised plan stays in the same round:

```bash
# Read next_artifact_number from state.json
next_num=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .next_artifact_number // 1' \
  specs/state.json)

# Plan uses (current - 1) to stay in the same round as research
# If next_artifact_number is 1 (no research yet), use 1
if [ "$next_num" -le 1 ]; then
  artifact_number=1
else
  artifact_number=$((next_num - 1))
fi

# Fallback for legacy tasks: count existing plan artifacts
if [ "$next_num" = "null" ] || [ -z "$next_num" ]; then
  padded_num=$(printf "%03d" "$task_number")
  count=$(ls "specs/${padded_num}_${project_name}/plans/"*[0-9][0-9]*.md 2>/dev/null | wc -l)
  artifact_number=$((count + 1))
fi

artifact_padded=$(printf "%02d" "$artifact_number")
```

**Note**: Revised plan does NOT increment `next_artifact_number`. Only research advances the sequence.

---

### Stage 4: Research Discovery

Discover existing plan and new research reports:

**4a. Find existing plan:**
```bash
padded_num=$(printf "%03d" "$task_number")
plan_dir="specs/${padded_num}_${project_name}/plans"
existing_plan=$(ls -1t "$plan_dir"/*.md 2>/dev/null | head -1)
```

**4b. Find new research reports:**

Use BOTH `reports_integrated` from state.json and file modification time comparison:

```bash
reports_dir="specs/${padded_num}_${project_name}/reports"
new_reports=()

if [ -n "$existing_plan" ]; then
  plan_mtime=$(stat -c %Y "$existing_plan")

  # Check reports_integrated from state.json (primary)
  integrated=$(jq -r --argjson num "$task_number" \
    '.active_projects[] | select(.project_number == $num) | .plan_metadata.reports_integrated // [] | .[]' \
    specs/state.json 2>/dev/null)

  for report in "$reports_dir"/*.md; do
    if [ -f "$report" ]; then
      report_basename=$(basename "$report")
      # Check if already integrated
      if echo "$integrated" | grep -qF "$report_basename"; then
        continue
      fi
      # Fallback: check modification time
      report_mtime=$(stat -c %Y "$report")
      if [ "$report_mtime" -gt "$plan_mtime" ]; then
        new_reports+=("$report")
      fi
    fi
  done
else
  # No plan exists -- all reports are "new"
  for report in "$reports_dir"/*.md; do
    if [ -f "$report" ]; then
      new_reports+=("$report")
    fi
  done
fi
```

---

### Stage 4b: Read and Inject Format Specification

Read the plan format file and prepare it for injection into the subagent prompt. This ensures the subagent always has the full format specification in its context.

```bash
format_content=$(cat .claude/context/formats/plan-format.md)
```

The format content will be included as a delimited section in the Stage 5 prompt.

---

### Stage 5: Prepare Delegation Context and Invoke Subagent

**CRITICAL**: You MUST use the **Task** tool to spawn the subagent.

Prepare delegation context:

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "revise", "skill-reviser"],
  "timeout": 1800,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "{task_type}"
  },
  "artifact_number": "{artifact_padded from Stage 3a}",
  "existing_plan_path": "{path to existing plan or null}",
  "new_research_paths": ["{path to report1}", "{path to report2}"],
  "revision_reason": "{optional user reason}",
  "roadmap_path": "specs/ROADMAP.md",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "reviser-agent"
  - prompt: [Include task_context, delegation_context, existing_plan_path, new_research_paths,
             revision_reason, metadata_file_path,
             AND the format specification from Stage 4b as shown below]
  - description: "Execute plan revision for task {N}"
```

**Format Injection**: Include the format specification from Stage 4b in the prompt as a clearly-delimited section:

```
<artifact-format-specification>
## CRITICAL: Plan Format Requirements

You MUST follow this format specification exactly when writing the plan artifact.
Non-compliance will be caught by postflight validation.

{format_content from Stage 4b}
</artifact-format-specification>
```

Place this section AFTER the delegation context JSON and BEFORE any other instructions.

**DO NOT** use `Skill(reviser-agent)` - this will FAIL.

The subagent will:
- Load revision context files
- Determine revision mode (plan revision or description update)
- Load existing plan and new research reports
- Synthesize revised plan or update description
- Write metadata to `specs/{NNN}_{SLUG}/.return-meta.json`
- Return a brief text summary (NOT JSON)

---

### Stage 5b: Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Task tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding to postflight. Use the schema from
`return-metadata-file.md` with the appropriate status value for this operation.

If you DID use the Task tool, skip this stage -- the subagent already wrote the metadata.

---

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 5b). Do NOT skip these stages for any reason.

### Stage 6: Read Metadata File

Read the metadata file:

```bash
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
    new_description=$(jq -r '.metadata.new_description // ""' "$metadata_file")
else
    echo "Error: Invalid or missing metadata file"
    status="failed"
fi
```

---

### Stage 6a: Validate Artifact Content

If subagent status is "planned" and `artifact_path` is non-empty, validate the plan artifact against format requirements. This is **non-blocking** -- warnings are logged but do not prevent postflight from completing.

```bash
if [ "$status" = "planned" ] && [ -n "$artifact_path" ] && [ -f "$artifact_path" ]; then
    echo "Validating plan artifact..."
    if ! bash .claude/scripts/validate-artifact.sh "$artifact_path" plan --fix; then
        echo "WARNING: Plan artifact has format issues (non-blocking). Review output above."
    fi
fi
```

---

### Stage 7: Postflight Status Update

**For Plan Revision** (status == "planned"):

Update task status to "planned" using the centralized script:

```bash
bash .claude/scripts/update-task-status.sh postflight $task_number plan $session_id
```

If the script exits non-zero, log error but continue (status update is best-effort for revise).

**For Description Update** (status == "description_updated"):

Update state.json description and TODO.md directly:

```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg desc "$new_description" \
   --argjson num "$task_number" \
  '(.active_projects[] | select(.project_number == $num)) |= . + {
    description: $desc,
    last_updated: $ts
  }' specs/state.json > specs/tmp/state.json && \
  mv specs/tmp/state.json specs/state.json
```

Then use Edit tool to update the description in TODO.md.

**On partial/failed**: Keep status unchanged (do not call the script).

---

### Stage 8: Artifact Linking (Plan Revision Only)

Add the new plan artifact to state.json.

**IMPORTANT**: Use two-step jq pattern to avoid Issue #1132 escaping bug. See `jq-escaping-workarounds.md`.

```bash
if [ -n "$artifact_path" ]; then
    # Step 1: Filter out existing plan artifacts (use "| not" pattern to avoid != escaping - Issue #1132)
    jq --argjson num "$task_number" \
      '(.active_projects[] | select(.project_number == $num)).artifacts =
        [(.active_projects[] | select(.project_number == $num)).artifacts // [] | .[] | select(.type == "plan" | not)]' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

    # Step 2: Add new plan artifact
    jq --argjson num "$task_number" \
       --arg path "$artifact_path" \
      '(.active_projects[] | select(.project_number == $num)).artifacts += [{"path": $path, "type": "plan"}]' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

**Update TODO.md**: Link artifact using the automated script:

```bash
bash .claude/scripts/link-artifact-todo.sh $task_number '**Plan**' '**Description**' "$artifact_path"
```

If the script exits non-zero, log a warning but continue (linking errors are non-blocking).

---

### Stage 9: Git Commit

**For Plan Revision:**
```bash
git add -A
git commit -m "$(cat <<'EOF'
task {N}: revise plan (v{NEW_VERSION})

Session: {session_id}

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

**For Description Update:**
```bash
git add -A
git commit -m "$(cat <<'EOF'
task {N}: revise description

Session: {session_id}

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

Commit failure is non-blocking (log and continue).

---

### Stage 10: Cleanup

Remove marker and metadata files:

```bash
rm -f "specs/${padded_num}_${project_name}/.postflight-pending"
rm -f "specs/${padded_num}_${project_name}/.postflight-loop-guard"
rm -f "specs/${padded_num}_${project_name}/.return-meta.json"
```

---

### Stage 11: Return Brief Summary

Return a brief text summary (NOT JSON). Example:

**Plan Revision:**
```
Plan revised for task {N}:
- Preserved {X} completed phases, revised {Y} phases
- Integrated {Z} new research reports
- Created revised plan at specs/{NNN}_{SLUG}/plans/MM_{short-slug}.md
- Status updated to [PLANNED]
- Changes committed with session {session_id}
```

**Description Update:**
```
Description updated for task {N}:
- Previous: {old_description}
- New: {new_description}
- Status: [{current_status}] (unchanged)
- Changes committed with session {session_id}
```

---

## Error Handling

### Input Validation Errors
Return immediately with error message if task not found.

### Metadata File Missing
If subagent didn't write metadata file:
1. Keep status unchanged
2. Do not cleanup postflight marker
3. Report error to user

### Git Commit Failure
Non-blocking: Log failure but continue with success response.

### jq Parse Failure
If jq commands fail with INVALID_CHARACTER or syntax error (Issue #1132):
1. Log to errors.json
2. Retry with two-step pattern (already implemented in Stage 8)

### Subagent Timeout
Return partial status if subagent times out (default 1800s).
Keep status unchanged for resume.

---

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Edit source files** - All revision work is done by agent
2. **Run build/test commands** - Verification is done by agent
3. **Use research tools** - Web/codebase search is for agent use only
4. **Analyze task requirements** - Analysis is agent work
5. **Write plan files** - Artifact creation is agent work

The postflight phase is LIMITED TO:
- Reading agent metadata file
- Updating status via `update-task-status.sh` (handles state.json + TODO.md atomically)
- Linking artifacts in state.json
- Updating description in state.json/TODO.md (description update path only)
- Git commit
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md

---

## Return Format

This skill returns a **brief text summary** (NOT JSON). The JSON metadata is written to the file and processed internally.
