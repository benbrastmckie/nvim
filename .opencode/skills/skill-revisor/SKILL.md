---
name: skill-revisor
description: Revise implementation plans or update task descriptions. Invoke for /revise command.
allowed-tools: Task, Bash, Edit, Read, Write
context: fork
---

# Revisor Skill

Thin wrapper that conditionally delegates to planner-agent or task-expander based on plan existence.

<context>
  <system_context>OpenCode revision skill wrapper.</system_context>
  <task_context>Delegate revision with conditional routing and coordinate postflight updates.</task_context>
</context>

<context_injection>
  <file path=".opencode/context/core/formats/return-metadata-file.md" variable="return_metadata" />
  <file path=".opencode/context/core/formats/plan-format.md" variable="plan_format" />
  <file path=".opencode/context/core/patterns/postflight-control.md" variable="postflight_control" />
  <file path=".opencode/context/core/patterns/file-metadata-exchange.md" variable="file_metadata" />
</context_injection>

<role>Delegation skill with conditional routing for revision workflows.</role>

<task>Check for plan, route conditionally, delegate, and update state.</task>

<execution>
  <stage id="1" name="LoadContext">
    <action>Read context files defined in <context_injection></action>
  </stage>
  <stage id="2" name="Preflight">
    <action>Validate task and check for plan existence using {return_metadata} and {postflight_control}</action>
  </stage>
  <stage id="3" name="CreatePostflightMarker">
    <action>Create .postflight-pending marker file to prevent premature termination</action>
  </stage>
  <stage id="4" name="DetermineTarget">
    <action>Check for existing plan to determine routing target</action>
  </stage>
  <stage id="5" name="Delegate">
    <action>Conditionally invoke planner-agent or task-expander via Task tool</action>
  </stage>
  <stage id="6" name="ReadMetadata">
    <action>Parse subagent return metadata using {file_metadata}</action>
  </stage>
  <stage id="7" name="ValidateReturn">
    <action>Validate subagent return format and artifacts</action>
  </stage>
  <stage id="8" name="UpdateState">
    <action>Update state.json and TODO.md</action>
  </stage>
  <stage id="9" name="LinkArtifacts">
    <action>Link new plan or description update artifact</action>
  </stage>
  <stage id="10" name="Commit">
    <action>Commit changes with session ID</action>
  </stage>
  <stage id="11" name="Cleanup">
    <action>Remove postflight marker and metadata files</action>
  </stage>
  <stage id="12" name="Return">
    <action>Return brief text summary to user</action>
  </stage>
</execution>

<validation>Validate metadata, conditional routing, subagent return, state updates, artifact linking.</validation>

<return_format>Brief text summary; metadata file in `specs/{N}_{SLUG}/.return-meta.json`.</return_format>

## Trigger Conditions

- /revise command invoked
- Task number and reason provided

## Execution Flow

1. **LoadContext**: Read injected context files.
2. **Preflight**: Validate task exists and status allows revision.
   - Accept: planned, researched, partial, revised, completed (with reason)
   - Reject: implementing (with guidance), not_started/abandoned (unless --force)
3. **CreatePostflightMarker**: Create marker file:
   ```bash
   cat > "specs/OC_${NNN}_${SLUG}/.postflight-pending" << EOF
   {
     "session_id": "${session_id}",
     "skill": "skill-revisor",
     "task_number": ${task_number},
     "reason": "Postflight pending: state update, artifact linking, git commit"
   }
   EOF
   ```
4. **DetermineTarget**: Check for existing plan.
   - Find latest: `specs/OC_{NNN}_{SLUG}/plans/implementation-{LATEST}.md`
   - Set plan_exists flag
5. **Delegate**: Conditional routing.
   - **If plan exists**: Invoke `planner-agent` with revision context
   - **If no plan**: Invoke `task-expander` with description update context
6. **ReadMetadata**: Read `.return-meta.json` from subagent.
7. **ValidateReturn**: Strict validation.
   - Check all required fields present
   - Validate status enum
   - Verify session_id matches
   - Check artifacts exist on disk
8. **UpdateState**: Update `specs/state.json`.
   - If plan revised: status → "revised"
   - If description updated: status unchanged
9. **LinkArtifacts**: Add to artifacts array.
   - Plan revision: type="plan", path to new version
   - Description update: type="description", summary of changes
10. **Commit**: Commit changes.
11. **Cleanup**: Remove marker files.
12. **Return**: Return summary with operation type and changes.

## Conditional Routing

| Plan Exists | Target Agent | Operation | Result |
|-------------|--------------|-----------|---------|
| Yes | planner-agent | Plan Revision | New plan version created |
| No | task-expander | Description Update | Task description modified |

## Return Validation

**Strict validation required**:
- Status: completed, partial, failed, blocked
- Metadata.session_id must match expected
- Artifacts array must not be empty for completed status
- Each artifact path must exist on disk
- Each artifact must be non-empty

## Error Handling

- Task not found → Error
- Invalid status → Error (or warning with --force)
- Implementation in progress → Warning with /task --sync suggestion
- Return validation failure → Detailed error with specific field

---

**Created**: 2026-03-05 as part of OC_135 skill postflight standardization
