---
name: skill-reviser
description: Thin wrapper that delegates plan revision to reviser-agent subagent. Invoke for /revise command.
allowed-tools: Agent, Bash, Edit, Read, Write, Glob, Grep
---

# Reviser Skill

Thin wrapper that delegates plan revision to `reviser-agent` subagent.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns,
this skill handles all postflight operations (status update, artifact linking, git commit) before returning.
This eliminates the "continue" prompt issue between skill return and orchestrator.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/formats/return-metadata-file.md` - Metadata file schema
- Path: `.claude/context/patterns/postflight-control.md` - Marker file protocol
- Path: `.claude/context/patterns/file-metadata-exchange.md` - File I/O helpers
- Path: `.claude/context/patterns/jq-escaping-workarounds.md` - jq escaping patterns (Issue #1132)
- Path: `.claude/context/formats/plan-format.md` - Plan file format specification

Note: This skill is a thin wrapper with internal postflight. Context is loaded by the delegated agent.

## Trigger Conditions

This skill activates when:
- `/revise` command is invoked
- Task exists in state.json

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json

```bash
# Lookup task
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)

# Validate exists
if [ -z "$task_data" ]; then
  return error "Task $task_number not found"
fi

# Extract fields
task_type=$(echo "$task_data" | jq -r '.task_type // "general"')
status=$(echo "$task_data" | jq -r '.status')
project_name=$(echo "$task_data" | jq -r '.project_name')
description=$(echo "$task_data" | jq -r '.description // ""')
```

**No status-based ABORT rules.** The skill works regardless of task status. Routing is determined by plan file existence, not status.

---

### Stage 2: Preflight

No intermediate "revising" status is needed for revision. The task transitions directly to "planned" on success (via postflight). Skip preflight status update.

**Rationale**: Unlike `/plan` which sets "planning" as an intermediate status, `/revise` is lightweight enough that an intermediate status adds no value. The postflight script handles the final status update.

---

### Stage 3: Create Postflight Marker

Source `skill-base.sh` once, then follow `@.claude/context/patterns/skill-preflight-flow.md`'s
Stage 3 (marker creation). `operation` stays `"revise"` here (not remapped to `research`/`plan`/
`implement`): unlike Stage 2's preflight status update (intentionally skipped above, so there is
no `update-task-status.sh` vocabulary constraint in play for this skill), the marker's `operation`
field is an opaque string with no vocabulary requirement — see
`skill_create_postflight_marker`'s signature in `skill-base.sh`.

```bash
source .claude/scripts/skill-base.sh
padded_num=$(printf "%03d" "$task_number")
skill_name="skill-reviser"
operation="revise"
skill_create_postflight_marker "$padded_num" "$project_name" "$session_id" "$skill_name" "$operation"
```

---

### Stage 3a: Calculate Artifact Number

Read `next_artifact_number` from state.json. Revision uses the current counter directly (not current-1), since each revision is a new planning attempt that advances the sequence.

```bash
# Read next_artifact_number from state.json
next_num=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .next_artifact_number // 1' \
  specs/state.json)

# Fallback for legacy tasks: count existing plan artifacts
if [ "$next_num" = "null" ] || [ -z "$next_num" ]; then
  padded_num=$(printf "%03d" "$task_number")
  count=$(ls "specs/${padded_num}_${project_name}/plans/"*[0-9][0-9]*.md 2>/dev/null | wc -l)
  next_num=$((count + 1))
fi

# Revision uses the current counter directly (each revision is a new planning attempt)
artifact_number=$next_num

# Reconciliation: scan all task subdirs for max artifact number on disk
# Handles legacy tasks where next_artifact_number may be behind actual files
padded_num=$(printf "%03d" "$task_number")
max_on_disk=$(find "specs/${padded_num}_${project_name}" -name "[0-9][0-9]_*.md" 2>/dev/null \
  | sed 's|.*/\([0-9][0-9]\)_.*|\1|' | sort -n | tail -1)
