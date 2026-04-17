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

      3. Scan TODO.md for completed/abandoned tasks not tracked in state.json or archive:
         - Parse task headers (`### {N}.` or `### OC_{N}.`) and status lines (`[COMPLETED]`/`[ABANDONED]`)
         - Cross-reference each against active_projects and archive completed_projects
         - Collect as `todo_md_orphans[]` if: status is completed/abandoned, not in either state file, and has a directory in specs/
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
      0. Ensure specs/ROADMAP.md exists. If the file does not exist, create it with the default template:
         ```markdown
         # Project Roadmap

         ## Phase 1: Current Priorities (High Priority)

         - [ ] (No items yet -- add roadmap items here)

         ## Success Metrics

         - (Define success metrics here)
         ```
      1. Read specs/ROADMAP.md
      2. For each completed task, extract:
         - completion_summary from completion_data
         - roadmap_items if present
         - Task N references from summaries
      3. Match against ROADMAP.md items
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
    <action>Collect, deduplicate, and classify memory candidates from state.json</action>
    <process>
      1. Collect candidates from state.json:
         - For each completed task in the archival batch:
           - Read `memory_candidates // []` from the task's state.json entry
           - Flatten into a single list, tagging each candidate with `task_number` provenance
         - If no candidates across all tasks, set `harvest_candidates = []` and skip to Stage 8

      2. Deduplicate against existing memory-index.json:
         - Read `.memory/memory-index.json` (if missing or empty, skip dedup -- all candidates are CREATE)
         - For each candidate, compute keyword overlap against every index entry:
           ```
           overlap = |candidate.suggested_keywords INTERSECT entry.keywords| / |candidate.suggested_keywords|
           ```
         - Classify dedup action:
           - overlap > 90%: mark `dedup_action = "NOOP"` (exclude from prompt)
           - overlap > 60%: mark `dedup_action = "UPDATE"` (present with warning label)
           - overlap <= 60%: mark `dedup_action = "CREATE"` (standard new memory)
         - If ALL candidates are NOOP after dedup, set `harvest_candidates = []` and skip to Stage 8

      3. Apply three-tier classification:
         - **Tier 1** (pre-selected): category in [PATTERN, CONFIG] AND confidence >= 0.8
         - **Tier 2** (shown, not pre-selected): category in [WORKFLOW, TECHNIQUE] AND confidence >= 0.5
         - **Tier 3** (hidden by default): category == INSIGHT OR confidence < 0.5
         - Assign `tier` (1, 2, or 3) to each non-NOOP candidate

      4. Store the classified candidate list as `harvest_candidates`:
         Each entry contains: `task_number`, `content`, `category`, `source_artifact`, `confidence`, `suggested_keywords`, `tier`, `dedup_action`
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
         - Memory candidates: tiered breakdown from `harvest_candidates`
           - Format: `Memory candidates: {T1} Tier 1, {T2} Tier 2, {T3} Tier 3 ({after_dedup} after dedup, {noop_count} NOOP excluded)`
           - If no candidates: `Memory candidates: none`
      2. Exit after display
    </process>
  </stage>
  
  <stage id="9" name="InteractivePrompts">
    <action>Handle interactive prompts</action>
    <process>
      Present AskUserQuestion prompts for each detected condition:
      1. **Orphaned directories**: track/skip options per directory
      2. **Misplaced directories**: move/skip options per directory
      3. **TODO.md orphans**: multiSelect list of completed/abandoned tasks not in state.json; store as `selected_todo_orphans`
      4. **Memory harvest candidates** (from `harvest_candidates`):
         - If `harvest_candidates` is empty (no candidates or all NOOP), skip this sub-step entirely
         - Build multiSelect option list, ordered by tier:
           a. **Tier 1 candidates first** (pre-selected): Format each as:
              `[PRE-SELECTED] [TIER 1] [{CATEGORY}] Task {N}: {content first 80 chars}... (confidence: {X.XX})`
              If `dedup_action == "UPDATE"`, append: ` [WARNING: similar memory exists]`
           b. **Tier 2 candidates** (shown, not pre-selected): Format each as:
              `[TIER 2] [{CATEGORY}] Task {N}: {content first 80 chars}... (confidence: {X.XX})`
              If `dedup_action == "UPDATE"`, append: ` [WARNING: similar memory exists]`
           c. **Tier 3 expansion option**: If Tier 3 candidates exist, add a final option:
              `Show {count} more candidates (Tier 3 -- low confidence/insight)`
         - Present AskUserQuestion with multiSelect
         - If user selected the Tier 3 expansion option:
           - Re-prompt with ALL tiers visible (Tier 1 + Tier 2 + Tier 3), Tier 1 still pre-selected
           - Tier 3 candidates formatted as:
             `[TIER 3] [{CATEGORY}] Task {N}: {content first 80 chars}... (confidence: {X.XX})`
         - Store user-approved candidates as `approved_memories` for Stage 14
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
    <action>Update ROADMAP.md with completion annotations</action>
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
      1. Create specs/CHANGE_LOG.md if not exists (header + format description)
      2. For each archived task, append dated entry with: task number/name, status, type, completion_summary, artifact list
      3. Append memory harvest note if memories were suggested
    </process>
  </stage>

  <stage id="14" name="CreateMemories">
    <action>Create approved memory files and regenerate indexes</action>
    <process>
      If `approved_memories` is empty, skip this stage entirely.

      For each candidate in `approved_memories`:

      1. **Generate slug**:
         - Derive from candidate category + content first few words (lowercase, hyphens, no special chars)
         - Example: `pattern-jq-safe-not-operator`, `config-lean4-lake-env`
         - Collision check: if `MEM-{slug}.md` exists in `.memory/10-Memories/`, append numeric suffix (`-2`, `-3`, ...)

      2. **Create memory file** at `.memory/10-Memories/MEM-{slug}.md`:
         - Use template from `.memory/30-Templates/memory-template.md`
         - Field mapping from candidate:
           - `{{title}}` -> descriptive title derived from content (first ~60 chars, cleaned)
           - `{{date}}` -> current date (YYYY-MM-DD)
           - `{{tags}}` -> `[{category}]` (e.g., `[PATTERN]`)
           - `{{topic}}` -> derived from category (lowercase, e.g., "pattern", "configuration")
           - `{{source}}` -> `"Task {N}: {source_artifact}"`
           - `{{last_updated}}` -> current date (YYYY-MM-DD)
           - `retrieval_count` -> `0`
           - `last_retrieved` -> `null`
           - `keywords` -> candidate's `suggested_keywords` array
           - `summary` -> first 60 characters of `content`
           - `token_count` -> `word_count(content) * 1.3` (rounded to integer)
           - `{{content}}` -> candidate's `content` field

      3. After ALL memory files are created, **batch-regenerate indexes**:
         - `.memory/memory-index.json`: Rebuild from filesystem scan of `.memory/10-Memories/MEM-*.md`
           - Parse frontmatter of each file to populate entries array
           - Update `entry_count`, `total_tokens`, `generated_at`
         - `.memory/20-Indices/index.md`: Rebuild table of contents from all memory files
         - `.memory/10-Memories/README.md`: Update memory listing

      Note: `memory_candidates` field is implicitly cleaned when the task entry is removed from
      active_projects and moved to archive during Stage 10.
    </process>
  </stage>
  
  <stage id="15" name="GitCommit">
    <action>Commit all changes</action>
    <process>
      1. **Pre-commit vault safety net**: If next_project_number > 1000 and vault_count unchanged, block commit with error directing back to Stage 10 sub-step 9
      2. `git add -A`
      3. Commit: `todo: archive {N} tasks` with counts for completed, abandoned, roadmap, orphans, misplaced, readme, memories
    </process>
  </stage>
  
  <stage id="16" name="OutputResults">
    <action>Display final results</action>
    <process>
      Display summary with counts for:
      - Archived tasks (completed/abandoned)
      - Directory operations (orphans tracked/misplaced moved)
      - Updates applied (roadmap annotations/readme changes/changelog entries)
      - Memory harvest with tier breakdown:
        - Format: `Memory harvest: {created} created ({t1_created} Tier 1, {t2_created} Tier 2, {t3_created} Tier 3), {noop_skipped} skipped (NOOP), {user_skipped} declined`
        - If no memories created: `Memory harvest: none (no candidates)` or `Memory harvest: none (all skipped)`
      - Active tasks remaining

      **Suggested Next Steps**:

      After displaying the archival summary, append a numbered "Suggested Next Steps" list.
      The list always includes at least one item (the archive review suggestion).
      Distill suggestions are conditionally added based on `memory_health` from state.json.

      1. Read `memory_health` from specs/state.json with fallback:
         ```bash
         memory_health=$(jq -r '.memory_health // {}' specs/state.json)
         total_memories=$(echo "$memory_health" | jq -r '.total_memories // 0')
         never_retrieved=$(echo "$memory_health" | jq -r '.never_retrieved // 0')
         health_score=$(echo "$memory_health" | jq -r '.health_score // 100')
         last_distilled=$(echo "$memory_health" | jq -r '.last_distilled // null')
         ```
         If `memory_health` is absent or empty (`{}`), suppress all /distill suggestions
         (only show the archive review suggestion).

      2. Always include as the first suggestion:
         `1. Review the archive at specs/archive/ to verify task directories moved correctly`

      3. Suppress ALL /distill suggestions when `total_memories < 5`:
         - Do not mention /distill at all in this case

      4. When `total_memories >= 5`, evaluate these conditions (in order):

         a. Suggest `/distill --report` when `total_memories >= 10`:
            `N. Run /distill --report to review memory vault health ({total_memories} memories, {health_score}/100 health)`

         b. Suggest `/distill` (full interactive) when ANY of these conditions are true:
            - `total_memories >= 30`
            - `never_retrieved / total_memories > 0.5` AND `total_memories >= 5`
            - `last_distilled` is null or stale (older than 30 days) AND `total_memories >= 10`

            Format: `N. Run /distill to maintain memory vault ({total_memories} memories, {health_score}/100 health)`

         Note: If condition (b) is met, it replaces condition (a) -- do not show both
         /distill --report and /distill suggestions. Show the stronger suggestion only.

      5. Format as a clean numbered list:
         ```
         Suggested next steps:
         1. Review the archive at specs/archive/ to verify task directories moved correctly
         2. Run /distill to maintain memory vault (42 memories, 72/100 health)
         ```
    </process>
  </stage>
</execution>

<validation>Validate state updates, CHANGE_LOG.md entries, and memory creation.</validation>

<return_format>Brief text summary with archival counts and operation results.</return_format>

## Error Handling

See `rules/error-handling.md` for general patterns. Skill-specific: jq failures skip affected operation; git failures are non-blocking; user cancel or AskUserQuestion failure defaults to skip.

## Example Usage

```
/todo              # Archive with full workflow
/todo --dry-run    # Preview what would be archived
```
