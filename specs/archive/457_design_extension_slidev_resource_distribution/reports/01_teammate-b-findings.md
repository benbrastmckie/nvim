# Teammate B Findings: Alternative Approaches to Extension-Based Slidev Resource Distribution

**Task 457** | Research Phase | Teammate B (Alternative Approaches)
**Date**: 2026-04-16

---

## Key Findings

### 1. The Current State is Documented Incompleteness

The present extension's `talk/index.json` has `null` paths for animations and styles with inline
prose notes saying "Reference founder extension directly." This is not a working solution -- it is
a deferred design decision that was never resolved. Agents reading this index will encounter null
paths and cannot act on them without understanding the cross-extension reference convention.

The current approach breaks the contract that `index.json` establishes: every category should
have an actionable path or items list. Null paths with prose notes require agents to understand
an implicit convention rather than follow a machine-readable contract.

### 2. Every Extension Currently Declares `"dependencies": []`

All 14 extensions in `.claude/extensions/` have empty `dependencies` arrays in their
`manifest.json`. The field exists -- the schema supports it -- but it has never been used. This is
significant: the extension system was designed with dependencies in mind but the pattern was never
exercised. The present extension already depends on founder resources (for animations and styles)
but this dependency is undeclared and only communicated via prose comments in index.json.

### 3. Slidev's Own Addon System Uses Declarative Composition

Slidev supports multiple addons in a single project. The resolution priority is:
`local project components > theme > addons > built-in`. When multiple addons provide
components with the same name, the last-loaded addon wins (no explicit conflict handling).
Slidev addons share by coexistence -- they all expose to the same namespace, not by
explicit cross-addon imports. This means Slidev itself does not have a model for "Addon A
depends on Addon B"; it assumes each addon is self-contained.

This is relevant because it confirms the sharing problem is at the **agent context** level
(what files agents read when building decks), not the Slidev runtime level (what Vue
components are available). The runtime sharing works fine. The problem is agents in the
`present` extension don't know about `founder` animations/styles unless the founder
extension is also loaded.

### 4. Three Distinct Alternative Architectures Exist

See the section below for full analysis.

---

## Alternative Approaches

### Alternative A: Declared Extension Dependencies + Cross-Extension Index References

**Pattern**: Use the existing but empty `dependencies` field in `manifest.json` to declare
that `present` depends on `founder`. When the extension loader loads `present`, it
automatically ensures `founder` context files are available. The present extension's
`index-entries.json` then references founder paths directly using absolute extension paths.

**How it works**:
```json
// present/manifest.json
{
  "dependencies": ["founder"],
  ...
}
```

```json
// present/index-entries.json - new entries added:
{
  "path": "project/founder/deck/animations/fade-in.md",
  "summary": "Fade entrance animation (from founder deck library)",
  "load_when": {
    "agents": ["slidev-assembly-agent"],
    "commands": ["/slides"]
  }
}
```

The present `talk/index.json` `animations` and `styles` categories get real paths pointing
into the founder directory structure, which is guaranteed to exist because the loader
enforces the dependency.

**Trade-offs**:
- **Complexity**: Low. The `dependencies` field already exists; only the loader needs a
  small enforcement step (check that dependencies are loaded before loading the dependent).
- **Brittleness**: Medium. If the founder extension moves or renames its animation directory,
  the present extension's hardcoded cross-extension paths break silently. The dependency
  declaration catches "founder not loaded" but not "founder restructured".
- **Context budget impact**: Low overhead. No duplication -- agents read from one canonical
  location. The founder deck library (~477 lines for index.json alone) is not duplicated.
- **Maintenance burden**: Low once the dependency contract is established. Adding new
  animations to founder automatically makes them available to present.

**Precedent**: Maven/Gradle BOM pattern. When a project declares a platform dependency,
it gets consistent version alignment without duplicating the dependency catalog. Here,
`present` declaring `"dependencies": ["founder"]` gets guaranteed access to founder's
resources without duplicating them.

---

### Alternative B: Capability-Tagged Shared Resources as a Third Extension

