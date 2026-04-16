# Research Report: Task #429

**Task**: 429 - Update docs for task 428 changes
**Started**: 2026-04-14T00:00:00Z
**Completed**: 2026-04-14T00:15:00Z
**Effort**: small
**Dependencies**: Task 428 (completed)
**Sources/Inputs**:
- Existing audit report: `specs/429_update_docs_for_task_428_changes/reports/01_docs-audit.md`
- Codebase: `.claude/docs/`, `.claude/extensions/`, `.claude/agents/`
- Actual manifests: `latex/manifest.json`, `filetypes/manifest.json`
- Actual agents: `general-implementation-agent.md`, `meta-builder-agent.md`
**Artifacts**: - `specs/429_update_docs_for_task_428_changes/reports/02_docs-update-research.md`
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- All 6 issues from the initial audit (01_docs-audit.md) are confirmed with exact line numbers and verbatim text
- 4 additional stale references were discovered that the audit missed, bringing the total to 10 distinct issues across 7 files
- The newly found issues are: `"language": "rust"` in delegation context examples in creating-skills.md and creating-agents.md, `language: your-domain` in the architecture diagram in adding-domains.md, and `language: latex` in prose text in extension-system.md line 299
- All fixes are straightforward text replacements with no structural changes needed
- Directly supports ROADMAP Phase 1 item: "Zero stale references to removed/renamed files"

## Context & Scope

Task 428 made five major changes: (1) deprecated `.backup` recovery in favor of git, (2) split `spreadsheet-agent` into `filetypes-spreadsheet-agent` and `founder-spreadsheet-agent`, (3) removed `skill-batch-dispatch`, (4) renamed manifest field `"language"` to `"task_type"` and added `routing` object, (5) enforced `model: opus` on implementation and meta agents. This research verifies all documentation files in `.claude/docs/` and `.claude/README.md` for stale references.

## Findings

### Verified Audit Issues (6 original)

#### Issue 1: Stale backup system documentation -- CONFIRMED

**File**: `.claude/docs/architecture/extension-system.md`
**Lines**: 380-383

**Current text** (verbatim):
```
### Backup System
Before modifying shared files (CLAUDE.md, index.json, settings.json):
- Original file is backed up to `{filename}.backup`
- If modification fails, backup is restored
```

**Replacement text**:
```
### Recovery
If modification of shared files fails, use git to restore the previous version:
- `git checkout HEAD -- .claude/{file}` to recover any overwritten file
```

---

#### Issue 2: Manifest example uses `"language"` instead of `"task_type"` -- CONFIRMED

**File 1**: `.claude/docs/architecture/extension-system.md`, line 111
- **Current**: `  "language": "latex",`
- **Replace**: `  "task_type": "latex",`

**File 2**: `.claude/docs/guides/creating-extensions.md`, line 55
- **Current**: `  "language": "your-domain",`
- **Replace**: `  "task_type": "your-domain",`

**File 3**: `.claude/docs/guides/adding-domains.md`, line 77
- **Current**: `  "language": "your-domain",`
- **Replace**: `  "task_type": "your-domain",`

---

#### Issue 3: Manifest examples missing `routing` object -- CONFIRMED

**File 1**: `.claude/docs/architecture/extension-system.md`, lines 106-135
The manifest JSON example (lines 106-135) has no `routing` key. Insert after `"provides": { ... }` block (after line 121) and before `"merge_targets"`:

**Add** (based on actual latex manifest):
```json
  "routing": {
    "research": {
      "your-domain": "skill-your-domain-research"
    },
    "plan": {
      "your-domain": "skill-planner"
    },
    "implement": {
      "your-domain": "skill-your-domain-implementation"
    }
  },
```

Use `"latex"` keys for extension-system.md (since the example uses `"name": "latex"`), and `"your-domain"` keys for creating-extensions.md and adding-domains.md.

**File 2**: `.claude/docs/guides/creating-extensions.md`, lines 50-89
Same: no `routing` key. Insert after `"provides"` block (after line 75), before `"merge_targets"`.

**File 3**: `.claude/docs/guides/adding-domains.md`, lines 72-101
Same: no `routing` key. Insert after `"provides"` block (after line 87), before `"merge_targets"`.

---

