# Teammate B Findings: Alternative Approaches for Core Extension README

## Key Findings

### 1. Core Is Categorically Different from Other Extensions

Core has no `task_type` routing because it IS the routing infrastructure. This makes the
standard extension template a poor fit for the following template sections:

- **Language Routing table**: Meaningless for core - it provides general/meta/markdown
  routing but these are not domain specializations, they are the baseline fallback paths
  that all non-specialized tasks use.
- **Installation section**: Core is always-active; it cannot be loaded or unloaded via
  the extension picker. Saying "loaded via extension picker" would be false.
- **Workflow diagram** (the `/research -> skill -> agent` linear path): Core provides
  the workflow engine itself, not a domain workflow within it.

### 2. Prior Art: "Provides Inventory" Pattern

The memory extension's README (291 lines) demonstrates what I call the **"provides inventory"
approach**: instead of documenting a workflow through the extension, it documents what the
extension makes available, organized by what users actually do with it. Sections like
"The Three Commands", "Writing Memories", "Reading Memories", and "Storage Details" are
capability inventories grouped by user action - not a workflow narrative.

This pattern fits core well because core's value is not "use core to do X" - it is "core
provides everything that makes X possible."

### 3. Prior Art: "Research-Only Pattern" in formal/README.md

The formal extension (158 lines) explicitly documents what the extension intentionally
**omits** ("Research-Only Pattern" section, lines 110-127). It explains why implementation
agents are missing, and redirects users to the correct extension when they need that capability.

This is directly applicable to core: core has no task_type routing row because it IS the
routing table. A clearly marked "No Task-Type Routing" section explaining why would prevent
confusion for contributors.

### 4. Prior Art: "Router Dispatch" Pattern Documentation in filetypes/README.md

The filetypes extension (225 lines) documents its architecture with both an architecture
tree and a "Skill-Agent Mapping" section that calls out the unusual dual-agent dispatch
(lines 141-151). It also adds a "Language Routing" section that notes the extension is
"file-type-driven rather than task-type-driven" and explains why `task_type` is null.

This model - acknowledge what differs from the standard pattern, explain why - fits core's
"no routing because it IS routing" situation.

### 5. The "System Architecture" Approach as an Alternative

Core's EXTENSION.md (54 lines) already documents what core provides via a table of
category counts. The docs/architecture/system-overview.md (292 lines) provides a full
three-layer diagram. Rather than duplicating this, core's README could serve as a
**navigational hub** - pointing to the richer docs that already exist - rather than
replicating their content.

This contrasts with feature extensions that have no such pre-existing documentation.

### 6. Standard Sections That Should Be Explicitly Omitted

Based on examination of all extensions:

| Section | Reason to Omit |
|---------|----------------|
| Installation | Core is always-active; cannot be loaded/unloaded |
| Language Routing table | Core provides the routing table itself, not a row in it |
| Workflow diagram | Core IS the workflow engine |
| MCP Tool Setup | Core has no MCP dependencies |
| Tool Dependencies | Core requires only Claude Code itself |
| Output Artifacts | Core's artifacts are framework-level (specs/), not per-command |

Omissions should be **documented** (not just absent) following the formal extension pattern.

---

## Recommended Approach

Use a **"System Payload Inventory"** structure that:

1. **Opens with a clear distinction statement** explaining why core differs from other
   extensions (it is the base layer, not a domain add-on)

2. **Uses the "provides inventory" pattern** from memory/README.md: organize content
   by capability category (commands, agents, skills, rules, scripts, hooks, context,
   templates), with brief descriptions of each item's purpose

3. **Documents intentional omissions** following the formal extension "Research-Only
   Pattern" model: one section explaining why installation, language routing, and
   workflow sections are absent

4. **Points to existing richer docs** rather than duplicating:
   - docs/architecture/system-overview.md for the three-layer architecture
   - docs/README.md for user-facing guides
   - EXTENSION.md for the canonical category count table

5. **Keeps it concise (~150 lines)** - core doesn't need the depth of memory.md (291) or
   founder.md (408) because its architecture is already documented elsewhere

### Proposed Section Structure

```
# Core Extension

<distinction statement: always-active foundational payload>

## What Core Provides

<table: category | count | description>
<brief narrative per category with examples>

## Commands

<table of 14 commands with one-line purpose each>

## Agents

<table of 8 agents with model + purpose>

## Skills

<table of 16 skills with agent mapping>

## Rules

<table of 6 rules with path patterns>

## Scripts and Hooks

<brief grouping: validation, hooks, lifecycle scripts>

## Intentionally Omitted Sections

<explain why: no installation, no routing table, no workflow diagram>

## Related Documentation

<links to docs/, CLAUDE.md, EXTENSION.md>
```

---

## Evidence and Examples

### EXTENSION.md content already covers the high-level

The existing EXTENSION.md at lines 17-28 has a category count table. README should
expand on this with per-item detail rather than repeat it.

### filetypes/README.md "Language Routing" section (line 153-164)

Shows how to document null/absent routing: "This extension is file-type-driven rather
than task-type-driven. The `task_type` field in `manifest.json` is `null`; the router
agent performs runtime detection..."

Core needs similar prose: "Core provides no task_type routing because it defines the
routing infrastructure itself. The `general`, `meta`, and `markdown` base types are
handled by core's own agents and are not extension routing entries."

### memory/README.md user-action sections

The memory README's "When to Write", "When to Read", "Vault Maintenance" sections are
task-oriented user guidance, not installation documentation. This user-centric style
would work well for core's "Commands" section which could focus on "when to use which
command" rather than just listing them.

### formal/README.md "Research-Only Pattern" (lines 109-127)

Direct template for core's "Intentionally Omitted Sections". The formal README's
explicit "Why This Is Intentional" subsection prevents contributors from thinking they
need to add missing sections.

---

## Confidence Level

**High.** The structural approach is well-supported by three direct analogues:
1. filetypes (null routing documentation)
2. formal (explicit omission documentation)
3. memory (provides-inventory structure)

The main open question (resolved by Teammate A's primary-approach focus) is whether the
README should primarily serve new contributors or existing users. The recommended approach
above assumes a mixed audience and uses the navigational-hub model to serve both.
