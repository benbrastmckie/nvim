# Research Report: Widen load_when for state-management-schema.md

- **Task**: 488 - widen_todo_entry_format_context
- **Started**: 2026-04-20T12:00:00Z
- **Completed**: 2026-04-20T12:30:00Z
- **Effort**: 30 minutes
- **Dependencies**: None
- **Sources/Inputs**:
  - `.claude/context/index.json` - Context index with load_when rules
  - `.claude/context/reference/state-management-schema.md` - Schema file
  - `.claude/context/orchestration/state-management.md` - Orchestration state management
  - `.claude/commands/review.md` - Review command definition
  - `.claude/commands/task.md` - Task command definition
  - `.claude/commands/meta.md` - Meta command definition
  - `.claude/commands/fix-it.md` - Fix-it command definition
  - `.claude/commands/errors.md` - Errors command definition
  - `.claude/commands/spawn.md` - Spawn command definition
  - `/home/benjamin/Projects/ProofChecker/.claude/context/index.json` - Sister repo comparison
- **Artifacts**: specs/488_widen_todo_entry_format_context/reports/01_widen-load-when.md
- **Standards**: report-format.md, status-markers.md

## Executive Summary

- `state-management-schema.md` and `state-management.md` both have `load_when` restricted to `commands: ["/task", "/todo"]` and `task_types: ["meta"]`, with empty `agents` arrays
- Six commands create tasks but only two (`/task`, `/todo`) can load these context files
- `/review`, `/fix-it`, `/meta`, `/spawn`, and `/task --expand`/`--review` all create TODO.md entries without guaranteed access to the entry format spec
- The `/review` command's task creation section (5.6.3) says "Add task entry following existing format" with no explicit reference to the schema
- The ProofChecker repo has the identical `load_when` configuration, confirming this is a systemic issue

## Context & Scope

The goal is to ensure all commands that create task entries in TODO.md and state.json have access to the authoritative format specification via context loading. Currently, the `load_when` rules are too narrow, causing task-creating commands to rely on ambient knowledge from CLAUDE.md rather than the detailed schema.

## Findings

### 1. Current load_when Configuration

**`reference/state-management-schema.md`** (352 lines):
```json
{
  "load_when": {
    "task_types": ["meta"],
    "agents": [],
    "commands": ["/task", "/todo"]
  }
}
```

**`orchestration/state-management.md`** (337 lines):
```json
{
  "load_when": {
    "task_types": ["meta"],
    "agents": [],
    "commands": ["/task", "/todo"]
  }
}
```

Both files share the same narrow `load_when` configuration.

### 2. Commands That Create Task Entries

| Command | Creates Tasks? | Has load_when Access? | Mechanism |
|---------|---------------|----------------------|-----------|
| `/task` (default) | Yes | Yes (via commands) | Direct state.json + TODO.md writes |
| `/task --expand` | Yes | Yes (via commands) | Expands task into subtasks |
| `/task --review` | Yes | Yes (via commands) | Creates follow-up tasks |
| `/todo` | No (archives) | Yes (via commands) | Archives completed tasks, does not create new ones |
| `/review` | Yes | **No** | Section 5.6.3: writes state.json + TODO.md entries |
| `/fix-it` | Yes | **No** | Section 5: creates tasks from FIX:/TODO: tags |
| `/meta` | Yes | **No** | Stage 7 (CreateTasks): updates state.json + TODO.md |
| `/spawn` | Yes | **No** | Postflight: creates spawned tasks in state.json + TODO.md |
| `/errors` | Yes (indirectly) | **No** | Creates error-fix tasks |

### 3. Content Needed by Task-Creating Commands

The `state-management-schema.md` contains several critical sections needed by task creators:

1. **TODO.md Entry Format** (lines 42-55): The canonical template for TODO.md entries including field order, formatting, and required/optional fields
2. **state.json Project Entry Fields** (lines 59-72): Required and optional fields for state.json entries
3. **task_type Field** (lines 74-100): Valid task_type values and compound format
4. **Dependencies Field** (lines 190-208): Format conversion between state.json arrays and TODO.md text
5. **Status Values Mapping** (lines 248-262): Correspondence between TODO.md markers and state.json values
6. **Artifact Linking Formats** (lines 264-308): How to link artifacts in TODO.md entries

### 4. Gap Analysis

Commands missing access to the format spec:

