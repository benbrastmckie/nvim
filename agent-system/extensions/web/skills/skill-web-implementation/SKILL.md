---
name: skill-web-implementation
description: Implement web (Astro/Tailwind/TypeScript) changes following a plan. Invoke for web-language implementation tasks.
allowed-tools: Agent, Bash, Edit, Read, Write
---

# Web Implementation Skill

Thin wrapper that delegates web (Astro/Tailwind/TypeScript) implementation to `web-implementation-agent` subagent.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns,
this skill handles all postflight operations (status update, artifact linking, git commit) before returning.
This eliminates the "continue" prompt issue between skill return and orchestrator.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/project/web/README.md` - Web context overview
- Path: `.claude/context/project/web/domain/astro-framework.md` - Astro reference
- Path: `.claude/context/project/web/domain/tailwind-v4.md` - Tailwind v4 reference

Note: This skill is a thin wrapper with internal postflight. Context is loaded by the delegated agent.

## Trigger Conditions

This skill activates when:
- Task type is "web"
- An implement-phase dispatch targets a web (Astro/Tailwind/TypeScript) task
- Pages, components, layouts, or web styling needs to be created or modified

---

## Execution Flow

**Stage numbering note**: this file previously used a `0. Preflight` / `1-4.` / `5.` / `6.`
layout, not the core Stage-N skeleton the other converted skills use. Renumbered here to match.

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- Task status must allow implementation (planned, implementing, partial)

```bash
# Lookup task (skill_validate_input exits 1 with its own not-found/terminal-state message;
# "terminal state" covers completed -- and also abandoned/expanded, a stricter but consistent
# superset of the prior completed-only check -- so the separate completed check below is
# removed as dead code, unreachable once skill_validate_input has already exited)
source .claude/scripts/skill-base.sh
skill_validate_input "$task_number"
task_data="$TASK_DATA"

# Extract fields
task_type="$TASK_TYPE"
status="$TASK_STATUS"
project_name="$PROJECT_NAME"
description="$DESCRIPTION"

# Validate language
if [ "$task_type" != "web" ]; then
  return error "Task $task_number is not a web task"
fi
```

---

### Stage 2 + Stage 3: Preflight Status Update and Postflight Marker

Source `skill-base.sh` once, then follow `@.claude/context/patterns/skill-preflight-flow.md` in
full for Stage 2 (preflight status update) and Stage 3 (marker creation):

```bash
source .claude/scripts/skill-base.sh
padded_num=$(printf "%03d" "$task_number")
skill_name="skill-web-implementation"
operation="implement"
```

**Routing fix**: this call replaces a hand-rolled raw-`jq` status write with
`update-task-status.sh preflight` (via `skill_preflight_update`), and the raw
`cat > .../.postflight-pending` heredoc with `skill_create_postflight_marker`.

**Update plan file** (if exists): Update the Status field in plan metadata (not covered by the
shared block — this skill's own domain step):
```bash
plan_file=$(ls -1 "specs/${padded_num}_${project_name}/plans/"*.md 2>/dev/null | sort -V | tail -1)
if [ -n "$plan_file" ] && [ -f "$plan_file" ]; then
    sed -i "s/^\- \*\*Status\*\*: \[.*\]$/- **Status**: [IMPLEMENTING]/" "$plan_file"
fi
```

---

### Stage 4a: Memory Retrieval and Literature Detection

**Skip memory retrieval if**: `clean_flag` is true (from `--clean`).

```bash
if [ "$clean_flag" != "true" ]; then
  memory_context=$(bash .claude/scripts/sapience-retrieve.sh "$description" "$task_type" "" 2>/dev/null) || memory_context=""
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
  "delegation_path": ["orchestrator", "implement", "skill-web-implementation"],
  "timeout": 3600,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "web"
  },
  "plan_path": "specs/{NNN}_{SLUG}/plans/MM_{short-slug}.md",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

If `memory_context` and/or `lit_context` from Stage 4a are non-empty, include them in the prompt
(memory context first, then literature briefing). Do NOT inject an empty block for either.

---

### Stage 5: Invoke Subagent

**CRITICAL**: You MUST use the **Agent** tool to spawn the subagent.