**Pattern**: Extract the shared Slidev resources (6 animations, 9 CSS presets, 3 generic
components) into a third extension: `slidev-core` (or `slides-shared`). Both `founder`
and `present` declare `"dependencies": ["slidev-core"]`. The `slidev-core` extension has
no agents or commands of its own -- it is a pure context library.

**How it works**:
```
extensions/
  slidev-core/         # NEW: pure resource extension
    manifest.json      # no agents, no routing, just context
    context/project/slidev/
      animations/      # 6 shared animation patterns
      styles/          # 9 CSS presets (generic, no brand)
      components/      # MetricCard.vue, TimelineItem.vue, ComparisonCol.vue
      index.json       # catalog of all shared resources
    index-entries.json # entries tagged with "slidev" topic
  founder/             # deck library: brand-specific themes + patterns
    manifest.json: { "dependencies": ["slidev-core"] }
  present/             # talk library: academic themes + content
    manifest.json: { "dependencies": ["slidev-core"] }
```

Tags in `index-entries.json` entries use a capability approach:
```json
{
  "path": "project/slidev/animations/fade-in.md",
  "topics": ["slidev", "animation", "entrance"],
  "keywords": ["slidev:animation"],
  ...
}
```

Agents needing animations query by `topic: "slidev:animation"` rather than by explicit path.

**Trade-offs**:
- **Complexity**: Higher up-front. Creating a new extension requires manifest, loader
  registration, and migration of existing files. The 3 "generic" Vue components
  (MetricCard, TimelineItem, ComparisonCol) are already in founder and would need to be
  moved or duplicated to determine which are truly generic vs. business-specific.
- **Brittleness**: Low once established. The shared extension is stable because it only
  contains genuinely domain-agnostic resources. Changes to business-specific deck content
  in `founder` don't affect it.
- **Context budget impact**: None (no duplication). Agents querying by topic load only
  the files they need. The capability tag approach enables lazy loading better than
  explicit path references.
- **Maintenance burden**: Higher ongoing. Three extensions instead of two. Decisions
  about "is this resource shared or domain-specific?" must be made explicitly when adding
  new content. Potentially beneficial as a forcing function for good resource hygiene.

**Precedent**: VS Code Extension Packs / Webpack Module Federation. VS Code Extension
Packs install bundled dependencies but the documentation explicitly states packs should
have "no functional dependency" with bundled extensions -- each must work independently.
This pattern inverts that: `slidev-core` has no independent use, it only exists to be
consumed. Module Federation's `shared:` configuration handles exactly this scenario --
declaring a shared singleton that multiple apps consume without duplication.

**Significant issue**: MetricCard, TimelineItem, and ComparisonCol are listed in both the
founder `deck/index.json` (as components) and are generic enough for academic use. But
they require Slidev's Vue runtime, so "sharing" them at the agent context level is
different from sharing them at the presentation runtime level. Agents reading about these
components would reference them in generated Slidev code; the actual `.vue` files need to
be in each project's `components/` directory anyway.

---

### Alternative C: Federated Query with Tag-Based Discovery at Runtime

**Pattern**: No structural changes to extensions. Instead, when an agent needs animations
or styles, it queries the loaded context index using capability tags rather than navigating
to a specific path. The index.json entries across all loaded extensions are tagged with
structured capability markers. A query layer resolves "I need Slidev animations" to
whichever loaded extension provides them.

**How it works**:
The `slidev-assembly-agent` prompt is updated to use a discovery query instead of a
hardcoded path:

```bash
# In agent context loading step:
jq -r '.entries[] | select(.keywords[]? | contains("slidev:animation")) | .path' \
  .claude/context/index.json
```

This returns animation paths from whichever extension(s) are loaded. If `founder` is
loaded, it returns founder paths. If `slidev-core` were ever created, it would return
those paths. The agent gets what's available without knowing the source.

The present extension's `talk/index.json` null entries are replaced with a discovery
instruction:
```json
"animations": {
  "description": "Reuse animation patterns from loaded slide extensions",
  "discovery": "keywords: slidev:animation",
  "path": null
}
```

