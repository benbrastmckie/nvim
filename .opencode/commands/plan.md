---
description: Create a phased implementation plan for a task
---

Create an implementation plan for the given task. Do NOT implement anything.

**Input**: $ARGUMENTS

---

## Parse Input

- First token: task number — accepts `OC_N` or `N` (strip `OC_` prefix to get integer N)
- Remaining tokens: optional notes/constraints
- If invalid: "Usage: /plan <OC_N> [notes]"

---

## Steps

### 1. Look up task

Strip `OC_` prefix, find task in `specs/state.json`:
```bash
jq --arg n "N" '.active_projects[] | select(.project_number == ($n | tonumber))' specs/state.json
```
If not found: "Task OC_N not found in state.json"

Extract: `language`, `status`, `project_name`, `description`

Zero-pad N to 3 digits: `NNN` (e.g. `printf "%03d" N`)

Directory: `specs/OC_NNN_<project_name>/`

### 2. Validate status

- `researched`, `not_started`, `partial`: proceed
- `planning`: warn "already planning, proceeding"
- `abandoned`: error "task is abandoned, use /task --recover first"
- `completed`: warn "already completed, re-planning"

### 3. Execute Preflight

**CRITICAL**: Commands must execute preflight BEFORE delegating to agents. The skill tool only loads skill definitions but does NOT execute workflows.

**Update state.json to planning**:
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "planning" \
  '(.active_projects[] | select(.project_number == N)) |= . + {
    status: $status,
    last_updated: $ts,
    planning: $ts
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

**Update TODO.md to [PLANNING]**:
- Edit file: `specs/TODO.md`
- Find line: `- **Status**: [RESEARCHED]` (or current status) for task OC_N
- Change to: `- **Status**: [PLANNING]`

**Create postflight marker file**:
```bash
touch "specs/OC_NNN_<project_name>/.postflight-pending"
```

### 5. Read existing research

Check for `specs/OC_NNN_<project_name>/reports/research-001.md`. If it exists, read it for context. If not, plan from the task description alone.

### 6. Delegate to Planning Agent

**Call skill tool** to load skill context and delegate to planning agent:

```
→ Tool: skill
→ Name: skill-planner
→ Prompt: Create implementation plan for task {N} with language {language} and research context from {research_content}
```

The skill-planner will:
1. Load context files (plan-format.md, status-markers.md, task-breakdown.md)
2. **Call Task tool with `subagent_type="planner-agent"`** to create the plan
3. Return results (subagent writes .return-meta.json)

**CRITICAL**: The skill tool ONLY loads skill definitions. It does NOT execute preflight/postflight workflows. This command MUST execute status updates before and after delegation.

**DELEGATION REQUIREMENT**:

After skill context is loaded, the skill MUST invoke the `Task` tool with `subagent_type="planner-agent"`. This is a NON-OPTIONAL requirement.

**EXECUTE NOW**: USE the Task tool with `subagent_type="planner-agent"` to delegate plan creation to the specialized agent. Do NOT process the planning request directly in this context.

**FAILURE CONDITION**: If the Task tool is not invoked with `subagent_type="planner-agent"`, this command has FAILED. The primary agent must NOT create the plan itself — it MUST delegate to the planner-agent via the Task tool.

### 7. Execute Postflight

**CRITICAL**: Commands must execute postflight AFTER agents return. The skill tool does NOT execute workflows.

**Step 7a: Read metadata file**:
```bash
metadata_file="specs/OC_NNN_<project_name>/.return-meta.json"
if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
    agent_type=$(jq -r '.metadata.agent_type // ""' "$metadata_file")
fi
```

**Step 7a-verify: Verify correct agent was used**:

**CRITICAL**: Verify that the metadata contains `agent_type: "planner-agent"`. If not present or incorrect, the delegation failed.

```bash
expected_agent="planner-agent"
if [ "$agent_type" != "$expected_agent" ]; then
    echo "WARNING: Delegation verification failed!"
    echo "Expected agent_type: $expected_agent"
    echo "Actual agent_type: $agent_type"
    echo "The skill may have processed the request directly instead of delegating."
    # Log this as an error for tracking
fi
```

If `agent_type` is empty or does not match `planner-agent`, log a warning but continue with postflight (the plan may still have been created correctly).

**Step 7b: Update state.json to planned**:
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "planned" \
  '(.active_projects[] | select(.project_number == N)) |= . + {
    status: $status,
    last_updated: $ts,
    planned: $ts
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

**Step 7c: Update TODO.md**:
- Edit file: `specs/TODO.md`
- Find line: `- **Status**: [PLANNING]` for task OC_N
- Change to: `- **Status**: [PLANNED]`

**Step 7d: Link artifacts in state.json**:
```bash
# Step 1: Filter out existing plan artifacts
jq '(.active_projects[] | select(.project_number == N)).artifacts =
    [(.active_projects[] | select(.project_number == N)).artifacts // [] | .[] | select(.type == "plan" | not)]' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

# Step 2: Add new plan artifact
jq --arg path "$artifact_path" \
   --arg type "$artifact_type" \
   --arg summary "$artifact_summary" \
  '(.active_projects[] | select(.project_number == N)).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

**Step 7e: Add artifact to TODO.md**:
- Edit file: `specs/TODO.md`
- Find "Artifacts" section for task OC_N
- Add line: `- [$artifact_path]($artifact_path) - $artifact_summary`

**Step 7f: Git commit**:
```bash
git add -A
git commit -m "task N: create implementation plan

Session: ${session_id}"
```

**Step 7g: Cleanup**:
```bash
rm -f "specs/OC_NNN_<project_name>/.postflight-pending"
rm -f "specs/OC_NNN_<project_name>/.postflight-loop-guard"
rm -f "specs/OC_NNN_<project_name>/.return-meta.json"
```

### 8. Report results

Show:
- Plan path
- Number of phases and estimated total effort
- Next step: `/implement OC_N`

---

## Rules

- This command executes preflight (status → planning) BEFORE delegating to skill-planner
- This command executes postflight (status → planned, link artifacts) AFTER skill-planner returns
- The skill-planner only loads context and delegates to planner-agent — it does NOT execute workflows
- Phases should be granular enough to be resumable if interrupted
- Directories use 3-digit padded number: `OC_174_slug` not `OC_17_slug`
- If plan already exists, create `implementation-002.md` (increment version)
- **NEVER use embedded plan templates** - always delegate to planner-agent with injected plan-format.md context
- **NO EMBEDDED TEMPLATES**: Do not include example plan structures in this file - they violate plan-format.md

## Critical Notes

**The skill tool only loads SKILL.md content — it does NOT execute preflight/postflight workflows.**

Commands must execute these workflows themselves:
1. **Preflight** (Step 4): Display header, update state.json to "planning", TODO.md to [PLANNING], create marker file
2. **Research** (Step 5): Read research report if available
3. **Delegation** (Step 6): Call skill-planner to load context and invoke planner-agent
4. **Postflight** (Step 7): Read .return-meta.json, update state.json to "planned", update TODO.md to [PLANNED], link artifacts, commit, cleanup

This pattern ensures status updates happen automatically without orchestrator intervention.