The `agent` field in this skill's frontmatter specifies the target: `web-implementation-agent`

**Required Tool Invocation**:
```
Tool: Agent (NOT Skill, NOT Plan)
Parameters:
  - subagent_type: "web-implementation-agent"
  - prompt: [Include task_context, delegation_context, plan_path]
  - description: "Execute web implementation for task {N}"
```

**DO NOT** use `Skill(web-implementation-agent)` - this will FAIL.
Agents live in `.claude/agents/`, not `.claude/skills/`.
The Skill tool can only invoke skills from `.claude/skills/`.

The subagent will:
- Load web-specific context files (Astro framework, Tailwind v4, style guide, etc.)
- Create/modify .astro, .ts, .tsx, .css files
- Execute build verification (pnpm build, pnpm check)
- Handle TypeScript and Astro errors
- Create implementation summary
- Write metadata to `specs/{NNN}_{SLUG}/.return-meta.json`
- Return a brief text summary (NOT JSON)

---

### Stage 5a: Validate Subagent Return Format

**IMPORTANT**: Check if subagent accidentally returned JSON to console (v1 pattern) instead of writing to file (v2 pattern).

If the subagent's text return parses as valid JSON, log a warning:

```bash
# Check if subagent return looks like JSON (starts with { and is valid JSON)
subagent_return="$SUBAGENT_TEXT_RETURN"
if echo "$subagent_return" | grep -q '^{' && echo "$subagent_return" | jq empty 2>/dev/null; then
    echo "WARNING: Subagent returned JSON to console instead of writing metadata file."
    echo "This indicates the agent may have outdated instructions (v1 pattern instead of v2)."
    echo "The skill will continue by reading the metadata file, but this should be fixed."
fi
```

This validation:
- Does NOT fail the operation (continues to read metadata file)
- Logs a warning for debugging
- Indicates the subagent instructions need updating
- Allows graceful handling of mixed v1/v2 agents

---

### Stage 5b: Self-Execution Fallback

Follow `@.claude/context/patterns/skill-self-execution-fallback.md` in full. This skill's success
status value for that block's write obligation is `"implemented"`.

---

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 5b). Do NOT skip these stages for any reason.

### Stage 6: Parse Subagent Return (Read Metadata File)

Read the metadata file:

```bash
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_type=$(jq -r '.artifacts[0].type // "summary"' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
    phases_completed=$(jq -r '.metadata.phases_completed // 0' "$metadata_file")
    phases_total=$(jq -r '.metadata.phases_total // 0' "$metadata_file")
    memory_candidates=$(jq -c '.memory_candidates // []' "$metadata_file")

    # Extract completion_data fields (if present)
    completion_summary=$(jq -r '.completion_data.completion_summary // ""' "$metadata_file")
    roadmap_items=$(jq -c '.completion_data.roadmap_items // []' "$metadata_file")
else
    echo "Error: Invalid or missing metadata file"
    status="failed"
fi
```

Validate the metadata contains required fields:
- Status is one of: implemented, partial, failed, blocked
- Summary is non-empty and <100 tokens
- Artifacts array present (source files, summary)
- Metadata contains session_id, agent_type, delegation info

---

### Stage 7, 7a, 8, 8a: Postflight Status, Memory Candidates, Artifact Linking, Notify

**If `status == "implemented"`**: follow `@.claude/context/patterns/skill-postflight-flow.md` for
Stage 7 (postflight status update), Stage 7a (memory-candidate propagation), Stage 8 (artifact
linking), and Stage 8a (TTS notify):

```bash
field_name='**Summary**'
next_field='**Description**'
skill_postflight_update "$task_number" "$operation" "$session_id" "$status"
skill_propagate_completion_summary "$task_number" "$completion_summary" "$roadmap_items" "$task_type"
skill_propagate_memory_candidates "$task_number" "$memory_candidates" "$session_id"
skill_link_artifacts "$task_number" "$artifact_path" "$artifact_type" "$artifact_summary" \
  "$field_name" "$next_field" "$session_id"
skill_lifecycle_notify "$status"
```

