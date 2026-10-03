# Creating Extensions Guide

[Back to Docs](../README.md) | [Extension System](../architecture/extension-system.md) | [Adding Domains](adding-domains.md)

Step-by-step guide for creating a new domain extension for the .claude/ system.

---

## Overview

Extensions are self-contained packages that add domain-specific support (agents, skills, rules, context) to the .claude/ system. Extensions can be loaded/unloaded via the extension picker without modifying core files. Extensions can optionally declare dependencies on other extensions for shared resources.

**When to Create an Extension**:
- Adding support for a new language/framework (Rust, React, Go)
- Adding support for a specialized tool (Lean, Z3, Typst)
- Creating portable domain knowledge that can be shared across projects

---

## Quick Start

### 1. Create Extension Directory

```bash
mkdir -p agent-system/extensions/your-domain/{agents,skills,rules,context/project/your-domain}
```

### 2. Create Required Files

```bash
# Required files
touch agent-system/extensions/your-domain/manifest.json
touch agent-system/extensions/your-domain/EXTENSION.md
touch agent-system/extensions/your-domain/README.md

# Optional but recommended
touch agent-system/extensions/your-domain/index-entries.json
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
  "task_type": "your-domain",
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
    "hooks": [],
    "docs": [],
    "templates": [],
    "systemd": [],
    "root_files": [],
    "data": []
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
  }
}
```

**On `mcp_servers`**: omit it. It is inert -- not consumed by the loader -- and a template that
included it would only invite a copy-paste author to reproduce a dead field. If your extension
uses an MCP server, register it in user-scope `~/.claude.json` (host-level activation block or a
`core/scripts/` setup script) and grant its tools in your `settings-fragment.json`'s
`permissions.allow`. See [MCP Server Ownership](../../context/patterns/mcp-server-ownership.md).

**Field Reference**:

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Extension name (matches directory name) |
| `version` | Yes | Semantic version for update tracking |
| `description` | Yes | Shown in picker UI |
| `task_type` | No | Language code for orchestrator routing (omit for resource-only extensions) |
| `dependencies` | No | Extensions that must load first (auto-loaded silently) |
| `provides` | Yes | Lists all files/directories provided |
| `merge_targets` | Yes | Defines CLAUDE.md and index.json merging |
| `mcp_servers` | No | Inert -- not consumed by the loader; MCP servers are registered in user-scope `~/.claude.json`, never via a manifest field. See [MCP Server Ownership](../../context/patterns/mcp-server-ownership.md). |

