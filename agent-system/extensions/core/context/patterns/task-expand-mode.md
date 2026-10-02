# Task Expand Mode

This file is the complete and only specification for `/task`'s Expand Mode (`--expand`). It was
extracted verbatim from `commands/task.md`'s former `## Expand Mode (--expand)` section. It MUST
be followed exactly when `/task --expand` is dispatched.

---

## Expand Mode (--expand)

Parse task number and optional prompt:

1. **Lookup task via gate-in**:
   ```bash
   # Note: command-gate-in.sh reads active_projects only (not archive).
   # This is correct for expand mode which operates on active tasks.
   source .claude/scripts/command-gate-in.sh "$task_number" "expand"
   # Exports: SESSION_ID, TASK_TYPE, TASK_STATUS, PROJECT_NAME, DESCRIPTION, PADDED_NUM
   # gate_in exits with error if task not found or in terminal status
   ```

2. **Apply the divide-reason list** to DESCRIPTION (exported by gate-in) to find legitimate
   breakpoints. A breakpoint is legitimate only where a named divide reason from Component 0 in
   `.claude/docs/reference/standards/multi-task-creation-standard.md` holds (see that component for
   the full list; it is not restated here). Do not split on a bare topical breakpoint that fails
   every named reason — the same bidirectional test that governs consolidation at creation time
   governs division here.

2.5. **Read parent topic** for inheritance:
   ```bash
   parent_topic=$(jq -r --arg num "$task_number" \
     '.active_projects[] | select(.project_number == ($num | tonumber)) | .topic // ""' \
     specs/state.json)
   ```

   **Mode A Universal Fallback**: If `parent_topic` is empty, invoke Mode A per
   @.claude/context/patterns/topic-assignment-pattern.md (Mode A: Interactive, batch variant —
   this assigns one topic shared by all subtasks being created). There is no Skip option;
   topic assignment is mandatory. Capture the result in `parent_topic`.
   ```bash
   if [[ -z "$parent_topic" ]]; then
     mapfile -t existing_topics < <(bash .claude/scripts/manage-topics.sh list)
     # Follow @.claude/context/patterns/topic-assignment-pattern.md (Mode A: Interactive,
     # batch variant) to show the picker and capture the result in $parent_topic.
   fi
   ```
   AskUserQuestion:
   ```json
   {
     "question": "Assign a topic to subtasks (parent has none)?",
     "header": "Topic",
     "multiSelect": false,
     "options": [
       {"label": "<existing-topic-1>", "description": "Existing topic"},
       {"label": "<existing-topic-2>", "description": "Existing topic"},
       {"label": "New topic...", "description": "Free-text follow-up to name a new topic"}
     ]
   }
   ```
   - If user selects an existing topic → `parent_topic="$selected"`
   - If user selects "New topic..." → free-text follow-up, capture as `parent_topic`

3. **Create subtasks** using the Create Task Mode jq pattern in `.claude/commands/task.md`'s
   Create Task Mode section for each, inheriting parent topic. The
   subtask count is a consequence of Step 2's divide-reason test, not an independently chosen
   number: create one subtask per part that Step 2 justified splitting out. In practice this is
   usually 2-5 subtasks, but that range is an expected outcome, not a target — a task for which
   Step 2 found no applicable divide reason should not be expanded at all; report that finding
   back to the user instead of forcing a split.
   ```bash
   # Each subtask jq entry MUST include a "description" field:
   # where $subtask_desc is the subtask's description derived from the parent task analysis.
   # Include "topic": parent_topic in each subtask jq entry. $parent_topic is non-empty by
   # construction: either inherited from the parent or assigned via the Mode A
   # universal fallback above.
   # After each subtask entry is written to state.json, call manage-topics.sh set:
   bash .claude/scripts/manage-topics.sh set "$subtask_num" "$parent_topic" \
     2>/dev/null || echo "Warning: manage-topics.sh set failed (non-fatal)" >&2
   ```

4. **Update original task** to reference subtasks and set status to expanded. Fold
   `--regen-todo` in — this write is immediately followed by nothing but the TODO.md regen
   (SESSION_ID was exported by `command-gate-in.sh` above):
   ```bash
   bash .claude/scripts/state-write.sh \
     '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
       status: "expanded",
       subtasks: [list_of_subtask_numbers],
       last_updated: $ts
      }' \
     --session-id "$SESSION_ID" \
     --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     --regen-todo
   ```

5. Git commit: "task {N}: expand into subtasks"

