# Task Order Format Standard

**Purpose**: Define the Task Order section format for TODO.md, providing structured task prioritization, dependency visualization, and category-based organization.

---

## Placement

The `## Task Order` section is placed between the `# TODO` header (and optional YAML frontmatter) and the `## Tasks` section:

```markdown
---
next_project_number: 277
---

# TODO

## Task Order
{task order content}

## Tasks
{individual task entries}
```

---

## Structure Elements

### Section Header

Format: `## Task Order`
Regex: `^## Task Order$`

### Update Timestamp

Format: `*Updated YYYY-MM-DD. {changelog summary}*`
Regex: `^\*Updated (\d{4}-\d{2}-\d{2})\. (.+)\*$`

The changelog summary briefly describes what changed (tasks completed, created, reordered).

Examples:
```markdown
*Updated 2026-03-25. Task 62 completed. Task 63 created for Box backward proof.*
*Updated 2026-03-24. Created 5 tasks for /review Task Order management feature.*
```

### Goal Statement

Format: `**Goal**: {one-line project goal}`
Regex: `^\*\*Goal\*\*: (.+)$`

The goal is a single-line summary of the current project focus.

Example:
```markdown
**Goal**: Zero custom axioms, zero sorries on the completeness path.
```

---

## Category Subsections

### Header Format

Format: `### {N}. {Category Name}` or `### {N}. {Category Name} -- {Subtitle}`
Regex: `^### (\d+)\. (.+?)(?:\s+--\s+(.+))?$`

Categories are numbered sequentially starting from 1.

### Standard Categories

| Number | Name | Purpose |
|--------|------|---------|
| 1 | Critical Path | Tasks on the main dependency chain toward the goal |
| 2 | Code Cleanup | Refactoring and technical debt (parallel to critical path) |
| 3 | Experimental | Exploratory tasks with uncertain outcomes |
| 4 | Deferred | Tasks postponed due to dependencies or low priority |
| 5 | Backlog | Future work, research topics, long-term items |

Categories are customizable per project. Not all categories need to be present. Additional categories may be added as needed.

### Category Subtitles

Optional descriptive text after the category name, separated by ` -- `:

```markdown
### 1. Critical Path -- Sorry-Free Completeness
### 2. Code Cleanup (parallel to critical path)
```

---

## Dependency Chain Syntax

### Linear Chains

Format: Code block with arrow notation using `→` (Unicode U+2192).

```
63 → 58 → 59 → 60
```

Meaning: Task 63 must complete before 58, which must complete before 59, etc.
Regex (per arrow): `(\d+)\s*→\s*(\d+)`

### Branching Dependencies

For non-linear dependency graphs, use multiple lines or box-drawing characters:

```
272 → 273 → 274 ─┐
           └ 275 ┴→ 276
```

Meaning: 273 depends on 272; 274 and 275 both depend on 273; 276 depends on both 274 and 275.

### Dependency Chain Placement

Dependency chains appear immediately after the category header, before the task list:

```markdown
### 1. Critical Path -- Sorry-Free Completeness

\```
63 → 58 → 59 → 60
\```

1. **63** [RESEARCHED] -- Prove Box backward via BFMCS modal saturation
```

---

## Task Entry Format

### Ordered Entries (numbered list)

For tasks within a dependency chain or with explicit ordering:

Format: `{N}. **{task_number}** [{STATUS}] -- {brief description}`
Regex: `^\d+\.\s+\*\*(\d+)\*\*\s+\[([A-Z ]+)\]\s+--\s+(.+)$`

Example:
```markdown
1. **63** [RESEARCHED] -- Prove Box backward via BFMCS modal saturation
2. **58** [NOT STARTED] -- Wire completeness to FrameConditions (3 sorries)
```

### Unordered Entries (bullet list)

For tasks without strict ordering within a category:

Format: `- **{task_number}** [{STATUS}] -- {brief description}`
Regex: `^-\s+\*\*(\d+)\*\*\s+\[([A-Z ]+)\]\s+--\s+(.+)$`

Example:
```markdown
- **61** [NOT STARTED] -- Eliminate BFMCS bundles entirely (independent, explore later)
- **992** [RESEARCHED] -- STSA temporal shift automorphism (algebraic, independent)
```

### Inline Dependency Notes

Append dependency information in parentheses:

Format: `(depends on {N})` or `(depends on {N}, {M})`
Regex: `\(depends on ([\d,\s]+)\)`

Example:
```markdown
- **20** [NOT STARTED] -- Parametric canonical audit (depends on 18)
```

### Inline Annotations

Additional context may follow the description in parentheses:

