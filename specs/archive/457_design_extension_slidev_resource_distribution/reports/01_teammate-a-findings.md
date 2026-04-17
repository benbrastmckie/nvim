# Teammate A Findings: Extension-Based Slidev Resource Distribution

## Key Findings

### Finding 1: Two Separate Resource Patterns Exist Side-by-Side

The founder and present extensions use **fundamentally different distribution strategies**:

**Founder extension (`founder:deck`)**:
- Resources live at `.claude/extensions/founder/context/project/founder/deck/`
- The `deck-builder-agent` and `deck-planner-agent` reference `@.context/deck/index.json` (local project context)
- At first use, agents initialize: `cp -r .claude/extensions/founder/context/project/founder/deck/* .context/deck/`
- This is a **seed-then-copy** pattern: the extension is read-only canonical seed; `.context/deck/` is the mutable runtime copy
- `index.json` in the extension has 45+ fully-resolved entries with real paths

**Present extension (`present:slides`)**:
- Resources live at `.claude/extensions/present/context/project/present/talk/`
- The `slidev-assembly-agent` references `@.claude/context/project/present/talk/...` directly (no seed-copy)
- The `talk/index.json` has **null paths** for animations and styles with notes like "Reference .claude/extensions/founder/context/project/founder/deck/animations/ directly"
- This creates a **dangling reference** pattern: present's index points outside its own extension

### Finding 2: The Components Directory Is Not Duplicated

Both extensions have components, but they are **distinct domain-specific sets**:

- `founder/deck/components/`: `MetricCard.vue`, `TeamMember.vue`, `TimelineItem.vue`, `ComparisonCol.vue` (investor pitch components)
- `present/talk/components/`: `FigurePanel.vue`, `DataTable.vue`, `CitationBlock.vue`, `StatResult.vue`, `FlowDiagram.vue` (academic research components)

There is **zero actual duplication** of Vue components between the two. The present extension also stores these directly in both locations (the component files physically exist in both `talk/components/` AND, oddly, the listing showed them co-located).

### Finding 3: Actual Shared Resources Are: Animations + CSS Styles

The only resources that present's `talk/index.json` explicitly defers to founder for are:
- **6 animations** (`fade-in`, `slide-in-below`, `metric-cascade`, `rough-marks`, `scale-in-pop`, `staggered-list`)
- **9 CSS styles** (4 color presets, 3 typography, 2 texture)

These are genuinely cross-domain: both investor pitch decks and academic talk slides need fade-in animations and CSS typography. These are pure Slidev mechanics, not domain-specific content.

### Finding 4: The `load_when` System Has a Multi-Extension Blind Spot

The current `load_when` schema supports:
```json
{
  "load_when": {
    "agents": ["deck-planner-agent", "deck-builder-agent"],
    "commands": ["/deck"],
    "task_types": ["deck"]
  }
}
```

