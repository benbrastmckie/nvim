# Context File Revision Guide for Meta Agents

**Version**: 1.0  
**Last Updated**: 2026-01-08  
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

**Example**: Adding a new routing pattern to `core/orchestration/routing.md`

### Create New File

Create a new context file when:
- New domain pattern discovered (e.g., formal verification domain)
- New standard introduced (e.g., new artifact type)
- Existing file would exceed 200 lines with addition
- Concept is orthogonal to existing files
- Topic deserves dedicated focus

**Example**: Creating `project/lean/proof-automation-patterns.md` for Lean-specific patterns

### Split Existing File

Split an existing file when:
- File exceeds 200 lines
- File covers multiple distinct concepts
- File has low cohesion (unrelated sections)
- Natural boundaries exist between sections

**Example**: Splitting `core/orchestration/delegation.md` into `delegation-basics.md` and `delegation-patterns.md`

---

## How to Revise Without Bloat

### File Size Limits

- **Target**: 50-200 lines per file
- **Warning**: 200-250 lines (consider splitting)
- **Error**: >250 lines (must split)

### Revision Checklist

1. **Read existing file completely**
   - Understand current structure and content
   - Identify section to update

2. **Check if change fits within 200-line limit**
   - Count current lines
   - Estimate lines to add
   - Calculate total

3. **If yes: Update in place**
   - Make targeted changes
   - Preserve existing structure
   - Update version/date

4. **If no: Split file or create new file**
   - Identify natural boundaries
   - Create new file(s)
   - Update references

5. **Update context index**
   - Add new files to index
   - Update descriptions
   - Maintain organization

6. **Update dependent agents**
   - Find agents loading this file
   - Update context_loading sections
   - Test context loading

---

## Context File Types and Revision Patterns

### Core Standards (`.opencode/context/core/standards/`)

**When to revise**: System-wide standard changes  
**Examples**: `xml-structure.md`, `documentation.md`, `task-management.md`  
**Revision pattern**: Update in place (rarely changes)  
**Frequency**: Low (quarterly or less)

### Core Templates (`.opencode/context/core/templates/`)

**When to revise**: Template structure changes  
**Examples**: `agent-template.md`, `command-template.md`, `subagent-template.md`  
**Revision pattern**: Update in place, add version notes  
**Frequency**: Medium (monthly)

### Core Workflows (`.opencode/context/core/workflows/`)

**When to revise**: Workflow pattern changes  
**Examples**: `command-lifecycle.md`, `status-transitions.md`, `preflight-postflight.md`  
**Revision pattern**: Update in place, document changes  
**Frequency**: Medium (monthly)

### Project Meta (`.opencode/context/project/meta/`)

**When to revise**: Meta-system patterns evolve  
**Examples**: `architecture-principles.md`, `domain-patterns.md`, `interview-patterns.md`  
**Revision pattern**: Update frequently, split if >200 lines  
**Frequency**: High (weekly)

### Project Domain (`.opencode/context/project/{domain}/`)

**When to revise**: Domain knowledge expands  
**Examples**: `proof-theory-concepts.md`, `kripke-semantics-overview.md`  
**Revision pattern**: Create new files for new concepts  
**Frequency**: High (per-task)

---

## Revision Workflow

### Stage 1: Assess Impact

1. **Identify affected files**
   - Which context files need changes?
   - Are changes breaking or additive?

2. **Count dependent agents**
   - How many agents load these files?
   - Which agents are affected?

3. **Determine change type**
   - Update existing content?
   - Add new content?
   - Remove obsolete content?

### Stage 2: Plan Revision

1. **Choose revision strategy**
   - Update in place?
   - Create new file?
   - Split existing file?

2. **Check file size constraints**
   - Current line count
   - Estimated new line count
   - Within 200-line limit?

3. **Identify agent updates needed**
   - Which agents need context_loading updates?
   - Are there breaking changes?

### Stage 3: Execute Revision

1. **Update/create context files**
   - Make targeted changes
   - Follow file size limits
   - Update version/date

2. **Update context index**
   - Add new files
   - Update descriptions
   - Maintain organization

