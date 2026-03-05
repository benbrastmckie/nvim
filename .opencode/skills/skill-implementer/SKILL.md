---
name: skill-implementer
description: Execute general implementation tasks following a plan. Invoke for non-Lean implementation work.
allowed-tools: Task, Bash, Edit, Read, Write
context: fork
agent: general-implementation-agent
---

# Implementer Skill

Thin wrapper that delegates implementation to `general-implementation-agent`.

<context>
  <system_context>OpenCode implementation skill wrapper.</system_context>
  <task_context>Delegate implementation and coordinate postflight updates.</task_context>
</context>

<context_injection>
  <file path=".opencode/context/core/formats/return-metadata-file.md" variable="return_metadata" />
  <file path=".opencode/context/core/patterns/postflight-control.md" variable="postflight_control" />
  <file path=".opencode/context/core/patterns/file-metadata-exchange.md" variable="file_metadata" />
  <file path=".opencode/context/core/patterns/jq-escaping-workarounds.md" variable="jq_workarounds" />
  
  **Task Context** (provided at invocation):
  - Task number: `{N}` - The integer task number (e.g., 146)
  - Task display: `OC_{N}` - The formatted task identifier (e.g., OC_146)
  - Project name: `{project_name}` - The task slug from state.json
</context_injection>

<role>Delegation skill for general implementation workflows.</role>

<task>Validate inputs, delegate implementation, and update status/artifacts.</task>

<execution>
  <stage id="1" name="LoadContext">
    <action>Read context files defined in <context_injection></action>
  </stage>
  <stage id="2" name="Preflight">
    <action>Validate status and prepare for delegation using {return_metadata} and {postflight_control}</action>
  </stage>
  <stage id="3" name="Delegate">
    <action>Invoke general-implementation-agent with injected context</action>
  </stage>
  <stage id="4" name="Postflight">
    <action>Update state and link artifacts using {file_metadata} and {jq_workarounds} patterns</action>
  </stage>
  <stage id="5" name="PostflightVerification">
    <action>Verify phase status consistency between plan file and metadata</action>
  </stage>
</execution>

<validation>Validate metadata file, summary artifact, state updates, and phase status consistency.</validation>

<return_format>Brief text summary; metadata file in `specs/{N}_{SLUG}/.return-meta.json`.</return_format>

## Context References

Reference (do not load eagerly):
- Path: `.opencode/context/core/formats/return-metadata-file.md` - Metadata file schema
- Path: `.opencode/context/core/patterns/postflight-control.md` - Marker file protocol
- Path: `.opencode/context/core/patterns/file-metadata-exchange.md` - Metadata file handling
- Path: `.opencode/context/core/patterns/jq-escaping-workarounds.md` - jq workaround patterns
- Path: `.opencode/context/index.md` - Context discovery index

## Execution Flow

1. **LoadContext**: Read injected context files.
2. **Preflight**: Validate task and status using {return_metadata} and {postflight_control}.
   - **Display Task Header**: Print the following header to show which task is being implemented:
     ```
     ╔══════════════════════════════════════════════════════════╗
     ║  Task OC_{N}: {project_name}                             ║
     ║  Action: IMPLEMENTING                                    ║
     ╚══════════════════════════════════════════════════════════╝
     ```
   - Update status to implementing.
   - Create postflight marker file.
3. **Delegate**: Invoke general-implementation-agent via Task tool with injected context.
   - Pass all {variables} from context_injection.
4. **Postflight**: Read metadata file and update state + TODO using {file_metadata} and {jq_workarounds}.
   - Link summary artifact and commit.
   - Clean up marker and metadata files.
5. **PostflightVerification**: Verify phase status consistency.
   - Read plan file and extract phase status markers.
   - Compare phase markers with metadata.phases_completed count.
   - If mismatch detected, update plan file phase statuses to match.
   - Log warning if any corrections were made.

## Phase Verification Details

**Purpose**: Ensure plan.md phase status markers stay synchronized with actual implementation progress.

**Process**:
1. Read the plan file from the path specified in metadata
2. Extract all phase status markers using regex: `\*\*Status\*\*: \[(NOT STARTED|IN PROGRESS|COMPLETED|PARTIAL)\]`
3. Count completed phases vs metadata.phases_completed
4. If counts don't match, update the plan file to correct phase statuses
5. Log the correction in the return summary

**Recovery Logic**:
- If metadata.phases_completed > plan [COMPLETED] phases: Update plan to mark additional phases as [COMPLETED]
- If metadata.phases_completed < plan [COMPLETED] phases: Log warning but don't downgrade (completed is final)
- Always prioritize the higher completion state

## Validation Checklist

- [ ] Metadata file exists and is valid JSON
- [ ] Summary artifact created at correct path
- [ ] state.json updated with correct status
- [ ] TODO.md updated with status and summary link
- [ ] Phase status markers in plan file match metadata.phases_completed

## Trigger Conditions

- Task language is general, meta, markdown
- /implement command invoked
