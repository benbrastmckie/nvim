# Research Report: Task #457

**Task**: Design extension-based slidev resource distribution strategy
**Date**: 2026-04-16
**Mode**: Team Research (4 teammates)

## Summary

The founder extension owns a complete Slidev deck library (animations, styles, components, content, themes, patterns). The present extension has an academic talk library with null-path references to founder's animations and styles -- a documented but broken workaround. This research evaluates strategies for sharing Slidev resources across extensions without duplication, context bloat, or silent failures.

The core finding is that the shared resource surface is **narrow** (6 animations + 9 CSS presets = ~1,096 lines / ~4,400 tokens) and the existing `dependencies` field in every manifest.json was designed for exactly this problem but never implemented. The recommended approach is a **two-phase strategy**: (1) immediate fix using cross-extension index entries with dependency declaration, and (2) medium-term extraction of a `slidev-core` micro-extension when a third consumer materializes.

## Key Findings

### 1. The Null-Path Pattern Is Actively Broken (All teammates)

Present's `talk/index.json` has `"path": null` with prose notes instructing agents to "reference .claude/extensions/founder/context/project/founder/deck/animations/ directly." This fails because:
- Agents cannot act on null paths with prose instructions
- The referenced path is an extension **source** path, not a deployed path
- If founder is not loaded, the path doesn't exist at all
- No enforcement mechanism ensures both extensions are loaded together

This is not a working design -- it is a deferred decision that creates silent failures.

### 2. Shared Resources Are Narrower Than Expected (Teammate C)

Detailed measurement of the "shared" resources:

| Resource Type | Files | Lines | ~Tokens |
|---------------|-------|-------|---------|
| Animations | 6 | 315 | 1,260 |
| Color CSS | 4 | 52 | 208 |
| Typography CSS | 3 | 73 | 292 |
| Texture CSS | 2 | 36 | 144 |
| **Total shared** | **15** | **476** | **~1,904** |

Vue components (MetricCard, TeamMember, TimelineItem, ComparisonCol) are founder-domain-specific despite being structurally generic. The present extension has its own distinct component set (FigurePanel, DataTable, CitationBlock, StatResult, FlowDiagram) with zero overlap.

The fear of "context bloat" from sharing is not justified by the numbers. The actual shared resources are under 2,000 tokens.

### 3. The `dependencies` Field Exists But Has No Enforcement (Teammates B, C, D)

Every extension manifest declares `"dependencies": []`. The field was anticipated in the original design but:
- The loader (`init.lua`) does not read or enforce dependencies
- No auto-loading of prerequisite extensions occurs
- No validation prevents loading an extension without its dependencies

Implementing dependency semantics would complete an existing design intent, not introduce a foreign pattern.

### 4. Two Distinct Resource Distribution Patterns Exist (Teammate A)

**Founder (seed-copy)**: Resources live in the extension; agents copy to `.context/deck/` on first use. The `.context/` copy is mutable and project-local.

**Present (direct-reference)**: Resources stay in the extension path; agents reference them directly via `@.claude/context/project/present/talk/...`. No seed-copy step.

These patterns are incompatible for sharing. The seed-copy pattern creates a project-local mutable copy; the direct-reference pattern assumes the extension source is always available. Any sharing strategy must account for this mismatch.

### 5. Cross-Extension Sharing Is an Emerging Pattern (Teammate D)

Currently only present->founder has this dependency. But:
- Epidemiology will eventually need slide-building capability for research presentations
- Typst/LaTeX could gain presentation support
- The pattern will recur across 3+ extensions within a year

Solving this structurally now prevents ad-hoc workarounds from accumulating.

### 6. Index Schema Inconsistency (Teammate C)

Founder's `deck/index.json` uses singular categories (`animation`, `component`, `style`). Present's `talk/index.json` uses plural categories (`animations`, `components`, `styles`). Any unification must reconcile this or maintain parallel schemas.

## Synthesis

### Conflicts Resolved

**Conflict 1: `.context/slidev/` shared layer (A) vs. declared dependencies (B, D)**

Teammate A proposed a new `.context/slidev/` runtime directory with seed-copy initialization. Teammates B and D preferred using the `dependencies` manifest field to declare present->founder dependency.

**Resolution**: The `.context/slidev/` approach creates a third copy location and a new initialization step in every slidev-related skill. The dependencies approach is simpler: present declares its dependency on founder, and the loader ensures founder is available. The dependency approach wins on simplicity and maintenance cost.

However, the dependency approach requires loader enforcement code that doesn't exist yet. As a **bridge**, present's `index-entries.json` can declare entries pointing into founder's deployed path (`.claude/context/project/founder/deck/animations/...`). This works immediately when both extensions are loaded, without loader changes.

