# Teammate A Findings: File Inventory and Path References

**Task**: Research for task 346 — Refactor deck library from `.context/deck/` to founder extension
**Date**: 2026-04-01
**Scope**: READ-ONLY research

---

## Part 1: Complete File Inventory

### Directory Structure

`.context/deck/` contains 7 top-level entries (6 subdirectories + 1 index file) and 22 subdirectory entries for a total of **54 files** across **22 directories**.

```
.context/deck/
├── index.json                  (477 lines, 21300 bytes)
├── animations/                 (6 files)
├── components/                 (4 files)
├── contents/                   (23 files across 11 subdirs)
│   ├── appendix/               (3 files)
│   ├── ask/                    (2 files)
│   ├── business-model/         (2 files)
│   ├── closing/                (2 files)
│   ├── cover/                  (2 files)
│   ├── market/                 (2 files)
│   ├── problem/                (2 files)
│   ├── solution/               (2 files)
│   ├── team/                   (2 files)
│   ├── traction/               (2 files)
│   └── why-us-now/             (2 files)
├── patterns/                   (5 files)
├── styles/                     (9 files across 3 subdirs)
│   ├── colors/                 (4 files)
│   ├── textures/               (2 files)
│   └── typography/             (3 files)
└── themes/                     (5 files)
```

### File Inventory by Subdirectory

#### animations/ (6 files)
| File | Lines |
|------|-------|
| `animations/fade-in.md` | 43 |
| `animations/metric-cascade.md` | 57 |
| `animations/rough-marks.md` | 48 |
| `animations/scale-in-pop.md` | 54 |
| `animations/slide-in-below.md` | 48 |
| `animations/staggered-list.md` | 65 |

#### components/ (4 files)
| File | Lines |
|------|-------|
| `components/ComparisonCol.vue` | 37 |
| `components/MetricCard.vue` | 28 |
| `components/TeamMember.vue` | 40 |
| `components/TimelineItem.vue` | 38 |

#### contents/ (23 files)
| File | Lines |
|------|-------|
| `contents/appendix/appendix-competition.md` | 30 |
| `contents/appendix/appendix-financials.md` | 30 |
| `contents/appendix/appendix-roadmap.md` | 27 |
| `contents/ask/ask-centered.md` | 38 |
| `contents/ask/ask-milestone.md` | 39 |
| `contents/business-model/biz-model-pricing.md` | 30 |
| `contents/business-model/biz-model-saas.md` | 55 |
| `contents/closing/closing-cta.md` | 38 |
| `contents/closing/closing-standard.md` | 19 |
| `contents/cover/cover-hero.md` | 34 |
| `contents/cover/cover-standard.md` | 29 |
| `contents/market/market-narrative.md` | 26 |
| `contents/market/market-tam-sam-som.md` | 43 |
| `contents/problem/problem-statement.md` | 25 |
| `contents/problem/problem-story.md` | 25 |
| `contents/solution/solution-demo.md` | 26 |
| `contents/solution/solution-two-col.md` | 35 |
| `contents/team/team-grid.md` | 41 |
| `contents/team/team-two-col.md` | 37 |
| `contents/traction/traction-chart.md` | 34 |
| `contents/traction/traction-metrics.md` | 36 |
| `contents/why-us-now/why-us-moat.md` | 29 |
| `contents/why-us-now/why-us-now-split.md` | 37 |

#### patterns/ (5 files)
| File | Lines |
|------|-------|
| `patterns/investor-update.json` | 30 |
| `patterns/lightning-5-slide.json` | 27 |
| `patterns/partnership-proposal.json` | 30 |
| `patterns/product-demo.json` | 32 |
| `patterns/yc-10-slide.json` | 33 |

#### styles/ (9 files)
| File | Lines |
|------|-------|
| `styles/colors/dark-blue-navy.css` | 13 |
| `styles/colors/dark-gold-premium.css` | 13 |
| `styles/colors/light-blue-corp.css` | 13 |
| `styles/colors/light-green-growth.css` | 13 |
| `styles/textures/grid-overlay.css` | 16 |
| `styles/textures/noise-grain.css` | 20 |
| `styles/typography/inter-only.css` | 25 |
| `styles/typography/montserrat-inter.css` | 24 |
| `styles/typography/playfair-inter.css` | 24 |

#### themes/ (5 files)
| File | Lines |
|------|-------|
| `themes/dark-blue.json` | 32 |
| `themes/growth-green.json` | 32 |
| `themes/minimal-light.json` | 32 |
| `themes/premium-dark.json` | 32 |
| `themes/professional-blue.json` | 32 |

### index.json Summary

- **Version**: 1.0
- **Total entries**: 52
- **Entry breakdown by category**:
  - `animation`: 6
  - `component`: 4
  - `content`: 23
  - `pattern`: 5
  - `style`: 9
  - `theme`: 5

---

## Part 2: Path Reference Audit

### Files Containing `.context/deck` References