max_on_disk=${max_on_disk:-0}
# Strip leading zeros to avoid octal interpretation
max_on_disk=$((10#$max_on_disk))
if [ "$artifact_number" -le "$max_on_disk" ]; then
  artifact_number=$((max_on_disk + 1))
fi

artifact_padded=$(printf "%02d" "$artifact_number")

# Collision check: ensure no existing file uses this prefix in plans/
while ls "specs/${padded_num}_${project_name}/plans/${artifact_padded}_"*.md 2>/dev/null | grep -q .; do
  artifact_number=$((artifact_number + 1))
  artifact_padded=$(printf "%02d" "$artifact_number")
done
```

**Note**: Revision increments `next_artifact_number` in postflight (Stage 8a), so each revision gets a unique, monotonically increasing number.

---

### Stage 4: Research Discovery

Discover existing plan and new research reports:

**4a. Find existing plan:**
```bash
padded_num=$(printf "%03d" "$task_number")
plan_dir="specs/${padded_num}_${project_name}/plans"
existing_plan=$(ls -1t "$plan_dir"/*.md 2>/dev/null | head -1)
```

**4b. Find new research reports:**

Use BOTH `reports_integrated` from state.json and file modification time comparison:

```bash
reports_dir="specs/${padded_num}_${project_name}/reports"
new_reports=()

if [ -n "$existing_plan" ]; then
  plan_mtime=$(stat -c %Y "$existing_plan")

  # Check reports_integrated from state.json (primary)
  integrated=$(jq -r --argjson num "$task_number" \
    '.active_projects[] | select(.project_number == $num) | .plan_metadata.reports_integrated // [] | .[]' \
    specs/state.json 2>/dev/null)

  for report in "$reports_dir"/*.md; do
    if [ -f "$report" ]; then
      report_basename=$(basename "$report")
      # Check if already integrated
      if echo "$integrated" | grep -qF "$report_basename"; then
        continue
      fi
      # Fallback: check modification time
      report_mtime=$(stat -c %Y "$report")
      if [ "$report_mtime" -gt "$plan_mtime" ]; then
        new_reports+=("$report")
      fi
    fi
  done
else
  # No plan exists -- all reports are "new"
  for report in "$reports_dir"/*.md; do
    if [ -f "$report" ]; then
      new_reports+=("$report")
    fi
  done
fi
```

---

### Stage 4b: Read and Inject Format Specification

Read the plan format file and prepare it for injection into the subagent prompt. This ensures the subagent always has the full format specification in its context.

```bash
format_content=$(cat .claude/context/formats/plan-format.md)
```

The format content will be included as a delimited section in the Stage 5 prompt.

---

### Stage 5: Prepare Delegation Context and Invoke Subagent

**CRITICAL**: You MUST use the **Agent** tool to spawn the subagent.

Prepare delegation context:

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "revise", "skill-reviser"],
  "timeout": 1800,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "{task_type}"
  },
  "artifact_number": "{artifact_padded from Stage 3a}",
  "existing_plan_path": "{path to existing plan or null}",
  "new_research_paths": ["{path to report1}", "{path to report2}"],
  "revision_reason": "{optional user reason}",
  "roadmap_path": "specs/ROADMAP.md",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

**Required Tool Invocation**:
```
Tool: Agent (NOT Skill, NOT Plan)
Parameters:
  - subagent_type: "reviser-agent"
  - prompt: [Include task_context, delegation_context, existing_plan_path, new_research_paths,
             revision_reason, metadata_file_path,
             AND the format specification from Stage 4b as shown below]
  - description: "Execute plan revision for task {N}"
```

**Format Injection**: Include the format specification from Stage 4b in the prompt as a clearly-delimited section:

```
<artifact-format-specification>
## CRITICAL: Plan Format Requirements

You MUST follow this format specification exactly when writing the plan artifact.
Non-compliance will be caught by postflight validation.

{format_content from Stage 4b}
</artifact-format-specification>
```

Place this section AFTER the delegation context JSON and BEFORE any other instructions.

**DO NOT** use `Skill(reviser-agent)` - this will FAIL.

The subagent will:
- Load revision context files
- Determine revision mode (plan revision or description update)
- Load existing plan and new research reports
- Synthesize revised plan or update description
- Write metadata to `specs/{NNN}_{SLUG}/.return-meta.json`
- Return a brief text summary (NOT JSON)

---

### Stage 5b: Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Agent tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding to postflight. Use the schema from
`return-metadata-file.md` with the appropriate status value for this operation.

If you DID use the Agent tool, skip this stage -- the subagent already wrote the metadata.

---

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 5b). Do NOT skip these stages for any reason.

### Stage 6: Read Metadata File

Read the metadata file:

```bash
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
    new_description=$(jq -r '.metadata.new_description // ""' "$metadata_file")
else
    echo "Error: Invalid or missing metadata file"
    status="failed"
fi
```

---

### Stage 6a: Validate Artifact Content

If subagent status is "planned" and `artifact_path` is non-empty, validate the plan artifact against format requirements. This is **non-blocking** -- warnings are logged but do not prevent postflight from completing.

```bash
if [ "$status" = "planned" ] && [ -n "$artifact_path" ] && [ -f "$artifact_path" ]; then
    echo "Validating plan artifact..."
    if ! bash .claude/scripts/validate-artifact.sh "$artifact_path" plan --fix; then
        echo "WARNING: Plan artifact has format issues (non-blocking). Review output above."
    fi
fi
```

---

### Stage 7: Postflight Status Update

**For Plan Revision** (status == "planned"):

Harvest `artifact_path`'s (the revised plan's) per-phase `Files to modify` union and forward it
as `--file-scope-add`, so `/revise` re-harvests on every revision round (Decision 2: additive
merge is safe even when a revision drops a phase's file mention). Degrades to no flag at all on
any harvester failure or empty result -- never re-implement path extraction here:

```bash
fsa_args=()
if [ -n "$artifact_path" ] && [ -f "$artifact_path" ]; then
  harvested_file_scope=$(bash .claude/scripts/plan-file-scope-harvest.sh "$artifact_path" 2>/dev/null) \
    || echo "WARNING: plan-file-scope-harvest.sh failed for $artifact_path, skipping file_scope harvest (non-blocking)"
  if [ -n "$harvested_file_scope" ] && [ "$harvested_file_scope" != "[]" ] && [ "$harvested_file_scope" != "null" ]; then
    fsa_args=(--file-scope-add="$harvested_file_scope")
  fi
fi
```

Update task status to "planned" using the centralized script:

```bash
bash .claude/scripts/update-task-status.sh postflight $task_number plan $session_id "${fsa_args[@]}"
```

If the script exits non-zero, log error but continue (status update is best-effort for revise).

**For Description Update** (status == "description_updated"):

Update state.json description and TODO.md directly:

Fold `--regen-todo` in — this write is immediately followed by nothing but the TODO.md regen:
```bash
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == $num)) |= . + {
    description: $desc,
    last_updated: $ts
  }' \
  --session-id "$session_id" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg desc "$new_description" \
  --argjson num "$task_number" \
  --regen-todo
```

**On partial/failed**: Keep status unchanged (do not call the script).

---

### Stage 8: Artifact Linking (Plan Revision Only)

Add the new plan artifact to state.json.

**IMPORTANT**: Use two-step jq pattern to avoid Issue #1132 escaping bug. See `jq-escaping-workarounds.md`.

```bash
if [ -n "$artifact_path" ]; then
    # Step 1: Filter out existing plan artifacts (use "| not" pattern to avoid != escaping - Issue #1132)
    bash .claude/scripts/state-write.sh \
      '(.active_projects[] | select(.project_number == $num)).artifacts =
        [(.active_projects[] | select(.project_number == $num)).artifacts // [] | .[] | select(.type == "plan" | not)]' \
      --session-id "$session_id" \
      --argjson num "$task_number"

    # Step 2: Add new plan artifact. Fold --regen-todo in — this write is immediately followed
    # by nothing but the TODO.md regen.
    bash .claude/scripts/state-write.sh \
      '(.active_projects[] | select(.project_number == $num)).artifacts += [{"path": $path, "type": "plan"}]' \
      --session-id "$session_id" \
      --argjson num "$task_number" --arg path "$artifact_path" \
      --regen-todo || echo "WARNING: state-write.sh --regen-todo failed (non-fatal)" >&2
fi
```

If the script exits non-zero, log a warning but continue (regeneration errors are non-blocking).

---

### Stage 8a: Increment Artifact Counter (Plan Revision Only)

After linking the artifact, increment `next_artifact_number` so subsequent revisions get unique numbers:

```bash
if [ -n "$artifact_path" ]; then
  bash .claude/scripts/state-write.sh \
    '(.active_projects[] | select(.project_number == $num)).next_artifact_number =
      (((.active_projects[] | select(.project_number == $num)).next_artifact_number // 1) + 1)' \
    --session-id "$session_id" \
    --argjson num "$task_number"
fi
```

**Note**: This is the key Bug 1 fix. Unlike plan (which reads current-1 and does NOT increment), revision reads the current counter, uses it, and increments it. This ensures each revision gets a unique, monotonically increasing artifact number.

---

### Stage 8b: Lifecycle TTS Notification

Fire TTS and WezTerm tab coloring after artifact linking is complete:

```bash
lifecycle_script=".claude/scripts/lifecycle-notify.sh"
if [ -f "$lifecycle_script" ]; then
    bash "$lifecycle_script" "$status" &
fi
```

Non-blocking: called in background after artifacts are linked. Speaks "Tab N STATUS"
(e.g., "Tab 3 planned") to announce the lifecycle transition.

---

### Stage 9: Git Commit

Apply task-dir scope from `.claude/context/standards/git-staging-scope.md` — targeted staging,
never a repo-wide add — then commit via `.claude/scripts/git-commit-scoped.sh`, the single
sanctioned implementation of path-scoped, mutex-serialized committing:

**For Plan Revision:**
```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task {N}: revise plan (v{NEW_VERSION})" \
  --session "${session_id}" \
  --honest-index-rows {N} \
  -- "specs/${padded_num}_${project_name}/" "specs/TODO.md" "specs/state.json"
```

**For Description Update:**
```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task {N}: revise description" \
  --session "${session_id}" \
  --honest-index-rows {N} \
  -- "specs/${padded_num}_${project_name}/" "specs/TODO.md" "specs/state.json"
```

Commit failure is non-blocking (log and continue).

---

### Stage 10: Cleanup

Follow `@.claude/context/patterns/skill-postflight-flow.md`'s Stage 9 (cleanup):

```bash
skill_cleanup "$padded_num" "$project_name"
```

---

### Stage 11: Return Brief Summary

Return a brief text summary (NOT JSON). Example:

**Plan Revision:**
```
Plan revised for task {N}:
- Preserved {X} completed phases, revised {Y} phases
- Integrated {Z} new research reports
- Created revised plan at specs/{NNN}_{SLUG}/plans/MM_{short-slug}.md
- Status updated to [PLANNED]
- Changes committed with session {session_id}
```

**Description Update:**
```
Description updated for task {N}:
- Previous: {old_description}
- New: {new_description}
- Status: [{current_status}] (unchanged)
- Changes committed with session {session_id}
```

---

## Error Handling

### Input Validation Errors
Return immediately with error message if task not found.

### Metadata File Missing
If subagent didn't write metadata file:
1. Keep status unchanged
2. Do not cleanup postflight marker
3. Report error to user

### Git Commit Failure
Non-blocking: Log failure but continue with success response.

### jq Parse Failure
If jq commands fail with INVALID_CHARACTER or syntax error (Issue #1132):
1. Log to errors.json
2. Retry with two-step pattern (already implemented in Stage 8)

### Subagent Timeout
Return partial status if subagent times out (default 1800s).
Keep status unchanged for resume.

---

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Edit source files** - All revision work is done by agent
2. **Run build/test commands** - Verification is done by agent
3. **Use research tools** - Web/codebase search is for agent use only
4. **Analyze task requirements** - Analysis is agent work
5. **Write plan files** - Artifact creation is agent work

The postflight phase is LIMITED TO:
- Reading agent metadata file
- Updating status via `update-task-status.sh` (handles state.json + TODO.md atomically)
- Linking artifacts in state.json
- Updating description in state.json/TODO.md (description update path only)
- Git commit
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md

---

## Return Format

This skill returns a **brief text summary** (NOT JSON). The JSON metadata is written to the file and processed internally.
