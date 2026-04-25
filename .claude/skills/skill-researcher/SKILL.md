---
name: skill-researcher
description: Conduct general research using web search, documentation, and codebase exploration. Invoke for general research tasks.
allowed-tools: Task, Bash, Edit, Read, Write
# Original context (now loaded by subagent):
#   - .claude/context/formats/report-format.md
# Original tools (now used by subagent):
#   - Read, Write, Edit, Glob, Grep, WebSearch, WebFetch
---

# Researcher Skill

Thin wrapper that delegates general research to `general-research-agent` subagent.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns,
this skill handles all postflight operations (status update, artifact linking, git commit) before returning.
This eliminates the "continue" prompt issue between skill return and orchestrator.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/formats/return-metadata-file.md` - Metadata file schema
- Path: `.claude/context/patterns/postflight-control.md` - Marker file protocol
- Path: `.claude/context/patterns/file-metadata-exchange.md` - File I/O helpers
- Path: `.claude/context/patterns/jq-escaping-workarounds.md` - jq escaping patterns (Issue #1132)

Note: This skill is a thin wrapper with internal postflight. Context is loaded by the delegated agent.

## Trigger Conditions

This skill activates when:
- Task type is "general", "meta", "markdown", "latex", or "typst"
- Research is needed for implementation planning
- Documentation or external resources need to be gathered

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

### Stage 2: Preflight Status Update

Update task status to "researching" BEFORE invoking subagent.

```bash
.claude/scripts/update-task-status.sh preflight "$task_number" research "$session_id"
```

This atomically updates state.json (status, timestamps, session_id), TODO.md task entry, and TODO.md Task Order section. If the script exits non-zero, abort and keep current status.

---

### Stage 3: Create Postflight Marker

Create the marker file to prevent premature termination:

```bash
# Ensure task directory exists
padded_num=$(printf "%03d" "$task_number")
mkdir -p "specs/${padded_num}_${project_name}"

cat > "specs/${padded_num}_${project_name}/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-researcher",
  "task_number": ${task_number},
  "operation": "research",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "stop_hook_active": false
}
EOF
```

---

### Stage 3a: Read Artifact Number

Read `next_artifact_number` from state.json (or fall back to directory scanning for legacy tasks):

```bash
# Read next_artifact_number from state.json
artifact_number=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .next_artifact_number // 1' \
  specs/state.json)

# Fallback for legacy tasks: count existing artifacts
if [ "$artifact_number" = "null" ] || [ -z "$artifact_number" ]; then
  padded_num=$(printf "%03d" "$task_number")
  count=$(ls "specs/${padded_num}_${project_name}/reports/"*[0-9][0-9]*.md 2>/dev/null | wc -l)
  artifact_number=$((count + 1))
fi

artifact_padded=$(printf "%02d" "$artifact_number")
```

---

### Stage 4a: Memory Retrieval (Auto)

Retrieve relevant memories from the memory system to inject into the delegation context.

**Skip if**: `clean_flag` is true in the delegation context (from `--clean` command flag).

```bash
# Check clean_flag
if [ "$clean_flag" != "true" ]; then
  memory_context=$(bash .claude/scripts/memory-retrieve.sh "$description" "$task_type" "$focus_prompt" 2>/dev/null) || memory_context=""
fi

# memory_context will be empty string if:
# - clean_flag is true (skipped)
# - memory-index.json missing or empty
# - no keywords matched any entries
# - script exited with error
```

If `memory_context` is non-empty, it will be injected into the Stage 5 prompt alongside the format specification from Stage 4b. If empty, no memory block is injected.

---

### Stage 4c: Roadmap Consultation (Auto)

Read the project roadmap to inject strategic context into the research agent prompt.

**Skip if**: `clean_flag` is true in the delegation context (from `--clean` command flag).

```bash
# Check clean_flag (same gate as memory retrieval)
roadmap_context=""
if [ "$clean_flag" != "true" ]; then
  roadmap_file="specs/ROADMAP.md"
  if [ -f "$roadmap_file" ]; then
    roadmap_context=$(cat "$roadmap_file")
  fi
fi

