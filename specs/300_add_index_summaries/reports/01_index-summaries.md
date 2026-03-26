# Research: Add Missing Summaries to index.json Entries

**Task**: 300
**Date**: 2026-03-26
**Status**: Complete

## Overview

The Website project's `.claude/context/index.json` contains 256 entries, of which 67 are missing the `summary` field. This report analyzes the gap, establishes conventions, and proposes an approach.

## Distribution

| Category | Count | Percentage |
|----------|-------|------------|
| With summary | 189 | 73.8% |
| Without summary | 67 | 26.2% |
| **Total** | **256** | **100%** |

## Missing Summaries by Domain/Path Prefix

| Path Prefix | Missing Count |
|-------------|---------------|
| project/typst/ | 24 |
| project/nix/ | 11 |
| project/latex/ | 10 |
| project/z3/ | 5 |
| project/python/ | 6 |
| project/memory/ | 5 |
| project/lean4/ | 2 |
| project/web/ | 1 |
| project/filetypes/ | 1 |

All 67 missing entries are in the `project/` subtree (extension context). Core context entries all have summaries.

## Summary Style Convention

Existing summaries follow a consistent pattern:
- **Length**: 27-112 characters, average 54 characters
- **Style**: Noun-phrase or short description, no trailing period
- **Content**: Describes what the file contains or provides, not what it does
- **Examples**:
  - "Overview of context system structure and usage patterns"
  - "Language-based routing for research and implementation"
  - "GATE IN preflight validation pattern"
  - "Metadata file schema for agent return values"

## Sample Drafted Summaries

Based on reading file headers of entries missing summaries:

| Path | Proposed Summary |
|------|-----------------|
| `project/filetypes/domain/conversion-tables.md` | Document conversion tool mappings and fallback chains |
| `project/memory/learn-usage.md` | /learn command usage guide for memory vault operations |
| `project/memory/memory-setup.md` | Memory system setup and configuration instructions |
| `project/python/standards/code-style.md` | Python code formatting and style guidelines |
| `project/typst/standards/compilation-standards.md` | Standards for compiling Typst documents |
| `project/typst/standards/notation-conventions.md` | Two-tier notation architecture for Typst documents |
| `project/typst/standards/type-theory-foundations.md` | Dependent type theory treatment standards for Typst |
| `project/nix/README.md` | Overview of NixOS and Home Manager context |

## Usage Analysis

The `summary` field is **not referenced** in any `load_when` conditions or routing logic. It serves as:
1. **Documentation** -- helps humans understand what each context file contains
2. **Search/discovery** -- agents can use summaries to decide which files to load
3. **Context budgeting** -- combined with `line_count`, summaries help agents estimate relevance before loading

While not mechanically required for routing, summaries improve agent decision-making when selecting context files to load.

## Proposed Approach

### Recommended: Semi-automated script

1. For each entry missing a summary, read the first 5-10 lines of the file
2. Extract the title (H1 heading) and any purpose/overview text
3. Generate a 40-70 character summary following the established convention
4. Write all summaries back to index.json in a single pass

A Python script can automate reading file headers and generating draft summaries. Manual review of the 67 drafts ensures quality.

### Alternative: Fully manual

Read each file and write summaries by hand. More accurate but slower.

### Recommendation

Use the semi-automated approach. Most files have clear H1 headings and purpose statements that map directly to summary text. Edge cases (about 10-15 entries) may need manual review after script generation.

## Effort Estimate

- **Semi-automated**: 30-45 minutes (script + review + corrections)
- **Fully manual**: 60-90 minutes

## Dependencies

- **Task 298**: Should complete first to establish metadata conventions. Summary field conventions should align with whatever metadata standards task 298 defines.

## Conclusion

67 entries (all in `project/` extensions) need summaries. The existing convention is clear and consistent. A semi-automated approach reading file headers can generate accurate summaries for most entries, with manual review for edge cases.
