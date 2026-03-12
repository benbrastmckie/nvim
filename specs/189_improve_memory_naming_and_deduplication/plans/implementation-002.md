# Implementation Plan: Task #189

- **Task**: 189 - improve_memory_naming_and_deduplication
- **Status**: [IMPLEMENTING]
- **Effort**: 3-4 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-002.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Revision**: v002 - Keep MEM- prefix for searchability

## Overview

This plan implements semantic slug-based naming for memories while **preserving the MEM- prefix** for grep/search discoverability. The naming convention changes from `MEM-{date}-{unix_ms}-{random_4}.md` to `MEM-{semantic-slug}.md` (e.g., `MEM-telescope-custom-pickers.md`). This maintains searchability via `grep MEM-` while providing human-readable filenames.

### Revision Note (v002)

Changed from original plan: **MEM- prefix is retained** because it enables easy searching/filtering of memory files via grep patterns. Only the suffix changes from timestamp-based to semantic slug.

### Research Integration

Key findings from research-001.md integrated:
- Current ID generation uses redundant date/timestamp in both filename and frontmatter
- Existing overlap scoring (Jaccard similarity with 60%/30% thresholds) is well-designed
- Best practices favor semantic filenames with metadata-based date tracking
- **User feedback**: MEM- prefix aids discoverability and should be preserved

## Goals & Non-Goals

**Goals**:
- Replace `MEM-{date}-{unix_ms}-{random}` with `MEM-{semantic-slug}` naming
- Rename `date` field to `created` and `last_updated` to `modified`
- Remove `id` field from frontmatter (filename becomes identifier)
- Maintain `MEM-*.md` grep patterns for searchability
- Ensure both .claude/ and .opencode/ memory extensions are updated consistently
- Update memory template and README generation patterns

**Non-Goals**:
- Adding semantic embedding-based deduplication (current keyword overlap is sufficient)
- Creating automated migration of existing memories (manual or future task)
- Adding keyword-index.json optimization (optional enhancement for future)
- Modifying the overlap scoring thresholds (already well-calibrated)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Slug collisions | M | L | Append `-2`, `-3` suffix; overlap scoring catches most cases before CREATE |
| Breaking existing memories | M | L | Only new memories use new format; existing memories unchanged |
| Obsidian link breakage | L | L | New memories use `[[MEM-slug]]` format; existing links preserved |

## Implementation Phases

### Phase 1: Update Memory Template [COMPLETED]

**Goal**: Update frontmatter template to use new field names and remove id field

**Tasks**:
- [ ] Edit `.claude/extensions/memory/data/.memory/30-Templates/memory-template.md`:
  - Remove `id: MEM-{{date}}-{{sequence}}` field
  - Rename `date:` to `created:`
  - Rename `last_updated:` to `modified:`
  - Keep `title`, `tags`, `topic`, `source` fields unchanged
- [ ] Edit `.opencode/extensions/memory/data/.memory/30-Templates/memory-template.md` with identical changes
- [ ] Verify `.memory/30-Templates/memory-template.md` (root vault) exists and update if present

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/memory/data/.memory/30-Templates/memory-template.md` - Frontmatter field updates
- `.opencode/extensions/memory/data/.memory/30-Templates/memory-template.md` - Same changes
- `.memory/30-Templates/memory-template.md` - Same changes (if exists)

**Verification**:
- Read updated templates and confirm:
  - No `id:` field present
  - `created:` replaces `date:`
  - `modified:` replaces `last_updated:`

---

### Phase 2: Implement Slug Generation Algorithm [COMPLETED]

**Goal**: Add slug generation logic to SKILL.md and replace ID generation

**Tasks**:
- [ ] Add slug generation algorithm to `.claude/extensions/memory/skills/skill-memory/SKILL.md`:
  ```bash
  generate_slug() {
    local topic="$1"
    local title="$2"
    local base=""

    # Priority 1: Topic path (most specific segment)
    if [ -n "$topic" ]; then
      base=$(echo "$topic" | rev | cut -d'/' -f1 | rev)
    fi

    # Priority 2: First 2-3 words of title
    local title_slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | \
      sed 's/[^a-z0-9 ]/-/g' | tr ' ' '-' | \
      cut -d'-' -f1-3 | sed 's/-$//')

    # Combine
    if [ -n "$base" ]; then
      slug="${base}-${title_slug}"
    else
      slug="$title_slug"
    fi

    # Sanitize and truncate to 50 chars
    slug=$(echo "$slug" | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | cut -c1-50)

    # Handle collision - NOTE: MEM- prefix preserved
    local final_slug="$slug"
    local counter=2
    while [ -f ".memory/10-Memories/MEM-${final_slug}.md" ]; do
      final_slug="${slug}-${counter}"
      counter=$((counter + 1))
    done

    echo "$final_slug"
  }
  ```
- [ ] Replace ID generation block (lines 313-322) with slug generation call
- [ ] Update CREATE operation template to use `MEM-${slug}.md` filename (preserving MEM- prefix)
- [ ] Update UPDATE and EXTEND operations to work with any `MEM-*.md` filename pattern
- [ ] Apply identical changes to `.opencode/extensions/memory/skills/skill-memory/SKILL.md`

**Timing**: 1 hour

**Files to modify**:
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` - Add slug generation, update CREATE
- `.opencode/extensions/memory/skills/skill-memory/SKILL.md` - Same changes

