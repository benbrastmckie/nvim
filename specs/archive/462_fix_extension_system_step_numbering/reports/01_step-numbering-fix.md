# Research Report: Task #462

**Task**: 462 - Fix extension system step numbering
**Started**: 2026-04-16T00:00:00Z
**Completed**: 2026-04-16T00:01:00Z
**Effort**: trivial
**Dependencies**: None
**Sources/Inputs**:
- `.claude/docs/architecture/extension-system.md` (nvim, lines 229-284)
- `~/.config/zed/.claude/docs/architecture/extension-system.md` (reference fix, lines 229-284)
**Artifacts**:
- `specs/462_fix_extension_system_step_numbering/reports/01_step-numbering-fix.md`
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- The Load/Unload Process section in `.claude/docs/architecture/extension-system.md` has duplicate step numbers caused by inserting dependency resolution steps without renumbering.
- The **load flow** has two steps numbered `3` (lines 240-241): "Check for conflicts" and "Copy files".
- The **unload flow** has two steps numbered `3` (lines 278-280): "Remove merged content" and "Remove files".
- The reference fix in `~/.config/zed/.claude/docs/architecture/extension-system.md` confirms the correct renumbering.
- Fix is mechanical: renumber steps sequentially after the inserted dependency steps.

## Context & Scope

When dependency resolution steps (step 2 in both load and unload flows) were added, subsequent steps were not renumbered, creating duplicate step 3 entries in both flows. This is a documentation-only fix with no code impact.

## Findings

### Load Flow -- Current (broken)

```
1. Read manifest.json
2. Resolve dependencies: ...
3. Check for conflicts (check_conflicts)       <-- FIRST step 3
3. Copy files: ...                              <-- DUPLICATE step 3
4. Pre-load index cleanup: ...
5. Load core index entries: ...
6. Merge shared files: ...
7. Update state (mark_loaded)
8. Write extensions.json
9. Post-load verification
```

### Load Flow -- Correct (after fix)

```
1. Read manifest.json
2. Resolve dependencies: ...
3. Check for conflicts (check_conflicts)
4. Copy files: ...
5. Pre-load index cleanup: ...
6. Load core index entries: ...
7. Merge shared files: ...
8. Update state (mark_loaded)
9. Write extensions.json
10. Post-load verification
```

### Unload Flow -- Current (broken)

```
1. Read state (get extension info)
2. Check reverse dependencies: ...
3. Remove merged content: ...                   <-- FIRST step 3
3. Remove files: ...                            <-- DUPLICATE step 3
4. Update state (mark_unloaded)
5. Write extensions.json
```

### Unload Flow -- Correct (after fix)

```
1. Read state (get extension info)
2. Check reverse dependencies: ...
3. Remove merged content: ...
4. Remove files: ...
5. Update state (mark_unloaded)
6. Write extensions.json
```

### Exact Lines to Change

**File**: `.claude/docs/architecture/extension-system.md`

**Load flow** (lines 241-265):
| Line | Current | Corrected |
|------|---------|-----------|
| 241 | `3. Copy files:` | `4. Copy files:` |
| 249 | `4. Pre-load index cleanup:` | `5. Pre-load index cleanup:` |
| 256 | `5. Load core index entries:` | `6. Load core index entries:` |
| 259 | `6. Merge shared files:` | `7. Merge shared files:` |
| 263 | `7. Update state (mark_loaded)` | `8. Update state (mark_loaded)` |
| 264 | `8. Write extensions.json` | `9. Write extensions.json` |
| 265 | `9. Post-load verification` | `10. Post-load verification` |

**Unload flow** (lines 280-282):
| Line | Current | Corrected |
|------|---------|-----------|
| 280 | `3. Remove files:` | `4. Remove files:` |
| 281 | `4. Update state (mark_unloaded)` | `5. Update state (mark_unloaded)` |
| 282 | `5. Write extensions.json` | `6. Write extensions.json` |

## Decisions

- Use the Zed repository's already-fixed version as the authoritative reference for correct numbering.

## Risks & Mitigations

- **Risk**: None. This is a documentation-only change with no behavioral impact.

## Appendix

- Reference fix: `~/.config/zed/.claude/docs/architecture/extension-system.md` (task 74)
- Both load and unload flows confirmed to match after applying the renumbering.
