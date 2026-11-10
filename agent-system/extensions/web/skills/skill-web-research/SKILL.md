---
name: skill-web-research
description: Conduct web development research using framework docs and codebase exploration. Invoke for web research tasks.
allowed-tools: Agent, Bash, Edit, Read, Write
---

# Web Research Skill

Thin wrapper that delegates web research to `web-research-agent` subagent.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns,
this skill handles all postflight operations (status update, artifact linking, git commit) before returning.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/project/web/README.md` - Web context overview
- Path: `.claude/context/project/web/domain/astro-framework.md` - Astro reference

## Trigger Conditions

This skill activates when:
- Task type is "web"
- Research is needed for web development tasks
- Astro, Tailwind, Cloudflare, or accessibility documentation needs to be gathered

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- `focus_prompt` - Optional focus for research direction

```bash
# Lookup task (skill_validate_input exits 1 with its own not-found/terminal-state message; no
# separate existence check needed)
source .claude/scripts/skill-base.sh
skill_validate_input "$task_number"
task_data="$TASK_DATA"

# Extract fields. task_type is re-derived from task_data rather than aliased directly from
# TASK_TYPE, to preserve this skill's "web" default (skill_validate_input's own TASK_TYPE
# default is "general").
task_type=$(echo "$task_data" | jq -r '.task_type // "web"')
status="$TASK_STATUS"
project_name="$PROJECT_NAME"
description="$DESCRIPTION"
```

---

### Stage 2 + Stage 3: Preflight Status Update and Postflight Marker

Source `skill-base.sh` once, then follow `@.claude/context/patterns/skill-preflight-flow.md` in
full for Stage 2 (preflight status update) and Stage 3 (marker creation):

```bash
source .claude/scripts/skill-base.sh
padded_num=$(printf "%03d" "$task_number")
skill_name="skill-web-research"
operation="research"
```

**Routing fix**: this call replaces a hand-rolled raw-`jq` status write with
`update-task-status.sh preflight` (via `skill_preflight_update`), and the raw
`cat > .../.postflight-pending` heredoc (which previously dropped `stop_hook_active`) with
`skill_create_postflight_marker`, which emits the full Shape A key set.

---

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

---

### Stage 4: Prepare Delegation Context

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "research", "skill-web-research"],
  "timeout": 3600,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "web"
  },
  "focus_prompt": "{optional focus}",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

---

### Stage 5: Invoke Subagent

**CRITICAL**: You MUST use the **Agent** tool to spawn the subagent.

```
Tool: Agent (NOT Skill, NOT Plan)
Parameters:
  - subagent_type: "web-research-agent"
  - prompt: [Include task_context, delegation_context, focus_prompt, metadata_file_path]
  - description: "Execute web research for task {N}"
```

The subagent will:
- Search local web project files (src/, public/)
- Search web for framework documentation
- Analyze findings and synthesize recommendations
- Create research report
- Write metadata file
- Return brief text summary

---

### Stage 5b: Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Agent tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding to postflight. Use the schema from
`return-metadata-file.md` with status value "researched".

If you DID use the Agent tool, skip this stage -- the subagent already wrote the metadata.

---

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 5b). Do NOT skip these stages for any reason.

### Stage 6: Parse Subagent Return

Read the metadata file:

```bash
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
    memory_candidates=$(jq -c '.memory_candidates // []' "$metadata_file")
else
    status="failed"
fi
```

---

### Stage 7, 7a, 8, 8a: Postflight Status, Memory Candidates, Artifact Linking, Notify

Follow `@.claude/context/patterns/skill-postflight-flow.md` for Stage 7 (postflight status
update), Stage 7a (memory-candidate propagation), Stage 8 (artifact linking), and Stage 8a (TTS
notify):

```bash
field_name='**Research**'
next_field='**Plan**'
skill_postflight_update "$task_number" "$operation" "$session_id" "$status"
skill_propagate_memory_candidates "$task_number" "$memory_candidates" "$session_id"
skill_link_artifacts "$task_number" "$artifact_path" "$artifact_type" "$artifact_summary" \
  "$field_name" "$next_field" "$session_id"
skill_lifecycle_notify "$status"
```

**Routing fix**: this replaces both the raw-`jq` two-step artifact-linking pattern (previously
hand-rolled per-call, bypassing `state-write.sh`'s mutex) and the missing memory-candidate
propagation (this skill never read or propagated `memory_candidates` before this conversion).

---

### Stage 9: Git Commit

Apply the `research` scope from `.claude/context/standards/git-staging-scope.md` — targeted
staging, never a repo-wide add:

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

### Stage 10: Cleanup

Follow `@.claude/context/patterns/skill-postflight-flow.md`'s Stage 9 (cleanup):

```bash
skill_cleanup "$padded_num" "$project_name"
```

---

### Stage 11: Return Brief Summary

```
Research completed for task {N}:
- Found framework documentation and project patterns
- Identified implementation approach with accessibility considerations
- Created report at specs/{NNN}_{SLUG}/reports/MM_{short-slug}.md
- Status updated to [RESEARCHED]
- Changes committed
```

---

## Error Handling

### Input Validation Errors
Return immediately if task not found.

### Metadata File Missing
Keep status as "researching" for resume.

### Git Commit Failure
Non-blocking: Log failure but continue.

---

## Return Format

Brief text summary (NOT JSON).

Example successful return:
```
Research completed for task {N}:
- Found Astro component patterns and Tailwind v4 styling approaches
- Identified accessibility requirements for interactive elements
- Created report at specs/412_add_blog_section/reports/01_blog-section-research.md
- Status updated to [RESEARCHED]
- Changes committed with session sess_1736700000_abc123
```

Example partial return:
```
Research partially completed for task {N}:
- Found local project patterns
- Web search failed due to network error
- Partial report created at specs/412_add_blog_section/reports/01_blog-section-research.md
- Status remains [RESEARCHING] - run /orchestrate 412 --research to continue
```
