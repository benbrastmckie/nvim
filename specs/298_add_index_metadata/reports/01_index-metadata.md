# Research: Missing domain/subdomain Metadata in index.json

**Task**: 298
**Date**: 2026-03-26
**Target**: `/home/benjamin/Projects/Logos/Website/.claude/context/index.json`

## Summary

The Website project's `.claude/context/index.json` contains 256 entries. Of these, 134 entries (52%) are missing `domain` and `subdomain` fields. All 134 missing entries are under the `project/` path prefix and appear to have been added by extensions without complete metadata.

## Quantitative Analysis

| Metric | Count |
|--------|-------|
| Total entries | 256 |
| Entries with domain/subdomain | 122 |
| Entries missing domain/subdomain | 134 |
| Missing both domain AND subdomain | 134 |
| Missing domain only | 0 |
| Missing subdomain only | 0 |

### Additional Field Population (among 134 missing entries)

| Field | Populated | Missing |
|-------|-----------|---------|
| `domain` | 0 | 134 |
| `subdomain` | 0 | 134 |
| `summary` | 67 | 67 |
| `keywords` | 0 | 134 |
| `topics` | 0 | 134 |
| `line_count` | 85 | 49 |
| `load_when` | 134 | 0 |

The missing entries fall into two tiers:
- **67 entries**: Have `summary` but lack domain/subdomain/keywords/topics
- **67 entries**: Completely bare -- only `path`, `load_when`, and sometimes `line_count`

## Breakdown by Path Prefix

All 134 missing entries reside under `project/`:

| Level-2 Prefix | Count | Recommended Domain | Recommended Subdomain |
|----------------|-------|--------------------|-----------------------|
| `project/typst` | 26 | `project` | `typst` |
| `project/logic` | 22 | `project` | `logic` |
| `project/founder` | 22 | `project` | `founder` |
| `project/math` | 21 | `project` | `math` |
| `project/nix` | 11 | `project` | `nix` |
| `project/latex` | 10 | `project` | `latex` |
| `project/python` | 6 | `project` | `python` |
| `project/memory` | 5 | `project` | `memory` |
| `project/z3` | 5 | `project` | `z3` |
| `project/physics` | 2 | `project` | `physics` |
| `project/lean4` | 2 | `project` | `lean4` |
| `project/filetypes` | 1 | `project` | `filetypes` |
| `project/web` | 1 | `project` | `web` |
| **Total** | **134** | | |

### Level-3 Path Detail (for largest groups)

| Path Pattern | Count |
|--------------|-------|
| `project/logic/domain/` | 14 |
| `project/math/category-theory/` | 10 |
| `project/founder/templates/` | 10 |
| `project/typst/patterns/` | 9 |
| `project/typst/standards/` | 7 |
| `project/founder/domain/` | 6 |
| `project/founder/patterns/` | 6 |
| `project/typst/templates/` | 5 |
| `project/logic/processes/` | 4 |
| `project/latex/standards/` | 4 |
| `project/nix/domain/` | 4 |

## Well-Formed vs Incomplete Examples

### Well-Formed Entry (complete metadata)

```json
{
  "path": "project/filetypes/tools/tool-detection.md",
  "keywords": ["filetype", "detection", "tool"],
  "subdomain": "filetypes",
  "domain": "project",
  "summary": "Tool detection patterns for filetype handling",
  "topics": ["filetype-detection", "tool-integration"],
  "line_count": 85,
  "load_when": { "languages": ["general"] }
}
```

### Incomplete Entry (missing metadata)

```json
{
  "path": "project/logic/domain/propositional-logic.md",
  "domain": null,
  "subdomain": null,
  "summary": "Propositional logic connectives, truth tables, normal forms",
  "keywords": null,
  "topics": null,
  "line_count": 120,
  "load_when": { "languages": ["logic"] }
}
```

### Bare Entry (minimal data)

```json
{
  "path": "project/python/standards/code-style.md",
  "domain": null,
  "subdomain": null,
  "summary": null,
  "keywords": null,
  "topics": null,
  "load_when": { "languages": ["python"] }
}
```

## Existing Domain/Subdomain Value Distribution

### Domains (122 entries)

| Domain | Count |
|--------|-------|
| `project` | 100 |
| `core` | 22 |

### Subdomains (122 entries)

| Subdomain | Count | Parent Domain |
|-----------|-------|---------------|
| `lean` | 24 | project |
| `web` | 22 | project |
| `neovim` | 21 | project |
| `present` | 21 | project |
| `filetypes` | 8 | project |
| `formats` | 5 | core |
| `patterns` | 4 | core |
| `reference` | 4 | core |
| `epidemiology` | 4 | project |
| `orchestration` | 2 | core |
| `checkpoints` | 2 | core |
| `standards` | 2 | core |
| `overview` | 1 | core |
| `meta` | 1 | core |
| `architecture` | 1 | core |

## Recommended Mapping

The pattern is consistent: `domain` = `"project"` for all `project/*` paths, and `subdomain` = second path component.

| Path Prefix | domain | subdomain |
|-------------|--------|-----------|
| `project/typst/*` | `project` | `typst` |
| `project/logic/*` | `project` | `logic` |
| `project/founder/*` | `project` | `founder` |
| `project/math/*` | `project` | `math` |
| `project/nix/*` | `project` | `nix` |
| `project/latex/*` | `project` | `latex` |
| `project/python/*` | `project` | `python` |
| `project/memory/*` | `project` | `memory` |
| `project/z3/*` | `project` | `z3` |
| `project/physics/*` | `project` | `physics` |
| `project/lean4/*` | `project` | `lean4` |
| `project/filetypes/*` | `project` | `filetypes` |
| `project/web/*` | `project` | `web` |

**Note on lean4**: Existing well-formed entries for `project/lean4/*` use subdomain `"lean"` (not `"lean4"`). The 2 missing lean4 entries should follow this convention and use `"lean"` for consistency.

## Potential Mismatches

No existing entries have incorrect domain/subdomain values. All populated entries follow the expected convention.

## Implementation Approach

### Option A: jq Script (recommended)

A single jq command can assign domain/subdomain based on path prefix:

```bash
jq '(.entries[] | select(.domain == null) | select(.path | startswith("project/"))) |=
  (.domain = "project" |
   .subdomain = (.path | split("/")[1] |
     if . == "lean4" then "lean" else . end))' index.json > index_updated.json
```

### Option B: Python Script

For entries also missing `summary`, `keywords`, and `topics`, a Python script could read the actual markdown files and extract metadata. This would be a more thorough fix but requires more effort.

### Recommendation

- **Phase 1** (this task): Add `domain` and `subdomain` to all 134 entries using the jq/path-based approach. Effort: ~30 minutes.
- **Phase 2** (future task): Backfill `summary`, `keywords`, and `topics` for the 67 fully bare entries by reading the source markdown files. Effort: 1-2 hours.

## Effort Estimate

- **Domain/subdomain only**: 30 minutes -- write and test a jq transformation, verify output, commit
- **Full metadata backfill**: 1-2 hours additional -- read 67 markdown files, extract summaries and keywords
- **Total with review**: 1-2 hours for domain/subdomain fix with testing
