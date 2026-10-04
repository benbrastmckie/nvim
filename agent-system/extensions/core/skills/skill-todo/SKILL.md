---
name: skill-todo
description: Archive completed, abandoned, and expanded tasks with CHANGE_LOG.md updates and memory harvest suggestions
allowed-tools: Bash, Edit, Read, Write, Grep, AskUserQuestion
context: direct
---

# Todo Skill

Direct execution skill for archiving tasks, updating CHANGE_LOG.md, and suggesting memory harvesting.

<context>
  <system_context>OpenCode task archival with changelog tracking and memory suggestions.</system_context>
  <task_context>Archive completed/abandoned/expanded tasks and track changes.</task_context>
</context>

<role>Direct execution skill for task archival operations with automated CHANGE_LOG updates and memory harvest suggestions.</role>

<task>Parse arguments, scan for archivable tasks (completed, abandoned, expanded), update states, generate CHANGE_LOG entries, suggest memory harvesting from completed task artifacts.</task>

<execution>
  <stage id="1" name="ParseArguments">
    <action>Parse command arguments</action>
    <process>
      1. Check for --dry-run flag
      2. Set dry_run = true if present
      3. Validate no other arguments expected
    </process>
  </stage>
  
  <stage id="1.5" name="ReconcileScan">
    <action>Dry-run scan for status-stranded tasks whose artifact for the in-flight phase already
    exists on disk -- these are invisible to Stage 2's literal completed/abandoned match today and
    can never be archived until something promotes them</action>
    <process>
      This stage never auto-repairs status: `/todo` performs the system's most irreversible
      operations (moving directories, rewriting CHANGE_LOG.md), and a silent status promotion
      immediately before a silent archive move would compound two mutations with no visibility.
      Every call this stage makes is `--dry-run`; only a user-approved selection in Stage 9 ever
      calls the script live.

      1. Generate a session ID via `common_session_id` (skill-todo does not source
         `command-gate-in.sh` and has no session ID of its own):
         ```bash
         source .claude/scripts/lib/common.sh
         todo_session_id="$(common_session_id)"
         ```
      2. Select the same four reconcilable statuses used by the `/task --sync` and `/orchestrate`
         triggers (positive-match against the four statuses `reconcile-task-status.sh` knows how
         to reconcile -- no `!=`/negation selector needed). CONFIRMED (not assumed): `hold` is
         absent from this positive-match list, so this stage can never silently promote a held
         task out of its hold -- a hold is lifted only through the explicit
         `preflight:unhold` path, never as a side effect of reconciliation:
         ```bash
         reconcile_scan_targets=$(jq -r '
           .active_projects[] |
           select(.status == "researching" or .status == "planning" or .status == "implementing" or .status == "partial") |
           .project_number
         ' specs/state.json)
         ```
      3. For each candidate, dry-run the script and collect any task whose output reports a
         would-promote line into `reconcile_candidates`, keeping each candidate's task number,
         current status, the artifact basename found, and the full dry-run output for display in
         Stage 8/9:
         ```bash
         reconcile_candidates=()
         for task_num in $reconcile_scan_targets; do
           recon_out=$(bash .claude/scripts/reconcile-task-status.sh "$task_num" "$todo_session_id" --dry-run 2>&1)
           if echo "$recon_out" | grep -q "Would promote"; then
             reconcile_candidates+=("$task_num")
             # associate $recon_out with $task_num (e.g. via an associative array) for Stage 9's
             # AskUserQuestion description text
           fi
         done
         ```
      4. If `reconcile_scan_targets` is empty, `reconcile_candidates` is `()` -- proceed straight
         to Stage 2. This stage is genuinely side-effect-free: `--dry-run` never writes
         `state.json` or any other file.
    </process>
  </stage>

  <stage id="2" name="ScanTasks">
    <action>Scan for archivable tasks</action>
    <process>
      1. Read specs/state.json
      2. Identify tasks with status = "completed"
      3. Identify tasks with status = "abandoned"
      4. Identify tasks with status = "expanded"
      5. Read specs/TODO.md and cross-reference (including entries marked [EXPANDED])
      6. Track counts: completed_count, abandoned_count, expanded_count

      **VERIFIED, not guarded**: this stage's archive-candidate selection (steps 2-4 above) and
      the archive-write jq at Stage 10 both POSITIVE-match only `completed`/`abandoned`/
      `expanded`, so a `hold`-status task is excluded from the archive set by construction at
      two independent points -- no redundant hold-specific guard is added here. (The task
      dispatch that motivated this feature pointed at "Stage 2.5, lines ~164-166" for this
      guard; that line range actually belongs to the Stage 2.5 `TopicRevision` selector below, a
      different, inverted-select mechanism for topic backfill -- noted here so a future reader
      following that line number is not misled.)

      **Subtasks-defer guard**: identical semantics to `commands/todo.md`'s Step 3 guard (see that
      file's "Prepare Archive List" section, which is the reference implementation this mirrors).
      Partition the tasks identified above into `archivable_tasks[]` (proceeds) and
      `deferred_expanded[]` (held back for a later `/todo` run) — an expanded parent is deferred
      while any task in its `subtasks[]` is still present in `active_projects` with a non-terminal
      status. Use a `case` statement for status classification (never `!=`):

      ```bash
      archivable_tasks=()
      deferred_expanded=()
      deferred_expanded_nums=()
      deferred_expanded_detail=()   # one entry per deferred parent, naming WHICH subtask(s) block
                                     # it and why (Decision 6 mitigation -- a reporting
                                     # improvement only; the blocking case statement below is
                                     # unchanged, and a held subtask continues to block exactly
                                     # as every other non-terminal status does)

      for task in "${candidate_tasks[@]}"; do
        status=$(echo "$task" | jq -r '.status')
        project_num=$(echo "$task" | jq -r '.project_number')

        case "$status" in
          expanded)
            # A missing, null, or empty subtasks array means nothing is blocking - archive normally.
            subtasks=$(echo "$task" | jq -c '.subtasks // []')
            subtask_count=$(echo "$subtasks" | jq 'length')
            if [ "$subtask_count" -eq 0 ]; then
              archivable_tasks+=("$task")
              continue
            fi

            blocking_count=0
            for subtask_num in $(echo "$subtasks" | jq -r '.[]'); do
              subtask_status=$(jq -r --argjson n "$subtask_num" \
                '.active_projects[] | select(.project_number == $n) | .status' \
                specs/state.json)

              # An empty result means the subtask is already archived - not blocking.
              if [ -z "$subtask_status" ]; then
                continue
              fi

              case "$subtask_status" in
                completed|abandoned|expanded)
                  # Terminal - not blocking.
                  ;;
                *)
                  # Any other status blocks.
                  ((blocking_count++))
                  ;;
              esac
            done

            if [ "$blocking_count" -gt 0 ]; then
              deferred_expanded+=("$task")
              deferred_expanded_nums+=("$project_num")
              # Reporting-only detail pass (Decision 6 mitigation): names which subtask(s) are
              # blocking and, for a held one specifically, its hold_reason -- so the operator
              # reads "subtask 123 is held (reason: ...)" rather than a generic "still active"
              # line. This is a SEPARATE pass over the same subtasks[] already resolved above; it
              # does not re-decide blocking and does not alter the case statement above.
              detail_parts=()
              for subtask_num in $(echo "$subtasks" | jq -r '.[]'); do
                d_status=$(jq -r --argjson n "$subtask_num" \
                  '.active_projects[] | select(.project_number == $n) | .status' \
                  specs/state.json)
                [ -z "$d_status" ] && continue
                case "$d_status" in
                  completed|abandoned|expanded) ;;
                  hold)
                    d_reason=$(jq -r --argjson n "$subtask_num" \
                      '.active_projects[] | select(.project_number == $n) | .hold_reason // "no reason recorded"' \
                      specs/state.json)
                    detail_parts+=("subtask $subtask_num is held (reason: $d_reason)")
                    ;;
                  *)
                    detail_parts+=("subtask $subtask_num is $d_status")
                    ;;
                esac
              done
              deferred_expanded_detail+=("$project_num: $(IFS='; '; echo "${detail_parts[*]}")")
            else
              archivable_tasks+=("$task")
            fi
            ;;
          *)
            # Non-expanded tasks pass through untouched.
            archivable_tasks+=("$task")
            ;;
        esac
      done
      ```

      Track `deferred_expanded[]` and `deferred_count` (`= ${#deferred_expanded[@]}`). Stage 10
      (`ArchiveTasks`) consumes `archivable_tasks[]` — never a freshly-recomputed status match —
      so a deferred parent's `active_projects` entry survives this run.
    </process>
  </stage>
  
  <stage id="2.5" name="TopicRevision">
    <action>Optional: backfill topics on active tasks missing the topic field</action>
    <process>
      Detect active tasks without a topic:
      ```bash
      missing=$(jq -r '.active_projects[] |
        select(.status == "completed" | not) |
        select(.status == "abandoned" | not) |
        select(.status == "expanded" | not) |
        select(.topic == null or .topic == "") |
        "\(.project_number)|\(.project_name)"' specs/state.json)
      ```

      If no tasks need backfill, skip this stage.

      For each task needing a topic, follow the topic assignment pattern from
      @.claude/context/patterns/topic-assignment-pattern.md (Mode A, per-task backfill).
      Use header "Topic Backfill ({i} of {total})".

      After each selection:
      ```bash
      bash .claude/scripts/manage-topics.sh set "$task_num" "$topic"
      ```
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
      0. Do NOT auto-create `specs/ROADMAP.md` if it is absent. An absent roadmap is "no roadmap
         tracked" — a supported state, not a repair trigger; `roadmap-integration.sh` itself
         treats absence this way (exits 0, emits the `roadmap_absent` warning, does not recreate
         the file) and step 3 below surfaces that warning. Re-creating the file here, ahead of
         the script call, would silently defeat that contract and make any deliberate deletion of
         the roadmap never stick.
      1. Partition `archivable_tasks[]` into roadmap-excluded (meta tasks, and expanded tasks —
         an expanded task has no `completion_summary` of its own by construction, since its
         subtasks carry the deliverables; do not "fix" this by requiring one) and
         roadmap-eligible tasks, exactly as `commands/todo.md`'s Step 3.5.1 does.
      2. This stage performs no matching of its own. Invoke `roadmap-integration.sh` parse-only
         (no `--annotate`) against `specs/ROADMAP.md`/`specs/state.json`, capturing
         `roadmap_structure`, `warnings`, and `roadmap_matches` from the payload. Filter
         `roadmap_matches` to only the roadmap-eligible tasks from step 1 before treating any
         match as an annotation candidate — this filter is where meta/expanded exclusion is
         enforced, since the script has no `task_type` filter of its own (see the script's header
         "Caller contract").
      3. **Error-handling contract** (identical to `commands/todo.md`'s Step 3.5 and
         `commands/review.md`'s Step 2.5): a missing script, a non-zero exit, or empty output all
         produce the same visible warning and the same fully-defined `parseable: false` fallback
         — never silence.
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
      Note: this stage stays scoped to completed tasks and is not widened to expanded tasks —
      an expanded task's work product and memory candidates belong to its subtasks, which are
      harvested (or already were harvested) in their own right when they complete.

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

      Note: the state.json `reflection` field this stage used to read here has been retired
      (zero live writers; see `context/formats/issue-log.md`'s relation table). Do NOT wire this
      harvest to `issues.jsonl` as a replacement -- surfacing that log is explicitly out of scope
      here and belongs exclusively to the separate orchestration conclusion stage.
    </process>
  </stage>
  
  <stage id="8" name="DryRunOutput">
    <action>Display dry run preview if requested</action>
    <process>
      If dry_run = true:
      1. Display comprehensive preview:
         - Tasks to archive (completed/abandoned/expanded counts)
         - Deferred: one summary line from `deferred_expanded[]` (Stage 2's subtasks-defer guard)
           - Format: `Deferred: {N} expanded parent(s) held back (subtasks still active)`
           - If `deferred_expanded[]` is empty: `Deferred: none` (mirrors the neighbouring
             memory-candidate and status-reconciliation dry-run lines)
           - Follow with one indented line per `deferred_expanded_detail[]` entry (Decision 6
             mitigation), so a hold specifically is named rather than folded into the generic
             "subtasks still active" summary, e.g. `  - 42: subtask 123 is held (reason: Awaiting
             upstream API decision)`
         - Orphaned directories count
         - Misplaced directories count
         - Roadmap updates needed: same three-way branch as `commands/todo.md`'s dry-run output —
           omit this line only when `roadmap_structure.parseable == true` and there are no
           eligible matches (legitimately nothing to do); **always** print
           `Warning: roadmap structure unrecognized (0 phases, 0 checkboxes, 0 table rows) -- see roadmap_structure in the payload`
           when `parseable == false`, regardless of match count; print
           `Warning: roadmap annotation no-op ({high_confidence_matches} high-confidence match(es), 0 applied) -- see skipped_reasons in the payload`
           when `silent_noop == true`. Invariant: omission is permitted only when the roadmap
           parsed successfully — an unparseable roadmap is never reportable as a successful
           annotation pass.
         - README.md suggestions count
         - Memory candidates: tiered breakdown from `harvest_candidates`
           - Format: `Memory candidates: {T1} Tier 1, {T2} Tier 2, {T3} Tier 3 ({after_dedup} after dedup, {noop_count} NOOP excluded)`
           - If no candidates: `Memory candidates: none`
         - Status reconciliation: one summary line from `reconcile_candidates` (Stage 1.5)
           - Format: `Status reconciliation: {N} task(s) stranded with artifacts on disk`
           - If `reconcile_candidates` is empty: `Status reconciliation: none`
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
      5. **Status reconciliation candidates** (from `reconcile_candidates`, Stage 1.5):
         - If `reconcile_candidates` is empty, skip this sub-step entirely (mirrors how the memory
           harvest sub-step above handles its empty case)
         - Build a multiSelect option list, one option per candidate, showing the task number, its
           current status, the artifact found, and the promotion that would result:
           `Task {N}: status={current_status}, artifact={artifact_basename} -- would promote to
           {target_status}`
         - Present AskUserQuestion with multiSelect (nothing pre-selected -- this stage never
           auto-repairs; every promotion here is an explicit opt-in)
         - Store user-approved candidates as `approved_reconciliations`
         - Only for `approved_reconciliations`: re-run `bash .claude/scripts/reconcile-task-status.sh
           "$task_num" "$todo_session_id"` **without** `--dry-run` to apply the promotion, echoing
           its `[reconcile]` output verbatim. Unselected candidates are left stranded and simply are
           not archived this run -- the correct conservative outcome, since a status promotion
           immediately before a directory move must never be inferred rather than chosen.
    </process>
  </stage>
  
  <stage id="10" name="ArchiveTasks" checkpoint="vault_check_complete">
    <action>Archive tasks to completed_projects (includes mandatory vault check)</action>
    <process>
      For each task in `archivable_tasks[]` (the guard-filtered list from Stage 2 — never a
      freshly-recomputed status match, so deferred expanded parents are excluded):
      1. Update specs/archive/state.json:
         - `completed` and `expanded` tasks add to completed_projects array (there is no third
           array for `expanded`); `abandoned` tasks add to archived_projects array
         - Include all task fields
         - Add archived timestamp
         - Bootstrap if this is the first archive operation (via `--init`), then apply the batch
           transform through `state-write.sh`'s `--state-file` flag, matching
           `commands/todo.md`'s Step 5A shape:
           ```bash
           [ -f specs/archive/state.json ] || bash .claude/scripts/state-write.sh \
             '{ "archived_projects": [], "completed_projects": [] }' \
             --init --state-file specs/archive/state.json --session-id "$todo_session_id"

           archivable_tasks_json=$(printf '%s\n' "${archivable_tasks[@]}" | jq -s '.')
           bash .claude/scripts/state-write.sh \
             '.completed_projects = ([$tasks[] | select(.status == "completed" or .status == "expanded") | .archived_at = $ts] + .completed_projects) |
              .archived_projects = ([$tasks[] | select(.status == "abandoned") | .archived_at = $ts] + .archived_projects)' \
             --state-file specs/archive/state.json \
             --session-id "$todo_session_id" \
             --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
             --argjson tasks "$archivable_tasks_json"
           ```

      2. Update specs/state.json:
         - Remove from active_projects array. As in `commands/todo.md`'s Step 5B, this removal
           must exclude any task listed in `deferred_expanded_nums[]` (Stage 2's guard) even
           though its status matches — the blanket status match alone would delete a deferred
           parent from state.json while its archive-list entry was held back, silently losing the
           task. Since Stage 10 iterates `archivable_tasks[]` directly rather than re-deriving a
           status match against the full `active_projects` array, deferred parents are naturally
           excluded from this removal as long as the removal is driven by the same
           `archivable_tasks[]` list — do not re-select by status here.

      3. Update specs/TODO.md:
         - Remove archived entries (both regular and TODO.md orphans) — the same
           `archivable_tasks[]` guard-filtered list from Stage 2; a deferred parent's entry stays
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

      4. Move project directories to specs/archive/ — again driven by `archivable_tasks[]`; a
         deferred parent's directory stays in place until a later `/todo` run archives it

      5. Track orphaned directories (if approved)

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
         b. Add entry to specs/archive/state.json completed_projects array, matching
            `commands/todo.md`'s Step 5E.2 shape (`$orphan` is the same JSON blob shown in
            step a):
            ```bash
            bash .claude/scripts/state-write.sh \
              '.completed_projects += [{
                project_number: $orphan.project_number,
                project_name: $orphan.project_name,
                status: $orphan.status,
                created_at: "TODO.md_orphan",
                archived_at: $ts
              }]' \
              --state-file specs/archive/state.json \
              --session-id "$todo_session_id" \
              --argjson orphan "$orphan" \
              --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
            ```
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

         Move archive state.json to vault root (a file rename, not a state write -- correctly
         outside state-write.sh's remit):
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

         Reinitialize empty specs/archive/ with fresh state.json via `state-write.sh`'s `--init`
         mode. The timestamp is bound with `--arg`, not shell-interpolated into the filter:
         ```bash
         mkdir -p "specs/archive"

         # Create fresh archive state.json
         bash .claude/scripts/state-write.sh \
           '{
             "_comment": "Archive state for completed and abandoned tasks",
             "completed_projects": [],
             "archived_at": $ts
           }' \
           --init --state-file specs/archive/state.json --session-id "$todo_session_id" \
           --arg ts "$current_timestamp"
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

           # Use state-write.sh to update the task entry
           bash .claude/scripts/state-write.sh \
             '
             .active_projects |= map(
               if .project_number == $old then
                 .project_number = $new |
                 .artifacts |= (if . then map(
                   .path |= gsub("specs/\($old_pad)_"; "specs/\($new_pad)_") |
                   .path |= gsub("specs/\($old)_"; "specs/\($new_pad)_")
                 ) else . end)
               else . end
             )
           ' \
             --session-id "$todo_session_id" \
             --argjson old "$old_num" \
             --argjson new "$new_num" \
             --arg old_pad "$old_padded" \
             --arg new_pad "$new_padded"
         done
         ```

         Update dependencies arrays (task numbers > 1000):
         ```bash
         # Build mapping for all renumbered tasks
         bash .claude/scripts/state-write.sh \
           '
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
         ' \
           --session-id "$todo_session_id" \
           --argjson mappings "$renumber_mappings"
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
         bash .claude/scripts/state-write.sh \
            '.next_project_number = $new_next' \
            --session-id "$todo_session_id" \
            --argjson new_next "$new_next_num"
         ```

         Increment vault_count:
         ```bash
         bash .claude/scripts/state-write.sh \
           '.vault_count = (.vault_count // 0) + 1' \
           --session-id "$todo_session_id"
         ```

         Add entry to vault_history:
         ```bash
         current_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
         archived_count=$(jq -r '.completed_projects | length' "${vault_path}/state.json" 2>/dev/null || echo "0")
         task_range="1-$((next_num - renumber_count - 1))"

         bash .claude/scripts/state-write.sh \
           '
           .vault_history = (.vault_history // []) + [{
             vault_number: $vault_num,
             vault_dir: $vault_dir,
             created_at: $created,
             task_range: $range,
             archived_count: $archived,
             final_task_number: $final
           }]
         ' \
           --session-id "$todo_session_id" \
           --arg vault_dir "$vault_path/" \
           --argjson vault_num "$new_vault_num" \
           --arg created "$current_timestamp" \
           --arg range "$task_range" \
           --argjson archived "$archived_count" \
           --argjson final "$next_num"
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
      Split design: completed-task annotation is delegated to `roadmap-integration.sh
      --annotate`; abandoned-task annotation stays this skill's own logic, since the script has
      no abandoned-status code path at all (see the script's header "Caller contract").

      1. **Build a filtered snapshot** from Stage 5's roadmap-eligible-task capture, taken
         *before* Stage 10's archival mutated `active_projects` — reading the live
         `specs/state.json` at this point (after Stage 10) would find none of the tasks being
         archived. Create a scratch directory (`mktemp -d`), write
         `{"active_projects": [<completed-status entries of Stage 5's roadmap-eligible tasks>]}`
         as `<scratchdir>/state.json`, and remove the scratch directory via `trap` on exit.
      2. **Snapshot safety rules**: the snapshot is a `--state` input only, never written back
         over `specs/state.json`; because the script resolves its archive input as the sibling
         `<scratchdir>/archive/state.json`, which does not exist, previously archived tasks are
         deliberately excluded from this run's annotation — only this run's newly-completed
         tasks are ever annotated.
      3. **Apply completed-task annotations**: invoke
         `roadmap-integration.sh --roadmap specs/ROADMAP.md --state <scratchdir>/state.json --annotate`
         and read `annotation_summary` from the payload: `annotations_made`, `items_skipped`,
         `skipped_reasons`, `high_confidence_matches`, `silent_noop`.
      4. **Apply abandoned-task annotations** (this skill's own logic, gated on
         `roadmap_structure.parseable` from Stage 5 — when `parseable` is false, do not attempt
         the annotation and rely on Stage 8/16's warning instead of silently no-op'ing): for each
         abandoned match, skip if already annotated, else `- [ ] item *(Task {N} abandoned: reason)*`
         (checkbox stays unchecked).
      5. Track changes: `completed_annotated` (from the script), `abandoned_annotated` (from step
         4), `items_skipped`/`skipped_reasons`/`high_confidence_matches`/`silent_noop` (from the
         script's `annotation_summary`)
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
         - `status` here already flows straight through from the task's state.json entry, so an
           `expanded` entry is recorded exactly as `completed`/`abandoned` entries are — expanded
           is a valid archived status in CHANGE_LOG entries, no separate handling needed
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

  <stage id="14.5" name="ReapRuntimeFiles">
    <action>Reap stale session-scoped orchestration runtime files and stale session-registry
    entries</action>
    <process>
      `/todo` is run far more often than `/refresh`, so this stage wires the same two reap calls
      `skill-refresh/SKILL.md` Steps 4.5 and 4.6 already make into every live `/todo` invocation,
      closing the gap where litter accumulates unbounded between manual `/refresh` runs. Reuses
      the `dry_run` boolean already parsed in Stage 1 -- same `--dry-run` passthrough branch shape
      as Steps 4.5/4.6.

      This stage is non-blocking: a nonzero exit or a missing script is logged and stepped over,
      never failing `/todo`. Both `ORCHESTRATOR_SESSION_REAP_MIN` and
      `SESSION_REGISTRY_REAP_MIN` (default 240min each) are honored unchanged, so an in-flight
      batch orchestration run is never reaped out from under itself. `/refresh`'s own invocation
      of these same two scripts (Steps 4.5/4.6) is untouched by this stage.

      ```bash
      echo ""
      echo "=== Reaping Stale Session-Scoped Orchestration Files ==="
      echo ""

      if [ "$dry_run" = true ]; then
          .claude/scripts/reap-session-runtime-files.sh --dry-run || true
      else
          .claude/scripts/reap-session-runtime-files.sh || true
      fi

      echo ""
      echo "=== Reaping Stale Session Registry Entries ==="
      echo ""

      if [ "$dry_run" = true ]; then
          .claude/scripts/task-lock.sh session-reap --dry-run || true
      else
          .claude/scripts/task-lock.sh session-reap || true
      fi
      ```

      Echo each script's own per-item output verbatim rather than summarizing it away, matching
      `skill-refresh/SKILL.md`'s "echo verbatim" convention for these same two calls. Because
      every path either script reaps is gitignored (see
      `context/standards/orchestrator-runtime-files.md`'s Class Table), Stage 15's staging is a
      fixed explicit path list and needs no git interaction for these deletions -- the reap
      simply lands ahead of Stage 15's commit in the same run, never inside it.
    </process>
  </stage>

  <stage id="15" name="GitCommit">
    <action>Commit all changes</action>
    <process>
      1. **Pre-commit vault safety net**: If next_project_number > 1000 and vault_count unchanged, block commit with error directing back to Stage 10 sub-step 9
      2. Apply the purpose-built archive scope from `.claude/context/standards/git-staging-scope.md`
         — never a repo-wide add. Stage the fixed archive paths plus every path this run actually
         touched: `git add specs/archive/ specs/TODO.md specs/state.json`, then conditionally add
         `specs/CHANGE_LOG.md` (Stage 12), `specs/ROADMAP.md` (Stage 11 annotations), any
         `README.md` files updated (Stage 13), and `.memory/` (Stage 14 memory harvest) — each
         only when that stage reports it made changes
      3. Commit: `todo: archive {N} tasks` with counts for completed, abandoned, expanded, roadmap, orphans, misplaced, readme, memories
    </process>
  </stage>
  
  <stage id="16" name="OutputResults">
    <action>Display final results</action>
    <process>
      Display summary with counts for:
      - Archived tasks (completed/abandoned/expanded)
      - Deferred expanded parents: `{N} held back (subtasks still active)`, from
        `deferred_expanded[]` (Stage 2); omit the line when `deferred_expanded[]` is empty
      - Directory operations (orphans tracked/misplaced moved)
      - Runtime file reap: echo Stage 14.5's two reap calls' own summary lines verbatim (e.g.
        "reaped N of M session-scoped orchestration file(s)" and "reaped N of M stale session
        registry entries"), the same verbatim-echo convention as the lines above
      - Updates applied (roadmap annotations/readme changes/changelog entries): same three-way
        branch as Stage 8's dry-run line — omit the roadmap count only when
        `roadmap_structure.parseable == true` and zero items were annotated; **always** print
        `Warning: roadmap structure unrecognized (0 phases, 0 checkboxes, 0 table rows) -- see roadmap_structure in the payload`
        when `parseable == false`; print
        `Warning: roadmap annotation no-op ({high_confidence_matches} high-confidence match(es), 0 applied) -- see skipped_reasons in the payload`
        when `silent_noop == true`. Invariant (stated once, applies to both Stage 8 and this
        stage): omission is permitted only when the roadmap parsed successfully — an unparseable
        roadmap is never reportable by `/todo` as a successful annotation pass.
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
