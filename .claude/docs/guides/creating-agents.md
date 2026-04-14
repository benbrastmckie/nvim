# Creating Agents Guide

This guide explains how to create new agents in the Neovim Configuration agent system that handle full workflow execution and artifact creation.

---

## Overview

Agents are execution components that:
- Load domain-specific context on-demand
- Execute multi-step workflows
- Create artifacts in proper locations
- Return standardized JSON results

Agents are invoked by skills via the Task tool and never directly by users.

---

## Agent Responsibilities

### What Agents Do

```
Agent receives delegation context
    |
    v
Stage 1: Validate inputs (task exists, parameters valid)
    |
    v
Stage 2: Load required context files
    |
    v
Stage 3: Execute core workflow (research, plan, implement)
    |
    v
Stage 4: Generate outputs in required formats
    |
    v
Stage 5: Create artifacts in task directory
    |
    v
Stage 6: Format return as standardized JSON
    |
    v
Stage 7: Validate artifacts and update status
    |
    v
Stage 8: Cleanup and return
```

### What Agents Must Return

All agents MUST return valid JSON. Plain text responses cause validation failures:

```json
{
  "status": "completed|partial|failed|blocked",
  "summary": "Brief 2-5 sentence summary (<100 tokens)",
  "artifacts": [...],
  "metadata": {...},
  "errors": [...],
  "next_steps": "..."
}
```

---

## Agent File Location

Agents are located in `.claude/agents/{name}-agent.md`:

```
.claude/agents/
├── general-research-agent.md
├── neovim-research-agent.md
├── planner-agent.md
├── general-implementation-agent.md
├── neovim-implementation-agent.md
└── meta-builder-agent.md
```

**Note**: Additional agents (latex, typst, filetypes) are available via extensions in `.claude/extensions/`.

---

## Agent Template

### Header Section

```markdown
# {Name} Agent

## Overview

{Brief description of agent purpose and when it is invoked.}

## Agent Metadata

- **Name**: {name}-agent
- **Purpose**: {purpose}
- **Invoked By**: skill-{name} (via Task tool)
- **Return Format**: JSON (see subagent-return.md)

## Allowed Tools

This agent has access to:

### File Operations
- Read - Read source files and documentation
- Write - Create artifacts
- Edit - Modify existing files
- Glob - Find files by pattern
- Grep - Search file contents

### Build Tools (if applicable)
- Bash - Run verification commands

### Web Tools (if applicable)
- WebSearch - Search for documentation
- WebFetch - Retrieve web pages

## Context References

Load these on-demand using @-references:

**Always Load**:
- `@.claude/context/formats/subagent-return.md` - Return format schema

**Load When Creating Artifacts**:
- `@.claude/context/formats/report-format.md` (for research)
- `@.claude/context/standards/plan.md` (for planning)
```

### 8-Stage Workflow Section

Document all 8 stages of the workflow:

```markdown
## Execution Flow

### Stage 1: Parse Delegation Context

Extract from input:
```json
{
  "task_context": {
    "task_number": 412,
    "task_name": "create_agent",
    "description": "...",
    "task_type": "meta"
  },
  "metadata": {
    "session_id": "sess_...",
    "delegation_depth": 1,
    "delegation_path": [...]
  },
  "focus_prompt": "optional focus area"
}
```

### Stage 2: Context Loading

Based on task language and purpose:
- Load required context files
- Note: Use @-references for lazy loading

### Stage 3: Execute Core Workflow

{Describe the main work this agent performs}

### Stage 4: Output Generation

{Describe output formats and structure}

### Stage 5: Artifact Creation

Create directory and write artifacts:
- Path: `specs/{NNN}_{SLUG}/{type}/`
- Verify artifacts are non-empty

### Stage 6: Return Structured JSON

Return ONLY valid JSON matching subagent-return.md schema.

### Stage 7: Status Updates (CRITICAL)

**This stage is mandatory and often missed.**

Tasks:
1. Update TODO.md with task status
2. Update state.json with status
3. Create git commit for artifacts

### Stage 8: Cleanup

Release resources and log completion.
```

