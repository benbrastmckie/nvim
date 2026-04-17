# Teammate D Findings: Horizons Analysis
# Task 474: Create Core Extension README

## Key Findings

### 1. Core Is the Last Extension Without a README

Every other extension (14/14) has a README.md. Core is the sole exception. The `check-extension-docs.sh` script actively checks for this and will fail the doc-lint CI check (a Phase 1 roadmap priority) until core has its README. Creating this README directly unblocks the "CI enforcement of doc-lint" roadmap item.

### 2. Core Is Fundamentally Different from All Other Extensions

Every other extension follows the domain-extension pattern: task type routing, skill-agent mapping, language-specific research/implementation agents. Core does not. Core provides:

- The base infrastructure that all other extensions build on
- No task type of its own (it IS the routing system)
- 27 scripts, 11 hooks, 16 skills, 8 agents, 14 commands, 6 rules
- A separately maintained `docs/README.md` that already serves as an agent system navigation hub

This means the standard extension-readme-template.md sections (Language Routing, Skill-Agent Mapping, Workflow diagram) are either inapplicable or degenerate for core.

### 3. Core Already Has Rich Documentation -- the README Is the Missing Indexing Layer

The core extension has:
- `docs/README.md`: Full system navigation hub (100+ lines, command tables, architecture diagram)
- `EXTENSION.md`: Concise functional description of what the extension provides
- `manifest.json`: Authoritative machine-readable inventory

The README.md at `extensions/core/README.md` should serve as a **contributor-facing entry point** that references these existing resources rather than duplicating them.

### 4. Auto-Generation from Manifest Is a Roadmap Priority -- Core README Is the Ideal Test Case

The ROADMAP.md Phase 1 item "Manifest-driven README generation" calls for a script that reads `manifest.json` and emits a starter README from the template. Core's manifest is the most complete in the system (8 categories, ~100+ files). Building the README for core manually now risks creating a pattern that the future script must accommodate -- or causing drift once the script exists.

**Strategic tension**: Should we write the README manually now (unblocks doc-lint), or should generating core's README be the forcing function to build the generation script first?

Resolution: Given that the roadmap item is a future goal and doc-lint enforcement is blocked today, write the README now but document its structure to inform the generation script design.

### 5. Core README Can Serve as the Canonical Example for New Extension Authors

Currently `extensions/README.md` describes the extension system architecture and mentions `founder/README.md` as a complex example and `python/README.md` as a simple example. Core is neither -- it is the meta-example of an extension that IS the system.

A well-structured core README doubles as the authoritative reference for:
- What a non-domain extension looks like (no task type routing)
- How an infrastructure extension documents its provides inventory
- What belongs in README vs EXTENSION.md vs docs/README.md

### 6. Extensions/README.md Is the "Index" -- Core README Should Not Duplicate It

The `extensions/README.md` already serves as the extension directory index. It lists all 14 extensions with their task types and descriptions. Core's README should NOT try to be a second index. Instead, it should link back to `extensions/README.md` for system-level navigation.

### 7. Scope Boundaries: What the README Must Cover

Based on the template's "Section Applicability Matrix" for complex extensions, and accounting for core's unique nature:

**Must include (required for all extensions)**:
- Overview: what core provides (infrastructure, not domain task type)
- Installation: always active, no manual loading needed

**Should include (for complex extensions)**:
- Architecture tree of the core extension directory
- Complete provides inventory (counts from manifest.json)
- References to docs/README.md and EXTENSION.md for deeper navigation

**Must omit (inapplicable to core)**:
- Language Routing table (core has no task type)
- Skill-Agent Mapping (core provides all skills; the mapping lives in CLAUDE.md)
- Workflow diagram (core IS the workflow system; docs/README.md has this)
- MCP Tool Setup (core has no mcp_servers)

### 8. Preventing README Drift

The ROADMAP mentions README drift as a CI enforcement target. Core's README is uniquely drift-prone because manifest.json lists ~100+ files across 9 categories. Recommendations:

- Keep the README at a **high-level summary level** (counts, not file lists)
- Use manifest.json as the single source of truth for detailed file lists
- Add a note: "For the complete provides inventory, see manifest.json"
- The future `generate-extension-readme.sh` script should be able to regenerate the counts section from manifest.json