#### Issue 4: Stale `spreadsheet-agent` / `skill-spreadsheet` in slim standard -- CONFIRMED

**File**: `.claude/docs/reference/standards/extension-slim-standard.md`, line 106

**Current** (verbatim):
```
| skill-spreadsheet | spreadsheet-agent | Spreadsheet to LaTeX/Typst |
```

**Replace with**:
```
| skill-filetypes-spreadsheet | filetypes-spreadsheet-agent | Spreadsheet to LaTeX/Typst |
```

**Note**: The filetypes EXTENSION.md itself (`extensions/filetypes/EXTENSION.md`, line 11) also still has `skill-spreadsheet | spreadsheet-agent`. That is outside the scope of this task (`.claude/docs/` only) but should be noted for a follow-up.

---

#### Issue 5: Stale `"language"` in adding-domains.md manifest -- CONFIRMED

Covered by Issue 2, File 3 above. Also confirmed that the adding-domains.md manifest example at lines 72-101 is missing the `routing` object (Issue 3, File 3).

---

#### Issue 6: Agent frontmatter example shows `model: sonnet` for implementation agent -- CONFIRMED

**File**: `.claude/docs/reference/standards/agent-frontmatter-standard.md`

**Location 1**: Lines 105-110 (Implementation Agent example)
**Current**:
```yaml
---
name: neovim-implementation-agent
description: Implement Neovim configuration changes from plans
model: sonnet
---
```

**Replace with**:
```yaml
---
name: general-implementation-agent
description: Implement general, meta, and markdown tasks from plans
model: opus
---
```

**Location 2**: Lines 57-60 (Usage Guidelines for `model: sonnet`)
**Current**:
```
**Use `model: sonnet` for**:
- Implementation agents with clear plans
- Routine code generation tasks
- Tasks where speed is prioritized over depth
```

**Replace with** (to reflect that implementation agents now use opus):
```
**Use `model: sonnet` for**:
- Team orchestration skills (lightweight coordination)
- Routine code generation tasks
- Tasks where speed is prioritized over depth
```

**Location 3**: Line 128 (Migration section)
**Current**: `2. Add `model: opus` or `model: sonnet` to frontmatter`
No change needed here -- this is generic migration guidance and both values remain valid.

---

### Newly Discovered Issues (4 additional)

#### Issue 7: `"language": "rust"` in creating-skills.md delegation context example

**File**: `.claude/docs/guides/creating-skills.md`, line 370

**Current** (within a JSON example of delegation context):
```json
    "language": "rust"
```

**Replace with**:
```json
    "task_type": "rust"
```

Also line 379 has `- Task context (number, name, description, language)` -- update to:
```
- Task context (number, name, description, task_type)
```

---

#### Issue 8: `"language": "rust"` in creating-agents.md delegation context example

**File**: `.claude/docs/guides/creating-agents.md`, line 276

**Current** (within a JSON example):
```json
    "language": "rust"
```

**Replace with**:
```json
    "task_type": "rust"
```

---

#### Issue 9: `language:` references in adding-domains.md architecture diagram and prose

**File**: `.claude/docs/guides/adding-domains.md`

**Location 1**: Lines 192-194 (architecture diagram)
**Current**:
```
    ├── language: your-domain → skill-your-domain-research / skill-your-domain-implementation
    ├── language: general    → skill-researcher / skill-implementer
    └── language: meta       → skill-researcher / skill-implementer
```

**Replace with**:
```
    ├── task_type: your-domain → skill-your-domain-research / skill-your-domain-implementation
    ├── task_type: general     → skill-researcher / skill-implementer
    └── task_type: meta        → skill-researcher / skill-implementer
```

**Location 2**: Line 197
**Current**: `Each language type routes to specialized skills, which delegate to specialized agents.`
**Replace**: `Each task type routes to specialized skills, which delegate to specialized agents.`

**Location 3**: Line 302
**Current**: `1. Validate task exists and language matches`
**Replace**: `1. Validate task exists and task_type matches`

**Location 4**: Line 431
**Current**: `- [ ] Test with `/task "Test" --language your-domain``
**Replace**: `- [ ] Test with `/task "Test your-domain feature"``

---

#### Issue 10: `language: latex` in extension-system.md prose

**File**: `.claude/docs/architecture/extension-system.md`, line 299

