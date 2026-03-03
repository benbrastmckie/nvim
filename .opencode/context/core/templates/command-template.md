# Command Template (Checkpoint-Based)

Standard command structure using checkpoint-based execution with three gates.

## Frontmatter Structure

```yaml
---
command: {command_name}
description: "{Brief description}"
version: "1.0"
arguments:
  - name: {arg_name}
    type: string
    required: true
    description: {arg_description}
allowed-tools: {tools}
argument-hint: {hint}
delegation_depth: 1
max_delegation_depth: 3
context_loading:
  strategy: lazy
  index: ".opencode/context/index.md"
  required:
    - "core/workflows/command-lifecycle.md"
---
```

## Command Body Structure

```markdown
# /{command} Command

{Description}

## Arguments

- `$1` - Task number (required)
- Optional: `--flag` description

## Execution

### CHECKPOINT 1: GATE IN

Execute checkpoint-gate-in.md:

1. Generate session_id: `sess_{timestamp}_{random}`
2. Lookup task via jq (see routing.md)
3. Validate task exists and status allows operation
4. Invoke skill-status-sync: `preflight_update(task_number, {in_progress_status})`
5. Verify status updated

**ABORT** if validation fails. **PROCEED** if all pass.

### STAGE 2: DELEGATE

Route to skill by language (see routing.md):

| Language | Skill |
|----------|-------|
| lean | skill-lean-{operation} |
| latex | skill-latex-{operation} |
| general/meta/markdown | skill-{operation} |

Invoke via Skill tool with:
- task_number
- session_id
- operation-specific context

### CHECKPOINT 2: GATE OUT

Execute checkpoint-gate-out.md:

1. Validate return structure
2. Verify artifacts exist on disk
3. Invoke skill-status-sync: `postflight_update(task_number, {completed_status}, artifacts)`
4. Verify status and artifact links

**PROCEED** to commit. **RETRY** if validation fails.

### CHECKPOINT 3: COMMIT

Execute checkpoint-commit.md:

1. `git add -A`
2. Create commit with session_id
3. Verify commit (non-blocking)

## Output

{Template for user-facing output}

## Error Handling

- GATE IN failure: Return immediately with error
- DELEGATE failure: Keep in-progress status, return error
- GATE OUT failure: Keep in-progress, attempt recovery
- COMMIT failure: Log warning, continue with success
```

---

## Key Principles

### Checkpoint Pattern
All commands follow: GATE IN → DELEGATE → GATE OUT → COMMIT

### Status Updates
All status updates go through skill-status-sync (no inline jq in commands).

### Language Routing
Route to skill by task language. See routing.md for mapping table.

### Session Tracking
Generate session_id at GATE IN, include in commit for traceability.

---

## Example: /research Command

```markdown
### CHECKPOINT 1: GATE IN
1. Generate session_id
2. Validate task exists
3. Invoke skill-status-sync: preflight_update(N, "researching")

### STAGE 2: DELEGATE
Route by language:
- lean → skill-lean-research
- other → skill-researcher

### CHECKPOINT 2: GATE OUT
1. Validate return
2. Invoke skill-status-sync: postflight_update(N, "researched", artifacts)

### CHECKPOINT 3: COMMIT
git commit -m "task N: complete research"
```

---

## Context References

Commands reference but do not load:
- `.opencode/context/core/checkpoints/` - Checkpoint patterns
- `.opencode/context/core/routing.md` - Language routing
- `.opencode/context/core/validation.md` - Return validation

Context is loaded by skills/agents, not commands.
