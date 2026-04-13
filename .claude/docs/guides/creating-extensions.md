# Creating Extensions Guide

[Back to Docs](../README.md) | [Extension System](../architecture/extension-system.md) | [Adding Domains](adding-domains.md)

Step-by-step guide for creating a new domain extension for the .claude/ system.

---

## Overview

Extensions are self-contained packages that add domain-specific support (agents, skills, rules, context) to the .claude/ system. Extensions can be loaded/unloaded via Neovim picker (`<leader>ac`) without modifying core files.

**When to Create an Extension**:
- Adding support for a new language/framework (Rust, React, Go)
- Adding support for a specialized tool (Lean, Z3, Typst)
- Creating portable domain knowledge that can be shared across projects

---

## Quick Start

### 1. Create Extension Directory

```bash
mkdir -p .claude/extensions/your-domain/{agents,skills,rules,context/project/your-domain}
```

### 2. Create Required Files

```bash
# Required files
touch .claude/extensions/your-domain/manifest.json
touch .claude/extensions/your-domain/EXTENSION.md
touch .claude/extensions/your-domain/README.md

# Optional but recommended
touch .claude/extensions/your-domain/index-entries.json
```

### 3. Populate Files

Follow the templates below for each file type.

---

## File Templates

### manifest.json (Required)

```json
{
  "name": "your-domain",
  "version": "1.0.0",
  "description": "Your domain description for picker display",
  "language": "your-domain",
  "dependencies": [],
  "provides": {
    "agents": [
      "your-domain-research-agent.md",
      "your-domain-implementation-agent.md"
    ],
    "skills": [
      "skill-your-domain-research",
      "skill-your-domain-implementation"
    ],
    "commands": [],
    "rules": [
      "your-domain.md"
    ],
    "context": [
      "project/your-domain"
    ],
    "scripts": [],
    "hooks": []
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

**Field Reference**:

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Extension name (matches directory name) |
| `version` | Yes | Semantic version for update tracking |
| `description` | Yes | Shown in picker UI |
| `task_type` | Yes | Language code for orchestrator routing |
| `dependencies` | No | Extensions that must load first |
| `provides` | Yes | Lists all files/directories provided |
| `merge_targets` | Yes | Defines CLAUDE.md and index.json merging |
| `mcp_servers` | No | MCP server configs to merge |

### EXTENSION.md (Required)

Content injected into CLAUDE.md when loaded:

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

- Feature 1: Description or keymap
- Feature 2: Description or keymap
- Common pattern: Example usage
```

### README.md (Required)

Every extension must provide a `README.md` file in its root directory. This is the user-facing overview of the extension, distinct from `EXTENSION.md` (which is a snippet injected into `.claude/CLAUDE.md` when the extension is loaded).

Start from the canonical template: `.claude/templates/extension-readme-template.md`.

The template includes a **section-applicability matrix** that distinguishes simple extensions (latex, python, typst, z3) from complex extensions (filetypes, lean, formal, nvim, nix, web, epidemiology). Simple extensions omit sections they do not need (MCP Setup, Workflow diagram, Output Artifacts) and produce README files under ~120 lines. Complex extensions use the full structure.

**Required sections for all extensions**:
- Overview (with a task type / command table)
- Installation
- Skill-Agent Mapping
- Language Routing
- References (optional but encouraged)

**Required sections for complex extensions**:
- MCP Tool Setup (if the extension configures MCP servers)
- Commands (if the extension provides commands)
- Architecture tree
- Workflow diagram
- Output Artifacts
- Key Patterns
- Tool Dependencies

The doc-lint script at `.claude/scripts/check-extension-docs.sh` flags missing `README.md` files during verification.

### index-entries.json (Recommended)

Context file metadata for agent discovery:

```json
{
  "entries": [
    {
      "path": "context/project/your-domain/README.md",
      "description": "Overview of your domain context",
      "tags": ["your-domain", "overview"],
      "load_when": {
        "task_types": ["your-domain"],
        "agents": ["your-domain-research-agent", "your-domain-implementation-agent"]
      }
    },
    {
      "path": "context/project/your-domain/patterns/common-pattern.md",
      "description": "Common implementation patterns",
      "tags": ["your-domain", "patterns"],
      "load_when": {
        "task_types": ["your-domain"],
        "agents": ["your-domain-implementation-agent"]
      }
    },
    {
      "path": "context/project/your-domain/standards/style-guide.md",
      "description": "Coding style conventions",
      "tags": ["your-domain", "style"],
      "load_when": {
        "task_types": ["your-domain"],
        "agents": ["your-domain-implementation-agent"]
      }
    }
  ]
}
```

---

## Creating Agents

### Research Agent

Create `agents/your-domain-research-agent.md`:

