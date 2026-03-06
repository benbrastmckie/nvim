# Research Report: Comparing /todo Command Implementations (OC_150)

**Date:** 2026-03-06  
**Task:** OC_150 - Fix /todo orphan detection for completed tasks not in state.json  
**Focus:** Compare .claude/ and .opencode/ /todo implementations for inspiration

---

## Executive Summary

This research compares the `/todo` command implementations in `.claude/` and `.opencode/` directories. While the `.claude/` version is simpler and more straightforward, the `.opencode/` version adds sophisticated features like memory harvesting and CHANGE_LOG.md updates. The key insight for OC_150 is understanding how the `.claude/` version handles TODO.md scanning (Step 2.5) and cross-referencing, which provides a pattern for fixing the orphan detection gap in the `.opencode/` version.

---

## .claude/ /todo Implementation Analysis

### Architecture

The `.claude/` version is a **self-contained command** (1199 lines) that embeds all logic directly without skill delegation:

```
/todo command → Direct execution (no skill layer)
```

### Key Workflow Steps

**Step 2: Scan for Archivable Tasks**
- Reads `specs/state.json` for completed/abandoned tasks
- Reads `specs/TODO.md` and **cross-references** entries
- This dual-source scanning is the key pattern for OC_150

**Step 2.5: Detect Orphaned Directories (CRITICAL)**
The `.claude/` version has a dedicated orphan detection phase:

```bash
# Orphan detection in specs/
for dir in specs/[0-9]*_*/; do
  project_num=$(basename "$dir" | cut -d_ -f1)
  
  # Check state.json
  in_active=$(jq -r --arg n "$project_num" \
    '.active_projects[] | select(.project_number == ($n | tonumber)) | .project_number' \
    specs/state.json 2>/dev/null)
  
  # Check archive/state.json
  in_archive=$(jq -r --arg n "$project_num" \
    '.completed_projects[] | select(.project_number == ($n | tonumber)) | .project_number' \
    specs/archive/state.json 2>/dev/null)
  
  # ORPHAN if not in either
  if [ -z "$in_active" ] && [ -z "$in_archive" ]; then
    orphaned_in_specs+=("$dir")
  fi
done
```

**Step 2.6: Detect Misplaced Directories**
- Directories in `specs/` that ARE tracked in `archive/state.json`
- Already have correct state entries, just need physical move

### Handling of TODO.md Cross-Reference

The `.claude/` version **explicitly** scans TODO.md:

```markdown
### 2. Scan for Archivable Tasks

Read specs/state.json and identify:
- Tasks with status = "completed"
- Tasks with status = "abandoned"

Read specs/TODO.md and cross-reference:
- Entries marked [COMPLETED]
- Entries marked [ABANDONED]
```

However, this cross-reference appears to be for **validation** rather than **orphan detection**. The actual orphan detection happens via filesystem scanning (Step 2.5), not TODO.md parsing.

### Orphan Categories

The `.claude/` version defines 4 clear categories:

| Category | Location | In state.json? | In archive/state.json? | Action |
|----------|----------|----------------|------------------------|--------|
| Active | specs/ | Yes | No | Normal |
| **Orphaned in specs/** | specs/ | No | No | Move + add state entry |
| **Orphaned in archive/** | archive/ | No | No | Add state entry only |
| **Misplaced** | specs/ | No | Yes | Move only |
| Archived | archive/ | No | Yes | Normal |

### Roadmap Integration

**Step 3.5: Scan Roadmap for Task References**
- Uses structured matching (roadmap_items field)
- Falls back to exact `(Task {N})` matching
- **Excludes meta tasks** from ROAD_MAP.md matching (they use claudemd_suggestions)

### CLAUDE.md Suggestions

**Step 3.6: Scan Meta Tasks for CLAUDE.md Suggestions**
- Meta tasks use `claudemd_suggestions` field instead of roadmap
- Actions: add, update, remove, none
- Interactive selection via AskUserQuestion

### Repository Metrics Sync

**Step 5.7: Sync Repository Metrics**
- Updates `repository_health` in state.json
- Updates TODO.md frontmatter technical_debt section
- Counts TODO/FIXME markers in codebase

---

## .opencode/ /todo Implementation Analysis

### Architecture

The `.opencode/` version uses a **command → skill delegation** pattern (139 lines command + ~500 line skill):

```
/todo command → skill-todo → Execution
```

### Key Features (Not in .claude/)

1. **Automatic CHANGE_LOG.md Updates**
   - Creates changelog entries for each archived task
   - Includes status, type, summary, artifacts list

2. **Memory Harvest Suggestions**
   - Scans task artifacts for valuable knowledge
   - 5-category classification: TECHNIQUE, PATTERN, CONFIG, WORKFLOW, INSIGHT
   - Interactive checkbox selection
   - Creates memory files in `.opencode/memory/10-Memories/`

3. **README.md Suggestions**
   - For meta tasks, applies readme_suggestions
   - Updates `.opencode/README.md`

### Current Limitation (The Bug)

The `.opencode/` version's skill-todo **only scans state.json** for archivable tasks. It does NOT:
- Scan TODO.md for completed/abandoned entries
- Cross-reference TODO.md entries with state.json
- Identify orphans that exist in TODO.md but not in state.json

This creates the gap where tasks like OC_138, OC_139, OC_140 are stranded.

---

## Comparison Matrix

| Feature | .claude/ | .opencode/ | Notes |
|---------|----------|------------|-------|
| **Architecture** | Self-contained command | Command → Skill | .opencode/ is more modular |
| **Orphan Detection** | ✅ Filesystem-based | ❌ Missing | .claude/ scans directories |
| **TODO.md Cross-Ref** | ✅ Validation | ❌ Not implemented | .claude/ mentions but minimal |
| **Memory Harvest** | ❌ Not present | ✅ Full implementation | .opencode/ innovation |
| **CHANGE_LOG.md** | ❌ Not present | ✅ Auto-updates | .opencode/ innovation |
| **Roadmap Updates** | ✅ Structured matching | ✅ Likely similar | Both have this |
| **CLAUDE.md/README Suggestions** | ✅ claudemd_suggestions | ✅ readme_suggestions | Different naming |
| **Metrics Sync** | ✅ repository_health | ❌ Unknown | .claude/ feature |
| **Misplaced Detection** | ✅ Step 2.6 | ❌ Unknown | .claude/ feature |

---

## Key Insights for OC_150

### 1. Orphan Detection Strategy

The `.claude/` version uses **filesystem-first detection**:
1. Scan `specs/` for directories
2. Check if tracked in state.json
3. Check if tracked in archive/state.json
4. If untracked anywhere → orphan

For OC_150, we need **TODO.md-first detection**:
1. Scan TODO.md for [COMPLETED]/[ABANDONED] entries
2. Extract project_number from headers
3. Check if in state.json active_projects
4. If NOT in state.json → TODO.md orphan

### 2. Implementation Pattern

**From .claude/ Step 2.5:**
```bash
# Pattern: Loop directories, check state files
for dir in specs/[0-9]*_*/; do
  project_num=$(basename "$dir" | cut -d_ -f1)
  in_active=$(jq ... state.json)
  in_archive=$(jq ... archive/state.json)
  if [ -z "$in_active" ] && [ -z "$in_archive" ]; then
    orphaned_in_specs+=("$dir")
  fi
done
```

**Adapted for OC_150:**
```bash
# Pattern: Parse TODO.md, check state.json
for task_entry in $(extract_from_todo_md "### OC_[0-9]+"); do
  project_num=$(extract_number "$task_entry")
  status=$(extract_status "$task_entry")  # COMPLETED or ABANDONED
  
  in_active=$(jq ... state.json)
  
  # OC_150: If completed/abandoned in TODO.md but NOT in state.json
  if [ -z "$in_active" ] && [[ "$status" =~ ^(COMPLETED|ABANDONED)$ ]]; then
    todo_md_orphans+=("$project_num")
  fi
done
```

### 3. Cross-Referencing Logic

The `.claude/` version cross-references in Step 2:
```markdown
Read specs/state.json and identify:
- Tasks with status = "completed"
- Tasks with status = "abandoned"

