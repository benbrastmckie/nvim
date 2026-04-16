# Documentation Audit: Post-Task 428 Stale References

**Task**: 429
**Date**: 2026-04-14
**Scope**: `.claude/docs/` and `.claude/README.md`

---

## Summary

Task 428 performed five major changes (backup deprecation, spreadsheet agent split, batch dispatch removal, manifest schema update, model enforcement). This audit identified 6 documentation issues across 5 files that were not updated to reflect those changes.

---

## Issues

### Issue 1: Stale backup system documentation (HIGH)

**File**: `docs/architecture/extension-system.md:380-382`
**Section**: Error Handling > Backup System

**Current text**:
> Before modifying shared files (CLAUDE.md, index.json, settings.json):
> - Original file is backed up to `{filename}.backup`
> - If modification fails, backup is restored

**Problem**: Task 428 deprecated the `.backup` mechanism. The `/refresh` skill now cleans stale backup files. `rules/state-management.md` was updated to say "Use git for recovery."

**Fix**: Replace the Backup System subsection with git-based recovery language. Example:
```markdown
### Recovery
If modification of shared files fails, use git to restore the previous version:
- `git checkout HEAD -- .claude/{file}` to recover any overwritten file
```

---

### Issue 2: Manifest example uses `"language"` instead of `"task_type"` (HIGH)

**Files**:
- `docs/architecture/extension-system.md:111` -- `"language": "latex"`
- `docs/guides/creating-extensions.md:55` -- `"language": "your-domain"`
- `docs/guides/adding-domains.md:77` -- `"language": "your-domain"`

**Problem**: Actual manifests now use `"task_type"` (singular string). The field table at `extension-system.md:144` already says `task_type` but the JSON examples above it still say `"language"`.

**Fix**: Replace `"language":` with `"task_type":` in all three manifest JSON examples.

---

### Issue 3: Manifest examples missing `routing` object (HIGH)

**Files**:
- `docs/architecture/extension-system.md:106-135` -- manifest JSON example
- `docs/guides/creating-extensions.md:50-89` -- manifest template

**Problem**: Actual manifests now include a `routing` object:
```json
"routing": {
  "research": { "latex": "skill-latex-research" },
  "plan": { "latex": "skill-planner" },
  "implement": { "latex": "skill-latex-implementation" }
}
```
The documentation examples omit this entirely.

**Fix**: Add `routing` object to manifest JSON examples in both files, after `provides`.

---

### Issue 4: Stale `spreadsheet-agent` / `skill-spreadsheet` reference (MEDIUM)

**File**: `docs/reference/standards/extension-slim-standard.md:106`

**Current text**:
```
| skill-spreadsheet | spreadsheet-agent | Spreadsheet to LaTeX/Typst |
```

**Problem**: Task 428 split `spreadsheet-agent` into `filetypes-spreadsheet-agent` and `founder-spreadsheet-agent`. The corresponding skills are `skill-filetypes-spreadsheet` and `skill-founder-spreadsheet`.

**Fix**: Update the example table row to:
```
| skill-filetypes-spreadsheet | filetypes-spreadsheet-agent | Spreadsheet to LaTeX/Typst |
```

---

### Issue 5: Stale `"language"` in `adding-domains.md` manifest (MEDIUM)

**File**: `docs/guides/adding-domains.md:77`

**Current text**: `"language": "your-domain"`

**Fix**: Change to `"task_type": "your-domain"` and add `routing` object to the example.

(Grouped with Issue 2 for implementation but listed separately for traceability since it's a different guide.)

---

### Issue 6: Agent frontmatter example inconsistency (LOW)

**File**: `docs/reference/standards/agent-frontmatter-standard.md:105-110`

**Current example**:
```yaml
name: neovim-implementation-agent
description: Implement Neovim configuration changes from plans
model: sonnet
```

**Problem**: Task 428 added `model: opus` to `general-implementation-agent` and `meta-builder-agent`. The standard's example and "Usage Guidelines" suggest `sonnet` for implementation agents, which is now inconsistent with practice.

**Fix options** (choose one):
- **Option A**: Update example to `model: opus` and revise guidelines to note implementation agents may use opus for complex tasks
- **Option B**: Keep as-is and add a note that actual agent model choices may vary from these guidelines
- **Option C**: Change example to use a different agent (e.g., a hypothetical lightweight agent) where sonnet is appropriate

**Recommendation**: Option A -- the standard should reflect actual practice.

---

## Files to Modify (Implementation Checklist)

| # | File | Changes |
|---|------|---------|
| 1 | `docs/architecture/extension-system.md` | Fix backup section (Issue 1), fix manifest example (Issues 2, 3) |
| 2 | `docs/guides/creating-extensions.md` | Fix manifest template (Issues 2, 3) |
| 3 | `docs/guides/adding-domains.md` | Fix manifest example (Issues 2, 5) |
| 4 | `docs/reference/standards/extension-slim-standard.md` | Fix spreadsheet agent names (Issue 4) |
| 5 | `docs/reference/standards/agent-frontmatter-standard.md` | Fix implementation agent example (Issue 6) |

## Files Verified Clean

- `.claude/README.md` -- No stale references
- `.claude/CLAUDE.md` -- Already updated by task 428
- `docs/README.md` -- Pure index, unaffected
- `docs/guides/creating-commands.md` -- Unaffected
- `docs/guides/creating-skills.md` -- Generic examples, unaffected
- `docs/guides/creating-agents.md` -- Generic examples, unaffected
- `docs/architecture/system-overview.md` -- Unaffected (stale Last Verified date predates 428)
- `docs/reference/standards/multi-task-creation-standard.md` -- Unaffected
