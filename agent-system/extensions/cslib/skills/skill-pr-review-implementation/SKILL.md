---
name: skill-pr-review-implementation
description: Compose PR review response files (pr-response.md, zulip-response.md) for pr-type review tasks. Delegates to pr-review-implementation-agent when sources are present; falls back to cslib-implementation-agent for legacy PR prep tasks. Transitions task to [PR READY]. Invoke for pr implementation tasks.
allowed-tools: Agent, Bash, Edit, Read, Write
---

# PR Review Implementation Skill

Thin wrapper that validates inputs, determines whether this is a PR review response task
(sources present) or a legacy PR description task (sources absent), and delegates to the
appropriate agent. The critical difference from `skill-pr-implementation` is the status
transition: this skill uses `preflight pr_ready` (not `postflight pr_ready`) to set the
task to `[PR READY]`, directing the user to manually post the response files.

## Trigger Conditions

This skill activates when:
- Task type is "pr"
- An implement-phase dispatch targets a pr-type task
- The routing entry for `implement.pr` resolves to `skill-pr-review-implementation`

## Dispatch Decision

After input validation, inspect the `sources` array in the task's state.json entry:

- **Sources present and non-empty** → PR review response workflow
  - Delegate to `pr-review-implementation-agent`
  - Agent composes `pr-response.md` and/or `zulip-response.md`
- **Sources absent or empty** → Legacy PR description workflow
  - Delegate to `cslib-implementation-agent` (same as `skill-pr-implementation`)
  - Agent composes `pr-description.md` from git diff

## Execution Flow

### Stage 1: Input Validation

Validate that:
1. `task_number` exists and resolves to an active project in state.json
2. `task_type` is `"pr"`

```bash
# Check task exists and get task_type
task_type=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .task_type' \
  specs/state.json)

if [ "$task_type" != "pr" ]; then
  echo "Error: Task $task_number has type '$task_type', not 'pr'. skill-pr-review-implementation only handles pr tasks."
  exit 1
fi
```

### Stage 1a: Dispatch Decision

Check for `sources` array in the task entry:

```bash
sources_count=$(jq --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .sources // [] | length' \
  specs/state.json)

if [ "$sources_count" -gt 0 ]; then
  workflow="review_response"
else
  workflow="pr_description"
fi
```

- `workflow="review_response"` → proceed with Stages 2-10 below
- `workflow="pr_description"` → delegate to `cslib-implementation-agent` (legacy path)

**Legacy path**: If `workflow="pr_description"`, use the same delegation context and
postflight as `skill-pr-implementation`. The agent should compose `pr-description.md` from
the task description and git diff, and the skill should call `postflight pr_ready` at Stage 7.

### Stage 2: Preflight Status Update

Update status to "implementing" BEFORE invoking subagent:

```bash
bash .claude/scripts/update-task-status.sh preflight "$task_number" implement "$session_id"
```

### Stage 3: Create Postflight Marker

This skill previously wrote a bare, metadata-free marker via `touch`. Source `skill-base.sh` and
derive `padded_num`/`project_name` (not previously derived anywhere in this skill), then follow
`@.claude/context/patterns/skill-preflight-flow.md`'s Stage 3 (marker creation) so this skill's
marker carries the full Shape A payload, matching every other lifecycle skill:

```bash
source .claude/scripts/skill-base.sh
padded_num=$(printf "%03d" "$task_number")
project_name=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .project_name' \
  specs/state.json)
skill_name="skill-pr-review-implementation"
operation="implement"
skill_create_postflight_marker "$padded_num" "$project_name" "$session_id" "$skill_name" "$operation"
```

### Stage 3a: Read Artifact Number

Read `next_artifact_number` from state.json for naming summary files:

```bash
artifact_number=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .next_artifact_number // 1' \
  specs/state.json)
artifact_number_padded=$(printf "%02d" "$artifact_number")
```

### Stage 4: Prepare Delegation Context

Find the latest research report and plan files:

```bash
# Find latest report (pattern: reports/{NN}_pr-review-research.md or any .md report)
report_path=$(ls "specs/{NNN}_{SLUG}/reports/"*.md 2>/dev/null | sort -r | head -1)

# Find latest plan if it exists
plan_path=$(ls "specs/{NNN}_{SLUG}/plans/"*.md 2>/dev/null | sort -r | head -1)
```

Build the delegation JSON with PR-review-specific fields:

```json
{
  "session_id": "{session_id}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "implement", "skill-pr-review-implementation"],
  "timeout": 3600,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "pr"
  },
  "sources": [...],
  "report_path": "specs/{NNN}_{SLUG}/reports/{NN}_pr-review-research.md",
  "plan_path": "specs/{NNN}_{SLUG}/plans/{NN}_pr-review-impl-skill.md",
  "artifact_number": "01",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

Extract `sources` from state.json:

```bash
sources=$(jq -c --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .sources // []' \
  specs/state.json)
