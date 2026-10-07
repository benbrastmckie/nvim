# Todo Archival Reference

This file holds the archival-status definitions, orphan and misplaced-directory categories,
completion-summary authoring guidance, and jq/shell escaping rules that `/todo`
(`commands/todo.md`) depends on. It was extracted verbatim from that command body's former
`## Notes` section. `/todo`'s Steps 2.5, 2.6, and 3 each depend on one or more subsections
below — read the relevant subsection before executing those steps.

## Task Archival
- Archivable statuses are exactly `completed`, `abandoned`, and `expanded` — these are the
  terminal states defined in `context/standards/status-markers.md`'s Validation Rules section.
  `partial` and `blocked` are NOT archivable: they are non-terminal, resumable states, and any
  command may pick a task back up from them.
- `completed` and `expanded` tasks route to archive/state.json's `completed_projects` array;
  `abandoned` tasks route to `archived_projects`. There is no third array for `expanded`.
- **Subtasks-defer guard**: an expanded parent waits to be archived until every task in its
  `subtasks[]` reaches a terminal status, so a subtask still being worked can read its parent's
  artifacts in place. A missing/empty `subtasks[]`, or a subtask no longer in `active_projects`
  (already archived), is never treated as blocking. This guard addresses only the parent/child
  case — general cross-task artifact citations remain a known, pre-existing limitation of
  archival (a plain directory `mv`, plus vault renumbering, can still break a citation from one
  archived task's artifacts into another's).
- Artifacts (plans, reports, summaries) are preserved in archive/{NNN}_{SLUG}/
- Tasks can be recovered with `/task --recover N`
- Archive is append-only (for audit trail)
- Run periodically to keep TODO.md and specs/ manageable

## Orphan Tracking

**Orphan Categories**:
1. **Orphaned in specs/** - Directories in `specs/` not tracked in any state file
   - Action: Move to archive/ AND add entry to archive/state.json
2. **Orphaned in archive/** - Directories in `specs/archive/` not tracked in archive/state.json
   - Action: Add entry to archive/state.json (no move needed)

**orphan_archived Status**:
- Orphaned directories receive status `"orphan_archived"` in archive/state.json
- The `source` field is set to `"orphan_recovery"` to distinguish from normal archival
- The `detected_artifacts` field lists any existing subdirectories (reports/, plans/, summaries/)

**Recovery**:
- Orphaned directories with state entries can be inspected in archive/
- Manual recovery is possible by moving directories and updating state files
- Use `/task --recover N` only for tracked tasks (not orphans)

## Misplaced Directories

**Definition**: Directories in `specs/` that ARE tracked in `archive/state.json`.

This indicates the directory was archived in state but never physically moved.

**Directory Categories Summary**:

| Category | Location | Tracked in state.json? | Tracked in archive/state.json? | Action |
|----------|----------|------------------------|--------------------------------|--------|
| Active | specs/ | Yes | No | Normal (no action) |
| Orphaned in specs/ | specs/ | No | No | Move + add state entry |
| Orphaned in archive/ | archive/ | No | No | Add state entry only |
| Misplaced | specs/ | No | Yes | Move only (state correct) |
| Archived | archive/ | No | Yes | Normal (no action) |

**Misplaced Directories**:
- Already have correct state entries in archive/state.json
- Only need to be physically moved to specs/archive/
- No state updates required

**Causes of Misplaced Directories**:
- Directory move failed silently during previous archival
- Manual state edits without corresponding directory moves
- System interrupted during archival process
- /todo command Step 5D not executing consistently

**Recovery**:
- Use `/task --recover N` to recover misplaced directories (they have valid state entries)
- After moving, the directory will be in the correct location matching its state

## Completion Summary Guidance

`/implement` populates `completion_summary` (and, optionally, `roadmap_items`) on task
completion; `/todo` consumes `completion_summary` when generating `specs/CHANGE_LOG.md` entries
for archived tasks.

**Well-Formed Completion Summaries**:

Good examples:
- "Implemented structured synchronization between task completion data and roadmap updates. Added completion_summary field to task schema."
- "Fixed modal logic proof for reflexive frames. Added missing transitivity lemma and updated test cases."
- "Created LaTeX documentation for Logos layer architecture with diagrams and examples."

The summary should:
- Be 1-3 sentences describing what was accomplished
- Focus on outcomes, not process
- Be specific enough to be useful in the CHANGE_LOG entry

## jq Pattern Safety (Issue #1132)

**Problem**: Claude Code Issue #1132 causes jq commands with `!=` operators to fail with `INVALID_CHARACTER` or syntax errors when Claude generates them inline.

**Solution**: This command uses safe jq patterns throughout:

1. **File-based filters** for `!=` operators:
   ```bash
   # Instead of: jq 'select(.task_type != "meta")' file
   cat > specs/tmp/filter_$$.jq << 'EOF'
   select(.task_type != "meta")
   EOF
   jq -f specs/tmp/filter_$$.jq file && rm -f specs/tmp/filter_$$.jq
   ```

2. **`has()` for null checks**:
   ```bash
   # Instead of: jq 'select(.field != null)'
   jq 'select(has("field"))'
   ```

3. **`del()` for exclusion filters**:
   ```bash
   # Instead of: jq '.array |= map(select(.status != "completed"))'
   jq 'del(.array[] | select(.status == "completed"))'
   ```

**Reference**: See `.claude/context/patterns/jq-escaping-workarounds.md` for comprehensive patterns.
