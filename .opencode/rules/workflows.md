---
paths: .opencode/**/*
---

# Workflow Rules

## Command Lifecycle

Every command follows the checkpoint lifecycle. Reference `core/checkpoints/` for the
current gate-in/gate-out/commit model.

### 1. Preflight (GATE IN)
Before starting work:
- Parse and validate arguments
- Check task exists and status allows operation
- Update status to "in progress" variant
- Log session start

### 2. Execute (DELEGATE)
Perform the actual work:
- Route to appropriate skill by language
- Execute steps/phases
- Track progress
- Handle errors gracefully

### 3. Postflight (GATE OUT + COMMIT)
After completing work:
- Update status to completed variant
- Create artifacts
- Git commit changes
- Return results

## Research Workflow

```
/research N [focus]
    │
    ▼
┌─────────────────┐
│ Validate task   │
│ exists, status  │
│ allows research │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Update status   │
│ [RESEARCHING]   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Route by lang   │
│ lean→lean-lsp   │
│ other→web/code  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Create report   │
│ research-NNN.md │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Update status   │
│ [RESEARCHED]    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Git commit      │
└─────────────────┘
```

## Planning Workflow

```
/plan N
    │
    ▼
┌─────────────────┐
│ Load research   │
│ and task desc   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Update status   │
│ [PLANNING]      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Create phases   │
│ with steps      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Write plan file │
│ impl-NNN.md     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Update status   │
│ [PLANNED]       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Git commit      │
└─────────────────┘
```

## Implementation Workflow

```
/implement N
    │
    ▼
┌─────────────────┐
│ Load plan,      │
│ find resume pt  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Update status   │
│ [IMPLEMENTING]  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ For each phase: │
│ ┌─────────────┐ │
│ │ Mark IN     │ │
│ │ PROGRESS    │ │
│ ├─────────────┤ │
│ │ Execute     │ │
│ │ steps       │ │
│ ├─────────────┤ │
│ │ Mark        │ │
│ │ COMPLETED   │ │
│ ├─────────────┤ │
│ │ Git commit  │ │
│ │ phase       │ │
│ └─────────────┘ │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Create summary  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Update status   │
│ [COMPLETED]     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Final commit    │
└─────────────────┘
```

## Resume Pattern

For interrupted implementations:

```
/implement N (resumed)
    │
    ▼
┌─────────────────┐
│ Load plan       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Scan phases:    │
│ [COMPLETED] → ✓ │
│ [PARTIAL] → ◀── │ Resume here
│ [NOT STARTED]   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Continue from   │
│ resume point    │
└─────────────────┘
```

## Error Recovery

```
On error during phase:
    │
    ▼
┌─────────────────┐
│ Keep phase      │
│ [IN PROGRESS]   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Log error       │
│ to errors.json  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Commit partial  │
│ progress        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Return partial  │
│ with resume     │
│ info            │
└─────────────────┘
```
