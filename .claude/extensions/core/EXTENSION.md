# Core Extension

## Overview

The core extension provides the base agent system infrastructure for Claude Code. It contains
all fundamental commands, agents, rules, skills, scripts, hooks, context, documentation, and
templates that power the task management and agent orchestration workflow.

## Purpose

This extension packages the core agent system files that were previously located directly in
`.claude/`. Moving them into the extension framework enables versioning, syncing, and management
via the extension loader while maintaining full backward compatibility.

## What This Extension Provides

| Category | Count | Description |
|----------|-------|-------------|
| agents | 8 | Research, implementation, planning, meta, review, revision, spawn agents |
| commands | 14 | `/task`, `/research`, `/plan`, `/implement`, `/todo`, `/meta`, and more |
| rules | 6 | Auto-applied rules for state, git, artifacts, workflows, and error handling |
| skills | 16 | Skill definitions including team mode, orchestration, and utility skills |
| scripts | 27 | Utility scripts for validation, hooks, memory, and extension management |
| hooks | 11 | Session logging, memory nudging, WezTerm notifications, validation hooks |
| context | 15 dirs | Architecture, patterns, guides, schemas, workflows, and reference material |
| docs | 23 files | Standards documentation, architecture guides, and references |
| templates | 2 | Extension README template and settings.json template |

## Key Capabilities

- **Task Management**: Full lifecycle from creation through research, planning, implementation,
  and archival via `/todo`
- **Agent Orchestration**: Routing, delegation, and team mode for parallel execution
- **State Management**: Atomic synchronization of TODO.md and state.json
- **Memory System**: Auto-retrieval hooks and distillation support
- **Extension Infrastructure**: Scripts to install, validate, and manage other extensions

## Usage Notes

- This extension is always active and is the foundational layer for all other extensions
- All core commands (e.g., `/implement`, `/research`) are defined here
- Context files are auto-loaded by agents via the context index
- Scripts are callable from hooks and other scripts using the extension-relative path
- The `context/reference/team-wave-helpers.md` file provides reusable wave patterns for team skills

## Dependencies

None. This is the foundational layer all other extensions build upon.

## Related Files

- `.claude/CLAUDE.md` - Agent system configuration and quick reference
- `.claude/context/index.json` - Context discovery index
- `.claude/extensions.json` - Extension registry
