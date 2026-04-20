# Project Overview Generation Guide

## Purpose

This guide helps generate a project-appropriate `project-overview.md` when the agent system is copied to a new repository. The project-overview.md file provides project-specific context that agents use for research, planning, and implementation.

## When to Use

Generate or update `project-overview.md` when:
- The agent system is first copied to a new repository
- The existing project-overview.md doesn't match the current project
- Project structure or technology stack has significantly changed

## Recommended Workflow

The fastest way to generate `project-overview.md` is the `/project-overview` command. It interactively scans the repository, interviews you about project purpose and workflow, and creates a task in [RESEARCHED] status with a research artifact. Then follow the standard lifecycle:

```bash
/project-overview     # Interactive scan + task creation
/plan {N}             # Create implementation plan
/implement {N}        # Generate the file
```

The manual process below is preserved as a reference for understanding what the command does internally, or for cases where fine-grained control is needed.

## Manual Generation Process

### Step 1: Analyze the Project

Gather information about the project by examining:

1. **Entry Points**
   - Look for: `main.go`, `index.ts`, `init.lua`, `main.py`, `Cargo.toml`, `package.json`, `Makefile`
   - Check for configuration files that indicate project type

2. **Technology Stack**
   - Language: Check file extensions, config files
   - Framework: Look for framework-specific files (e.g., `next.config.js`, `vite.config.ts`)
   - Build tools: `Makefile`, `Cargo.toml`, `package.json`, `build.gradle`
   - Testing: `jest.config.js`, `pytest.ini`, `_test.go` files

3. **Directory Structure**
   - Run `ls -la` at root to see top-level organization
   - Identify source directories (`src/`, `lib/`, `pkg/`, `lua/`)
   - Find test directories (`tests/`, `test/`, `__tests__/`)
   - Locate documentation (`docs/`, `README.md`)

4. **Development Workflow**
   - Build commands (from Makefile, package.json scripts, etc.)
   - Test commands
   - Lint/format tools

### Step 2: Write project-overview.md

Create the file at `.claude/context/repo/project-overview.md` using the template below.

## Template

```markdown
# {Project Name}

## Project Overview

{One paragraph describing what the project does and its primary purpose}

**Purpose**: {Single sentence stating the main goal}

## Technology Stack

**Primary Language:** {Language}
**Framework/Platform:** {If applicable}
**Build System:** {Build tool}
**Testing:** {Test framework}
**Version Requirements:** {Runtime/compiler version if specific}

## Project Structure

{Use a tree diagram showing the main directories and their purpose}

```
project-root/
├── src/                    # {Description}
├── tests/                  # {Description}
├── docs/                   # {Description}
├── specs/                  # Task management (from agent system)
└── .claude/                # Agent system configuration
```

## Core Components

### {Component/Module Name}

{Brief description of what this component does and its key files}

### {Another Component}

{Description}

## Development Workflow

### Standard Workflow

1. **{Step 1}**: {Description}
2. **{Step 2}**: {Description}
3. **{Step 3}**: {Description}

### AI-Assisted Workflow

1. **Research**: `/research` - Gather relevant documentation and patterns
2. **Planning**: `/plan` - Create implementation plan
3. **Implementation**: `/implement` - Execute the plan
4. **Review**: `/review` - Analyze changes

## Common Tasks

### {Task Type 1}

1. {Step}
2. {Step}
3. {Step}

### {Task Type 2}

1. {Step}
2. {Step}

## Verification Commands

```bash
# Build the project
{build command}

# Run tests
{test command}

# Run linter
{lint command}

# Check types (if applicable)
{type check command}
```

## Related Documentation

- `{path}` - {Description}
- `{path}` - {Description}
```

## Notes

- Keep the document concise but complete
- Focus on information agents need for research and implementation
- Update when project structure changes significantly
- The existing project-overview.md serves as a template for generating project-specific documentation
