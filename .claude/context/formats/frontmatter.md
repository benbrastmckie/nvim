# Subagent YAML Frontmatter Standard

**Created**: 2025-12-29  
**Purpose**: Comprehensive standard for subagent YAML frontmatter configuration  
**Scope**: All subagent files in `.claude/agent/subagents/`

---

## Overview

This document defines the standard structure and requirements for YAML frontmatter in AI agent configuration files. All subagents MUST follow this standard to ensure consistent configuration, validation, and runtime behavior.

**Key Benefits**:
- Consistent structure across all subagents
- Automated validation with 3-tier approach
- Clear security boundaries via permissions
- Efficient context loading via lazy strategies
- Safe delegation with depth limits and cycle detection

---

## Essential Fields

All subagents MUST include these 13 essential fields:

| Field | Type | Required | Purpose |
|-------|------|----------|---------|
| `name` | string | Yes | Unique agent identifier |
| `version` | string | Yes | Semantic version (X.Y.Z) |
| `description` | string | Yes | Human-readable purpose |
| `mode` | string | Yes | Execution mode |
| `agent_type` | string | Yes | Agent category |
| `temperature` | float | Yes | LLM sampling temperature |
| `max_tokens` | integer | No | Maximum output tokens |
| `timeout` | integer | No | Execution timeout |
| `tools` | array | Yes | Available tools |
| `permissions` | object | Yes | Access control rules |
| `context_loading` | object | No | Context management |
| `delegation` | object | No | Delegation configuration |
| `lifecycle` | object | No | Lifecycle integration |

---

## Field Specifications

### 1. name (Required)

**Type**: string  
**Format**: lowercase, hyphen-separated  
**Pattern**: `^[a-z][a-z0-9-]*$`  
**Length**: 3-50 characters

**Purpose**: Unique identifier for the agent used in delegation chains and logging.

**Examples**:
```yaml
name: "researcher"
name: "neovim-implementation-agent"
name: "status-sync-manager"
```

**Validation**:
- Must start with lowercase letter
- Only lowercase letters, numbers, and hyphens allowed
- No consecutive hyphens
- No leading/trailing hyphens

---

### 2. version (Required)

**Type**: string  
**Format**: Semantic Versioning 2.0.0 (MAJOR.MINOR.PATCH)  
**Pattern**: `^\d+\.\d+\.\d+$`

**Purpose**: Track agent evolution and breaking changes.

**Examples**:
```yaml
version: "1.0.0"  # Initial release
version: "1.1.0"  # New features, backward compatible
version: "2.0.0"  # Breaking changes
```

**Versioning Guidelines**:
- MAJOR: Breaking changes to frontmatter structure or agent behavior
- MINOR: New fields or features, backward compatible
- PATCH: Bug fixes, no new features

---

### 3. description (Required)

**Type**: string  
**Length**: 20-500 characters  
**Format**: 2-5 sentences, plain text

**Purpose**: Human-readable explanation of agent purpose and capabilities.

**Example**:
```yaml
description: |
  General research agent for non-Neovim tasks with topic subdivision support.
  Conducts comprehensive research using web sources and documentation.
  Returns detailed reports and summaries following standardized format.
```

**Guidelines**:
- No emojis (text-based only)
- Focus on what the agent does, not how
- Include key capabilities and integration points
- Use active voice

---

### 4. mode (Required)

**Type**: string  
**Enum**: `subagent` | `orchestrator`

**Purpose**: Define execution mode for routing and delegation.

**Values**:
- `subagent`: Delegated to by commands or other agents
- `orchestrator`: Delegates to other agents, manages workflow

**Example**:
```yaml
mode: subagent
```

**Note**: Most agents are `subagent`. Only the main orchestrator uses `orchestrator`.

---

### 5. agent_type (Required)

**Type**: string  
**Enum**: `research` | `planning` | `implementation` | `execution` | `validation` | `orchestration`

**Purpose**: Category for temperature configuration and routing decisions.

**Values**:
- `research`: Research and information gathering
- `planning`: Implementation planning and phase breakdown
- `implementation`: Code/proof implementation
- `execution`: Task execution and orchestration
- `validation`: Validation and verification
- `orchestration`: High-level workflow coordination

**Example**:
```yaml
agent_type: research
```

---

### 6. temperature (Required)

**Type**: float  
**Range**: 0.0-1.0  
**Precision**: 0.1

