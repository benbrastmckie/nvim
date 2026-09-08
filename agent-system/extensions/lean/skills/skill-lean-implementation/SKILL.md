---
name: skill-lean-implementation
description: Implement Lean 4 proofs and definitions using lean-lsp tools. Invoke for Lean-language implementation tasks.
allowed-tools: Agent, Bash, Edit, Read, Write
---

# Lean Implementation Skill

Thin wrapper that delegates Lean 4 proof implementation to `lean-implementation-agent` subagent.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns,
this skill handles all postflight operations (status update, artifact linking, git commit) before returning.

## Trigger Conditions

This skill activates when:
- Task type is "lean4" or "lean" (either accepted)
- /implement command targets a Lean task
- Plan exists and task is ready for implementation

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- Task status must allow implementation (planned, implementing, partial)
- Task language must be "lean"

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

# Validate task_type (accept both "lean" and "lean4")
if [ "$task_type" != "lean" ] && [ "$task_type" != "lean4" ]; then
  return error "Task $task_number is not a Lean task"
fi
```

---

### Stage 2: Preflight Status Update

Update task status to "implementing" BEFORE invoking subagent.

```bash
bash .claude/scripts/update-task-status.sh preflight "$task_number" implement "$session_id"
```

---

### Stage 3: Prepare Delegation Context

Prepare delegation context for the subagent:

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "implement", "skill-lean-implementation"],
  "timeout": 7200,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "lean"
  },
  "plan_path": "specs/{N}_{SLUG}/plans/MM_{short-slug}.md",
  "metadata_file_path": "specs/{N}_{SLUG}/.return-meta.json",
  "compare_flag": {true|false}
}
```

`compare_flag` is forwarded from this skill's own delegation context unchanged and defaults to
`false` when absent — modeled on the hard skill's own "forward `dispatch_seq` unchanged, never
invent" wording. It gates the subagent's advisory Comparator step (see Stage 4 below).

---

### Stage 4: Invoke Subagent

**CRITICAL**: You MUST use the **Agent** tool to spawn the subagent.

**Required Tool Invocation**:
```
Tool: Agent (NOT Skill, NOT Plan)
Parameters:
  - subagent_type: "lean-implementation-agent"
  - prompt: [Include task_context, delegation_context, plan_path, metadata_file_path]
  - description: "Execute Lean implementation for task {N}"
```

**DO NOT** use `Skill(lean-implementation-agent)` - this will FAIL.

The subagent will:
- Load implementation context files (MCP tools guide, tactic patterns)
- Parse plan and find resume point
- Execute phases sequentially using lean-lsp MCP tools
- Verify proofs with `lean_goal` and `lake build` (detached, via the build guard — see
  `context/project/lean4/operations/long-builds.md`)
- Create implementation summary
- Run the advisory Comparator gate against the snapshot Challenge and the implemented Solution
  when `compare_flag` is `true` (no-op, no cost, when absent or `false`)
- Write metadata to `specs/{N}_{SLUG}/.return-meta.json`
- Return a brief text summary (NOT JSON)

---

### Stage 4b: Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Agent tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding to postflight. Use the schema from
`return-metadata-file.md` with the appropriate status value for this operation.

If you DID use the Agent tool, skip this stage -- the subagent already wrote the metadata.

---

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 4b). Do NOT skip these stages for any reason.

### Stage 5: Parse Subagent Return

Read the metadata file:

```bash
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    phases_completed=$(jq -r '.metadata.phases_completed // 0' "$metadata_file")
    phases_total=$(jq -r '.metadata.phases_total // 0' "$metadata_file")

    # Read verification results (agent is responsible for verification)
    verification_passed=$(jq -r '.verification.verification_passed // false' "$metadata_file")
else
    echo "Error: Invalid or missing metadata file"
    status="failed"
    verification_passed="false"
fi
```

**Note**: The agent performs all verification (sorry check, axiom check, lake build — detached and
guarded, see `context/project/lean4/operations/long-builds.md`) and records results in metadata.
This skill reads those results - it does NOT re-verify.

