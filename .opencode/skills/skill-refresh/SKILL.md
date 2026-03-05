---
name: skill-refresh
description: Manage orphaned processes and project file cleanup. Invoke for /refresh command.
allowed-tools: Task, Bash, Edit, Read, Write
context: fork
agent: cleanup-agent
---

# Refresh Skill

Thin wrapper that delegates cleanup operations to `cleanup-agent`.

<context>
  <system_context>OpenCode cleanup and session maintenance.</system_context>
  <task_context>Delegate cleanup and coordinate postflight updates.</task_context>
</context>

<context_injection>
  <file path=".opencode/context/core/formats/return-metadata-file.md" variable="return_metadata" />
  <file path=".opencode/context/core/patterns/postflight-control.md" variable="postflight_control" />
  <file path=".opencode/context/core/patterns/file-metadata-exchange.md" variable="file_metadata" />
</context_injection>

<role>Delegation skill for cleanup workflows.</role>

<task>Validate inputs, delegate cleanup, and report results.</task>

<execution>
  <stage id="1" name="LoadContext">
    <action>Read context files defined in <context_injection></action>
  </stage>
  <stage id="2" name="Preflight">
    <action>Validate ~/.opencode/ exists and prepare for delegation using {return_metadata} and {postflight_control}</action>
  </stage>
  <stage id="3" name="CreatePostflightMarker">
    <action>Create .postflight-pending marker file to prevent premature termination</action>
  </stage>
  <stage id="4" name="Delegate">
    <action>Invoke cleanup-agent via Task tool with injected context</action>
  </stage>
  <stage id="5" name="ReadMetadata">
    <action>Parse subagent return metadata using {file_metadata}</action>
  </stage>
  <stage id="6" name="UpdateState">
    <action>Record cleanup statistics</action>
  </stage>
  <stage id="7" name="Commit">
    <action>Commit changes with session ID if cleanup performed</action>
  </stage>
  <stage id="8" name="Cleanup">
    <action>Remove postflight marker and metadata files</action>
  </stage>
  <stage id="9" name="Return">
    <action>Return brief text summary to user</action>
  </stage>
</execution>

<validation>Validate metadata, cleanup results, and statistics.</validation>

<return_format>Brief text summary; metadata file in `~/.opencode/.return-meta.json`.</return_format>

## Trigger Conditions

- /refresh command invoked
- --dry-run and/or --force flags optional

## Execution Flow

1. **LoadContext**: Read injected context files.
2. **Preflight**: Validate ~/.opencode/ directory exists.
   - Check for orphaned processes
   - Check for temp directories needing cleanup
3. **CreatePostflightMarker**: Create marker file:
   ```bash
   cat > "~/.opencode/.postflight-pending" << EOF
   {
     "session_id": "${session_id}",
     "skill": "skill-refresh",
     "operation": "cleanup",
     "reason": "Postflight pending: cleanup completion, statistics recording"
   }
   EOF
   ```
4. **Delegate**: Invoke cleanup-agent via Task tool.
   - Pass dry_run and force flags
   - If not force: Agent will request confirmation
   - Subagent performs process termination and directory cleanup
5. **ReadMetadata**: Read `.return-meta.json` from subagent.
6. **UpdateState**: Record cleanup statistics.
   - Processes terminated count
   - Files deleted count
   - Space reclaimed
7. **Commit**: Commit changes (if cleanup performed and not dry_run).
8. **Cleanup**: Remove marker files.
9. **Return**: Return summary with cleanup statistics.

## Cleanup Operations

**Process Cleanup**:
- Find orphaned opencode processes (pgrep)
- Terminate with SIGTERM, then SIGKILL if needed

**Directory Cleanup**:
- Scan ~/.opencode/ for temp files
- Remove incomplete postflight markers
- Clean cached artifacts older than threshold

**Confirmation** (unless --force):
- Show preview of actions
- Request user confirmation before execution

## Error Handling

- No ~/.opencode/ → Nothing to clean (not an error)
- Permission denied → Error with sudo suggestion
- Process termination failure → Log warning, continue with directory cleanup
- No orphaned processes → Inform user

---

**Updated**: 2026-03-05 as part of OC_135 skill postflight standardization