**Purpose**: LLM sampling temperature for controlling creativity vs. determinism.

**Guidelines by Agent Type**:
- **Research agents**: 0.3 (moderate creativity for diverse source exploration)
- **Planning agents**: 0.2 (structured, deterministic planning)
- **Implementation agents**: 0.2 (precise, deterministic code generation)
- **Execution agents**: 0.2 (consistent task execution)
- **Validation agents**: 0.1-0.2 (highly deterministic validation)

**Examples**:
```yaml
# Research agent
agent_type: research
temperature: 0.3

# Implementation agent
agent_type: implementation
temperature: 0.2
```

**Validation**: Temperature must be within ±0.1 of recommended range for agent_type.

---

### 7. max_tokens (Optional)

**Type**: integer  
**Range**: 1000-100000  
**Default**: 4000

**Purpose**: Maximum output tokens to control response length.

**Example**:
```yaml
max_tokens: 4000
```

**Guidelines**:
- 4000: Default for most agents
- 8000: Agents generating longer outputs (planners, researchers)
- Custom: Adjust based on agent-specific needs

---

### 8. timeout (Optional)

**Type**: integer  
**Range**: 60-10800 seconds  
**Default**: 3600 (1 hour)

**Purpose**: Maximum execution time before timeout.

**Guidelines by Agent Type**:
- Research: 3600s (1 hour)
- Planning: 1800s (30 minutes)
- Implementation: 7200s (2 hours)
- Execution: 7200s (2 hours)

**Example**:
```yaml
timeout: 3600
```

---

### 9. tools (Required)

**Type**: array of strings  
**Items**: Tool names from available tools list

**Purpose**: Define which tools the agent can use.

**Available Tools**:
- Core: `read`, `write`, `edit`, `bash`, `grep`, `glob`, `list`
- Specialized: `webfetch` (research)

**Examples**:
```yaml
# Research agent
tools:
  - read
  - write
  - bash
  - webfetch
  - grep
  - glob

# Implementation agent
tools:
  - read
  - write
  - edit
  - bash
  - grep
  - glob
```

**Guidelines**:
- Include only tools needed for agent function
- Add `webfetch` for agents needing web research
- Add `edit` for agents modifying code
- Order: Core tools first, then specialized

---

### 10. permissions (Required)

**Type**: object with `allow` and `deny` arrays

**Purpose**: Access control rules using glob patterns.

**Structure**:
```yaml
permissions:
  allow:
    - read: ["**/*.md", ".claude/**/*"]
    - write: ["specs/**/*"]
    - bash: ["grep", "find", "wc"]
  deny:
    - bash: ["rm -rf", "sudo", "chmod +x", "dd"]
    - write: [".git/**/*"]
    - read: [".env", "**/*.key", "**/*.pem"]
```

**Permission Evaluation**:
1. Check deny list first (deny takes precedence)
2. If not denied, check allow list
3. If not in allow list, deny by default
4. Log all permission denials for audit

**Dangerous Commands (MUST be in deny list)**:

```yaml
deny:
  # Destructive filesystem operations
  - bash: ["rm -rf", "rm -fr", "rm -r *"]
  
  # Privilege escalation
  - bash: ["sudo", "su", "doas"]
  
  # Permission changes
  - bash: ["chmod +x", "chmod 777", "chown"]
  
  # Disk operations
  - bash: ["dd", "mkfs", "fdisk"]
  
  # Network operations
  - bash: ["wget", "curl", "nc", "netcat"]
  
  # Process manipulation
  - bash: ["kill -9", "killall", "pkill"]
  
  # System modification
  - bash: ["systemctl", "service", "shutdown"]
  
  # Package management
  - bash: ["apt", "yum", "pip", "npm", "cargo"]
  
  # Shell execution
  - bash: ["eval", "exec", "source"]
  
  # Sensitive file access
  - read: [".env", "**/*.key", "**/*.pem", ".ssh/**/*"]
  
  # Critical file modification
  - write: [".git/**/*", "init.lua", "lazy-lock.json"]
```

**Rationale**: These commands pose security risks (data loss, privilege escalation, credential leakage).

**Glob Pattern Syntax**:
- `*`: Matches any characters except `/`
- `**`: Matches any characters including `/` (recursive)
- `?`: Matches single character
- `[abc]`: Matches any character in set

---

### 11. context_loading (Optional but Recommended)

