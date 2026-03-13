---
description: Execute implementation with resume support
---

Execute the implementation plan for the given task, phase by phase.

**Input**: $ARGUMENTS

---

## Parse Input

- First token: task number — accepts `OC_N` or `N` (strip `OC_` prefix to get integer N)
- `--force`: skip status validation
- Remaining tokens: optional custom instructions
- If invalid: "Usage: /implement <OC_N> [--force] [instructions]"

---

## Steps

### 1. Look up task

Strip `OC_` prefix, find task in `specs/state.json`:
```bash
jq --arg n "N" '.active_projects[] | select(.project_number == ($n | tonumber))' specs/state.json
```
If not found: "Task OC_N not found in state.json"

Extract: `language`, `status`, `project_name`, `description`

Zero-pad N to 3 digits: `NNN`

Directory: `specs/OC_NNN_<project_name>/`

### 2. Validate status (unless --force)

- `planned`, `partial`, `researched`, `not_started`: proceed
- `implementing`: warn "already implementing, resuming"
- `abandoned`: error "task is abandoned, use /task --recover first"
- `completed`: error "already completed, use --force to re-implement"

### 3. Find implementation plan

Look for `specs/OC_NNN_<project_name>/plans/implementation-*.md` — use the highest version.

If no plan found: "No plan found. Run `/plan OC_N` first."

Read the plan to understand all phases and their current status (`[NOT STARTED]`, `[IN PROGRESS]`, `[COMPLETED]`, `[PARTIAL]`).

### 4. Execute Preflight

**CRITICAL**: Commands must execute preflight BEFORE delegating to agents. The skill tool only loads skill definitions but does NOT execute workflows.

**Update state.json to implementing**:
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "implementing" \
  '(.active_projects[] | select(.project_number == N)) |= . + {
    status: $status,
    last_updated: $ts,
    implementing: $ts
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

**Update TODO.md to [IMPLEMENTING]**:
- Edit file: `specs/TODO.md`
- Find line: `- **Status**: [PLANNED]` (or current status) for task OC_N
- Change to: `- **Status**: [IMPLEMENTING]`

**Create postflight marker file**:
```bash
touch "specs/OC_NNN_<project_name>/.postflight-pending"
```

### 5. Delegate to Implementation Agent

**Call skill tool** to load skill context and delegate to implementation agent:

```
→ Tool: skill
→ Name: skill-implementer
→ Prompt: Execute implementation plan for task {N} with language {language}
```

The skill-implementer will:
1. Load context files (plan-format.md, status-markers.md, etc.)
2. **Call Task tool with `subagent_type="general-implementation-agent"`** to execute phases
3. Return results (subagent writes .return-meta.json)

**CRITICAL**: The skill tool ONLY loads skill definitions. It does NOT execute preflight/postflight workflows. This command MUST execute status updates before and after delegation.

**DELEGATION REQUIREMENT**:

After skill context is loaded, the skill MUST invoke the `Task` tool with the appropriate `subagent_type`. This is a NON-OPTIONAL requirement.

| Language | Required subagent_type |
|----------|------------------------|
| neovim | `neovim-implementation-agent` |
| general, meta, markdown, latex, typst | `general-implementation-agent` |

**EXECUTE NOW**: USE the Task tool with the correct `subagent_type` to delegate implementation to the specialized agent. Do NOT process the implementation request directly in this context.

**FAILURE CONDITION**: If the Task tool is not invoked with the correct `subagent_type`, this command has FAILED. The primary agent must NOT execute implementation phases itself — it MUST delegate to the appropriate implementation agent via the Task tool.

**Phase Status Tracking**: The implementation agent maintains phase status in the plan file as source of truth for resume points.

**Language-specific guidance**:
- **meta**: Edit `.opencode/` files, create/update agent and command definitions
- **lean**: Write Lean 4 proofs, use `lake build` to verify
- **typst**: Write Typst markup, use `typst compile` to verify
- **latex**: Write LaTeX, use `pdflatex` to verify
- **general**: Follow the plan steps using appropriate tools

### 6. Execute Postflight

**CRITICAL**: Commands must execute postflight AFTER agents return. The skill tool does NOT execute workflows.

**Step 7a: Read metadata file**:
```bash
metadata_file="specs/OC_NNN_<project_name>/.return-meta.json"
if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    phases_completed=$(jq -r '.metadata.phases_completed // 0' "$metadata_file")
    phases_total=$(jq -r '.metadata.phases_total // 0' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
    agent_type=$(jq -r '.metadata.agent_type // ""' "$metadata_file")
fi
```

