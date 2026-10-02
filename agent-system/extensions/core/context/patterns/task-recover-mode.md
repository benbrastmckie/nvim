# Task Recover Mode

This file is the complete and only specification for `/task`'s Recover Mode (`--recover`). It
was extracted verbatim from `commands/task.md`'s former `## Recover Mode (--recover)` section. It
MUST be followed exactly when `/task --recover` is dispatched.

---

## Recover Mode (--recover)

Parse task ranges after --recover (e.g., "343-345", "337, 343"):

<!-- NOTE: command-gate-in.sh does NOT apply here. gate-in reads active_projects only;
     recover mode looks up tasks from specs/archive/state.json (completed_projects).
     The inline archive lookup below is intentional. -->

Recover Mode does not source `command-gate-in.sh` either (the task is being restored, not
looked up in `active_projects`), so it has no `session_id` of its own — generate one once for
the whole recover run, following the same self-generating fallback used by Sync Mode
(`context/patterns/task-sync-mode.md`):
```bash
source .claude/scripts/lib/common.sh
session_id="$(common_session_id)"
```

1. For each task number in range:
   **Lookup task in archive via jq**:
   ```bash
   task_data=$(jq -r --arg num "$task_number" \
     '.completed_projects[] | select(.project_number == ($num | tonumber))' \
     specs/archive/state.json)

   if [ -z "$task_data" ]; then
     echo "Error: Task $task_number not found in archive"
     exit 1
   fi

   # Get project name for directory move
   slug=$(echo "$task_data" | jq -r '.project_name')
   ```

   **Topic check (net-new)**: Recovered tasks may predate mandatory topic
   assignment or have lost their topic in archival. Check before returning to
   `active_projects`:
   ```bash
   recovered_topic=$(echo "$task_data" | jq -r '.topic // empty')

   if [[ -z "$recovered_topic" ]]; then
     mapfile -t existing_topics < <(bash .claude/scripts/manage-topics.sh list)
     # Follow @.claude/context/patterns/topic-assignment-pattern.md (Mode A: Interactive)
     # to show the picker and capture the result in $recovered_topic. No Skip option;
     # topic assignment is mandatory.
     task_data=$(echo "$task_data" | jq --arg topic "$recovered_topic" '.topic = $topic')
   fi
   ```
   AskUserQuestion (shown only when `recovered_topic` is empty):
   ```json
   {
     "question": "Assign a topic to recovered task {task_number} (none found)?",
     "header": "Topic",
     "multiSelect": false,
     "options": [
       {"label": "<existing-topic-1>", "description": "Existing topic"},
       {"label": "<existing-topic-2>", "description": "Existing topic"},
       {"label": "New topic...", "description": "Free-text follow-up to name a new topic"}
     ]
   }
   ```

   **Move to active_projects via jq** (two-step to avoid jq escaping bug - see `jq-escaping-workarounds.md`):
   ```bash
   # Step 1: Remove from archive using del() instead of map(select(!=)). The archive target is
   # reached via state-write.sh's --state-file flag, so this step is mutex-guarded and staged
   # exactly like the live-state write in Step 2 below -- a single specs/.scope-lock mutex covers
   # both targets (see context/patterns/task-lock.md's State-Write Convention section), so this
   # step's acquire/release and Step 2's are safely sequential rather than nested.
   bash .claude/scripts/state-write.sh \
     'del(.completed_projects[] | select(.project_number == ($num | tonumber)))' \
     --state-file specs/archive/state.json \
     --session-id "$session_id" \
     --arg num "$task_number"

   # Step 2: Add to active with status reset ($task_data now carries a non-empty .topic)
   bash .claude/scripts/state-write.sh \
     '.active_projects = [$task | .status = "not_started" | .last_updated = $ts] + .active_projects' \
     --session-id "$session_id" \
     --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson task "$task_data"

   # Ensure the topic is registered in active_topics (idempotent)
   if [[ -n "$recovered_topic" ]]; then
     bash .claude/scripts/manage-topics.sh add "$recovered_topic" \
       2>/dev/null || echo "Warning: manage-topics.sh add failed (non-fatal)" >&2
   fi
   ```

   **Move project directory from archive** (handle both legacy unpadded and new padded formats):
   ```bash
   PADDED_NUM=$(printf "%03d" "$task_number")
   # Check legacy unpadded format first (e.g., 15_slug), then padded (e.g., 015_slug)
   if [ -d "specs/archive/${task_number}_${slug}" ]; then
     mv "specs/archive/${task_number}_${slug}" "specs/${PADDED_NUM}_${slug}"
   elif [ -d "specs/archive/${PADDED_NUM}_${slug}" ]; then
     mv "specs/archive/${PADDED_NUM}_${slug}" "specs/${PADDED_NUM}_${slug}"
   fi
   ```
   Note: Recovered directories always use 3-digit padding regardless of source format.

   **Regenerate TODO.md** from state.json:
   ```bash
   bash .claude/scripts/generate-todo.sh \
     2>/dev/null || echo "Note: Failed to regenerate TODO.md (non-fatal)" >&2
   ```

2. Git commit: "task: recover tasks {ranges}"

