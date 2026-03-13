---
description: Create new version of implementation plan, or update task description if no plan exists
---

**DO NOT start with a markdown heading.** Your first output must be a plain line using the actual argument value. If $ARGUMENTS is `72` or `OC_72`, output:

[Revising] Task OC_72: (project_name once known from state.json)

Substitute the real integer from $ARGUMENTS — never output "OC_N" or "OC_NN" literally.

---

**Task Input (required):** $ARGUMENTS

<context>
  <system_context>Revise command with conditional routing</system_context>
  <task_context>Parse task number and optional reason, determine if plan exists, route to appropriate agent</task_context>
</context>

<context_injection>
  <file path=".opencode/context/core/formats/plan-format.md" variable="plan_format" />
  <file path=".opencode/context/core/standards/status-markers.md" variable="status_markers" />
</context_injection>

<role>Revise command agent - Parse arguments, check for existing plan, route to planner or task-updater</role>

<task>
  Parse task number from $ARGUMENTS, check for existing implementation plan, route to appropriate agent based on plan existence
</task>

<workflow_execution>
  <stage id="1" name="LoadContext">
    <action>Read context files defined in <context_injection></action>
    <process>
      1. Load plan-format.md -> {plan_format}
      2. Load status-markers.md -> {status_markers}
    </process>
    <checkpoint>Context loaded: plan_format, status_markers</checkpoint>
  </stage>
  
  <stage id="2" name="ParseAndValidate">
    <action>Parse task number and check for existing plan</action>
    <process>
      1. Parse task number and optional reason from $ARGUMENTS
         - Extract first token as task_number
         - Extract remaining tokens as reason (optional)
         - Validate task_number matches OC_N or N (accept with or without OC_ prefix)
         - If invalid: Return error "Usage: /revise <OC_N> [REASON]"
       
      2. Validate state.json exists and is valid
         - Check specs/state.json exists
         - Validate is valid JSON with jq
         - If missing/corrupt: Return error "Run /meta to regenerate state.json"
       
      3. Lookup task in state.json
         - Strip OC_ prefix if present:
           task_num=$(echo "$task_number" | sed 's/^OC_//')
         - Use jq to find task by project_number:
           task_data=$(jq -r --arg num "$task_num" \
             '.active_projects[] | select(.project_number == ($num | tonumber))' \
             specs/state.json)
         - If task_data is empty: Return error "Task OC_$task_num not found"
       
      4. Extract all metadata at once
         - language=$(echo "$task_data" | jq -r '.language // "general"')
         - status=$(echo "$task_data" | jq -r '.status')
         - project_name=$(echo "$task_data" | jq -r '.project_name')
         - description=$(echo "$task_data" | jq -r '.description // ""')
         - priority=$(echo "$task_data" | jq -r '.priority')

      5. Display header — output this line immediately using the actual values from steps 3-4:

         [Revising] Task OC_N: project_name

         (e.g. if N=200 and project_name="my_task", output: `[Revising] Task OC_200: my_task`)

      6. Check for existing implementation plan
         - Find latest plan: `specs/OC_{NNN}_{SLUG}/plans/implementation-{LATEST}.md`
         - If plan exists:
              plan_exists=true
              plan_path="specs/{project_slug}/plans/implementation-{LATEST}.md"
         - Else:
              plan_exists=false
              plan_path=""

      7. Validate task status allows revision
         case "$status" in
           "completed"|"implemented")
             if [ -n "$reason" ]; then
               echo "Warning: Task $task_number already completed"
               echo "Creating revised plan for future implementation"
             else
               echo "Warning: Task $task_number already completed - no reason provided"
               echo "Creating revised plan for additional context"
             fi
             ;;
           "planned"|"researched"|"partial"|"revised")
             # Status allows revision, proceed
             ;;
           "implementing")
             echo "Warning: Task $task_number is currently being implemented"
             echo "If previous implementation crashed: /task --sync to reset status"
             echo "To force revision despite implementation in progress: /revise $task_number --force"
             exit 1
             ;;
           "not_started"|"abandoned")
             echo "Error: Task $task_number status is $status"
             echo "Recommendation: Complete prerequisites before revising"
             echo "To override: /revise $task_number --force"
             exit 1
             ;;
           *)
             echo "Warning: Unknown status '$status' for task $task_number"
             echo "Proceeding with revision, but status may be invalid"
             ;;
         esac
    </process>
    <checkpoint>Task validated, plan existence checked, routing determined</checkpoint>
  </stage>
  
  <stage id="3" name="RouteAndExecute">
    <action>Route to appropriate agent based on plan existence</action>
    <process>
      1. Determine target agent based on plan existence
         if [ "$plan_exists" = true ]; then
              target_agent="planner-agent"
              operation="revise_plan"
         else
              target_agent="task-expander"
              operation="update_description"
         fi
       
      2. Generate session_id for tracking
         - session_id="sess_$(date +%s)_$(head -c 6 /dev/urandom | base64 | tr -dc 'a-z0-9')"
         - Store for later use: expected_session_id="$session_id"
         - Log: "Generated session_id: ${session_id}"
      
      3. Invoke target agent via task tool
         if [ "$plan_exists" = true ]; then
              task(
                subagent_type="planner-agent",
                prompt="""
                Revise implementation plan for task ${task_number}: ${reason}. 
                Current status: ${status}. 
                Existing plan: ${plan_path}
                
                <system_context>
                Using the following format standards and guidelines:
                {plan_format}
                {status_markers}
                </system_context>
                
                IMPORTANT: Always use the injected plan-format.md context. 
                Do NOT use embedded templates from command specifications.
                If plan_format is not available, load @.opencode/context/core/formats/plan-format.md directly.
                """,
                description="Revise implementation plan for task ${task_number}",
                session_id="${session_id}"
              )
         else
              task(
                subagent_type="task-expander",
                prompt="Update task ${task_number} description. New description: ${reason}. Current description: ${description}",
                description="Update task description for task ${task_number}",
                session_id="${session_id}"
              )
         fi
      
      4. Wait for agent to complete and capture return
         - Subagent returns JSON to stdout
         - Log: "Agent completed, validating return"
         - Capture in variable: subagent_return
    </process>
    <checkpoint>Delegated to appropriate agent, return captured</checkpoint>
  </stage>
  
  <stage id="4" name="ValidateReturn">
    <action>Validate agent return format and artifacts</action>
    <process>
      1. Log return for debugging
         - Log first 500 chars of return
         - Log: "Validating return from ${target_agent}"
      
      2. VALIDATION STEP 1: Validate JSON Structure
         - Parse return as JSON using jq
         - If parsing fails:
           * Log error: "[FAIL] Invalid JSON return from ${target_agent}"
           * Return error to user: "Subagent return validation failed: Cannot parse return as JSON"
           * Recommendation: "Fix ${target_agent} subagent return format"
           * Exit with error
         - If parsing succeeds:
           * Log: "[PASS] Return is valid JSON"
      
      3. VALIDATION STEP 2: Validate Required Fields
         - Check required fields exist: status, summary, artifacts, metadata
         - Check metadata subfields exist: session_id, agent_type, delegation_depth, delegation_path
         - For each missing field:
           * Log error: "[FAIL] Missing required field: ${field}"
           * Return error to user: "Subagent return validation failed: Missing required field: ${field}"
           * Recommendation: "Fix ${target_agent} subagent to include all required fields"
           * Exit with error
         - If all fields present:
           * Log: "[PASS] All required fields present"
      
      4. VALIDATION STEP 3: Validate Status Field
         - Extract status from return: status=$(echo "$subagent_return" | jq -r '.status')
         - Check status is valid enum: completed, partial, failed, blocked
         - If status invalid:
           * Log error: "[FAIL] Invalid status: ${status}"
           * Log: "Valid statuses: completed, partial, failed, blocked"
           * Return error to user: "Subagent return validation failed: Invalid status: ${status}"
           * Recommendation: "Fix ${target_agent} subagent to use valid status enum"
           * Exit with error
         - If status valid:
           * Log: "[PASS] Status is valid: ${status}"
      
      5. VALIDATION STEP 4: Validate Session ID
         - Extract returned session_id: returned_session_id=$(echo "$subagent_return" | jq -r '.metadata.session_id')
         - Compare with expected session_id (from delegation context)
         - If mismatch:
           * Log error: "[FAIL] Session ID mismatch"
           * Log: "Expected: ${expected_session_id}"
           * Log: "Got: ${returned_session_id}"
           * Return error to user: "Subagent return validation failed: Session ID mismatch"
           * Recommendation: "Fix ${target_agent} subagent to return correct session_id"
           * Exit with error
         - If match:
           * Log: "[PASS] Session ID matches"
      
      6. VALIDATION STEP 5: Validate Artifacts (if applicable)
         - For task-expander (description update): No artifacts expected
         - For planner-agent (plan revision):
              a. Check artifacts array is non-empty
                 - artifact_count=$(echo "$subagent_return" | jq '.artifacts | length')
                 - If artifact_count == 0:
                      * Log error: "[FAIL] Agent returned 'completed' status but created no artifacts"
                      * Log error: "Error: Phantom revision created - status=completed but no artifacts"
                      * Return error to user: "Subagent return validation failed: Phantom revision detected"
                      * Recommendation: "Verify planner-agent creates artifacts before updating status"
                      * Exit with error
                 - Else:
                      * Log: "[INFO] Artifact count: ${artifact_count}"
              
              b. Verify each artifact exists on disk
                 - Extract artifact paths: artifact_paths=$(echo "$subagent_return" | jq -r '.artifacts[].path')
                 - For each path in artifact_paths:
                      * Check file exists: [ -f "$path" ]
                      * If file does not exist:
                        - Log error: "[FAIL] Artifact does not exist: ${path}"
                        - Return error to user: "Subagent return validation failed: Artifact not found: ${path}"
                        * Recommendation: "Verify planner-agent writes artifacts to correct paths"
                        * Exit with error
                      * If file exists:
                        - Log: "[PASS] Artifact exists: ${path}"
              
              c. Verify each artifact is non-empty
                 - For each path in artifact_paths:
                      * Check file is non-empty: [ -s "$path" ]
                      * If file is empty:
                        - Log error: "[FAIL] Artifact is empty: ${path}"
                        - Return error to user: "Subagent return validation failed: Empty artifact: ${path}"
                        * Recommendation: "Verify planner-agent writes content to artifacts"
                        * Exit with error
                      * If file is non-empty:
                        - file_size=$(stat -c%s "$path" 2>/dev/null || stat -f%z "$path")
                        - Log: "[PASS] Artifact is non-empty: ${path} (${file_size} bytes)"
              
              d. Log validation success
                 - Log: "[PASS] ${artifact_count} artifacts validated"
         
         - Else (status != "completed"):
           * Log: "[INFO] Skipping artifact validation (status=${status})"
           * Note: Partial/failed/blocked status may have empty or incomplete artifacts
       
      7. Validation Summary
         - Log: "[PASS] Return validation succeeded"
         - Log: "Status: ${status}"
         - If status == "completed":
           * Log: "Artifacts: ${artifact_count} validated"
    </process>
    <checkpoint>Subagent return validated, all checks passed</checkpoint>
  </stage>
  
  <stage id="5" name="RelayResult">
    <action>Relay validated result to user</action>
    <process>
      1. Extract key information from validated return
         - summary=$(echo "$subagent_return" | jq -r '.summary')
         - next_steps=$(echo "$subagent_return" | jq -r '.next_steps // "None"')
         - operation_type=$(echo "$subagent_return" | jq -r '.operation_type // "unknown"')
       
      2. Format response for user
         case "$operation_type" in
           "revise_plan")
              echo "✅ Implementation plan revised successfully"
              echo "New plan created: ${summary}"
              ;;
           "update_description")
              echo "✅ Task description updated successfully"
              echo "New description: ${summary}"
              ;;
           *)
              echo "✅ Revision completed"
              echo "Summary: ${summary}"
              ;;
         esac
       
      3. List next steps
         if [ -n "$next_steps" ]; then
              echo ""
              echo "**Next Steps:**"
              echo "$next_steps"
         fi
       
      4. Return to user
    </process>
    <checkpoint>Result relayed to user</checkpoint>
  </stage>
