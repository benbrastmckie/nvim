---
description: Archive completed and abandoned tasks
---

# Command: /todo

**Purpose**: Archive completed and abandoned tasks to clean up active task list  
**Layer**: 2 (Command File - Argument Parsing Agent)  
**Delegates To**: None (Direct execution)

---

## Argument Parsing

<argument_parsing>
  <step_1>
    Parse arguments:
    dry_run = "--dry-run" in $ARGUMENTS
  </step_1>
</argument_parsing>

---

## Workflow Execution

<workflow_execution>
  <step_1>
    <action>Scan for Archivable Tasks</action>
    <process>
      Read specs/state.json and identify:
      - Tasks with status = "completed"
      - Tasks with status = "abandoned"
      
      Read specs/TODO.md and cross-reference:
      - Entries marked [COMPLETED]
      - Entries marked [ABANDONED]
    </process>
  </step_1>

  <step_2>
    <action>Detect Orphaned Directories</action>
    <process>
      Scan for project directories not tracked in any state file.
      
      Get orphaned directories in specs/ (not tracked anywhere):
      ```bash
      orphaned_in_specs=()
      # Match both OC_ prefixed (OpenCode) and plain number (Claude Code) directories
      for dir in specs/OC_[0-9]*_*/ specs/[0-9]*_*/; do
        [ -d "$dir" ] || continue
        basename_dir=$(basename "$dir")
        # Strip OC_ prefix if present for numeric lookup
        project_num=$(echo "$basename_dir" | sed 's/^OC_//' | cut -d_ -f1)
        
        in_active=$(jq -r --arg n "$project_num" \
          '.active_projects[] | select(.project_number == ($n | tonumber)) | .project_number' \
          specs/state.json 2>/dev/null)
        
        in_archive=$(jq -r --arg n "$project_num" \
          '.completed_projects[] | select(.project_number == ($num | tonumber)) | .project_number' \
          specs/archive/state.json 2>/dev/null)
        
        if [ -z "$in_active" ] && [ -z "$in_archive" ]; then
          orphaned_in_specs+=("$dir")
        fi
      done
      ```
      
      Get orphaned directories in archive/ (not tracked in state):
      ```bash
      orphaned_in_archive=()
      # Match both OC_ prefixed (OpenCode) and plain number (Claude Code) directories
      for dir in specs/archive/OC_[0-9]*_*/ specs/archive/[0-9]*_*/; do
        [ -d "$dir" ] || continue
        basename_dir=$(basename "$dir")
        # Strip OC_ prefix if present for numeric lookup
        project_num=$(echo "$basename_dir" | sed 's/^OC_//' | cut -d_ -f1)
        
        in_archive=$(jq -r --arg n "$project_num" \
          '.completed_projects[] | select(.project_number == ($num | tonumber)) | .project_number' \
          specs/archive/state.json 2>/dev/null)
        
        if [ -z "$in_archive" ]; then
          orphaned_in_archive+=("$dir")
        fi
      done
      ```
      
      Combine for archival operations.
    </process>
  </step_2>

  <step_3>
    <action>Detect Misplaced Directories</action>
    <process>
      Scan for project directories in specs/ that ARE tracked in specs/archive/state.json:
      ```bash
      misplaced_in_specs=()
      # Match both OC_ prefixed (OpenCode) and plain number (Claude Code) directories
      for dir in specs/OC_[0-9]*_*/ specs/[0-9]*_*/; do
        [ -d "$dir" ] || continue
        basename_dir=$(basename "$dir")
        # Strip OC_ prefix if present for numeric lookup
        project_num=$(echo "$basename_dir" | sed 's/^OC_//' | cut -d_ -f1)
        
        in_active=$(jq -r --arg n "$project_num" \
          '.active_projects[] | select(.project_number == ($num | tonumber)) | .project_number' \
          specs/state.json 2>/dev/null)
        
        in_archive=$(jq -r --arg n "$project_num" \
          '.completed_projects[] | select(.project_number == ($num | tonumber)) | .project_number' \
          specs/archive/state.json 2>/dev/null)
        
        if [ -z "$in_active" ] && [ -n "$in_archive" ]; then
          misplaced_in_specs+=("$dir")
        fi
      done
      ```
    </process>
  </step_3>

  <step_4>
    <action>Scan Roadmap for Task References</action>
    <process>
      Use structured extraction from completion_summary fields, falling back to exact (Task {N}) matching.
      
      Separate meta and non-meta tasks.
      For non-meta tasks with completion summaries, match against ROAD_MAP.md:
      - Explicit roadmap_items (highest confidence)
      - Exact (Task N) references
      - Summary-based search (optional)
      
      Track roadmap_matches array with confidence levels.
    </process>
  </step_4>

  <step_5>
    <action>Scan Meta Tasks for CLAUDE.md Suggestions</action>
    <process>
      For meta tasks, extract claudemd_suggestions if present.
      Track by action type:
      - Add: Insert new content
      - Update: Replace existing content  
      - Remove: Delete content
      - None: No changes needed
    </process>
  </step_5>

  <step_6>
    <action>Dry Run Output (if --dry-run)</action>
    <process>
      Display comprehensive preview:
      - Tasks to archive (completed/abandoned)
      - Orphaned directories (specs/archive counts)
      - Misplaced directories count
      - Roadmap updates needed
      - CLAUDE.md suggestions
      
      Exit after display.
    </process>
  </step_6>

  <step_7>
    <action>Handle Interactive Prompts</action>
    <process>
      If orphaned directories found:
      Use AskUserQuestion for track/skip decision
      
      If misplaced directories found:
      Use AskUserQuestion for move/skip decision
      
      Store decisions for use in archival steps.
    </process>
  </step_7>

  <step_8>
    <action>Archive Tasks</action>
    <process>
      A. Update specs/archive/state.json
      B. Update specs/state.json (remove archived tasks)
      C. Update specs/TODO.md (remove archived entries)
      D. Move project directories to archive/
      E. Track orphaned directories (if approved)
      F. Move misplaced directories (if approved)
    </process>
  </step_8>

  <step_9>
    <action>Update Roadmap for Archived Tasks</action>
    <process>
      For each roadmap match:
      - Skip if already annotated
      - Apply appropriate annotation (use OC_ prefix for OpenCode tasks):
        * Completed: - [x] item *(Completed: Task OC_N, DATE)*
        * Abandoned: - [ ] item *(Task OC_N abandoned: reason)*
      - Track changes: completed_annotated, abandoned_annotated, skipped
    </process>
  </step_9>

  <step_10>
    <action>Interactive CLAUDE.md Suggestion Selection</action>
    <process>
      For actionable meta task suggestions:
      A. Filter suggestions where action != "none"
      B. Present AskUserQuestion with multiSelect
      C. Apply selected suggestions via Edit tool
      D. Display results (applied/failed/skipped)
      E. Acknowledge "none" action tasks
    </process>
  </step_10>

  <step_11>
    <action>Git Commit</action>
    <process>
      Include comprehensive message with counts:
      - todo: archive {N} tasks
      - update {R} roadmap items  
      - track {M} orphans
      - move {P} misplaced directories
    </process>
  </step_11>

  <step_12>
    <action>Output Results</action>
    <process>
      Display complete summary:
      - Archived tasks (completed/abandoned counts)
      - Directory operations
      - Roadmap updates
      - CLAUDE.md suggestions
      - Active tasks remaining
    </process>
  </step_12>
</workflow_execution>

---

## Error Handling

<error_handling>
  <parsing_errors>
    - Invalid flags -> Return usage help
  </parsing_errors>
  
  <execution_errors>
    - jq failures -> Return error with technical details
    - File permission errors -> Return error with guidance
    - Git commit failures -> Log warning, continue
  </execution_errors>
  
  <interactive_errors>
    - User cancels prompts -> Exit gracefully
    - AskUserQuestion failures -> Default to conservative option
  </interactive_errors>
</error_handling>

---

## State Management

<state_management>
  <reads>
    specs/state.json
    specs/TODO.md
    specs/ROAD_MAP.md
    specs/archive/state.json
    specs/errors.json
  </reads>
  
  <writes>
    specs/archive/state.json
    specs/state.json
    specs/TODO.md
    specs/ROAD_MAP.md
    .opencode/CLAUDE.md
  </writes>
</state_management>