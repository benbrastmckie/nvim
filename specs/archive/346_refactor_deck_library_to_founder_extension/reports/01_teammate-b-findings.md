# Teammate B Findings: Extension Loader and Write-Back Patterns

**Task**: 346 - Refactor deck library from .context/ to founder extension
**Focus**: Extension loader mechanism, context index integration, write-back, cross-repo portability
**Date**: 2026-04-01

---

## Part 1: Extension Loader Mechanism

### How Extension Context Entries Get Into index.json

The extension loader (`.claude/extensions/founder/manifest.json`) declares a `merge_targets.index` that points to `index-entries.json` as source and `.claude/context/index.json` as target:

```json
"merge_targets": {
  "index": {
    "source": "index-entries.json",
    "target": ".claude/context/index.json"
  }
}
```

The loader calls `append_index_entries()` (`merge.lua`) which merges entries from the extension's `index-entries.json` into the single `.claude/context/index.json`. After loading, all entries (core + extension) are queryable from one index.

From `context-layers.md` (confirmed by code review 2026-03-25):
> The loader calls `copy_context_dirs()` to copy extension context into `.claude/context/` and `append_index_entries()` to merge extension entries into the single `index.json`. After loading, all agent context (core + extensions) is queryable from one index.

**Critical finding**: All paths in `.claude/context/index.json` are **relative to `.claude/context/`**. When the extension loader copies files from `.claude/extensions/founder/context/` to `.claude/context/`, the paths in the merged index entries resolve correctly because the extension's `index-entries.json` already uses paths relative to `.claude/context/` (e.g., `project/founder/patterns/pitch-deck-structure.md`).

### How Deck Agents Discover Context

Both `deck-planner-agent` and `deck-builder-agent` are registered in the founder extension's `index-entries.json` under `load_when.agents` for relevant patterns files:

```json
{
  "path": "project/founder/patterns/pitch-deck-structure.md",
  "load_when": {
    "agents": ["deck-research-agent", "deck-planner-agent", "deck-builder-agent", ...]
  }
}
```

This means when agents are invoked, the context discovery pattern (`jq` queries against `.claude/context/index.json`) will return the correct paths for them.

### What Controls Loading

Three fields in `load_when` control context loading:
- `agents[]` - Match when the named agent is running
- `languages[]` - Match when the task language matches
- `commands[]` - Match when the named command is active

Empty arrays mean "never match". `"always": true` means unconditional load.

---

## Part 2: Context Index Integration

### Current State

The deck library at `.context/deck/` is registered in **two separate places**:

1. **`.context/index.json`** (project context layer) — has one entry:
   ```json
   {
     "path": "deck/index.json",
     "load_when": {
       "agents": ["deck-planner-agent", "deck-builder-agent", "deck-research-agent"],
       "languages": ["founder"],
       "commands": ["/deck"]
     }
   }
   ```
   Paths here are relative to `.context/`.

2. **`deck-planner-agent.md` and `deck-builder-agent.md`** — both load `.context/deck/index.json` directly via @-reference in their "Always Load" sections:
   ```
   @.context/deck/index.json
   ```

### How Deck Library Discovery Should Work After Migration

If the deck library moves to `.claude/extensions/founder/context/project/founder/deck/`, the index entry paths change prefix from `.context/` to `.claude/context/` (after loader copies). Three approaches exist:

**Option A: Single index entry for the whole deck/ directory**
- One entry in `index-entries.json` pointing to `project/founder/deck/index.json`
- Agents query this file to discover all library content
- Pros: Minimal index bloat, delegates discovery to the sub-index
- Cons: Agents must still know to query the sub-index separately

**Option B: Individual entries per category (all ~52 entries)**
- Add all 52 current entries from `.context/deck/index.json` to `index-entries.json`
- Load by deck agents + founder language + /deck command
- Pros: Standard discovery pattern, no special sub-index query
- Cons: Extremely large index-entries.json; most entries are content files rarely loaded directly

**Option C: One entry per category group (6 entries)**
- Six entries covering themes/, patterns/, animations/, styles/, contents/, components/
- Pros: Compact, discoverable by category
- Cons: Agents still need to read each directory to find specific files

**Recommendation**: Option A is most consistent with current design. The `.context/deck/index.json` already serves as a sub-index that agents query directly via jq. One index entry pointing to `deck/index.json` suffices — the agents already know to query it. This matches the current `.context/index.json` registration pattern exactly.

