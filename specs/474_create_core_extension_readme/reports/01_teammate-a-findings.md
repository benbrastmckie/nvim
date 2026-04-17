# Teammate A Findings: Core Extension README

## Key Findings

### 1. Core is Structurally Unique — No Routing Block, No Task Type

Core has no `routing` block in its manifest.json. Every other extension with skills (nix, memory, nvim, etc.) declares a routing block mapping task types to skills. Core's 16 skills are **system infrastructure skills** (e.g., `skill-orchestrator`, `skill-status-sync`, `skill-git-workflow`), not task-type-routed skills. They are invoked by commands directly, not by the routing table.

This means:
- The "Language Routing" section from the template **does not apply** to core.
- The "Skill-Agent Mapping" section **does apply** but must explain that skills are invoked directly.
- The standard template section order may need adaptation.

### 2. Validation Script Has a Core-Specific Problem

`check-extension-docs.sh` currently produces TWO failures for core:
1. `README.md missing` (the task being solved)
2. `manifest declares 16 skill(s) but has no routing block`

The second failure is a **false positive** — core intentionally has no routing block because it provides system-level skills, not domain task type routing. The README should document why core has no routing, and the implementation plan should include a fix to the validation script to exempt core from the routing check (or add a `"routing_exempt": true` flag to manifest.json).

### 3. Existing EXTENSION.md Content is Reusable (Partially)

`EXTENSION.md` contains:
- A well-written Overview section (reusable verbatim)
- A "What This Extension Provides" table (good for README Overview section)
- "Key Capabilities" list (usable as-is in a condensed form)
- "Usage Notes" and "Dependencies" (short, usable)

**What's missing from EXTENSION.md** that the README needs:
- Architecture tree showing directory structure
- Per-command descriptions
- Per-skill descriptions with agent mappings
- Agent-skill mapping table
- Rules section listing what rules apply
- Scripts overview

### 4. Template Section Applicability for Core

Core is a **complex extension** (many components) but with unique characteristics. Template applicability:

| Template Section      | Applies to Core? | Notes |
|-----------------------|-----------------|-------|
| Overview              | YES (adapted)   | Drop task type column; use category table instead |
| Installation          | YES (adapted)   | "Always active" — no installation needed |
| MCP Tool Setup        | NO              | Core has no MCP servers |
| Commands              | YES (required)  | 14 commands — validation script checks all are mentioned |
| Architecture tree     | YES             | Core has many directories; tree aids navigation |
| Skill-Agent Mapping   | YES (adapted)   | Map all 16 skills; note no routing block |
| Language Routing      | NO              | Core has no task-type routing |
| Workflow diagram      | OPTIONAL        | Could show core command lifecycle at high level |
| Output Artifacts      | PARTIAL         | Standard specs/ artifacts for research/plan/implement |
| Key Patterns          | OPTIONAL        | Checkpoint pattern, team mode pattern useful |
| Rules Applied         | YES             | Core declares 6 rules |
| Tool Dependencies     | NO              | Core tools are all standard (git, jq, bash) |
| References            | YES             | CLAUDE.md, context/index.json, extensions.json |

### 5. Command Mention Requirement

The validation script checks that every command in `provides.commands[]` has a `/<name>` mention in README.md. Core's 14 commands are:
`/errors`, `/fix-it`, `/implement`, `/merge`, `/meta`, `/plan`, `/refresh`, `/research`, `/review`, `/revise`, `/spawn`, `/tag`, `/task`, `/todo`

All 14 must appear in the README as `/<cmdname>` patterns. The simplest approach: a commands reference table with all 14.

### 6. How Other Extensions Handle Similar Documentation

**nix/README.md** (complex, 187 lines) — Most similar in structure:
- Has Overview table, Installation, MCP Setup, Commands (says "no dedicated commands"), Architecture tree, Skill-Agent Mapping, Language Routing, Workflow, Output Artifacts, Key Patterns, Rules Applied, Context References, References.
- The "no dedicated commands" pattern is directly applicable — nix says "This extension provides no commands of its own. Use the core `/research`, `/plan`, and `/implement` commands..."
- For core, we invert this: "All core commands are provided by this extension."