**Current**:
```
- Extension routing (e.g., `language: latex`) only works when extension is loaded
```

**Replace with**:
```
- Extension routing (e.g., `task_type: latex`) only works when extension is loaded
```

---

### Verified Clean (no stale references)

- `.claude/README.md` -- No stale references to backup, language, spreadsheet, or batch-dispatch
- `.claude/CLAUDE.md` -- Already updated by task 428
- `docs/README.md` -- Pure index file, unaffected
- `docs/architecture/system-overview.md` -- Has stale `Last Verified: 2026-01-19` but no task-428-related issues
- `docs/guides/creating-commands.md` -- Unaffected
- `docs/guides/copy-claude-directory.md` -- Has `--language neovim` (line 228) but this is a different context (CLI flag, not manifest/schema); may warrant a separate follow-up
- `docs/reference/standards/multi-task-creation-standard.md` -- Unaffected

### Search Results for Batch Dispatch

No references to `skill-batch-dispatch`, `batch-dispatch`, or `batch_dispatch` found anywhere in `.claude/docs/`. This was already clean.

## Decisions

- **Issue 6 approach**: Use Option A from the audit (update example to reflect actual practice with `model: opus` for implementation agents)
- **Scope boundary**: The filetypes `EXTENSION.md` source file has stale `skill-spreadsheet`/`spreadsheet-agent` references, but that is outside `.claude/docs/` scope. Noted for follow-up.
- **`"languages"` in index-entries**: The field `"languages"` in `index-entries.json` examples (extension-slim-standard.md line 66, creating-extensions.md index-entries template) is NOT stale -- actual index-entries files use `"languages"`, not `"task_types"`. Only `manifest.json` uses `"task_type"`.
- **`--language` CLI flag**: References to `--language` in task creation commands (creating-extensions.md line 576, adding-domains.md line 431, copy-claude-directory.md line 228) may be a separate issue. The `/task` command syntax may have changed. Flagged but not in scope for this task.

## Recommendations

1. **Fix all 10 issues** in one implementation pass across 7 files
2. **Priority order**: Issues 1-3 (HIGH), Issues 4, 7-10 (MEDIUM), Issue 6 (LOW)
3. **Consider follow-up task** for filetypes EXTENSION.md stale spreadsheet references
4. **Consider follow-up task** for `--language` CLI flag references if the flag was renamed

## Risks & Mitigations

- **Risk**: Manifest examples may be used as templates by extension creators. Incorrect examples lead to broken extensions.
  - **Mitigation**: Verify replacement text against actual working manifests (latex, filetypes). Already done.
- **Risk**: Changing `model: sonnet` guidance may confuse extension authors about when to use sonnet.
  - **Mitigation**: Keep sonnet as a valid option in the standard; only update the specific example that contradicts practice.

## Appendix

### Files to Modify (Complete List)

| # | File | Issues | Changes |
|---|------|--------|---------|
| 1 | `docs/architecture/extension-system.md` | 1, 2, 3, 10 | Replace backup section, fix `"language"` to `"task_type"`, add `routing`, fix prose |
| 2 | `docs/guides/creating-extensions.md` | 2, 3 | Fix `"language"` to `"task_type"`, add `routing` |
| 3 | `docs/guides/adding-domains.md` | 2, 3, 9 | Fix `"language"` to `"task_type"`, add `routing`, fix diagram/prose |
| 4 | `docs/reference/standards/extension-slim-standard.md` | 4 | Fix spreadsheet agent names |
| 5 | `docs/reference/standards/agent-frontmatter-standard.md` | 6 | Fix implementation agent example and sonnet guidelines |
| 6 | `docs/guides/creating-skills.md` | 7 | Fix `"language"` to `"task_type"` in delegation context |
| 7 | `docs/guides/creating-agents.md` | 8 | Fix `"language"` to `"task_type"` in delegation context |

### Reference Manifests Consulted

- `extensions/latex/manifest.json` -- `"task_type": "latex"`, has `routing` object
- `extensions/filetypes/manifest.json` -- `"task_type": "filetypes"`, has `routing` object, lists `filetypes-spreadsheet-agent.md`

### Reference Agents Consulted

- `agents/general-implementation-agent.md` -- `model: opus`
- `agents/meta-builder-agent.md` -- `model: opus`
