# Orchestration Core

**Created**: 2026-01-19
**Purpose**: Essential orchestration patterns for delegation, session tracking, and routing
**Consolidates**: orchestrator.md, delegation.md (partial), routing.md (partial), sessions.md (partial)

---

## Overview

This document defines the core orchestration patterns for the project's command-skill-agent architecture:

- **Session Tracking**: Unique identifiers for delegation chains
- **Delegation Safety**: Depth limits, cycle detection, timeouts
- **Return Format**: Standardized JSON structure for all agent returns
- **Routing**: Command to agent mapping and task-type-based routing

---

## Session Tracking

### Session ID Format

```
sess_{timestamp}_{random_6char}
Example: sess_1735460684_a1b2c3
```

**Generation** (portable, works on Linux/macOS):
```bash
session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
```

**Lifecycle**:
1. Generated at CHECKPOINT 1 (GATE IN) before delegation
2. Passed through delegation to skill/agent
3. Returned by agent in metadata for validation
4. Included in git commits for correlation

### Session Registry

Active delegations tracked in memory:

```json
{
  "sess_1735460684_a1b2c3": {
    "session_id": "sess_1735460684_a1b2c3",
    "command": "implement",
    "agent": "general-implementation-agent",
    "task_number": 191,
    "task_type": "meta",
    "start_time": "2026-01-19T10:00:00Z",
    "timeout": 3600,
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "implement", "general-implementation-agent"]
  }
}
```

---

## Delegation Safety

### Depth Limits

**Maximum delegation depth**: 3 levels

```
Level 0: User -> Orchestrator (not counted)
Level 1: Orchestrator -> Command -> Skill
Level 2: Skill -> Agent
Level 3: Agent -> Utility (rare)
Level 4+: BLOCKED
```

**Enforcement**: Check depth before delegating:
```bash
if [ "$delegation_depth" -ge 3 ]; then
  echo "Error: Max delegation depth exceeded"
  exit 1
fi
```

### Cycle Detection

Before delegating, verify target is not already in delegation path:

```python
def check_cycle(delegation_path, target):
    if target in delegation_path:
        raise CycleError(f"Cycle detected: {delegation_path} -> {target}")
```

### Timeout Configuration

| Command | Default Timeout | Max Timeout |
|---------|----------------|-------------|
| /research | 3600s (1 hour) | 7200s (2 hours) |
| /plan | 1800s (30 min) | 3600s (1 hour) |
| /implement | 7200s (2 hours) | 14400s (4 hours) |
| /revise | 1800s (30 min) | 3600s (1 hour) |

**Timeout Handling**:
- Return partial results if available
- Mark task as [PARTIAL] not failed
- Provide actionable recovery message

---

## Return Format

All agents MUST return this standardized JSON structure:

```json
{
  "status": "implemented|partial|failed|blocked",
  "summary": "Brief 2-5 sentence summary (<100 tokens)",
  "artifacts": [
    {
      "type": "research|plan|implementation|summary",
      "path": "relative/path/from/root",
      "summary": "One-sentence description"
    }
  ],
  "metadata": {
    "session_id": "sess_{timestamp}_{random}",
    "duration_seconds": 123,
    "agent_type": "agent_name",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "command", "agent"]
  },
  "errors": [
    {
      "type": "timeout|validation|execution",
      "message": "Human-readable description",
      "recoverable": true,
      "recommendation": "Suggested fix"
    }
  ],
  "next_steps": "Recommended next actions"
}
```

### Status Values

| Status | Meaning | Artifacts |
|--------|---------|-----------|
| `implemented` | Work finished successfully | Required |
| `partial` | Some work completed | Optional |
| `failed` | No usable results | Empty |
| `blocked` | Cannot proceed | Empty |

**CRITICAL**: Never use "completed" or "done" as status values - use contextual terms like "implemented", "researched", "planned".

---

## Delegation Context

Every delegation MUST include this context:

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "command", "agent"],
  "timeout": 3600,
  "task_context": {
    "task_number": 191,
    "task_type": "meta",
    "description": "Task description"
  }
}
```

---

## Routing

### Command -> Agent Mapping

| Command | Language-Based | Agent(s) |
|---------|---------------|----------|
| /research | Yes | Extension-provided or general-research-agent |
| /plan | No | planner-agent |
| /implement | Yes | Extension-provided or general-implementation-agent |
| /revise | No | planner-agent |
| /review | No | reviewer-agent |
| /meta | No | meta-builder-agent |

### Language Extraction

Priority order for extracting task language:

1. **state.json** (fast, ~12ms):
   ```bash
   language=$(jq -r --arg num "$task_number" \
     '.active_projects[] | select(.project_number == ($num | tonumber)) | .task_type // "general"' \
     specs/state.json)
   ```

2. **TODO.md** (fallback, ~100ms):
   ```bash
   language=$(grep -A 20 "^### ${task_number}\." specs/TODO.md | grep "Language" | sed 's/.*: //')
   ```

3. **Default**: "general"

### Routing Validation

Validate language/agent compatibility before delegation:

```bash
# Extension tasks must route to extension-provided agents
# Each extension defines its own task_type -> agent mapping in manifest.json
# Core task types (general, meta, markdown) route to core agents
```

---

## Quick Reference

### Preflight Checklist
- [ ] Parse task number from arguments
- [ ] Validate task exists in state.json
- [ ] Extract language for routing
- [ ] Generate session_id
- [ ] Prepare delegation context
- [ ] Update status to in-progress via skill-status-sync

### Postflight Checklist
- [ ] Validate return is valid JSON
- [ ] Check required fields present
- [ ] Verify session_id matches
- [ ] Validate artifacts exist (if status=implemented)
- [ ] Update status and link artifacts
- [ ] Create git commit

---

## Related Documentation

- `orchestration-validation.md` - Return validation details
- `preflight-pattern.md` - Preflight execution steps
- `postflight-pattern.md` - Postflight execution steps
- `state-management.md` - Task state and status markers
- `architecture.md` - Three-layer delegation architecture