---

### Stage 6b: Plan Compliance Check (Read from Metadata)

**This stage only runs if status from metadata is "implemented".**

Read the agent-reported compliance result from metadata (agent ran the grep check in Final Verification Stage; SKILL reads the result — MUST NOT re-run grep per postflight-tool-restrictions.md):

```bash
if [ "$status" = "implemented" ]; then
    compliance_check=$(jq -r '.metadata.compliance_check // "skipped"' "$metadata_file" 2>/dev/null)

    case "$compliance_check" in
        "failed")
            echo "Stage 6b: Plan compliance check FAILED (agent reported)"
            echo "  See agent output for missing deliverables or integrity violations"
            status="partial"
            ;;
        "passed")
            echo "Stage 6b: Plan compliance check PASSED"
            ;;
        "skipped"|*)
            echo "Stage 6b: INFO — compliance_check absent or skipped; proceeding"
            ;;
    esac
fi
```

**Architecture note**: The `.claude/` skill MUST NOT run grep or shell analysis in postflight (see postflight-tool-restrictions.md). The lean-implementation-agent runs the check during Final Verification Stage and records results in metadata. This stage reads that result only.

---

### Stage 6c: Comparator Verdict Surface (Read from Metadata)

Read the agent-recorded `comparator` block, if any, from metadata and surface it. The
Comparator invocation itself was performed by the agent in its Final Verification Stage — this
stage reads that recorded result and MUST NOT re-run it, per
`context/standards/postflight-tool-restrictions.md`, exactly as Stage 6b above reads
`compliance_check` rather than re-running its grep.

```bash
comparator_ran=$(jq -r '.comparator.ran // false' "$metadata_file" 2>/dev/null)
comparator_verdict=$(jq -r '.comparator.verdict // ""' "$metadata_file" 2>/dev/null)
comparator_verdict_source=$(jq -r '.comparator.verdict_source // ""' "$metadata_file" 2>/dev/null)
comparator_reason_detail=$(jq -r '.comparator.reason_detail // ""' "$metadata_file" 2>/dev/null)

if [ "$comparator_ran" = "false" ] && [ -z "$comparator_verdict" ]; then
    echo "Stage 6c: INFO — no comparator block recorded (--compare not requested, or agent preflight stopped before invocation); proceeding"
elif [ "$comparator_verdict" = "verified" ]; then
    echo "Stage 6c: Comparator PASS — verdict=verified"
else
    echo "Stage 6c: *** COMPARATOR ADVISORY FINDING ***"
    echo "  verdict: ${comparator_verdict} (verdict_source: ${comparator_verdict_source})"
    echo "  reason_detail: ${comparator_reason_detail}"
    echo "  This is ADVISORY ONLY — completion is proceeding regardless. See the implementation"
    echo "  summary's Comparator section for full detail."
fi
```

**Asymmetry note (deliberate, not an omission)**: unlike Stage 6b's `compliance_check == "failed"`
branch above, which sets `status="partial"`, this stage MUST NOT assign `status` on any
`comparator` verdict, however severe. The gate is advisory-only by binding design decision — see
`### comparator (optional)` in `return-metadata-file.md`.

---

### Stage 6: Update Task Status (Postflight)

**If status is "implemented" AND verification_passed is true**:

```bash
bash .claude/scripts/update-task-status.sh postflight "$task_number" implement "$session_id" --phase-check=warn
```

Then add completion_data to state.json (not covered by centralized script):
```bash
# Extract completion_data fields from metadata (if present)
completion_summary=$(jq -r '.completion_data.completion_summary // ""' "$metadata_file")
roadmap_items=$(jq -c '.completion_data.roadmap_items // []' "$metadata_file")

# Add completion_summary if present
if [ -n "$completion_summary" ]; then
    bash .claude/scripts/state-write.sh \
      '(.active_projects[] | select(.project_number == $num)).completion_summary = $summary' \
      --session-id "$session_id" \
      --argjson num "$task_number" \
      --arg summary "$completion_summary"
fi

# Add roadmap_items if present (for non-meta tasks only)
if [ "$task_type" != "meta" ] && [ "$roadmap_items" != "[]" ] && [ -n "$roadmap_items" ]; then
    bash .claude/scripts/state-write.sh \
      '(.active_projects[] | select(.project_number == $num)).roadmap_items = $items' \
      --session-id "$session_id" \
      --argjson num "$task_number" \
      --argjson items "$roadmap_items"
fi
```

