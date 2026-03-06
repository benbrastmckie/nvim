---
name: skill-implementer
description: Execute general implementation tasks following a plan. Invoke for non-Lean implementation work.
allowed-tools: Task, Bash, Edit, Read, Write
context: fork
agent: general-implementation-agent
---

# Implementer Skill

**WARNING**: This file defines context injection patterns ONLY. Commands must execute status updates themselves — this skill does NOT execute workflows.

Thin wrapper that delegates implementation to `general-implementation-agent`.

<context>
  <system_context>OpenCode implementation skill wrapper.</system_context>
  <task_context>Delegate implementation and coordinate postflight updates.</task_context>
</context>

<context_injection>
  <file path=".opencode/context/core/formats/return-metadata-file.md" variable="return_metadata" />
  <file path=".opencode/context/core/patterns/postflight-control.md" variable="postflight_control" />
  <file path=".opencode/context/core/patterns/file-metadata-exchange.md" variable="file_metadata" />
  <file path=".opencode/context/core/patterns/jq-escaping-workarounds.md" variable="jq_workarounds" />
  
  **Task Context** (provided at invocation):
  - Task number: `{N}` - The integer task number (e.g., 146)
  - Task display: `OC_{N}` - The formatted task identifier (e.g., OC_146)
  - Project name: `{project_name}` - The task slug from state.json
</context_injection>

<role>Delegation skill for general implementation workflows.</role>

<task>Validate inputs, delegate implementation, and update status/artifacts.</task>

<execution>
  <stage id="1" name="LoadContext">
    <action>Read context files defined in <context_injection></action>
  </stage>
  <stage id="2" name="Preflight">
    <action>Validate status and prepare for delegation using {return_metadata} and {postflight_control}</action>
  </stage>
  <stage id="3" name="Delegate">
    <action>Invoke general-implementation-agent with injected context</action>
  </stage>
  <stage id="4" name="Postflight">
    <action>Update state and link artifacts using {file_metadata} and {jq_workarounds} patterns</action>
  </stage>
  <stage id="5" name="PostflightVerification">
    <action>Verify phase status consistency between plan file and metadata</action>
  </stage>
</execution>

<validation>Validate metadata file, summary artifact, state updates, and phase status consistency.</validation>

<return_format>Brief text summary; metadata file in `specs/{N}_{SLUG}/.return-meta.json`.</return_format>

## Context References

Reference (do not load eagerly):
- Path: `.opencode/context/core/formats/return-metadata-file.md` - Metadata file schema
- Path: `.opencode/context/core/patterns/postflight-control.md` - Marker file protocol
- Path: `.opencode/context/core/patterns/file-metadata-exchange.md` - Metadata file handling
- Path: `.opencode/context/core/patterns/jq-escaping-workarounds.md` - jq workaround patterns
- Path: `.opencode/context/index.md` - Context discovery index

## Execution Flow

**IMPORTANT**: The skill tool only LOADS this skill definition. It does NOT execute the workflow below. Commands must implement preflight/postflight logic themselves.

1. **LoadContext**: Read injected context files.
2. **Preflight**: Validate task and status using {return_metadata} and {postflight_control}.
    - **Update state.json to implementing**:
      ```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
          --arg status "implementing" \
         '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
           status: $status,
           last_updated: $ts,
           implementing: $ts
         }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
      ```
    
    - **Update TODO.md to [IMPLEMENTING]**:
      ```
      Edit file: specs/${padded_num}_${project_name}/TODO.md
      oldString: "- **Status**: [PLANNED]"
      newString: "- **Status**: [IMPLEMENTING]"
      ```
    
    - **Create postflight marker file**:
      ```bash
      touch "specs/${padded_num}_${project_name}/.postflight-pending"
      ```

### 2a. Verify Phase Status

**Purpose**: Ensure the current implementation phase is marked [IN PROGRESS] before delegation.

**Process**:
1. Read the plan file from `specs/${padded_num}_${project_name}/plans/implementation-*.md` (highest version)
2. Extract all phase headings using regex: `### Phase \d+: .*? \[(NOT STARTED|IN PROGRESS|COMPLETED|PARTIAL)\]`
3. Find the first phase that is not [COMPLETED]
4. Verify it shows [IN PROGRESS]
5. If it shows [NOT STARTED]:
   - Update the phase status to [IN PROGRESS] using Edit tool
   - Log warning: "Phase {N} was [NOT STARTED], updated to [IN PROGRESS]"
6. If it shows [PARTIAL]:
   - Keep as [PARTIAL] (resuming from partial state)
   - Log info: "Resuming Phase {N} from [PARTIAL]"

**Auto-Correction Logic**:
```
Edit file: specs/${padded_num}_${project_name}/plans/implementation-{NNN}.md
oldString: "### Phase {N}: {Name} [NOT STARTED]"
newString: "### Phase {N}: {Name} [IN PROGRESS]"
```

**Why This Matters**:
- Catches cases where agent fails to update phase status
- Provides early warning for status synchronization issues
- Ensures plan file is accurate resume point source of truth