**Verification**:
- Grep for timestamp-based ID generation - should be replaced with slug generation
- Confirm generate_slug function exists in both files
- Check CREATE operation references `MEM-${slug}.md`
- Verify MEM- prefix is preserved for grep discoverability

---

### Phase 3: Update Index and README Generation [NOT STARTED]

**Goal**: Update index maintenance to handle semantic filenames and new metadata fields

**Tasks**:
- [ ] Update Index Maintenance section (line ~376-396):
  - Change README.md listing format from timestamp-based to slug-based
  - Update metadata extraction to use `created:` instead of `date:`
  - Update template to use `modified:` instead of `last_updated:`
- [ ] Update example entries in documentation:
  - Change `MEM-2026-03-05-042` references to `MEM-{slug}` examples
  - Update Search Result Presentation section with new filename format
- [ ] Update `.memory/10-Memories/README.md` structure comment:
  - Change from: `### [MEM-YYYY-MM-DD-NNN](MEM-YYYY-MM-DD-NNN.md)`
  - Change to: `### [MEM-{slug}](MEM-{slug}.md)`
- [ ] Apply identical changes to `.opencode/extensions/memory/skills/skill-memory/SKILL.md`

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` - Index maintenance updates
- `.opencode/extensions/memory/skills/skill-memory/SKILL.md` - Same changes

**Verification**:
- Grep for timestamp patterns like "MEM-YYYY" or "MEM-2026" - should be replaced with slug examples
- Confirm index extraction uses `created:` field
- Confirm README generation template uses `MEM-{slug}` linking
- Verify `MEM-*.md` grep patterns still work for search

---

### Phase 4: Synchronize Root Memory Vault [NOT STARTED]

**Goal**: Ensure root .memory/ vault template is consistent with extension templates

**Tasks**:
- [ ] Check if `.memory/30-Templates/memory-template.md` exists at project root
- [ ] If exists, update with same frontmatter changes as Phase 1
- [ ] Verify `.memory/10-Memories/README.md` structure is compatible with new format
- [ ] Update any hardcoded timestamp-based references in root vault files

**Timing**: 15 minutes

**Files to modify**:
- `.memory/30-Templates/memory-template.md` - Frontmatter updates (if exists)
- `.memory/10-Memories/README.md` - Header/structure updates (if needed)

**Verification**:
- Confirm all three template locations use identical frontmatter structure
- Verify `MEM-` prefix convention documented in README

---

### Phase 5: Documentation and Verification [NOT STARTED]

**Goal**: Update documentation and perform end-to-end verification

**Tasks**:
- [ ] Update examples in SKILL.md to use `MEM-{slug}` format consistently
- [ ] Update any remaining `id:` field references in documentation
- [ ] Add note about MEM- prefix being preserved for grep discoverability
- [ ] Create summary of changes for implementation summary
- [ ] Verify both .claude/ and .opencode/ SKILL.md files are identical (diff check)
- [ ] Verify template files across all three locations are consistent

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` - Documentation examples
- `.opencode/extensions/memory/skills/skill-memory/SKILL.md` - Same changes

**Verification**:
- Run: `diff .claude/extensions/memory/skills/skill-memory/SKILL.md .opencode/extensions/memory/skills/skill-memory/SKILL.md` - expect no differences
- Grep for timestamp-based patterns - should only appear in explicit migration notes
- Confirm all frontmatter examples use `created:` and `modified:`
- Confirm `grep MEM-` still finds all memory files

---

## Testing & Validation

- [ ] Template verification: All three template files use `created:`/`modified:` fields, no `id:` field
- [ ] SKILL.md consistency: `.claude/` and `.opencode/` versions are identical
- [ ] Naming convention: New memories created as `MEM-{slug}.md`
- [ ] Slug generation: Function exists and handles collision with `-N` suffix
- [ ] Grep discoverability: `grep -r "MEM-" .memory/10-Memories/` finds all memories
- [ ] Index maintenance: README generation uses `MEM-{slug}` format
- [ ] Metadata extraction: Uses `created:` field for date extraction

## Artifacts & Outputs

- `specs/189_improve_memory_naming_and_deduplication/plans/implementation-001.md` (superseded)
- `specs/189_improve_memory_naming_and_deduplication/plans/implementation-002.md` (this file)
- `specs/189_improve_memory_naming_and_deduplication/summaries/implementation-summary-YYYYMMDD.md` (on completion)
- Modified files:
  - `.claude/extensions/memory/skills/skill-memory/SKILL.md`
  - `.opencode/extensions/memory/skills/skill-memory/SKILL.md`
  - `.claude/extensions/memory/data/.memory/30-Templates/memory-template.md`
  - `.opencode/extensions/memory/data/.memory/30-Templates/memory-template.md`
  - `.memory/30-Templates/memory-template.md` (if exists)

## Rollback/Contingency

- All changes are to .claude/ and .opencode/ extension files, not to actual memory content
- If issues arise, revert commits affecting SKILL.md and template files
- Existing memories (if any) are unaffected - they retain their current filenames
- New memories will use `MEM-{slug}` naming; this is forward-compatible
- Git history preserves all previous versions for reference