```markdown
---
name: your-domain-research-agent
description: Research [Your Domain] tasks
model: opus
---

# Your Domain Research Agent

## Overview

Research agent for [Your Domain] tasks. Invoked by `skill-your-domain-research` via the orchestrator when task language is "your-domain".

## Context References

Load these on-demand using @-references:

**Always Load**:
- `@.claude/context/project/your-domain/README.md`
- `@.claude/context/project/your-domain/domain/overview.md`

**Load for Specific Topics**:
- `@.claude/context/project/your-domain/tools/tool-guide.md` - When researching tool usage
- `@.claude/context/project/your-domain/patterns/*.md` - When researching patterns

## Research Strategy

1. **Codebase Search**: Check local files for existing patterns
2. **Documentation**: Search official documentation
3. **Best Practices**: Find recommended approaches
4. **Implementation Options**: Identify viable solutions

## Execution Flow

### Stage 0: Initialize Early Metadata
Create metadata file before substantive work for recovery.

### Stage 1: Parse Delegation Context
Extract task_number, task_name, focus from input.

### Stage 2: Determine Search Strategy
Plan search based on task description and focus.

### Stage 3: Execute Searches
Run Grep/Glob for codebase, WebSearch for external resources.

### Stage 4: Synthesize Findings
Compile discoveries into coherent recommendations.

### Stage 5: Create Research Report
Write report to `specs/{NNN}_{SLUG}/reports/MM_{short-slug}.md`.

### Stage 6: Write Metadata File
Write completion status to `.return-meta.json`.

### Stage 7: Return Brief Summary
Return 3-6 bullet point summary (NOT JSON).

## Tool Usage

- **Read**: Load context files, examine existing code
- **Grep**: Search for patterns in codebase
- **Glob**: Find relevant files
- **WebSearch**: Find documentation and best practices
- **WebFetch**: Retrieve specific documentation pages
```

### Implementation Agent

Create `agents/your-domain-implementation-agent.md`:

```markdown
---
name: your-domain-implementation-agent
description: Implement [Your Domain] tasks from plans
---

# Your Domain Implementation Agent

## Overview

Implementation agent for [Your Domain] tasks. Invoked by `skill-your-domain-implementation` via the orchestrator when task language is "your-domain".

## Context References

Load these on-demand using @-references:

**Always Load**:
- `@.claude/context/project/your-domain/standards/style-guide.md`

**Load as Needed**:
- `@.claude/context/project/your-domain/patterns/*.md` - For implementation patterns
- `@.claude/context/project/your-domain/templates/*.md` - For boilerplate

## Verification Commands

```bash
# Build/compile command
your-tool build

# Test command
your-tool test

# Lint command
your-tool lint
```

## Execution Flow

### Stage 0: Initialize Early Metadata
Create metadata file for recovery.

### Stage 1: Parse Delegation Context
Extract task_number, plan_path, metadata_file_path.

### Stage 2: Load Implementation Plan
Read and parse the plan file.

### Stage 3: Find Resume Point
Identify first incomplete phase (NOT STARTED or PARTIAL).

### Stage 4: Execute Implementation Loop
For each phase:
1. Mark [IN PROGRESS] in plan file
2. Execute steps as documented
3. Run phase verification
4. Mark [COMPLETED] in plan file

### Stage 5: Run Final Verification
Run full build/test suite.

### Stage 6: Create Implementation Summary
Write summary to `specs/{NNN}_{SLUG}/summaries/`.

### Stage 7: Write Metadata File
Write completion status to `.return-meta.json`.

### Stage 8: Return Brief Summary
Return 3-6 bullet point summary (NOT JSON).

## Tool Usage

- **Read**: Load plan, context, existing files
- **Write**: Create new files
- **Edit**: Modify existing files
- **Bash**: Run build/test commands
```

---

## Creating Skills

### Research Skill

Create `skills/skill-your-domain-research/SKILL.md`:

```markdown
---
name: skill-your-domain-research
description: Conduct [Your Domain] research. Invoke for your-domain research tasks.
allowed-tools: Task, Bash, Edit, Read, Write
---

# Your Domain Research Skill

Thin wrapper that delegates to `your-domain-research-agent`.

## Invocation

Invoked by the orchestrator when:
- Command is `/research`
- Task language is "your-domain"

## Execution Flow

### GATE IN (Preflight)
1. Validate task exists and status allows research
2. Update state.json status to "researching"
3. Update TODO.md status marker
4. Create postflight marker file

### DELEGATE
5. Invoke `your-domain-research-agent` via Task tool with delegation context

### GATE OUT (Postflight)
6. Read metadata file from agent
7. Update state.json status to "researched"
8. Link research artifact in state.json
9. Update TODO.md with research link

### COMMIT
10. Git commit with message: `task {N}: complete research`
11. Cleanup postflight marker
12. Return summary to orchestrator
```

### Implementation Skill

Create `skills/skill-your-domain-implementation/SKILL.md`:

```markdown
---
name: skill-your-domain-implementation
description: Implement [Your Domain] changes from plans. Invoke for your-domain implementation.
allowed-tools: Task, Bash, Edit, Read, Write
---

# Your Domain Implementation Skill

Thin wrapper that delegates to `your-domain-implementation-agent`.

## Invocation

Invoked by the orchestrator when:
- Command is `/implement`
- Task language is "your-domain"

## Execution Flow

### GATE IN (Preflight)
1. Validate task exists and plan exists
2. Update state.json status to "implementing"
3. Update TODO.md status marker
4. Create postflight marker file

### DELEGATE
5. Invoke `your-domain-implementation-agent` via Task tool with delegation context

### GATE OUT (Postflight)
6. Read metadata file from agent
7. Update state.json status to "completed"
8. Link summary artifact in state.json
9. Update TODO.md with summary link and completion date

### COMMIT
10. Git commit with message: `task {N}: complete implementation`
11. Cleanup postflight marker
12. Return summary to orchestrator
```

---

## Creating Rules

Create `rules/your-domain.md`:

```markdown
# Your Domain Development Rules

## Path Pattern

Applies to: `path/to/your/files/**/*.ext`

## Coding Standards

### File Organization
- Organize files by [structure]
- Use [naming convention]

### Code Style
- Use [indentation] spaces
- Maximum line length: [N] characters
- [Other conventions]

### Naming Conventions
- Variables: [pattern]
- Functions: [pattern]
- Constants: [pattern]

### Error Handling
- [Error handling pattern]

## Common Patterns

### Pattern 1
```[language]
// Example code
```

## Related Context

Load for detailed patterns:
- `@.claude/context/project/your-domain/standards/style-guide.md`
- `@.claude/context/project/your-domain/patterns/common-pattern.md`
```

