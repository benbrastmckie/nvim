# Research Report: Task #OC_146

**Task**: OC_146 - research_implement_subagent_workflow_best_practices
**Started**: 2026-03-05T00:00:00Z
**Completed**: 2026-03-05T00:30:00Z
**Effort**: 4 hours
**Dependencies**: None
**Sources/Inputs**: Codebase exploration of .opencode/skills/, .opencode/agents/, .opencode/commands/, .opencode/context/core/
**Artifacts**: specs/OC_146_research_implement_subagent_workflow_best_practices/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- **Current State**: The .opencode/ system uses a well-established three-layer delegation architecture (Command -> Skill -> Agent) with isolated context windows via the Task tool's `context: fork` mode
- **Key Pattern**: Skills act as "thin wrappers" that delegate to subagents with carefully prepared context, avoiding context pollution by NOT loading heavy context in skills
- **Metadata Passing**: Uses a file-based metadata exchange pattern via `.return-meta.json` files, avoiding console JSON pollution and enabling reliable structured data exchange
- **Critical Finding**: The system already implements most 2026 best practices for subagent workflows, including early metadata creation, session tracking, and validation gates
- **Gap Identified**: Primary agent currently performs research directly instead of delegating to research subagents - this is the core issue to address

## Context & Scope

This research investigates the current state of subagent workflows in the .opencode/ agent system, focusing on:

1. How isolated context windows are achieved
2. How metadata is passed between primary agent and subagents
3. How results are aggregated back into the primary workflow
4. Error handling patterns for subagent failures
5. Integration with the existing skill-based architecture

The research covers all major components: commands, skills, agents, and context files in the .opencode/ directory.

## Findings

### 1. Isolated Context Windows

**Current Implementation**:

The system achieves isolated context windows through the **Task tool with `context: fork` mode**:

```yaml
# From skill-researcher/SKILL.md
---
name: skill-researcher
context: fork  # CRITICAL: Prevents context pollution
agent: general-research-agent
---
```

**How It Works**:
1. Skills declare `context: fork` in their frontmatter
2. When the skill invokes a subagent via Task tool, the subagent receives a **clean, isolated context window**
3. The primary agent's context is NOT passed to the subagent
4. Only explicitly injected context (via `<context_injection>`) is passed

**Context Injection Pattern** (Push Model):

```xml
<context_injection>
  <file path=".opencode/context/core/formats/report-format.md" variable="report_format" />
  <file path=".opencode/context/core/standards/status-markers.md" variable="status_markers" />
</context_injection>

<execution>
  <stage id="1" name="LoadContext">
    <action>Read context files defined in <context_injection></action>
  </stage>
  <stage id="2" name="Delegate">
    <action>Inject context into agent prompt using {variable_name}</action>
  </stage>
</execution>
```

**Benefits**:
- **No context pollution**: Subagent starts with clean slate
- **Controlled information flow**: Only critical context is injected
- **Reduced token usage**: Subagent doesn't inherit primary agent's context bloat
- **Predictable behavior**: Subagent follows documented patterns, not inherited context

### 2. Metadata Passing

**File-Based Metadata Exchange Pattern**:

The system uses a sophisticated file-based metadata exchange to avoid console JSON pollution:

**Agent Side** (writes metadata file):
```json
// specs/{N}_{SLUG}/.return-meta.json
{
  "status": "researched",
  "artifacts": [
    {
      "type": "report",
      "path": "specs/259_prove_completeness/reports/research-001.md",
      "summary": "Research report with theorem findings"
    }
  ],
  "next_steps": "Run /plan 259 to create implementation plan",
  "metadata": {
    "session_id": "sess_1736700000_abc123",
    "agent_type": "lean-research-agent",
    "duration_seconds": 180,
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "research", "lean-research-agent"],
    "findings_count": 5
  }
}
```

**Skill Side** (reads metadata file):
```bash
metadata_file="specs/${task_number}_${task_slug}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    # ... process metadata
fi
```

**Delegation Context Schema**:

