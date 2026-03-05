---
name: skill-researcher
description: Conduct general research using web search, documentation, and codebase exploration. Invoke for non-Lean research tasks.
allowed-tools: Task, Bash, Edit, Read, Write
context: fork
agent: general-research-agent
---

# Researcher Skill

Thin wrapper that delegates research to `general-research-agent`.

<context>
  <system_context>OpenCode research skill wrapper.</system_context>
  <task_context>Delegate research and coordinate postflight updates.</task_context>
</context>

<context_injection>
  <file path=".opencode/context/core/formats/report-format.md" variable="report_format" />
  <file path=".opencode/context/core/standards/status-markers.md" variable="status_markers" />
</context_injection>

<role>Delegation skill for general research workflows.</role>

<task>Validate inputs, delegate research, and update status/artifacts.</task>

<execution>
  <stage id="1" name="LoadContext">
    <action>Read context files defined in <context_injection></action>
  </stage>
  <stage id="2" name="Preflight">
    <action>Validate status and prepare for delegation</action>
  </stage>
  <stage id="3" name="Delegate">
    <action>Invoke general-research-agent with injected context</action>
  </stage>
  <stage id="4" name="Postflight">
    <action>Update state and link artifacts</action>
  </stage>
</execution>

<validation>Validate metadata file, report artifact, and state updates.</validation>

<return_format>Brief text summary; metadata file in `specs/{N}_{SLUG}/.return-meta.json`.</return_format>

## Trigger Conditions

- Task language is general, meta, markdown, or latex
- /research command invoked

## Execution Flow

1. **Load Context**:
   - Read `report-format.md` -> `{report_format}`
   - Read `status-markers.md` -> `{status_markers}`

2. **Preflight**:
   - Validate task and status using `{status_markers}`.
   - **Display Task Header**: Print the following header to show which task is being researched:
     ```
     ╔══════════════════════════════════════════════════════════╗
     ║  Task OC_{N}: {project_name}                             ║
     ║  Action: RESEARCHING                                     ║
     ╚══════════════════════════════════════════════════════════╝
     ```
   - Update status to researching.
   - Create postflight marker file.

3. **Delegate**:
   - Call `Task` tool with `subagent_type="general-research-agent"`
   - Prompt:
     """
     Conduct research for task {N}.

     <system_context>
     Using the following format standards:
     {report_format}
     {status_markers}
     </system_context>
     """

4. **Postflight**:
   - Read metadata file and update state + TODO.
   - Link research artifact and commit.
   - Clean up marker and metadata files.
