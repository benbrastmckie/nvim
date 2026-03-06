---
name: skill-task
description: Load task creation context for CREATE mode. Invoke when delegating to task-creation agent.
allowed-tools: Task, Bash, Edit, Read, Write
context: fork
agent: task-creation-agent
---

# Task Skill

**WARNING**: This file defines context injection patterns ONLY. Commands must execute status updates themselves — this skill does NOT execute workflows.

Thin wrapper that delegates task creation to `task-creation-agent`.

<context>
  <system_context>OpenCode task creation skill wrapper.</system_context>
  <task_context>Delegate task creation and manage postflight updates.</task_context>
</context>

<context_injection>
  <file path=".opencode/context/core/formats/return-metadata-file.md" variable="return_metadata" />
  <file path=".opencode/context/core/patterns/postflight-control.md" variable="postflight_control" />
  <file path=".opencode/context/core/patterns/file-metadata-exchange.md" variable="file_metadata" />
  <file path=".opencode/context/core/patterns/jq-escaping-workarounds.md" variable="jq_workarounds" />
  <file path=".opencode/commands/task.md" variable="task_command" />
  
  **Task Context** (provided at invocation):
  - Task number: `{N}` - The integer task number (e.g., 146)
  - Task display: `OC_{N}` - The formatted task identifier (e.g., OC_146)
  - Project name: `{project_name}` - The task slug from state.json
</context_injection>

<role>Delegation skill for task creation workflows.</role>

<task>Validate inputs, delegate task creation, and update status/artifacts.</task>

<execution>
  <stage id="1" name="LoadContext">
    <action>Read context files defined in <context_injection></action>
  </stage>
  <stage id="2" name="Preflight">
    <action>Validate status and prepare for delegation using {return_metadata} and {postflight_control}</action>
  </stage>
  <stage id="3" name="Delegate">
    <action>Invoke task-creation-agent with injected context</action>
  </stage>
  <stage id="4" name="Postflight">
    <action>Update state and link artifacts using {file_metadata} and {jq_workarounds}</action>
  </stage>
</execution>

<validation>Validate metadata file, task entry creation, state updates.</validation>

<return_format>Brief text summary; metadata file in `specs/{N}_{SLUG}/.return-meta.json`.</return_format>

## Context References

Reference (do not load eagerly):
- Path: `.opencode/context/core/formats/return-metadata-file.md` - Metadata file schema
- Path: `.opencode/context/core/patterns/postflight-control.md` - Marker file protocol
- Path: `.opencode/context/core/patterns/file-metadata-exchange.md` - Metadata file handling
- Path: `.opencode/context/core/patterns/jq-escaping-workarounds.md` - jq workaround patterns
- Path: `.opencode/commands/task.md` - Task command CREATE mode steps (authoritative source)
- Path: `.opencode/context/index.md` - Context discovery index

## Execution Flow

**IMPORTANT**: The skill tool only LOADS this skill definition. It does NOT execute the workflow below. Commands must implement preflight/postflight logic themselves.

1. **LoadContext**: Read injected context files.
2. **Preflight**: Validate task and status using {return_metadata} and {postflight_control}.
    - **Update state.json to creating**:
      ```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
          --arg status "creating" \
         '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
           status: $status,
           last_updated: $ts,
           creating: $ts
         }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
      ```
    
    - **Update TODO.md to [CREATING]**:
      ```
      Edit file: specs/${padded_num}_${project_name}/TODO.md
      oldString: "- **Status**: [NOT STARTED]"
      newString: "- **Status**: [CREATING]"
      ```
    
    - **Create task-creating marker file**:
      ```bash
      touch "specs/${padded_num}_${project_name}/.task-creating"
      ```

3. **Delegate**: Invoke task-creation-agent via Task tool with injected context.
   - Pass all {variables} from context_injection.
   - Agent must follow CREATE mode steps from {task_command}

4. **Postflight**: Read metadata file and update state + TODO using {file_metadata} and {jq_workarounds}.

   **Stage 4a: Read metadata file**:
   - Read metadata file and validate JSON:
     ```bash
     metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"
     if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
         status=$(jq -r '.status' "$metadata_file")
         task_number=$(jq -r '.metadata.task_number // 0' "$metadata_file")
         project_name=$(jq -r '.metadata.project_name // ""' "$metadata_file")
     fi
     ```

   **Stage 4b: Update Task Status in state.json**:
   - Determine final status based on metadata:
     - If `status` == "created": use "not_started"
     - If `status` == "partial": use "partial"
     - Otherwise: use "not_started" (default)
   - Update state.json with timestamp:
     ```bash
     final_status="not_started"
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
         --arg status "$final_status" \
        '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
          status: $status,
          last_updated: $ts
        }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
     ```

   **Stage 4c: Update TODO.md Status**:
   - Edit TODO.md to change status marker:
     ```
     Edit file: specs/${padded_num}_${project_name}/TODO.md
     oldString: "- **Status**: [CREATING]"
     newString: "- **Status**: [NOT STARTED]"
     ```

   **Stage 4d: Verify Task Entry**:
   - Verify task entry exists in state.json
   - Verify task entry exists in TODO.md
   - Verify task directory was created

   **Stage 4e: Git Commit**:
   - Stage all changes and commit:
     ```bash
     git add -A
     git commit -m "task ${task_number}: create task entry

Session: ${session_id}"
     ```

   **Stage 4f: Cleanup**:
   - Remove marker and metadata files:
     ```bash
     rm -f "specs/${padded_num}_${project_name}/.task-creating"
     rm -f "specs/${padded_num}_${project_name}/.return-meta.json"
     ```

   **Stage 4g: Return Brief Summary**:
   - Return concise text summary (3-6 bullet points):
     ```
     Task creation completed for task {N}:
     - Status: [NOT STARTED]
     - Task entry created in state.json and TODO.md
     - Task directory: specs/OC_{NNN}_{slug}/
     - Git commit: task {N}: create task entry
     ```

   **Error Handling**:
   - If metadata file missing or invalid JSON: Log error, skip updates
   - If jq command fails: Log error, preserve original state.json
   - If git commit fails: Log warning, continue (do not block on git)
   - If TODO.md edit fails: Log error, state.json still updated

## Validation Checklist

- [ ] Metadata file exists and is valid JSON
- [ ] Task entry created in state.json
- [ ] Task entry created in TODO.md
- [ ] Task directory created at correct path
- [ ] state.json updated with correct status
- [ ] TODO.md updated with status

## CRITICAL: Context Only

**This skill file ONLY loads context and references the task.md command file.**

- It does NOT contain CREATE mode step-by-step instructions
- It does NOT execute preflight/postflight workflows
- It delegates to task-creation-agent which reads task.md for CREATE mode steps

The task.md command file is the authoritative source for CREATE mode workflow.

## Trigger Conditions

- /task command invoked with create mode (no flags or description only)
- Task creation requires delegation to task-creation-agent
