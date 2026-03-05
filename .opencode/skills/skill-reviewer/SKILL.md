---
name: skill-reviewer
description: Analyze codebase, identify issues, and create review reports. Invoke for /review command.
allowed-tools: Task, Bash, Edit, Read, Write, Glob, Grep
context: fork
agent: code-reviewer-agent
---

# Reviewer Skill

Thin wrapper that delegates code review to `code-reviewer-agent`.

<context>
  <system_context>OpenCode review skill wrapper.</system_context>
  <task_context>Delegate review and coordinate postflight updates.</task_context>
</context>

<context_injection>
  <file path=".opencode/context/core/formats/return-metadata-file.md" variable="return_metadata" />
  <file path=".opencode/context/core/patterns/postflight-control.md" variable="postflight_control" />
  <file path=".opencode/context/core/patterns/file-metadata-exchange.md" variable="file_metadata" />
</context_injection>

<role>Delegation skill for codebase review workflows.</role>

<task>Validate inputs, delegate review, and update state/artifacts.</task>

<execution>
  <stage id="1" name="LoadContext">
    <action>Read context files defined in <context_injection></action>
  </stage>
  <stage id="2" name="Preflight">
    <action>Validate scope and prepare for delegation using {return_metadata} and {postflight_control}</action>
  </stage>
  <stage id="3" name="CreatePostflightMarker">
    <action>Create .postflight-pending marker file to prevent premature termination</action>
  </stage>
  <stage id="4" name="Delegate">
    <action>Invoke code-reviewer-agent via Task tool with injected context</action>
  </stage>
  <stage id="5" name="ReadMetadata">
    <action>Parse subagent return metadata using {file_metadata}</action>
  </stage>
  <stage id="6" name="UpdateState">
    <action>Update review state and link artifacts</action>
  </stage>
  <stage id="7" name="Commit">
    <action>Commit changes with session ID</action>
  </stage>
  <stage id="8" name="Cleanup">
    <action>Remove postflight marker and metadata files</action>
  </stage>
  <stage id="9" name="Return">
    <action>Return brief text summary to user</action>
  </stage>
</execution>

<validation>Validate metadata file, review report, state updates, and artifact linking.</validation>

<return_format>Brief text summary; metadata file in `specs/reviews/.return-meta.json`.</return_format>

## Trigger Conditions

- /review command invoked
- Scope provided (file, directory, or "all")

## Execution Flow

1. **LoadContext**: Read injected context files.
2. **Preflight**: Validate scope and prepare for delegation.
3. **CreatePostflightMarker**: Create `.postflight-pending` marker file:
   ```bash
   cat > "specs/reviews/.postflight-pending" << EOF
   {
     "session_id": "${session_id}",
     "skill": "skill-reviewer",
     "operation": "review",
     "reason": "Postflight pending: state update, report linking, git commit"
   }
   EOF
   ```
4. **Delegate**: Invoke code-reviewer-agent via Task tool with context.
   - Pass scope and --create-tasks flag
   - Subagent performs codebase analysis
   - Creates review report at `specs/reviews/review-{DATE}.md`
5. **ReadMetadata**: Read `.return-meta.json` from subagent.
   - Extract status, summary, artifacts, metadata
6. **UpdateState**: Update `specs/reviews/state.json`.
   - Add review entry with timestamp
   - Update statistics
   - Link review report artifact
   - If --create-tasks: Update state.json with created task numbers
7. **Commit**: Commit changes.
   ```bash
   git add specs/reviews/
   git commit -m "review: ${scope} analysis
   
   Session: ${session_id}"
   ```
8. **Cleanup**: Remove marker files.
   ```bash
   rm -f specs/reviews/.postflight-pending
   rm -f specs/reviews/.return-meta.json
   ```
9. **Return**: Return brief summary.
   - Report path
   - Issue counts by category
   - Created tasks (if applicable)

## Error Handling

- Invalid scope → Error with guidance
- Missing review state → Initialize with defaults
- Analysis failure → Log warning, partial results preserved
- Git failure → Log warning, continue

## Postflight Marker Pattern

**Purpose**: Prevents premature termination before postflight completes.

**Created**: In stage 3 (before subagent invocation)
**Removed**: In stage 8 (after all operations complete)
**Contains**: Session ID, skill name, operation type, reason

**Benefits**:
- Signals work in progress
- Enables crash recovery
- Prevents partial state updates

---

**Created**: 2026-03-05 as part of OC_135 skill postflight standardization
