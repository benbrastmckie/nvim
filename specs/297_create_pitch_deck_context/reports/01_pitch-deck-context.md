# Research Report: Task #297

**Task**: Create missing pitch-deck context files
**Date**: 2026-03-26
**Focus**: Missing context files referenced in Website .claude/context/index.json

## Summary

Two context files in the Website project's `filetypes` subdomain are referenced in `index.json` but do not exist on disk. Identical files already exist in the `present` subdomain. The `filetypes` entries appear to be duplicates created when the filetypes extension was added, referencing files that were never copied from the `present` subdomain.

## Findings

### Missing Files

1. **`project/filetypes/patterns/pitch-deck-structure.md`**
   - Full path: `/home/benjamin/Projects/Logos/Website/.claude/context/project/filetypes/patterns/pitch-deck-structure.md`
   - Status: Referenced in index.json but does not exist on disk

2. **`project/filetypes/patterns/touying-pitch-deck-template.md`**
   - Full path: `/home/benjamin/Projects/Logos/Website/.claude/context/project/filetypes/patterns/touying-pitch-deck-template.md`
   - Note: The index.json entry uses "touying" (correct Typst package name), matching the existing present subdomain file

### Index.json Entries (filetypes subdomain -- missing files)

```json
{
  "path": "project/filetypes/patterns/pitch-deck-structure.md",
  "keywords": [],
  "subdomain": "filetypes",
  "domain": "project",
  "summary": "YC pitch deck structure, slide content guidelines, and design principles",
  "topics": [],
  "line_count": 253,
  "load_when": {
    "agents": ["deck-agent"],
    "languages": []
  }
}
```

```json
{
  "path": "project/filetypes/patterns/touying-pitch-deck-template.md",
  "keywords": [],
  "subdomain": "filetypes",
  "domain": "project",
  "summary": "Touying 0.6.3 template for investor pitch decks with customization patterns",
  "topics": [],
  "line_count": 396,
  "load_when": {
    "agents": ["deck-agent"],
    "languages": []
  }
}
```

### Index.json Entries (present subdomain -- existing files)

```json
{
  "path": "project/present/patterns/pitch-deck-structure.md",
  "keywords": ["pitch-deck", "yc", "investor", "slides", "structure", "10-slide"],
  "subdomain": "present",
  "domain": "project",
  "summary": "YC-recommended 10-slide pitch deck structure with design principles",
  "topics": ["deck", "pitch", "yc", "slides", "investor"],
  "line_count": 180,
  "load_when": {
    "agents": ["deck-agent"],
    "languages": ["deck"],
    "commands": ["/deck"]
  }
}
```

```json
{
  "path": "project/present/patterns/touying-pitch-deck-template.md",
  "keywords": ["touying", "typst", "template", "pitch-deck", "slides", "themes"],
  "subdomain": "present",
  "domain": "project",
  "summary": "Touying pitch deck template patterns and code examples for Typst",
  "topics": ["deck", "touying", "typst", "template", "presentation"],
  "line_count": 250,
  "load_when": {
    "agents": ["deck-agent"],
    "languages": ["deck"],
    "commands": ["/deck"]
  }
}
```

### Key Differences Between Entries

| Attribute | filetypes (missing) | present (existing) |
|-----------|--------------------|--------------------|
| keywords | Empty `[]` | Populated with relevant terms |
| topics | Empty `[]` | Populated with relevant terms |
| languages | Empty `[]` | `["deck"]` |
| commands | Not present | `["/deck"]` |
| line_count (structure) | 253 | 180 |
| line_count (template) | 396 | 250 |

The filetypes entries have empty keywords/topics and different line counts from the present entries, suggesting they may have been intended as extended versions but were never written. Alternatively, the line counts in the filetypes entries may simply be stale/incorrect estimates.

### Existing Neighbor Files in filetypes/patterns/

The directory `/home/benjamin/Projects/Logos/Website/.claude/context/project/filetypes/patterns/` contains:
- `presentation-slides.md` (367 lines) -- PPTX extraction and slide generation patterns for Beamer, Polylux, and Touying
- `spreadsheet-tables.md` (265 lines) -- Spreadsheet to table conversion patterns for LaTeX and Typst

These neighbor files focus on **conversion patterns and tool usage** (python-pptx, pandas, pandoc) rather than content structure or templates. This is a distinct concern from the pitch deck files, which focus on **content guidelines and Typst templates**.

### Existing Present Subdomain Files

The `present` subdomain files are comprehensive:
- `pitch-deck-structure.md` (409 lines) -- Complete YC pitch deck structure with 9+1 slides, design principles, content density rules, typography enforcement, anti-patterns, and validation checklists
- `touying-pitch-deck-template.md` (423 lines) -- Full Touying 0.6.3 template with customization patterns, prohibited patterns, and design checklist

## Recommendations

There are two viable approaches:

### Option A: Remove duplicate index entries (Recommended)

Remove the two `filetypes` subdomain entries from `index.json` entirely. Rationale:
- The `present` subdomain already has these files with richer metadata (keywords, topics, languages, commands)
- The `filetypes` subdomain focuses on file conversion patterns (PPTX extraction, spreadsheet conversion), not content structure
- Pitch deck content belongs in the `present` subdomain, which is purpose-built for presentation concerns
- Duplication creates maintenance burden and confusion

### Option B: Create symlinks or copies

Copy or symlink the `present` versions into `filetypes/patterns/`. This would:
- Satisfy the index.json references
- But create content duplication across subdomains
- Require keeping both copies in sync

**Recommendation**: Option A is strongly preferred. The filetypes entries appear to be accidental duplicates from an automated index generation process. Removing them from index.json is cleaner than creating duplicate files.

## Context Extension Recommendations

None -- this is a meta task addressing context system consistency.

## Next Steps

1. Decide between Option A (remove entries) and Option B (create files)
2. If Option A: Edit `/home/benjamin/Projects/Logos/Website/.claude/context/index.json` to remove the two `filetypes` subdomain pitch-deck entries
3. If Option B: Copy files from `present/patterns/` to `filetypes/patterns/` and update line counts in index.json
4. Verify no other index.json entries reference missing files

## References

- `/home/benjamin/Projects/Logos/Website/.claude/context/index.json` -- Context index with both sets of entries
- `/home/benjamin/Projects/Logos/Website/.claude/context/project/present/patterns/pitch-deck-structure.md` -- Existing structure file (409 lines)
- `/home/benjamin/Projects/Logos/Website/.claude/context/project/present/patterns/touying-pitch-deck-template.md` -- Existing template file (423 lines)
- `/home/benjamin/Projects/Logos/Website/.claude/context/project/filetypes/patterns/` -- Directory with 2 existing pattern files (presentation-slides.md, spreadsheet-tables.md)
