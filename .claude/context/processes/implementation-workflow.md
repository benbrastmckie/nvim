# Implementation Workflow

**Created**: 2025-12-29  
**Purpose**: Detailed implementation workflow for project tasks

---

## Overview

This document describes the complete implementation workflow executed by the implementer subagent. It covers both plan-based (phased) and direct (single-pass) implementation modes.

---

## Implementation Modes

### Plan-Based Implementation (Phased)

**When**: Task has existing plan in TODO.md  
**Characteristics**:
- Multi-phase execution
- Resume support
- Per-phase git commits
- Phase status tracking
- Timeout recovery

**Workflow**:
1. Load plan file
2. Parse phase status markers
3. Find resume point (first [NOT STARTED] or [IN PROGRESS] phase)
4. Execute phases sequentially
5. Update phase status after each phase
6. Create git commit per phase
7. Support resume on timeout

### Direct Implementation (Single-Pass)

**When**: Task has no plan  
**Characteristics**:
- Single-pass execution
- No phase tracking
- Single git commit
- No resume support (must re-execute if fails)

**Workflow**:
1. Read task description
2. Determine files to modify/create
3. Execute all changes
4. Create all artifacts
5. Create single git commit

---

## Task-Type-Based Routing

### Language Extraction

Language is extracted from task entry in TODO.md:

```bash
grep -A 20 "^### ${task_number}\." specs/TODO.md | grep "Language" | sed 's/\*\*Language\*\*: //'
```

**Fallback**: If extraction fails, defaults to "general" with warning logged.

### Routing Rules

| Task Type | Agent | Tools Available |
|----------|-------|----------------|
| `neovim` | `neovim-implementation-agent` | nvim --headless, File operations, git |
| `markdown` | `implementer` | File operations, git |
| `meta` | `implementer` | File operations, git |
| `general` | `implementer` | File operations, git |

**Note**: Additional languages (latex, typst) available via extensions in `.claude/extensions/`.

**Critical**: Language extraction MUST occur before routing. Incorrect routing bypasses task-type-specific tooling.

---

## Detailed Workflow Steps

### Step 1: Load Task and Determine Mode

**Action**: Load task details and determine implementation mode

**Process**:
1. Read task from TODO.md using grep (selective loading):
   ```bash
   grep -A 50 "^### ${task_number}\." specs/TODO.md > specs/tmp/task-${task_number}.md
   ```
2. Extract task metadata:
   - Task number
   - Task title
   - Language
   - Description
   - Acceptance criteria
   - Plan link (if exists)
3. Check for existing plan link in task entry
4. If plan link exists:
   - Load plan file from path
   - Parse phase status markers
   - Determine resume point (first [NOT STARTED] or [IN PROGRESS] phase)
   - Set mode = "phased"
5. If no plan link:
   - Set mode = "direct"

**Checkpoint**: Task loaded and mode determined

### Step 2: Execute Implementation

#### For Phased Mode:

**Action**: Execute implementation phase by phase

**Process**:
1. For each phase (starting from resume point):
   a. Read phase description and tasks
   b. Update phase status: [NOT STARTED] → [IN PROGRESS]
   c. Execute phase implementation:
      - Determine files to modify/create for this phase
      - Execute changes
      - Create phase artifacts
   d. Validate phase completion against success criteria
   e. Update phase status: [IN PROGRESS] → [COMPLETED]
   f. Create git commit for phase:
      ```bash
      git add {phase_artifacts}
      git commit -m "task {number} phase {N}: {phase_name}"
      ```
   g. If timeout occurs:
      - Save current progress
      - Update phase status to [IN PROGRESS]
      - Return partial status with resume instructions
      - Exit (user can resume later)
2. Continue until all phases complete or timeout

**Phase Execution Details**:
- Each phase is independent
- Phase artifacts are committed immediately
- Phase status is updated in plan file
- Timeout recovery: Resume from last incomplete phase

#### For Direct Mode:

**Action**: Execute implementation in single pass

**Process**:
1. Analyze task requirements:
   - Read description
   - Read acceptance criteria
   - Identify scope
2. Determine files to modify/create:
   - Based on language and task type
   - Consider existing codebase structure
3. Execute all changes:
   - Modify existing files
   - Create new files
   - Update configurations
4. Create all artifacts (see Artifact Creation section)
5. Validate against acceptance criteria
6. Create single git commit:
   ```bash
   git add {all_artifacts}
   git commit -m "task {number}: {description}"
   ```

**Checkpoint**: Implementation executed

### Step 3: Create Artifacts

**Action**: Create implementation artifacts

**Process**:
1. Create implementation files (code, docs, configs):
   - Paths vary by language and task
   - Neovim: `nvim/lua/**/*.lua`, `after/ftplugin/**/*.lua`
   - Markdown: `docs/**/*.md`, `.claude/**/*.md`
   - LaTeX: `**/*.tex`
   - Config: `**/*.json`, `**/*.yaml`, etc.
