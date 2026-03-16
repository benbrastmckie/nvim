---
name: skill-grant
description: Grant proposal research and drafting support
version: 1.0.0
agent: grant-agent
model: opus
---

# Skill: Grant Proposal Support

Placeholder skill definition for grant writing support. Full implementation in Task #206.

## Purpose

Provides structured support for grant proposal development including:
- Funder research and requirement analysis
- Proposal narrative drafting
- Budget development and justification
- Review checklist validation

## Invocation

This skill is invoked when:
- Task language is set to `grant`
- User requests grant-related research or writing assistance
- Extension is loaded via `<leader>ac`

## Agent Delegation

Delegates to `grant-agent` for execution. See Task #205 for agent implementation.

## Tools

| Tool | Purpose |
|------|---------|
| WebSearch | Research funder priorities and past grants |
| WebFetch | Retrieve application guidelines |
| Read | Access context files and templates |
| Write | Create proposal documents |
| Edit | Modify draft sections |

## Context Loading

Automatically loads context from:
- `project/grant/README.md`
- `project/grant/domain/`
- `project/grant/templates/`
