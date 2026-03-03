# Component Selection Guide

This guide helps you decide which component type to create when adding new capabilities to the Neovim Configuration agent system.

---

## Overview: Three-Layer Architecture

The Neovim Configuration system uses a three-layer architecture where each layer has distinct responsibilities:

```
Layer 1: Commands         User-facing entry points (/research, /plan, /implement)
    |
    v
Layer 2: Skills           Specialized execution logic with input validation
    |
    v
Layer 3: Agents           Full execution agents that do the actual work
```

### Quick Summary

| Component | Location | Purpose | User-Facing? |
|-----------|----------|---------|--------------|
| Command | `.claude/commands/` | User invocation point | Yes |
| Skill | `.claude/skills/skill-*/SKILL.md` | Routing and validation | No |
| Agent | `.claude/agents/*.md` | Execution and artifact creation | No |

---

## Decision Tree

Use this decision tree to determine which component(s) to create:

```
START: What capability do you need?
    |
    |-- User needs to invoke via slash command?
    |       |
    |       YES --> Create Command (Layer 1)
    |                   |
    |                   |-- Does it need specialized execution logic?
    |                           |
    |                           YES --> Also create Skill + Agent (Layers 2-3)
    |                           |
    |                           NO --> Command can delegate to existing skill
    |
    |-- Adding new language/domain support?
    |       |
    |       YES --> Create Skill + Agent pair (Layers 2-3)
    |               (Commands already exist for standard workflows)
    |
    |-- Need reusable execution logic?
            |
            YES --> Create Agent only (Layer 3)
                    (Existing skills can invoke it)
```

### Practical Decision Questions

Answer these questions to determine what to create:

1. **"Can users type something to trigger this?"**
   - Yes -> You need a Command
   - No -> Skip to question 2

2. **"Does this need different handling based on task language?"**
   - Yes -> You need a Skill (for routing logic)
   - No -> Skip to question 3

3. **"Does this need to execute multi-step work and create artifacts?"**
   - Yes -> You need an Agent
   - No -> Existing components may suffice

---

## When to Create Each Component

### Create a Command When...

You need a new user-invocable operation that does not exist yet.

**Good candidates**:
- New workflow operations (like `/analyze` or `/migrate`)
- Operations that span multiple tasks
- User-facing utilities

**Examples**:
| Command | Purpose |
|---------|---------|
| `/task` | Create, manage, sync tasks |
| `/research` | Conduct task research |
| `/implement` | Execute implementation |

**Do NOT create a command when**:
- You are just adding a new language variant (create skill + agent instead)
- The operation already exists (extend existing command)
- It is an internal-only capability (create skill/agent only)

### Create a Skill When...

You need to add routing logic or input validation for execution.

**Good candidates**:
- New language support (e.g., `skill-python-research`)
- Specialized domain handling (e.g., `skill-database-implementation`)
- Thin wrapper for delegation with validation

**Examples**:
| Skill | Purpose |
|-------|---------|
| `skill-neovim-research` | Neovim/plugin research via web search |
| `skill-researcher` | General web/codebase research |
| `skill-status-sync` | Atomic multi-file status updates |

**Do NOT create a skill when**:
- The execution is simple (no validation needed)
- An existing skill already handles your use case
- You need only an agent (skills require corresponding agents)

### Create an Agent When...

You need to implement actual execution logic that creates artifacts.

**Good candidates**:
- Full research workflows for a new domain
- Implementation workflows for a new language
- Complex multi-step execution with artifact creation

**Examples**:
| Agent | Purpose |
|-------|---------|
| `neovim-research-agent` | Neovim configuration research via web search |
| `general-implementation-agent` | General file implementation |
| `planner-agent` | Implementation plan creation |

**Do NOT create an agent when**:
- The execution is trivial (embed in skill)
- An existing agent can be extended
- No artifacts are created

---

## Component Combinations

Most capabilities require multiple components working together:

### Common Patterns

**Pattern 1: New User Workflow**
```
/analyze command
    |
    v
skill-analyzer (new)
    |
    v
general-analysis-agent (new)
```
Creates: Command + Skill + Agent

**Pattern 2: New Language Support**
```
/research (existing)
    |
    v
skill-python-research (new)
    |
    v
python-research-agent (new)
```
Creates: Skill + Agent (command exists)

**Pattern 3: New Domain Agent**
```
/implement (existing)
    |
    v
skill-implementer (existing)
    |
    v
database-implementation-agent (new)
```
Creates: Agent only (skill routes to it)

---

## Component Responsibilities

### Commands

**MUST DO**:
- Parse and validate `$ARGUMENTS`
- Provide clear usage documentation
- Specify target skill/agent in frontmatter
- Include examples

**MUST NOT**:
- Execute complex logic
- Create artifacts directly
- Access external systems
- Exceed 300 lines

### Skills

