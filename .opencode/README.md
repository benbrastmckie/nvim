# Logos/Theory .opencode System

This directory contains the opencode agent system for Logos/Theory. It mirrors the
capabilities of the .opencode system using opencode directory conventions and routing.

## Directory Structure

```
.opencode/
├── agent/        # Primary agents and subagents
├── commands/      # Slash command definitions
├── context/      # Core and project context
├── docs/         # User-facing documentation
├── hooks/        # Hook scripts used by tooling
├── rules/        # System rules and conventions
├── skills/       # Skill definitions
├── systemd/      # Service definitions for refresh automation
└── templates/    # JSON and markdown templates
```

## Usage

Use the opencode commands in `commands/` and agents in `agent/` to execute task
workflows. Context files are organized under `context/core/` and
`context/project/` following the Logos/Theory standards.
