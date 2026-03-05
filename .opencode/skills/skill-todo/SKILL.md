---
name: skill-todo
description: Archive completed/abandoned tasks and clean up orphaned directories. Invoke for /todo command.
allowed-tools: Task, Bash, Edit, Read, Write, Glob
context: fork
agent: task-archive-agent
---

# Todo Skill

Thin wrapper that delegates task archiving to `task-archive-agent`.

<context>
  <system_context>OpenCode task archiving skill wrapper.</system_context>
  <task_context>Delegate archiving and coordinate postflight updates.</task_context>
</context>

<context_injection>
  <file path=".opencode/context/core/formats/return-metadata-file.md" variable="return_metadata" />
  <file path=".opencode/context/core/patterns/postflight-control.md" variable="postflight_control" />
  <file path=".opencode/context/core/patterns/file-metadata-exchange.md" variable="file_metadata" />
</context_injection>

<role>Delegation skill for task archiving workflows.</role>

<task>Validate inputs, delegate archiving, and update state/TODO.</task>

<execution>
  <stage id="1" name="LoadContext">
    <action>Read context files defined in <context_injection></action>
  </stage>
  <stage id="2" name="Preflight">
    <action>Validate state.json and prepare for delegation using {return_metadata} and {postflight_control}</action>
  </stage>
  <stage id="3" name="CreatePostflightMarker">
    <action>Create .postflight-pending marker file to prevent premature termination</action>
  </stage>
  <stage id="4" name="Delegate">
    <action>Invoke task-archive-agent via Task tool with injected context</action>
  </stage>
  <stage id="5" name="ReadMetadata">
    <action>Parse subagent return metadata using {file_metadata}</action>
  </stage>
  <stage id="6" name="UpdateState">
    <action>Update state.json and TODO.md with archived tasks</action>
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

<validation>Validate metadata, archived tasks, state updates, and TODO updates.</validation>

<return_format>Brief text summary; metadata file in `specs/.return-meta.json`.</return_format>

## Trigger Conditions

- /todo command invoked
- --dry-run flag optional

## Execution Flow

1. **LoadContext**: Read injected context files.
2. **Preflight**: Validate state.json exists.
   - Check for archivable tasks (completed/abandoned)
3. **CreatePostflightMarker**: Create marker file:
   ```bash
   cat > "specs/.postflight-pending" << EOF
   {
     "session_id": "${session_id}",
     "skill": "skill-todo",
     "operation": "archive",
     "reason": "Postflight pending: state update, TODO update, git commit"
   }
   EOF
   ```
4. **Delegate**: Invoke task-archive-agent via Task tool.
   - Pass dry_run flag
   - Subagent scans for archivable tasks and orphaned directories
5. **ReadMetadata**: Read `.return-meta.json` from subagent.
6. **UpdateState**:
   - Update `specs/state.json` (move to completed_projects)
   - Update `specs/TODO.md` (mark entries archived)
   - Calculate repository health metrics
7. **Commit**: Commit changes (if not dry_run).
8. **Cleanup**: Remove marker files.
9. **Return**: Return summary with archive counts and health metrics.

## Archiving Process

**Archivable Tasks**:
- Status = "completed" or "abandoned"
- Cross-referenced with TODO.md

**Orphaned Directories**:
- In specs/ but not in state.json
- In specs/archive/ but not tracked

**Operations**:
- Move directories to archive
- Update state.json
- Update TODO.md
- Calculate metrics

## Error Handling

- Missing state.json → Error with /meta suggestion
- No archivable tasks → Inform user
- Permission errors → Error with sudo suggestion
- Git failures → Log warning, continue

---

**Created**: 2026-03-05 as part of OC_135 skill postflight standardization