# roadmap_context will be empty string if:
# - clean_flag is true (skipped)
# - specs/ROADMAP.md does not exist
# - file is empty
```

If `roadmap_context` is non-empty, it will be injected into the Stage 5 prompt as a tagged block. If empty, no roadmap block is injected.

**Note**: If ROADMAP.md grows beyond ~100 lines, consider adding a size-check threshold and summarizing before injection.

---

### Stage 4: Prepare Delegation Context

Prepare delegation context for the subagent:

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "research", "skill-researcher"],
  "timeout": 3600,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "{task_type}"
  },
  "artifact_number": "{artifact_number from Stage 3a}",
  "focus_prompt": "{optional focus}",
  "effort_flag": "{effort_flag from command, null if not set}",
  "model_flag": "{model_flag from command, null if not set}",
  "roadmap_path": "specs/ROADMAP.md",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

**Note**: The `artifact_number` field tells the agent which sequence number to use for artifact naming (e.g., `01`, `02`).

**Model/Effort Flags**: If `model_flag` is set (haiku, sonnet, opus), pass it as the `model` parameter on the Task tool to override the agent's frontmatter default. If `effort_flag` is set (fast, hard), include it as prompt context for reasoning depth guidance.

---

### Stage 4b: Read and Inject Format Specification

Read the report format file and prepare it for injection into the subagent prompt. This ensures the subagent always has the full format specification in its context, regardless of whether it reads the file itself.

```bash
format_content=$(cat .claude/context/formats/report-format.md)
```

The format content will be included as a delimited section in the Stage 5 prompt (see below).

---

### Stage 5: Invoke Subagent

**CRITICAL**: You MUST use the **Task** tool to spawn the subagent.

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "general-research-agent"
  - prompt: [Include task_context, delegation_context, focus_prompt, metadata_file_path,
             AND the format specification from Stage 4b as shown below]
  - description: "Execute research for task {N}"
```

**Format Injection**: Include the format specification from Stage 4b in the prompt as a clearly-delimited section:

```
<artifact-format-specification>
## CRITICAL: Report Format Requirements

You MUST follow this format specification exactly when writing the research report.
Non-compliance will be caught by postflight validation.

{format_content from Stage 4b}
</artifact-format-specification>
```

Place this section AFTER the delegation context JSON and BEFORE any other instructions.

**Memory Context Injection**: If `memory_context` from Stage 4a is non-empty, include it in the prompt as a separate block:

```
{memory_context from Stage 4a -- already wrapped in <memory-context> tags}
```

Place the memory context block AFTER the format specification and BEFORE the roadmap context block. Do NOT inject an empty `<memory-context>` block when no memories were retrieved.

**Roadmap Context Injection**: If `roadmap_context` from Stage 4c is non-empty, include it in the prompt as a separate block:

```
<roadmap-context>
## Project Roadmap (auto-injected, read-only)

{roadmap_context from Stage 4c}
</roadmap-context>
```

Place the roadmap context block AFTER the `<memory-context>` block and BEFORE the task-specific instructions. Do NOT inject an empty `<roadmap-context>` block when no roadmap was read.

**DO NOT** use `Skill(general-research-agent)` - this will FAIL.

The subagent will:
- Search codebase for related patterns
- Search web for documentation and examples
- Analyze findings and synthesize recommendations
- Create research report in `specs/{NNN}_{SLUG}/reports/`
- Write metadata to `specs/{NNN}_{SLUG}/.return-meta.json`
- Return a brief text summary (NOT JSON)

---

### Stage 5b: Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Task tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding to postflight. Use the schema from
`return-metadata-file.md` with status value `"researched"` and the appropriate artifact information.

If you DID use the Task tool (Stage 5), skip this stage -- the subagent already wrote the metadata.

---

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent (Stage 5) or inline (Stage 5b). Do NOT skip these stages for any reason.

### Stage 6: Parse Subagent Return (Read Metadata File)

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
    echo "Error: Invalid or missing metadata file"
    status="failed"
fi
```

---

### Stage 6a: Validate Artifact Content

If subagent status is "researched" and `artifact_path` is non-empty, validate the report artifact against format requirements. This is **non-blocking** -- warnings are logged but do not prevent postflight from completing.

```bash
if [ "$status" = "researched" ] && [ -n "$artifact_path" ] && [ -f "$artifact_path" ]; then
    echo "Validating report artifact..."
    if ! bash .claude/scripts/validate-artifact.sh "$artifact_path" report --fix; then
        echo "WARNING: Report artifact has format issues (non-blocking). Review output above."
    fi
fi
```

**Note**: The `--fix` flag attempts auto-repair of missing metadata fields. Validation failures are logged but do not block status update or git commit.

---

### Stage 7: Update Task Status (Postflight)

If status is "researched", update status and increment artifact number:

```bash
# Step 1: Update status (state.json, TODO.md task entry, TODO.md Task Order)
if [ "$status" = "researched" ]; then
  .claude/scripts/update-task-status.sh postflight "$task_number" research "$session_id"
