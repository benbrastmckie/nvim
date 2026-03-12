# Research Report: Task #189

**Task**: 189 - improve_memory_naming_and_deduplication
**Started**: 2026-03-12
**Completed**: 2026-03-12
**Effort**: 2-4 hours
**Dependencies**: None
**Sources/Inputs**: Codebase analysis, WebSearch for naming conventions and deduplication algorithms
**Artifacts**: specs/189_improve_memory_naming_and_deduplication/reports/research-001.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Current memory naming uses verbose `MEM-{date}-{unix_ms}-{random_4}` format (e.g., `MEM-2026-03-12-1773330053135-4d32`)
- The `MEM` prefix, date, and timestamp are redundant since the directory context (`.memory/10-Memories/`) and internal metadata already capture this information
- Recommendation: Use short semantic slugs (e.g., `telescope-custom-pickers.md`) with metadata-based tracking
- Existing overlap scoring (keyword-based Jaccard similarity) is well-designed; enhancements could include semantic embeddings for future scalability
- All memories should include standardized frontmatter metadata with creation and modification dates

## Context and Scope

### Problem Statement

The memory systems in `.claude/` and `.opencode/` use timestamp-heavy naming conventions that:
1. Create long, hard-to-read filenames (e.g., `MEM-2026-03-12-1773330053135-4d32.md`)
2. Duplicate information already present in frontmatter metadata
3. Make manual navigation and search difficult
4. Do not convey the content or topic of the memory

### Research Questions

1. What naming patterns exist currently in the memory extension?
2. What are best practices for semantic slug generation?
3. How should deduplication/overlap detection work before storing new memories?
4. What metadata format should memories use?

## Findings

### Current Memory System Architecture

Both `.claude/` and `.opencode/` share identical memory extension implementations:

**Memory Vault Structure:**
```
.memory/
+-- .obsidian/           # Obsidian configuration
+-- 00-Inbox/            # Quick capture for new memories
+-- 10-Memories/         # Stored memory entries (target of improvements)
+-- 20-Indices/          # Navigation and organization
+-- 30-Templates/        # Memory entry templates
```

**Current Naming Convention (from SKILL.md):**
```bash
# Current ID generation algorithm
today=$(date +%Y-%m-%d)
unix_ms=$(date +%s%N | head -c13)
random_4=$(od -An -N2 -tx1 /dev/urandom | tr -d ' ')
memory_id="MEM-${today}-${unix_ms}-${random_4}"
```

This produces filenames like: `MEM-2026-03-12-1773330053135-4d32.md`

**Redundancy Analysis:**
| Component | In Filename | In Frontmatter | In Directory |
|-----------|-------------|----------------|--------------|
| "MEM" prefix | Yes | No (implicit) | Yes (10-Memories/) |
| Date (YYYY-MM-DD) | Yes | Yes (`date:`) | No |
| Timestamp (ms) | Yes | No | No |
| Random ID | Yes | No | No |
| Topic/Content | No | Yes (`topic:`, `title:`) | No |

The current scheme prioritizes uniqueness over readability but duplicates date information unnecessarily.

### Existing Deduplication System

The memory skill already implements a robust deduplication workflow:

**Content Mapping Phase:**
1. Input segmented into topic-aligned chunks
2. Key terms extracted (3-5 per segment)
3. Segments assigned unique IDs (`seg-001`, etc.)

**Memory Search Phase:**
```
For each segment:
  1. Extract key_terms
  2. MCP search OR grep fallback
  3. Calculate overlap_score = |segment_terms intersect memory_terms| / |segment_terms|
```

**Classification Thresholds:**
| Overlap Score | Classification | Action |
|---------------|----------------|--------|
| >60% | HIGH | UPDATE - Replace memory content |
| 30-60% | MEDIUM | EXTEND - Append new section |
| <30% | LOW | CREATE - New memory |

This existing system is well-designed for pre-storage deduplication. The issue is that it requires MCP or grep to find existing memories by keyword, which works but could be enhanced.

### Best Practices from External Research

**File Naming Conventions:**

