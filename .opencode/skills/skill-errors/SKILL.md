---
name: skill-errors
description: Analyze error patterns and create fix tasks. Invoke for /errors command.
allowed-tools: Task, Bash, Edit, Read, Write
context: fork
agent: error-analysis-agent
---

# Errors Skill

Thin wrapper that delegates error analysis to `error-analysis-agent`.

<context>
  <system_context>OpenCode error analysis skill wrapper.</system_context>
  <task_context>Delegate error analysis and coordinate postflight updates.</task_context>
</context>

<context_injection>
  <file path=".opencode/context/core/formats/return-metadata-file.md" variable="return_metadata" />
  <file path=".opencode/context/core/patterns/postflight-control.md" variable="postflight_control" />
  <file path=".opencode/context/core/patterns/file-metadata-exchange.md" variable="file_metadata" />
</context_injection>

<role>Delegation skill for error analysis and fix workflows.</role>

<task>Validate inputs, delegate analysis/fix, and update error state.</task>

<execution>
  <stage id="1" name="LoadContext">
    <action>Read context files defined in <context_injection></action>
  </stage>
  <stage id="2" name="Preflight">
    <action>Validate errors.json and prepare for delegation using {return_metadata} and {postflight_control}</action>
  </stage>
  <stage id="3" name="CreatePostflightMarker">
    <action>Create .postflight-pending marker file to prevent premature termination</action>
  </stage>
  <stage id="4" name="Delegate">
    <action>Invoke error-analysis-agent via Task tool with injected context</action>
  </stage>
  <stage id="5" name="ReadMetadata">
    <action>Parse subagent return metadata using {file_metadata}</action>
  </stage>
  <stage id="6" name="UpdateState">
    <action>Update errors.json and link analysis report</action>
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

<validation>Validate metadata file, analysis report, error state updates.</validation>

<return_format>Brief text summary; metadata file in specs/.return-meta.json.</return_format>

## Trigger Conditions

- /errors command invoked
- Analysis mode or fix mode (--fix OC_N)

## Execution Flow

1. **LoadContext**: Read injected context files.
2. **Preflight**: Validate errors.json exists (initialize if missing).
3. **CreatePostflightMarker**: Create marker file in specs/:
   ```bash
   cat > "specs/.postflight-pending" << EOF
   {
     "session_id": "${session_id}",
     "skill": "skill-errors",
     "operation": "${mode}",
     "reason": "Postflight pending: error state update, report linking, git commit"
   }
   EOF
   ```
4. **Delegate**: Invoke error-analysis-agent via Task tool.
   - Pass mode (analysis or fix) and task number (if fix mode)
   - Subagent performs error analysis or fix implementation
5. **ReadMetadata**: Read `.return-meta.json` from subagent.
6. **UpdateState**: Update `specs/errors.json`.
   - Add analysis metadata
   - Update error statuses (if fix mode)
   - Link analysis report at `specs/errors/analysis-{DATE}.md`
7. **Commit**: Commit changes.
8. **Cleanup**: Remove marker files.
9. **Return**: Return summary with error statistics and fix results.

## Modes

**Analysis Mode** (no --fix flag):
- Group errors by type, severity, recurrence
- Identify patterns and root causes
- Create analysis report
- Create fix task recommendations

**Fix Mode** (--fix OC_N):
- Load specific task error data
- Analyze context and history
- Implement fixes
- Verify and update status

## Error Handling

- Missing errors.json → Initialize empty
- No errors found → Inform user
- Analysis failure → Log warning, partial results
- Fix failure → Keep status "unfixed"

---

**Created**: 2026-03-05 as part of OC_135 skill postflight standardization
