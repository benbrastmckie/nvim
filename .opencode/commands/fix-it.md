---
description: Scan files for FIX, NOTE, TODO, QUESTION tags and create structured tasks interactively
---

# Command: /fix-it

**Purpose**: Scans codebase files for embedded tags (`FIX:`, `NOTE:`, `TODO:`, `QUESTION:`) and creates structured tasks based on user selection. This command helps capture and track issues, notes, pending work, and research questions found in code comments.  
**Layer**: 2 (Command File - Argument Parsing Agent)  
**Delegates To**: skill-fix-it

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
    <action>Delegate to Fix-It Skill</action>
    <input>
      - skill: "skill-fix-it"
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
      - QUESTION: tags found
      
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

---

## Examples

```bash
/fix-it                           # Scan entire project for tags
/fix-it src/                      # Scan specific directory
/fix-it src/core.lua src/utils/   # Scan multiple paths
```

---

## Migration Notes

**Command Renamed**: This command was previously `/fix`. It has been renamed to `/fix-it` to align with the .claude/ system and to better reflect the interactive "fix-it" workflow.

**Backward Compatibility**: Existing scripts and documentation should be updated to use `/fix-it`. The old `/fix` command is no longer available.
