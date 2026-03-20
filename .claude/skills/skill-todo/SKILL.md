---
name: skill-todo
description: Archive completed and abandoned tasks with CHANGE_LOG.md updates and memory harvest suggestions
allowed-tools: Bash, Edit, Read, Write, Grep, AskUserQuestion
context: direct
---

# Todo Skill

Direct execution skill for archiving tasks, updating CHANGE_LOG.md, and suggesting memory harvesting.

<context>
  <system_context>OpenCode task archival with changelog tracking and memory suggestions.</system_context>
  <task_context>Archive completed/abandoned tasks and track changes.</task_context>
</context>

<role>Direct execution skill for task archival operations with automated CHANGE_LOG updates and memory harvest suggestions.</role>

<task>Parse arguments, scan for archivable tasks, update states, generate CHANGE_LOG entries, suggest memory harvesting from completed task artifacts.</task>

<execution>
  <stage id="1" name="ParseArguments">
    <action>Parse command arguments</action>
    <process>
      1. Check for --dry-run flag
      2. Set dry_run = true if present
      3. Validate no other arguments expected
    </process>
  </stage>
  
  <stage id="2" name="ScanTasks">
    <action>Scan for archivable tasks</action>
    <process>
      1. Read specs/state.json
      2. Identify tasks with status = "completed"
      3. Identify tasks with status = "abandoned"
      4. Read specs/TODO.md and cross-reference
      5. Track counts: completed_count, abandoned_count
    </process>
  </stage>
  
  <stage id="3" name="DetectOrphans">
    <action>Detect orphaned directories and TODO.md orphans</action>
    <process>
      1. Scan specs/ for directories not tracked in state files:
         ```bash
         for dir in specs/OC_[0-9]*_*/ specs/[0-9]*_*/; do
           [ -d "$dir" ] || continue
           basename_dir=$(basename "$dir")
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

      2. Scan specs/archive/ for orphaned directories:
         ```bash
         for dir in specs/archive/OC_[0-9]*_*/ specs/archive/[0-9]*_*/; do
           [ -d "$dir" ] || continue
           basename_dir=$(basename "$dir")
           project_num=$(echo "$basename_dir" | sed 's/^OC_//' | cut -d_ -f1)

           in_archive=$(jq -r --arg n "$project_num" \
             '.completed_projects[] | select(.project_number == ($num | tonumber)) | .project_number' \
             specs/archive/state.json 2>/dev/null)

           if [ -z "$in_archive" ]; then
             orphaned_in_archive+=("$dir")
           fi
         done
         ```

      3. Scan TODO.md for completed/abandoned tasks not in state.json:
         ```lua
         -- Read TODO.md content
         local todo_content = read_file("specs/TODO.md")

         -- Pattern to match task headers: ### OC_{N}. or ### {N}.
         local task_pattern = "###%s+(OC_)?(%d+)%.%s+(.-)\n"

         -- Pattern to match status line
         local status_pattern = "%-%s+\*\*Status%*\*:%s+\[(COMPLETED|ABANDONED)\]"

         -- Extract all tasks with their status
         local todo_tasks = {}
         for prefix, num_str, name in todo_content:gmatch(task_pattern) do
           local task_num = tonumber(num_str)
           local task_entry = todo_content:match("(###%s+" .. (prefix or "") .. num_str .. "%." .. name .. ".-)\n###%s+")
             or todo_content:match("(###%s+" .. (prefix or "") .. num_str .. "%." .. name .. ".-)$")

           if task_entry then
             local status = task_entry:match(status_pattern)
             if status then
               table.insert(todo_tasks, {
                 project_number = task_num,
                 status = status:lower(),
                 project_name = name:gsub("%s*\n.*", ""), -- First line only
                 has_directory = vim.fn.isdirectory("specs/OC_" .. num_str .. "_" .. name:gsub("%s*\n.*", "")) == 1
                   or vim.fn.isdirectory("specs/" .. num_str .. "_" .. name:gsub("%s*\n.*", "")) == 1
               })
             end
           end
         end

         -- Cross-reference with state.json active_projects
         local todo_md_orphans = {}
         for _, task in ipairs(todo_tasks) do
           local in_active = false
           for _, proj in ipairs(state.active_projects or {}) do
             if proj.project_number == task.project_number then
               in_active = true
               break
             end
           end

           local in_archive = false
           if archive_state.completed_projects then
             for _, proj in ipairs(archive_state.completed_projects) do
               if proj.project_number == task.project_number then
                 in_archive = true
                 break
               end
             end
           end

           -- If task is in TODO.md as completed/abandoned but not in state.json and has directory
           if not in_active and not in_archive and task.has_directory then
             table.insert(todo_md_orphans, task)
           end
         end
         ```
    </process>
  </stage>
  
  <stage id="4" name="DetectMisplaced">
    <action>Detect misplaced directories</action>
    <process>
      1. Scan specs/ for directories tracked in archive state:
         ```bash
         for dir in specs/OC_[0-9]*_*/ specs/[0-9]*_*/; do
           [ -d "$dir" ] || continue
           basename_dir=$(basename "$dir")
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
  </stage>
  
  <stage id="5" name="ScanRoadmap">
    <action>Scan for roadmap references</action>
    <process>
      1. Read specs/ROAD_MAP.md
      2. For each completed task, extract:
         - completion_summary from completion_data
         - roadmap_items if present
         - Task N references from summaries
      3. Match against ROAD_MAP.md items
      4. Track roadmap_matches array with confidence levels
    </process>
  </stage>
  
  <stage id="6" name="ScanMetaSuggestions">
    <action>Scan meta tasks for README.md suggestions</action>
    <process>
      1. For each archived meta task:
         - Check completion_data.readme_suggestions
         - Filter out "none" values
         - Track actionable suggestions by type:
           * Add: Insert new content
           * Update: Replace existing content
           * Remove: Delete content
    </process>
  </stage>
  
  <stage id="7" name="HarvestMemories">
    <action>Scan artifacts for memory harvest suggestions</action>
    <process>
      1. For each completed task:
         - Scan reports/ for insights and findings
         - Scan plans/ for reusable patterns
         - Check summaries/ for key learnings
      2. Extract potential memory candidates:
         - Research findings with general applicability
         - Implementation patterns documented
         - Configuration examples
         - Workflow descriptions
      3. Generate suggestions list with:
         - Source file path
         - Brief description of insight
         - Suggested memory category (TECHNIQUE, PATTERN, CONFIG, WORKFLOW, INSIGHT)
    </process>
  </stage>
  
  <stage id="8" name="DryRunOutput">
    <action>Display dry run preview if requested</action>
    <process>
      If dry_run = true:
      1. Display comprehensive preview:
         - Tasks to archive (completed/abandoned counts)
         - Orphaned directories count
         - Misplaced directories count
         - Roadmap updates needed
         - README.md suggestions count
         - Memory harvest suggestions count
      2. Exit after display
    </process>
  </stage>
  
  <stage id="9" name="InteractivePrompts">
    <action>Handle interactive prompts</action>
    <process>
      1. If orphaned directories found:
         - Present AskUserQuestion with track/skip options
         - Store user decisions

      2. If misplaced directories found:
         - Present AskUserQuestion with move/skip options
         - Store user decisions

      3. If TODO.md orphans found (todo_md_orphans array not empty):
         - Display formatted list:
           ```
           Found {N} completed/abandoned tasks in TODO.md not tracked in state.json:
           ```
         - For each orphan, show:
           ```
           - OC_{project_number}: {project_name} (Status: {status})
             Directory: specs/OC_{project_number}_{project_name}/
           ```
         - Use AskUserQuestion with multiSelect to prompt:
           ```json
           {
             "question": "Select TODO.md orphans to archive:",
             "options": [
               {"label": "OC_138: task_name (completed)", "value": "todo_orphan_138"},
               {"label": "OC_139: task_name (abandoned)", "value": "todo_orphan_139"}
             ],
             "multiple": true
           }
           ```
         - Store user decisions in `selected_todo_orphans` array

      4. If memory harvest suggestions found:
         - Present suggestions with multiSelect:
           ```json
           {
             "question": "Select memories to create from completed tasks:",
             "options": [
               {"label": "[PATTERN] Configuration pattern from task 142", "value": "mem_142_pattern"},
               {"label": "[TECHNIQUE] Agent delegation from task 143", "value": "mem_143_tech"}
             ],
             "multiple": true
           }
           ```
         - Store selected memories for creation
    </process>
  </stage>
  
  <stage id="10" name="ArchiveTasks" checkpoint="vault_check_complete">
    <action>Archive tasks to completed_projects (includes mandatory vault check)</action>
    <process>
      For each task to archive:
      1. Update specs/archive/state.json:
         - Add to completed_projects array
         - Include all task fields
         - Add archived timestamp

      2. Update specs/state.json:
         - Remove from active_projects array

      3. Update specs/TODO.md:
         - Remove archived entries (both regular and TODO.md orphans)
         - Pattern to match task entry start:
           ```lua
           -- Match both "### OC_N. " and "### N. " formats
           local task_start_pattern = "###%s+(OC_)?(%d+)%.%s+"
           ```
         - For each task to remove:
           a. Find entry start (header line)
           b. Find entry end (next task header or end of Active Tasks section)
           c. Extract complete entry including all lines
           d. Validate entry matches expected format before removal
         - Use Edit tool to remove validated entries:
           ```lua
           -- Remove the matched section
           edit_file("specs/TODO.md", old_entry_content, "")
           ```
         - Note: next_project_number should NOT be decremented when removing orphans
           (numbering continues from highest used number)

      4. Move project directories to specs/archive/

      5. Remove archived task from Recommended Order section (non-blocking):
         ```bash
         # Remove archived task from Recommended Order section (non-blocking)
         if source "$PROJECT_ROOT/.claude/scripts/update-recommended-order.sh" 2>/dev/null; then
             remove_from_recommended_order "$project_number" || echo "Note: Failed to update Recommended Order"
         fi
         ```

      6. Track orphaned directories (if approved)

      7. Move misplaced directories (if approved)

      8. Archive TODO.md orphans:
         For each selected orphan in `selected_todo_orphans`:
         a. Build archive entry from TODO.md data:
            ```json
            {
              "project_number": orphan.project_number,
              "project_name": orphan.project_name,
              "status": orphan.status,  // "completed" or "abandoned"
              "created_at": "TODO.md_orphan",  // Marker indicating source
              "archived_at": "YYYY-MM-DDTHH:MM:SSZ"
            }
            ```
         b. Add entry to specs/archive/state.json completed_projects array
         c. Move directory from specs/ to specs/archive/:
            ```bash
            source_dir="specs/OC_${orphan.project_number}_${orphan.project_name}/"
            if [ ! -d "$source_dir" ]; then
              source_dir="specs/${orphan.project_number}_${orphan.project_name}/"
            fi
            target_dir="specs/archive/$(basename "$source_dir")"
            mv "$source_dir" "$target_dir"
            ```
         d. Track orphan archival for CHANGE_LOG.md
         e. If no directory found, log warning:
            ```
            Warning: TODO.md orphan {N} has no directory in specs/
            Archive entry created but no files moved
            ```

      9. **Vault Threshold Check (MANDATORY)**

         **CRITICAL: ALWAYS EXECUTE - DO NOT SKIP**

         This sub-step MUST be executed unconditionally after archiving tasks.
         The bash block below produces output for BOTH vault-needed and vault-not-needed cases.

         Execute vault threshold detection:
         ```bash
         # UNCONDITIONAL VAULT CHECK - produces output in all cases
         PROJECT_ROOT="${PROJECT_ROOT:-.}"
         STATE_FILE="${PROJECT_ROOT}/specs/state.json"
         VAULT_THRESHOLD=1000

         next_num=$(jq -r '.next_project_number // 0' "$STATE_FILE")

         if [[ "$next_num" -gt "$VAULT_THRESHOLD" ]]; then
             echo ""
             echo "=============================================="
             echo "  VAULT THRESHOLD EXCEEDED"
             echo "=============================================="
             echo "  next_project_number: $next_num"
             echo "  threshold: $VAULT_THRESHOLD"
             echo "  status: VAULT OPERATION REQUIRED"
             echo "=============================================="
             echo ""
             vault_needed=true
         else
             echo ""
             echo "Vault check: next_project_number=$next_num (threshold: $VAULT_THRESHOLD) - OK"
             echo ""
             vault_needed=false
         fi
         ```

         **Decision Logic**:
         - If `vault_needed=true`: Proceed to sub-step 9.1 (VaultConfirmation)
         - If `vault_needed=false`: Skip sub-steps 9.1-9.4, continue to Stage 11 (UpdateRoadmap)

      9.1. **VaultConfirmation** (if vault_needed=true)

         Identify tasks requiring renumbering:
         ```bash
         # Find active tasks with project_number > 1000
         tasks_to_renumber=$(jq -r '
           .active_projects[] |
           select(.project_number > 1000) |
           {
             old_number: .project_number,
             new_number: (.project_number - 1000),
             project_name: .project_name,
             status: .status
           }
         ' specs/state.json)

         # Count tasks to renumber
         renumber_count=$(echo "$tasks_to_renumber" | jq -s 'length')

         # Build mapping array: [{old: 1001, new: 1}, {old: 1003, new: 3}, ...]
         renumber_mappings=$(jq -n --argjson tasks "$tasks_to_renumber" '
           [$tasks[] | {old: .old_number, new: .new_number, name: .project_name}]
         ')
         ```

         Build preview of renumbering:
         ```bash
         # Format preview of task renumbering
         renumber_preview=""
         for mapping in $(echo "$renumber_mappings" | jq -c '.[]'); do
           old=$(echo "$mapping" | jq -r '.old')
           new=$(echo "$mapping" | jq -r '.new')
           name=$(echo "$mapping" | jq -r '.name')
           renumber_preview="${renumber_preview}\n  - Task ${old} (${name}) -> Task ${new}"
         done
         ```

         Present AskUserQuestion for vault confirmation:
         ```json
         {
           "question": "Task numbering has exceeded 1000. Initiate vault archival?",
           "header": "Vault Operation",
           "description": "Current next_project_number: {next_num}\nActive tasks to renumber: {renumber_count}\n\nRenumbering preview:{renumber_preview}\n\nThis will:\n1. Move specs/archive/ to specs/vault/{NN-vault}/\n2. Renumber tasks > 1000 by subtracting 1000\n3. Reset next_project_number",
           "multiSelect": false,
           "options": [
             {"label": "Yes, proceed with vault operation", "value": "proceed"},
             {"label": "No, skip vault this time", "value": "skip"}
           ]
         }
         ```

         Handle user response:
         ```bash
         if [ "$user_response" = "proceed" ]; then
           vault_approved=true
           # Continue to sub-step 9.2
         else
           vault_approved=false
           # Skip to Stage 11 (UpdateRoadmap)
         fi
         ```

      9.2. **CreateVault** (if vault_approved=true)

         Calculate vault number:
         ```bash
         # Get current vault_count (or 0 if not set)
         vault_count=$(jq -r '.vault_count // 0' specs/state.json)
         new_vault_num=$((vault_count + 1))
         vault_dir_name=$(printf "%02d-vault" "$new_vault_num")
         vault_path="specs/vault/${vault_dir_name}"
         ```

         Create vault directory structure:
         ```bash
         mkdir -p "$vault_path"
         ```

         Move archive contents to vault:
         ```bash
         # Move archive directory to vault
         if [ -d "specs/archive" ]; then
           mv "specs/archive" "${vault_path}/archive"
         fi
         ```

         Move archive state.json to vault root:
         ```bash
         # Archive state.json becomes vault state.json
         if [ -f "${vault_path}/archive/state.json" ]; then
           mv "${vault_path}/archive/state.json" "${vault_path}/state.json"
         fi
         ```

         Create vault meta.json:
         ```bash
         # Calculate metadata
         current_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
         archived_count=$(jq -r '.completed_projects | length' "${vault_path}/state.json" 2>/dev/null || echo "0")
         task_range="1-$((next_num - renumber_count - 1))"

         # Create meta.json
         jq -n \
           --arg vault_num "$new_vault_num" \
           --arg created_at "$current_timestamp" \
           --arg task_range "$task_range" \
           --argjson archived_count "$archived_count" \
           --argjson final_task_num "$next_num" \
           '{
             vault_number: ($vault_num | tonumber),
             created_at: $created_at,
             task_range: $task_range,
             archived_count: $archived_count,
             final_task_number: $final_task_num,
             description: "Vault containing archived tasks from task numbering cycle"
           }' > "${vault_path}/meta.json"
         ```

         Reinitialize empty specs/archive/ with fresh state.json:
         ```bash
         mkdir -p "specs/archive"

         # Create fresh archive state.json
         jq -n '{
           "_comment": "Archive state for completed and abandoned tasks",
           "completed_projects": [],
           "archived_at": "'"$current_timestamp"'"
         }' > "specs/archive/state.json"
         ```

      9.3. **RenumberTasks** (if vault_approved=true)

         For each task in renumber_mappings, update state.json:
         ```bash
         # Update each task's project_number and artifact paths
         for mapping in $(echo "$renumber_mappings" | jq -c '.[]'); do
           old_num=$(echo "$mapping" | jq -r '.old')
           new_num=$(echo "$mapping" | jq -r '.new')
           task_name=$(echo "$mapping" | jq -r '.name')

           # Update project_number
           # Update artifact paths (4-digit dir -> 3-digit dir)
           old_padded=$(printf "%04d" "$old_num")
           new_padded=$(printf "%03d" "$new_num")

           # Use jq to update the task entry
           jq --argjson old "$old_num" \
              --argjson new "$new_num" \
              --arg old_pad "$old_padded" \
              --arg new_pad "$new_padded" '
             .active_projects |= map(
               if .project_number == $old then
                 .project_number = $new |
                 .artifacts |= (if . then map(
                   .path |= gsub("specs/\($old_pad)_"; "specs/\($new_pad)_") |
                   .path |= gsub("specs/\($old)_"; "specs/\($new_pad)_")
                 ) else . end)
               else . end
             )
           ' specs/state.json > specs/state.json.tmp
           mv specs/state.json.tmp specs/state.json
         done
         ```

         Update dependencies arrays (task numbers > 1000):
         ```bash
         # Build mapping for all renumbered tasks
         jq --argjson mappings "$renumber_mappings" '
           # Create lookup from mappings
           ($mappings | map({(.old | tostring): .new}) | add) as $lookup |
           .active_projects |= map(
             .dependencies |= (if . then map(
               . as $dep |
               if $lookup[$dep | tostring] then
                 $lookup[$dep | tostring]
               else $dep end
             ) else . end)
           )
         ' specs/state.json > specs/state.json.tmp
         mv specs/state.json.tmp specs/state.json
         ```

         Rename task directories:
         ```bash
         for mapping in $(echo "$renumber_mappings" | jq -c '.[]'); do
           old_num=$(echo "$mapping" | jq -r '.old')
           new_num=$(echo "$mapping" | jq -r '.new')
           task_name=$(echo "$mapping" | jq -r '.name')

           old_padded=$(printf "%04d" "$old_num")
           new_padded=$(printf "%03d" "$new_num")

           # Find source directory (could be 3-digit or 4-digit padded)
           source_dir=""
           if [ -d "specs/${old_padded}_${task_name}" ]; then
             source_dir="specs/${old_padded}_${task_name}"
           elif [ -d "specs/${old_num}_${task_name}" ]; then
             source_dir="specs/${old_num}_${task_name}"
           fi

           # Rename to 3-digit padded format
           if [ -n "$source_dir" ]; then
             target_dir="specs/${new_padded}_${task_name}"
             mv "$source_dir" "$target_dir"
           fi
         done
         ```

         Update TODO.md entries:
         ```bash
         for mapping in $(echo "$renumber_mappings" | jq -c '.[]'); do
           old_num=$(echo "$mapping" | jq -r '.old')
           new_num=$(echo "$mapping" | jq -r '.new')

           old_padded=$(printf "%04d" "$old_num")
           new_padded=$(printf "%03d" "$new_num")

           # Update task headers: ### 1001. Title -> ### 1. Title
           sed -i "s/^### ${old_num}\./### ${new_num}./" specs/TODO.md

           # Update artifact links with directory references
           sed -i "s|${old_padded}_|${new_padded}_|g" specs/TODO.md
           sed -i "s|${old_num}_|${new_padded}_|g" specs/TODO.md

           # Update dependency references
           sed -i "s|Task #${old_num}|Task #${new_num}|g" specs/TODO.md
         done
         ```

      9.4. **ResetState** (if vault_approved=true)

         Calculate new next_project_number:
         ```bash
         # Find maximum project_number in active_projects after renumbering
         max_active=$(jq -r '[.active_projects[].project_number] | max // 0' specs/state.json)
         new_next_num=$((max_active + 1))
         ```

         Update state.json with new next_project_number:
         ```bash
         jq --argjson new_next "$new_next_num" \
            '.next_project_number = $new_next' specs/state.json > specs/state.json.tmp
         mv specs/state.json.tmp specs/state.json
         ```

         Increment vault_count:
         ```bash
         jq '.vault_count = (.vault_count // 0) + 1' specs/state.json > specs/state.json.tmp
         mv specs/state.json.tmp specs/state.json
         ```

         Add entry to vault_history:
         ```bash
         current_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
         archived_count=$(jq -r '.completed_projects | length' "${vault_path}/state.json" 2>/dev/null || echo "0")
         task_range="1-$((next_num - renumber_count - 1))"

         jq --arg vault_dir "$vault_path/" \
            --argjson vault_num "$new_vault_num" \
            --arg created "$current_timestamp" \
            --arg range "$task_range" \
            --argjson archived "$archived_count" \
            --argjson final "$next_num" '
           .vault_history = (.vault_history // []) + [{
             vault_number: $vault_num,
             vault_dir: $vault_dir,
             created_at: $created,
             task_range: $range,
             archived_count: $archived,
             final_task_number: $final
           }]
         ' specs/state.json > specs/state.json.tmp
         mv specs/state.json.tmp specs/state.json
         ```

         Add vault transition comment to TODO.md:
         ```bash
         current_date=$(date +"%Y-%m-%d")
         transition_comment="<!-- Vault transition: ${current_date} - Tasks 1-$((next_num - renumber_count - 1)) archived to ${vault_path}/ -->"

         # Insert after frontmatter or at top of file
         if grep -q "^---$" specs/TODO.md; then
           # Has frontmatter, insert after closing ---
           sed -i "/^---$/,/^---$/{/^---$/{n;a\\
${transition_comment}
}}" specs/TODO.md
         else
           # No frontmatter, insert at top
           sed -i "1i${transition_comment}" specs/TODO.md
         fi
         ```

         After sub-step 9.4 completes, continue to Stage 11 (UpdateRoadmap).

      <!-- CHECKPOINT: Stage 10 complete when vault_check output is present AND
           (vault_needed=false OR vault operations 9.1-9.4 completed) -->
    </process>
    <checkpoint>vault_check_complete output present; if vault_needed, sub-steps 9.1-9.4 executed</checkpoint>
  </stage>

  <stage id="11" name="UpdateRoadmap">
    <action>Update ROAD_MAP.md with completion annotations</action>
    <process>
      For each roadmap match:
      1. Skip if already annotated
      2. Apply appropriate annotation:
         - Completed: `- [x] item *(Completed: Task {N}, DATE)*`
         - Abandoned: `- [ ] item *(Task {N} abandoned: reason)*`
      3. Track changes: completed_annotated, abandoned_annotated, skipped
    </process>
  </stage>
  
  <stage id="12" name="UpdateREADME">
    <action>Apply README.md suggestions</action>
    <process>
      1. Filter suggestions where action != "none"
      2. Present AskUserQuestion with multiSelect for review
      3. Apply selected suggestions via Edit tool
      4. Display results (applied/failed/skipped)
      5. Acknowledge "none" action tasks
    </process>
  </stage>
  
  <stage id="13" name="UpdateChangelog">
    <action>Update CHANGE_LOG.md with archive entries</action>
    <process>
      1. Create specs/CHANGE_LOG.md if not exists:
         ```markdown
         # Change Log
         
         All notable changes to the OpenCode system.
         
         ## Format
         
         Each entry includes:
         - Date
         - Task number and name
         - Type of change
         - Brief description
         
         ---
         ```
      
      2. For each archived task, append entry:
         ```markdown
         ### YYYY-MM-DD
         
         **Task {N}: {project_name}**
         - Status: {completed|abandoned}
         - Type: {meta|neovim|general|lean}
         - Summary: {completion_summary or description}
         
         Artifacts:
         {List of artifact paths}
         ```
      
      3. Append memory harvest note if memories were suggested
    </process>
  </stage>
  
  <stage id="14" name="CreateMemories">
    <action>Create selected memories</action>
    <process>
      For each selected memory suggestion:
      1. Generate memory ID: MEM-YYYY-MM-DD-NNN
      2. Create memory file in .opencode/memory/10-Memories/
      3. Format with classification tag:
         ```markdown
         # Memory: {title}
         
         **Category**: [TECHNIQUE|PATTERN|CONFIG|WORKFLOW|INSIGHT]
         **Source**: Task OC_{N} - {artifact_path}
         **Date**: YYYY-MM-DD
         
         {content}
         ```
      4. Update .opencode/memory/20-Indices/index.md
      5. Track created memory IDs
    </process>
  </stage>
  
  <stage id="15" name="GitCommit">
    <action>Commit all changes</action>
    <process>
      1. **Pre-commit vault safety net**:

         Before committing, verify vault threshold was handled if exceeded:
         ```bash
         # PRE-COMMIT SAFETY NET - blocks commit if vault was skipped when required
         PROJECT_ROOT="${PROJECT_ROOT:-.}"
         STATE_FILE="${PROJECT_ROOT}/specs/state.json"
         VAULT_THRESHOLD=1000

         next_num=$(jq -r '.next_project_number // 0' "$STATE_FILE")
         vault_count_before=$(jq -r '.vault_count // 0' "$STATE_FILE")
         vault_count_after=$(jq -r '.vault_count // 0' "$STATE_FILE")

         if [[ "$next_num" -gt "$VAULT_THRESHOLD" ]]; then
           # Threshold exceeded - vault should have been performed
           if [[ "$vault_count_after" -eq "$vault_count_before" ]]; then
             echo ""
             echo "=============================================="
             echo "  ERROR: VAULT OPERATION SKIPPED"
             echo "=============================================="
             echo "  next_project_number: $next_num (exceeds threshold: $VAULT_THRESHOLD)"
             echo "  vault_count unchanged: $vault_count_after"
             echo ""
             echo "  The vault threshold was exceeded but vault operation"
             echo "  was not performed. Return to Stage 10 sub-step 9 and"
             echo "  complete the vault operation before committing."
             echo "=============================================="
             echo ""
             exit 1
           fi
         fi
         echo "Pre-commit vault check: OK"
         ```

      2. Stage all modified files:
         ```bash
         git add -A
         ```
      
      2. Create comprehensive commit message:
         ```
         todo: archive {N} tasks
         
         - {completed} completed tasks
         - {abandoned} abandoned tasks
         - {roadmap} roadmap items updated
         - {orphans} orphaned directories tracked
         - {misplaced} misplaced directories moved
         - {readme} README.md suggestions applied
         - {memories} memories harvested from artifacts
         
         Updated: specs/state.json, specs/TODO.md, specs/CHANGE_LOG.md
         ```
      
      3. Commit changes
    </process>
  </stage>
  
  <stage id="16" name="OutputResults">
    <action>Display final results</action>
    <process>
      Display complete summary:
      ```
      Task Archival Complete
      ======================
      
      Archived Tasks:
      - {completed} completed
      - {abandoned} abandoned
      
      Directory Operations:
      - {orphans} orphaned directories tracked
      - {misplaced} misplaced directories moved
      
      Updates Applied:
      - {roadmap} roadmap items annotated
      - {readme} README.md suggestions applied
      - {changelog} CHANGE_LOG.md entries added
      
      Memory Harvest:
      - {memories_created} new memories created
      - {memories_suggested} suggestions available
      
      Active tasks remaining: {remaining_count}
      ```
    </process>
  </stage>
