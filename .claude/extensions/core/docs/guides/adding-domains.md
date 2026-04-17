# Adding New Domains Guide

[Back to Docs](../README.md) | [Extension System](../architecture/extension-system.md) | [Creating Extensions](creating-extensions.md)

Step-by-step guide for adding new domain contexts, agents, and skills to the .claude/ system.

---

## Choosing Your Approach

The .claude/ system supports two approaches for adding domain support:

| Approach | Use When | Portability | Complexity |
|----------|----------|-------------|------------|
| **Extension** (Recommended) | Adding any new domain | High - portable across projects | Moderate - self-contained package with optional dependencies |
| **Core** | Primary project domain only | Low - embedded in repository | Simple - direct integration |

### Decision Tree

```
Is this the repository's PRIMARY domain?
├── YES (e.g., python in a Python project)
│   └── Use Core Approach
└── NO (e.g., latex, lean, rust, react)
    └── Use Extension Approach (Recommended)
```

**Why Extensions?**
- Extensions are self-contained packages that can be loaded/unloaded
- Extensions can declare dependencies on other extensions for shared resources
- Extensions are portable across projects without modification
- Extensions keep the core system clean and focused
- Extensions can be versioned and shared independently

---

## Extension Approach (Recommended)

For most new domains, create an extension. Extensions live in `.claude/extensions/{domain}/` and are loaded via the the extension picker.

### Directory Structure

```
.claude/extensions/your-domain/
├── manifest.json              # Extension metadata (required)
├── EXTENSION.md               # CLAUDE.md merge content (required)
├── index-entries.json         # Context index entries (optional)
├── settings-fragment.json     # MCP server configs (optional)
├── agents/                    # Domain agents
│   ├── your-domain-research-agent.md
│   └── your-domain-implementation-agent.md
├── skills/                    # Domain skills
│   ├── skill-your-domain-research/SKILL.md
│   └── skill-your-domain-implementation/SKILL.md
├── rules/                     # Auto-applied rules
│   └── your-domain.md
├── commands/                  # Domain commands (optional)
│   └── your-command.md
├── context/                   # Domain knowledge
│   └── project/your-domain/
│       ├── README.md
│       ├── domain/
│       ├── patterns/
│       ├── standards/
│       └── tools/
└── scripts/                   # Helper scripts (optional)
```

### manifest.json Format

The manifest declares what the extension provides:

```json
{
  "name": "your-domain",
  "version": "1.0.0",
  "description": "Domain description for picker display",
  "task_type": "your-domain",
  "dependencies": [],
  "provides": {
    "agents": ["your-domain-research-agent.md", "your-domain-implementation-agent.md"],
    "skills": ["skill-your-domain-research", "skill-your-domain-implementation"],
    "commands": [],
    "rules": ["your-domain.md"],
    "context": ["project/your-domain"],
    "scripts": [],
    "hooks": []
  },
  "routing": {
    "research": {
      "your-domain": "skill-your-domain-research"
    },
    "implement": {
      "your-domain": "skill-your-domain-implement"
    }
  },
  "merge_targets": {
    "claudemd": {
      "source": "EXTENSION.md",
      "target": ".claude/CLAUDE.md",
      "section_id": "extension_your_domain"
    },
    "index": {
      "source": "index-entries.json",
      "target": ".claude/context/index.json"
    }
  },
  "mcp_servers": {}
}
```

### EXTENSION.md Format

Content injected into CLAUDE.md when extension is loaded:

```markdown
## Your Domain Extension

This project includes [Your Domain] support via the your-domain extension.

### Language Routing

| Task Type | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `your-domain` | WebSearch, WebFetch, Read | Read, Write, Edit, Bash (your-tool) |

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-your-domain-research | your-domain-research-agent | [Your Domain] research |
| skill-your-domain-implementation | your-domain-implementation-agent | [Your Domain] implementation |

### Quick Reference

- [Key feature 1]
- [Key feature 2]
```

### index-entries.json Format

Entries appended to the main context index:

