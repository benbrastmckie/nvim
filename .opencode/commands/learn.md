---
description: Scan files for FIX, NOTE, TODO tags and create structured tasks interactively
---

# Command: /learn

**Purpose**: Scans codebase files for embedded tags (`FIX:`, `NOTE:`, `TODO:`) and creates structured tasks based on user selection  
**Layer**: 2 (Command File - Argument Parsing Agent)  
**Delegates To**: skill-learn

---

## Argument Parsing

<argument_parsing>
  <step_1>
    Parse arguments:
    paths = remaining args (optional)
    
    If no paths: Scan entire project
    If paths provided: Scan specified files/directories
  </step_1>
</argument_parsing>

---

## Workflow Execution

<workflow_execution>
  <step_1>
    <action>Delegate to Learn Skill</action>
    <input>
      - skill: "skill-learn"
      - args: "paths={paths}"
    </input>
    <expected_return>
      {
        "status": "completed",
        "tags_found": {...},
        "tasks_created": [...],
        "interactive_selection": {...}
      }
    </expected_return>
  </step_1>

  <step_2>
    <action>Present Results</action>
    <process>
      Display tag scan results:
      - FIX: tags found
      - NOTE: tags found  
      - TODO: tags found
      
      Display task creation results:
      - Tasks created by type
      - Task numbers and paths
      - Next step guidance
      
      Return to orchestrator
    </process>
  </step_2>
</workflow_execution>

---

## Error Handling

<error_handling>
  <argument_errors>
    - Invalid paths -> Return error with guidance
  </argument_errors>
  
  <execution_errors>
    - Skill failure -> Return error message
    - No tags found -> Inform user, no error
  </execution_errors>
  
  <interactive_errors>
    - User cancels selection -> Exit gracefully
  </interactive_errors>
</error_handling>

---

## State Management

<state_management>
  <reads>
    Specified paths (or entire project)
  </reads>
  
  <writes>
    None (skill handles task creation via TodoWrite)
  </writes>
</state_management>