</execution>

<validation>Validate state updates, CHANGE_LOG.md entries, and memory creation.</validation>

<return_format>Brief text summary with archival counts and operation results.</return_format>

## Error Handling

- **jq failures**: Log error with technical details, skip affected operation
- **File permission errors**: Return error with guidance
- **Git commit failures**: Log warning, continue with other operations
- **User cancels prompts**: Exit gracefully
- **AskUserQuestion failures**: Default to conservative option (skip)

## Memory Harvest Categories

When suggesting memories from task artifacts, use these categories:

| Category | Description | Example |
|----------|-------------|---------|
| TECHNIQUE | Reusable method or approach | "Three-phase debugging process" |
| PATTERN | Design or implementation pattern | "Agent delegation wrapper pattern" |
| CONFIG | Configuration or setup knowledge | "Neovim LSP keymap configuration" |
| WORKFLOW | Process or procedure | "Code review checklist workflow" |
| INSIGHT | Key learning or understanding | "Root cause of race condition" |

## CHANGE_LOG.md Format

```markdown
# Change Log

All notable changes to the OpenCode system.

## Format

Each entry includes:
- Date
- Task number and name  
- Type of change
- Brief description

---

### YYYY-MM-DD

**Task {N}: {project_name}**
- Status: {completed|abandoned}
- Type: {meta|neovim|general|lean}
- Summary: {description}

Artifacts:
- path/to/artifact.ext - description

---
```

## Example Usage

```
/todo              # Archive with full workflow
/todo --dry-run    # Preview what would be archived
```