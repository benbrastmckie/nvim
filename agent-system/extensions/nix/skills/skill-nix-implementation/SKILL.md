---
name: skill-nix-implementation
description: Implement Nix configuration changes from plans. Invoke for nix implementation tasks.
allowed-tools: Agent, Bash, Edit, Read, Write
---

# Nix Implementation Skill

Thin wrapper that delegates Nix configuration implementation to `nix-implementation-agent` subagent.

## Trigger Conditions

This skill activates when:
- Task type is "nix"
- An implement-phase dispatch targets a Nix task
- NixOS modules, Home Manager configs, or flake changes need to be created using Nix

## Execution Flow

### Stage 1: Input Validation
Validate task_number exists, task_type is "nix", and an implementation plan is present.

### Stage 2 + Stage 3: Preflight Status Update and Postflight Marker

Source `skill-base.sh` once, then follow `@.claude/context/patterns/skill-preflight-flow.md` in
full for Stage 2 (preflight status update) and Stage 3 (marker creation):

```bash
source .claude/scripts/skill-base.sh
padded_num=$(printf "%03d" "$task_number")
skill_name="skill-nix-implementation"
operation="implement"
```

**Intentional behavior fix**: this skill previously wrote no `.postflight-pending` marker at
all — zero premature-termination protection. This import gives it one.

### Stage 4a: Memory Retrieval and Literature Detection

**Skip memory retrieval if**: `clean_flag` is true (from `--clean`).

```bash
if [ "$clean_flag" != "true" ]; then
  memory_context=$(bash .claude/scripts/memory-retrieve.sh "$description" "$task_type" "" 2>/dev/null) || memory_context=""
fi
```

Follow `@.claude/context/patterns/lit-stage4a-flow.md` in full to resolve `--lit` and set
`lit_context`, exactly as `skill-orchestrate` does. This skill supplies the shared block's
preconditions: `lit_flag`, `description`, `orchestrator_mode` (default `"false"` when unset).

### Stage 4: Prepare Delegation Context

Domain-specific context for the nix-implementation-agent:
- Nix style guide from `.claude/extensions/nix/context/`
- MCP-NixOS for package/option validation (when available)
- Verification: `nix flake check`, `nixos-rebuild build --flake .#hostname`

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "implement", "skill-nix-implementation"],
  "timeout": 7200,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "nix"
  },
  "plan_path": "specs/{NNN}_{SLUG}/plans/MM_{short-slug}.md",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

If `memory_context` and/or `lit_context` from Stage 4a are non-empty, include them in the prompt
(memory context first, then literature briefing), after the delegation context and before
task-specific instructions. Do NOT inject an empty block for either.

### Stage 5: Invoke Subagent
Use Agent tool with subagent_type: "nix-implementation-agent".

### Stage 5b: Self-Execution Fallback

Follow `@.claude/context/patterns/skill-self-execution-fallback.md` in full. This skill's success
status value for that block's write obligation is `"implemented"`.

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
    # Schema: .claude/context/formats/return-metadata-file.md
    completion_summary=$(jq -r '.completion_data.completion_summary // ""' "$metadata_file")
    roadmap_items=$(jq -c '.completion_data.roadmap_items // []' "$metadata_file")
else
    echo "Error: Invalid or missing metadata file"
    status="failed"
fi
```

### Stage 7, 7a, 8, 8a, 9: Postflight Status, Memory Candidates, Artifact Linking, Notify, Cleanup

Follow `@.claude/context/patterns/skill-postflight-flow.md` in full:

```bash
field_name='**Summary**'
next_field='**Description**'
```

**Not covered by the shared block**: `completion_summary`/`roadmap_items` propagation via
`skill_propagate_completion_summary`, preserved from before this conversion (already routed
through `skill-base.sh`, which is now sourced once at Stage 2 + Stage 3 above rather than
re-sourced here):

```bash
if [ "$status" = "implemented" ] || [ "$status" = "completed" ]; then
    # Literal "nix" (deliberate): this skill's Trigger Conditions hardcode a single task_type.
    skill_propagate_completion_summary "$task_number" "$completion_summary" "$roadmap_items" "nix"
fi
```

## Error Handling

### Input Validation Errors
Return immediately if task not found.

### Metadata File Missing
Keep status as "implementing", report error.

### Subagent Returns Partial/Failed
Do not attempt to continue, complete, or "fill in" the subagent's work. Report the status and let
the user re-run the implement-phase dispatch to resume.

### Git Commit Failure
Non-blocking: Log failure but continue.

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Edit .nix files** - All Nix config work is done by agent
2. **Run nix flake check** - Verification is done by agent
3. **Analyze or grep source** - Analysis is agent work
4. **Write summary/reports** - Artifact creation is agent work

See `context/standards/postflight-tool-restrictions.md` § "MUST NOT Section Template"
for the full PROHIBITION clause (the lead skill must not continue, complete, or "fill in" a
partial/failed subagent's work; report the status and let the user re-run the implement-phase dispatch) and the
postflight-phase allowed-operations list (read metadata, state.json/TODO.md updates, artifact
linking, git commit, cleanup).

## Return Format

Brief text summary (NOT JSON).
