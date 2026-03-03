---
description: Analyze errors and create fix plans
---

# Command: /errors

**Purpose**: Analyze errors.json, identify patterns, and create fix plans  
**Layer**: 2 (Command File - Argument Parsing Agent)  
**Delegates To**: Task (for creating fix tasks)

---

## Argument Parsing

<argument_parsing>
  <step_1>
    Parse arguments:
    - No args: Analysis mode
    - --fix OC_N or --fix N: Fix mode for specific task number (strip OC_ prefix for state.json lookup)

    Extract fix_task_number if --fix flag present; strip OC_ prefix to get integer
  </step_1>
</argument_parsing>

---

## Workflow Execution

<analysis_mode>
  <step_1>
    <action>Load Error Data</action>
    <process>
      Read specs/errors.json if exists, initialize if missing:
      ```json
      {
        "errors": [],
        "_schema_version": "1.0.0"
      }
      ```
      
      Extract error array and metadata.
    </process>
  </step_1>

  <step_2>
    <action>Analyze Patterns</action>
    <process>
      Group errors by:
      - Type: delegation_hang, timeout, build_error, etc.
      - Severity: critical, high, medium, low
      - Recurrence: How often each error repeats
      - Context: Which commands/agents trigger them
      
      Identify:
      - Most frequent error types
      - Highest severity unfixed errors
      - Patterns suggesting root causes
      - Quick wins (easy fixes)
    </process>
  </step_2>

  <step_3>
    <action>Create Analysis Report</action>
    <process>
      Write to specs/errors/analysis-{DATE}.md
      
      Include sections:
      - Summary (total, unfixed, fixed counts)
      - Summary by type table
      - Critical errors (unfixed)
      - Pattern analysis
      - Recommended fix plan (prioritized)
      - Suggested tasks
    </process>
  </step_3>

  <step_4>
    <action>Create Fix Tasks</action>
    <process>
      For significant error patterns:
      
      Use TodoWrite to create tasks:
      ```
      /task "Fix: {error description} ({N} occurrences)"
      ```
      
      Track created task numbers in report.
    </process>
  </step_4>

  <step_5>
    <action>Output Results</action>
    <process>
      Display summary:
      - Report location
      - Error statistics
      - Top patterns
      - Created tasks
      
      Return to orchestrator
    </process>
  </step_5>
</analysis_mode>

<fix_mode>
  <step_1>
    <action>Load Fix Task</action>
    <process>
      Read task {fix_task_number} from specs/state.json
      Verify it's an error-fix task by checking title for "Fix:"
      
      Extract task metadata (description, context).
    </process>
  </step_1>

  <step_2>
    <action>Identify Related Errors</action>
    <process>
      Find errors in errors.json linked to this task:
      - By task number in context
      - By matching task description patterns
      - By error type mentioned in task
      
      Build list of errors to fix.
    </process>
  </step_2>

  <step_3>
    <action>Delegate to Task Creation</action>
    <process>
      For each error pattern needing fix:
      
      Delegate to Task to create subtask:
      ```
      Delegate to Task with:
      - description: "Fix error: {error_type} - {error_message}"
      - priority: based on error severity
      - context: error details and fix approach
      ```
    </process>
  </step_3>

  <step_4>
    <action>Update Error Status</action>
    <process>
      For errors being addressed:
      Update errors.json entries:
      ```json
      {
        "fix_status": "in_progress",
        "fix_task": {fix_task_number},
        "fix_date": "ISO_DATE"
      }
      ```
      
      Use jq for safe updates.
    </process>
  </step_4>

  <step_5>
    <action>Git Commit</action>
    <process>
      ```bash
      git add specs/
      git commit -m "errors: create fix tasks for task {fix_task_number}"
      ```
    </process>
  </step_5>

  <step_6>
    <action>Output Results</action>
    <process>
      Display fix summary:
      - Task being fixed
      - Errors identified
      - Fix tasks created
      - Next steps
      
      Return to orchestrator
    </process>
  </step_6>
</fix_mode>
</workflow_execution>

---

## Error Handling

<error_handling>
  <argument_errors>
    - Invalid task number -> Return error with guidance
    - Task not found -> Return error message
  </argument_errors>
  
  <execution_errors>
    - jq failures -> Return error with technical details
    - File permission errors -> Return error with guidance
    - Git commit failures -> Log warning, continue
    - TodoWrite failures -> Log error, continue with analysis
  </execution_errors>
</error_handling>

---

## State Management

<state_management>
  <reads>
    specs/errors.json
    specs/state.json
  </reads>
  
  <writes>
    specs/errors/analysis-{DATE}.md
    specs/errors.json (status updates)
  </writes>
</state_management>