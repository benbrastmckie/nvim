---
name: skill-cslib-implementation-hard
description: Implement CSLib proofs with hard-mode contracts (H2 anti-analysis, H7 territory, H9 wrap-up with sorry_inventory). Invoke for --hard cslib implementation tasks.
allowed-tools: Agent, Bash, Edit, Read, Write
---

# CSLib Implementation Hard Skill

Hard-mode wrapper that delegates CSLib proof implementation to `cslib-implementation-hard-agent`
subagent. Extends `skill-cslib-implementation` with:

- Single-phase dispatch context (H1): reads handoff JSON to identify next incomplete phase
- Territory parameters (H7): includes territory contract when dispatched from orchestrate-hard
- Anti-analysis contract (H2): passed in delegation context for agent enforcement
- Wrap-up discipline (H9): sorry_inventory populated in orchestrator handoff

**Relationship to base skill**: Structurally follows `skill-cslib-implementation` postflight
pattern. Key difference: when `orchestrator_mode=true`, uses per-phase dispatch (H1) rather than
whole-plan dispatch.
**Maintenance note**: changes to `skill-cslib-implementation` postflight should be mirrored here.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/formats/return-metadata-file.md` - Metadata file schema
- Path: `.claude/context/contracts/anti-analysis.md` - H2 contract (loaded by agent)
- Path: `.claude/context/contracts/wrap-up.md` - H9 contract (loaded by agent)
- Path: `.claude/context/contracts/territory.md` - H7 contract (when territory params present)
- Path: `.claude/context/contracts/phase-closure.md` - depth-first phase closure: close one phase before opening the next (loaded by agent)
- Path: `.claude/context/contracts/pre-edit-gate.md` - per-item evidence before applying a mechanical-list edit (loaded by agent)
- Path: `.claude/context/patterns/postflight-control.md` - Marker file protocol
- Path: `.claude/context/patterns/subagent-continuation-loop.md` - Continuation loop pattern

## Trigger Conditions

This skill activates when:
- `/implement N --hard` is invoked and task type is `cslib`
- Not currently routing-reachable: the routing-ladder collapse retired the skill-side `routing`/
  `routing_hard` manifest blocks and their resolver. This skill is pending migration onto
  `hard_contracts` (a separate, not-yet-dispatched follow-on); until then it is reachable only by
  direct invocation, not through `/implement --hard` dispatch
- Note: `skill-orchestrate`'s own hard-mode dispatch (both effort modes, one engine — the
  formerly-separate hard-mode engine is deleted) resolves and dispatches the AGENT
  (`cslib-implementation-hard-agent`) directly via `command-route-agent.sh`, not this SKILL
  file; this skill's own activation is via the paths above.

---

## Execution Flow

### Stage 1: Input Validation

```bash
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)

if [ -z "$task_data" ]; then
  return error "Task $task_number not found"
fi

task_type=$(echo "$task_data" | jq -r '.task_type // "general"')
status=$(echo "$task_data" | jq -r '.status')
project_name=$(echo "$task_data" | jq -r '.project_name')
description=$(echo "$task_data" | jq -r '.description // ""')

if [ "$status" = "completed" ] || [ "$status" = "abandoned" ] || [ "$status" = "expanded" ]; then
  return error "Task is in terminal state [$status]"
fi
```

---

### Stage 1.5: Hard-Mode Cost Note

```bash
session_flag_file="/tmp/.hard-mode-notified-${SESSION_ID:-$$}"
if [ ! -f "$session_flag_file" ]; then
  echo "[hard-mode] Hard mode active (cslib implementation). Cost: ~3-5x standard." >&2
  touch "$session_flag_file"
