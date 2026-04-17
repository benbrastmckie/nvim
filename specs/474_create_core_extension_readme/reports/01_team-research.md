# Research Report: Task #474

**Task**: Create core extension README.md
**Date**: 2026-04-17
**Mode**: Team Research (4 teammates)

## Summary

The core extension is the sole extension without a README.md, causing `check-extension-docs.sh` to fail. Creating the README requires understanding core's unique nature: it is the foundational system payload, not a domain extension, and intentionally has no task-type routing block. The README must list all 14 commands by slash name (validator requirement), explain the absence of routing, and avoid duplicating content from EXTENSION.md. A secondary blocker was discovered: the validator also fails core on a "no routing block" check that needs a script fix.

## Key Findings

### Primary Approach (from Teammate A)

- Core is structurally unique: no routing block, no task type. Its 16 skills are system infrastructure (skill-orchestrator, skill-status-sync, etc.), invoked directly by commands.
- The standard extension template maps to core as a complex extension with adapted sections. "Language Routing" and "MCP Tool Setup" sections do not apply.
- EXTENSION.md content (category count table, capabilities list) is partially reusable but lacks the architecture tree, per-command descriptions, and agent-skill mapping needed for a full README.
- All 14 commands must appear as `/<cmdname>` patterns -- the validator does a literal `grep -q "/$cmd_name"` check.
- Recommended structure: ~200-300 lines following the nix/README.md pattern (structured reference) rather than the memory/README.md pattern (narrative workflow).

### Alternative Approaches (from Teammate B)

- Three prior-art patterns identified:
  1. **filetypes/README.md**: Documents null/absent routing with explicit prose explaining why
  2. **formal/README.md**: "Research-Only Pattern" section explicitly documents intentional omissions
  3. **memory/README.md**: "Provides inventory" approach organizes by capability category
- Recommended a "System Payload Inventory" structure at ~150 lines that serves as a navigational hub pointing to existing rich documentation (docs/README.md, EXTENSION.md) rather than duplicating it.
- Proposed an "Intentionally Omitted Sections" section following the formal extension pattern.

### Gaps and Shortcomings (from Critic)

- **Critical gap**: The task description mentions only the missing README, but `check-extension-docs.sh` has TWO failures for core: (1) missing README, (2) "manifest declares 16 skill(s) but has no routing block". Creating the README alone will not make the script pass.
- The routing check (`check_routing_block()`) has no core-specific exemption. Every other extension with skills has a routing block. Core is the only exception.
- **Duplication risk**: EXTENSION.md already covers the high-level provides inventory. README must add value beyond it (architecture tree, routing absence explanation, command listing).
- **Stale content risk**: Exact counts from manifest.json (8 agents, 14 commands, etc.) will drift. README should use counts sparingly or cross-reference manifest.json.
- **Audience ambiguity**: Extension developers, agents performing /meta tasks, and the validator script all need different things from this README.

### Strategic Horizons (from Teammate D)

- Core is the last of 15 extensions without a README. Completing this directly unblocks the "CI enforcement of doc-lint" roadmap item.
- The README should establish an "infrastructure extension" pattern for non-domain extensions, informing the future manifest-driven README generation script design.
- Core already has rich documentation (docs/README.md, EXTENSION.md). The README should be a contributor-facing entry point (~100-140 lines) that references these rather than duplicating them.
- Auto-generation from manifest.json is a roadmap priority. Writing the README manually now is correct (unblocks CI), but its structure should inform the generation script.

## Synthesis

### Conflicts Resolved

1. **README length**: Teammate A recommends ~200-300 lines, Teammate B ~150 lines, Teammate D ~100-140 lines. **Resolution**: Target ~150-180 lines. Core needs enough detail to list all 14 commands (validator requirement) and explain its unique nature, but should not duplicate EXTENSION.md or docs/README.md content. The nix README (187 lines) is the closest structural analogue.

2. **Skill-Agent Mapping section**: Teammate A says include it; Teammate D says omit it (lives in CLAUDE.md). **Resolution**: Include a condensed version. The validator checks for command mentions but agents are also discoverable. A brief agents table (8 rows) adds value without excessive drift risk. Skip the full 16-skill mapping table -- reference CLAUDE.md for that.

3. **Commands section**: All teammates agree it must exist (validator requirement). Teammate D initially suggested omitting it and linking to CLAUDE.md, but the validator does a literal grep. **Resolution**: Must include all 14 commands as `/<name>` in the README text. A concise table is the cleanest approach.

### Gaps Identified

1. **Routing block validator fix**: The implementation plan MUST address the `check-extension-docs.sh` routing block check. Options:
   - (A) Hardcode core exemption in script
   - (B) Add `"routing_exempt": true` to manifest.json and check in script (cleanest)
   - (C) Add a dummy routing block to core's manifest (hack, not recommended)
   Recommendation: Option B.

2. **Core's special loader behavior**: The Lua extension loader uses core's manifest as a sync allow-list (`get_core_provides()`). The README should note this but not over-document it.

### Recommendations

1. **Structure**: Use the "System Payload Inventory" pattern with these sections:
   - Overview (category table from EXTENSION.md, adapted)
   - Always Active (no installation needed)
   - Commands (table of all 14, required by validator)
   - Agents (brief table of 8 agents)
   - Architecture (directory tree)
   - No Task-Type Routing (explain why, following formal/filetypes pattern)
   - Intentionally Omitted Sections (following formal/README.md pattern)
   - Related Documentation (links to EXTENSION.md, docs/README.md, CLAUDE.md)

2. **Validator fix**: Add `"routing_exempt": true` to core's manifest.json and update `check_routing_block()` in `check-extension-docs.sh` to skip extensions with this flag.

3. **Drift resistance**: Use counts sparingly. Reference manifest.json for detailed file lists. Keep conceptual content (why no routing, what makes core different) as the stable core of the README.

4. **Target length**: ~150-180 lines.

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Primary approach & template analysis | completed | high |
| B | Alternative patterns & prior art | completed | high |
| C | Critic: gaps & validation | completed | high |
| D | Strategic horizons & roadmap alignment | completed | high |

## References

- `.claude/extensions/core/manifest.json` - Authoritative provides inventory
- `.claude/extensions/core/EXTENSION.md` - Existing high-level documentation
- `.claude/extensions/core/templates/extension-readme-template.md` - Section applicability matrix
- `.claude/scripts/check-extension-docs.sh` - Validator with routing block check
- `.claude/extensions/nix/README.md` - Complex extension README model (~187 lines)
- `.claude/extensions/formal/README.md` - "Intentionally omitted" section pattern
- `.claude/extensions/filetypes/README.md` - Null routing documentation pattern
- `.claude/extensions/memory/README.md` - Provides-inventory structural pattern
