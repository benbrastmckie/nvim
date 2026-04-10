# Creating Commands Guide

## Overview

This guide provides a streamlined walkthrough for creating new task-based commands in the Neovim Configuration .opencode system.

## Prerequisites

Before creating a new command, understand:

1. **Task-Based Pattern**: Neovim Configuration uses task numbers from TODO.md, not topics
2. **Orchestrator-Mediated**: All task-based commands route through orchestrator
3. **Hybrid Architecture**: Orchestrator validates, subagents execute
4. **Language Routing**: Neovim tasks route to neovim-specific agents

**Required Reading**:
- `.claude/skills/skill-orchestrator/SKILL.md` - Orchestrator skill
- `.claude/context/formats/subagent-return.md` - Subagent return format
- [Creating Skills](creating-skills.md) - For skill delegation patterns
- [Creating Agents](creating-agents.md) - For agent implementation

## Neovim Configuration vs OpenAgents

**IMPORTANT**: Neovim Configuration has a different command pattern than OpenAgents.

| Aspect | Neovim Configuration | OpenAgents |
|--------|--------------|------------|
| **Arguments** | Task numbers (integers) | Topics (natural language) |
| **Workflow** | Task exists first | Creates new projects |
| **Validation** | TODO.md lookup required | No validation needed |
| **Routing** | Language-based (neovim vs general) | Keyword-based |
| **Example** | `/research 259` | `/research "modal logic"` |

**You cannot copy OpenAgents patterns directly to Neovim Configuration.**

## Step-by-Step Process

### Step 1: Understand the Hybrid Architecture

Neovim Configuration uses a **hybrid architecture** (v6.1):

**Orchestrator Responsibilities**:
1. Extract task number from `$ARGUMENTS`
2. Validate task exists in TODO.md
3. Extract language from task metadata
4. Route to appropriate subagent (neovim vs general)
5. Pass validated context to subagent

**Subagent Responsibilities**:
1. Receive validated inputs (task_number, language, task_description)
2. Update task status
3. Execute workflow
4. Return standardized result

**Why This Pattern?**:
- Only orchestrator has access to `$ARGUMENTS`
- Task validation prevents errors
- Language extraction enables routing
- Subagents receive clean, pre-validated inputs

### Step 2: Create Command File

Create `.claude/commands/{command-name}.md` with this structure:

**Task-Based Command Template**:

```markdown
---
name: {command-name}
agent: orchestrator
description: "{Brief description with status}"
timeout: 3600
routing:
  language_based: true
  neovim: neovim-{command}-agent
  default: {command}er
---

# /{command-name} - {Title}

{Brief description of what this command does}

## Usage

\`\`\`bash
/{command-name} TASK_NUMBER [PROMPT]
/{command-name} 196
/{command-name} 196 "Custom focus"
\`\`\`

## What This Does

1. Routes to appropriate agent based on task language
2. Agent executes workflow
3. Creates artifacts
4. Updates task status to [{STATUS}]
5. Creates git commit

## Task-Type-Based Routing

| Task Type | Agent | Tools |
|----------|-------|-------|
| neovim | neovim-{command}-agent | {neovim-specific tools} |
| general | {command}er | {general tools} |

See `.claude/agents/{agent}.md` for details.
```

**Key Points**:
- **MUST use `agent: orchestrator`** (not `agent: implementer` or direct agent!)
- Include `routing` configuration for task-type-based routing
- Keep documentation concise (<50 lines)

### Step 3: Create or Update Subagent

If creating a new subagent, follow this pattern:

**Step 0 Template** (Receives Validated Inputs):

```xml
<step_0_preflight>
  <action>Preflight: Extract validated inputs and update status</action>
  <process>
    1. Extract task inputs from delegation context (already validated by orchestrator):
       - task_number: Integer (already validated to exist in TODO.md)
       - language: String (already extracted from task metadata)
       - task_description: String (already extracted from TODO.md)
       - Example: task_number=259, language="neovim", task_description="..."
       
       NOTE: Orchestrator has already:
       - Validated task_number exists in TODO.md
       - Extracted language from task metadata
       - Extracted task description
       - Performed task-type-based routing
       
       No re-parsing or re-validation needed!
    
    2. Update status to [{STATUS}]:
       - Delegate to status-sync-manager
       - Validate status update succeeded
    
    3. Proceed to execution with validated inputs
  </process>
  <checkpoint>Task inputs extracted from validated context, status updated</checkpoint>
</step_0_preflight>
```

**Workflow Steps** (Steps 1-N):

Implement your specific workflow. Subagent has access to:
- `task_number`: Validated integer
- `language`: String ("neovim", "general", etc.)
- `task_description`: Full description from TODO.md

**Return Format**:

Must return JSON matching `subagent-return-format.md` schema:
```json
{
  "status": "completed|partial|failed|blocked",
  "summary": "Brief summary <100 tokens",
  "artifacts": [{"type": "...", "path": "...", "summary": "..."}],
  "metadata": {
    "session_id": "...",
    "duration_seconds": 123,
    "agent_type": "...",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "agent"]
  },
  "errors": [],
  "next_steps": "What user should do next"
}
```

### Step 4: Test Command

Test your new command:

```bash
# Find a test task
grep "^###" specs/TODO.md | head -5

# Test command
/{command-name} {task-number}

# Verify:
# 1. Orchestrator extracts task number from $ARGUMENTS
# 2. Orchestrator validates task exists
# 3. Orchestrator extracts language from TODO.md
# 4. Orchestrator routes to correct agent
# 5. Subagent receives validated context
# 6. Artifacts created
# 7. Status updated
# 8. Git commit created
```

## Architecture Flow

### How Commands Work (v6.1 Hybrid)

```
User types: /implement 259
  ↓
OpenCode reads command file: agent: orchestrator
  ↓
OpenCode invokes orchestrator with $ARGUMENTS = "259"
  ↓
Orchestrator Stage 1 (ExtractAndValidate):
  - Parse task_number from $ARGUMENTS: 259
  - Validate task 259 exists in TODO.md
  - Extract language: "neovim"
  - Extract task_description: "Configure LSP settings"
  ↓
Orchestrator Stage 2 (Route):
  - Check routing config: language_based = true
  - Map language "neovim" → agent "neovim-implementation-agent"
  - Prepare delegation context
  ↓
Orchestrator Stage 3 (Delegate):
  - Invoke neovim-implementation-agent with validated context:
    * task_number = 259
    * language = "neovim"
    * task_description = "Configure LSP settings"
  ↓
Subagent Step 0:
  - Extract validated inputs from delegation context
  - Update status to [IMPLEMENTING]
  - Proceed with validated inputs (no parsing!)
  ↓
Subagent executes workflow, returns result
  ↓
Orchestrator relays result to user
```

## Key Principles

1. **Orchestrator-Mediated**: All task-based commands route through orchestrator
2. **Validate Once**: Orchestrator validates, subagent receives clean inputs
3. **No Re-Parsing**: Subagent uses validated context, doesn't re-parse prompts
4. **Language Routing**: Orchestrator extracts language, routes to correct agent
5. **Clean Separation**: Orchestrator validates/routes, subagent executes
6. **No Version History**: NEVER add version history sections to commands or agents (useless cruft)

## Common Mistakes

### ❌ WRONG: Direct Invocation

```markdown
---
name: implement
agent: implementer  # WRONG! Bypasses orchestrator
---
```

**Problem**: OpenCode directly invokes implementer, bypassing orchestrator.
Implementer has no access to `$ARGUMENTS`, cannot extract task number.

### ❌ WRONG: Subagent Parses Prompt

```xml
<step_0_preflight>
  <process>
    1. Parse task number from prompt string  # WRONG! Orchestrator already did this
    2. Validate task exists  # WRONG! Already validated
  </process>
</step_0_preflight>
```

**Problem**: Duplicate parsing, duplicate validation. Fragile and inefficient.

### ✅ CORRECT: Use Validated Inputs

```markdown
---
name: implement
agent: orchestrator  # CORRECT! Routes through orchestrator
routing:
  language_based: true
  neovim: neovim-implementation-agent
  default: implementer
---
```

```xml
<step_0_preflight>
  <process>
    1. Extract validated inputs from delegation context  # CORRECT!
       - task_number, language, task_description
    2. Update status
    3. Proceed with validated inputs
  </process>
</step_0_preflight>
```

## Examples

See existing implementations:
- `.claude/commands/implement.md` - Language-based command
- `.claude/commands/research.md` - Language-based command
- `.claude/commands/plan.md` - Language-based command
- `.claude/skills/skill-orchestrator/SKILL.md` - Orchestrator skill
- `.claude/skills/skill-implementer/SKILL.md` - General implementer skill
- `.claude/agents/general-implementation-agent.md` - General implementation agent
- `.claude/agents/neovim-implementation-agent.md` - Neovim-specific agent

## Related Guides

- [Component Selection](component-selection.md) - When to create a command vs skill vs agent
- [Creating Skills](creating-skills.md) - How to create skills that commands delegate to
- [Creating Agents](creating-agents.md) - How to create agents that skills invoke

## Troubleshooting

**"Task number not provided"**:
- Check command file has `agent: orchestrator` (not direct agent)
- Orchestrator extracts from `$ARGUMENTS`, subagent receives validated context

**"Task not found"**:
- Task number doesn't exist in TODO.md
- Orchestrator validates this in Stage 1

**Wrong agent invoked**:
- Check routing configuration in command frontmatter
- Check task_type field in TODO.md task entry
- Orchestrator uses language to route to correct agent

**Subagent can't access task_number**:
- Check Step 0 extracts from delegation_context
- Orchestrator passes validated context as parameters