fi
```

---

### Stage 2: Preflight Status Update

Source `skill-base.sh` once, then follow `@.claude/context/patterns/skill-preflight-flow.md`'s
Stage 2 (preflight status update):

```bash
source .claude/scripts/skill-base.sh
padded_num=$(printf "%03d" "$task_number")
skill_name="skill-cslib-implementation-hard"
operation="implement"
skill_preflight_update "$task_number" "$operation" "$session_id"
```

---

### Stage 2b: Preflight Cache Warming

Ensure Mathlib cache is warm before delegating to the agent:

```bash
cd /home/benjamin/Projects/cslib && lake exe cache get 2>&1 || echo "Warning: cache fetch failed (non-fatal)"
```

This is non-blocking. Cache fetch failure does not prevent delegation. On a cache hit, this
completes in ~1-2 minutes and prevents 30-45 minute Mathlib rebuilds during CI verification.

---

### Stage 3: Create Postflight Marker

Follow `@.claude/context/patterns/skill-preflight-flow.md`'s Stage 3 (marker creation):

```bash
skill_create_postflight_marker "$padded_num" "$project_name" "$session_id" "$skill_name" "$operation"
```

---

### Stage 3a: Calculate Artifact Number

```bash
next_num=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .next_artifact_number // 1' \
  specs/state.json)

if [ "$next_num" -le 1 ]; then
  artifact_number=1
else
  artifact_number=$((next_num - 1))
fi

artifact_padded=$(printf "%02d" "$artifact_number")
```

---

### Stage 3b: Single-Phase Dispatch Context (H1)

When `orchestrator_mode=true`, determine the specific phase to dispatch:

```bash
if [ "$orchestrator_mode" = "true" ]; then
  # Read handoff JSON to find next incomplete phase
  handoff_file="specs/.orchestrator-handoff.json"
  if [ -f "$handoff_file" ]; then
    phases_completed=$(jq -r '.phases_completed // 0' "$handoff_file")
    next_phase=$((phases_completed + 1))
    echo "[hard-mode] Per-phase dispatch: targeting phase ${next_phase} (cslib)" >&2
  else
    next_phase=1
    echo "[hard-mode] No handoff found, dispatching cslib phase 1" >&2
  fi
fi
```

---

### Stage 4a: Memory Retrieval (Auto)

```bash
if [ "$clean_flag" != "true" ]; then
  memory_context=$(bash .claude/scripts/memory-retrieve.sh "$description" "$task_type" "" 2>/dev/null) || memory_context=""
fi
```

```bash
# Literature briefing injection (independent of clean_flag)
lit_context=""
if [ "$lit_flag" = "true" ]; then
  lit_context=$(bash .claude/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""
fi

# lit_context will be empty string if:
# - lit_flag is not "true" (skipped)
# - specs/literature/ sub-index is empty or missing
# - script exited with error
```

**Note**: `lit_flag` is independent of `clean_flag`. Using `--clean --lit` suppresses memory retrieval but still injects literature briefing. Literature briefing is gated solely on `lit_flag == "true"`.

---

### Stage 4: Prepare Delegation Context

Pass anti-analysis contract reference and territory params (when applicable):

```json
{
  "session_id": "{session_id}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "implement", "skill-cslib-implementation-hard"],
  "timeout": 7200,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "cslib"
  },
  "artifact_number": "{artifact_number}",
  "effort_flag": "hard",
  "model_flag": "{model_flag from command}",
  "plan_path": "{plan_path}",
  "phase_number": "{next_phase when orchestrator_mode=true, null otherwise}",
  "territory": "{territory params from orchestrate-hard dispatch, null if not provided}",
  "orchestrator_mode": "{orchestrator_mode}",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json",
  "dispatch_seq": "{dispatch_seq from this skill's own delegation context, forwarded unchanged; omit if absent}"
}
```

**Forward `dispatch_seq` unchanged.** If this skill's own delegation context carries a
`dispatch_seq` field, forward it into the sub-agent's delegation context above verbatim — the
same pass-through treatment already given to `territory`. Never invent, increment, or recompute
a value at this layer; only the orchestrator mints one. If absent, omit the field. See
`context/patterns/dispatch-report-not-termination.md`.

> **CRITICAL**: No source reading before delegation. The subagent handles all codebase exploration.

---

### Stage 4b: Read Format Specification

```bash
format_content=$(cat .claude/context/formats/summary-format.md)
```

---

### Stage 5: Invoke Subagent

```
Tool: Agent
Parameters:
  - subagent_type: "cslib-implementation-hard-agent"
  - prompt: [task_context, delegation_context, format specification, memory_context, lit_context]
  - description: "Execute hard-mode CSLib implementation for task {N} phase {next_phase}"
