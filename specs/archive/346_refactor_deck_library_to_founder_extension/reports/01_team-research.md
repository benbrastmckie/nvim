# Research Report: Task #346

**Task**: Refactor deck library from .context/ to founder extension
**Date**: 2026-04-01
**Mode**: Team Research (2 teammates)

## Summary

The deck library at `.context/deck/` (54 files, 52 indexed entries) is entirely general-purpose and should ship with the founder extension. However, the extension loader's overwrite-on-reload behavior creates a critical tension with the deck-builder-agent's library write-back mechanism. The recommended architecture uses a **seed-and-overlay** pattern: the extension ships the initial library, and `.context/deck/` serves as the mutable overlay for runtime write-back.

## Key Findings

### 1. File Inventory (Teammate A)

54 files across 7 categories:

| Category | Files | Description |
|----------|-------|-------------|
| themes/ | 5 | JSON configs with Slidev headmatter + themeConfig |
| patterns/ | 5 | Structural definitions (YC 10-slide, lightning, etc.) |
| animations/ | 6 | Markdown animation pattern definitions |
| styles/ | 9 | CSS presets (colors, typography, textures) |
| contents/ | 23 | Reusable slide templates with [SLOT:] placeholders |
| components/ | 4 | Vue SFC components (MetricCard, TeamMember, etc.) |
| index.json | 1 | Master sub-index (477 lines, 52 entries) |

All files are general founder deck resources. None contain repo-specific data.

### 2. Path Reference Audit (Teammate A)

All `.context/deck` references are confined to 6 files in `.claude/extensions/founder/` plus `.context/index.json`:

| File | Refs | Type |
|------|------|------|
| `agents/deck-builder-agent.md` | ~14 | Read paths + 2 write-back operations |
| `agents/deck-planner-agent.md` | ~10 | jq queries, @-refs, error guards |
| `context/project/founder/patterns/slidev-deck-template.md` | ~7 | Documentation references |
| `context/project/founder/patterns/pitch-deck-structure.md` | 1 | Documentation reference |
| `index-entries.json` | 1 | Summary text |
| `skills/skill-deck-implement/SKILL.md` | 1 | Documentation reference |
| `.context/index.json` | 1 | Registration entry |

**No references** in deck-research-agent.md, deck.md command, CLAUDE.md files, or .claude/docs/.

Historical references exist in specs/345_* artifacts (read-only, no changes needed).

### 3. Extension Loader Mechanism (Teammate B)

The founder extension's loader:
1. Copies `.claude/extensions/founder/context/` → `.claude/context/` on each load
2. Merges `index-entries.json` → `.claude/context/index.json`
3. **Overwrites** `.claude/context/` content on each reload

**Critical implication**: Any content written to `.claude/context/project/founder/deck/` by the write-back mechanism would be overwritten on the next extension reload.

### 4. Write-Back Tension (Teammate B)

The deck-builder-agent's Stage 7 writes new content back to the library:
- New slide content → `.context/deck/contents/{slide_type}/{variant}.md`
- New index entry → `.context/deck/index.json`

This write-back **must target a mutable, non-overwritten location**. The `.context/` layer is architecturally correct for this: it's user-owned, not touched by the extension loader, and persists across reloads.

### 5. Cross-Repository Portability (Teammate B)

- No hardcoded absolute paths exist
- Extension files resolve correctly in any repo after loader runs
- New repos lack `.context/deck/`, which is the portability gap this refactor addresses
- The sub-index pattern (agents query deck/index.json via jq) is well-designed and reusable

## Synthesis

### Conflict Resolved: Read vs Write Paths

Teammate A recommended moving everything to `.claude/extensions/founder/context/project/founder/deck/` with all path references updated. Teammate B identified that write-back to extension-managed paths is non-durable due to loader overwrite behavior.

**Resolution**: Use a **seed-and-overlay** architecture:

1. **Extension ships seed library** at `.claude/extensions/founder/context/project/founder/deck/`
2. **Loader copies seed** to `.claude/context/project/founder/deck/` on each load
3. **Agents read from a single resolved path** (see Path Resolution below)
4. **Write-back targets `.context/deck/`** (mutable project layer, never overwritten)

### Recommended Architecture: Seed-and-Overlay

