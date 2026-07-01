---
description: Analyze repository and create task to generate project-overview.md
allowed-tools: Skill
---

# /project-overview Command

Interactively analyzes the repository structure, technology stack, and development workflow, then creates a task with a research artifact for generating `project-overview.md`.

## Overview

This command automates the process of creating a project-specific `project-overview.md` file. Instead of writing the file directly, it:

1. **Scans** the repository (languages, frameworks, build tools, testing, CI/CD, key files)
2. **Interviews** the user to verify findings and gather project purpose/workflow details
3. **Creates** a task in [RESEARCHED] status with a research artifact containing all findings

The user then follows the standard task lifecycle (`/plan`, `/implement`) to generate the actual file.

## When to Use

- First time setting up the agent system in a new repository
- When `project-overview.md` contains the generic template placeholder
- When project structure has significantly changed and the overview needs regeneration

## Interactive Flow

1. Check if `project-overview.md` already exists and is customized
2. Auto-scan repository structure, languages, frameworks, and tools
3. Present findings to user for verification
4. Ask about project purpose and development workflow
5. Create task and research artifact
6. Display next steps guidance

## Examples

```bash
# Run the interactive project overview generator
/project-overview
```

## Output

Creates a task in [RESEARCHED] status. The user then runs:
```bash
/plan {N}       # Create implementation plan
/implement {N}  # Generate project-overview.md
```

## Execution

Invoke skill-project-overview for direct execution.