Every delegation includes structured context:

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "command", "agent"],
  "timeout": 3600,
  "task_context": {
    "task_number": 191,
    "task_name": "example_task",
    "description": "Task description",
    "language": "meta"
  },
  "metadata_file_path": "specs/191_example/.return-meta.json"
}
```

**Key Fields**:
- `session_id`: Unique identifier for tracking delegation chains
- `delegation_depth`: Prevents runaway delegation (max 3 levels)
- `delegation_path`: Enables cycle detection
- `task_context`: Task-specific information
- `metadata_file_path`: Where to write return metadata

### 3. Result Aggregation

**Skill Postflight Pattern**:

Skills aggregate subagent results through a standardized postflight process:

```xml
<stage id="4" name="Postflight">
  <action>Read metadata file and update state + TODO</action>
  <process>
    1. Read .return-meta.json
    2. Validate status and artifacts
    3. Update specs/state.json with new status
    4. Update specs/TODO.md with status and artifact links
    5. Create git commit with session ID
    6. Clean up marker and metadata files
  </process>
</stage>
```

**Validation Gates**:

```
Delegate → Wait → Verify → Proceed
```

1. **Delegate**: Invoke subagent via Task tool
2. **Wait**: Subagent executes with isolated context
3. **Verify**: Read metadata file, validate JSON structure
4. **Proceed**: Update state, link artifacts, commit changes

**Artifact Linking**:

```bash
# Update state.json with artifact
jq --arg path "$artifact_path" \
   --arg type "$(jq -r '.artifacts[0].type' "$metadata_file")" \
   --arg summary "$artifact_summary" \
  '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
    ([(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] ] +
     [{"path": $path, "type": $type, "summary": $summary}])' \
  specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

### 4. Error Handling

**Subagent Error Categories**:

| Error Type | Handling | Status |
|------------|----------|--------|
| `timeout` | Return partial results, mark [PARTIAL] | Recoverable |
| `validation` | Return failed status with details | May be recoverable |
| `execution` | Log error, return failed | Depends on error |
| `tool_unavailable` | Return blocked status | Recoverable after fix |

**Error Object Schema**:

```json
{
  "errors": [
    {
      "type": "timeout",
      "message": "Implementation timed out after 1 hour",
      "code": "TIMEOUT",
      "recoverable": true,
      "recommendation": "Resume with /implement 259"
    }
  ]
}
```

**Early Metadata Pattern** (Critical for interruption recovery):

```markdown
## Stage 0: Initialize Early Metadata

**CRITICAL**: Create metadata file BEFORE any substantive work.

1. Ensure task directory exists:
   ```bash
   mkdir -p "specs/{OC_NNN}_{SLUG}"
   ```

2. Write initial metadata:
   ```json
   {
     "status": "in_progress",
     "started_at": "{ISO8601 timestamp}",
     "artifacts": [],
     "partial_progress": {
       "stage": "initializing",
       "details": "Agent started, parsing delegation context"
     },
     "metadata": {
       "session_id": "{from delegation context}",
       "agent_type": "general-research-agent",
       "delegation_depth": 1,
       "delegation_path": ["orchestrator", "research", "general-research-agent"]
     }
   }
   ```
```

**Fallback Chain**:

```
Primary: Codebase exploration (Glob/Grep/Read)
    |
    v
Fallback 1: Broaden search patterns
    |
    v
Fallback 2: Web search with specific query
    |
    v
Fallback 3: Web search with broader terms
    |
    v
Fallback 4: Write partial with recommendations
```

### 5. Integration with Skills Architecture

**Three-Layer Delegation**:

```
Layer 1: Command (e.g., /research)
  |
  v
Layer 2: Skill (e.g., skill-researcher)
  |
  v
Layer 3: Agent (e.g., general-research-agent)
```

**Skill Responsibilities**:

| Phase | Skill Action | Agent Action |
|-------|--------------|--------------|
| Preflight | Validate, update status, display header | N/A |
| Context Loading | Load critical context via injection | Load on-demand via @-references |
| Delegation | Invoke agent via Task tool | Receive delegation context |
| Core Work | N/A | Execute research/planning/implementation |
| Postflight | Read metadata, update state, commit | N/A |