**Conflict 2: Duplication acceptable vs. sharing required (C vs. A, B)**

Teammate C argues the shared resources (~1,904 tokens) are small enough that duplication might be simpler. Others argue against duplication on principle.

**Resolution**: At ~1,904 tokens, duplication is technically feasible but creates a maintenance divergence problem. When founder updates an animation, the present copy would become stale. Sharing via reference is preferred because it eliminates divergence at negligible complexity cost.

**Conflict 3: Scope -- include epidemiology or not (D vs. task description)**

The task description mentions epidemiology as a contributor. Teammate D found that epidemiology has zero slidev content and no slide commands.

**Resolution**: Design the architecture to accommodate future consumers (epi), but scope the immediate implementation to present->founder only. Epidemiology can be added later by declaring `"dependencies": ["present"]` in its manifest.

### Gaps Identified

1. **Loader enforcement**: The `dependencies` field has no runtime enforcement. This is a prerequisite for the recommended approach to be robust. Without it, the solution works only when users manually load both extensions.

2. **Component namespace collision**: Slidev registers Vue components globally. No namespace mechanism prevents collisions if both libraries are copied to the same project. This is a Slidev-level limitation, not solvable in the agent system alone. Mitigation: document a naming convention (domain prefix, e.g., `FounderMetricCard` vs. `AcademicStatResult`).

3. **Scaffold vs. context ambiguity**: It's unclear whether slidev resource files are used as agent prompt context (text the agent reads) or as scaffold files (copied into the Slidev project). The answer affects whether "sharing" means shared context entries or shared file copying. Both uses exist: agents read animation patterns as prompt context AND copy component .vue files as scaffolds.

4. **No `load_when.extensions_loaded` condition**: The current context discovery system cannot express "load this when extension X is also loaded." This limits conditional composition.

### Recommendations

#### Phase 1: Immediate Fix (Small effort, no loader changes)

1. **Replace null paths in present's `talk/index.json`** with actual entries pointing to the deployed founder path:
   ```json
   "animations": {
     "description": "Reusable Slidev animation patterns (from founder deck library)",
     "path": "../../../founder/deck/animations/",
     "items": [
       { "name": "fade-in", "file": "fade-in.md" },
       ...
     ]
   }
   ```

2. **Add cross-extension entries to present's `index-entries.json`** for the 15 shared resources, tagged with both `/slides` and `/deck` agents/commands:
   ```json
   {
     "path": "project/founder/deck/animations/fade-in.md",
     "summary": "CSS fade entrance via v-click (shared slidev primitive)",
     "load_when": {
       "agents": ["slidev-assembly-agent", "slide-planner-agent", "deck-builder-agent", "deck-planner-agent"],
       "commands": ["/slides", "/deck"]
     }
   }
   ```

3. **Add `"dependencies": ["founder"]`** to present's `manifest.json` as documentation of the relationship (even without loader enforcement).

4. **Normalize index category names** to singular form across both extensions for consistency.

#### Phase 2: Loader Enforcement (Medium effort, meta task)

1. **Implement dependency resolution in the extension loader**: When loading an extension, check `dependencies` and auto-load prerequisites first.
2. **Add validation**: Warn if a dependency is not available.
3. **Update ROADMAP.md** with "Extension dependency resolution" entry.

#### Phase 3: Micro-Extension Extraction (Large effort, when 3+ consumers exist)

1. **Create `slidev-core` extension** containing only animations, styles, and the shared index.
2. **Both founder and present declare `"dependencies": ["slidev-core"]`**.
3. **Remove animations/styles from founder's deck directory** (breaking change, requires migration).
4. **Epidemiology declares `"dependencies": ["slidev-core", "present"]`** when it gains slide capability.

This phase is deferred until a third extension needs slidev resources, which would validate the extraction.

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Primary approach (.context/slidev/ shared layer) | completed | high |
| B | Alternative patterns (deps, micro-ext, tag-discovery) | completed | high |
| C | Critic (size measurement, enforcement gaps, edge cases) | completed | high |
| D | Strategic horizons (roadmap alignment, creative alternatives) | completed | high |

## References

- Present talk index: `.claude/extensions/present/context/project/present/talk/index.json`
- Founder deck index: `.claude/extensions/founder/context/project/founder/deck/index.json`
- Extension development guide: `.claude/context/guides/extension-development.md`
- Context discovery patterns: `.claude/context/patterns/context-discovery.md`
- Zed port report: `/home/benjamin/.config/zed/specs/073_port_vision_slidev_resources/reports/01_vision-slidev-port.md`
- Vision source: `/home/benjamin/Projects/Logos/Vision/.context/deck/`