### Can the deck index.json serve as sub-index?

Yes. Both `deck-planner-agent.md` and `deck-builder-agent.md` already query `.context/deck/index.json` directly with jq:
```bash
jq -r '.entries[] | select(.category == "pattern") ...' .context/deck/index.json
```

After migration, these hardcoded paths would need to update to the new location. The sub-index pattern is valid and already implemented.

---

## Part 3: Write-Back Mechanism

### Current Write-Back Paths (deck-builder-agent.md, Stage 7)

```
Stage 7: Library Write-Back

For slides marked as NEW in the content manifest:
1. Extract the generated slide content from slides.md
2. Generalize by replacing specific values with [SLOT: ...] markers
3. Write generalized version to .context/deck/contents/{slide_type}/{variant}.md
4. Add entry to .context/deck/index.json
5. Add comment in slide: <!-- Content saved to library: contents/{path} -->
```

Write-back targets:
- `.context/deck/contents/{slide_type}/{variant}.md` — new content file
- `.context/deck/index.json` — append new entry

### Is Write-Back to .claude/extensions/ Appropriate?

**No, for two reasons:**

1. **Extension loader ownership**: `context-layers.md` states explicitly:
   > "Lifecycle: Rebuilt each time extensions are loaded"

   The extension loader **overwrites** `.claude/context/` content on each load. Any write-back to `.claude/extensions/founder/context/` would survive if writing to the extension source, but the loader would also need to be re-run to propagate changes to `.claude/context/`.

2. **Git semantics**: `.claude/extensions/founder/context/` is checked into git as part of the extension definition. Writing generated/learned content there mixes system-provided templates with user-generated content in the same git-tracked directory. This makes the extension non-portable: the fork accumulates user data that can't be cleanly separated for publishing.

### Analysis of Alternatives

**Alternative A: Write-back to .context/deck/ as local cache (current behavior)**
- Pros: Clean separation — extension defines how, `.context/deck/` stores what
- Pros: User-owned, not overwritten by extension loader
- Pros: Cross-repo portable extension (extension stays clean)
- Cons: Requires `.context/deck/` to exist in every repo where deck is used
- **This is the design intent per task 345's research report** (specs/345_port_deck_typst_to_slidev/reports/03_slidev-system-design.md, line 107)

**Alternative B: Write-back to extension path directly**
- Pros: Single source of truth for library
- Cons: Mixes user-generated with system-provided; breaks portability; needs loader re-run
- **Not recommended**

**Alternative C: Write-back to a .memory/ file or agent state**
- Pros: Agent-managed persistence layer
- Cons: Not queryable by jq; doesn't integrate with the structured library pattern

**Conclusion**: Write-back should stay at `.context/deck/` (project context layer), regardless of where the initial library lives. This is the correct owner per the three-layer architecture.

---

## Part 4: Cross-Repository Portability

### What Happens When Founder Extension Loads in a Different Repo

The extension loader:
1. Copies `.claude/extensions/founder/context/` → `.claude/context/` (repo-local)
2. Merges `index-entries.json` → `.claude/context/index.json` (repo-local)

**Extension files resolve correctly in any repo** because they land in `.claude/context/` relative to the repo root after the loader runs. No absolute paths are used in the extension context files.

### The Critical Problem With Moving Library to Extension

If the deck library (themes, patterns, animations, styles, contents, components) moves into `.claude/extensions/founder/context/project/founder/deck/`:

1. **Write-back breaks**: `deck-builder-agent` writes to `.context/deck/contents/` and `.context/deck/index.json`. If the library is in `.claude/context/project/founder/deck/`, write-back would need to target `.claude/context/` — which the loader may overwrite on next extension reload.

2. **Hardcoded paths in agents**: Both agents hardcode `.context/deck/` in many places:
   - `@.context/deck/index.json` (context reference)
   - `.context/deck/themes/{theme_id}.json` (bash path)
   - `.context/deck/contents/{path}` (bash path)
   - `.context/deck/components/$component` (bash path)

   All of these would need updating to the new path.

3. **The `.context/deck/index.json` sub-index path**: Both agents reference this directly via `@`-ref and bash jq queries. The path is hardcoded in `deck-planner-agent.md` (line 124), `deck-builder-agent.md` (line 40), and their error handling (line 356, 361).

