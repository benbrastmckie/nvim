---
name: skill-researcher
description: Conduct general research using web search, documentation, and codebase exploration. Invoke for non-Lean research tasks.
allowed-tools: Task, Bash, Edit, Read, Write
context: fork
agent: general-research-agent
---

# Researcher Skill

**WARNING**: This file defines context injection patterns ONLY. Commands must execute status updates themselves — this skill does NOT execute workflows.

Thin wrapper that delegates research to `general-research-agent`.

<context>
  <system_context>OpenCode research skill wrapper.</system_context>
  <task_context>Delegate research and coordinate postflight updates.</task_context>
</context>

<context_injection>
  <file path=".opencode/context/core/formats/report-format.md" variable="report_format" />
  <file path=".opencode/context/core/formats/return-metadata-file.md" variable="return_metadata" />
  <file path=".opencode/context/core/workflows/postflight-control.md" variable="postflight_control" />
  <file path=".opencode/context/core/workflows/file-metadata-exchange.md" variable="file_metadata" />
  <file path=".opencode/context/core/standards/status-markers.md" variable="status_markers" />
  <file path=".opencode/context/core/standards/jq-escaping-workarounds.md" variable="jq_workarounds" />
  
  **Task Context** (provided at invocation):
  - Task number: `{N}` - The integer task number (e.g., 146)
  - Task display: `OC_{N}` - The formatted task identifier (e.g., OC_146)
  - Project name: `{project_name}` - The task slug from state.json
</context_injection>

<role>Delegation skill for general research workflows.</role>

<task>Validate inputs, delegate research, and update status/artifacts.</task>

<execution>
  <stage id="1" name="LoadContext">
    <action>Read context files defined in <context_injection></action>
  </stage>
  <stage id="2" name="Preflight">
    <action>Validate status and prepare for delegation</action>
  </stage>
  <stage id="3" name="Delegate">
    <action>Invoke general-research-agent with injected context</action>
  </stage>
  <stage id="4" name="Postflight">
    <action>Update state and link artifacts</action>
  </stage>
</execution>

<validation>Validate metadata file, report artifact, and state updates.</validation>

<return_format>Brief text summary; metadata file in `specs/{N}_{SLUG}/.return-meta.json`.</return_format>

## Trigger Conditions

- Task language is general, meta, markdown, or latex
- /research command invoked

## Execution Flow

**IMPORTANT**: The skill tool only LOADS this skill definition. It does NOT execute the workflow below. Commands must implement preflight/postflight logic themselves.

1. **Load Context**:
   - Read `report-format.md` -> `{report_format}`
   - Read `status-markers.md` -> `{status_markers}`

2. **Preflight**:
   - Validate task and status using `{status_markers}`.
   - Update status to researching.
   - Create postflight marker file.

3. **Delegate**:
   - Call `Task` tool with `subagent_type="general-research-agent"`
   - Prompt:
     """
     Conduct research for task {N}.

     **Delegation Context**:
     ```json
     {
       "task_context": {
         "task_number": {N},
         "task_name": "{project_name}",
         "language": "general"
       },
       "metadata": {
         "session_id": "{session_id}",
         "delegation_depth": 1,
         "delegation_path": ["orchestrator", "research", "general-research-agent"]
       },
       "metadata_file_path": "specs/OC_{N}_{project_name}/.return-meta.json"
     }
     ```

     <system_context>
     Using the following format standards:
     {report_format}
     {status_markers}
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
   - Update status to "researched" with timestamp:
     ```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
         --arg status "researched" \
        '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
          status: $status,
          last_updated: $ts,
          researched: $ts
        }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
     ```

   **Stage 6a: Update TODO.md Status**
   - Edit TODO.md to change status marker:
     ```
     Edit file: specs/${padded_num}_${project_name}/TODO.md
     oldString: "- Status: [IN PROGRESS]"
     newString: "- Status: [RESEARCHED]"
     ```

   **Stage 7: Link Artifacts in state.json**
   - Use two-step jq pattern to avoid Issue #1132:
     ```bash
     # Step 1: Filter out existing research artifacts
jq '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
          [(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "research" | not)]' \
        specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
     
     # Step 2: Add new research artifact
jq --arg path "$artifact_path" \
         --arg type "$artifact_type" \
         --arg summary "$artifact_summary" \
        '(.active_projects[] | select(.project_number == '$task_number')).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
        specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
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
git commit -m "task ${task_number}: complete research

Session: ${session_id}"
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
     Research completed for task {N}:
     - Status updated to [RESEARCHED]
     - Report created at: {artifact_path}
     - Artifacts linked in state.json and TODO.md
     - Git commit: task {N}: complete research
     ```

   **Error Handling**:
   - If metadata file missing or invalid JSON: Log error, skip artifact linking
   - If jq command fails: Log error, preserve original state.json
   - If git commit fails: Log warning, continue (don't block on git)
   - If TODO.md edit fails: Log error, state.json still updated