**Update plan file** (if exists): Update the Status field to `[COMPLETED]` (not covered by the
shared block):
```bash
plan_file=$(ls -1 "specs/${padded_num}_${project_name}/plans/"*.md 2>/dev/null | sort -V | tail -1)
if [ -n "$plan_file" ] && [ -f "$plan_file" ]; then
    sed -i "s/^\- \*\*Status\*\*: \[.*\]$/- **Status**: [COMPLETED]/" "$plan_file"
fi
```

**If `status == "partial"`**:

Update state.json with resume point (keep status as "implementing") — the
`skill_postflight_update` call above already no-ops for a non-success status, so the resume-point
write stays a direct `state-write.sh` call:
```bash
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    last_updated: $ts,
    resume_phase: ($phase | tonumber + 1)
  }' \
  --session-id "$session_id" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg phase "$completed_phase"
```

TODO.md stays as `[IMPLEMENTING]`.

**Update plan file** (if exists): Update the Status field to `[PARTIAL]`:
```bash
plan_file=$(ls -1 "specs/${padded_num}_${project_name}/plans/"*.md 2>/dev/null | sort -V | tail -1)
if [ -n "$plan_file" ] && [ -f "$plan_file" ]; then
    sed -i "s/^\- \*\*Status\*\*: \[.*\]$/- **Status**: [PARTIAL]/" "$plan_file"
fi
```

**On failed**: Do NOT run postflight linking. Keep status as "implementing" for retry (the shared
`skill_postflight_update` call no-ops automatically). Do not update plan file (leave as
`[IMPLEMENTING]` for retry).

---

### Stage 9: Git Commit

Apply the `implement` scope from `.claude/context/standards/git-staging-scope.md` — targeted
staging, never a repo-wide add — then commit with session ID:

```bash
stage_paths=("specs/${padded_num}_${project_name}/" "specs/TODO.md" "specs/state.json")
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"
while IFS= read -r f; do
  [ -n "$f" ] && stage_paths+=("$f")
done < <(jq -r '.modified_files[]? // empty' "$metadata_file" 2>/dev/null)
bash .claude/scripts/git-commit-scoped.sh \
  --message "task ${task_number}: complete implementation" \
  --session "${session_id}" \
  --honest-index-rows "${task_number}" \
  -- "${stage_paths[@]}"
```

---

### Stage 10: Cleanup

Follow `@.claude/context/patterns/skill-postflight-flow.md`'s Stage 9 (cleanup):

```bash
skill_cleanup "$padded_num" "$project_name"
```

---

### Stage 11: Return Brief Summary

Return a brief text summary (NOT JSON) describing the implementation results.

---

## Return Format

This skill returns a **brief text summary** (NOT JSON). The JSON metadata is written to the file and processed internally.

Example successful return:
```
Web implementation completed for task {N}:
- All 3 phases executed, build passes cleanly
- Created about page with hero section and team grid
- Created summary at specs/10_create_about_page/summaries/01_web-feature-summary.md
- Status updated to [COMPLETED]
- Changes committed with session sess_1770319142_a293c5
```

Example partial return:
```
Web implementation partially completed for task {N}:
- Phases 1-2 of 3 executed
- Phase 3 blocked: TypeScript error in ContactForm component
- Partial summary at specs/10_create_about_page/summaries/01_web-feature-summary.md
- Status remains [IMPLEMENTING] - run /orchestrate 10 --implement to resume
```

---

## Error Handling

### Input Validation Errors
Return immediately with failed status if task not found, wrong language, or status invalid.

### Subagent Errors
Pass through the subagent's error return verbatim.

### Timeout
Return partial status if subagent times out (default 3600s).

---

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Edit .astro/.tsx/.ts files** - All web implementation is done by agent
2. **Run pnpm build/check** - Build verification is done by agent
3. **Analyze or grep source** - Analysis is agent work
4. **Write summary/reports** - Artifact creation is agent work

See `context/standards/postflight-tool-restrictions.md` § "MUST NOT Section Template"
for the full PROHIBITION clause (the lead skill must not continue, complete, or "fill in" a
partial/failed subagent's work; report the status and let the user re-run the implement-phase dispatch) and the
postflight-phase allowed-operations list (read metadata, state.json/TODO.md updates, artifact
linking, git commit, cleanup).
