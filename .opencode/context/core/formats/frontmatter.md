# Subagent YAML Frontmatter Standard

**Version**: 1.0.1
**Created**: 2026-01-23
**Purpose**: Standard for subagent YAML frontmatter configuration
**Scope**: All subagent files in `.opencode/agent/subagents/`

---

## Overview

This document defines the standard structure and requirements for YAML frontmatter in AI agent configuration files.

## Essential Fields

| Field | Type | Required | Purpose |
|-------|------|----------|---------|
| `description` | string | Yes | Human-readable purpose |
| `mode` | string | Yes | Execution mode (`subagent` or `primary`) |
| `temperature` | float | Yes | LLM sampling temperature |
| `tools` | map | Yes | Available tools (boolean flags) |
| `permissions` | map | Yes | Access control rules |

---

## Field Specifications

### 1. description (Required)

**Type**: string
**Purpose**: Human-readable explanation of agent purpose.

```yaml
description: "Documentation authoring agent"
```

### 2. mode (Required)

**Type**: string
**Enum**: `subagent` | `primary`

**Purpose**: Define execution mode. Most agents should be `subagent`.

```yaml
mode: subagent
```

### 3. temperature (Required)

**Type**: float
**Range**: 0.0-1.0

**Purpose**: LLM sampling temperature.

```yaml
temperature: 0.2
```

### 4. tools (Required)

**Type**: map of booleans
**Purpose**: Enable/disable specific tools.

**Available Tools**: `read`, `write`, `edit`, `bash`, `grep`, `glob`, `task`

```yaml
tools:
  read: true
  write: true
  edit: true
  glob: true
  task: false
  bash: false
  grep: true
```

### 5. permissions (Required)

**Type**: map of maps
**Purpose**: Access control rules.

**Structure**:
Top-level keys are tool names (`read`, `write`, `bash`, `edit`).
Values are maps where keys are patterns/commands and values are "allow" or "deny".

**Example**:
```yaml
permissions:
  read:
    "**/*.md": "allow"
    ".opencode/**/*": "allow"
  write:
    "specs/**/*": "allow"
  bash:
    "*": "deny"
```

---

## Example Agent

```yaml
---
description: "Example agent"
mode: subagent
temperature: 0.2
tools:
  read: true
  write: true
  edit: true
  glob: true
  task: false
  bash: false
permissions:
  read:
    "**/*.md": "allow"
  write:
    "specs/**/*": "allow"
  bash:
    "*": "deny"
---
```