**Type**: object with strategy and file configuration

**Purpose**: Define how agent loads contextual information.

**Structure**:
```yaml
context_loading:
  strategy: lazy
  index: ".claude/context/index.json"
  required:
    - "core/workflows/command-lifecycle.md"
    - "formats/subagent-return.md"
  optional:
    - "project/neovim/plugin-patterns.md"
  max_context_size: 50000
```

**Strategies**:
- **lazy**: Load context on-demand using index (recommended)
- **eager**: Load all context files upfront
- **filtered**: Load based on categories/tags

**File Paths**: Relative to `.claude/context/` directory

**Guidelines**:
- Use lazy strategy for efficiency
- Include command-lifecycle.md and subagent-return-format.md in required
- Add agent-specific context in optional
- Set max_context_size to 50000 tokens (default)

---

### 12. delegation (Optional but Recommended)

**Type**: object with depth limits and delegation rules

**Purpose**: Configure safe delegation to other agents.

**Structure**:
```yaml
delegation:
  max_depth: 3
  can_delegate_to:
    - "status-sync-manager"
    - "git-workflow-manager"
  timeout_default: 1800
  timeout_max: 3600
```

**Fields**:
- `max_depth`: Maximum delegation depth (0-5, recommended: 3)
- `can_delegate_to`: Array of agent names
- `timeout_default`: Default timeout for delegations (seconds)
- `timeout_max`: Maximum timeout for delegations (seconds)

**Delegation Depth**:
- 0: Atomic agent (no delegation)
- 1: Command → Subagent
- 2: Command → Subagent → Specialist
- 3: Command → Subagent → Specialist → Helper (recommended max)

**Guidelines**:
- Set max_depth to 3 to prevent infinite loops
- List only agents this agent directly delegates to
- Use timeout_default < timeout_max
- For implementation agents: timeout_default = 7200 (2 hours)

---

### 13. lifecycle (Optional)

**Type**: object with workflow metadata

**Purpose**: Document where agent fits in command lifecycle.

**Structure**:
```yaml
lifecycle:
  stage: 4
  command: "/research"
  return_format: "subagent-return-format.md"
```

**Fields**:
- `stage`: Workflow stage (1-8, typically 4 for subagents)
- `command`: Command that invokes this agent
- `return_format`: Return format standard reference

**Stages**:
- Stage 4: InvokeAgent (most common for subagents)
- See command-lifecycle.md for full stage definitions

---

## Validation

### 3-Tier Validation Approach

All frontmatter MUST pass three validation tiers:

**Tier 1: Syntax Validation** (YAML parsing)
- Valid YAML 1.2 syntax
- Proper indentation (spaces only, no tabs)
- Correct delimiter usage (---)
- No parsing errors

**Tier 2: Schema Validation** (JSON Schema)
- All required fields present
- Field types match schema
- Enum values valid
- Numeric ranges valid

**Tier 3: Semantic Validation** (Custom rules)
- Temperature matches agent_type
- Dangerous commands in deny list
- Context files exist (warning only)
- Delegation depth ≤ 5
- Version follows SemVer

### Validation Script

Use `.claude/scripts/validate_frontmatter.py` for automated validation:

```bash
# Validate single file
python3 .claude/scripts/validate_frontmatter.py .claude/agent/subagents/researcher.md

# Validate all subagents
python3 .claude/scripts/validate_frontmatter.py --all
```

---

## Examples

### Research Agent Example

```yaml
---
name: "researcher"
version: "1.0.0"
description: "General research agent for non-Lean tasks with topic subdivision support"
mode: subagent
agent_type: research
temperature: 0.3
max_tokens: 4000
timeout: 3600
tools:
  - read
  - write
  - bash
  - webfetch
  - grep
  - glob
permissions:
  allow:
    - read: ["**/*.md", ".claude/**/*", "docs/**/*"]
    - write: ["specs/**/*"]
    - bash: ["grep", "find", "wc", "date", "mkdir"]
  deny:
    - bash: ["rm -rf", "sudo", "chmod +x", "dd", "wget"]
    - write: [".git/**/*"]
    - read: [".env", "**/*.key", "**/*.pem"]
context_loading:
  strategy: lazy
  index: ".claude/context/index.json"
  required:
    - "core/workflows/command-lifecycle.md"
    - "formats/subagent-return.md"
  max_context_size: 50000
delegation:
  max_depth: 3
  can_delegate_to:
    - "web-research-specialist"
  timeout_default: 1800
  timeout_max: 3600
lifecycle:
  stage: 4
  command: "/research"
  return_format: "subagent-return-format.md"
---
```

