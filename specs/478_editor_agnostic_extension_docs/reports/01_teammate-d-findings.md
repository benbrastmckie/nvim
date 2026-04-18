# Teammate D (Horizons) - Strategic Findings
# Task 478: Make Extension Core Docs Editor-Agnostic

**Date**: 2026-04-18
**Role**: Strategic direction, long-term alignment, creative alternatives

---

## Key Findings

### 1. This Task Is Part of an Active Multi-Editor Portability Initiative

The evidence is unambiguous: this task is not addressing a new problem in isolation -- it is fixing a gap that an existing multi-editor initiative left behind.

**Evidence**:
- `extensions/README.md` already uses the multi-editor pattern: "Extensions are loaded via the editor's extension picker: Neovim: `<leader>ac` | OpenCode: `<leader>ao`" (line 42) -- this is the established pattern.
- The zed repo (`~/.config/zed/`) has its own `.syncprotect` that already protects `context/repo/project-overview.md` with the comment "Zed-specific project overview (not nvim)" -- proving this contamination problem has been manually worked around downstream.
- The zed repo's project-overview.md is already editor-agnostic ("The extension picker triggers the loader" -- no `<leader>ac`). Someone already wrote a clean version for Zed.
- The zed `~/.config/zed/.claude/context/guides/loader-reference.md` and `extension-development.md` **still contain `<leader>ac`** -- synced from the nvim core and never fixed at the source.

**Conclusion**: The contamination is confirmed, real, and actively worked around downstream via `.syncprotect`. Task 478 addresses the root cause rather than another workaround.

### 2. The Scale of the Problem Is Narrow and Well-Bounded

Despite the task description mentioning "59 nvim references" (from a zed task), the actual `<leader>ac` contamination in `extensions/core/` is limited to exactly 4 locations:

1. `extensions/core/context/repo/project-overview.md` (1 occurrence) -- describes the Neovim Lua loader by name
2. `extensions/core/context/guides/loader-reference.md` (1 occurrence) -- mentions `picker.lua` and `<leader>ac`
3. `extensions/core/context/guides/extension-development.md` (1 occurrence) -- step 6 of creating an extension
4. `extensions/core/templates/extension-readme-template.md` (1 occurrence) -- "Loaded via `<leader>ac` in Neovim"

The deployed copies in `.claude/context/` mirror these exactly. So the fix is surgical: 4 source files, 4 deployed copies.

### 3. The project-overview.md Problem Has a Clean Existing Solution: The `data` Category

This is the most important strategic finding. The extension loader already implements **merge-copy semantics** via the `data` category (`copy_data_dirs()`):

- Files in `data/` are copied only if they do NOT already exist at the target
- If the target file already exists (user-customized), it is skipped
- These files are tracked as `data_skeleton_files` separately -- unload removes only the extension-provided starters, not user-created files

This is semantically exactly what project-overview.md needs: seed it once, never overwrite it on re-sync. Moving project-overview.md from `context/repo/` to a `data/` directory in the core extension would:

1. Stop propagating the nvim-specific version to downstream projects on every re-sync
2. Seed a generic template on first install if no project-overview.md exists
3. Preserve user-written project-overview.md on all subsequent syncs

**However**, there is a subtlety: `copy_data_dirs` writes to `project_dir` (repository root), not `target_dir` (`.claude/`). The current project-overview.md lives at `.claude/context/repo/project-overview.md`. The manifest would need to declare the data item as something that lands in `.claude/context/repo/` -- which means `project_dir` + data directory path needs to resolve correctly. This needs verification against the actual loader implementation before committing to this approach.

**Alternative**: The simpler approach is to keep project-overview.md in `context/repo/` but replace the nvim-specific content with a generic placeholder that instructs Claude to generate a real one. The existing `update-project.md` (already in `context/repo/`) already provides this guidance. The `claudemd.md` source already has: "If project-overview.md doesn't exist, see `.claude/context/repo/update-project.md` for guidance on generating project-appropriate documentation." This is halfway there -- but it only triggers when the file is absent, whereas the problem is the file is always present (but wrong).