From [Smithsonian Data Management](https://library.si.edu/sites/default/files/tutorial/pdf/filenamingorganizing20180227.pdf) and [IT Glue](https://www.itglue.com/blog/naming-conventions-examples-formats-best-practices/):
- Avoid overcomplicating filenames with too much semantic information
- Once metadata records exist, use those for discovery rather than filenames
- Keep naming simple and intuitive
- Avoid redundancy between directory names and filenames

**Obsidian/Zettelkasten Community Practices:**

From [Obsidian Forum discussions](https://forum.obsidian.md/t/i-want-to-get-better-in-namingfile-names/11029) and [Jamie Rubin's guide](https://jamierubin.net/2021/11/09/practically-paperless-with-obsidian-episode-6-tips-for-naming-notes/):
- Timestamp prefixes useful for chronological sorting but reduce readability
- Semantic titles enable quick recognition and sensemaking
- Hybrid approaches exist: `YYYYMMDDHHmmss--title__tag1_tag2`
- Many prefer semantic names with dates in metadata only

**Deduplication Algorithms:**

From [Made of Bugs (MinHash)](https://blog.nelhage.com/post/fuzzy-dedup/) and [Hugging Face (BigCode)](https://huggingface.co/blog/dedup):
- **Jaccard Similarity**: Ratio of overlap to union - exactly what current system uses
- **MinHash/LSH**: Probabilistic technique for large-scale similarity
- **Semantic Deduplication**: Embeddings from LLMs for semantic similarity (expensive)
- For small-scale systems, keyword overlap (current approach) is appropriate

### Codebase Patterns

**Task Directory Naming:**
The specs/ directory uses `{NNN}_{slug}` format (e.g., `189_improve_memory_naming_and_deduplication/`), demonstrating a preference for semantic slugs with numeric prefixes.

**Artifact Naming:**
Plan and report files use `{type}-{NNN}.md` format (e.g., `research-001.md`), showing that version numbers are preferred over timestamps for artifacts.

## Recommendations

### 1. New Naming Convention

**Proposed Format:** `{slug}.md`

Where `{slug}` is:
- Derived from the topic path and/or first significant words of title
- Lowercase with hyphens for word separation
- Maximum 50 characters
- No date, timestamp, or "MEM" prefix

**Examples:**
| Current | Proposed |
|---------|----------|
| `MEM-2026-03-12-1773330053135-4d32.md` | `telescope-custom-pickers.md` |
| `MEM-2026-03-11-1773243000000-ab12.md` | `neovim-lsp-config-patterns.md` |
| `MEM-2026-03-10-1773156000000-cd34.md` | `lazy-nvim-plugin-spec.md` |

**Slug Generation Algorithm:**
```python
def generate_slug(topic: str, title: str) -> str:
    # Priority 1: Topic path (most specific segment)
    if topic:
        base = topic.split('/')[-1]  # e.g., "neovim/plugins/telescope" -> "telescope"
    else:
        base = ""

    # Priority 2: First 2-3 words of title
    title_words = title.lower().split()[:3]
    title_slug = '-'.join(title_words)

    # Combine if topic exists
    if base:
        slug = f"{base}-{title_slug}"
    else:
        slug = title_slug

    # Sanitize: lowercase, replace spaces/underscores with hyphens
    slug = re.sub(r'[^a-z0-9-]', '-', slug.lower())
    slug = re.sub(r'-+', '-', slug).strip('-')

    # Truncate to 50 chars at word boundary
    if len(slug) > 50:
        slug = slug[:50].rsplit('-', 1)[0]

    return slug
```

**Collision Handling:**
If `{slug}.md` already exists:
1. First check overlap score - may be UPDATE/EXTEND instead of CREATE
2. If CREATE needed, append `-2`, `-3`, etc.

### 2. Enhanced Metadata Format

**Proposed Frontmatter:**
```yaml
---
title: "Telescope Custom Picker Patterns"
created: 2026-03-12
modified: 2026-03-12
topic: "neovim/plugins/telescope"
tags: [telescope, picker, neovim]
source: "file: /path/to/source.md"
category: "[PATTERN]"
---
```

**Field Changes:**
| Current Field | Proposed Change |
|---------------|-----------------|
| `id: MEM-...` | Remove (filename is now the identifier) |
| `date:` | Rename to `created:` for clarity |
| `last_updated:` | Rename to `modified:` for brevity |
| (new) | Add `category:` for classification tag |

### 3. Pre-Storage Overlap Scanning

The current system already implements overlap scanning via the Memory Search phase. Enhancements:

**A. Always-On Overlap Check:**
Currently, overlap scanning runs during `/learn` command. Recommend making it automatic for any memory write operation.

**B. Quick Index for Fast Lookup:**
Maintain a lightweight JSON index file for rapid keyword matching without full-file reads:

```json
// .memory/20-Indices/keyword-index.json
{
  "telescope": ["telescope-custom-pickers.md", "neovim-fuzzy-finder.md"],
  "lsp": ["neovim-lsp-config-patterns.md", "lsp-diagnostics-setup.md"],
  "plugin": ["lazy-nvim-plugin-spec.md", "neovim-plugin-development.md"]
}
```

**C. Similarity Score Refinement:**
Current thresholds (60%/30%) are reasonable. Could add:
- Title similarity check (Levenshtein distance)
- Topic hierarchy matching (same parent topic = higher similarity)

### 4. Index File Maintenance

**Update `.memory/10-Memories/README.md` Pattern:**
Since filenames are now semantic, the README becomes more valuable for quick scanning:

```markdown
# Memories

## Contents

### [telescope-custom-pickers.md](telescope-custom-pickers.md)
**Title**: Telescope Custom Picker Patterns
**Topic**: neovim/plugins/telescope
**Category**: [PATTERN]
**Modified**: 2026-03-12

### [neovim-lsp-config-patterns.md](neovim-lsp-config-patterns.md)
**Title**: Neovim LSP Configuration Patterns
**Topic**: neovim/lsp
**Category**: [CONFIG]
**Modified**: 2026-03-11
```

### 5. Migration Strategy

For existing memories (if any exist):
1. Read frontmatter to extract title and topic
2. Generate new slug using algorithm above
3. Rename file
4. Update index files

## Decisions

1. **Remove `MEM-` prefix** - Provides no value; directory context is sufficient
2. **Remove date from filename** - Captured in frontmatter `created:` field
3. **Remove timestamp/random suffix** - Collision handling via `-N` suffix simpler
4. **Rename `date` to `created`** - More explicit naming
5. **Rename `last_updated` to `modified`** - Brevity
6. **Add `category` field** - Surface classification in frontmatter
7. **Remove `id` field** - Filename is now the identifier

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Slug collisions | Append `-2`, `-3` suffix; overlap scoring should catch most cases |
| Breaking existing memories | Migration script provided; check for existing files first |
| Obsidian link breakage | Obsidian uses `[[filename]]` which will need updating |
| Loss of creation timestamp precision | Keep `created:` date; add optional `created_at:` for full timestamp if needed |
| Grep fallback assumes MEM-* pattern | Update grep patterns to match `*.md` in 10-Memories/ |

## Implementation Scope

### Files to Modify

1. `.claude/extensions/memory/skills/skill-memory/SKILL.md` - ID generation, template
2. `.opencode/extensions/memory/skills/skill-memory/SKILL.md` - Same changes
3. `.claude/extensions/memory/data/.memory/30-Templates/memory-template.md` - Update template
4. `.opencode/extensions/memory/data/.memory/30-Templates/memory-template.md` - Same
5. `.memory/30-Templates/memory-template.md` - Root vault template
6. Index regeneration logic in SKILL.md (grep patterns, README format)

### Estimated Effort

- Phase 1: Update templates and ID generation - 1-2 hours
- Phase 2: Update index maintenance logic - 1 hour
- Phase 3: Update grep fallback patterns - 30 minutes
- Phase 4: Add keyword-index.json generation (optional) - 1 hour
- Phase 5: Create migration script (optional) - 1 hour

**Total: 2-4 hours**

## Context Extension Recommendations

None applicable for this meta task.

## Appendix

### Search Queries Used

1. "best practices semantic file naming slug generation knowledge management"
2. "obsidian note naming conventions semantic slugs vs timestamps"
3. "content deduplication similarity detection knowledge base text overlap algorithms"

### References

- [Smithsonian Data Management Best Practices](https://library.si.edu/sites/default/files/tutorial/pdf/filenamingorganizing20180227.pdf)
- [IT Glue Naming Conventions](https://www.itglue.com/blog/naming-conventions-examples-formats-best-practices/)
- [Obsidian Forum - File Naming Discussion](https://forum.obsidian.md/t/i-want-to-get-better-in-namingfile-names/11029)
- [Jamie Rubin - Tips for Naming Notes](https://jamierubin.net/2021/11/09/practically-paperless-with-obsidian-episode-6-tips-for-naming-notes/)
- [MinHash and Jaccard Similarity](https://blog.nelhage.com/post/fuzzy-dedup/)
- [Hugging Face - Large-scale Deduplication](https://huggingface.co/blog/dedup)

### Codebase Files Examined

- `.claude/extensions/memory/skills/skill-memory/SKILL.md`
- `.opencode/extensions/memory/skills/skill-memory/SKILL.md`
- `.claude/extensions/memory/commands/learn.md`
- `.claude/extensions/memory/EXTENSION.md`
- `.memory/README.md`
- `.memory/30-Templates/memory-template.md`
- `.claude/extensions/memory/context/project/memory/memory-setup.md`
- `.claude/extensions/memory/context/project/memory/knowledge-capture-usage.md`
