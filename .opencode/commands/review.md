---
description: Review code and create analysis reports
---

# Command: /review

**Purpose**: Analyze codebase, identify issues, and optionally create tasks  
**Layer**: 2 (Command File - Argument Parsing Agent)  
**Delegates To**: None (Direct execution)

---

## Argument Parsing

<argument_parsing>
  <step_1>
    Parse arguments:
    scope = $1 or "all"
    create_tasks = "--create-tasks" in $ARGUMENTS
    
    Determine review scope:
    - If file path: Review that file
    - If directory: Review all files in directory
    - If "all": Review entire codebase
  </step_1>
</argument_parsing>

---

## Workflow Execution

<workflow_execution>
  <step_1>
    <action>Load Review State</action>
    <process>
      Read existing specs/reviews/state.json
      Initialize if missing
    </process>
  </step_1>
  
  <step_2>
    <action>Gather Context</action>
    <process>
      For Lean files (.lean):
      - Run lean_diagnostic_messages
      - Check for sorry, axioms, admitted proofs
      - Identify incomplete theorems
      - Check import organization
      
      For general code:
      - Check for TODO/FIXME comments
      - Identify code smells
      - Check for security issues
      - Review error handling
      
      For documentation:
      - Check for outdated information
      - Identify missing documentation
      - Verify links work
    </process>
  </step_2>
  
  <step_3>
    <action>Roadmap Integration</action>
    <process>
      Load roadmap-format.md for parsing patterns
      Ensure specs/ROADMAP.md exists before parsing. If the file does not exist, create it with the default template:
      ```markdown
      # Project Roadmap

      ## Phase 1: Current Priorities (High Priority)

      - [ ] (No items yet -- add roadmap items here)

      ## Success Metrics

      - (Define success metrics here)
      ```
      Parse specs/ROADMAP.md:
      - Phase headers: ## Phase {N}: {Title} ({Priority})
      - Checkboxes: - [ ] and - [x]
      - Status tables: Component/Status/Location
      - Priority markers
      
      Build roadmap_state structure
      Cross-reference with project state
      Generate matches with confidence levels
    </process>
  </step_3>
  
  <step_4>
    <action>Analyze Findings</action>
    <process>
      Categorize issues:
      - Critical: Broken functionality, security vulnerabilities
      - High: Missing features, significant bugs
      - Medium: Code quality issues, incomplete implementations
      - Low: Style issues, minor improvements
    </process>
  </step_4>
  
  <step_5>
    <action>Create Review Report</action>
    <process>
      Write to specs/reviews/review-{DATE}.md
      
      Include sections:
      - Summary with issue counts
      - Critical, High, Medium, Low issues
      - Code quality metrics
      - Roadmap progress
      - Recommendations
    </process>
  </step_5>
  
  <step_6>
    <action>Annotate Completed Roadmap Items</action>
    <process>
      For high-confidence matches:
      Update ROADMAP.md checkboxes:
      - [x] item *(Completed: Task {N}, {DATE})*
      
      Update status tables for verified components
      
      Track changes in review state
    </process>
  </step_6>
  
  <step_7>
    <action>Update Review State</action>
    <process>
      Generate review entry with metadata
      Add to reviews array
      Update statistics
      Update _last_updated timestamp
    </process>
  </step_7>
  
  <step_8>
    <action>Create Tasks (if --create-tasks)</action>
    <process>
      For each High/Critical issue:
      Create task with /tool-task
      
      Update review state with created task numbers
      Increment statistics.total_tasks_created
    </process>
  </step_8>
  
  <step_9>
    <action>Generate Roadmap Task Recommendations</action>
    <process>
      Identify current goals from incomplete roadmap items
      Score items by priority and position
      Select top 5-7 recommendations
      Present to user for selection
      Create selected tasks
    </process>
  </step_9>
  
  <step_10>
    <action>Commit Changes</action>
    <process>
      Create targeted commit with only changed files:
      
      ```bash
      # Generate session ID
      session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
      
      # Get list of changed files
      git status --porcelain | awk '{print $NF}' > /tmp/changed_files_$$.txt
      changed_files=$(cat /tmp/changed_files_$$.txt | tr '\n' ' ')
      
      # Commit if there are changes
      if [ -n "$changed_files" ]; then
          git add $changed_files
          git commit -m "review: analyze ${scope} (task OC_${N})

Session: ${session_id}" || echo "Warning: Commit failed but review completed"
      fi
      
      # Cleanup
      rm -f /tmp/changed_files_$$.txt
      ```
      
      **Files committed** (when modified):
      - `specs/reviews/review-{DATE}.md` - Review report
      - `specs/reviews/state.json` - Review state updates
      - `specs/ROADMAP.md` - Roadmap annotations (if modified)
      - `specs/TODO.md` - Task updates (if status changes)
      
      **Error handling**: Commit failures are non-blocking. Log a warning and continue.
    </process>
  </step_10>

  <step_11>
    <action>Output Results</action>
    <process>
      Display comprehensive summary:
      - Issue statistics
      - Roadmap progress
      - Created tasks
      - Recommendations
      
      Return to orchestrator
    </process>
  </step_11>
</workflow_execution>

---

## Error Handling

<error_handling>
  <parsing_errors>
    - Invalid scope -> Return error with guidance
    - Missing review files -> Initialize with defaults
  </parsing_errors>
  
  <execution_errors>
    - Lean diagnostics failure -> Log warning, continue
    - Roadmap parsing errors -> Log warning, skip roadmap integration
    - File permission errors -> Return error with guidance
    - Git commit failures -> Log warning, continue
  </execution_errors>
</error_handling>

---

## State Management

<state_management>
  <reads>
    specs/reviews/state.json
    specs/ROADMAP.md
    specs/TODO.md
    specs/state.json
  </reads>
  
  <writes>
    specs/reviews/review-{DATE}.md
    specs/reviews/state.json
    specs/ROADMAP.md (if annotating)
  </writes>
</state_management>