```json
{
  "entries": [
    {
      "path": "context/project/your-domain/patterns/common-pattern.md",
      "description": "Common patterns for your domain",
      "tags": ["your-domain", "patterns"],
      "load_when": {
        "task_types": ["your-domain"],
        "agents": ["your-domain-implementation-agent"]
      }
    }
  ]
}
```

### Load/Unload Mechanism

Extensions are managed via the extension picker:

1. **Loading**: Open the extension picker, select extension, files are copied into core
2. **Unloading**: Open the extension picker, select loaded extension, copied files are removed

When loaded:
- Agents copied to `.claude/agents/`
- Skills copied to `.claude/skills/`
- Rules copied to `.claude/rules/`
- Commands copied to `.claude/commands/`
- Context copied to `.claude/context/`
- EXTENSION.md section injected into CLAUDE.md
- Index entries appended to index.json
- Settings merged into settings.json

When unloaded:
- All copied files removed
- CLAUDE.md section removed
- Index entries removed
- Settings unmerged

### Creating Your Extension

See [Creating Extensions](creating-extensions.md) for a complete step-by-step guide.

---

## Core Approach (Primary Domain Only)

Use this approach only for the repository's primary domain (e.g., python for a Python project). Core domains are always available without loading.

### Architecture

```
Command (/research, /implement)
    │
    ▼
Orchestrator (skill-orchestrator)
    │
    ├── task_type: your-domain → skill-your-domain-research / skill-your-domain-implementation
    ├── task_type: general    → skill-researcher / skill-implementer
    └── task_type: meta       → skill-researcher / skill-implementer
```

Each task type routes to specialized skills, which delegate to specialized agents.

### Step 1: Create Domain Context Directory

Create the context directory structure:

```bash
mkdir -p .claude/context/project/your-domain/{domain,patterns,standards,tools,templates}
```

#### Required Files

**README.md** - Overview and loading strategy:
```markdown
# Your Domain Context

Domain knowledge for [Your Domain] development.

## Directory Structure
- domain/ - Core concepts
- patterns/ - Common implementation patterns
- standards/ - Coding conventions
- tools/ - Tool-specific guides
- templates/ - Boilerplate templates

## Loading Strategy
- Always load README.md first
- Load domain/*.md for core concepts
- Load patterns/*.md for implementation work

## Agent Context Loading
| Task Type | Required Context |
|-----------|-----------------|
| Setup | domain/overview.md, patterns/setup.md |
| Feature | patterns/feature-pattern.md |
```

### Step 2: Create Domain Agents

Create research and implementation agents in `.claude/agents/`:

**your-domain-research-agent.md**:
```markdown
---
name: your-domain-research-agent
description: Research [Your Domain] tasks
---

# Your Domain Research Agent

## Overview
Research agent for [Your Domain] tasks. Invoked by `skill-your-domain-research`.

## Context References
Load these on-demand:
- `@.claude/context/project/your-domain/README.md`
- `@.claude/context/project/your-domain/domain/overview.md`

## Execution Flow
[Standard research agent stages]
```

**your-domain-implementation-agent.md**:
```markdown
---
name: your-domain-implementation-agent
description: Implement [Your Domain] tasks from plans
---

# Your Domain Implementation Agent

## Overview
Implementation agent for [Your Domain] tasks. Invoked by `skill-your-domain-implementation`.

## Context References
Load these on-demand:
- `@.claude/context/project/your-domain/standards/style-guide.md`
- `@.claude/context/project/your-domain/patterns/common-pattern.md`

## Verification Commands
```bash
your-tool --check
```

## Execution Flow
[Standard implementation agent stages]
```

### Step 3: Create Domain Skills

Create skill wrappers in `.claude/skills/`:

**skill-your-domain-research/SKILL.md**:
```markdown
---
name: skill-your-domain-research
description: Conduct [Your Domain] research. Invoke for your-domain research tasks.
allowed-tools: Task, Bash, Edit, Read, Write
---

# Your Domain Research Skill

Thin wrapper that delegates to `your-domain-research-agent`.

## Execution Flow
1. Validate task exists and task_type matches
2. Update status to "researching"
3. Invoke your-domain-research-agent via Task tool
4. Update status to "researched"
5. Git commit
```