### Implementation Agent Example

```yaml
---
name: "implementer"
version: "1.0.0"
description: "Direct implementation for simple tasks without multi-phase plans"
mode: subagent
agent_type: implementation
temperature: 0.2
max_tokens: 4000
timeout: 7200
tools:
  - read
  - write
  - edit
  - bash
  - grep
  - glob
permissions:
  allow:
    - read: ["**/*"]
    - write: ["**/*", "!.git/**/*"]
    - bash: ["grep", "find", "wc", "date", "mkdir", "git"]
  deny:
    - bash: ["rm -rf", "sudo", "chmod +x", "dd"]
    - write: [".git/config", ".git/HEAD"]
context_loading:
  strategy: lazy
  index: ".claude/context/index.json"
  required:
    - "core/workflows/command-lifecycle.md"
    - "formats/subagent-return.md"
  max_context_size: 50000
delegation:
  max_depth: 3
  can_delegate_to:
    - "neovim-implementation-agent"
    - "status-sync-manager"
  timeout_default: 7200
  timeout_max: 7200
lifecycle:
  stage: 4
  command: "/implement"
  return_format: "subagent-return-format.md"
---
```

---

## Best Practices

### 1. Minimal Tool Set

Include only tools needed for agent function. Don't grant unnecessary capabilities.

**Good**:
```yaml
# Research agent - needs webfetch
tools: [read, write, bash, webfetch, grep, glob]
```

**Bad**:
```yaml
# Research agent - doesn't need edit
tools: [read, write, edit, bash, webfetch, grep, glob]
```

### 2. Deny Dangerous Commands

Always include comprehensive dangerous command deny list.

**Critical Commands** (MUST be denied):
- `rm -rf` (data loss)
- `sudo` (privilege escalation)
- `chmod +x` (permission changes)
- `dd` (disk operations)

### 3. Use Lazy Context Loading

Prefer lazy loading with index-based discovery for efficiency.

**Good**:
```yaml
context_loading:
  strategy: lazy
  index: ".claude/context/index.json"
```

**Bad**:
```yaml
context_loading:
  strategy: eager  # Loads all context upfront
```

### 4. Limit Delegation Depth

Set max_depth to 3 to prevent infinite delegation loops.

**Good**:
```yaml
delegation:
  max_depth: 3
```

**Bad**:
```yaml
delegation:
  max_depth: 10  # Too deep, risks infinite loops
```

### 5. Match Temperature to Agent Type

Use recommended temperature for agent category.

**Good**:
```yaml
agent_type: implementation
temperature: 0.2  # Correct for implementation
```

**Bad**:
```yaml
agent_type: implementation
temperature: 0.7  # Too high for implementation
```

---

## Common Pitfalls

### 1. Missing Dangerous Commands in Deny List

**Issue**: Forgetting to deny critical commands like `rm -rf`, `sudo`.

**Solution**: Copy dangerous command list from template, don't write from scratch.

### 2. Incorrect Temperature for Agent Type

**Issue**: Using research temperature (0.3) for implementation agent.

**Solution**: Follow temperature guidelines by agent_type.

### 3. Overly Permissive File Access

**Issue**: Allowing write access to `.git/**/*` or other critical files.

**Solution**: Use specific glob patterns, deny critical directories.

### 4. Missing Required Fields

**Issue**: Omitting name, version, or other required fields.

**Solution**: Use frontmatter template as starting point, validate with script.

### 5. Invalid YAML Syntax

**Issue**: Incorrect indentation, missing quotes, invalid characters.

**Solution**: Use YAML linter, test with `yaml.safe_load()` before committing.

---

## Future Enhancements

**Planned improvements** (out of scope for current standard):

1. **Runtime Enforcement**: Implement permission checking in tool execution
2. **Context Loading Implementation**: Lazy loading with index-based discovery
3. **Delegation Routing**: Delegation with depth limits and cycle detection
4. **CI/CD Integration**: GitHub Actions workflow for frontmatter validation
5. **Plugin Integration**: Add Neovim plugin tooling for configuration agents

---

## Related Documentation

See `.claude/context/index.json` for navigation to all context files.

---