---

## Step-by-Step Guide

### Step 1: Create Agent File

Create `.claude/agents/{name}-agent.md`:

```markdown
# {Name} Agent

## Overview

{Brief description}

## Agent Metadata

- **Name**: {name}-agent
- **Purpose**: {purpose}
- **Invoked By**: skill-{name}
- **Return Format**: JSON
```

### Step 2: Define Allowed Tools

Specify which tools this agent can use:

```markdown
## Allowed Tools

### File Operations
- Read - Read source files and documentation
- Write - Create artifact files
- Edit - Modify existing files
- Glob - Find files by pattern
- Grep - Search file contents

### Build Tools
- Bash - Run commands (builds, tests, git)

### Web Tools
- WebSearch - Search for documentation
- WebFetch - Retrieve documentation pages
```

### Step 3: Document Context References

List context files to load on-demand:

```markdown
## Context References

**Always Load**:
- `@.claude/context/formats/subagent-return.md`

**Load When Needed**:
- `@.claude/context/formats/report-format.md` (for research)
- `@.claude/context/standards/plan.md` (for planning)
- `@.claude/context/project/neovim/tools/lazy-nvim-guide.md` (for Lean)
```

### Step 4: Implement 8-Stage Workflow

Document each stage in detail.

#### Stage 1: Parse Delegation Context

```markdown
### Stage 1: Parse Delegation Context

Extract from input:
```json
{
  "task_context": {
    "task_number": 450,
    "task_name": "add_async_runtime",
    "description": "Add async runtime support to API client",
    "task_type": "rust"
  },
  "metadata": {
    "session_id": "sess_1736700000_abc123",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "research", "{name}-agent"]
  },
  "focus_prompt": "tokio best practices"
}
```
```

#### Stage 2: Context Loading

```markdown
### Stage 2: Context Loading

Load context based on task task_type:

| Task Type | Context Files |
|----------|---------------|
| rust | `project/rust/tools.md` |
| neovim | `project/neovim/tools/lazy-nvim-guide.md` |
| general | `project/repo/project-overview.md` |
```

#### Stage 3: Core Execution

This is the main work of the agent. Be specific:

```markdown
### Stage 3: Execute Core Workflow

**For Research Agents**:
1. Search codebase for existing patterns (Glob/Grep)
2. Review relevant context files
3. Search web for documentation (WebSearch)
4. Fetch specific documentation pages (WebFetch)
5. Synthesize findings

**For Implementation Agents**:
1. Load implementation plan
2. Find resume point (if resuming)
3. Execute phases sequentially
4. Verify each phase before proceeding
5. Handle errors and rollback if needed
```

#### Stage 4: Output Generation

```markdown
### Stage 4: Output Generation

Format outputs according to standards:

**Research Report**:
- Follow `report-format.md` structure
- Include findings, recommendations, risks

**Implementation Summary**:
- Follow `summary.md` structure
- List files modified, verification results
```

#### Stage 5: Artifact Creation

```markdown
### Stage 5: Artifact Creation

Create directory structure:
```
specs/{NNN}_{SLUG}/
├── reports/
│   └── MM_{short-slug}.md
├── plans/
│   └── MM_{short-slug}.md
└── summaries/
    └── MM_{short-slug}-summary.md
```

Write artifacts and verify:
- File exists on disk
- File is non-empty
- File contains required sections
```

#### Stage 6: Return Format