**memory/README.md** (complex, ~290 lines) — Diverges significantly from template:
- User-facing documentation style with "Three Commands" framing
- Task-flow narrative rather than reference table
- This style doesn't suit core (core is infrastructure, not user-workflow-oriented)

**python/README.md** (simple, ~60 lines) — Compact reference:
- Uses all required template sections minimally
- Shows what a simple extension looks like; core needs more detail

**Key insight from examples**: Core should follow the nix pattern (structured reference, architecture tree, skill-agent mapping) rather than the memory pattern (narrative workflow guide). The audience for core's README is developers extending the agent system, not end users.

---

## Recommended Approach

### Structure

Core README should be a **complex extension README** (~200-300 lines) following this adapted structure:

```
# Core Extension

<2-3 sentence overview>

## Overview

<Category table showing counts of agents/commands/rules/skills/scripts/hooks>

## Always Active

<Explain core is foundational, no installation needed, always loaded>

## Commands

<Table with all 14 commands + brief descriptions>
<Note: All commands use checkpoint-based execution pattern>

## Architecture

<Directory tree of core/ directory>

## Agents

<Table: agent -> purpose>

## Skill-Agent Mapping

<Table: skill -> agent/invocation -> purpose>
<Note: Core skills are invoked directly by commands, not via task-type routing>

## No Language Routing

<Explain why core has no routing block: skills are infrastructure, not task-type-specific>

## Rules Applied

<List of 6 rules with their auto-applied path patterns>

## Key Scripts

<Notable scripts: check-extension-docs.sh, export-to-markdown.sh, install-extension.sh, etc.>

## References

<Links to CLAUDE.md, context/index.json, extensions.json>
```

### Critical Points

1. **All 14 commands must be mentioned** as `/cmdname` patterns (validation requirement)
2. **No routing block** — must explain this is intentional, not an oversight
3. **"Always active"** framing for Installation section — no `<leader>ac` picker needed
4. **Core is the foundation** — other extensions build on it; this should be clear

### Potential Plan Item: Fix Validation Script

The routing block check in `check-extension-docs.sh` should be updated to exempt core (or any extension with a `"provides.routing_exempt": true` flag). Otherwise even after creating the README, one validation failure will persist.

Options:
- A) Hardcode an exemption for `core` in the script
- B) Add `"routing_exempt": true` to core's manifest.json and check for it in the script
- C) Add a `routing` block to core's manifest.json even though core doesn't route by task type (hack, not recommended)

Option B is cleanest and most extensible.

---

## Evidence/Examples

### From nix/README.md — "No Commands" Pattern
```markdown
## Commands

This extension provides no commands of its own. Use the core `/research`, `/plan`, and `/implement` commands with tasks typed as `nix`.
```
Core inverts this: all commands come FROM core.

### From check-extension-docs.sh — Routing Check (lines 109-123)
The check requires `has("routing")` when `provides.skills | length > 0`. Core has 16 skills but no routing. This is a bug in the validator for core's special case.

### From EXTENSION.md — Reusable Summary Table
```markdown
| Category | Count | Description |
|----------|-------|-------------|
| agents   | 8     | Research, implementation, planning, meta, review, revision, spawn agents |
| commands | 14    | `/task`, `/research`, `/plan`, `/implement`, `/todo`, `/meta`, and more |
| rules    | 6     | Auto-applied rules for state, git, artifacts, workflows, and error handling |
| skills   | 16    | Skill definitions including team mode, orchestration, and utility skills |
...
```
This table can be reproduced directly in the README Overview section.

---

## Confidence Level: High

All key facts verified by direct inspection:
- manifest.json confirms: no routing block, 16 skills, 14 commands, 8 agents, 6 rules
- check-extension-docs.sh confirms: two failures (README missing + routing block missing)
- Three example READMEs examined (nix, memory, python) to understand style conventions
- Template examined for section applicability matrix
- EXTENSION.md content inventoried for reuse potential

The main uncertainty is whether the implementation plan should also fix the validation script (routing block check). This is a separate concern from creating the README itself, but both are needed for a complete `check-extension-docs.sh` PASS.
