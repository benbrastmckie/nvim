---
name: skill-planner
description: Create phased implementation plans from research findings. Invoke when a task needs an implementation plan.
allowed-tools: Task, Bash, Edit, Read, Write
context: fork
agent: planner-agent
---

# Planner Skill

Thin wrapper that delegates plan creation to `planner-agent`.

<context>
  <system_context>OpenCode planning skill wrapper.</system_context>
  <task_context>Delegate planning and coordinate postflight updates.</task_context>
</context>

<context_injection>
  <file path=".opencode/context/core/formats/plan-format.md" variable="plan_format" />
  <file path=".opencode/context/core/standards/status-markers.md" variable="status_markers" />
  <file path=".opencode/context/core/workflows/task-breakdown.md" variable="task_breakdown" />
</context_injection>

<role>Delegation skill for planning workflows.</role>

<task>Validate planning inputs, delegate plan creation, and update task state.</task>

<execution>
  <stage id="1" name="LoadContext">
    <action>Read context files defined in <context_injection></action>
  </stage>
  <stage id="2" name="Preflight">
    <action>Validate status and prepare for delegation</action>
  </stage>
  <stage id="3" name="Delegate">
    <action>Invoke planner-agent with injected context</action>
  </stage>
  <stage id="4" name="Postflight">
    <action>Update state and link artifacts</action>
  </stage>
</execution>

<validation>Validate metadata file, plan artifact, and status updates.</validation>

<return_format>Brief text summary; metadata file in `specs/{N}_{SLUG}/.return-meta.json`.</return_format>

## Trigger Conditions

- Task status allows planning
- /plan command invoked

## Execution Flow

1. **Load Context**:
   - Read `plan-format.md` -> `{plan_format}`
   - Read `status-markers.md` -> `{status_markers}`
   - Read `task-breakdown.md` -> `{task_breakdown}`

2. **Preflight**:
   - Validate task and status using `{status_markers}`.
   - **Display Task Header**: Print the following header to show which task is being planned:
     ```
     ╔══════════════════════════════════════════════════════════╗
     ║  Task OC_{N}: {project_name}                             ║
     ║  Action: PLANNING                                        ║
     ╚══════════════════════════════════════════════════════════╝
     ```
   - Update status to planning.
   - Create postflight marker file.

3. **Delegate**:
   - Call `Task` tool with `subagent_type="planner-agent"`
   - Prompt:
     """
     Create implementation plan for task {N}.

     <system_context>
     Using the following format standards and guidelines:
     {plan_format}
     {status_markers}
     {task_breakdown}
     </system_context>
     """

4. **Postflight**:
   - Read metadata file and update state + TODO.
   - Link plan artifact and commit.
   - Clean up marker and metadata files.