Read specs/TODO.md and cross-reference:
- Entries marked [COMPLETED]
- Entries marked [ABANDONED]
```

This suggests the fix for OC_150 should:
1. Parse TODO.md headers to extract task numbers
2. Check if those tasks exist in state.json
3. Identify mismatches (in TODO.md but not state.json)
4. Treat mismatches as orphans for archival

### 4. State Management

Both versions update similar files:
- `specs/state.json` (remove from active)
- `specs/archive/state.json` (add to completed)
- `specs/TODO.md` (remove entries)

The `.opencode/` version also updates:
- `specs/CHANGE_LOG.md`
- `.opencode/memory/` files
- `.opencode/README.md`

### 5. Validation Approach

The `.claude/` version emphasizes validation at each step:
- Check both state files for orphan detection
- Verify directory existence before moves
- Skip already-annotated roadmap items

For OC_150, we should:
- Verify task exists in TODO.md with completed/abandoned status
- Verify task directory exists in specs/
- Verify task is NOT in state.json
- Then proceed with archival

---

## Recommendations for OC_150 Fix

### Stage 3 Enhancement (skill-todo/SKILL.md)

**Add Step 3.2 - Scan TODO.md for Orphans:**

```markdown
**Step 3.2 - Extract Completed/Abandoned from TODO.md:**

1. Read specs/TODO.md content
2. Parse task entries with regex pattern: `### (OC_)?([0-9]+)\. `
3. For each task found:
   - Extract project_number
   - Extract status from `- **Status**: \[(COMPLETED|ABANDONED)\]`
4. For each completed/abandoned task:
   - Check if project_number exists in state.json active_projects
   - If NOT found → add to `todo_md_orphans` array
5. Cross-reference with filesystem:
   - Verify directory exists in specs/ or specs/archive/
   - Track orphans with/without directories separately
```

### Stage 9 Enhancement

**Add Step 9.1 - Present TODO.md Orphans:**

```markdown
If todo_md_orphans found:
- Display: "Found {N} completed/abandoned tasks in TODO.md not tracked in state.json:"
- List each with: task number, status, directory location
- AskUserQuestion: "Archive these TODO.md orphans?"
  - Options: "Archive all", "Review list first", "Skip orphans"
```

### Stage 10 Enhancement

**Add Step 10.2 - Archive TODO.md Orphans:**

```markdown
For each orphan in todo_md_orphans:
- Create archive entry (similar to regular tasks)
- Move directory to specs/archive/ (if in specs/)
- Update specs/archive/state.json
- Track for CHANGE_LOG.md
- Update TODO.md (remove entry)
```

---

## Files to Reference

### .claude/ Implementation
- `.claude/commands/todo.md` - Full self-contained implementation (1199 lines)
  - Steps 2, 2.5, 2.6: Scanning and orphan detection
  - Steps 3.5, 3.6: Roadmap and CLAUDE.md suggestions
  - Step 5.7: Repository metrics sync

### .opencode/ Implementation
- `.opencode/commands/todo.md` - Delegation layer (139 lines)
- `.opencode/skills/skill-todo/SKILL.md` - Core execution logic
  - Stage 3: ScanTasks (needs TODO.md scanning)
  - Stage 9: InteractivePrompts (needs orphan prompts)
  - Stage 10: ArchiveTasks (needs TODO.md orphan handling)
  - Stage 11: UpdateTODO (ensure entries removed)

---

## Success Criteria for OC_150

- [ ] OC_138, OC_139, OC_140 properly detected as TODO.md orphans
- [ ] User prompted to archive these orphans
- [ ] Directories moved to specs/archive/
- [ ] Entries removed from TODO.md
- [ ] Entries added to specs/archive/state.json
- [ ] CHANGE_LOG.md updated with orphan archival entries
- [ ] Git commit includes all changes

---

## Notes

### Why .claude/ Approach Works

The `.claude/` version's filesystem-first approach catches all orphans because:
1. Directories are physical artifacts that can't be "forgotten" like state.json entries
2. Scanning `specs/[0-9]*_*/` finds all task directories regardless of state
3. Cross-referencing with state files identifies tracking gaps

### Why .opencode/ Gap Exists

The `.opencode/` version trusts state.json as the single source of truth:
1. Only scans state.json for completed/abandoned tasks
2. Assumes TODO.md and state.json are synchronized
3. When tasks are manually removed from state.json, they become invisible

### Best Practice Hybrid

Combine the best of both:
1. **Filesystem scanning** (.claude/ pattern) - catches true orphans
2. **TODO.md scanning** (OC_150 addition) - catches tracking gaps
3. **Memory harvesting** (.opencode/ innovation) - preserves knowledge
4. **CHANGE_LOG.md** (.opencode/ innovation) - maintains audit trail

---

**Report created:** 2026-03-06  
**Next step:** Create implementation plan for skill-todo updates
