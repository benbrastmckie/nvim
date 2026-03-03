# Anti-Stop Patterns for OpenCode Agent Systems

## Critical Background

OpenCode interprets certain words and phrases as signals to stop execution immediately. This causes workflow delegation to fail when subagents return these patterns, because the orchestrator's postflight (status updates, git commits) never runs.

**Root Cause**: OpenCode treats certain return values as "conversation complete" signals, halting execution before the calling skill/orchestrator can continue.

**Impact**: Workflow commands like /research, /plan, /implement stop prematurely, leaving tasks in inconsistent states (e.g., [RESEARCHING] instead of [RESEARCHED]).

## Forbidden Patterns

### Status Values - NEVER Use

These status values trigger immediate stop behavior:

| Forbidden | Replacement | Use Case |
|-----------|-------------|----------|
| `"completed"` | `"researched"` | Research operations |
| `"completed"` | `"planned"` | Planning operations |
| `"completed"` | `"implemented"` | Implementation operations |
| `"completed"` | `"synced"` | Status sync operations |
| `"completed"` | `"committed"` | Git commit operations |
| `"completed"` | `"tasks_created"` | Meta/task creation operations |
| `"done"` | Use contextual value | Any operation |
| `"finished"` | Use contextual value | Any operation |

### Phrases - NEVER Use in Summaries or next_steps

These phrases trigger stop behavior:

| Forbidden Phrase | Safe Alternative |
|------------------|------------------|
| "Task complete" | "Implementation finished. Run /task --sync to verify." |
| "Task is done" | "Research concluded. Artifacts created." |
| "Work is finished" | "Plan created. Ready for implementation." |
| "All tasks completed" | "All phases implemented. Run verification." |
| "Nothing more to do" | "Operation concluded. Orchestrator continues." |
| Any phrase suggesting finality | Use continuation-oriented language |

## Required Patterns

### Contextual Status Values

Use operation-specific status values that describe *what was achieved*:

```json
// Research agent
{"status": "researched", ...}

// Planner agent
{"status": "planned", ...}

// Implementation agent
{"status": "implemented", ...}

// Status sync skill
{"status": "synced", ...}

// Git workflow skill
{"status": "committed", ...}

// Meta builder agent
{"status": "tasks_created", ...}
```

### Non-Success Values (unchanged)

These values are safe and should be used as-is:
- `"partial"` - Task partially completed, can resume
- `"failed"` - Task failed, cannot continue
- `"blocked"` - Task blocked by dependency

### Safe Phrasing for next_steps

Use continuation-oriented language that implies the workflow continues:

```json
// Good: implies orchestrator continues
{"next_steps": "Implementation finished. Run /task --sync to verify."}
{"next_steps": "Research concluded. Artifacts created."}
{"next_steps": "Plan created. Ready for /implement {N}."}

// Bad: triggers stop
{"next_steps": "Task complete"}
{"next_steps": "All done."}
```

## Enforcement Points

### 1. subagent-return.md (Primary Specification)

The return format specification explicitly lists allowed status values and explains why "completed" was removed.

**Location**: `.opencode/context/core/formats/subagent-return.md`

### 2. Agent MUST NOT Sections

Each agent file's Critical Requirements section includes anti-stop rules:

```markdown
**MUST NOT**:
...
8. Return the word "completed" as a status value (triggers OpenCode stop behavior)
9. Use phrases like "task is complete", "work is done", or "finished" in summaries
10. Assume your return ends the workflow (orchestrator continues with postflight)
```

### 3. skill-status-sync (Direct Execution)

The status sync skill uses direct execution (Bash, Edit, Read) for atomic status updates. It demonstrates correct anti-stop patterns in its return format documentation.

**Location**: `.opencode/skills/skill-status-sync/SKILL.md`

### 4. meta-builder-agent (New Component Enforcement)

When /meta creates new agents or skills, it must apply anti-stop patterns to the generated templates.

**Location**: `.opencode/agents/meta-builder-agent.md`

## Validation

### Quick Check Commands

Verify no forbidden patterns exist:

```bash
# Check for "completed" status in agent return schemas
grep '"status": "completed' .opencode/agents/*.md

# Check for "Task complete" in skill files
grep -r "Task complete" .opencode/skills/

# Check for "completed|partial|failed" pattern (old format)
grep '"completed|partial|failed"' .opencode/agents/*.md

# Verify anti-stop language is present
grep "triggers OpenCode stop behavior" .opencode/agents/*.md | wc -l
# Expected: 6 (one per agent file)
```

### Automated Verification

Add to CI/pre-commit hook:

```bash
# Fail if any agent uses "completed" status
if grep -q '"status": "completed' .opencode/agents/*.md; then
  echo "ERROR: Agent files contain forbidden 'completed' status value"
  exit 1
fi
```

## Background References

### GitHub Issues

- **Issue #6159**: Documents OpenCode's stop behavior with certain return values
- **Issue #599**: Reports subagent early termination patterns

### Internal Documentation

- Research report: `specs/480_investigate_workflow_delegation_early_stop/reports/research-001.md`
- Implementation plan: `specs/480_investigate_workflow_delegation_early_stop/plans/implementation-002.md`

## Creating New Agents/Skills

When creating new agents or skills via /meta:

1. **Use contextual status values** - Choose from: researched, planned, implemented, synced, linked, committed, tasks_created
2. **Avoid terminal language** - Never use "complete", "done", "finished" in summaries
3. **Include anti-stop MUST NOT items** - Copy from existing agents
4. **Reference this pattern file** - Add to Context References section
5. **Test with full workflow** - Verify orchestrator postflight runs after return
