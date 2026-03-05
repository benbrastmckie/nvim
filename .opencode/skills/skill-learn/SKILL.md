---
name: skill-learn
description: Scan files for FIX:/NOTE:/TODO: tags and create tasks. Invoke for /learn command.
allowed-tools: Task, Bash, Edit, Read, Write
context: fork
agent: tag-scan-agent
---

# Learn Skill

Thin wrapper that delegates tag scanning to `tag-scan-agent`.

<context>
  <system_context>OpenCode tag scanning and task creation.</system_context>
  <task_context>Delegate scanning and coordinate task creation.</task_context>
</context>

<context_injection>
  <file path=".opencode/context/core/formats/return-metadata-file.md" variable="return_metadata" />
  <file path=".opencode/context/core/patterns/postflight-control.md" variable="postflight_control" />
  <file path=".opencode/context/core/patterns/file-metadata-exchange.md" variable="file_metadata" />
  <file path="specs/TODO.md" variable="todo_file" />
  <file path="specs/state.json" variable="state_file" />
</context_injection>

<role>Delegation skill for tag discovery and task creation.</role>

<task>Validate paths, delegate scanning, and coordinate task creation.</task>

<execution>
  <stage id="1" name="LoadContext">
    <action>Read context files defined in <context_injection></action>
  </stage>
  <stage id="2" name="Preflight">
    <action>Validate paths and prepare for delegation using {return_metadata} and {postflight_control}</action>
  </stage>
  <stage id="3" name="CreatePostflightMarker">
    <action>Create .postflight-pending marker file to prevent premature termination</action>
  </stage>
  <stage id="4" name="Delegate">
    <action>Invoke tag-scan-agent via Task tool with injected context</action>
  </stage>
  <stage id="5" name="ReadMetadata">
    <action>Parse subagent return metadata using {file_metadata}</action>
  </stage>
  <stage id="6" name="InteractiveSelection">
    <action>Present findings and let user select which to convert to tasks</action>
  </stage>
  <stage id="7" name="CreateTasks">
    <action>Create tasks in {state_file} and {todo_file} for selected tags</action>
  </stage>
  <stage id="8" name="UpdateState">
    <action>Update state.json and TODO.md with new tasks</action>
  </stage>
  <stage id="9" name="Commit">
    <action>Commit changes with session ID</action>
  </stage>
  <stage id="10" name="Cleanup">
    <action>Remove postflight marker and metadata files</action>
  </stage>
  <stage id="11" name="Return">
    <action>Return brief text summary to user</action>
  </stage>
</execution>

<validation>Validate tag parsing, interactive selection, and task creation outputs.</validation>

<return_format>Brief text summary; metadata file in `specs/.return-meta.json`.</return_format>

## Trigger Conditions

- /learn command invoked
- Optional paths provided (default: entire project)

## Execution Flow

1. **LoadContext**: Read injected context files.
2. **Preflight**: Validate paths (if provided) or use entire project.
3. **CreatePostflightMarker**: Create marker file:
   ```bash
   cat > "specs/.postflight-pending" << EOF
   {
     "session_id": "${session_id}",
     "skill": "skill-learn",
     "operation": "tag_scan",
     "reason": "Postflight pending: task creation, state update, git commit"
   }
   EOF
   ```
4. **Delegate**: Invoke tag-scan-agent via Task tool.
   - Pass paths to scan
   - Subagent scans for FIX:/NOTE:/TODO: tags
   - Groups tags by type and file
   - Removes duplicates
5. **ReadMetadata**: Read `.return-meta.json` from subagent.
6. **InteractiveSelection**: Present findings.
   - Display tag counts by type
   - Show examples from each file
   - Use AskUserQuestion with multiSelect
   - Allow user to select which tags to convert
7. **CreateTasks**: For selected items.
   - Group related items into single tasks
   - Create tasks using /task command
8. **UpdateState**: Update `specs/state.json` and `specs/TODO.md`.
   - Add new task entries
   - Update next_project_number if needed
9. **Commit**: Commit changes.
10. **Cleanup**: Remove marker files.
11. **Return**: Return summary with created tasks.

## Tag Types

**FIX:** - Issues needing fixes
- Code problems
- Bugs identified
- Workarounds needed

**NOTE:** - Important notes/documentation
- Design decisions
- Context information
- Important caveats

**TODO:** - Tasks to complete
- Missing features
- Refactoring needed
- Documentation gaps

## Interactive Flow

1. Scan notification displayed
2. Tag summary (counts by type)
3. AskUserQuestion multiSelect dialog
4. User confirmation
5. Task creation progress
6. Completion summary

## Error Handling

- Invalid paths → Error with guidance
- No tags found → Inform user, no error
- User cancels selection → Exit gracefully
- Task creation failure → Log error, continue with others
- Git failures → Log warning, continue

---

**Updated**: 2026-03-05 as part of OC_135 skill postflight standardization
