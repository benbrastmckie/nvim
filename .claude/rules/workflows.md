---
paths: .claude/**/*
---

# Workflow Rules

## Command Lifecycle

Every command follows this pattern:

### 1. Preflight
Before starting work:
- Parse and validate arguments
- Check task exists and status allows operation
- Update status to "in progress" variant
- Log session start

### 2. Execute
Perform the actual work:
- Route to appropriate skill by task_type
- Execute steps/phases
- Track progress
- Handle errors gracefully

### 3. Postflight
After completing work:
- Update status to completed variant
- Create artifacts
- Git commit changes
- Return results

## Workflow Diagrams

For visual process diagrams (research, planning, implementation, resume, error recovery), see:
- [Workflow Diagrams](.claude/context/reference/workflow-diagrams.md)