```markdown
### Stage 6: Return Structured JSON

Return ONLY valid JSON matching this schema:

```json
{
  "status": "completed|partial|failed|blocked",
  "summary": "Brief 2-5 sentence summary (<100 tokens)",
  "artifacts": [
    {
      "type": "report|plan|summary|implementation",
      "path": "specs/{NNN}_{SLUG}/{type}/{file}.md",
      "summary": "Brief artifact description"
    }
  ],
  "metadata": {
    "session_id": "{from delegation context}",
    "duration_seconds": 123,
    "agent_type": "{name}-agent",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "{command}", "{name}-agent"]
  },
  "errors": [],
  "next_steps": "What user should do next"
}
```

**CRITICAL**: Return ONLY JSON. Plain text responses fail validation.
```

#### Stage 7: Status Updates

```markdown
### Stage 7: Status Updates (CRITICAL)

This stage is mandatory. Missing status updates cause synchronization issues.

**Tasks**:

1. **Validate Artifacts**:
   - Verify all artifact files exist
   - Verify files are non-empty
   - Verify files contain required sections

2. **Update TODO.md**:
   - Update task status marker
   - Add artifact links
   - Add completion timestamp

3. **Update state.json**:
   - Update task status field
   - Add last_updated timestamp
   - Add artifact paths to artifacts array

4. **Create Git Commit** (if appropriate):
   - Stage artifact files
   - Commit with message: `task {N}: {action}`

**Error Handling**:
- Artifact validation failure -> Return failed status
- TODO.md update failure -> Log error, continue
- state.json update failure -> Log error, continue
- Git commit failure -> Log error, continue (non-blocking)
```

#### Stage 8: Cleanup

```markdown
### Stage 8: Cleanup

1. Remove temporary files
2. Log completion
3. Return JSON result
```

### Step 5: Add Error Handling

Document error handling patterns:

```markdown
## Error Handling

### Network Errors

When WebSearch or WebFetch fails:
1. Log error but continue with local-only approach
2. Note limitation in report
3. Return `partial` if significant work was planned

### Timeout/Interruption

If operation times out:
1. Save partial progress to artifact
2. Return `partial` status
3. Include resume point in errors array

### Invalid Task

If task not found or status invalid:
1. Return `failed` immediately
2. Include clear error message
3. Recommend checking task status
```

### Step 6: Add Return Format Examples

Include complete examples:

```markdown
## Return Format Examples

### Completed Research

```json
{
  "status": "completed",
  "summary": "Found 8 patterns for agent implementation. Identified report-format.md standard and documented execution flow.",
  "artifacts": [
    {
      "type": "report",
      "path": "specs/412_create_agent/reports/01_create-agent-research.md",
      "summary": "Research report with 8 findings"
    }
  ],
  "metadata": {
    "session_id": "sess_1736689200_abc123",
    "duration_seconds": 180,
    "agent_type": "general-research-agent",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "research", "general-research-agent"],
    "findings_count": 8
  },
  "next_steps": "Run /plan 412 to create implementation plan"
}
```

### Failed with Error

```json
{
  "status": "failed",
  "summary": "Research failed: Task 999 not found in state.json.",
  "artifacts": [],
  "metadata": {
    "session_id": "sess_1736689200_xyz789",
    "duration_seconds": 5,
    "agent_type": "general-research-agent",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "research", "general-research-agent"]
  },
  "errors": [
    {
      "type": "validation",
      "message": "Task 999 not found in state.json",
      "recoverable": false,
      "recommendation": "Verify task number with /task --sync"
    }
  ],
  "next_steps": "Check task exists with /task --sync"
}
```
```

---

## Return Format Reference

### Status Values

| Status | Meaning | Artifacts? |
|--------|---------|------------|
| `completed` | Task fully completed | Yes, all required |
| `partial` | Some work done, can resume | Yes, partial |
| `failed` | Task failed, cannot proceed | No |
| `blocked` | External dependency blocking | No |

### Required Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `status` | enum | Yes | completed, partial, failed, blocked |
| `summary` | string | Yes | Brief summary (<100 tokens) |
| `artifacts` | array | Yes | List of created artifacts (can be empty) |
| `metadata` | object | Yes | Session and agent information |
| `errors` | array | No | List of errors (required if status != completed) |
| `next_steps` | string | No | Recommended next action |

