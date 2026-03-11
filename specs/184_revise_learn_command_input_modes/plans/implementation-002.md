# Implementation Plan: Task #184

- **Task**: 184 - revise_learn_command_input_modes
- **Status**: [NOT STARTED]
- **Effort**: 4-6 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md), [research-002.md](../reports/research-002.md)
- **Artifacts**: plans/implementation-002.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false
- **Date**: 2026-03-11
- **Feature**: Redesign /learn command with content mapping, MCP memory search, topic-based organization, and four input modes
- **Estimated Hours**: 4-6 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
- **Research Reports**: [research-001.md](../reports/research-001.md), [research-002.md](../reports/research-002.md)

## Overview

This plan supersedes implementation-001.md (which only added directory scanning) with a comprehensive redesign of the /learn command. The key architectural change is introducing a **content mapping** intermediate step: all input modes first produce a structured content map of topic segments, which are then matched against existing memories via MCP search (or grep fallback), and finally processed through three distinct memory operations (UPDATE, EXTEND, CREATE). This transforms /learn from a simple capture tool into an intelligent knowledge management system with topic-based organization and deduplication.

### Research Integration

Research-002 identified six major improvements over the original design: (1) MCP uses a two-tool pattern (search + execute) rather than individual tool names, (2) recursive directory scanning with two-tier text detection, (3) content mapping as a semantic chunking layer, (4) MCP memory search for deduplication reusing the same mechanism as /research --remember, (5) three memory operations instead of two, and (6) topic-based frontmatter for hierarchical organization. All six are incorporated into this plan.

## Goals and Non-Goals

**Goals**:
- Restructure argument parsing for four clean input modes: --task N, directory, file, text
- Add recursive directory scanning with two-tier text file detection
- Introduce content mapping as an intermediate representation between acquisition and memory creation
- Integrate MCP memory search (execute("search", ...)) with grep fallback for deduplication
- Support three memory operations: UPDATE (replace), EXTEND (append section), CREATE (new)
- Add topic field to memory frontmatter with slash-separated hierarchy
- Add "By Topic" section to index.md
- Rewrite documentation to cover the complete revised workflow

**Non-Goals**:
- NLP-based semantic analysis (use heading/section boundaries for segmentation)
- Automatic topic taxonomy management (topics are inferred, user-confirmed)
- Stdin piping support
- Memory merging (combining two existing memories into one)
- Full-text indexing or search ranking beyond keyword overlap

## Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Content mapping adds latency for small inputs | L | M | Skip mapping for inputs under 500 tokens; pass directly to memory creation |
| MCP server unavailable during search | L | M | Grep-based fallback on .memory/10-Memories/ already works |
| Topic inference assigns wrong topic | L | M | Always present inferred topic for user confirmation/override |
| UPDATE operation destroys valuable old content | H | L | Preserve old content in ## History section before replacing |
| Large directories (200+ files) overwhelm processing | M | L | Hard limit at 200 files with warning at 50; suggest narrowing path |
| Overlap scoring merges unrelated memories | M | L | Conservative 60% threshold for UPDATE; always require user confirmation |
| Increased SKILL.md complexity | M | M | Clean section structure with shared utilities; each mode delegates to content mapping |

## Implementation Phases

### Phase 1: Foundation - Memory Template and Index Schema [COMPLETED]

**Goal**: Update the memory template with new frontmatter fields (topic, last_updated) and add the "By Topic" section to index.md. These schema changes are prerequisites for all subsequent phases.

**Tasks**:
- [ ] Add `topic` field to memory-template.md frontmatter (after tags, before source)
- [ ] Add `last_updated` field to memory-template.md frontmatter (after source)
- [ ] Add "By Topic" section to index.md between "By Category" and "Statistics"
- [ ] Update Statistics section to include topic count

**Timing**: 30 minutes

**Files to modify**:
- `.opencode/extensions/memory/data/.memory/30-Templates/memory-template.md` - Add topic and last_updated fields to frontmatter template
- `.opencode/extensions/memory/data/.memory/20-Indices/index.md` - Add "By Topic" section with placeholder structure

