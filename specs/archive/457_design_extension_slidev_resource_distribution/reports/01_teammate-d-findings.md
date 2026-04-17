# Teammate D: Strategic Horizons — Task 457

## Key Findings

### 1. The `dependencies: []` field already exists in every manifest

Every extension manifest has `"dependencies": []` — an empty array, never populated.
The infrastructure slot for declaring inter-extension dependencies exists today; it
just has no semantics attached. This is not accidental scaffolding: it signals that
the original system designer anticipated this need and deferred it.

Implementing inter-extension dependencies would complete an existing design intent
rather than introduce a foreign pattern.

### 2. Present already hard-codes a null-reference pattern that is fragile

In `present/context/project/present/talk/index.json`, two categories have
`"path": null` with notes like:

```
"Reference .claude/extensions/founder/context/project/founder/deck/animations/ directly"
```

This is a documented workaround, not a solution. It only works if both extensions
happen to be loaded simultaneously. If only `present` is loaded (without `founder`),
agents receive instructions to reference a path that does not exist in the merged
context. The current state introduces silent failures.

### 3. The cross-extension sharing pattern is narrow today but will grow

Currently only present→founder has this dependency. But examining the other
extensions reveals predictable future cases:
- `epidemiology` produces research presentations; it will eventually want the
  same slidev animations/styles from `founder` or `present`
- `typst` and `latex` are document-generation extensions; if either gains
  presentation support they face the same choice
- `web` could benefit from shared component patterns

This is not a one-off problem. It is an emerging class of problem. A structural
solution now avoids ad-hoc workarounds accreting across 5+ extensions over the
next year.

### 4. The `dependencies` field in manifest.json is the minimal viable integration point

The loader already reads `manifest.json`. Adding semantics to `dependencies` requires:
1. The loader to parse `dependencies: ["founder"]` in present's manifest
2. Auto-load the listed extensions before loading the dependent
3. No changes to agent prompt construction, context merging, or index format

The rest of the system stays identical. This is the minimum change surface.

### 5. Shared resource extraction is a separate, higher-cost option

An alternative is creating a `slidev-core` micro-extension that both `founder`
and `present` depend on. This is architecturally cleaner for long-term
maintainability but requires:
- Creating a new extension from scratch
- Migrating resources out of `founder` (breaking existing founder agents)
- Updating all founder index-entries that reference deck/animations and deck/styles
- Testing that founder still works after migration

The cost is higher and the blast radius is larger. This approach is worth doing
eventually, but is likely out of scope for this task.

### 6. The ROADMAP.md does not mention extension sharing at all

The current roadmap focuses on:
- Manifest-driven README generation
- Extension slim standard enforcement
- Agent frontmatter validation

None of these address cross-extension dependencies. This task is filling a gap
that the roadmap has not yet articulated. Completing it well could inform a roadmap
entry: "Extension dependency resolution: allow extensions to declare and auto-load
prerequisite extensions."

---

## Strategic Recommendations

### Primary recommendation: Populate `dependencies` field semantics in the loader

The cleanest minimal solution is:

1. Add `"dependencies": ["founder"]` to `present/manifest.json`
2. Add `"dependencies": ["present", "founder"]` to `epidemiology/manifest.json`
   (or just `present` if epidemiology will use present's academic slidev resources)
3. Update the loader script to auto-load listed dependencies before the main extension
4. Remove the null-path workarounds from `present/talk/index.json`

This is a meta-task change (touches `.claude/` infrastructure) but a small one.
The benefit is that the `null`-path anti-pattern disappears and agents reliably
find the files they need.

### Secondary recommendation: Scope epidemiology carefully

The task description groups three extensions (epidemiology, founder, present) as
if they have equal needs. In practice:
- `founder` is the resource provider
- `present` is an active consumer (null-reference workaround already in place)
- `epidemiology` has no slidev content whatsoever in its current context tree

Before designing for epidemiology, determine whether epidemiology actually uses
slidev today, or whether that is a future capability. If future, it can be deferred.
The present→founder dependency is the concrete, solved-today problem.

### Tertiary recommendation: Consider a shared-resources boundary document

Regardless of mechanism, a one-page document in `.claude/context/` (or in the
`present` extension) should declare what resources are "stable API" vs. internal
to `founder`. Currently the boundary is implicit. If `present` depends on
`founder/deck/animations/`, those animation files become a semi-public interface.
Documenting that boundary prevents `founder` changes from breaking `present` silently.

---

## Creative Alternatives

### Alternative A: Resource Provider Protocol

Extensions declare `provides.shared_resources` in manifest.json:

```json
"provides": {
  "shared_resources": {
    "slidev-animations": "context/project/founder/deck/animations/",
    "slidev-styles": "context/project/founder/deck/styles/"
  }
}
```

Consumers declare `requires.shared_resources`:

```json
"requires": {
  "shared_resources": ["slidev-animations", "slidev-styles"]
}
```

The loader resolves these at load-time and injects symlinks or copies into the
consumer's context directory. This is more abstract than a simple dependency list
and avoids hard-coding path relationships between extensions. The consumer does not
need to know which extension provides `slidev-animations`; the registry resolves it.

**Tradeoff**: More complex to implement than `dependencies`, but more loosely coupled.
A `slidev-core` micro-extension later just registers the same resource keys. No
consumer changes needed.

### Alternative B: Conditional index entries in `present`

Without any loader changes, present's `index-entries.json` could declare entries
that resolve to paths under `founder/deck/` using the canonical path format:

```json
{
  "path": "project/founder/deck/animations/fade-in.md",
  "load_when": { "agents": ["slidev-assembly-agent"] }
}
```

This works if both extensions are loaded. The present extension would include
founder-hosted files in its own index without a dependency declaration. The loader
already merges all index entries; this just means present's entries point into
founder's context tree.

**Tradeoff**: Fragile (silently fails if founder not loaded), but zero loader
changes. A viable short-term fix while a proper dependency mechanism is built.

### Alternative C: Shared context namespace in core

Move slidev primitives (animations, styles, base components) out of both `founder`
and `present` and into `.claude/context/project/shared/slidev/`. The core loader
always includes `project/shared/` regardless of which extensions are loaded.
Extensions opt-in via index entries that load from the shared namespace.

**Tradeoff**: Requires migrating founder's existing deck resources, but creates a
genuinely extension-agnostic home for presentation infrastructure. Aligns with the
core system philosophy that language-agnostic patterns belong in the core.

---

## Confidence Level

**High** on the strategic direction:
- The `dependencies: []` field is the right integration point
- The present→founder null-path workaround is the active pain point to fix
- The solution is small and does not require creating new extensions

**Medium** on implementation specifics:
- Loader modification details depend on the loader script's current structure
- Whether epidemiology needs slidev resources now vs. later affects scope

**Low** on the micro-extension approach:
- Extracting `slidev-core` is architecturally appealing but not validated as
  necessary at current scale; premature until at least 3 extensions need the same resources

---

*Report written: 2026-04-16*
*Scope: Strategic alignment, long-term direction, creative alternatives*