**MUST DO**:
- Validate inputs before delegation
- Prepare delegation context
- Route to appropriate agent
- Validate agent returns

**MUST NOT**:
- Load heavy context (use `context: fork`)
- Execute implementation logic
- Create artifacts (delegate to agent)
- Skip return validation

### Agents

**MUST DO**:
- Load required context on-demand
- Execute full workflow
- Create artifacts in proper locations
- Return standardized JSON format
- Include session_id in metadata

**MUST NOT**:
- Be invoked directly by users
- Skip return format requirements
- Create artifacts without verification
- Ignore error handling

---

## File Location Reference

```
.claude/
├── commands/                    # Layer 1: User commands
│   └── {command-name}.md
├── skills/                      # Layer 2: Execution skills
│   └── skill-{name}/
│       └── SKILL.md
└── agents/                      # Layer 3: Execution agents
    └── {name}-agent.md
```

### Naming Conventions

| Component | Pattern | Example |
|-----------|---------|---------|
| Command | `{verb}.md` | `research.md`, `implement.md` |
| Skill | `skill-{purpose}/SKILL.md` | `skill-neovim-research/SKILL.md` |
| Agent | `{domain}-{purpose}-agent.md` | `neovim-research-agent.md` |

---

## Current Inventory

### Commands (9)

| Command | Skill(s) Used |
|---------|---------------|
| /task | skill-status-sync |
| /research | skill-researcher, skill-neovim-research |
| /plan | skill-planner |
| /implement | skill-implementer, skill-neovim-implementation |
| /revise | skill-planner |
| /review | (direct execution) |
| /errors | (direct execution) |
| /todo | (direct execution) |
| /meta | skill-meta |

**Note**: Additional skills (latex, typst, document-converter) available via extensions.

### Skills (Core)

| Skill | Agent |
|-------|-------|
| skill-orchestrator | (routing only) |
| skill-status-sync | (direct execution) |
| skill-git-workflow | (direct execution) |
| skill-researcher | general-research-agent |
| skill-neovim-research | neovim-research-agent |
| skill-planner | planner-agent |
| skill-implementer | general-implementation-agent |
| skill-neovim-implementation | neovim-implementation-agent |
| skill-meta | meta-builder-agent |

**Note**: Additional skills (latex, typst, document-converter) available via extensions.

### Agents (Core)

| Agent | Purpose |
|-------|---------|
| general-research-agent | General web/codebase research |
| neovim-research-agent | Neovim/plugin research |
| planner-agent | Implementation planning |
| general-implementation-agent | General file implementation |
| neovim-implementation-agent | Neovim configuration implementation |
| meta-builder-agent | System building and task creation |

**Note**: Additional agents (latex, typst, document-converter) available via extensions.

---

## Examples

### Example 1: Adding Python Support

**Goal**: Support Python tasks with language-specific tooling

**Components needed**:
1. `skill-python-research/SKILL.md` - Routes Python tasks to Python agent
2. `python-research-agent.md` - Uses Python-specific tools

**No command needed** - existing `/research` routes by language

### Example 2: Adding Code Review Command

**Goal**: New `/review-pr` command for PR reviews

**Components needed**:
1. `review-pr.md` command - User entry point
2. `skill-pr-reviewer/SKILL.md` - Validation and delegation
3. `pr-review-agent.md` - GitHub API integration, artifact creation

### Example 3: Adding Git Integration

**Goal**: Consistent git commits across all workflows

**Components needed**:
1. `skill-git-workflow/SKILL.md` - Commit creation skill

**No agent needed** - skill handles direct execution

---

## Anti-Patterns

### 1. Overloaded Commands

**Wrong**: Command file >300 lines with embedded logic
```markdown
# /mega-command
## This command does everything
[500 lines of logic]
```

**Right**: Command delegates to skill/agent
```markdown
---
agent: orchestrator
routing:
  default: skill-mega
---
# /mega-command
Brief description and usage only.
```

### 2. Skills Without Agents

**Wrong**: Skill contains full execution logic
```markdown
# skill-processor
[300 lines of processing logic, artifact creation]
```

**Right**: Skill delegates to agent
```markdown
---
context: fork
agent: processor-agent
---
# skill-processor
Validation and delegation only.
```

### 3. Agent Without Return Format

**Wrong**: Agent returns plain text
```
Research completed successfully. Found 5 patterns.
```

**Right**: Agent returns structured JSON
```json
{
  "status": "completed",
  "summary": "Found 5 patterns",
  "artifacts": [...],
  "metadata": {...}
}
```

---

## Related Documentation

- [Creating Commands](creating-commands.md) - Command creation guide
- [Creating Skills](creating-skills.md) - Skill creation guide
- [Creating Agents](creating-agents.md) - Agent creation guide
- [Integration Examples](../examples/research-flow-example.md) - End-to-end flow example

---

**Document Version**: 1.0
**Created**: 2026-01-12
**Maintained By**: Neovim Configuration Development Team