**If status is "partial"**:

Keep status as "implementing" but update resume point.
TODO.md stays as `[IMPLEMENTING]`.

---

### Stage 7: Link Artifacts

Add summary artifact to state.json. Update TODO.md per `@.claude/context/patterns/artifact-linking-todo.md` with `field_name=**Summary**`, `next_field=**Description**`.

```bash
if [ -n "$summary_artifact_path" ]; then
    bash .claude/scripts/state-write.sh \
      '(.active_projects[] | select(.project_number == $num)).artifacts += [{"path": $path, "type": "summary", "summary": $summary}]' \
      --session-id "$session_id" \
      --argjson num "$task_number" \
      --arg path "$summary_artifact_path" \
      --arg summary "$summary_artifact_summary"
fi
```

---

### Stage 8: Git Commit

Commit changes with session ID:

```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task ${task_number}: complete implementation" \
  --session "${session_id}" \
  --honest-index-rows "${task_number}" \
  -- "Theories/" \
     "specs/${padded_num}_${project_name}/summaries/" \
     "specs/${padded_num}_${project_name}/plans/" \
     "specs/TODO.md" \
     "specs/state.json"
```

---

### Stage 9: Return Brief Summary

Return a brief text summary (NOT JSON). Example:

```
Lean implementation completed for task {N}:
- All {phases_total} phases executed, all proofs verified
- Lake build: Success
- Key theorems: {theorem names}
- Created summary at specs/{N}_{SLUG}/summaries/MM_{short-slug}-summary.md
- Status updated to [COMPLETED]
- Changes committed
```

If a `comparator` block was recorded and its `verdict` is not `verified`, add a bullet naming the
verdict and its `verdict_source` (e.g. `- Comparator advisory finding: statement_mismatch
(verdict_source: runner) — see summary for detail`). Add no more than a single short line for the
`verified` or absent cases beyond what the example above already shows.

---

## Error Handling

### Input Validation Errors
Return immediately with error message if task not found, wrong language, or status invalid.

### Metadata File Missing
If subagent didn't write metadata file:
1. Keep status as "implementing"
2. Report error to user

### Git Commit Failure
Non-blocking: Log failure but continue with success response.

### Subagent Timeout
Return partial status if subagent times out (default 7200s).
Keep status as "implementing" for resume.

---

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Edit source files** - All Lean proof work is done by agent
2. **Run lake build** - Build verification is done by agent (the agent's build is detached and
   guarded — see `context/project/lean4/operations/long-builds.md`)
3. **Use MCP tools** - lean-lsp tools are for agent use only
4. **Grep for sorries** - Debt analysis is agent work
5. **Write summary/reports** - Artifact creation is agent work
6. **Re-run the Comparator** - The advisory gate is agent work; this skill only reads the
   recorded `comparator` block (Stage 6c)
7. **Downgrade status on a Comparator verdict** - The gate is advisory-only by binding design
   decision; see Stage 6c's asymmetry note

> **PROHIBITION**: If the subagent returned partial or failed status, the lead skill MUST NOT attempt to continue, complete, or "fill in" the subagent's work. Report the partial/failed status and let the user re-run `/implement` to resume.

The postflight phase is LIMITED TO:
- Reading agent metadata file
- Updating state.json via jq
- Updating TODO.md status marker via Edit
- Linking artifacts in state.json
- Git commit
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md

---

## Return Format

This skill returns a **brief text summary** (NOT JSON). The JSON metadata is written to the file and processed internally.