### 4. The Current Detection Mechanism Is Incomplete

The `claudemd.md` (CLAUDE.md source) already has conditional language:

```
**Project-specific structure**: See `.claude/context/repo/project-overview.md` for details about this repository's layout.

**New repository setup**: If project-overview.md doesn't exist, see `.claude/context/repo/update-project.md` for guidance on generating project-appropriate documentation.
```

And `update-project.md` is already loaded for meta-builder-agent and meta task types (via index-entries.json). This mechanism is sound but has a gap: it only instructs Claude what to do when the file is *absent*, but the nvim-specific project-overview.md is always *present* after sync.

**Best practice for self-detecting stale context**: The cleanest pattern for LLM-facing context files is to embed a "validity check" header in the generic template:

```markdown
<!-- NOTICE: This is a generic project overview template. If this repository is not a
     Neovim configuration, this file should be regenerated. Run `/task "Generate
     project-overview.md for this project"` to create a project-specific version. -->
```

This makes the stale state self-evident to Claude without requiring any code changes -- Claude will see this notice and act on it. This is a pattern used by tools like cookiecutter and copier for template freshness detection.

### 5. Long-Term: The Extension System Is Structurally Headed Toward Full Editor-Agnosticism

**Trajectory evidence**:
- `extensions/README.md` already uses the "editor's extension picker" abstraction with per-editor footnotes -- the intention is clear.
- The ROADMAP.md Phase 2 item "Extension hot-reload: Allow `<leader>ac` to reload..." reveals that even the roadmap has nvim leakage. This item should be written as "Allow the extension picker to reload..." when it is addressed.
- The `config.lua` module already has `M.claude()` and `M.opencode()` presets -- multi-editor abstraction is built into the loader.
- The task 477 summary described fixing "the generated CLAUDE.md" -- each fix pushes the system toward being the editor-agnostic core it architecturally intends to be.

**Future state**: If 5 editors sync from this extension system, the correct model is:
1. Core extension: 100% editor-agnostic
2. Editor-specific references live only in the editor's own extension (e.g., the `nvim` extension)
3. project-overview.md is seeded once (merge-copy) with a generic template, then customized per-project
4. `.syncprotect` remains available as an escape hatch for projects with unusual needs

---

## Recommended Approach

### Part 1: Replace `<leader>ac` References (Trivial)

Replace the 4 occurrences in core extension source files using the established pattern from `extensions/README.md`:

- `loader-reference.md`: "Provides the extension browser launched from the extension picker (e.g., `<leader>ac` in Neovim)." -- the mention of `picker.lua` makes it inherently Neovim-specific; add the parenthetical rather than removing context.
- `extension-development.md`: "Load via the extension picker" (drop the keybinding entirely -- the instruction is editor-agnostic).
- `extension-readme-template.md`: "Loaded via the extension picker. Once loaded, `<type>` becomes a recognized task type." (drop the Neovim-specific qualifier from the template).
- `project-overview.md`: "The extension picker triggers the loader" (already done correctly in the Zed version -- copy that language).

Update the 4 deployed copies in `.claude/context/` to match.

### Part 2: Handle project-overview.md Propagation (More Nuanced)

**Recommended**: Replace the nvim-specific content in the core extension's `project-overview.md` with a **generic template** that:
1. Describes the two-layer architecture in editor-agnostic terms (copy from zed version)
2. Includes a prominent notice at the top: "This is a generic template. Generate a project-specific version with `/task 'Generate project-overview.md for this project'`."
3. Keeps the file in `context/repo/` (no architecture change needed)

This approach:
- Requires no loader changes
- Works immediately for all downstream projects
- Is self-documenting (Claude reads the notice and acts)
- The nvim-specific project-overview.md in this repo is protected by `.syncprotect` (already in place: `context/repo/project-overview.md`)

**Rejected alternative**: Moving project-overview.md to the `data/` category would be architecturally elegant but requires changes to the manifest and loader behavior, and raises questions about what happens when the file is already in `context/repo/` (wrong category). The simpler approach achieves the same outcome with zero complexity.

**Rejected alternative**: Post-sync hooks that strip editor-specific references. Too fragile -- string manipulation on markdown is brittle and creates a maintenance burden.

### Part 3: Strengthen the Detection/Suggestion Mechanism

The existing mechanism (update-project.md + CLAUDE.md language) is nearly sufficient. Add one improvement: update `update-project.md` to also detect the *stale generic template* case, not just the *missing file* case. The notice header in the generic template (see above) is the trigger.

Also consider: the `/task` command could check for the notice header on startup and prompt the user. But this is optional -- the embedded notice is sufficient for Claude Code workflows.

---

## Evidence Summary

| File | Issue | Evidence Location |
|------|-------|-------------------|
| `core/context/repo/project-overview.md` | `<leader>ac` reference; nvim-specific architecture description | Line 11 |
| `core/context/guides/loader-reference.md` | `<leader>ac` reference | Line 141 |
| `core/context/guides/extension-development.md` | `<leader>ac` reference | Line 143 |
| `core/templates/extension-readme-template.md` | `<leader>ac` reference | Line 50 |
| `~/.config/zed/.syncprotect` | Downstream workaround protecting `context/repo/project-overview.md` | Lines 6-8 |
| `~/.config/zed/.claude/context/guides/loader-reference.md` | Confirmed contamination from sync | Line 141 |
| `~/.config/zed/.claude/context/guides/extension-development.md` | Confirmed contamination from sync | Line 143 |
| `extensions/README.md` | Established multi-editor pattern to follow | Lines 41-42 |
| Zed `context/repo/project-overview.md` | Already editor-agnostic version (model to copy) | Lines 10-13 |

---

## Creative Alternatives Considered

**Extension "flavors"**: An nvim flavor of core extension would carry all nvim-specific references; other editors get a clean flavor. This is elegant but over-engineered for what is currently 4 references. Revisit when the reference count grows significantly or when a third editor is added.

**Auto-generate project-overview.md during first load**: Could be implemented as a post-load hook that checks for the notice header and immediately spawns a task. This is a nice user experience improvement but goes beyond the scope of task 478. Add to ROADMAP.md as a future enhancement.

**`.claude/extensions/core/data/` directory for seed-once files**: Architecturally sound (the `copy_data_dirs` mechanism already exists) but requires manifest changes and careful testing. The simpler template-with-notice approach achieves the same user outcome without infrastructure changes.

---

## Confidence Levels

| Finding | Confidence | Basis |
|---------|------------|-------|
| 4 files need `<leader>ac` fixes | High | Direct grep of source files |
| Zed .syncprotect workaround confirms the problem | High | File read directly |
| `data/` category has merge-copy semantics | High | loader-reference.md documentation |
| Generic template + notice is the right approach for project-overview.md | High | Simplest solution; no architecture changes |
| Extension system moving toward full editor-agnosticism | High | README, config.lua, task history |
| ROADMAP.md Phase 2 should also be cleaned | Medium | Single occurrence, low priority |
| Post-sync hook approach would be fragile | High | Engineering judgment |

---

## Roadmap Implications

After task 478, consider adding to ROADMAP.md:

1. **Auto-generate project-overview.md on first load**: Post-load hook detects generic template (via notice header) and spawns a task to generate a project-specific version. Eliminates the manual step.
2. **Fix ROADMAP.md Phase 2 `<leader>ac` reference**: Single occurrence in "Extension hot-reload" item. Low priority but part of the overall cleanup.
3. **Lint check for editor-specific references in core**: Add to `check-extension-docs.sh` -- fail if any file in `extensions/core/` contains `<leader>ac` without a parenthetical editor qualifier.
