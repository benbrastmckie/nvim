---
name: skill-learn
description: Scan files for FIX:/NOTE:/TODO: tags and create tasks.
allowed-tools: Task, Bash, Edit, Read, Write
---

# Learn Skill

Direct execution skill for scanning tags and creating tasks.

<context>
  <system_context>OpenCode tag scanning and task creation.</system_context>
  <task_context>Scan codebase tags and create tasks based on selections.</task_context>
</context>

<context_injection>
  <file path="specs/TODO.md" variable="todo_file" />
  <file path="specs/state.json" variable="state_file" />
</context_injection>

<role>Direct execution skill for tag discovery.</role>

<task>Scan FIX/NOTE/TODO tags and create tasks.</task>

<execution>
  <stage id="1" name="LoadContext">
    <action>Load {todo_file} and {state_file} for task management</action>
  </stage>
  <stage id="2" name="ScanTags">
    <action>Scan for FIX:/NOTE:/TODO: tags across codebase</action>
  </stage>
  <stage id="3" name="InteractiveSelection">
    <action>Present findings and let user select which to convert to tasks</action>
  </stage>
  <stage id="4" name="CreateTasks">
    <action>Create tasks in {todo_file} and {state_file} for selected tags</action>
  </stage>
</execution>

<validation>Validate tag parsing and task creation outputs.</validation>

<return_format>Return summary of created tasks.</return_format>

## Context References

Reference (do not load eagerly):
- Path: `@specs/TODO.md` - Current task list
- Path: `@specs/state.json` - Machine state