```
Extension (seed, immutable, git-tracked):
  .claude/extensions/founder/context/project/founder/deck/
    ├── index.json, themes/, patterns/, animations/, styles/, contents/, components/

After loader runs (working copy, overwritten on reload):
  .claude/context/project/founder/deck/
    ├── (copy of extension seed)

Project overlay (mutable, persists, write-back target):
  .context/deck/
    ├── (user-accumulated content written back by deck-builder-agent)
```

### Path Resolution Strategy for Agents

Agents need a **single resolution function** that checks both locations. Two viable approaches:

**Approach A: Overlay-first resolution (recommended)**
```bash
# Check .context/deck/ first (user overlay), fall back to extension seed
DECK_LIB=".context/deck"
if [ ! -f "$DECK_LIB/index.json" ]; then
  DECK_LIB=".claude/context/project/founder/deck"
fi
```
- Pros: Simple, user content takes precedence, works in new repos (falls back to seed)
- Cons: Adds ~3 lines of path resolution to each agent

**Approach B: Initialize-on-first-use**
```bash
# If .context/deck/ doesn't exist, copy from extension seed
if [ ! -d ".context/deck" ]; then
  cp -r ".claude/context/project/founder/deck" ".context/deck"
fi
DECK_LIB=".context/deck"
```
- Pros: Single path after initialization, write-back always works
- Cons: Creates .context/deck/ in every repo on first /deck use; may confuse users

**Approach C: Merged index at runtime**
- Agent reads both index files and merges entries
- Most complex, handles partial overlays
- Overkill for current needs

**Recommendation**: **Approach B (initialize-on-first-use)** is cleanest. Agents always use `.context/deck/` as the single path. On first `/deck` invocation in a new repo, the deck-planner-agent copies the seed library from the extension to `.context/deck/`. This means:
- All existing path references in agents stay as `.context/deck/` (minimal churn)
- Write-back works immediately
- New repos get the library automatically
- The extension seed is the canonical "factory reset" source

### Index Registration

- **Remove** the current `.context/index.json` entry for `deck/index.json` (project layer)
- **Add** one entry to `index-entries.json` for `project/founder/deck/index.json` (extension layer)
- Agents continue to query `.context/deck/index.json` directly (after initialization copies it there)

### Files Requiring Changes

| File | Change |
|------|--------|
| `.claude/extensions/founder/context/project/founder/deck/` | **NEW**: Copy entire .context/deck/ here as seed |
| `.claude/extensions/founder/index-entries.json` | Add 1 entry for deck/index.json |
| `.claude/extensions/founder/agents/deck-planner-agent.md` | Add initialization guard (~5 lines) |
| `.claude/extensions/founder/agents/deck-builder-agent.md` | Add initialization guard (~5 lines) |
| `.context/index.json` | Remove deck/index.json entry |
| `.context/deck/` | Keep as mutable overlay (no delete) |

**If using Approach B**: Only 2 agent files need modification (add init guard). All `.context/deck/` path references remain unchanged. Documentation files need no updates.

**If using Approach A**: All 6 files with `.context/deck/` references need path updates to use a `$DECK_LIB` variable pattern. More invasive but no `.context/deck/` creation side effect.

### Consolidation Note

`slidev-deck-template.md` and `pitch-deck-structure.md` should remain in `patterns/` (they are reference documentation, not library content). Only their `.context/deck/` references need updating if Approach A is chosen.

## Gaps Identified

1. **No `/deck init` command exists** -- if Approach B is chosen, initialization happens inside the agent, not via a standalone command. A future `/deck init` could be added for explicit library setup.
2. **Merged index behavior** -- if a user's `.context/deck/index.json` diverges significantly from the seed, there's no merge strategy. The user's version simply takes precedence (Approach B) or the seed is used when overlay doesn't exist (Approach A).
3. **Library version tracking** -- no mechanism to detect when the extension's seed library has been updated and the user's `.context/deck/` is stale. A `version` field in index.json could address this.

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | File inventory + path audit | completed | high |
| B | Extension loader + write-back | completed | high |

## References

- `.claude/extensions/founder/manifest.json` -- extension registration
- `.claude/context/architecture/context-layers.md` -- three-layer architecture
- `specs/345_port_deck_typst_to_slidev/reports/03_slidev-system-design.md` -- original system design
- `.claude/extensions/founder/agents/deck-builder-agent.md` lines 305-306 -- write-back mechanism