For the complete manifest schema with all field descriptions and examples, see [Extension System Architecture](../architecture/extension-system.md#manifest-schema).

### EXTENSION.md (Required)

Content included in CLAUDE.md via `generate_claudemd()` when loaded:

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

Every extension must provide a `README.md` file in its root directory. This is the user-facing overview of the extension, distinct from `EXTENSION.md` (which is included in `.claude/CLAUDE.md` via `generate_claudemd()` when the extension is loaded).

Start from the canonical template: `.claude/templates/extension-readme-template.md`.

The template includes a **section-applicability matrix** that distinguishes simple extensions (latex, python, typst, z3) from complex extensions (filetypes, lean, formal, nix, web, epidemiology). Simple extensions omit sections they do not need (MCP Setup, Workflow diagram, Output Artifacts) and produce README files under ~120 lines. Complex extensions use the full structure.

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

## Resource-Only Extensions

Extensions that provide only shared context (no agents, skills, commands, or routing) are called resource-only extensions. They exist to share resources between other extensions.

**Example**: The `slidev` extension provides Slidev animation patterns and CSS style presets consumed by `founder` and `present`:

```json
{
  "name": "slidev",
  "version": "1.0.0",
  "description": "Shared Slidev animation patterns and CSS style presets",
  "dependencies": [],
  "provides": {
    "agents": [], "skills": [], "commands": [],
    "rules": [], "context": ["project/slidev"],
    "scripts": [], "hooks": []
  },
  "merge_targets": {
    "index": { "source": "index-entries.json", "target": ".claude/context/index.json" }
  }
}
```

Consuming extensions declare the dependency: `"dependencies": ["slidev"]`. When founder or present is loaded, slidev is auto-loaded first if not already present.

**Key characteristics**:
- No `task_type` field (no routing)
- No `EXTENSION.md` or `claudemd` merge target (nothing included in CLAUDE.md)
- Only `provides.context` populated
- Loaded automatically as a dependency, not typically selected directly

For complete resource-only extension patterns, see [Extension System Architecture](../architecture/extension-system.md).

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
allowed-tools: Agent, Bash, Edit, Read, Write
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
5. Invoke `your-domain-research-agent` via Agent tool with delegation context

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
allowed-tools: Agent, Bash, Edit, Read, Write
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
5. Invoke `your-domain-implementation-agent` via Agent tool with delegation context

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

Press the extension picker and select your extension from the picker.

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

# Check CLAUDE.md content was included
grep "Your Domain Extension" .claude/CLAUDE.md

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

Press the extension picker and select your extension again to unload.

Verify:
- All copied files are removed
- CLAUDE.md section is removed
- Index entries are removed

---

## Lifecycle Hooks

Extensions can declare **lifecycle hook scripts** in `manifest.json` under a top-level `hooks` object. These hooks are invoked by `skill-base.sh` at specific points in the skill execution lifecycle, before and after agent delegation.

### Hooks vs. provides.hooks

**Important distinction**: Two different `hooks` concepts exist in manifests:

| Field | Purpose | Example |
|-------|---------|---------|
| `"hooks": {}` (top-level) | Lifecycle hook scripts called by skill-base.sh | `{"preflight": "scripts/my-check.sh"}` |
| `"provides": { "hooks": [] }` | File-copy targets deployed to `.claude/hooks/` | `["log-session.sh", "post-command.sh"]` |

Top-level `hooks` are NOT copied anywhere — they are called in-place from the extension directory.

### Hook Schema

Add a `hooks` object to your manifest:

```json
{
  "name": "your-domain",
  ...
  "hooks": {
    "preflight": "scripts/your-domain-preflight.sh",
    "context_injection": "scripts/your-domain-context.sh",
    "verification": "scripts/your-domain-verify.sh",
    "postflight": "scripts/your-domain-postflight.sh"
  }
}
```

All hooks are optional. Missing keys (or `"hooks": {}`) are silently skipped.

**Path resolution**: a hook's manifest value is resolved by **basename** against the deployed
`.claude/scripts/` directory -- never against a nested path under the extension's own deployed
directory. The deploy pipeline flattens `manifest.provides.scripts` into `.claude/scripts/`, so
there is no `.claude/extensions/<name>/scripts/` subdirectory for any extension to resolve
against. This means a hook's script **must also be declared in `provides.scripts`** to be
deployed at all -- a hook value with no matching `provides.scripts` entry resolves to a path
that is never written by the deploy. The conventional `scripts/your-domain-preflight.sh` value
(mirroring the source layout) is accepted, and so is a bare filename with no prefix -- both
resolve to the same deployed file by basename. This was the trap that left two shipped
extensions' hooks dead: a syntactically valid `hooks` entry whose script simply never deployed to
where the resolver looked for it.

### Hook Execution Contract

Hook scripts receive 5 positional arguments:

| Arg | Variable | Example |
|-----|----------|---------|
| `$1` | `task_number` | `42` |
| `$2` | `task_type` | `"your-domain"` |
| `$3` | `task_dir` | `"specs/042_my-task"` |
| `$4` | `session_id` | `"sess_1234_abc"` |
| `$5` | `operation` | `"research"` or `"implement"` |

**Exit codes**:
- Exit 0: success (hook output printed to stdout)
- Exit non-zero: warning logged (non-blocking, skill continues)

This non-blocking disposition is unchanged and does not depend on anything below -- every
`skill_run_extension_hook` call site keeps "exit non-zero -> warning, skill continues" exactly as
stated above, with no opt-in blocking mode.

**Observability addition**: a hook's outcome is additionally exposed to the calling skill code
(never to the hook script itself -- hook scripts still receive no environment variables) through
four uppercase globals set by `skill_run_extension_hook`, all reset **unconditionally** at
function entry so a caller never reads a value left over from a prior invocation:

| Global | Holds |
|--------|-------|
| `SKILL_HOOK_LAST_RC` | The hook script's own exit code (only meaningful when STATUS is `ran`) |
| `SKILL_HOOK_LAST_STATUS` | One of: `ran`, `skipped_no_extension`, `skipped_no_manifest`, `skipped_not_declared`, `skipped_not_executable` |
| `SKILL_HOOK_LAST_NAME` | The stage name the invocation was asked to run |
| `SKILL_HOOK_LAST_PATH` | The resolved script path, empty until a hook path is resolved |

A non-zero hook exit additionally appends one `deviation`-category row to the unified event
store (`specs/events.jsonl`), the same way other lifecycle stages already record their outcome.
**This channel is observability only and never blocking**: `skill_run_extension_hook`'s literal
last statement is always `return 0`, regardless of the hook's own exit code or of anything read
from these globals -- returning the hook's own rc instead would abort a caller running under
`set -e` mid-lifecycle, silently flipping the non-blocking contract stated above as a side
effect. No existing call site inspects these globals, and none is required to.

A declared hook whose resolved script is missing or not executable is **not** silently skipped
the way a missing hook key or an absent `.claude-extensions.json` is (both of those stay silent,
unchanged) -- it emits a one-line NOTE on stderr naming the stage, the declaring manifest, and
the resolved path, then proceeds exactly as before (non-blocking, `return 0`).

Scripts MUST be executable (`chmod +x`).

### Lifecycle Stage Mapping

| Hook | Called From | When |
|------|-------------|------|
| `preflight` | `skill_preflight_update()` | After status is set to "in_progress" |
| `context_injection` | `skill_context_injection()` | Before agent delegation |
| `verification` | `command-gate-out.sh`, immediately after its `skill_validate_task_artifacts` call | After agent returns, artifacts validated, on every task's gate-out |
| `postflight` | `skill_postflight_update()` | After status is set to completed |

### Example: Preflight Validation Hook

```bash
#!/usr/bin/env bash
# scripts/your-domain-preflight.sh

set -euo pipefail

TASK_NUMBER="${1:-}"
TASK_TYPE="${2:-}"
TASK_DIR="${3:-}"
SESSION_ID="${4:-}"
OPERATION="${5:-}"

# Validate toolchain availability (warn but do not fail)
if ! command -v your-tool &>/dev/null; then
  echo "[your-domain-preflight] WARNING: 'your-tool' not found" >&2
fi

echo "[your-domain-preflight] Preflight OK"
exit 0
```

### Example: Context Injection Hook

```bash
#!/usr/bin/env bash
# scripts/your-domain-context.sh

set -euo pipefail

TASK_NUMBER="${1:-}"
TASK_TYPE="${2:-}"
TASK_DIR="${3:-}"
SESSION_ID="${4:-}"
OPERATION="${5:-}"

echo "[your-domain-context] Domain context:"

if command -v your-tool &>/dev/null; then
  version=$(your-tool --version 2>/dev/null | head -1 || echo "unknown")
  echo "[your-domain-context]   Tool version: $version"
fi

exit 0
```

### Adding Hooks to Your Extension

1. Create `scripts/` directory in your extension:
   ```bash
   mkdir -p agent-system/extensions/your-domain/scripts
   ```

2. Create and make executable:
   ```bash
   touch agent-system/extensions/your-domain/scripts/your-domain-preflight.sh
   chmod +x agent-system/extensions/your-domain/scripts/your-domain-preflight.sh
   ```

3. Update `manifest.json`:
   ```json
   {
     "hooks": {
       "preflight": "scripts/your-domain-preflight.sh"
     }
   }
   ```

4. Verify with jq:
   ```bash
   jq '.hooks' agent-system/extensions/your-domain/manifest.json
   ```

---

## Troubleshooting

### Extension Not Appearing in Picker

1. Check manifest.json exists and is valid JSON:
   ```bash
   cat agent-system/extensions/your-domain/manifest.json | jq .
   ```

2. Verify extension directory is in the correct location:
   ```bash
   ls agent-system/extensions/your-domain/
   ```

### Load Fails with Conflicts

The loader detected existing files that would be overwritten and showed a confirmation dialog. If you chose not to override, the load was cancelled. To resolve:
- Rename conflicting files in your extension to avoid the collision
- Remove conflicting files from core (if safe)
- Check if another extension provides the same files
- Re-run the load and confirm the override if the conflict is acceptable

### Routing Not Working After Load

1. Check CLAUDE.md includes your extension content:
   ```bash
   grep "Your Domain Extension" .claude/CLAUDE.md
   ```

2. Verify orchestrator knows about your language routing (check `task_type` in manifest and routing entries)

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

- `agent-system/extensions/latex/` - LaTeX document development
- `agent-system/extensions/lean/` - Lean theorem prover
- `agent-system/extensions/typst/` - Typst document preparation

---

## Related Documentation

- [Extension System Architecture](../architecture/extension-system.md) - How the system works
- [Adding Domains](adding-domains.md) - When to use extensions vs core
- [Creating Agents](creating-agents.md) - Agent patterns
- [Creating Skills](creating-skills.md) - Skill patterns

---

[Back to Docs](../README.md) | [Extension System](../architecture/extension-system.md) | [Adding Domains](adding-domains.md)
