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

<role>Direct execution skill for tag discovery.</role>

<task>Scan FIX/NOTE/TODO tags and create tasks.</task>

<execution>Follow the Interactive Flow steps for scanning and task creation.</execution>

<validation>Validate tag parsing and task creation outputs.</validation>

<return_format>Return summary of created tasks.</return_format>

## Context References

Reference (do not load eagerly):
- Path: `@specs/TODO.md` - Current task list
- Path: `@specs/state.json` - Machine state
