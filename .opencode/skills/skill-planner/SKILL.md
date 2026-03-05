---
name: skill-planner
description: Create phased implementation plans from research findings. Invoke when a task needs an implementation plan.
allowed-tools: Task, Bash, Edit, Read, Write
context: fork
agent: planner-agent
---

# Planner Skill

Thin wrapper that delegates plan creation to `planner-agent`.

<context>
  <system_context>OpenCode planning skill wrapper.</system_context>
  <task_context>Delegate planning and coordinate postflight updates.</task_context>
</context>

<context_injection>
  <file path=".opencode/context/core/formats/plan-format.md" variable="plan_format" />
  <file path=".opencode/context/core/formats/return-metadata-file.md" variable="return_metadata" />
  <file path=".opencode/context/core/workflows/postflight-control.md" variable="postflight_control" />
  <file path=".opencode/context/core/workflows/file-metadata-exchange.md" variable="file_metadata" />
  <file path=".opencode/context/core/standards/status-markers.md" variable="status_markers" />
  <file path=".opencode/context/core/workflows/task-breakdown.md" variable="task_breakdown" />
  <file path=".opencode/context/core/standards/jq-escaping-workarounds.md" variable="jq_workarounds" />
  
  **Task Context** (provided at invocation):
  - Task number: `{N}` - The integer task number (e.g., 146)
  - Task display: `OC_{N}` - The formatted task identifier (e.g., OC_146)
  - Project name: `{project_name}` - The task slug from state.json
</context_injection>

<role>Delegation skill for planning workflows.</role>

<task>Validate planning inputs, delegate plan creation, and update task state.</task>

<execution>
  <stage id="1" name="LoadContext">
    <action>Read context files defined in <context_injection></action>
  </stage>
  <stage id="2" name="Preflight">
    <action>Validate status and prepare for delegation</action>
  </stage>
  <stage id="3" name="Delegate">
    <action>Invoke planner-agent with injected context</action>
  </stage>
  <stage id="4" name="Postflight">
    <action>Update state and link artifacts</action>
  </stage>
</execution>

<validation>Validate metadata file, plan artifact, and status updates.</validation>

<return_format>Brief text summary; metadata file in `specs/{N}_{SLUG}/.return-meta.json`.</return_format>

## Trigger Conditions

- Task status allows planning
- /plan command invoked

## Execution Flow

1. **Load Context**:
   - Read `plan-format.md` -> `{plan_format}`
   - Read `status-markers.md` -> `{status_markers}`
   - Read `task-breakdown.md` -> `{task_breakdown}`

2. **Preflight**:
   - Validate task and status using `{status_markers}`.
   - **Display Task Header**: Print the following header to show which task is being planned:
     ```
     ╔══════════════════════════════════════════════════════════╗
     ║  Task OC_{N}: {project_name}                             ║
     ║  Action: PLANNING                                        ║
     ╚══════════════════════════════════════════════════════════╝
     ```
   - Update status to planning.
   - Create postflight marker file.

3. **Delegate**:
   - Call `Task` tool with `subagent_type="planner-agent"`
   - Prompt:
     """
     Create implementation plan for task {N}.

     <system_context>
     Using the following format standards and guidelines:
     {plan_format}
     {status_markers}
     {task_breakdown}
     </system_context>
     """

4. **Postflight**:

   **Stage 5: Parse Subagent Return**
   - Read metadata file and validate JSON:
     ```bash
     metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"
     if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
         status=$(jq -r '.status' "$metadata_file")
         artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
         artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file")
         artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
     fi
     ```

   **Stage 6: Update Task Status in state.json**
   - Update status to "planned" with timestamp:
     ```bash
     jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg status "planned" \
       '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
         status: $status,
         last_updated: $ts,
         planned: $ts
       }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
     ```

   **Stage 6a: Update TODO.md Status**
   - Edit TODO.md to change status marker:
     ```
     Edit file: specs/${padded_num}_${project_name}/TODO.md
     oldString: "- Status: [IN PROGRESS]"
     newString: "- Status: [PLANNED]"
     ```

   **Stage 7: Link Artifacts in state.json**
   - Use two-step jq pattern to avoid Issue #1132:
     ```bash
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
     ```

   **Stage 7a: Update TODO.md Artifacts**
   - Add artifact link to TODO.md:
     ```
     Edit file: specs/${padded_num}_${project_name}/TODO.md
     Add to Artifacts section:
     "- [${artifact_path}](${artifact_path}) - ${artifact_summary}"
     ```

   **Stage 8: Git Commit**
   - Stage all changes and commit:
     ```bash
     git add -A
     git commit -m "task ${task_number}: create implementation plan

     Session: ${session_id}

     Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
     ```

   **Stage 9: Cleanup**
   - Remove marker and metadata files:
     ```bash
     rm -f "specs/${padded_num}_${project_name}/.postflight-pending"
     rm -f "specs/${padded_num}_${project_name}/.postflight-loop-guard"
     rm -f "specs/${padded_num}_${project_name}/.return-meta.json"
     ```

   **Stage 10: Return Brief Summary**
   - Return concise text summary (3-6 bullet points):
     ```
     Planning completed for task {N}:
     - Status updated to [PLANNED]
     - Plan created at: {artifact_path}
     - Artifacts linked in state.json and TODO.md
     - Git commit: task {N}: create implementation plan
     ```

   **Error Handling**:
   - If metadata file missing or invalid JSON: Log error, skip artifact linking
   - If jq command fails: Log error, preserve original state.json
   - If git commit fails: Log warning, continue (don't block on git)
   - If TODO.md edit fails: Log error, state.json still updated