3. **Delegate**: Invoke general-implementation-agent via Task tool with injected context.
   - Pass all {variables} from context_injection.
4. **Postflight**: Read metadata file and update state + TODO using {file_metadata} and {jq_workarounds}.

   **Stage 5: Parse Subagent Return**
   - Read metadata file and validate JSON:
     ```bash
     metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"
     if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
         status=$(jq -r '.status' "$metadata_file")
         phases_completed=$(jq -r '.metadata.phases_completed // 0' "$metadata_file")
         phases_total=$(jq -r '.metadata.phases_total // 0' "$metadata_file")
         artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
         artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file")
         artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
     fi
     ```

   **Stage 6: Update Task Status in state.json**
   - Determine final status based on metadata:
     - If `status` == "implemented" and `phases_completed` == `phases_total`: use "completed"
     - If `status` == "partial": use "partial"
     - Otherwise: keep "implementing"
   - Update state.json with timestamp:
     ```bash
     final_status="completed"  # or "partial" based on logic above
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
         --arg status "$final_status" \
        '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
          status: $status,
          last_updated: $ts,
          ${final_status}: $ts
        }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
     ```

   **Stage 6a: Update TODO.md Status**
   - Edit TODO.md to change status marker:
     ```
     Edit file: specs/${padded_num}_${project_name}/TODO.md
     oldString: "- **Status**: [IMPLEMENTING]"
     newString: "- **Status**: [COMPLETED]"  # or [PARTIAL] based on final_status
     ```

   **Stage 7: Link Artifacts in state.json**
   - Use two-step jq pattern to avoid Issue #1132:
     ```bash
     # Step 1: Filter out existing summary artifacts
jq '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
          [(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "summary" | not)]' \
        specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
     
     # Step 2: Add new summary artifact
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
git commit -m "task ${task_number}: complete implementation

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
     Implementation completed for task {N}:
     - Status updated to [COMPLETED] (or [PARTIAL])
     - Phases completed: {phases_completed}/{phases_total}
     - Summary created at: {artifact_path}
     - Artifacts linked in state.json and TODO.md
     - Git commit: task {N}: complete implementation
     ```

   **Error Handling**:
   - If metadata file missing or invalid JSON: Log error, skip artifact linking
   - If jq command fails: Log error, preserve original state.json
   - If git commit fails: Log warning, continue (do not block on git)
   - If TODO.md edit fails: Log error, state.json still updated

5. **PostflightVerification**: Verify phase status consistency.

   **Purpose**: Ensure plan.md phase status markers stay synchronized with actual implementation progress.

   **Process**:
   1. Read the plan file from the path specified in metadata
   2. Extract all phase status markers using regex: `### Phase \d+:.*?\[(NOT STARTED|IN PROGRESS|COMPLETED|PARTIAL)\]`
   3. Count phases by status:
      - completed_count = number of [COMPLETED] phases
      - in_progress_count = number of [IN PROGRESS] phases
      - partial_count = number of [PARTIAL] phases
      - not_started_count = number of [NOT STARTED] phases
   4. Compare with metadata.phases_completed
   5. Apply recovery logic to correct mismatches
   6. Log all corrections for audit trail

   **Recovery Logic**:

   1. **Completed Phase Recovery**:
      - If metadata.phases_completed > plan [COMPLETED] phases: 
        - Update plan to mark additional phases as [COMPLETED]
        - Log: "Corrected {N} phases to [COMPLETED] based on metadata"
      - If metadata.phases_completed < plan [COMPLETED] phases: 
        - Log warning but do not downgrade (completed is final)
        - Log: "Warning: Plan shows more completed phases than metadata"

   2. **In Progress Phase Recovery**:
      - If metadata.phases_completed indicates active work but no [IN PROGRESS] phase found:
        - Find first [NOT STARTED] phase after completed phases
        - Update to [IN PROGRESS]
        - Log: "Corrected Phase {N} to [IN PROGRESS] based on active work"

   3. **Partial Phase Recovery**:
      - If metadata.status == "partial" and no [PARTIAL] phase found:
        - Find the phase at metadata.phases_completed + 1
        - If it shows [NOT STARTED] or [IN PROGRESS], update to [PARTIAL]
        - Log: "Marked Phase {N} as [PARTIAL] based on partial completion"

   4. **Not Started During Active Work**:
      - If metadata.phases_completed > 0 but current phase shows [NOT STARTED]:
        - Update to [IN PROGRESS] (work has begun on this phase)
        - Log: "Corrected Phase {N} from [NOT STARTED] to [IN PROGRESS]"

## Validation Checklist

- [ ] Metadata file exists and is valid JSON
- [ ] Summary artifact created at correct path
- [ ] state.json updated with correct status
- [ ] TODO.md updated with status and summary link
- [ ] Phase status markers in plan file match metadata.phases_completed

## Trigger Conditions

- Task language is general, meta, markdown
- /implement command invoked
