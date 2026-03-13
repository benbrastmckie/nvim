# Integration Example: Research Flow

This example traces a complete `/research` command through all three layers of the project agent system, showing how commands, skills, and agents work together.

---

## Scenario

A user runs `/research 427` to research task 427 (documenting the command/skill/subagent framework). This is a "meta" language task.

---

## Complete Flow Diagram

```
User Input: /research 427
       |
       v
[Layer 1: Command] .claude/commands/research.md
       |
       | Frontmatter specifies: agent: orchestrator
       v
[Orchestrator] skill-orchestrator/SKILL.md
       |
       | 1. Parse $ARGUMENTS -> task_number = 427
       | 2. Lookup task in state.json -> language = "meta"
       | 3. Route by language: meta -> skill-researcher
       v
[Layer 2: Skill] skill-researcher/SKILL.md
       |
       | 1. Validate task exists
       | 2. Prepare delegation context
       | 3. Invoke general-research-agent via Task tool
       v
[Layer 3: Agent] general-research-agent.md
       |
       | 1. Parse delegation context
       | 2. Load required context files
       | 3. Execute research (codebase + web)
       | 4. Create report artifact
       | 5. Update status
       | 6. Return JSON result
       v
[Return Flow]
       |
       | Agent -> Skill -> Orchestrator -> User
       v
Output: Research report created at specs/427_document.../reports/01_research-findings.md
```

---

## Step-by-Step Walkthrough

### Step 1: User Invokes Command

```bash
/research 427
```

Claude Code reads `.claude/commands/research.md` and sees:

```yaml
---
name: research
agent: orchestrator
description: Conduct research for a task
routing:
  language_based: true
  neovim: skill-neovim-research
  default: skill-researcher
---
```

### Step 2: Orchestrator Receives Command

The orchestrator (skill-orchestrator) receives `$ARGUMENTS = "427"`.

**Orchestrator Stage 1: Parse Arguments**
```
Input: $ARGUMENTS = "427"
Parsed: task_number = 427
```

**Orchestrator Stage 2: Lookup Task**

Read from `specs/state.json`:
```json
{
  "project_number": 427,
  "project_name": "document_command_skill_subagent_framework",
  "status": "researching",
  "language": "meta",
  "priority": "medium"
}
```

Extracted:
- task_number = 427
- language = "meta"
- status = "researching"
- project_name = "document_command_skill_subagent_framework"

**Orchestrator Stage 3: Route by Language**

```
Language: "meta"
Routing rules from command frontmatter:
  neovim -> skill-neovim-research
  default -> skill-researcher

Decision: "meta" matches default -> invoke skill-researcher
```

### Step 3: Skill Validates and Delegates

The skill (`skill-researcher/SKILL.md`) receives the routing.

**Skill Step 1: Input Validation**

```bash
# Lookup task
task_data=$(jq -r --arg num "427" \
  '.active_projects[] | select(.project_number == ($num | tonumber))' \
  specs/state.json)

# Validate exists -> YES
# Extract fields
language="meta"
status="researching"
project_name="document_command_skill_subagent_framework"
description="Systematically document the framework..."
```

**Skill Step 2: Prepare Delegation Context**

```json
{
  "session_id": "sess_1736700000_abc123",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "research", "skill-researcher"],
  "timeout": 3600,
  "task_context": {
    "task_number": 427,
    "task_name": "document_command_skill_subagent_framework",
    "description": "Systematically document the framework for using commands, skills, and subagents in conjunction.",
    "language": "meta"
  },
  "focus_prompt": null
}
```

**Skill Step 3: Invoke Subagent**

The skill invokes `general-research-agent` via the Task tool.

### Step 4: Agent Executes Research

The agent (`general-research-agent.md`) receives the delegation context.

**Agent Stage 1: Parse Delegation Context**

Extract:
- task_number = 427
- task_name = "document_command_skill_subagent_framework"
- language = "meta"
- session_id = "sess_1736700000_abc123"

**Agent Stage 2: Determine Search Strategy**

Based on language = "meta":
- Primary: Context files + existing skills
- Secondary: WebSearch for Claude docs

**Agent Stage 3: Execute Searches**

```
Step 1: Codebase Exploration
- Glob(".claude/skills/**/SKILL.md") -> 9 skills found
- Glob(".claude/agents/*.md") -> 6 agents found
- Glob(".claude/commands/*.md") -> 9 commands found
- Read key files to understand patterns

Step 2: Context File Review
- Read .claude/context/core/templates/thin-wrapper-skill.md
- Read .claude/context/core/formats/subagent-return.md
- Read .claude/context/core/orchestration/orchestration-core.md

Step 3: Synthesize Findings
- 8 key patterns identified
- 5 documentation gaps found
- 4 recommendations formed
```

**Agent Stage 4: Generate Output**

Create research report following `report-format.md`:

```markdown
# Research Report: Task #427

**Task**: 427 - Document command, skill, and subagent framework
**Date**: 2026-01-12
**Focus**: Framework documentation

## Summary
This research analyzed the existing command, skill, and subagent
architecture. Found 8 key patterns, 5 documentation gaps, and
formed 4 recommendations.

## Findings
### 1. Current Architecture: Three-Layer Delegation Pattern
...

### 2. Component Relationships
...

## Recommendations
1. Create Component Selection Guide
2. Create Skill Creation Guide
...
```

**Agent Stage 5: Create Artifact**

```bash
mkdir -p specs/427_document_command_skill_subagent_framework/reports/
write 01_research-findings.md
```

**Agent Stage 6: Update Status**