2. If multi-file output (>1 file modified/created):
   - Create implementation summary artifact
   - Path: `specs/{number}_{slug}/summaries/MM_{short-slug}-summary.md`
   - Content:
     - What was implemented
     - Files modified/created
     - Key decisions made
     - Testing recommendations
   - Token limit: <100 tokens (~400 characters)
3. Verify all artifacts created successfully:
   - Check files exist on disk
   - Verify file sizes > 0
   - Validate file formats

**Artifact Naming**:
- Implementation files: Follow project conventions
- Summary: `MM_{short-slug}-summary.md`
- Directories created lazily (only when writing first artifact)

**Token Limit Rationale**:
Multi-file implementations create N+1 artifacts (N implementation files + 1 summary). Summary provides unified overview without requiring orchestrator to read all N files. This protects orchestrator context window from bloat.

**Checkpoint**: Artifacts created

### Step 4: Update Status

**Action**: Update task status to [COMPLETED]

**Process**:
1. Delegate to status-sync-manager for atomic update:
   - Prepare update payload:
     ```json
     {
       "operation": "implementation_complete",
       "task_number": {number},
       "status": "completed",
       "artifacts": [{artifact_list}],
       "metadata": {
         "mode": "phased|direct",
         "phases_completed": {count} (if phased),
         "files_modified": {count}
       }
     }
     ```
   - Invoke status-sync-manager
   - Wait for return
2. status-sync-manager performs atomic update:
   - Update TODO.md:
     - Status: [IMPLEMENTING] → [COMPLETED]
     - Add **Completed**: {date}
     - Add artifact links
   - Update state.json:
     - Update status and timestamps
     - Add artifact_paths
   - Update plan file (if phased):
     - Update phase statuses
     - Mark plan as complete
   - Two-phase commit (all or nothing)
3. Verify atomic update succeeded:
   - Check return status
   - Verify files updated on disk

**Atomic Update Guarantee**:
status-sync-manager ensures TODO.md, state.json, and plan file (if exists) are updated atomically. If any update fails, all are rolled back.

**Checkpoint**: Status updated atomically

### Step 5: Create Git Commit

**Action**: Create git commit for implementation

**Process**:
1. Delegate to git-workflow-manager:
   - Prepare commit payload:
     ```json
     {
       "operation": "implementation_commit",
       "scope": [{all_artifacts}, "TODO.md", "state.json"],
       "message": "task {number}: {description}",
       "mode": "phased|direct"
     }
     ```
   - Invoke git-workflow-manager
   - Wait for return
2. git-workflow-manager creates commit:
   - Stage all files in scope
   - Create commit with message
   - Verify commit created
3. If commit fails:
   - Log error to errors.json (non-critical)
   - Continue (implementation already complete)
   - Return success with warning

**Commit Strategy**:
- **Phased**: One commit per completed phase (created in Step 2)
- **Direct**: One commit for entire task (created here)

**Commit Message Format**:
- Direct: `task {number}: {description}`
- Phased: `task {number} phase {N}: {phase_name}` (per phase)

**Checkpoint**: Git commit created

### Step 6: Prepare Return

**Action**: Format return object per subagent-return-format.md

**Process**:
1. Build return object:
   ```json
   {
     "status": "completed|partial",
     "summary": "{brief_1_sentence_overview} (<100 tokens)",
     "artifacts": [
       {
         "type": "implementation",
         "path": "{file_path}",
         "summary": "{brief_description}"
       },
       {
         "type": "summary",
         "path": "{summary_path}",
         "summary": "Implementation summary"
       }
     ],
     "metadata": {
       "task_number": {number},
       "mode": "phased|direct",
       "phases_completed": {count} (if phased),
       "files_modified": {count},
       "task_type": "{task_type}"
     },
     "session_id": "{session_id}"
   }
   ```
2. Validate return format:
   - Check all required fields present
   - Verify summary <100 tokens
   - Verify session_id matches input
   - Verify artifacts exist on disk
3. If validation fails:
   - Log error
   - Fix issues
   - Re-validate

**Checkpoint**: Return object prepared

### Step 7: Return

**Action**: Return to command

**Process**:
1. Return formatted object to command
2. Command validates return
3. Command relays to user

**Checkpoint**: Return sent

---

## Resume Support

### Resume Detection

**Automatic**: Implementer automatically detects incomplete phases and resumes

**Process**:
1. Load plan file
2. Parse phase status markers
3. Find first phase with [NOT STARTED] or [IN PROGRESS]
4. Resume from that phase
5. Skip all [COMPLETED] phases

### Resume Invocation

**Same command** works for both initial implementation and resume:

```bash
/implement {task_number}
```

**No special flags needed** - implementer detects state automatically

### Partial Return

On timeout or failure:
1. Save current phase progress
2. Update phase status to [IN PROGRESS]
3. Return partial status:
   ```json
   {
     "status": "partial",
     "summary": "Implementation partially completed. Phase {N} in progress.",
     "artifacts": [{completed_artifacts}],
     "metadata": {
       "resume_phase": {N},
       "phases_completed": {count},
       "phases_remaining": {count}
     }
   }
   ```