All references to `.context/deck` are confined to the `.claude/extensions/founder/` directory plus `.context/index.json`. No references exist outside these locations (excluding historical `specs/` plan/report files which are read-only artifacts).

#### 1. `.claude/extensions/founder/agents/deck-builder-agent.md`
**Reference count**: ~14 references

| Line | Reference | Purpose |
|------|-----------|---------|
| 10 | `.context/deck/themes/` | Description — library location |
| 10 | `.context/deck/contents/` | Description — slide assembly source |
| 40 | `@.context/deck/index.json` | Context load — library index for querying |
| 170 | `.context/deck/themes/{theme_id}.json` | Read — load selected theme config |
| 174 | `theme_path=".context/deck/themes/${theme_id}.json"` | Bash script — theme path variable |
| 179 | `theme_path=".context/deck/themes/dark-blue.json"` | Bash script — fallback theme path |
| 214 | `.context/deck/contents/{path}` | Read — load content files for slot filling |
| 217 | `.context/deck/contents/{path}` | Comment annotation — import tracking |
| 225 | `.context/deck/animations/` | Read — animation pattern reference |
| 269 | `.context/deck/components/` | Read — Vue component source |
| 276 | `.context/deck/components/$component` | Bash script — component copy source path |
| 277 | `.context/deck/components/$component` | Bash script — component copy path |
| 305 | `.context/deck/contents/{slide_type}/{variant}.md` | **Write-back** — save new content to library |
| 306 | `.context/deck/index.json` | **Write-back** — add new entry to index |
| 482 | `.context/deck/themes/` | Error message — themes not found |
| 491 | `.context/deck/contents/{path}` | Warning message — content not found |
| 522 | `.context/deck/themes/{theme_id}.json` | Summary — load theme config |
| 523 | `.context/deck/contents/` | Summary — assemble slides from library |

**Write-back operations (critical for refactor)**: Lines 305–306 — the builder writes new generalized slide content back to `.context/deck/contents/` and updates `index.json`.

#### 2. `.claude/extensions/founder/agents/deck-planner-agent.md`
**Reference count**: ~10 references

| Line | Reference | Purpose |
|------|-----------|---------|
| 11 | `.context/deck/` | Description — library location |
| 44 | `@.context/deck/index.json` | Context load — library index for querying |
| 124 | `.context/deck/index.json` | jq query — list patterns |
| 147 | `.context/deck/index.json` | jq query — list themes |
| 223 | `.context/deck/contents/` | Plan output — import map references |
| 230 | `.context/deck/contents/` | Plan output — new content phase reference |
| 356 | `.context/deck/index.json` | Error check — library not found guard |
| 361 | `.context/deck/index.json` | Error message — missing library |
| 372 | `.context/deck/index.json` | Summary — query patterns/themes/content |

#### 3. `.claude/extensions/founder/context/project/founder/patterns/slidev-deck-template.md`
**Reference count**: ~7 references

| Line | Reference | Purpose |
|------|-----------|---------|
| 281 | `.context/deck/components/` | Documentation — component copy pattern |
| 293 | `.context/deck/contents/` | Documentation — slot filling explanation |
| 296 | `.context/deck/contents/{slide_type}/{variant}.md` | Documentation — content path pattern |
| 304 | `../../.context/deck/contents/closing/closing-standard.md` | Documentation — example src import |
| 315 | `.context/deck/contents/traction/traction-metrics.md` | Documentation — example import comment |
| 381 | `.context/deck/index.json` | Documentation — see also reference |
| 382 | `.context/deck/themes/` | Documentation — see also reference |

#### 4. `.claude/extensions/founder/context/project/founder/patterns/pitch-deck-structure.md`
**Reference count**: 1 reference

| Line | Reference | Purpose |
|------|-----------|---------|
| 408 | `.context/deck/` | Documentation — see also reference |

#### 5. `.claude/extensions/founder/index-entries.json`
**Reference count**: 1 reference

| Line | Reference | Purpose |
|------|-----------|---------|
| 603 | `.context/deck/` (in summary text) | Index entry summary for `slidev-deck-template.md` |

#### 6. `.claude/extensions/founder/skills/skill-deck-implement/SKILL.md`
**Reference count**: 1 reference

| Line | Reference | Purpose |
|------|-----------|---------|
| 167 | `.context/deck/themes/` | Documentation — skill step reference |

#### 7. `.context/index.json`
**Reference count**: 1 entry (the deck library registration)

The `.context/index.json` contains exactly one deck-related entry:
```json
{
  "path": "deck/index.json",
  "summary": "Slidev deck library index with themes, patterns, animations, styles, content snippets, and Vue components for agent-driven deck construction",
  "line_count": 50,
  "load_when": {
    "agents": ["deck-planner-agent", "deck-builder-agent", "deck-research-agent"],
    "languages": ["founder"],
    "commands": ["/deck"]
  }
}
```
Note: The `path` is relative to `.context/` so `deck/index.json` resolves to `.context/deck/index.json`.

