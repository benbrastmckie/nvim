# Orchestration Reference

**Version**: 1.0
**Created**: 2026-01-19
**Purpose**: Examples, troubleshooting, and quick reference for orchestration
**Consolidates**: orchestrator.md (examples/troubleshooting), delegation.md (examples)

---

## Quick Reference

### Command Execution Flow

```
User: /implement 611
    |
    v
CHECKPOINT 1: GATE IN (Preflight)
- Parse task number: 611
- Validate task exists
- Generate session_id
- Update status: [IMPLEMENTING]
    |
    v
STAGE 2: DELEGATE
- Extract language: meta
- Route to: general-implementation-agent
- Pass delegation context
    |
    v
CHECKPOINT 2: GATE OUT (Postflight)
- Validate return format
- Verify artifacts exist
- Update status: [COMPLETED]
- Link artifacts to task
    |
    v
CHECKPOINT 3: COMMIT
- Create git commit
- Return result to user
```

### Status Flow by Command

| Command | Preflight Status | Postflight Status |
|---------|------------------|-------------------|
| /research | RESEARCHING | RESEARCHED |
| /plan | PLANNING | PLANNED |
| /implement | IMPLEMENTING | COMPLETED |
| /revise | REVISING | REVISED |

---

## Examples

### Example 1: Simple Research Delegation

```
User: /research 197

GATE IN:
- Task 197 exists: YES
- Language: lean
- Session: sess_1735460684_a1b2c3
- Status update: [RESEARCHING]

DELEGATE:
- Route to: lean-research-agent
- Timeout: 3600s

GATE OUT:
- Status: implemented
- Artifacts: research-001.md (2,450 bytes)
- Status update: [RESEARCHED]
- Artifact link: added to specs/TODO.md

COMMIT:
- Git commit: "task 197: complete research"
```

### Example 2: Implementation with Timeout

```
User: /implement 191

GATE IN:
- Task 191 exists: YES
- Language: markdown
- Session: sess_1735460685_d4e5f6
- Status update: [IMPLEMENTING]

DELEGATE:
- Route to: general-implementation-agent
- Timeout: 7200s

TIMEOUT AFTER 3600s:
- Status: partial
- Artifacts: phase 1 complete (summary.md)
- Status update: [PARTIAL]
- Recovery: "Run /implement 191 to resume from phase 2"
```

### Example 3: Cycle Detection

```
Delegation path: ["orchestrator", "implement", "task-executor"]
Target: task-executor

RESULT: BLOCKED
Error: "Cycle detected: orchestrator -> implement -> task-executor -> task-executor"
```

### Example 4: Bulk Task Recovery

```
User: /task --recover 343-345, 337

Parsed ranges: [337, 343, 344, 345]

Validation:
- Task 337: exists in archive: YES
- Task 343: exists in archive: YES
- Task 344: exists in archive: YES
- Task 345: exists in archive: YES

Result: 4 tasks recovered
Files updated: specs/TODO.md, specs/state.json, specs/archive/state.json
```

---

## Troubleshooting

### Symptom: Delegation Hangs

**Cause**: Missing timeout or return validation

**Fix**:
1. Check timeout is set (default 3600s)
2. Verify agent returns standardized format
3. Check session_id tracking
4. Enable delegation registry monitoring

### Symptom: Infinite Loop

**Cause**: Cycle in delegation path

**Fix**:
1. Enable cycle detection
2. Check delegation_path before routing
3. Verify depth limit enforced (max 3)
4. Log delegation paths for debugging

### Symptom: Phantom Research

**Cause**: Agent returned status=completed but no artifacts

**Detection**:
```
[FAIL] Agent returned 'completed' status but created no artifacts
Error: Phantom research detected
```

**Fix**:
1. Reset task status to [NOT STARTED]
2. Re-run command
3. Verify agent creates artifacts before returning

### Symptom: Language Routing Mismatch

**Cause**: Language extraction failed or routing incorrect

**Detection**:
```
[FAIL] Routing validation failed: language=lean but agent=researcher
```

**Fix**:
1. Verify **Language** field in specs/TODO.md
2. Check routing configuration
3. Re-run after fixing language field

### Symptom: Session ID Mismatch

**Cause**: Agent not returning correct session_id

**Detection**:
```
[FAIL] Session ID mismatch
Expected: sess_1735460684_a1b2c3
Got: sess_1735460685_different
```

**Fix**:
1. Check agent receives session_id in delegation context
2. Verify agent returns same session_id in metadata
3. Review agent return format

### Symptom: Status Update Failed

**Cause**: skill-status-sync failed or state desync

**Detection**:
```
[WARN] Postflight verification failed - status not updated
Expected: completed
Actual: implementing
```

**Fix**:
1. Run `/task --sync {task_number}` to fix state
2. Check specs/TODO.md and specs/state.json for inconsistencies
3. Review skill-status-sync logs

---

## Delegation Registry Operations

| Operation | When | Purpose |
|-----------|------|---------|
| Register | Delegation start | Add entry with session_id |
| Monitor | Every 60s | Check for timeouts |
| Update | Status changes | Update status field |
| Complete | Delegation done | Mark completed |
| Cleanup | Timeout/error | Remove and log |

---

## Bulk Operation Patterns

### Range Syntax

```
"343"         -> [343]
"343-345"     -> [343, 344, 345]
"337, 343-345" -> [337, 343, 344, 345]
```

### Bulk Recovery Return

```json
{
  "status": "implemented",
  "summary": "Recovered 4 tasks from archive",
  "artifacts": [],
  "metadata": {
    "session_id": "sess_...",
    "task_numbers": [337, 343, 344, 345],
    "success_count": 4,
    "failure_count": 0,
    "files_updated": ["specs/TODO.md", "specs/state.json", "specs/archive/state.json"]
  }
}
```

### Bulk Sync with Git Blame

For conflict resolution, git blame determines which file has more recent changes:

```json
{
  "conflict_details": [{
    "task_number": 343,
    "field": "status",
    "winner": "specs/state.json",
    "timestamp_state": "2026-01-07T10:00:00Z",
    "timestamp_todo": "2026-01-06T09:00:00Z"
  }]
}
```

---

## Logging Patterns

### Routing Logs

```
[INFO] Task 258 language: lean
[INFO] Routing to lean-research-agent (language=lean)
[PASS] Routing validation succeeded
```

### Validation Logs

```
[PASS] Return is valid JSON
[PASS] All required fields present
[PASS] Status is valid: implemented
[PASS] Session ID matches
[PASS] 2 artifacts validated
```

### Error Logs

```
[FAIL] Artifact not found: specs/197/reports/research-001.md
Error: Subagent claimed to create artifact but file does not exist
Recommendation: Verify researcher writes artifacts to correct paths
```

---

## Related Documentation

- `orchestration-core.md` - Core patterns (session, delegation, routing)
- `orchestration-validation.md` - Validation rules and steps
- `preflight-pattern.md` - Pre-delegation checklist
- `postflight-pattern.md` - Post-completion checklist
- `architecture.md` - Three-layer architecture overview