### Metadata Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `session_id` | string | Must match delegation context |
| `agent_type` | string | Name of this agent |
| `delegation_depth` | integer | Current depth (usually 1) |
| `delegation_path` | array | Full path from orchestrator |

---

## Validation Checklist

Before finalizing a new agent, verify:

### 8-Stage Workflow
- [ ] Stage 1 (Input Validation) documented
- [ ] Stage 2 (Context Loading) documented with @-references
- [ ] Stage 3 (Core Execution) documented with specific steps
- [ ] Stage 4 (Output Generation) documented with formats
- [ ] Stage 5 (Artifact Creation) documented with paths
- [ ] Stage 6 (Return Format) documented with JSON schema
- [ ] **Stage 7 (Status Updates) documented** (CRITICAL)
- [ ] Stage 8 (Cleanup) documented

### Return Format
- [ ] Returns valid JSON only (not plain text)
- [ ] All required fields present
- [ ] Summary is <100 tokens
- [ ] Artifacts array lists all created files
- [ ] Metadata includes session_id from delegation
- [ ] Errors array populated for non-completed status

### Context Loading
- [ ] Uses @-references for lazy loading
- [ ] Lists specific files to load per stage
- [ ] No eager loading of large context files

### Error Handling
- [ ] Network errors handled
- [ ] Timeout errors handled
- [ ] Validation errors handled
- [ ] Each error case returns appropriate status

### Integration
- [ ] Corresponding skill exists in `.claude/skills/`
- [ ] Agent name follows `{domain}-{purpose}-agent` pattern
- [ ] Skill's `agent:` field matches this agent name

---

## Common Mistakes

### 1. Returning Plain Text Instead of JSON

**Wrong**:
```
Research completed successfully. Found 5 patterns. See report at ...
```

**Right**:
```json
{
  "status": "completed",
  "summary": "Found 5 patterns for implementation",
  "artifacts": [...],
  "metadata": {...}
}
```

### 2. Missing Stage 7 (Status Updates)

**Wrong**: Agent creates artifacts but never updates TODO.md or state.json.

**Right**: Agent explicitly updates both files and creates git commit.

### 3. Eager Context Loading

**Wrong**: Loading all context files at start of agent execution.

**Right**: Loading only needed context files on-demand during execution.

### 4. Missing session_id in Metadata

**Wrong**:
```json
{
  "metadata": {
    "agent_type": "research-agent"
  }
}
```

**Right**:
```json
{
  "metadata": {
    "session_id": "sess_1736689200_abc123",
    "agent_type": "research-agent",
    "delegation_depth": 1,
    "delegation_path": [...]
  }
}
```

### 5. Summary Too Long

**Wrong**: 500-word narrative explaining everything in detail.

**Right**: 2-5 sentences, <100 tokens, captures key points only.

---

## Current Agent Inventory

| Agent | Purpose | Invoked By |
|-------|---------|------------|
| `general-research-agent` | Web/codebase research | skill-researcher |
| `neovim-research-agent` | Neovim/plugin research | skill-neovim-research |
| `planner-agent` | Implementation planning | skill-planner |
| `general-implementation-agent` | General file implementation | skill-implementer |
| `neovim-implementation-agent` | Neovim configuration implementation | skill-neovim-implementation |
| `meta-builder-agent` | System building and task creation | skill-meta |

**Note**: Additional agents (latex, typst, filetypes) are available via extensions in `.claude/extensions/`.

---

## Related Documentation

- [Component Selection](component-selection.md) - When to create an agent
- [Creating Skills](creating-skills.md) - Creating the skill that invokes agent
- [Creating Commands](creating-commands.md) - Creating commands that invoke skills
- `.claude/context/formats/subagent-return.md` - Return format schema
- `.claude/docs/templates/agent-template.md` - Agent template

---

**Document Version**: 1.0
**Created**: 2026-01-12
**Maintained By**: Neovim Configuration Development Team