---

## Recommended Approach

### Scope: "Infrastructure Extension README" Pattern

Create a README that establishes a new pattern for non-domain infrastructure extensions. This README should be:
- **Concise** (~100-140 lines, matching mid-range complexity)
- **Navigation-focused** (points to docs/README.md for depth)
- **Inventory-aware** (summarizes what's in manifest.json without duplicating it)
- **Drift-resistant** (uses counts, not lists; links to manifest.json)

### Structure

```markdown
# Core Extension

One-sentence description.

## Overview

Summary table of provides categories with counts.

## Always Active

Note: unlike other extensions, core is always loaded.

## What Core Provides

Brief category descriptions with links to relevant docs.

## Architecture

Directory tree of extensions/core/.

## Key Entry Points

- CLAUDE.md (agent quick reference)
- docs/README.md (full system navigation)
- manifest.json (complete provides inventory)
- EXTENSION.md (CLAUDE.md merge source)

## Extension Infrastructure

Scripts for managing other extensions (install, uninstall, validate).

## References

Links to key docs.
```

### Do NOT Include

- Full file lists from manifest.json (too long, will drift)
- Skill-agent mapping tables (these live in CLAUDE.md, maintained there)
- Workflow diagrams (live in docs/README.md)
- Language Routing table (core has no task type routing)

### Size Target

100-140 lines. Core is more complex than latex/python (57-59 lines) but should not match founder (408 lines). The memory extension README (291 lines) is instructive: it has rich user-facing workflow documentation because users need to understand memory vault operations. Core's audience is developers/contributors, not end users -- it needs orientation, not tutorial.

---

## Evidence / Examples

### Template Fitness Check

The `extension-readme-template.md` has a section applicability matrix:

| Section | Verdict for Core | Reason |
|---------|-----------------|--------|
| Overview | Required | Yes, but task-type table is inapplicable; use provides-count table |
| Installation | Required | Note: "always active" not loaded via picker |
| MCP Tool Setup | Omit | Core has no MCP servers |
| Commands | Omit | Core's commands listed in CLAUDE.md; linking there is cleaner |
| Architecture tree | Required | Core has 13 subdirectories; tree is useful |
| Skill-Agent Mapping | Omit | Already in CLAUDE.md; duplication causes drift |
| Language Routing | Omit | Core has no task type |
| Workflow diagram | Omit | Lives in docs/README.md |
| Output Artifacts | Omit | Infrastructure, not workflow |
| Key Patterns | Optional | Could reference extension infrastructure scripts |
| Tool Dependencies | Optional | None for core itself |
| References | Required | docs/README.md, CLAUDE.md, manifest.json |

### Existing READMEs for Pattern Comparison

| Extension | Lines | Type | Why Different from Core |
|-----------|-------|------|-------------------------|
| founder | 408 | Domain/complex | Rich workflow docs for end users |
| memory | 291 | Domain/complex | Tutorial-level user guidance |
| filetypes | 225 | Domain/complex | Many conversion formats to document |
| nvim | 197 | Domain/complex | Repository-specific patterns |
| python | 59 | Domain/simple | One-task-type, minimal |
| core | ? | Infrastructure/meta | No task type; points to docs/ |

Core is closest to a "meta" extension -- it should orient contributors, not instruct users.

### ROADMAP Alignment

This task directly unblocks:
- "CI enforcement of doc-lint" (Phase 1): `check-extension-docs.sh` fails without core/README.md
- "Integration with /review command" (Phase 1): /review surfaces README drift; core needs a README to drift from

This task indirectly informs:
- "Manifest-driven README generation": Core README establishes what a non-domain extension README looks like, constraining the template script's design

---

## Confidence Level

**High**

The strategic direction is clear:
1. Write the README now (unblocks CI roadmap item)
2. Use the "infrastructure extension" pattern (no task type, points to docs/)
3. Keep it drift-resistant (counts not lists, link to manifest.json)
4. Target ~100-130 lines

The only uncertainty is whether the future generate-extension-readme.sh script should special-case core (likely yes, as core has no task type). The README should include a comment noting this.
