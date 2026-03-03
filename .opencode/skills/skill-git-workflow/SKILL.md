---
name: skill-git-workflow
description: Manage git commits for task workflows with file tracking and targeted commits.
allowed-tools: Bash, Edit, Read
---

# Git Workflow Skill

Direct execution skill for git operations, file change tracking, and targeted commits.

<context>
  <system_context>OpenCode git workflow maintenance.</system_context>
  <task_context>Create targeted commits for task workflows, tracking only changed files.</task_context>
</context>

<role>Direct execution skill for git operations and file tracking.</role>

<task>Track file changes and create targeted commits following git workflow rules.</task>

<execution>Use the Execution Flow and Functions sections to track changes and create commits.</execution>

<validation>Confirm commit formatting, staged file scope, and change tracking accuracy.</validation>

<return_format>Return structured commit summary with changed files and commit SHA.</return_format>

## Context References

Reference (do not load eagerly):
- Path: `.opencode/context/core/standards/git-safety.md` - Git safety rules
- Path: `.opencode/context/core/standards/git-workflow.md` - Git workflow standards
- Path: `.opencode/context/index.md` - Context discovery index

---

## Execution Flow

### 1. File Change Tracking

Before executing commands that modify files, capture the baseline git state:

```bash
# Store baseline for comparison
git status --porcelain > /tmp/git_baseline_$$.txt
```

After command execution, detect changed files:

```bash
# Get current state
git status --porcelain > /tmp/git_current_$$.txt

# Compare to get changed files
changed_files=$(comm -13 <(sort /tmp/git_baseline_$$.txt) <(sort /tmp/git_current_$$.txt) | awk '{print $NF}')
```

### 2. Targeted Commit

Stage and commit only the changed files:

```bash
# Stage only changed files
git add $changed_files

# Create commit with proper message
git commit -m "${commit_message}"
```

### 3. Error Handling

- Commit failures are non-blocking
- Log warnings for failed commits
- Continue with operation success

---

## Functions

### track_changes_start()

**Purpose**: Capture baseline git state before operations

**Usage**:
```bash
git status --porcelain > /tmp/git_baseline_${session_id}.txt
```

**Returns**: Path to baseline file

---

### track_changes_end()

**Purpose**: Compare current state to baseline and return changed files

**Usage**:
```bash
git status --porcelain > /tmp/git_current_${session_id}.txt
changed_files=$(comm -13 <(sort /tmp/git_baseline_${session_id}.txt) <(sort /tmp/git_current_${session_id}.txt) | awk '{print $NF}')
```

**Returns**: Space-separated list of changed file paths

---

### commit_targeted()

**Purpose**: Stage and commit only specified files

**Parameters**:
- `task_number` - Task number (e.g., "185")
- `action` - Action type (research, plan, review, implement)
- `files` - Space-separated list of files to commit
- `session_id` - Session ID for traceability
- `extra_info` - Optional extra info (phase number, blocked status, etc.)

**Usage**:
```bash
# Generate commit message
commit_msg=$(generate_commit_message "$task_number" "$action" "$extra_info")

# Stage and commit
git add $files
git commit -m "$commit_msg"
```

**Returns**: Commit SHA or empty on failure

---

### generate_commit_message()

**Purpose**: Generate properly formatted commit message

**Message Templates**:

| Command | Template |
|---------|----------|
| Research | `task OC_{N}: complete research` |
| Plan | `task OC_{N}: create implementation plan` |
| Review | `review: analyze {scope} (task OC_{N})` |
| Implement Phase | `task OC_{N} phase {P}: {phase_name}` |
| Implement Complete | `task OC_{N}: complete implementation` |
| Implement Blocked | `task OC_{N}: partial implementation (blocked phase {P})` |

**Format**:
```
task OC_{N}: {action}

Session: {session_id}

Co-Authored-By: OpenCode <noreply@opencode.ai>
```

---

## Integration with Commands

### For /research Command

**When**: After Step 6 (Write research report)

