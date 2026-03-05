---
description: Add a memory to the vault with interactive checkbox confirmation
---

# Command: /remember

**Purpose**: Takes text or file paths, analyzes content, and adds them to the memory vault with interactive checkbox confirmation. Supports task mode for reviewing task artifacts and creating classified memories.  
**Layer**: 2 (Command File - Argument Parsing Agent)  
**Delegates To**: skill-remember (direct execution)

---

## Argument Parsing

<argument_parsing>
  <step_1>
    Parse arguments:
    - Check for --task flag: `--task OC_N`
    - If --task present: Task mode - parse task number
    - If no --task: Standard mode - first argument is text/file
    
    task_mode = "--task" in $ARGUMENTS
    task_number = extract_value("--task") if task_mode
    
    If not task_mode:
      - First argument is either text content or file path
      - If path exists: treat as file
      - If path doesn't exist: treat as text content
      
      input = remaining args joined with spaces
      is_file = file_exists(input)
  </step_1>
</argument_parsing>

---

## Workflow Execution

<workflow_execution>
  <step_1>
    <action>Delegate to Remember Skill</action>
    <input>
      If task_mode:
        - skill: "skill-remember"
        - args: "mode=task, task_number={task_number}"
      Else:
        - skill: "skill-remember"
        - args: "mode=standard, input={input}, is_file={is_file}"
    </input>
    <expected_return>
      {
        "status": "completed",
        "mode": "task|standard",
        "memory_id": "MEM-YYYY-MM-DD-NNN",
        "actions_taken": ["added", "updated"],
        "file_path": "path/to/memory.md",
        "artifacts_reviewed": [...]  // task mode only
      }
    </expected_return>
  </step_1>

  <step_2>
    <action>Present Results</action>
    <process>
      If task_mode:
        Display task artifact review results:
        - Number of artifacts reviewed
        - Artifacts processed by classification
        - Memories created per category
        
      Else:
        Display memory operations completed:
        - List of memories added/updated
        - File paths
        
      Display Git commit info and next steps guidance
    </process>
  </step_2>
</workflow_execution>

---

## Task Mode

When invoked with `--task OC_N`, /remember enters task mode for reviewing task artifacts:

### Workflow

1. **Parse Task Directory**: Locate specs/OC_{N}_{SLUG}/ directory
2. **Scan Artifacts**: Find all files in subdirectories:
   - reports/ - Research reports
   - plans/ - Implementation plans
   - summaries/ - Completion summaries
   - code/ - Code artifacts
   - Any other artifact directories
3. **Present Artifact List**: Show numbered list of all found files
4. **Interactive Selection**: Let user select which artifacts to review
5. **Review Content**: Display selected file content in manageable chunks
6. **Classification**: Present 5-category taxonomy for each artifact:
   - [TECHNIQUE] - Reusable method or approach
   - [PATTERN] - Design or implementation pattern
   - [CONFIG] - Configuration or setup knowledge
   - [WORKFLOW] - Process or procedure
   - [INSIGHT] - Key learning or understanding
   - [SKIP] - Not valuable for memory
7. **Create Memories**: Generate memory entries with classification tags
8. **Update Index**: Link new memories in vault index

### Example Usage

```bash
/remember --task 142                    # Review all artifacts from task 142
/remember --task 142 --category PATTERN # Focus on pattern extraction only
```

---

## Standard Mode

Original behavior for adding arbitrary text or files:

```bash
/remember "Text content to save"        # Add text as memory
/remember /path/to/file.md              # Add file content as memory
```

---

## Error Handling

<error_handling>
  <argument_errors>
    - No arguments provided (standard mode) -> "Usage: /remember <text or file path> OR /remember --task OC_N"
    - Invalid file path (standard mode) -> "File not found: {path}"
    - Invalid task number (task mode) -> "Task not found: OC_{N}"
    - Non-existent task directory -> "Task directory not found: specs/OC_{N}_*"
  </argument_errors>
  
  <execution_errors>
    - Skill failure -> Return error details
    - MCP unavailable -> Continue with direct file access
    - No artifacts found in task -> "No artifacts found for task OC_{N}"
  </execution_errors>
  
  <interactive_errors>
    - User cancels -> Exit gracefully, no files created
    - All artifacts skipped -> "No memories created (all artifacts skipped)"
  </interactive_errors>
</error_handling>

---

## State Management

<state_management>
  <reads>
    - specs/OC_{N}_*/ (task mode - artifact directories)
    - .opencode/memory/30-Templates/memory-template.md
    - .opencode/memory/10-Memories/ (for ID generation)
  </reads>
  
  <writes>
    - .opencode/memory/10-Memories/*.md (new memory files)
    - .opencode/memory/20-Indices/index.md (updated links)
  </writes>
</state_management>