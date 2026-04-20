# Context File Revision Guide for Meta Agents

**Last Updated**: 2026-04-19
**Purpose**: Guide meta agents on when and how to revise context files without bloat

---

## When to Revise Context Files

### Update Existing File (Preferred)

Update an existing context file when:
- Standard evolves (e.g., new frontmatter field required)
- Pattern improves (e.g., better routing logic discovered)
- Example needs updating (e.g., outdated syntax)
- File is under 200 lines and change fits naturally
- Change is directly related to existing content

**Example**: Adding a new routing pattern to `orchestration/routing.md`

### Create New File

Create a new context file when:
- New domain pattern discovered (e.g., formal verification domain)
- New standard introduced (e.g., new artifact type)
- Existing file would exceed 200 lines with addition
- Concept is orthogonal to existing files
- Topic deserves dedicated focus

**Example**: Creating `extensions/{ext}/context/patterns/optimization-patterns.md` for domain-specific patterns

### Split Existing File

Split an existing file when:
- File exceeds 200 lines
- File covers multiple distinct concepts
- File has low cohesion (unrelated sections)
- Natural boundaries exist between sections

**Example**: Splitting `orchestration/delegation.md` into `delegation-basics.md` and `delegation-patterns.md`

---

## How to Revise Without Bloat

### File Size Limits

- **Target**: 50-200 lines per file
- **Warning**: 200-250 lines (consider splitting)
- **Error**: >250 lines (must split)

### Revision Checklist

1. **Read existing file completely** -- understand current structure and content
2. **Check if change fits within 200-line limit** -- count current lines, estimate additions
3. **If yes**: Update in place, preserve existing structure, update date
4. **If no**: Split file or create new file, update references
5. **Update context index** -- add new files, update descriptions and line_count
6. **Update dependent agents** -- find agents loading this file, update context references

---

## Context File Types and Revision Patterns

### Core Standards (`.claude/context/standards/`)

**When to revise**: System-wide standard changes
**Examples**: `xml-structure.md`, `documentation-standards.md`, `task-management.md`
**Revision pattern**: Update in place (rarely changes)
**Frequency**: Low (quarterly or less)

### Core Templates (`.claude/context/templates/`)

**When to revise**: Template structure changes
**Examples**: `agent-template.md`, `command-template.md`, `thin-wrapper-skill.md`
**Revision pattern**: Update in place, add version notes
**Frequency**: Medium (monthly)

### Core Workflows (`.claude/context/workflows/`)

**When to revise**: Workflow pattern changes
**Examples**: `command-lifecycle.md`, `status-transitions.md`, `preflight-postflight.md`
**Revision pattern**: Update in place, document changes
**Frequency**: Medium (monthly)

### Project Meta (`.claude/context/meta/`)

**When to revise**: Meta-system patterns evolve
**Examples**: `meta-guide.md`, `domain-patterns.md`, `context-revision-guide.md`
**Revision pattern**: Update frequently, split if >200 lines
**Frequency**: High (weekly)

### Project Domain (`.claude/context/project/{domain}/`)

**When to revise**: Domain knowledge expands
**Examples**: Domain-specific tool guides, pattern files, API references
**Revision pattern**: Create new files for new concepts
**Frequency**: High (per-task)

---

## Revision Workflow

### Stage 1: Assess Impact

1. **Identify affected files** -- which context files need changes? Breaking or additive?
2. **Count dependent agents** -- how many agents load these files?
3. **Determine change type** -- update existing, add new, or remove obsolete?

### Stage 2: Plan Revision

1. **Choose revision strategy** -- update in place, create new file, or split?
2. **Check file size constraints** -- current line count, estimated new count, within 200 lines?
3. **Identify index updates needed** -- line_count changes, new entries, removed entries?

### Stage 3: Execute Revision

1. **Update/create context files** -- make targeted changes, follow file size limits
2. **Update context index** -- add new files, update line_count, maintain organization
3. **Sync extension source and deployed copies** -- both locations must match
4. **Test affected agents** -- verify context loads correctly

### Stage 4: Validate

1. **Check file sizes** -- all files within limits?
2. **Verify context index** -- all files listed with correct line_count?
3. **Verify sync** -- deployed and extension source copies are identical?
4. **Check for duplication** -- no duplicate content across files?

---

## Common Revision Scenarios

### Scenario 1: New Pattern Discovered

**Situation**: Agent discovers new delegation pattern
**Action**: Update `orchestration/delegation.md`
**Steps**:
1. Read file (currently 180 lines)
2. Add new pattern section (20 lines)
3. Total: 200 lines (within limit)
4. Update date
5. No agent updates needed (already loaded)

### Scenario 2: File Exceeds Limit

**Situation**: `standards/task-management.md` grows to 220 lines
**Action**: Split into two files
**Steps**:
1. Identify natural boundary (e.g., task creation vs. task updates)
2. Create `task-creation.md` (100 lines)
3. Create `task-updates.md` (120 lines)
4. Update context index (remove old entry, add two new entries)
5. Update agents loading task-management.md to load both files

### Scenario 3: New Domain Added

**Situation**: Adding a new domain extension (e.g., Typst)
**Action**: Create new extension directory
**Steps**:
1. Create `.claude/extensions/typst/` with manifest.json
2. Create domain-specific context files
3. Add index entries via `index-entries.json`
4. Register routing in manifest

### Scenario 4: Standard Evolves

**Situation**: New frontmatter field required for all agents
**Action**: Update `standards/xml-structure.md`
**Steps**:
1. Read xml-structure.md
2. Add new field documentation
3. Update examples
4. Update date
5. No agent updates needed (standard applies to all)

---

## Anti-Patterns to Avoid

### Bloated Files

**Problem**: Single file grows to 500+ lines
**Why bad**: Hard to navigate, slow to load, low cohesion
**Solution**: Split into focused files (50-200 lines each)

### Duplicate Content

**Problem**: Same information in multiple files
**Why bad**: Inconsistency, maintenance burden
**Solution**: Single source of truth, cross-reference

### Orphaned Files

**Problem**: Context file not referenced by any agent or index
**Why bad**: Dead code, wasted space, risk of staleness
**Solution**: Remove or document purpose; update index

### Missing Index Updates

**Problem**: New files created but not added to index
**Why bad**: Files not discoverable, lazy loading broken
**Solution**: Always update index.json when adding files

### Breaking Changes Without Updates

**Problem**: Context file changed but dependent agents not updated
**Why bad**: Agents fail or behave incorrectly
**Solution**: Update all dependent agents atomically

---

## Metrics and Monitoring

| Metric | Ideal | Warning | Action |
|--------|-------|---------|--------|
| File size | 50-200 lines | >200 lines | Split file |
| Context per agent | <40KB | >40KB | Review required vs. optional |
| File cohesion | Single topic | Multiple unrelated topics | Split file |
| Index accuracy | 100% files indexed | Missing entries | Update index |

---

## Summary

**Key Principles**:
1. Keep files focused (50-200 lines)
2. Update in place when possible
3. Create new files for new concepts
4. Split files that exceed 200 lines
5. Always update context index with correct line_count
6. Sync deployed and extension source copies

**Decision Tree**:
```
Change needed?
+-- Fits in existing file (<200 lines)? -> Update in place
+-- New concept? -> Create new file
+-- File >200 lines? -> Split file
+-- Breaking change? -> Update all dependent agents
```

**Remember**: Context files are living documentation. Keep them focused, current, and discoverable.