</workflow_execution>

## Usage

```bash
# Revise existing implementation plan
/revise 259 "Add comprehensive error handling"

# Revise with force override
/revise 259 --force "Add error handling despite completed status"

# Update task description (no plan exists)
/revise 259 "Change scope to include mobile support"

# Update task description (plan exists)
/revise 259 "Add error handling section to plan"
```

## Arguments

- **TASK_NUMBER**: Required - Task number to revise
- **REASON**: Optional - Reason for revision or description update

## What This Does

1. Parses task number and optional reason from arguments
2. Validates task exists in state.json
3. Extracts all metadata (language, status, description, priority)
4. Checks for existing implementation plan
5. Routes conditionally:
   - If plan exists: Delegates to planner-agent for plan revision
   - If no plan: Delegates to task-expander for description update
6. Validates agent returns and artifacts
7. Provides formatted results to user

## Conditional Routing

| Plan Exists | Target Agent | Operation | Description |
|--------------|--------------|-----------|-----------|
| Yes | planner-agent | revise_plan | Create new version of implementation plan |
| No | task-expander | update_description | Update task description |

## Language Compatibility

All task operations are language-agnostic and work with any task type.

## Features

- **Smart Routing**: Automatically detects plan existence and routes appropriately
- **Plan Revision**: Creates new versions of existing implementation plans
- **Description Updates**: Allows task description updates without creating plans
- **Status Validation**: Respects current task status with --force override
- **Session Tracking**: Consistent session management across operations
- **Context Injection**: Injects plan-format.md and status-markers.md for plan revisions (ensures format compliance)

## Context Injection

This command uses the Push context loading model to ensure plan format compliance:

1. **plan-format.md**: Loaded and injected into planner-agent prompts to ensure revised plans follow the specification
2. **status-markers.md**: Loaded for status validation and transitions

**Fallback Mechanism**: If context injection fails, the planner-agent is instructed to load plan-format.md directly via @-reference.

See individual subagent files for detailed operation implementations.