---

## Creating Context

### Directory Structure

```
context/project/your-domain/
├── README.md           # Overview and loading strategy
├── domain/
│   └── overview.md     # Core concepts
├── patterns/
│   └── common.md       # Implementation patterns
├── standards/
│   └── style-guide.md  # Coding conventions
└── tools/
    └── tool-guide.md   # Tool usage guide
```

### README.md Template

```markdown
# Your Domain Context

Domain knowledge for [Your Domain] development.

## Directory Structure

- domain/ - Core concepts and terminology
- patterns/ - Common implementation patterns
- standards/ - Coding conventions and style guide
- tools/ - Tool-specific guides

## Loading Strategy

**Always load** README.md first for overview.

| Task Type | Load These Files |
|-----------|-----------------|
| Research | domain/overview.md |
| Implementation | standards/style-guide.md, patterns/*.md |
| Setup | domain/overview.md, tools/tool-guide.md |

## Agent Context Loading

| Agent | Primary Context |
|-------|----------------|
| your-domain-research-agent | domain/*, tools/* |
| your-domain-implementation-agent | standards/*, patterns/* |
```

---

## Testing Your Extension

### 1. Load the Extension

Press `<leader>ac` and select your extension from the picker.

### 2. Verify Files are Installed

```bash
# Check agents
ls .claude/agents/your-domain-*-agent.md

# Check skills
ls .claude/skills/skill-your-domain-*/SKILL.md

# Check rules
ls .claude/rules/your-domain.md

# Check context
ls .claude/context/project/your-domain/

# Check CLAUDE.md injection
grep "extension_your_domain" .claude/CLAUDE.md

# Check index entries
grep "your-domain" .claude/context/index.json
```

### 3. Test Routing

Create a test task:
```
/task "Test your-domain feature" --language your-domain
```

Run research:
```
/research {task_number}
```

Verify:
- Orchestrator routes to `skill-your-domain-research`
- Research agent loads correct context
- Report is created successfully

### 4. Test Unload

Press `<leader>ac` and select your extension again to unload.

Verify:
- All copied files are removed
- CLAUDE.md section is removed
- Index entries are removed

---

## Troubleshooting

### Extension Not Appearing in Picker

1. Check manifest.json exists and is valid JSON:
   ```bash
   cat .claude/extensions/your-domain/manifest.json | jq .
   ```

2. Verify extension directory is in the correct location:
   ```bash
   ls .claude/extensions/your-domain/
   ```

### Load Fails with Conflicts

The loader detected existing files that would be overwritten. Either:
- Rename conflicting files in your extension
- Remove conflicting files from core (if safe)
- Check if another extension provides the same files

### Routing Not Working After Load

1. Check CLAUDE.md section was injected:
   ```bash
   grep "extension_your_domain" .claude/CLAUDE.md
   ```

2. Verify orchestrator knows about your language routing

3. Check skill files exist:
   ```bash
   ls .claude/skills/skill-your-domain-*/SKILL.md
   ```

### Context Not Loading

1. Verify index entries were added:
   ```bash
   jq '.entries[] | select(.path | contains("your-domain"))' .claude/context/index.json
   ```

2. Check agent references correct context paths

---

## Example Extensions

Refer to existing extensions for complete examples:

- `.claude/extensions/latex/` - LaTeX document development
- `.claude/extensions/lean/` - Lean theorem prover
- `.claude/extensions/typst/` - Typst document preparation

---

## Related Documentation

- [Extension System Architecture](../architecture/extension-system.md) - How the system works
- [Adding Domains](adding-domains.md) - When to use extensions vs core
- [Creating Agents](creating-agents.md) - Agent patterns
- [Creating Skills](creating-skills.md) - Skill patterns

---

[Back to Docs](../README.md) | [Extension System](../architecture/extension-system.md) | [Adding Domains](adding-domains.md)