```

- If `memory_context` is non-empty, include it as a `<memory-context>` block after the format specification.
- If `lit_context` is non-empty, include it as a `<literature-briefing>` block after the memory context.
- Do NOT inject empty blocks when content is empty.

Include territory parameters in prompt when `territory` is non-null:
```
<territory-contract>
This is a hard-mode parallel dispatch. Territory rules are mandatory:
- Owned files: {territory.owned_files}
- Read-only references: {territory.read_only_files}
- See .claude/context/contracts/territory.md for full protocol
</territory-contract>
```

---

### Stage 5b: Self-Execution Fallback

If Agent tool not used, write `.return-meta.json` with `status: "implemented"` before postflight.

---

### Stage 5c: Continuation Loop Init

```bash
continuation_count=0
max_continuations=3
task_dir="specs/${padded_num}_${project_name}"
cat > "${task_dir}/.continuation-loop-guard" << EOF
{
  "session_id": "${session_id}",
  "continuation_count": 0,
  "max_continuations": 3
}
EOF
```

---

## Postflight (ALWAYS EXECUTE)

### Stage 6: Parse Subagent Return

```bash
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
    memory_candidates=$(jq -c '.memory_candidates // []' "$metadata_file")
    completion_summary=$(jq -r '.completion_data.completion_summary // ""' "$metadata_file")
    phases_completed=$(jq -r '.phases_completed // 0' "$metadata_file")
    phases_total=$(jq -r '.phases_total // 0' "$metadata_file")
else
    status="failed"
fi
```

---

### Stage 7: Update Task Status (Postflight)

```bash
if [ "$status" = "implemented" ]; then
  bash .claude/scripts/update-task-status.sh postflight "$task_number" implement "$session_id" --phase-check=warn
fi
# On partial: keep status as "implementing" for resume
```

---

### Stage 7a: Propagate Memory Candidates and Completion Summary

Same as `skill-cslib-implementation` Stage 7a + completion summary propagation.

---

### Stage 8: Link Artifacts

Two-step jq pattern (Issue #1132 safety):
1. Filter out existing summary artifacts
2. Add new summary artifact

Regenerate TODO.md after linking.

---

### Stage 8a: Lifecycle TTS Notification

```bash
if [ -f ".claude/scripts/lifecycle-notify.sh" ]; then
  bash ".claude/scripts/lifecycle-notify.sh" "$status" &
fi
```

---

### Stage 9: Cleanup

Follow `@.claude/context/patterns/skill-postflight-flow.md`'s Stage 9 (cleanup); this skill also
removes `.continuation-loop-guard`, which is implementer-specific and not folded into
`skill_cleanup`:

```bash
skill_cleanup "$padded_num" "$project_name"
rm -f "specs/${padded_num}_${project_name}/.continuation-loop-guard"
```

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Edit .lean files** - All CSLib proof work is done by agent
2. **Run lake build/test/lint** - Verification is done by agent
3. **Use lean-lsp MCP tools** - Domain tools are for agent use only
4. **Grep for sorries** - Debt analysis is agent work
5. **Write summary/reports** - Artifact creation is agent work

> **PROHIBITION**: If the subagent returned partial or failed status, MUST NOT attempt to continue,
> complete, or "fill in" the subagent's work. Report partial/failed status and let user re-run
> `/implement --hard` to resume.

The postflight phase is LIMITED TO:
- Reading agent metadata file
- Updating state.json via jq
- Updating TODO.md status marker via Edit
- Linking artifacts in state.json
- Git commit
- Cleanup of temp/marker files

## Return Format

Brief text summary (NOT JSON).