fi

# Step 2: Increment next_artifact_number (research advances the sequence)
jq '(.active_projects[] | select(.project_number == '$task_number')).next_artifact_number =
    (((.active_projects[] | select(.project_number == '$task_number')).next_artifact_number // 1) + 1)' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

**Note**: Research is the only operation that increments `next_artifact_number`. Plan and implement use `(current - 1)` to stay in the same "round".

**On partial/failed**: Keep status as "researching" for resume (do not call the script).

---

### Stage 7a: Propagate Memory Candidates

If the agent emitted memory candidates, append them to the task's state.json entry using append semantics (merge with any existing candidates from prior operations).

```bash
if [ "$memory_candidates" != "[]" ] && [ -n "$memory_candidates" ]; then
    # Append new candidates to existing array (append semantics, not overwrite)
    jq --argjson new_candidates "$memory_candidates" \
      '(.active_projects[] | select(.project_number == '$task_number')).memory_candidates =
        ((.active_projects[] | select(.project_number == '$task_number')).memory_candidates // []) + $new_candidates' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

**Note**: Uses `// []` fallback so this works whether or not the task already has candidates. Append semantics ensure research and implementation candidates coexist.

---

### Stage 8: Link Artifacts

Add artifact to state.json with summary.

**IMPORTANT**: Use two-step jq pattern to avoid Issue #1132 escaping bug. See `jq-escaping-workarounds.md`.

```bash
if [ -n "$artifact_path" ]; then
    # Step 1: Filter out existing research artifacts (use "| not" pattern to avoid != escaping - Issue #1132)
    jq '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
        [(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "research" | not)]' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

    # Step 2: Add new research artifact
    jq --arg path "$artifact_path" \
       --arg type "$artifact_type" \
       --arg summary "$artifact_summary" \
      '(.active_projects[] | select(.project_number == '$task_number')).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

**Link artifact in TODO.md**: Use the `link-artifact-todo.sh` script (REQUIRED -- do NOT manually edit artifact links in TODO.md):

```bash
bash .claude/scripts/link-artifact-todo.sh $task_number '**Research**' '**Plan**' "$artifact_path"
```

The script produces bracket-only `[path]` format. Never use markdown `[name](path)` format for artifact links. If the script exits non-zero, log a warning but continue (linking errors are non-blocking).

---

### Stage 9: Cleanup

Remove marker and metadata files:

```bash
rm -f "specs/${padded_num}_${project_name}/.postflight-pending"
rm -f "specs/${padded_num}_${project_name}/.postflight-loop-guard"
rm -f "specs/${padded_num}_${project_name}/.return-meta.json"
```

---

### Stage 10: Return Brief Summary

Return a brief text summary (NOT JSON). Example:

```
Research completed for task {N}:
- Found {count} relevant patterns and resources
- Identified implementation approach: {approach}
- Created report at specs/{NNN}_{SLUG}/reports/MM_{short-slug}.md
- Status updated to [RESEARCHED]
```

---

## Error Handling

### Input Validation Errors
Return immediately with error message if task not found.

### Metadata File Missing
If subagent didn't write metadata file:
1. Keep status as "researching"
2. Do not cleanup postflight marker
3. Report error to user

### Subagent Timeout
Return partial status if subagent times out (default 3600s).
Keep status as "researching" for resume.

---

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Edit source files** - All research work is done by agent
2. **Run build/test commands** - Verification is done by agent
3. **Use MCP/WebSearch tools** - Research tools are for agent use only
4. **Analyze or grep source** - Analysis is agent work
5. **Write reports** - Artifact creation is agent work

The postflight phase is LIMITED TO:
- Reading agent metadata file
- Calling `update-task-status.sh` for status updates (state.json + TODO.md)
- Incrementing `next_artifact_number` via jq
- Linking artifacts in state.json
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md

---

## Return Format

This skill returns a **brief text summary** (NOT JSON). The JSON metadata is written to the file and processed internally.

Example successful return:
```
Research completed for task 412:
- Found 8 relevant patterns for implementation
- Identified lazy context loading and skill-to-agent mapping patterns
- Created report at specs/412_general_research/reports/MM_{short-slug}.md
- Status updated to [RESEARCHED]
```

Example partial return:
```
Research partially completed for task 412:
- Found 4 codebase patterns
- Web search failed due to network error
- Partial report created at specs/412_general_research/reports/MM_{short-slug}.md
- Status remains [RESEARCHING] - run /research 412 to continue
```
