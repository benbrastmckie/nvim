# Task Sync Mode

This file is the complete and only specification for `/task`'s Sync Mode (`--sync`). It was
extracted verbatim from `commands/task.md`'s former `## Sync Mode (--sync)` section. It MUST be
followed exactly when `/task --sync` is dispatched.

---

## Sync Mode (--sync)

state.json is the authoritative source of truth. Sync validates integrity and regenerates TODO.md.

1. **Validate state.json integrity**:
   ```bash
   state_tasks=$(jq -r '.active_projects[].project_number' specs/state.json | sort -n)
   state_next=$(jq -r '.next_project_number' specs/state.json)
   # Verify state.json is valid JSON
   jq empty specs/state.json || { echo "Error: state.json is invalid JSON"; exit 1; }
   ```

2. **Identify orphan TODO.md tasks** not in state.json (warn user only, do not auto-add):
   ```bash
   todo_tasks=$(grep -o "^### [0-9]\+\." specs/TODO.md | sed 's/[^0-9]//g' | sort -n)
   # Warn about tasks in TODO.md but not in state.json (orphans)
   for task_num in $todo_tasks; do
     if ! jq -e --argjson n "$task_num" '.active_projects[] | select(.project_number == $n)' specs/state.json > /dev/null 2>&1; then
       echo "Warning: Task $task_num in TODO.md not found in state.json (orphan)"
     fi
   done
   ```

2.5. **Artifact reconciliation** — backfill missing artifact registrations:

   Sync Mode does not source `command-gate-in.sh`, so it has no `session_id` of its own —
   generate one inline using the standard portable pattern, shared by this step and step 2.6
   below:
   ```bash
   source .claude/scripts/lib/common.sh
   sync_session_id="$(common_session_id)"
   bash .claude/scripts/reconcile-artifacts.sh --session-id "$sync_session_id"
   ```

2.6. **Status reconciliation** — repair tasks stuck in an in-flight status whose artifact for
   that phase already exists on disk (a crashed or killed session that wrote an artifact but
   never reached postflight). This is the primary, user-invoked trigger for
   `reconcile-task-status.sh`; it runs only on explicit `/task --sync` invocation, never on a
   hot path. Runs after step 2.5 so artifact registration is backfilled before status is
   reconciled against it. Reuses `$sync_session_id` generated in step 2.5 above.

   Sweep every task whose status is one of the four statuses `reconcile-task-status.sh` knows
   how to reconcile (all other statuses are already a no-op inside the script itself, so no
   `!=`/negation selector is needed here):
   ```bash
   reconcile_targets=$(jq -r '
     .active_projects[] |
     select(.status == "researching" or .status == "planning" or .status == "implementing" or .status == "partial") |
     .project_number
   ' specs/state.json)

   promoted_count=0
   for task_num in $reconcile_targets; do
     recon_out=$(bash .claude/scripts/reconcile-task-status.sh "$task_num" "$sync_session_id" 2>&1) || {
       echo "Warning: reconcile-task-status.sh failed for task $task_num (non-fatal)" >&2
       continue
     }
     if [[ -n "$recon_out" ]]; then
       echo "$recon_out"
       if echo "$recon_out" | grep -q "promoted"; then
         promoted_count=$((promoted_count + 1))
       fi
     fi
   done

   if [[ "$promoted_count" -gt 0 ]]; then
     echo "Status reconciliation: $promoted_count task(s) promoted"
   else
     echo "Status reconciliation: no tasks required status repair"
   fi
   ```
   This call is live (not `--dry-run`): the user explicitly invoked a repair command. The
   summary line always prints, including the zero-candidate case — a silent sweep is the
   failure mode this step exists to eliminate.

3. **Regenerate TODO.md from state.json** (single authoritative operation):
   ```bash
   bash .claude/scripts/generate-todo.sh \
     2>/dev/null || echo "Warning: generate-todo.sh failed (non-fatal)" >&2
   ```

6.5. **Topic backfill** for tasks missing the `topic` field:

   Detect active tasks without a topic:
   ```bash
   missing_topics=$(jq -r '.active_projects[] |
     select(.status == "completed" | not) |
     select(.status == "abandoned" | not) |
     select(.status == "expanded" | not) |
     select(.topic == null or .topic == "") |
     "\(.project_number)|\(.project_name)"
   ' specs/state.json)
   ```

   If any tasks need backfill, follow @.claude/context/patterns/topic-assignment-pattern.md
   (Mode A: Interactive — `/task --sync` backfill exception). Loop over detected tasks with
   header "Topic Backfill ({i} of {total})". This is the ONE path in the system permitted an
   explicit deferral option, because it remediates pre-existing topicless tasks rather than
   gatekeeping new-task creation (the mandatory-topic-assignment Decision (a)):
   ```json
   {
     "question": "Assign a topic to task {task_num} ({i} of {total})?",
     "header": "Topic Backfill",
     "multiSelect": false,
     "options": [
       {"label": "<existing-topic-1>", "description": "Existing topic"},
       {"label": "<existing-topic-2>", "description": "Existing topic"},
       {"label": "New topic...", "description": "Free-text follow-up to name a new topic"},
       {"label": "Defer (leave uncategorized for now)", "description": "The one exception to mandatory topic assignment: leaves this pre-existing task topicless for now"}
     ]
   }
   ```

   After each topic selection:
   ```bash
   if [[ "$topic" == "Defer (leave uncategorized for now)" ]]; then
     : # no-op; task remains topicless. The Phase 6 stderr warning in
       # generate-task-order.sh keeps deferred tasks visible until categorized.
   else
     bash .claude/scripts/manage-topics.sh set "$task_num" "$topic"
   fi
   ```

7. Git commit: "sync: reconcile TODO.md and state.json"

