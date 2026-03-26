# Research: Slim Parent CLAUDE.md

## Problem

`~/.config/CLAUDE.md` is 224 lines of agent system documentation (directory protocols, testing protocols, code standards, etc.). This loads in EVERY project under ~/.config/, including non-agent projects.

## Content Audit

| Section | Lines | Always Needed? |
|---------|-------|----------------|
| Core Documentation links | 5 | Yes (pointers) |
| Directory Protocols | 15 | Agent-only |
| Testing Protocols | 4 | Agent-only |
| Code Standards | 6 | Agent-only |
| Non-Interactive Testing | 4 | Agent-only |
| Clean-Break Development | 4 | Agent-only |
| Code Quality Enforcement | 4 | Agent-only |
| Output Formatting | 4 | Agent-only |
| Error Logging | 5 | Agent-only |
| Directory Organization | 4 | Agent-only |
| Concurrent Execution Safety | 5 | Agent-only |
| Development Philosophy | 4 | Agent-only |
| Adaptive Planning (x2) | 8 | Agent-only |
| Plan Metadata Standard | 4 | Agent-only |
| Development Workflow | 4 | Agent-only |
| Hierarchical Agent Architecture | 8 | Agent-only |
| Skills Architecture | 4 | Agent-only |
| State-Based Orchestration | 6 | Agent-only |
| Configuration Portability | 4 | Agent-only |
| Project-Specific Commands | 10 | Agent-only |
| Quick Reference | 8 | Agent-only |
| Documentation Policy | 6 | Agent-only |
| Standards Discovery | 20 | Generic |

## Proposed Fix

Convert `~/.config/CLAUDE.md` to a slim pointer file (~15-20 lines), matching the pattern of `~/.config/.claude/CLAUDE.md` which is already a pointer (15 lines).

Move all agent-system standards sections to `.claude/CLAUDE.md` where they belong (already partially there at 294 lines in `nvim/.claude/CLAUDE.md`).

## Impact

- Saves ~200 lines from cross-project context loading
- Agent-system docs only load when working in agent-system projects
- Parent file becomes a clean index pointing to subdirectory configs