4. User can resume with same command

---

## Status Transitions

| From | To | Condition |
|------|-----|-----------|
| [NOT STARTED] | [IMPLEMENTING] | Implementation started |
| [PLANNED] | [IMPLEMENTING] | Implementation started |
| [REVISED] | [IMPLEMENTING] | Implementation started |
| [IMPLEMENTING] | [COMPLETED] | Implementation completed successfully |
| [IMPLEMENTING] | [IMPLEMENTING] | Implementation failed or partial |
| [IMPLEMENTING] | [BLOCKED] | Implementation blocked by dependency |

**Status Update**: Delegated to `status-sync-manager` for atomic synchronization across TODO.md and state.json.

**Timestamps**:
- `**Started**: {date}` added when status → [IMPLEMENTING]
- `**Completed**: {date}` added when status → [COMPLETED]

---

## Context Loading

### Routing Stage (Command)

Load minimal context for routing decisions:
- `.claude/context/orchestration/routing.md` (routing logic)

### Execution Stage (Implementer)

Implementation agents load context on-demand per `.claude/context/index.json`:
- `.claude/context/formats/subagent-return.md` (return format)
- `.claude/rules/state-management.md` (status transitions)
- `.claude/rules/artifact-formats.md` (artifact naming)
- Task entry via `grep -A 50 "^### ${task_number}\." TODO.md` (~2KB vs 109KB full file)
- `state.json` (project state)
- Plan file if exists (for phase tracking and resume)

**Language-specific context**:
- Extension context loaded based on task language (see `.claude/extensions/*/context/`)
- If markdown: (no additional context)

**Optimization**: Task extraction reduces context from 109KB (full TODO.md) to ~2KB (task entry only), 98% reduction.

---

## Error Handling

### Task Not Found

```
Error: Task {task_number} not found in specs/TODO.md

Recommendation: Verify task number exists in TODO.md
```

### Invalid Task Number

```
Error: Task must be integer or range (N-M). Got: {input}

Usage: /implement TASK_NUMBER [PROMPT]
```

### Task Already Completed

```
Error: Task {task_number} is already [COMPLETED]

Recommendation: Cannot re-implement completed tasks
```

### Implementation Timeout

```
Error: Implementation timed out

Status: Partial implementation may exist
Task status: [IMPLEMENTING]
Phase status: [IN PROGRESS] (if plan exists)

Recommendation: Resume with /implement {task_number}
```

### Validation Failure

```
Error: Implementation validation failed

Details: {validation_error}

Recommendation: Fix implementer subagent implementation
```

### Git Commit Failure (non-critical)

```
Warning: Git commit failed

Implementation completed successfully
Task status updated to [COMPLETED]

Manual commit required:
  git add {files}
  git commit -m "task {number}: {description}"

Error: {git_error}
```

### Language Extraction Failure

```
Warning: Could not extract language from task entry

Defaulting to: general
Agent: implementer

Recommendation: Add **Task Type**: {language} to task entry in TODO.md
```

---

## Quality Standards

### Atomic Updates

Status updates delegated to `status-sync-manager` for atomic synchronization:
- `specs/TODO.md` (status, timestamps, artifact links)
- `state.json` (status, timestamps, artifact_paths)
- Plan file (phase status markers if plan exists)
- Project state.json (lazy created if needed)

Two-phase commit ensures consistency across all files.

### Lazy Directory Creation

Directories created only when writing artifacts:
- `specs/{task_number}_{slug}/` created when writing first artifact
- `summaries/` subdirectory created when writing implementation-summary.md

No directories created during routing or validation stages.

### Git Workflow

Git commits delegated to `git-workflow-manager` for standardized commits:
- Commit message format: `task {number}: {description}`
- Scope files: All implementation artifacts + TODO.md + state.json
- Per-phase commits if plan exists
- Single commit if no plan

### Token Limits

- Summary artifacts: <100 tokens (~400 characters)
- Protects orchestrator context window from bloat
- Provides unified overview for multi-file outputs

---

## Performance Optimization

### Task Extraction

Extract only specific task entry from TODO.md to reduce context load:

```bash
grep -A 50 "^### ${task_number}\." specs/TODO.md > specs/tmp/task-${task_number}.md
```

**Impact**: Reduces context from 109KB (full TODO.md) to ~2KB (task entry only), 98% reduction.

### Lazy Context Loading

Load context on-demand:
- Required context loaded upfront
- Optional context loaded when needed
- Language-specific context loaded only for that language

### Delegation Safety

- Max delegation depth: 3 (orchestrator → command → implementer → utility)
- Timeout: 7200s (2 hours) for implementation
- Session tracking: Unique session_id for all delegations
- Cycle detection: Prevent infinite delegation loops

---

## References

- **Command**: `.claude/commands/implement.md`
- **Agent**: `.claude/agents/general-implementation-agent.md`
- **Return Format**: `.claude/context/formats/subagent-return.md`
- **Artifact Formats**: `.claude/rules/artifact-formats.md`
- **Delegation**: `.claude/context/orchestration/delegation.md`