**Problem**: There is no mechanism in `load_when` for "load when extension X OR extension Y is loaded". The system tags by agents, commands, and task_types -- not by extension combination state. When both founder and present are loaded, shared resources like animations could appear twice in the merged `index.json` (once per extension's `index-entries.json`).

### Finding 5: The `dependencies` Array Is Unused But Present

Every extension manifest has `"dependencies": []` currently. The loader reads this field (per the architecture docs), but no extension currently declares any dependencies. This is an **available hook** for cross-extension dependency declarations.

### Finding 6: The `.context/deck/` Seed Pattern Is a Pivot Point

The deck-builder-agent uses:
```bash
if [ ! -f .context/deck/index.json ]; then
  mkdir -p .context/deck
  cp -r .claude/extensions/founder/context/project/founder/deck/* .context/deck/
fi
```

This means the deck library is designed to be **project-local and mutable** -- not consumed directly from the extension. This is intentional: users can customize their local `.context/deck/` copy. The slidev-assembly-agent for present does NOT use this pattern -- it reads directly from the extension path.

---

## Recommended Approach

### Architecture: Shared Slidev Core Layer via `.context/slidev/`

The cleanest solution is a **shared context layer** using the existing `.context/` project directory, with a defined initialization step in both `skill-deck-plan` and `skill-slide-planning`.

**Proposed directory structure:**

```
.context/
└── slidev/                          # Shared slidev runtime layer (created on first use)
    ├── index.json                   # Combined index (initialized from founder, extended by present)
    ├── animations/                  # Copied from founder at first use
    │   ├── fade-in.md
    │   ├── slide-in-below.md
    │   ├── metric-cascade.md
    │   ├── rough-marks.md
    │   ├── scale-in-pop.md
    │   └── staggered-list.md
    └── styles/                      # Copied from founder at first use
        ├── colors/
        ├── typography/
        └── textures/
```

Domain-specific resources remain in their respective extensions:
```
.claude/extensions/founder/context/project/founder/deck/
    themes/, patterns/, components/, contents/     # founder-only

.claude/extensions/present/context/project/present/talk/
    themes/, patterns/, components/, contents/     # present-only
```

**Initialization pattern** (added to `skill-deck-plan` and `skill-slide-planning`):

```bash
# Initialize shared slidev layer if absent
if [ ! -f .context/slidev/index.json ]; then
  mkdir -p .context/slidev
  cp -r .claude/extensions/founder/context/project/founder/deck/animations/ .context/slidev/animations/
  cp -r .claude/extensions/founder/context/project/founder/deck/styles/ .context/slidev/styles/
  # Build combined index with only animation + style entries
  jq '[.entries[] | select(.category == "animation" or .category == "style")]' \
    .claude/extensions/founder/context/project/founder/deck/index.json \
    > .context/slidev/index.json
fi
```

**Agent context references** (both deck-builder and slidev-assembly use):
```markdown
- `@.context/slidev/index.json` - Shared animation + style catalog
- `@.context/slidev/animations/{id}.md` - Load specific animation patterns
```

### Index Schema for Shared Resources

The `load_when` design should tag shared resources with **both** command sets:

```json
{
  "path": "slidev/animations/fade-in.md",
  "category": "animation",
  "summary": "CSS fade entrance via v-click opacity transition",
  "load_when": {
    "agents": [
      "deck-planner-agent", "deck-builder-agent",
      "slidev-assembly-agent", "slide-planner-agent"
    ],
    "commands": ["/deck", "/slides"],
    "task_types": ["founder:deck", "present:slides"]
  }
}
```

Domain content stays tagged to only its owner:
```json
{
  "path": "founder/deck/patterns/yc-10-slide.json",
  "summary": "YC 10-slide investor pitch pattern",
  "load_when": {
    "agents": ["deck-planner-agent", "deck-builder-agent"],
    "commands": ["/deck"]
  }
}
```

### The `dependencies` Alternative (Simpler, No Runtime Copy)

A lighter approach: declare `founder` as a dependency in `present`'s manifest:

```json
// present/manifest.json
{
  "dependencies": ["founder"],
  ...
}
```

Then in `present`'s `index-entries.json`, add real (non-null) entries for founder's animations/styles with both command sets in `load_when`:

```json
{
  "path": "project/founder/deck/animations/fade-in.md",
  "summary": "CSS fade entrance - shared with present:slides",
  "load_when": {
    "agents": ["slidev-assembly-agent", "deck-builder-agent"],
    "commands": ["/slides", "/deck"]
  }
}
```

**Tradeoff**: If founder is NOT loaded, this breaks (null path problem resurfaces). The dependency declaration in the loader would need to enforce co-loading.

### Recommended: `.context/slidev/` Shared Layer (Option A)

**Rationale**:
1. Consistent with existing `.context/deck/` seed pattern already established for founder
2. No cross-extension dependency required -- works regardless of which extensions are loaded
3. Mutable: users can add custom animations/styles to `.context/slidev/` without touching extensions
4. Context bloat prevention: `load_when` tags ensure only relevant resources load per command
5. Single source of truth for shared resources at runtime

**What does NOT move**:
- Domain content (investor pitch templates, academic slide templates) stays in each extension
- Domain-specific components stay in each extension
- Domain-specific themes stay in each extension
- Only animations and CSS styles are shared (these are pure Slidev mechanics)

---

## Evidence / Examples

### Current State: Null Pointer in present's talk/index.json
```json
// present/context/project/present/talk/index.json
{
  "animations": {
    "path": null,
    "note": "Reference .claude/extensions/founder/context/project/founder/deck/animations/ directly"
  }
}
```
This is a **documented known gap** in the current system.

### Existing Seed Pattern in deck-builder-agent.md
```bash
if [ ! -f .context/deck/index.json ]; then
  mkdir -p .context/deck
  cp -r .claude/extensions/founder/context/project/founder/deck/* .context/deck/
fi
```
The `.context/slidev/` proposal follows this **same established pattern**, just scoped to shared resources only.

### Founder `index-entries.json`: deck/index.json entry
```json
{
  "path": "project/founder/deck/index.json",
  "load_when": {
    "agents": ["deck-planner-agent", "deck-builder-agent", "deck-research-agent"],
    "commands": ["/deck"]
  }
}
```
This loads the whole 477-line deck index only for `/deck` commands. With the shared layer, `/slides` would load only the 15-entry shared index.

### Extension Loader: Dependencies Array
All manifests currently have `"dependencies": []` -- the field exists in the spec but is unused. The loader already has `check_conflicts()` logic; dependency checking would be additive.

---

## Confidence Level: High

The `.context/slidev/` shared layer approach is:
- Consistent with existing patterns (`.context/deck/` precedent)
- Non-destructive (doesn't modify any existing extension)
- Technically feasible with the current loader architecture
- Well-scoped: only animations and CSS styles are truly shared, not themes or content

The only open question is whether the epidemiology extension might also need academic slide animations in the future -- but the shared layer design handles this naturally (any extension can reference `.context/slidev/`).