| Command | Gap Impact | Severity |
|---------|-----------|----------|
| `/review` | Creates tasks with vague "following existing format" instruction | High |
| `/fix-it` | Creates tasks from tag scans, no explicit format reference | High |
| `/meta` | Creates multiple tasks via meta-builder-agent | Medium |
| `/spawn` | Creates spawned tasks via spawn-agent | Medium |
| `/errors` | Creates error-fix tasks | Low |

The `/review` command is the highest-impact gap because:
- It has the most complex task creation logic (grouped + individual + interactive selection)
- Section 5.6.3 step 4 says only "Add task entry following existing format in TODO.md frontmatter section" with no reference to the authoritative format
- It writes directly to state.json and TODO.md without loading the schema

### 5. Review Command Reference Gap

The review command (`/review`) at `.claude/commands/review.md`:
- **Section 5.6.3, Step 4**: Says "Add task entry following existing format in TODO.md frontmatter section" -- this is the only guidance for TODO.md entry format
- **No explicit @-reference** to `state-management-schema.md` or `state-management.md`
- **No inline format template** for the TODO.md entry structure
- The review-process workflow at `.claude/context/workflows/review-process.md` references `orchestration/state-management.md` but that file is about behavioral patterns, not the entry format schema

### 6. Sister Repo Comparison (ProofChecker)

The ProofChecker at `/home/benjamin/Projects/ProofChecker/.claude/context/index.json` has the identical configuration:

**`orchestration/state-management.md`**:
```json
"commands": ["/task", "/todo"]
"task_types": ["meta"]
"agents": []
```

**`reference/state-management-schema.md`**:
```json
"commands": ["/task", "/todo"]
"task_types": ["meta"]
"agents": []
```

This confirms the gap exists across all repositories using this agent system.

## Decisions

1. Both `state-management-schema.md` and `state-management.md` need widened `load_when.commands` arrays
2. The `/review` command should get an explicit `@`-reference to the schema in its task creation section
3. Changes should be mirrored to the ProofChecker repo

## Recommendations

### R1: Widen load_when.commands for state-management-schema.md

Add all task-creating commands to the commands array:

```json
{
  "load_when": {
    "task_types": ["meta"],
    "agents": ["meta-builder-agent", "spawn-agent"],
    "commands": ["/task", "/todo", "/review", "/fix-it", "/meta", "/spawn", "/errors"]
  }
}
```

**Rationale**: Adding agents `meta-builder-agent` and `spawn-agent` because they are the agents that actually perform task creation for `/meta` and `/spawn` respectively.

### R2: Widen load_when.commands for state-management.md

Apply the same widening:

```json
{
  "load_when": {
    "task_types": ["meta"],
    "agents": ["meta-builder-agent", "spawn-agent"],
    "commands": ["/task", "/todo", "/review", "/fix-it", "/meta", "/spawn", "/errors"]
  }
}
```

### R3: Add explicit format reference in review.md

In Section 5.6.3, Step 4, replace the vague instruction with an explicit reference:

**Current** (line 806):
```
Add task entry following existing format in TODO.md frontmatter section.
```

**Proposed**:
```
Add task entry to TODO.md following the format in @.claude/context/reference/state-management-schema.md (see "TODO.md Entry Format" section).
```

### R4: Mirror changes to ProofChecker

Apply R1 and R2 to `/home/benjamin/Projects/ProofChecker/.claude/context/index.json`.

### R5: Consider line count budget impact

Both files together add ~689 lines to context. The additional commands loading this context should be acceptable since:
- These commands already load other context via `task_types: ["meta"]`
- The schema is essential reference material for correct task creation
- Incorrect TODO.md entries cause downstream sync failures

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Increased context loading for commands that rarely create tasks (e.g., `/errors`) | The 352+337 = 689 lines is moderate; commands only load when matched |
| ProofChecker changes could drift from nvim config | Both repos should be updated simultaneously |
| Adding agents to load_when could load schema for non-task-creating delegations | The agents listed (`meta-builder-agent`, `spawn-agent`) always create tasks |

## Appendix

### Files Examined
- `.claude/context/index.json` - Full index (3307 lines)
- `.claude/context/reference/state-management-schema.md` - Schema (352 lines)
- `.claude/context/orchestration/state-management.md` - Orchestration patterns (337 lines)
- `.claude/commands/review.md` - Review command (1571 lines)
- `.claude/commands/task.md` - Task command
- `.claude/commands/meta.md` - Meta command
- `.claude/commands/fix-it.md` - Fix-it command
- `.claude/commands/spawn.md` - Spawn command
- `.claude/commands/errors.md` - Errors command
- `/home/benjamin/Projects/ProofChecker/.claude/context/index.json` - Sister repo index