**Verification**:
- memory-template.md frontmatter includes: id, title, date, tags, topic, source, last_updated
- index.md has "By Topic" section with explanation of slash-separated hierarchy
- Existing "By Category" section is preserved unchanged

---

### Phase 2: Command Parser - Four Input Modes [COMPLETED]

**Goal**: Rewrite learn.md argument parsing for clean four-mode detection and update the skill delegation to pass mode-specific parameters including the new content mapping workflow.

**Tasks**:
- [ ] Rewrite argument_parsing block with explicit four-mode priority chain: (1) --task N, (2) directory (-d test), (3) file (-f test), (4) text
- [ ] Add `mode=directory` and `mode=file` as distinct delegation modes (currently file and text share `mode=standard`)
- [ ] Update workflow_execution to describe the unified content mapping flow for all non-task modes
- [ ] Add directory mode to results presentation step
- [ ] Update error handling for all four modes (directory-specific: empty dir, too many files, no text files)
- [ ] Update command description and purpose line to reflect four modes
- [ ] Add "Directory Mode" section parallel to existing "Task Mode" and "Standard Mode" sections
- [ ] Rename "Standard Mode" section to cover both "File Mode" and "Text Mode" with clearer separation

**Timing**: 45 minutes

**Files to modify**:
- `.opencode/extensions/memory/commands/learn.md` - Full rewrite of argument parsing, workflow execution, mode sections, and error handling

**Verification**:
- Argument parsing shows clear priority: --task > directory > file > text
- Skill delegation uses four distinct mode values: task, directory, file, text
- Each mode has its own section with usage examples
- Error handling covers all four modes

---

### Phase 3: Content Mapping Engine [COMPLETED]

**Goal**: Add the content mapping system to SKILL.md as a shared step that all non-task modes flow through. This is the architectural centerpiece: input content is segmented into topic chunks before any memory operations occur.

**Tasks**:
- [ ] Add "Content Mapping" section to SKILL.md after Execution Modes, before individual mode sections
- [ ] Define content map data structure: source, segments[] with id, topic, source_file, source_lines, summary, estimated_tokens, key_terms
- [ ] Implement segmentation algorithm for structured files (split at heading boundaries for markdown, blank-line blocks for code)
- [ ] Implement segmentation algorithm for unstructured text (paragraph boundaries, keyword-overlap grouping)
- [ ] Implement segmentation for directory input (each file as initial segment, split large files at section boundaries)
- [ ] Add small-input bypass: inputs under 500 tokens skip mapping and become a single segment
- [ ] Add segment size guidance: target 200-500 tokens, merge segments under 100 tokens with adjacent same-topic, split segments over 800 tokens
- [ ] Define key term extraction: 3-5 significant terms per segment (nouns, technical terms, unique identifiers)

**Timing**: 1 hour

**Files to modify**:
- `.opencode/extensions/memory/skills/skill-memory/SKILL.md` - Add Content Mapping section with data structure, segmentation algorithms, and size guidelines

**Verification**:
- Content map structure is clearly defined with all fields
- Three segmentation paths exist: structured (markdown), unstructured (text), directory (per-file)
- Small-input bypass threshold (500 tokens) is documented
- Segment size targets (200-500 tokens) and merge/split rules are specified
- Key term extraction algorithm is defined

---

### Phase 4: MCP Memory Search and Deduplication [COMPLETED]

**Goal**: Add MCP-based memory search to SKILL.md that matches each content map segment against existing memories, scores overlap, and classifies the relationship as UPDATE, EXTEND, or CREATE. This reuses the same search mechanism as /research --remember.