```

Note: Use `jq -c` (compact output) for inline JSON in delegation context.
Use the safe `select(.project_number == $num)` pattern (not `!=`) per jq-escaping-workarounds.md.

### Stage 4a: Memory Retrieval (Optional)

If `--clean` flag is NOT set, retrieve relevant memories:

```bash
memory_context=$(bash .claude/scripts/sapience-retrieve.sh "pr review response implementation" 2>/dev/null || echo "")
```

Include `memory_context` in the delegation context if non-empty.

### Stage 5: Invoke Subagent

Use the Agent tool with:
- `subagent_type: "pr-review-implementation-agent"`
- Prompt: the prepared delegation JSON

The subagent will:
1. Write early metadata to `.return-meta.json`
2. Read the research report and extract reviewer feedback
3. Apply minor code changes if any are requested
4. Compose `pr-response.md` and/or `zulip-response.md`
5. Write final metadata to `.return-meta.json`
6. Return brief text summary

### Stage 5b: Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Agent tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding to postflight. Use the schema from
`return-metadata-file.md` with `status: "implemented"` and include the response file artifacts.

If you DID use the Agent tool, skip this stage -- the subagent already wrote the metadata.

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 5b). Do NOT skip these stages for any reason.

### Stage 6: Parse Subagent Return

Read the metadata file:

```bash
cat "specs/{NNN}_{SLUG}/.return-meta.json"
```

Check `status` field:
- `"implemented"` → success, proceed normally
- `"partial"` → partial success, note in status update
- `"failed"` → failure, update status accordingly

### Stage 6a: Validate Artifact Content (Non-Blocking)

```bash
# Check which response files were created
if [ -f "specs/{NNN}_{SLUG}/pr-response.md" ] && [ -s "specs/{NNN}_{SLUG}/pr-response.md" ]; then
  echo "pr-response.md validated"
else
  echo "Warning: pr-response.md missing or empty"
fi

if [ -f "specs/{NNN}_{SLUG}/zulip-response.md" ] && [ -s "specs/{NNN}_{SLUG}/zulip-response.md" ]; then
  echo "zulip-response.md validated"
fi
```

### Stage 7: Update Task Status (PR READY)

**CRITICAL**: Use `preflight pr_ready` to transition the task to `[PR READY]`.

```bash
bash .claude/scripts/update-task-status.sh preflight "$task_number" pr_ready "$session_id"
```

**Why `preflight pr_ready` and NOT `postflight pr_ready`**:
- `postflight pr_ready` would mark the task `[COMPLETED]` (the postflight for pr_ready is "completed")
- `preflight pr_ready` sets the task to `[PR READY]` without advancing to completed
- The task stays `[PR READY]` until the user manually posts the response files and runs `/pr`

Do NOT use `postflight implement` (that would set [COMPLETED]), and do NOT use `postflight pr_ready`.

### Stage 7a: Propagate Memory Candidates

If `.return-meta.json` contains `memory_candidates` array with entries, log them for later
harvest by `/learn --task N`:

```bash
memory_candidates=$(jq -c '.memory_candidates // []' "specs/{NNN}_{SLUG}/.return-meta.json")
if [ "$memory_candidates" != "[]" ]; then
  echo "Memory candidates available: $memory_candidates"
fi
```

### Stage 8: Link Artifacts in state.json

Add response file artifacts to state.json and regenerate TODO.md.

For each response file created, add an artifact entry. Use `pr_response` for `pr-response.md`
and `zulip_response` for `zulip-response.md`:

```bash
# Read which artifacts were created from .return-meta.json
artifacts=$(jq -c '.artifacts // []' "specs/{NNN}_{SLUG}/.return-meta.json")

# Add each artifact to state.json
# Example for pr-response.md:
bash .claude/scripts/state-write.sh \
  '.active_projects |= map(if .project_number == $num then
     . + {"artifacts": ((.artifacts // []) + [{"type": "pr_response", "path": $path, "summary": $summary}]),
          "next_artifact_number": ((.next_artifact_number // 1) + 1)}
     else . end)' \
  --session-id "$session_id" \
  --argjson num "$task_number" \
  --arg path "specs/{NNN}_{SLUG}/pr-response.md" \
  --arg summary "GitHub PR comment response for review task" \
  --regen-todo
```

### Stage 8a: TTS Lifecycle Notification

```bash
bash .claude/scripts/lifecycle-notify.sh "implement" "$task_number" "pr_ready" 2>/dev/null || true
```

### Stage 9: Cleanup Marker Files

Follow `@.claude/context/patterns/skill-postflight-flow.md`'s Stage 9 (cleanup), reusing the
`padded_num`/`project_name` derived at Stage 3:

```bash
skill_cleanup "$padded_num" "$project_name"
```

### Stage 10: Return Brief Text Summary

Return 3-6 bullet points summarizing:
- Research report used (if any)
- Code changes applied (count)
- Response files created (pr-response.md, zulip-response.md)
- Task status transition (now [PR READY])
- Guidance to manually post response files

Example:
```
- Read PR review research report (7 requested changes, 3 open questions)
- Applied 2 minor code changes (typo fix, import ordering)
- Created pr-response.md with responses to 3 reviewers (5 comments addressed)
- Created zulip-response.md for stream 'cslib' topic 'PR Review: GroupAlgebra'
- Task transitioned to [PR READY]
- Next: Post pr-response.md as GitHub PR comment, send zulip-response.md to Zulip
```

Do NOT return JSON.

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Edit .lean files** - All CSLib proof work is done by agent
2. **Run lake build/test/lint** - Verification is done by agent
3. **Use lean-lsp MCP tools** - Domain tools are for agent use only
4. **Grep for sorries** - Debt analysis is agent work
5. **Write pr-response.md or zulip-response.md** - Artifact creation is agent work
6. **Create feature branches or push to remote** - Never in this skill
7. **Post to GitHub or Zulip** - User handles this manually
8. **Call `postflight pr_ready`** - This skill MUST use `preflight pr_ready` to set [PR READY]
9. **Call `postflight implement`** - That would incorrectly set [COMPLETED]

> **PROHIBITION**: If the subagent returned partial or failed status, the lead skill MUST NOT
> attempt to continue, complete, or "fill in" the subagent's work. Report the partial/failed
> status and let the user re-run the implement-phase dispatch to resume.

The postflight phase is LIMITED TO:
- Reading agent metadata file
- Updating state.json via jq (using `preflight pr_ready` status target)
- Linking artifacts in state.json
- Regenerating TODO.md
- Lifecycle notification
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md

## Return Format

Brief text summary (NOT JSON).
