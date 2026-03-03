---
description: Interactive system builder that creates TASKS for agent architecture changes (never implements directly)
---

# Command: /meta

**Purpose**: Interactive system builder that delegates to skill-meta for creating TASKS for .opencode/ system changes  
**Layer**: 2 (Command File - Argument Parsing Agent)  
**Delegates To**: skill-meta

---

## Argument Parsing

<argument_parsing>
  <step_1>
    Parse arguments to determine mode:
    
    if $ARGUMENTS is empty:
      mode = "interactive"
    elif $ARGUMENTS == "--analyze":
      mode = "analyze"
    else:
      mode = "prompt"
      prompt = $ARGUMENTS
  </step_1>
  
  <step_2>
    Validate constraints:
    - This command MUST NOT directly create files
    - This command MUST track work via tasks
    - This command MUST require user confirmation
  </step_2>
</argument_parsing>

---

## Workflow Execution

<workflow_execution>
  <step_1>
    <action>Delegate to Meta Skill</action>
    <input>
      - skill: "skill-meta"
      - args: "mode={mode} prompt={prompt}"
    </input>
    <expected_return>
      {
        "status": "completed" | "cancelled",
        "tasks_created": [...],
        "analysis": {...},
        "message": "..."
      }
    </expected_return>
  </step_1>

  <step_2>
    <action>Present Results</action>
    <process>
      Based on agent return:
      - Interactive/Prompt modes: Display created tasks and next steps
      - Analyze mode: Display component inventory and recommendations
      - Cancelled: Acknowledge user cancellation
    </process>
  </step_2>

  <step_3>
    <action>Return to Orchestrator</action>
    <process>
      Display standardized output format based on mode
      
      For tasks created:
      - Show task numbers and paths
      - Provide next step guidance (/research, /plan, /implement)
      
      For analysis:
      - Show current component counts
      - Provide recommendations
      
      Return to orchestrator
    </process>
  </step_3>
</workflow_execution>

---

## Error Handling

<error_handling>
  <argument_errors>
    - Invalid flags -> Return usage help
  </argument_errors>
  
  <execution_errors>
    - Skill failure -> Return error message
    - Invalid mode -> Return error with guidance
  </execution_errors>
  
  <constraint_violations>
    - If skill attempts direct file creation -> Return error "Meta command must delegate, not implement directly"
    - If skill skips task creation -> Return error "Meta command must create tasks for all work"
  </constraint_violations>
</error_handling>

---

## State Management

<state_management>
  <reads>
    .opencode/ structure (for analyze mode)
    specs/state.json (for mode detection)
  </reads>
  
  <writes>
    None (read-only command - task creation handled by skill)
  </writes>
</state_management>