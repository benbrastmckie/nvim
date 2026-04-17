# Teammate C: Critic Findings
# Task 457: Extension-Based Slidev Resource Distribution

**Role**: Critic - Gaps and Blind Spots
**Date**: 2026-04-16

---

## Key Findings (What Is Being Overlooked)

### 1. The "Shared Resources" Are Smaller Than Feared

The founder deck resources that present extension currently null-pointers to are:
- **6 animation files**: 315 lines total (~52 lines/file)
- **4 color CSS files**: 52 lines total (~13 lines/file)
- **3 typography CSS files**: 73 lines total
- **2 texture CSS files**: 36 lines total
- **4 Vue components** (MetricCard, TeamMember, TimelineItem, ComparisonCol): 143 lines total
- **founder deck index.json**: 477 lines

Total "shared" resources: ~1,096 lines across 19 files.

At ~4 tokens/line, this is roughly **4,400 tokens** — a significant fraction of the TOKEN_BUDGET=2000 cap used in the memory retrieval system, but not the entire context window. The fear of "context bloat" needs to be weighed against the actual numbers. Duplication of 19 files (1,096 lines) is not trivially small but is also not catastrophically large.

**Critical insight**: The founder deck `index.json` itself is 477 lines and is what agents actually load for deck construction. If the "shared" strategy requires both extensions' index files to be loaded simultaneously, that's 477 + 70 (present's talk/index.json) = 547 lines of index alone, before any actual resource files.

### 2. The `dependencies` Field Is Declared But Not Enforced

Both manifests declare `"dependencies": []`. The manifest validator (`manifest.lua:validate`) checks only required fields (`name`, `version`, `description`), provides categories, and merge_targets. It **does not validate or enforce dependencies**.

The loader (`init.lua:manager.load`) makes no calls to check or enforce dependency ordering. There is no code in the load path that reads `ext_manifest.dependencies` and requires those extensions to be loaded first.

**Implication**: A "shared-base" extension pattern (e.g., `"slidev"` extension that `founder` and `present` depend on) could declare the dependency in the manifest, but nothing would actually enforce it. Users could load `present` without loading `slidev`, and the `dependencies` field would silently do nothing.

### 3. The Null-Pointer Pattern Is Already Broken

The `present/talk/index.json` currently has:
```json
"animations": {
  "path": null,
  "note": "Reference .claude/extensions/founder/context/project/founder/deck/animations/ directly"
},
"styles": {
  "path": null,
  "note": "Reference .claude/extensions/founder/context/project/founder/deck/styles/ for base styles"
}
```

This null-pointer approach requires agents to:
1. Know to check the `note` field
2. Construct the correct absolute path to the extension source directory
3. Have that path be valid in the context where the extension is installed

**The path in the note is an extensions source path, not a deployed path.** When the founder extension is loaded into a project, its context files are copied to `.claude/context/project/founder/deck/`. The note references `.claude/extensions/founder/context/project/founder/deck/` which is only valid in the nvim config repo itself, not in typical project deployments where extensions are loaded.

### 4. Context Path Resolution Is Fundamentally Per-Project

Extensions are loaded by **copying** files from `~/.config/nvim/.claude/extensions/{name}/context/` into the target project's `.claude/context/`. After loading:
- founder content lives at `<project>/.claude/context/project/founder/deck/`
- present content lives at `<project>/.claude/context/project/present/talk/`

The extension source directory (`~/.config/nvim/.claude/extensions/`) is irrelevant at runtime. Any cross-reference mechanism must work with the post-copy paths. This eliminates any strategy that relies on source paths being stable references at agent-runtime.

### 5. Vue Component Naming Conflict Is Real, Not Hypothetical

Present extension provides: `FigurePanel`, `DataTable`, `CitationBlock`, `StatResult`, `FlowDiagram`
Founder extension provides: `MetricCard`, `TeamMember`, `TimelineItem`, `ComparisonCol`

These currently don't conflict. However, both libraries are clearly growing. If `present` later adds a `TimeLine` or `Chart` component, and `founder` already has `TimelineItem` — a collision is possible. More concerning: **there is no namespace mechanism in the Slidev component system**. Vue components loaded into a Slidev project are registered globally. If both extension libraries are copied to the same Slidev project's `components/` directory, a name collision would silently overwrite one with the other.

This is a Slidev-level problem, not just a context-level problem.

---

## Gaps and Shortcomings in Likely Approaches

### Gap 1: "Shared Extension" Approach Requires Infrastructure That Doesn't Exist

A proposed "shared slidev extension" that founder and present both depend on would require:
1. Dependency enforcement in the loader (currently absent)
2. A new UX where loading `present` automatically loads `slidev` first
3. A way to prevent `slidev` from being unloaded while `founder` or `present` is loaded
4. Versioning alignment between the three extensions

None of these capabilities exist today. The `dependencies` array is documented as optional, not enforced. Building a shared extension layer requires non-trivial loader changes before any content migration.

### Gap 2: Index Category Name Inconsistency Signals Different Mental Models

Founder deck `index.json` uses singular categories: `animation`, `component`, `content`, `pattern`, `style`, `theme`.
Present talk `index.json` uses plural categories: `animations`, `components`, `content`, `patterns`, `styles`, `themes`, `templates`.

These are structurally different schemas for the same concept. Any unification strategy must reconcile this inconsistency or maintain two separate schemas indefinitely.

### Gap 3: The Epidemiology Extension Has Unique Visualization Needs Not Covered by Either Library

The epidemiology extension (`epi` task type) handles research presentations. Epidemiology presentations have fundamentally different visual requirements:
- Forest plots (meta-analysis)
- Kaplan-Meier survival curves
- STROBE/CONSORT flow diagrams
- DAG (Directed Acyclic Graph) visualizations for causal inference
- Risk ratio tables with confidence intervals

The present extension's academic library includes `results-forest-plot.md` and `results-kaplan-meier.md` content templates, suggesting this overlap was anticipated. However, the epidemiology extension has no `slides` command and no Slidev context. If epi presentations are desired, the epi extension would need to either:
a. Depend on `present` for slides infrastructure
b. Have its own slides resources (redundancy)
c. Be treated as a sub-domain of `present` (architectural change)

The task description says "without redundancy" — but epi-specific visualization components cannot be satisfied by either the founder or present libraries without extension.

### Gap 4: "Conditional Inheritance" Is Not an Extensible Pattern

If the strategy is "when both founder and present are loaded, the agent gets both libraries," this creates implicit behavioral coupling. Agents would need to know which libraries are available at runtime and adapt their behavior. The current `load_when` system in `index.json` is **static** — it binds context files to agents/task_types/commands at load time, not based on what other extensions happen to be loaded.

There is no `load_when.extensions_loaded` condition in the schema. Adding this would require changes to the context discovery mechanism and the adaptive query in CLAUDE.md.

### Gap 5: The Actual Overlap Between Founder and Present Is Asymmetric

Founder's Slidev resources exist for **investor pitch decks** (dark themes, business metrics, team cards, CTA slides). Present's Slidev resources exist for **academic talks** (white themes, data tables, citation blocks, figure panels).

The animation primitives (fade, slide-in, stagger) are genuinely shared. But the CSS styles are **domain-specific**: founder uses dark/gold/navy themes; present uses academic-clean/UCSF-institutional/clinical-teal themes. Sharing CSS at the variable level requires either:
- Abstract CSS variables that each domain overrides
- A minimal shared base with domain-specific overrides

This is a CSS architecture problem, not just an index organization problem.

---

## Questions That Need Answers

1. **What does "sharing" actually mean at runtime?** When an agent builds a Slidev deck for a `present:slides` task, should it be able to use `MetricCard` from founder? If yes, that implies intentional cross-domain resource use. If no, "sharing animations/styles" is really just "both extensions happen to use similar CSS patterns" — which doesn't require any infrastructure.

2. **Are the Slidev resource files used as context (text in agent prompt) or as project scaffold files (copied to the deck project)?** The `copy_data_dirs` loader function suggests data directories can be scaffold-copied. If resource files are scaffolded to the project, the cross-extension path problem is a deployment-time issue, not a context-loading issue.

3. **What is the actual failure mode today?** The present extension has null-pointers to founder animations/styles. Does this mean current `present:slides` tasks produce Slidev decks without animations? Or do agents successfully ignore the null and produce working decks?

4. **What is the TOKEN_BUDGET for full context loading (not just memory retrieval)?** The 2000-token memory budget is specifically for the memory-retrieve.sh script. The full agent context window is much larger. Context bloat from 1,096 additional lines may be acceptable in practice.

5. **Should the epidemiology extension have a `/slides` command?** The epi extension has `epi-research-agent` and `epi-implement-agent` but no slide-building agents. Epi researchers give presentations. If this is a real use case, the architecture needs to support `epi:slides` routing to a slidev agent that combines epi-domain content (forest plots, DAGs) with the shared Slidev infrastructure.

6. **What happens when both founder and present are loaded into the same project?** Can a user simultaneously work on a pitch deck (founder:deck) and a conference talk (present:slides) in the same project? If yes, both extensions' index entries are merged into index.json, and both libraries are discoverable. Is this tested?

---

## Confidence Level

**High confidence** on:
- File sizes and line counts (measured directly)
- Dependency enforcement gap (confirmed by reading manifest.lua and init.lua)
- Null-pointer path issue (the paths reference extension source dir, not deployed dir)
- Vue component namespace absence (inherent to Slidev's component system)

**Medium confidence** on:
- Token budget implications (depends on total context window usage, not just these files)
- Epidemiology slides gap (inferred from extension structure, not confirmed user need)
- CSS architecture problem (the styles are domain-specific but sharing animations is feasible)

**Low confidence** on:
- Whether the current null-pointer pattern breaks in practice (would need to actually run a present:slides task to verify)
- Whether dependency enforcement is actually needed vs. just documented as a user responsibility