3. **Update agent context_loading sections**
   - Add new required files
   - Move to optional if appropriate
   - Remove obsolete files

4. **Test affected agents**
   - Verify context loads correctly
   - Check for errors
   - Validate behavior

### Stage 4: Validate

1. **Check file sizes**
   - All files within limits?
   - No files >200 lines?

2. **Verify context index**
   - All files listed?
   - Descriptions accurate?
   - Organization logical?

3. **Test agent context loading**
   - Agents load correct files?
   - No broken references?
   - Context usage reasonable?

4. **Check for duplication**
   - No duplicate content across files?
   - Clear boundaries between files?

---

## Common Revision Scenarios

### Scenario 1: New Pattern Discovered

**Situation**: Agent-generator discovers new delegation pattern  
**Action**: Update `core/orchestration/delegation.md`  
**Steps**:
1. Read delegation.md (currently 180 lines)
2. Add new pattern section (20 lines)
3. Total: 200 lines (within limit)
4. Update version/date
5. No agent updates needed (already loaded)

### Scenario 2: File Exceeds Limit

**Situation**: `core/standards/task-management.md` grows to 220 lines  
**Action**: Split into two files  
**Steps**:
1. Identify natural boundary (e.g., task creation vs. task updates)
2. Create `task-creation.md` (100 lines)
3. Create `task-updates.md` (120 lines)
4. Update context index
5. Update agents loading task-management.md to load both files

### Scenario 3: New Domain Added

**Situation**: Adding formal verification domain  
**Action**: Create new domain directory  
**Steps**:
1. Create `.opencode/context/project/formal-verification/`
2. Create domain-specific files (e.g., `proof-strategies.md`)
3. Update context index
4. Update relevant agents to load new files

### Scenario 4: Standard Evolves

**Situation**: New frontmatter field required for all agents  
**Action**: Update `core/standards/xml-structure.md`  
**Steps**:
1. Read xml-structure.md
2. Add new field documentation
3. Update examples
4. Update version/date
5. No agent updates needed (standard applies to all)

---

## Anti-Patterns to Avoid

### ❌ Bloated Files

**Problem**: Single file grows to 500+ lines  
**Why bad**: Hard to navigate, slow to load, low cohesion  
**Solution**: Split into focused files (50-200 lines each)

### ❌ Duplicate Content

**Problem**: Same information in multiple files  
**Why bad**: Inconsistency, maintenance burden  
**Solution**: Single source of truth, cross-reference

### ❌ Orphaned Files

**Problem**: Context file not referenced by any agent  
**Why bad**: Dead code, wasted space  
**Solution**: Remove or document purpose

### ❌ Missing Index Updates

**Problem**: New files created but not added to index  
**Why bad**: Files not discoverable, lazy loading broken  
**Solution**: Always update index when adding files

### ❌ Breaking Changes Without Updates

**Problem**: Context file changed but dependent agents not updated  
**Why bad**: Agents fail or behave incorrectly  
**Solution**: Update all dependent agents atomically

---

## Metrics and Monitoring

### File Size Distribution

- **Ideal**: 80% of files between 50-200 lines
- **Warning**: >10% of files >200 lines
- **Action**: Review and split large files

### Context Loading Efficiency

- **Ideal**: <40KB per agent
- **Warning**: >40KB per agent
- **Action**: Review required vs. optional files

### File Cohesion

- **Ideal**: Each file covers single topic
- **Warning**: File covers multiple unrelated topics
- **Action**: Split into focused files

---

## Summary

**Key Principles**:
1. Keep files focused (50-200 lines)
2. Update in place when possible
3. Create new files for new concepts
4. Split files that exceed 200 lines
5. Always update context index
6. Update dependent agents atomically

**Decision Tree**:
```
Change needed?
├─ Fits in existing file (<200 lines)? → Update in place
├─ New concept? → Create new file
├─ File >200 lines? → Split file
└─ Breaking change? → Update all dependent agents
```

**Remember**: Context files are living documentation. Keep them focused, current, and discoverable.