#### No References Found In:
- `.claude/extensions/founder/agents/deck-research-agent.md` — no `.context/deck` references
- `.claude/extensions/founder/commands/deck.md` — no `.context/deck` references
- `.claude/extensions/founder/skills/skill-deck-plan/SKILL.md` — no `.context/deck` references
- `.claude/extensions/founder/skills/skill-deck-research/SKILL.md` — no `.context/deck` references
- `.claude/context/index.json` — no `.context/deck` references

---

## Part 3: Destination Path Analysis

### Existing Founder Extension Context Structure

```
.claude/extensions/founder/context/project/founder/
├── README.md                          (3733 bytes, general overview)
├── domain/                            (8 files — frameworks, financial analysis, etc.)
│   ├── business-frameworks.md
│   ├── financial-analysis.md
│   ├── legal-frameworks.md
│   ├── migration-guide.md
│   ├── spreadsheet-frameworks.md
│   ├── strategic-thinking.md
│   ├── timeline-frameworks.md
│   └── workflow-reference.md
├── patterns/                          (10 files — decision patterns, deck structure, etc.)
│   ├── contract-review.md
│   ├── cost-forcing-questions.md
│   ├── decision-making.md
│   ├── financial-forcing-questions.md
│   ├── forcing-questions.md
│   ├── legal-planning.md
│   ├── mode-selection.md
│   ├── pitch-deck-structure.md        ← DECK RELATED
│   ├── project-planning.md
│   ├── slidev-deck-template.md        ← DECK RELATED
│   └── yc-compliance-checklist.md     ← DECK RELATED
└── templates/                         (5 files + 1 subdir)
    ├── competitive-analysis.md
    ├── contract-analysis.md
    ├── financial-analysis.md
    ├── gtm-strategy.md
    ├── market-sizing.md
    └── typst/                         (7 Typst template files)
```

### Recommended Destination Path

The best destination for the deck library is:

```
.claude/extensions/founder/context/project/founder/deck/
```

This path:
1. Mirrors the current `.context/deck/` structure exactly (same subdirectory layout)
2. Sits within the founder extension's context layer where all deck-related agent and context files already live
3. Is consistent with the `.claude/extensions/founder/context/project/founder/` naming convention
4. Makes the library extension-owned, not user-project-owned (`.context/` is for user project data)

### Consolidation Consideration for slidev-deck-template.md and pitch-deck-structure.md

These two files in `patterns/` are reference documentation (not library content), and are already correctly placed. They should **remain in `patterns/`** and only have their path references updated (`.context/deck/` → `.claude/extensions/founder/context/project/founder/deck/` or a shorter relative equivalent).

The key distinction:
- `patterns/slidev-deck-template.md` — HOW to use the library (documentation)
- `patterns/pitch-deck-structure.md` — WHAT goes in a deck (structural guide)
- `deck/` directory — THE actual reusable library files (themes, patterns, content, etc.)

These should not be merged together.

### Path Length Consideration

The full destination path `.claude/extensions/founder/context/project/founder/deck/` is long. In agent instructions, a shorter reference form may be preferable. One option is to define a symbolic notation or alias. Alternatively, the path could be shortened to:

```
.claude/extensions/founder/context/deck/
```

This would parallel how the founder extension already has `context/project/founder/` for project-specific files. The `deck/` library is arguably not "project-specific content" but rather "extension-owned reusable assets," making a shallower path defensible.

**Recommendation**: Use `.claude/extensions/founder/context/project/founder/deck/` to maintain consistency with the existing `context/project/founder/` structure where all other founder context lives. All agent references would update from `.context/deck/` to `.claude/extensions/founder/context/project/founder/deck/` (or a relative path like `../../extensions/founder/context/project/founder/deck/` depending on CWD assumptions).

---

## Summary of Changes Required

When implementing this refactor, the following files must be updated:

| File | Change Type | Details |
|------|-------------|---------|
| `.claude/extensions/founder/agents/deck-builder-agent.md` | Path update | ~14 references to `.context/deck/` → new path |
| `.claude/extensions/founder/agents/deck-planner-agent.md` | Path update | ~10 references to `.context/deck/` → new path |
| `.claude/extensions/founder/context/project/founder/patterns/slidev-deck-template.md` | Path update | ~7 documentation references |
| `.claude/extensions/founder/context/project/founder/patterns/pitch-deck-structure.md` | Path update | 1 documentation reference |
| `.claude/extensions/founder/index-entries.json` | Path update | 1 summary string reference |
| `.claude/extensions/founder/skills/skill-deck-implement/SKILL.md` | Path update | 1 documentation reference |
| `.context/index.json` | Entry removal OR update | Either remove `deck/index.json` entry entirely (if library moves to extension) or update path |
| `.context/deck/` | File move | 54 files moved to new destination |

**Critical write-back paths** (deck-builder-agent writes new content back to library):
- `deck-builder-agent.md` lines 305–306: write-back to `contents/` and `index.json` must use the new path