**Trade-offs**:
- **Complexity**: Medium. Requires standardizing a tagging vocabulary (`slidev:animation`,
  `slidev:style`, etc.) across extensions and updating agent prompts to use discovery
  queries. The jq query pattern is already established in this codebase.
- **Brittleness**: Low. No hardcoded cross-extension paths. If the founder extension is
  not loaded, the query returns nothing -- the agent must handle the empty case gracefully.
  This makes the dependency implicit rather than explicit, which can be a liability
  (silent failure) or an asset (works with any combination of loaded extensions).
- **Context budget impact**: Variable. The discovery query loads entries from all loaded
  extensions, but agents only read the matched files. If no slide extension is loaded,
  budget impact is zero. With both founder and present loaded, budget equals the union of
  matched entries.
- **Maintenance burden**: Low per-extension. Each extension just tags its entries
  correctly. No cross-extension coordination required. The vocabulary of tags needs
  maintenance as new resource types emerge.

**Precedent**: Navidrome's capability-based plugin system. When Navidrome needs metadata,
it iterates registered agents and invokes them if a plugin exports the required functions.
The host doesn't care which plugin satisfies the capability -- only that something does.
This is the same model applied to context loading.

---

## Evidence / Examples from Other Ecosystems

### VS Code Extension Packs
Extension packs bundle extensions together but must not create functional dependencies.
This is instructive by contrast: it shows that the VS Code model avoids the exact problem
we're solving (shared resources between extensions). The VS Code approach would be to
duplicate resources in each extension, accepting redundancy to preserve independence.
This is appropriate for user-facing tooling but wasteful for an internal agent context
system where duplication inflates the context budget.

### Webpack Module Federation (Shared Singletons)
Module Federation's `shared` configuration is the closest analogue to our problem. When
two micro-frontends both need React, they declare it as a shared singleton. The host
negotiates which version is loaded and ensures only one copy exists at runtime. For our
system, the "singleton" is the animation/style context: both `founder` and `present`
agents need it, and there should be exactly one canonical copy. Alternative A (declared
dependencies) achieves this by pointing to the founder copy; Alternative B achieves it
by creating a neutral shared extension.

### Maven Bill of Materials (BOM)
The BOM pattern defines a version catalog that dependent projects import. The analogy
here is weak because our "versions" don't change frequently, but the structural insight
is useful: a dedicated artifact whose sole purpose is to define a shared resource catalog
is a legitimate and widely-used pattern (Alternative B).

### Terraform Provider Composition
Terraform modules cannot contain provider configuration -- providers are global to the
root module and passed down. Child modules implicitly inherit parent providers. This
enforces exactly the kind of "single canonical source" that Alternative A implements:
when `present` extension is loaded, it inherits `founder` resources via the declared
dependency, not by bundling its own copy.

### Slidev's Own Resolution Model
Slidev resolves components local > theme > addons > built-in. This means if both `founder`
and `present` were Slidev addons (they're not -- they're agent context extensions), the
last-loaded would win on name conflicts. There is no conflict mechanism. This confirms
that the agent context layer (index.json) is where our problem actually lives, not in
Slidev itself.

---

## Confidence Level

**Overall**: High

The codebase evidence is clear: the `dependencies: []` field exists and is unused; the
present extension already depends on founder resources via undeclared prose conventions;
the extension loader already handles a load ordering mechanism that could enforce
declared dependencies.

**Confidence by alternative**:
- Alternative A (declared dependencies + cross-references): **High** -- minimal new
  infrastructure, leverages existing schema fields
- Alternative B (third shared extension): **Medium** -- correct pattern but requires
  deciding which resources are genuinely shared; the MetricCard/TimelineItem/ComparisonCol
  boundary is ambiguous
- Alternative C (tag-based discovery): **Medium** -- elegant but requires agent prompt
  changes and graceful empty-case handling; increases implicit coupling

**Key recommendation for synthesis**: Alternative A is the lowest-risk immediate fix.
Alternative B is the correct long-term architecture if a third presentation domain
(e.g., epidemiology research talks) needs the same resources. Alternative C adds resilience
without solving the root cause of undeclared cross-extension dependencies.