**skill-your-domain-implementation/SKILL.md**:
```markdown
---
name: skill-your-domain-implementation
description: Implement [Your Domain] changes from plans. Invoke for your-domain implementation.
allowed-tools: Task, Bash, Edit, Read, Write
---

# Your Domain Implementation Skill

Thin wrapper that delegates to `your-domain-implementation-agent`.

## Execution Flow
1. Validate task exists and plan exists
2. Update status to "implementing"
3. Invoke your-domain-implementation-agent via Task tool
4. Update status to "completed"
5. Git commit
```

### Step 4: Create Domain Rule

Create a rule file in `.claude/rules/`:

**your-domain.md**:
```markdown
# Your Domain Development Rules

## Path Pattern
Applies to: `your-path/**/*.ext`

## Coding Standards
### Naming Conventions
- [Convention 1]

### Code Organization
[Organization rules]

## Related Context
Load for detailed patterns:
- `@.claude/context/project/your-domain/standards/style-guide.md`
```

### Step 5: Update Routing

#### Update skill-orchestrator

Edit `.claude/skills/skill-orchestrator/SKILL.md`:

```markdown
### Task-Type-Based Routing

| Task Type | Research Skill | Implementation Skill |
|----------|---------------|---------------------|
| {domain} | skill-{domain}-research | skill-{domain}-implementation |
| your-domain | skill-your-domain-research | skill-your-domain-implementation |
| general | skill-researcher | skill-implementer |
```

#### Update CLAUDE.md

Add to Task-Type-Based Routing table:
```markdown
| `your-domain` | WebSearch, Read | Read, Write, Edit, Bash (your-tool) |
```

Add to Skill-to-Agent Mapping:
```markdown
| skill-your-domain-research | your-domain-research-agent | [Your Domain] research |
| skill-your-domain-implementation | your-domain-implementation-agent | [Your Domain] implementation |
```

Add to Rules References:
```markdown
- @.claude/rules/your-domain.md - [Your Domain] development (your-path/**)
```

### Step 6: Update Context Index

Add entries to `.claude/context/index.json`:

```json
{
  "path": "context/project/your-domain/domain/overview.md",
  "description": "Core concepts",
  "tags": ["your-domain", "domain"],
  "load_when": {
    "task_types": ["your-domain"],
    "agents": ["your-domain-research-agent", "your-domain-implementation-agent"]
  }
}
```

---

## Verification Checklist

### Extension Approach

- [ ] manifest.json created with correct structure
- [ ] EXTENSION.md created with routing/mapping tables
- [ ] index-entries.json created (if context files exist)
- [ ] Agents created in extension agents/ directory
- [ ] Skills created in extension skills/ directory
- [ ] Rules created in extension rules/ directory
- [ ] Context files created in extension context/ directory
- [ ] Extension loads successfully via picker
- [ ] Routing works after loading
- [ ] Extension unloads cleanly

### Core Approach

- [ ] Context directory created with README.md
- [ ] Domain context files populated
- [ ] Research agent created
- [ ] Implementation agent created
- [ ] Research skill created
- [ ] Implementation skill created
- [ ] Rule file created
- [ ] Orchestrator routing updated
- [ ] CLAUDE.md updated
- [ ] Context index updated
- [ ] Test with `/task "Test" --task-type your-domain`

---

## Related Documentation

- [Extension System Architecture](../architecture/extension-system.md) - How the extension system works
- [Creating Extensions](creating-extensions.md) - Step-by-step extension creation guide
- [Creating Agents](creating-agents.md) - Agent creation patterns
- [Creating Skills](creating-skills.md) - Skill creation patterns
- [Component Selection](component-selection.md) - Choosing commands vs skills vs agents

---

[Back to Docs](../README.md) | [Extension System](../architecture/extension-system.md) | [Creating Extensions](creating-extensions.md)
