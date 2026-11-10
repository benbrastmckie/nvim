---
name: skill-nix-research
description: Conduct Nix/NixOS/Home Manager research using MCP-NixOS, web docs, and codebase exploration. Invoke for nix research tasks.
allowed-tools: Agent, Bash, Edit, Read, Write
---

# Nix Research Skill

Thin wrapper that delegates Nix research to `nix-research-agent` subagent.

## Trigger Conditions

This skill activates when:
- Task type is "nix"
- Research is needed for Nix, NixOS, or Home Manager configuration
- Package definitions or module patterns need to be gathered

## Execution Flow

### Stage 1: Input Validation
Validate task_number exists and task_type is "nix".

### Stage 2 + Stage 3: Preflight Status Update and Postflight Marker

Source `skill-base.sh` once, then follow `@.claude/context/patterns/skill-preflight-flow.md` in
full for Stage 2 (preflight status update) and Stage 3 (marker creation):

```bash
source .claude/scripts/skill-base.sh
padded_num=$(printf "%03d" "$task_number")
skill_name="skill-nix-research"
operation="research"
```

**Intentional behavior fix**: this skill previously wrote no `.postflight-pending` marker at all —
zero premature-termination protection. This import gives it one.

### Stage 4a: Memory Retrieval and Literature Detection

**Skip memory retrieval if**: `clean_flag` is true (from `--clean`).

```bash
if [ "$clean_flag" != "true" ]; then
  memory_context=$(bash .claude/scripts/sapience-retrieve.sh "$description" "$task_type" "$focus_prompt" 2>/dev/null) || memory_context=""
fi
```

Follow `@.claude/context/patterns/lit-stage4a-flow.md` in full to resolve `--lit` and set
`lit_context`, exactly as `skill-orchestrate` does. This skill supplies the shared block's
preconditions: `lit_flag`, `description`, `orchestrator_mode` (default `"false"` when unset).

### Stage 4: Prepare Delegation Context

Domain-specific context for the nix-research-agent:
- MCP-NixOS tools for package/option lookup (when available)
- NixOS module patterns from `.claude/extensions/nix/context/`
- Local .nix files (flake.nix, home.nix, modules/)

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "research", "skill-nix-research"],
  "timeout": 3600,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "nix"
  },
  "focus_prompt": "{optional focus}",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

If `memory_context` and/or `lit_context` from Stage 4a are non-empty, include them in the prompt
(memory context first, then literature briefing), after the delegation context and before
task-specific instructions. Do NOT inject an empty block for either.

### Stage 5: Invoke Subagent
Use Agent tool with subagent_type: "nix-research-agent".

### Stage 5b: Self-Execution Fallback

Follow `@.claude/context/patterns/skill-self-execution-fallback.md` in full. This skill's success
status value for that block's write obligation is `"researched"`.

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 5b). Do NOT skip these stages for any reason.

### Stage 6: Parse Subagent Return
Read the metadata file from `specs/{N}_{SLUG}/.return-meta.json`.

```bash
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"
if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
    memory_candidates=$(jq -c '.memory_candidates // []' "$metadata_file")
else
    echo "Error: Invalid or missing metadata file"
    status="failed"
fi
```

### Stage 7, 7a, 8, 8a, 9: Postflight Status, Memory Candidates, Artifact Linking, Notify, Cleanup

Follow `@.claude/context/patterns/skill-postflight-flow.md` in full:

```bash
field_name='**Research**'
next_field='**Plan**'
```

## Error Handling

### Input Validation Errors
Return immediately if task not found.

### Metadata File Missing
Keep status as "researching", report error.

### Git Commit Failure
Non-blocking: Log failure but continue.

---

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Edit source files** - All research work is done by agent
2. **Run build/test commands** - Verification is done by agent
3. **Use MCP-NixOS/WebSearch tools** - Research tools are for agent use only
4. **Analyze or grep source** - Analysis is agent work
5. **Write reports** - Artifact creation is agent work

The postflight phase is LIMITED TO:
- Reading agent metadata file
- Calling `update-task-status.sh` for status updates (state.json + TODO.md)
- Linking artifacts in state.json
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md

## Return Format

Brief text summary (NOT JSON).