```markdown
- **8** [RESEARCHED] -- Genuine truth_at completeness (publication quality, 12-20h)
- **619** [RESEARCHED] -- Agent system architecture upgrade (meta, blocked on GitHub #16803)
```

---

## Status Markers

Task Order entries use the same status markers as TODO.md task entries:

| Marker | Meaning |
|--------|---------|
| `[NOT STARTED]` | Task not yet begun |
| `[RESEARCHING]` | Research in progress |
| `[RESEARCHED]` | Research completed |
| `[PLANNING]` | Plan creation in progress |
| `[PLANNED]` | Plan created, ready for implementation |
| `[IMPLEMENTING]` | Implementation in progress |
| `[COMPLETED]` | Task finished |
| `[BLOCKED]` | Cannot proceed (with reason) |
| `[ABANDONED]` | Task dropped |
| `[PARTIAL]` | Partially complete |
| `[EXPANDED]` | Divided into subtasks |

Regex: `\[([A-Z ]+)\]`

---

## Complete Example

```markdown
## Task Order

*Updated 2026-03-25. Task 62 completed (documentation corrections). Task 63 created for BFMCS Box backward proof.*

**Goal**: Zero custom axioms, zero sorries on the completeness path.

### 1. Critical Path -- Sorry-Free Completeness

\```
63 → 58 → 59 → 60
\```

1. **63** [RESEARCHED] -- Prove Box backward via BFMCS modal saturation; eliminate singleton-Omega dead end
2. **58** [NOT STARTED] -- Wire completeness to FrameConditions (3 sorries)
3. **59** [NOT STARTED] -- Prove frame-specific soundness axioms (5 sorries)
4. **60** [NOT STARTED] -- Remove discrete_Icc_finite_axiom (custom axiom)

### 2. Code Cleanup (parallel to critical path)

1. **57** [NOT STARTED] -- Clean up UltrafilterChain.lean, remove unused ultrafilter relations

### 3. Experimental

- **61** [NOT STARTED] -- Eliminate BFMCS bundles entirely (independent, explore later)
- **992** [RESEARCHED] -- STSA temporal shift automorphism (algebraic, independent)

### 4. Deferred

- **18** [BLOCKED] -- Dense representation theorem (4 sorries, defer until base is clean)
- **20** [NOT STARTED] -- Parametric canonical audit (depends on 18)
- **21** [PLANNED] -- Tech debt cleanup (depends on 18)
- **19** [NOT STARTED] -- Deprecate old discrete pipeline (low priority)
- **998** [NOT STARTED] -- FMP redesign for strict temporal (separate concern)

### 5. Backlog

- **8** [RESEARCHED] -- Genuine truth_at completeness (publication quality, 12-20h)
- **6** [RESEARCHED] -- Canonical TaskFrame completeness (may be superseded by 8)
- **39** [RESEARCHED] -- Preorder semantics study (theoretical)
- **953** [RESEARCHED] -- Bilateral proof system (55-90h)
- **949** [RESEARCHED] -- Update Demo.lean (cosmetic)
- **619** [RESEARCHED] -- Agent system architecture upgrade (meta, blocked on GitHub #16803)
```

---

## Parsing Patterns Summary

| Element | Pattern |
|---------|---------|
| Section header | `^## Task Order$` |
| Timestamp | `^\*Updated (\d{4}-\d{2}-\d{2})\. (.+)\*$` |
| Goal | `^\*\*Goal\*\*: (.+)$` |
| Category header | `^### (\d+)\. (.+?)(?:\s+--\s+(.+))?$` |
| Dependency arrow | `(\d+)\s*→\s*(\d+)` |
| Ordered task entry | `^\d+\.\s+\*\*(\d+)\*\*\s+\[([A-Z ]+)\]\s+--\s+(.+)$` |
| Unordered task entry | `^-\s+\*\*(\d+)\*\*\s+\[([A-Z ]+)\]\s+--\s+(.+)$` |
| Status marker | `\[([A-Z ]+)\]` |
| Inline dependency | `\(depends on ([\d,\s]+)\)` |
| Code block (chain) | Lines between `` ``` `` markers within a category |

---

## Generation Template

When creating a new Task Order section:

```
## Task Order

*Updated {YYYY-MM-DD}. {changelog description}*

**Goal**: {project goal statement}

### 1. {Primary Category}

{dependency chain in code block, if applicable}

{numbered or bulleted task entries}
```

---

## Related

- @.claude/context/core/formats/roadmap-format.md - ROAD_MAP.md structure
- @.claude/rules/state-management.md - Task status management
- @.claude/rules/artifact-formats.md - Status marker definitions