4. **New-repo initialization**: In a new repo without `.context/deck/`, the agents get their initial library from the extension (`.claude/context/project/founder/deck/`). But write-back still needs a mutable location. The correct pattern: extension ships the initial library, loader copies it to `.claude/context/`, agents use `.claude/context/deck/` for both read and write-back.

### Hardcoded Absolute Path Risk

No hardcoded absolute paths were found. All paths use relative forms (`.context/deck/...`, `specs/...`, `strategy/...`). This is correct.

### How Agents Should Locate the deck index.json After Migration

Option 1: Keep library in `.context/deck/` — no change needed for agent paths.

Option 2: Move to extension, have loader copy to `.claude/context/deck/` — agents update all path references from `.context/deck/` to `.claude/context/deck/`.

Option 3: Move to extension for initial ship, write-back to `.context/deck/` — agents use two different paths for read (`.claude/context/deck/`) and write-back (`.context/deck/`). This is complex and error-prone.

**Option 1 (no change to agent paths) or Option 2 (consistent path under .claude/context/) are viable. Option 3 should be avoided.**

---

## Part 5: References Outside .context/deck/

### References in .claude/ agents and skills

All in `.claude/extensions/founder/`:
- `agents/deck-builder-agent.md` — 20+ references to `.context/deck/`
- `agents/deck-planner-agent.md` — 10+ references to `.context/deck/`
- `skills/skill-deck-implement/SKILL.md` — 1 reference (line 167)
- `context/project/founder/patterns/slidev-deck-template.md` — 6 references
- `context/project/founder/patterns/pitch-deck-structure.md` — 1 reference

### References in specs/

- `specs/state.json` — 3 references (completion summaries for task 345, now historical)
- `specs/TODO.md` — 1 reference (completion entry for task 345)
- `specs/345_port_deck_typst_to_slidev/plans/03_slidev-system-plan.md` — 50+ references (historical plan artifact)
- `specs/345_port_deck_typst_to_slidev/reports/03_slidev-system-design.md` — 60+ references (historical report)
- `specs/345_port_deck_typst_to_slidev/summaries/02_slidev-system-summary.md` — 12 references (historical summary)

### References in .claude/docs/

No references found.

### References in CLAUDE.md files

No references found.

### References in .context/index.json

One entry registering `deck/index.json` as a project context entry (path relative to `.context/`).

---

## Summary of Key Findings

### What Works Well (Keep)

1. **Sub-index pattern**: `.context/deck/index.json` as queryable library index is well-designed and already in use. Agents query it with jq to discover themes, patterns, content.

2. **Three-layer separation**: Extension defines behaviors; `.context/deck/` stores library data. This is architecturally correct per `context-layers.md`.

3. **Write-back to .context/deck/**: Correct owner for mutable, user-accumulated content. Extension loader never touches `.context/`.

4. **No hardcoded absolute paths**: All paths are relative to repo root.

### What Needs to Change for Migration

If the goal is to ship the **initial library** with the extension so new repos get it automatically:

1. Add deck library files to `.claude/extensions/founder/context/project/founder/deck/`
2. Add a single index entry to `index-entries.json` for `project/founder/deck/index.json`
3. Update all agent `@`-references and bash paths from `.context/deck/` to `.claude/context/project/founder/deck/`
4. Keep write-back pointing to `.context/deck/` (project context layer) — OR accept that write-back goes to `.claude/context/project/founder/deck/` and gets overwritten on extension reload (bad)
5. The loader copies the extension's deck/ to `.claude/context/project/founder/deck/` on each load

**Key tension**: The loader overwrites `.claude/context/` on reload. This means write-back to the extension-managed path is not durable. Write-back must remain in `.context/deck/` for persistence, creating a split read/write path.

### Recommended Architecture

The cleanest solution (minimum path proliferation, correct ownership):

- **Extension ships**: Initial library files in `.claude/extensions/founder/context/project/founder/deck/`
- **Loader copies to**: `.claude/context/project/founder/deck/` on each load (initial seed)
- **Agents read from**: `.claude/context/project/founder/deck/` (after first load)
- **Write-back goes to**: `.context/deck/` (project context layer — mutable, not overwritten)
- **Agent path logic**: Try `.context/deck/` first (user-accumulated), fall back to `.claude/context/project/founder/deck/` (extension-provided seed)

This requires updating agent path references but preserves correct ownership boundaries. However, this two-path fallback adds complexity. The **simplest** approach may be to leave `.context/deck/` where it is and simply document that the deck library must be initialized manually in new repos (or via a `/deck init` command).