**Tasks**:
- [ ] Add "Memory Search" section to SKILL.md after Content Mapping
- [ ] Implement MCP search path: execute("search", {query: key_terms}) for each segment
- [ ] Implement grep fallback path: grep -l -i on .memory/10-Memories/*.md when MCP unavailable
- [ ] Define overlap scoring: count keyword matches between segment key_terms and memory content
- [ ] Define classification thresholds: HIGH (>60%) -> UPDATE, MEDIUM (30-60%) -> EXTEND, LOW (<30%) -> CREATE
- [ ] Design search result presentation showing each segment with related memories, overlap score, and recommended action
- [ ] Add interactive selection via AskUserQuestion for user to confirm/override per-segment actions

**Timing**: 1 hour

**Files to modify**:
- `.opencode/extensions/memory/skills/skill-memory/SKILL.md` - Add Memory Search section with MCP path, grep fallback, scoring, classification, and interactive presentation

**Verification**:
- MCP search uses execute("search", ...) pattern matching EXTENSION.md docs
- Grep fallback is specified for MCP-unavailable case
- Three overlap thresholds are defined with clear boundaries
- Interactive presentation shows segment topic, related memories, overlap percentage, and recommended action
- User can override any recommendation (change UPDATE to CREATE, skip segment, etc.)

---

### Phase 5: Three Memory Operations [COMPLETED]

**Goal**: Replace the current two-operation model (add/append) with three distinct operations: UPDATE (replace content), EXTEND (append dated section), CREATE (new memory). Add topic inference and integrate with the content mapping flow.

**Tasks**:
- [ ] Rewrite Standard Mode to become a unified "Memory Operations" section that all modes share
- [ ] Implement UPDATE operation: read existing memory, replace content section, preserve frontmatter (id, date, tags, topic), preserve Connections section, add/update last_updated, save old content to ## History subsection
- [ ] Implement EXTEND operation: read existing memory, append new dated section (## Extension (date)), update tags if new topics introduced, update last_updated
- [ ] Implement CREATE operation: generate new memory ID, apply memory template with topic field, assign inferred topic, add to index
- [ ] Add topic inference logic: (1) directory path of source -> topic prefix, (2) keyword analysis -> topic suffix, (3) related memory topics -> inherit, (4) user override via confirmation
- [ ] Update index.md maintenance: add new entries to both "By Category" and "By Topic" sections
- [ ] Update "Task Mode" to optionally flow through content mapping for large artifacts (>500 tokens)

**Timing**: 1.5 hours

**Files to modify**:
- `.opencode/extensions/memory/skills/skill-memory/SKILL.md` - Rewrite Standard Mode as Memory Operations; add UPDATE, EXTEND, CREATE operations; add topic inference; update index maintenance; adjust Task Mode

**Verification**:
- UPDATE preserves frontmatter and Connections, saves old content to History
- EXTEND appends dated section without modifying existing content
- CREATE follows template with topic field populated
- Topic inference uses the four-source priority chain
- Index updates include both category and topic placement
- All three operations update last_updated field

---

### Phase 6: Directory Mode Execution [COMPLETED]

**Goal**: Add the complete directory mode execution path to SKILL.md, including recursive scanning with two-tier text detection, file selection, and routing through the content mapping pipeline.

**Tasks**:
- [ ] Add "Directory Mode Execution" section to SKILL.md
- [ ] Implement recursive scanning: find with exclusion patterns (.git/, node_modules/, __pycache__, .obsidian/, binary extensions)
- [ ] Implement two-tier text detection: Tier 1 extension whitelist (60+ formats from research-002), Tier 2 `file --mime-type` fallback
- [ ] Add size limits: 100KB per file skip, warning at 50 files, hard limit at 200 files
- [ ] Present scanned file list via AskUserQuestion multiSelect with file sizes
- [ ] Route selected files through content mapping (Phase 3) as directory-type segmentation
- [ ] Route content map through memory search (Phase 4) and memory operations (Phase 5)
- [ ] Add directory-specific error handling: empty directory, no text files, over limit

**Timing**: 45 minutes

**Files to modify**:
- `.opencode/extensions/memory/skills/skill-memory/SKILL.md` - Add Directory Mode Execution section with scanning, selection, and pipeline routing

**Verification**:
- Recursive scanning excludes .git/, node_modules/, etc.
- Two-tier detection: extension whitelist first, mime-type fallback second
- Size limits enforced: 100KB/file, 50 warning, 200 hard limit
- Selected files flow through content mapping -> memory search -> operations
- Directory errors handled gracefully

---

### Phase 7: Documentation Rewrite [COMPLETED]

**Goal**: Update all documentation to reflect the redesigned /learn command with four modes, content mapping, and topic-based organization.

**Tasks**:
- [ ] Rewrite EXTENSION.md command table to show all four /learn modes with content mapping note
- [ ] Update EXTENSION.md MCP Integration section to correct tool names (execute("search", ...) pattern)
- [ ] Full rewrite of learn-usage.md:
  - New sections: Text Mode, File Mode, Directory Mode, Task Mode, Content Mapping, Memory Operations, Topic Organization
  - Updated examples for each mode showing the content map -> search -> operate flow
  - Updated Quick Reference table with all four modes
  - Updated Best Practices with topic guidelines
- [ ] Update knowledge-capture-usage.md /learn examples to show new workflow
- [ ] Update SKILL.md context references if paths changed

**Timing**: 45 minutes

**Files to modify**:
- `.opencode/extensions/memory/EXTENSION.md` - Update command table, MCP tool names
- `.opencode/extensions/memory/context/project/memory/learn-usage.md` - Full rewrite with four modes, content mapping, and topic organization
- `.opencode/extensions/memory/context/project/memory/knowledge-capture-usage.md` - Update /learn cross-reference examples

**Verification**:
- EXTENSION.md shows all four modes: text, file, directory, --task N
- learn-usage.md covers full workflow: input -> content map -> search -> operate
- All examples show the new interactive flow with segment presentation
- Quick reference table includes all modes and operations (UPDATE/EXTEND/CREATE)
- No references to old two-operation model (add/append) remain in docs

---

## Testing and Validation

- [ ] Argument parsing correctly routes: `--task 42` -> task, `/path/dir/` -> directory, `/path/file.md` -> file, `"text"` -> text
- [ ] Content mapping produces segments with all required fields (id, topic, summary, key_terms, estimated_tokens)
- [ ] Small inputs (<500 tokens) bypass content mapping and become single segment
- [ ] MCP search returns related memories; grep fallback works when MCP unavailable
- [ ] Overlap scoring correctly classifies: >60% -> UPDATE, 30-60% -> EXTEND, <30% -> CREATE
- [ ] UPDATE preserves frontmatter and saves old content to History
- [ ] EXTEND appends dated section without modifying existing content
- [ ] CREATE populates topic field from inference
- [ ] Directory scanning respects exclusion patterns and size limits
- [ ] Index.md updated with both category and topic entries
- [ ] Memory template includes topic and last_updated fields
- [ ] All documentation is internally consistent

## Artifacts and Outputs

- Modified: `.opencode/extensions/memory/data/.memory/30-Templates/memory-template.md`
- Modified: `.opencode/extensions/memory/data/.memory/20-Indices/index.md`
- Modified: `.opencode/extensions/memory/commands/learn.md`
- Modified: `.opencode/extensions/memory/skills/skill-memory/SKILL.md`
- Modified: `.opencode/extensions/memory/EXTENSION.md`
- Modified: `.opencode/extensions/memory/context/project/memory/learn-usage.md`
- Modified: `.opencode/extensions/memory/context/project/memory/knowledge-capture-usage.md`

## Rollback/Contingency

All changes are to markdown specification files (no executable code). Rollback is straightforward via `git checkout` of the seven modified files. No runtime state or data is affected. The memory vault data (.memory/10-Memories/) is never modified by this plan -- only templates, indices, and command/skill specifications change.

If implementation reveals that content mapping adds too much complexity, Phase 3 can be simplified to a pass-through that treats each input as a single segment, preserving the MCP search and three-operation model from Phases 4-5 without the segmentation logic.