**Thin Wrapper Pattern**:

Skills are "thin wrappers" that:
- ✅ Validate inputs
- ✅ Prepare delegation context
- ✅ Invoke subagent via Task tool
- ✅ Validate and propagate return

Skills do NOT:
- ❌ Load heavy context (subagent does this)
- ❌ Execute business logic (subagent does this)
- ❌ Handle complex error recovery (subagent does this)

**Context Loading Best Practices** (from context-loading-best-practices.md):

| Model | Use When | Example |
|-------|----------|---------|
| **Push** | Critical context required | plan-format.md, status-markers.md |
| **Pull** | Optional reference material | code-examples.md, guides/*.md |

**Skill Examples**:

- **skill-planner**: Injects 3 files (plan-format.md, status-markers.md, task-breakdown.md)
- **skill-researcher**: Injects 2 files (report-format.md, status-markers.md)
- **skill-implementer**: Injects 4 files (return-metadata-file.md, postflight-control.md, file-metadata-exchange.md, jq-escaping-workarounds.md)

### 6. Current Issue: Primary Agent Research

**Problem Statement**:

The current issue is that the **primary agent performs research directly** instead of delegating to research subagents. This means:

1. Primary agent context gets polluted with research details
2. Token usage is higher than necessary
3. Research cannot be resumed independently if interrupted
4. Research findings aren't properly isolated in structured reports

**Current Flow (Problematic)**:
```
User: /research 146
  |
  v
Orchestrator
  |
  v
Command (/research)
  |
  v
Skill (skill-researcher) - SHOULD delegate here
  |
  v
❌ Primary agent does research directly (WRONG)
```

**Desired Flow (Correct)**:
```
User: /research 146
  |
  v
Orchestrator
  |
  v
Command (/research)
  |
  v
Skill (skill-researcher)
  |
  v
Agent (general-research-agent) - Delegate to isolated context
  |
  v
✅ Agent writes report, returns via metadata file
```

## Decisions

### Decision 1: Use File-Based Metadata Exchange

**Rationale**: Console JSON output gets interpreted as conversational text by OpenCode, causing parsing failures. File-based exchange is reliable and enables postflight processing.

**Implementation**: All agents write to `specs/{N}_{SLUG}/.return-meta.json` before returning.

### Decision 2: Push Model for Critical Context

**Rationale**: Critical context (format standards, status markers) must be available for correct operation. Push model via `<context_injection>` ensures this.

**Implementation**: Skills declare context_injection blocks; agents receive injected context in their prompts.

### Decision 3: Pull Model for Optional Context

**Rationale**: Optional context (examples, guides) should not bloat the context window. Pull model via @-references allows on-demand loading.

**Implementation**: Agents use @-references to load context files when needed.

### Decision 4: Early Metadata Creation

**Rationale**: If an agent is interrupted, the metadata file must exist for skill postflight to detect the interruption and provide recovery guidance.

**Implementation**: All agents create metadata file at Stage 0, before any substantive work.

### Decision 5: Thin Wrapper Skills

**Rationale**: Skills should focus on lifecycle management (preflight/postflight), not business logic. This keeps skills simple and maintainable.

**Implementation**: Skills are ~100 lines; agents are ~400-500 lines with full workflow documentation.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Context injection bloat | High | Medium | Keep total injected context <1000 lines |
| Metadata file corruption | Medium | Low | Validate JSON before reading; use jq for safe extraction |
| Subagent timeout | Medium | Medium | Set appropriate timeouts; return partial status |
| Cycle in delegation | High | Low | Enforce max depth (3); track delegation_path |
| Session ID mismatch | Medium | Low | Include session_id in metadata; validate in postflight |
| Context window overflow | High | Low | Use lazy loading; monitor line counts |

## Recommendations

### Immediate Actions

1. **Fix Primary Agent Research**: Ensure `/research` command properly delegates through skill-researcher to general-research-agent, rather than having the primary agent perform research directly.

2. **Audit All Commands**: Verify all commands follow the three-layer delegation pattern (Command -> Skill -> Agent) and don't bypass the agent layer.

3. **Validate Context Injection**: Ensure all skills have appropriate `<context_injection>` blocks for critical context.

### Best Practices for 2026

1. **Always Use `context: fork`**: Skills must declare `context: fork` to ensure isolated context windows for subagents.

2. **Early Metadata Creation**: Agents must create `.return-meta.json` at Stage 0, before any substantive work.

3. **Push vs Pull Decision Tree**:
   - Required for correct operation? → Push
   - Strict format/standard? → Push
   - Optional reference material? → Pull
   - Large file (>500 lines)? → Pull

4. **Validation Gates**: Always verify subagent results before proceeding:
   ```
   Delegate → Wait → Verify → Proceed
   ```

5. **Session Tracking**: Include session_id in all delegations and metadata for traceability.

6. **Status Values**: Never use "completed" or "done" - use contextual values ("researched", "planned", "implemented").

### Integration Checklist

When implementing subagent workflows:

- [ ] Skill declares `context: fork` in frontmatter
- [ ] Skill has `<context_injection>` block for critical context
- [ ] Skill invokes agent via Task tool (NOT Skill tool)
- [ ] Agent creates early metadata at Stage 0
- [ ] Agent writes final metadata to `.return-meta.json`
- [ ] Agent returns brief text summary (NOT JSON to console)
- [ ] Skill reads metadata file in postflight
- [ ] Skill validates artifacts exist before linking
- [ ] Skill updates state.json and TODO.md
- [ ] Skill creates git commit with session ID
- [ ] Skill cleans up metadata file after successful postflight

## Appendix: Context Knowledge Candidates

### Candidate 1: Three-Layer Delegation Architecture

**Type**: Pattern
**Domain**: system-architecture
**Target Context**: `.opencode/context/core/architecture/system-overview.md`
**Content**: The .opencode/ system uses a three-layer delegation architecture: Commands (input validation, routing) -> Skills (lifecycle management, preflight/postflight) -> Agents (domain-specific work). This separation of concerns enables isolated context windows and reliable metadata passing.
**Source**: `.opencode/context/core/architecture/system-overview.md`
**Rationale**: This is a fundamental architectural pattern that applies to all workflow implementations.

### Candidate 2: File-Based Metadata Exchange Pattern

**Type**: Pattern
**Domain**: workflow-patterns
**Target Context**: `.opencode/context/core/patterns/file-metadata-exchange.md`
**Content**: Agents write structured metadata to `specs/{N}_{SLUG}/.return-meta.json` instead of returning JSON to console. Skills read this file during postflight to update state and link artifacts. This avoids console pollution and enables reliable structured data exchange.
**Source**: `.opencode/context/core/patterns/file-metadata-exchange.md`
**Rationale**: This is a core pattern used across all agent workflows for result aggregation.

### Candidate 3: Push vs Pull Context Loading

**Type**: Technique
**Domain**: context-management
**Target Context**: `.opencode/context/core/patterns/context-loading-best-practices.md`
**Content**: Use Push model (context_injection) for critical context required for correct operation (format standards, status markers). Use Pull model (@-references) for optional reference material (examples, guides, large files).
**Source**: `.opencode/docs/guides/context-loading-best-practices.md`
**Rationale**: This technique optimizes context window usage and ensures critical context is always available.

### Candidate 4: Early Metadata Pattern

**Type**: Pattern
**Domain**: workflow-patterns
**Target Context**: `.opencode/context/core/patterns/metadata-file-return.md`
**Content**: Agents must create `.return-meta.json` with "in_progress" status at Stage 0, before any substantive work. This ensures metadata exists even if the agent is interrupted, enabling skill postflight to detect interruptions and provide recovery guidance.
**Source**: `.opencode/agent/subagents/general-research-agent.md`
**Rationale**: This pattern is critical for interruption recovery and should be standardized across all agents.

---

**Report Version**: 1.0
**Researcher**: general-research-agent
**Session ID**: research-session-oc146