**Files to commit**:
- Research report: `specs/OC_{NNN}_{slug}/reports/research-001.md`
- State updates: `specs/state.json`
- TODO updates: `specs/TODO.md`

**Message**: `task OC_{N}: complete research`

---

### For /plan Command

**When**: After Step 6 (Write plan file)

**Files to commit**:
- Plan file: `specs/OC_{NNN}_{slug}/plans/implementation-001.md`
- State updates: `specs/state.json`
- TODO updates: `specs/TODO.md`

**Message**: `task OC_{N}: create implementation plan`

---

### For /review Command

**When**: After Step 5 (Create review report)

**Files to commit**:
- Review report: `specs/reviews/review-{DATE}.md`
- ROAD_MAP.md (if modified)
- TODO.md (if status changes)

**Message**: `review: analyze {scope} (task OC_{N})`

---

### For /implement Command

**Per-Phase Commit**:
- **When**: After each phase completion
- **Files**: Phase-modified files, TODO.md, state.json, plan file
- **Message**: `task OC_{N} phase {P}: {phase_name}`

**Final Commit**:
- **When**: After all phases complete
- **Files**: Summary file, final state/TODO updates
- **Message**: `task OC_{N}: complete implementation`

**Blocked Commit**:
- **When**: When implementation blocked and partial report created
- **Files**: Partial summary, current state
- **Message**: `task OC_{N}: partial implementation (blocked phase {P})`

---

## Error Handling

### Commit Failure

```xml
<error_handling>
  <error_type name="commit_failure">
    <detection>git commit returns non-zero exit code</detection>
    <handling>
      1. Log warning to stderr
      2. Return empty commit SHA
      3. Continue operation (non-blocking)
    </handling>
    <user_message>
      Warning: Changes made but git commit failed
      
      Modified files:
      {file_list}
      
      Manual commit required:
        git add {files}
        git commit -m "{message}"
    </user_message>
  </error_type>
</error_handling>
```

### No Changes Detected

```xml
<error_handling>
  <error_type name="no_changes">
    <detection>track_changes_end returns empty file list</detection>
    <handling>
      1. Log info: "No file changes detected"
      2. Skip commit step
      3. Continue normally
    </handling>
  </error_type>
</error_handling>
```

---

## Best Practices

1. **Always track changes**: Call track_changes_start() before file operations
2. **Targeted commits**: Only stage files that actually changed
3. **Never use git add -A**: Use explicit file lists
4. **Include session_id**: All commits must include session ID in message body
5. **Non-blocking commits**: Commit failures should not block command completion
6. **Clean up temp files**: Remove /tmp/git_* files after commit

---

## Example Usage

```bash
# 1. Start tracking
git status --porcelain > /tmp/git_baseline_sess_1234567890_abc123.txt

# 2. Execute command (modifies files)
# ... command execution ...

# 3. Detect changes
git status --porcelain > /tmp/git_current_sess_1234567890_abc123.txt
changed_files=$(comm -13 <(sort /tmp/git_baseline_*.txt) <(sort /tmp/git_current_*.txt) | awk '{print $NF}')

# 4. Commit if changes exist
if [ -n "$changed_files" ]; then
    git add $changed_files
    git commit -m "task OC_185: complete research

Session: sess_1234567890_abc123

Co-Authored-By: OpenCode <noreply@opencode.ai>"
fi

# 5. Cleanup
rm -f /tmp/git_*_sess_1234567890_abc123.txt
```

---

## Return Format

**Success**:
```json
{
  "status": "committed",
  "commit_sha": "abc123...",
  "files": ["file1", "file2"],
  "message": "task OC_185: complete research"
}
```

**No changes**:
```json
{
  "status": "no_changes",
  "files": [],
  "message": null
}
```

**Failure (non-blocking)**:
```json
{
  "status": "failed",
  "error": "git commit failed",
  "files": ["file1", "file2"],
  "message": "task OC_185: complete research"
}
```