**Step 7a-verify: Verify correct agent was used**:

**CRITICAL**: Verify that the metadata contains the correct `agent_type`. Expected values depend on task language:

| Language | Expected agent_type |
|----------|---------------------|
| neovim | `neovim-implementation-agent` |
| general, meta, markdown, latex, typst | `general-implementation-agent` |

```bash
# Determine expected agent based on task language
if [ "$language" == "neovim" ]; then
    expected_agent="neovim-implementation-agent"
else
    expected_agent="general-implementation-agent"
fi

if [ "$agent_type" != "$expected_agent" ]; then
    echo "WARNING: Delegation verification failed!"
    echo "Expected agent_type: $expected_agent"
    echo "Actual agent_type: $agent_type"
    echo "The skill may have processed the request directly instead of delegating."
    # Log this as an error for tracking
fi
```

If `agent_type` is empty or does not match the expected agent, log a warning but continue with postflight (the implementation may still have been completed correctly).

**Step 7b: Determine final status**:
- If `status` == "implemented" and `phases_completed` == `phases_total`: final_status="completed"
- If `status` == "partial": final_status="partial"
- Otherwise: final_status="implementing" (keep current)

**Step 7c: Update state.json**:
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "$final_status" \
  '(.active_projects[] | select(.project_number == N)) |= . + {
    status: $status,
    last_updated: $ts,
    "${final_status}": $ts
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

**Step 7d: Update TODO.md**:
- Edit file: `specs/TODO.md`
- Find line: `- **Status**: [IMPLEMENTING]` for task OC_N
- Change to: `- **Status**: [COMPLETED]` (or [PARTIAL] if final_status is "partial")

**Step 7e: Link artifacts in state.json**:
```bash
# Step 1: Filter out existing summary artifacts
jq '(.active_projects[] | select(.project_number == N)).artifacts =
    [(.active_projects[] | select(.project_number == N)).artifacts // [] | .[] | select(.type == "summary" | not)]' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

# Step 2: Add new summary artifact
jq --arg path "$artifact_path" \
   --arg type "$artifact_type" \
   --arg summary "$artifact_summary" \
  '(.active_projects[] | select(.project_number == N)).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

**Step 7f: Add artifact to TODO.md**:
- Edit file: `specs/TODO.md`
- Find "Artifacts" section for task OC_N
- Add line: `- [$artifact_path]($artifact_path) - $artifact_summary`

**Step 7g: Git commit**:
```bash
git add -A
git commit -m "task N: complete implementation

Session: ${session_id}"
```

**Step 7h: Cleanup**:
```bash
rm -f "specs/OC_NNN_<project_name>/.postflight-pending"
rm -f "specs/OC_NNN_<project_name>/.postflight-loop-guard"
rm -f "specs/OC_NNN_<project_name>/.return-meta.json"
```

### 7. Report results

Show:
- Phases completed
- Files changed
- Summary path
- Any follow-up suggestions

---

## Rules

- This command executes preflight (status → implementing) BEFORE delegating to skill-implementer
- This command executes postflight (status → completed/partial, link artifacts) AFTER skill-implementer returns
- The skill-implementer only loads context and delegates to general-implementation-agent — it does NOT execute workflows
- Execute phases in order — do not skip ahead
- Mark each phase `[COMPLETED]` in the plan file as you finish it
- If a phase fails, mark it `[PARTIAL]` in the plan and stop — do not mark task completed
- Write the summary BEFORE updating status to COMPLETED
- Directories use 3-digit padded number: `OC_174_slug` not `OC_17_slug`
- For Lean tasks, always verify with `lake build` after each phase
- **Commit after each phase completion** — stage only files modified in that phase
- **Commit when blocked** — if phase fails, commit partial progress before stopping

## Critical Notes

**The skill tool only loads SKILL.md content — it does NOT execute preflight/postflight workflows.**

Commands must execute these workflows themselves:
1. **Preflight** (Step 4): Update state.json to "implementing", TODO.md to [IMPLEMENTING], create marker file
2. **Delegation** (Step 5): Call skill-implementer to load context and invoke general-implementation-agent
3. **Postflight** (Step 6): Read .return-meta.json, update state.json to "completed"/"partial", update TODO.md, link artifacts, commit, cleanup

This is the fix for the bug where task status was never updated after implementation completed.