```bash
# Update state.json
jq '.active_projects |= map(
  if .project_number == 427
  then .status = "researched" | .last_updated = "2026-01-12T05:40:23Z"
  else . end
)' state.json > state.json.tmp && mv state.json.tmp state.json

# Update TODO.md
# Add [RESEARCHED] status and research report link
```

**Agent Stage 7: Return JSON Result**

```json
{
  "status": "completed",
  "summary": "Research completed with 8 key findings on the three-layer architecture. Identified documentation gaps and formed 4 recommendations for component selection, skill creation, agent creation, and integration examples.",
  "artifacts": [
    {
      "type": "report",
      "path": "specs/427_document_command_skill_subagent_framework/reports/01_research-findings.md",
      "summary": "Research report with 8 findings and 4 recommendations"
    }
  ],
  "metadata": {
    "session_id": "sess_1736700000_abc123",
    "duration_seconds": 180,
    "agent_type": "general-research-agent",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "research", "general-research-agent"],
    "findings_count": 8
  },
  "next_steps": "Run /plan 427 to create implementation plan"
}
```

### Step 5: Return Flow

**Agent -> Skill**

Skill receives JSON, validates against `subagent-return.md`:
- status is "completed" (valid)
- summary is non-empty and <100 tokens (valid)
- artifacts array present with path (valid)
- metadata contains session_id (valid, matches expected)

Skill propagates return without modification.

**Skill -> Orchestrator**

Orchestrator receives validated result, formats for user.

**Orchestrator -> User**

User sees:
```
Research completed for task 427.

Created: specs/427_document_command_skill_subagent_framework/reports/01_research-findings.md

Next steps: Run /plan 427 to create implementation plan
```

---

## Key Decision Points

### Routing Decision

```
Input: /research 427 (task language = "meta")

Command frontmatter:
  routing:
    neovim: skill-neovim-research
    default: skill-researcher

Decision tree:
  Is language "neovim"? NO
  -> Use default: skill-researcher
```

If task 427 had `language: "neovim"`, the flow would be:
```
orchestrator -> skill-neovim-research -> neovim-research-agent
```

### Context Loading Decision

```
Agent: general-research-agent
Task language: "meta"

Context loading:
  Always load:
    - subagent-return.md (return format)
    - report-format.md (artifact format)

  Language-specific (meta):
    - Load existing skill/agent patterns
    - NO Lean-specific context
    - NO LaTeX-specific context
```

---

## Artifact Locations

After `/research 427` completes:

```
specs/
├── state.json                 # Updated: task 427 status = "researched"
├── TODO.md                    # Updated: task 427 [RESEARCHED] with link
└── 427_document_command_skill_subagent_framework/
    └── reports/
        └── 01_research-findings.md    # Created: research report
```

---

## Error Scenarios

### Scenario A: Task Not Found

If user runs `/research 999` but task 999 does not exist:

```
Orchestrator Stage 2:
  Lookup task 999 in state.json -> NOT FOUND

Return:
{
  "status": "failed",
  "summary": "Task 999 not found in state.json",
  "errors": [{
    "type": "validation",
    "message": "Task 999 not found",
    "recommendation": "Check task exists with /task --sync"
  }]
}
```

### Scenario B: Network Error During Research

If WebSearch fails during research:

```
Agent Stage 3:
  WebSearch request fails -> network timeout

Agent continues with fallback:
  Use codebase-only patterns
  Note limitation in report

Return:
{
  "status": "partial",
  "summary": "Found 4 codebase patterns but WebSearch failed. Report contains local findings with suggested follow-up.",
  "errors": [{
    "type": "network",
    "message": "WebSearch request failed: connection timeout",
    "recoverable": true,
    "recommendation": "Retry research or proceed with codebase-only findings"
  }]
}
```

### Scenario C: Neovim Task Routing

If user runs `/research 259` where task 259 has `language: "neovim"`:

```
Orchestrator Stage 2:
  Lookup task 259 -> language = "neovim"

Orchestrator Stage 3:
  Routing: neovim -> skill-neovim-research

Flow:
  orchestrator -> skill-neovim-research -> neovim-research-agent

Agent uses:
  - WebSearch for plugin documentation
  - WebFetch for API references
  - Read for codebase exploration
  - Neovim/lazy.nvim context
```

---

## Session Tracking

The session_id flows through all layers:

```
Skill generates: session_id = "sess_1736700000_abc123"
         |
         v
Agent receives session_id in delegation context
         |
         v
Agent includes session_id in return metadata
         |
         v
Skill validates session_id matches expected
         |
         v
Session tracked for debugging/auditing
```

---

## Summary

This example demonstrated:

1. **Command Layer**: User entry point, routing configuration in frontmatter
2. **Orchestrator**: Parses arguments, looks up task, routes by language
3. **Skill Layer**: Validates inputs, prepares context, delegates to agent
4. **Agent Layer**: Executes work, creates artifacts, returns structured JSON
5. **Return Flow**: JSON propagated back through layers with validation
6. **Status Updates**: state.json and TODO.md updated after completion

The three-layer architecture provides:
- Clean separation of concerns
- Token-efficient context loading
- Language-based routing
- Standardized return format
- Resume support via partial status

---

## Related Documentation

- [Component Selection](../guides/component-selection.md) - When to create each component
- [Creating Skills](../guides/creating-skills.md) - Skill creation guide
- [Creating Agents](../guides/creating-agents.md) - Agent creation guide
- `.claude/context/core/formats/subagent-return.md` - Return format schema

---

**Document Version**: 1.0
**Created**: 2026-01-12
**Maintained By**: project Development Team
