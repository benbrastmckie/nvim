---
name: skill-lean-research-hard
description: Research Lean 4 and Mathlib for theorem proving tasks with hard-mode behavioral contracts. Invoke for Lean-language research using LeanSearch, Loogle, and lean-lsp tools when hard-mode is requested.
allowed-tools: Agent, Bash, Edit, Read, Write
---

# Lean Research Hard Skill

Thin wrapper that delegates Lean hard-mode research to `lean-research-hard-agent` subagent.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns,
this skill handles all postflight operations (status update, artifact linking, git commit) before returning.

Hard mode activates H2 (anti-analysis), H3 (lean4 reference grounding), H4 (adversarial
self-verification), and H5 (divergence audit) behavioral contracts. Cost is approximately
3-5x standard lean4 research.

## Trigger Conditions

This skill activates when:
- Task type is "lean4" or "lean" (either accepted)
- `/research N --hard` is invoked for a lean4 task
- Routed by `command-route-skill.sh` via `routing_hard.research.lean4`

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- `focus_prompt` - Optional focus for research direction

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

---

### Stage 1.5: Hard-Mode Cost Note

Before proceeding, emit the cost note for session tracking:

```
[hard-mode] skill-lean-research-hard activated (session flag: hard)
Cost multiplier: ~3-5x standard lean4 research
Behavioral contracts: H2 (anti-analysis), H3 (lean4 reference grounding),
  H4 (adversarial self-verification), H5 (divergence audit on demand)
```

---

### Stage 2: Preflight Status Update

Update task status to "researching" BEFORE invoking subagent.

```bash
bash .claude/scripts/update-task-status.sh preflight "$task_number" research "$session_id"
```

```bash
# WARN-only: reports lean-lsp MCP registration drift without blocking dispatch. Two
# invocations: the no-flag call keeps the human-readable transcript message unchanged; the
# --dispatch-block call separately captures the evidence-tier block for Stage 3's
# lean_readiness field, so the finding reaches the subagent instead of being discarded after
# printing to the transcript. Not latency-critical on this (non-/orchestrate) path.
lean_readiness=""
if [ -x .claude/scripts/lean-mcp-preflight-check.sh ]; then
  bash .claude/scripts/lean-mcp-preflight-check.sh || true
  lean_readiness="$(bash .claude/scripts/lean-mcp-preflight-check.sh --dispatch-block 2>/dev/null)" || lean_readiness=""
fi
```

---

### Stage 3: Prepare Delegation Context

Prepare delegation context for the subagent:

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "research", "skill-lean-research-hard"],
  "timeout": 3600,
  "effort_flag": "hard",
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "lean4"
  },
  "focus_prompt": "{optional focus — if contains 'divergence' or 'audit', agent activates H5}",
  "lean_readiness": "{Stage 2's captured --dispatch-block output; empty string when the probe is absent or this is not a Lean project}",
  "metadata_file_path": "specs/{N}_{SLUG}/.return-meta.json"
}
```

---

### Stage 4: Invoke Subagent

**CRITICAL**: You MUST use the **Agent** tool to spawn the subagent.

**Required Tool Invocation**:
```
Tool: Agent (NOT Skill, NOT Plan)
Parameters:
  - subagent_type: "lean-research-hard-agent"
  - model: "opus"
  - prompt: [Include task_context, delegation_context, focus_prompt, metadata_file_path]
  - description: "Execute hard-mode Lean research for task {N}"
```

When `lean_readiness` is non-empty, include it verbatim in the subagent prompt — the field is
useless if the prompt composer drops it.

**DO NOT** use `Skill(lean-research-hard-agent)` - this will FAIL.

The subagent will:
- Apply H2 anti-analysis contract (lean4 formal proof line bar)
- Apply H3 reference grounding (5-column lemma mapping table for Tier 1)
- Execute H4 adversarial self-verification pass before returning
- Execute H5 divergence audit if focus_prompt contains "divergence" or "audit"
- Search Mathlib using lean_leansearch, lean_loogle, lean_leanfinder
- Create research report in `specs/{N}_{SLUG}/reports/`
- Write metadata to `specs/{N}_{SLUG}/.return-meta.json`
- Return a brief text summary (NOT JSON)

---

### Stage 4b: Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Agent tool, you MUST write a
`.return-meta.json` file now before proceeding to postflight.

If you DID use the Agent tool, skip this stage.

---

## Postflight (ALWAYS EXECUTE)

### Stage 5: Parse Subagent Return

Read the metadata file:

```bash
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
    adversarial_triggered=$(jq -r '.metadata.adversarial_verification_triggered // false' "$metadata_file")
    findings_count=$(jq -r '.metadata.findings_count // 0' "$metadata_file")
else
    echo "Error: Invalid or missing metadata file"
    status="failed"
fi
```

---

### Stage 6: Update Task Status (Postflight)

If status is "researched", update state.json:

```bash
bash .claude/scripts/update-task-status.sh postflight "$task_number" research "$session_id"
```

**On partial/failed**: Keep status as "researching" for resume.

---

### Stage 7: Link Artifacts

Add artifact to state.json with summary. Update TODO.md per
`@.claude/context/patterns/artifact-linking-todo.md` with `field_name=**Research**`,
`next_field=**Plan**`.

```bash
if [ -n "$artifact_path" ]; then
    bash .claude/scripts/state-write.sh \
      '(.active_projects[] | select(.project_number == $num)).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
      --session-id "$session_id" \
      --argjson num "$task_number" \
      --arg path "$artifact_path" \
      --arg type "$artifact_type" \
      --arg summary "$artifact_summary"
fi
```

---

### Stage 8: Git Commit

```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task ${task_number}: complete research" \
  --session "${session_id}" \
  --honest-index-rows "${task_number}" \
  -- "specs/${padded_num}_${project_name}/reports/" \
     "specs/${padded_num}_${project_name}/.return-meta.json" \
     "specs/TODO.md" \
     "specs/state.json"
```

---

### Stage 9: Return Brief Summary

Return a brief text summary (NOT JSON). Example:

```
Hard-mode research completed for task {N}:
- Found {findings_count} verified Mathlib lemmas/theorems
- H4 adversarial verification: {triggered revisions / no revisions needed}
- H5 divergence audit: {activated / not activated}
- H3 reference grounding tier: {Tier 1 / Tier 2 / Tier 3 / none}
- Created report at specs/{N}_{SLUG}/reports/MM_{short-slug}.md
- Status updated to [RESEARCHED]
- Changes committed
```

---

## Error Handling

### Input Validation Errors
Return immediately with error message if task not found.

### Metadata File Missing
If subagent didn't write metadata file:
1. Keep status as "researching"
2. Report error to user

### Git Commit Failure
Non-blocking: Log failure but continue with success response.

### Subagent Timeout
Return partial status if subagent times out (default 3600s).
Keep status as "researching" for resume.

---

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:
1. **Re-run Lean searches** - All MCP searches are done by agent
2. **Re-verify type signatures** - Verification is done by agent
3. **Edit research reports** - Artifact creation is agent work
4. **Run adversarial verification** - H4 is done by agent

The postflight phase is LIMITED TO:
- Reading agent metadata file
- Updating state.json via jq
- Updating TODO.md status marker via Edit
- Linking artifacts in state.json
- Git commit

---

## Return Format

This skill returns a **brief text summary** (NOT JSON). The JSON metadata is written to the
file and processed internally.
