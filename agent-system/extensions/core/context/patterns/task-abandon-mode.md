# Task Abandon Mode

This file is the complete and only specification for `/task`'s Abandon Mode (`--abandon`). It
was extracted verbatim from `commands/task.md`'s former `## Abandon Mode (--abandon)` section.
It MUST be followed exactly when `/task --abandon` is dispatched.

---

## Abandon Mode (--abandon)

Parse task ranges:

1. For each task:
   **Lookup and validate task via gate-in**:
   ```bash
   # Note: command-gate-in.sh reads active_projects only (not archive).
   # This is correct for abandon mode which operates on active tasks.
   # gate_in also guards against abandoning already-terminal tasks.
   source .claude/scripts/command-gate-in.sh "$task_number" "abandon"
   # Exports: SESSION_ID, TASK_TYPE, TASK_STATUS, PROJECT_NAME, DESCRIPTION, PADDED_NUM
   # gate_in exits with error if task not found or already in terminal status
   slug="$PROJECT_NAME"
   ```

   **Read full task JSON for archive operation** (gate-in validated existence; read blob for jq insert):
   ```bash
   task_data=$(jq -c --argjson num "$task_number" \
     '.active_projects[] | select(.project_number == $num)' \
     specs/state.json)
   ```

   **Move to archive via jq** (two-step to avoid jq escaping bug - see `jq-escaping-workarounds.md`):
   ```bash
    # Step 1: Add to archive with abandoned status. The archive target is reached via
    # state-write.sh's --state-file flag, so this step is mutex-guarded and staged exactly like
    # the live-state write in Step 2 below -- a single specs/.scope-lock mutex covers both
    # targets (see context/patterns/task-lock.md's State-Write Convention section), so this
    # step's acquire/release and Step 2's are safely sequential rather than nested.
    bash .claude/scripts/state-write.sh \
      '.completed_projects = [$task | .status = "abandoned" | .abandoned = $ts] + .completed_projects' \
      --state-file specs/archive/state.json \
      --session-id "$SESSION_ID" \
      --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson task "$task_data"

    # Step 2: Remove from active using del() instead of map(select(!=)). Fold --regen-todo
    # in -- this write is immediately followed by nothing but the TODO.md regen (abandoned
    # task no longer in active_projects, so it will not be rendered). SESSION_ID was
    # exported by command-gate-in.sh above. --regen-todo stays on this live-state write only --
    # D4 refuses it on the archive write above, and the intent here is also correct: TODO.md
    # should reflect the removal from active_projects, not the archive insert.
    bash .claude/scripts/state-write.sh \
      'del(.active_projects[] | select(.project_number == ($num | tonumber)))' \
      --session-id "$SESSION_ID" \
      --arg num "$task_number" \
      --regen-todo
    ```

   **Move task directory to archive** (handle both legacy unpadded and new padded formats):
   ```bash
   # slug and PADDED_NUM are already exported by gate-in above
   # Check padded format first (new), then unpadded (legacy)
   if [ -d "specs/${PADDED_NUM}_${slug}" ]; then
     mv "specs/${PADDED_NUM}_${slug}" "specs/archive/${PADDED_NUM}_${slug}"
   elif [ -d "specs/${task_number}_${slug}" ]; then
     mv "specs/${task_number}_${slug}" "specs/archive/${PADDED_NUM}_${slug}"
   fi
   ```
   Note: Archived directories always use 3-digit padding regardless of source format.

2. Git commit: "task: abandon tasks {ranges}"

