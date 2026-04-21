# Teammate A Findings: Priority 1 File Audit

**Task**: 480 - Comprehensively strip ALL remaining nvim/neovim/neotex/VimTeX references from extension sources
**Scope**: Priority 1 files only (6 files)
**Date**: 2026-04-18

---

## Key Findings

All 6 Priority 1 files contain nvim/neovim/VimTeX references. The most critical is
`EXTENSION.md` (latex), which injects `<leader>` keybindings into CLAUDE.md on reload.
The `validate-wiring.sh` script has the most structural references (nvim case block).
The `code-reviewer-agent.md` has a context section that points to nvim extension paths
that may not exist in non-nvim projects. The two `docs` files have comment-style entries
noting what was "moved to nvim extension", which are informational but still contaminate.

---

## Per-File Analysis

### 1. `.claude/extensions/latex/EXTENSION.md`

**File path**: `/home/benjamin/.config/nvim/.claude/extensions/latex/EXTENSION.md`

| Line | Content | Action |
|------|---------|--------|
| 17 | `### VimTeX Integration` | **REMOVE** (entire subsection, lines 17-22) |
| 18 | `- Compile: \`:VimtexCompile\` (\`<leader>lc\`)` | **REMOVE** |
| 19 | `- View PDF: \`:VimtexView\` (\`<leader>lv\`)` | **REMOVE** |
| 20 | `- Clean: \`:VimtexClean\` (\`<leader>lk\`)` | **REMOVE** |
| 21 | `- TOC: \`:VimtexTocOpen\` (\`<leader>li\`)` | **REMOVE** |

**Context**: This is the root cause of VimTeX `<leader>` binding contamination. The `### VimTeX Integration` subsection (lines 17-22) propagates into CLAUDE.md on every extension reload. This content is Neovim-specific and belongs only in the `nvim` extension, not in `latex/EXTENSION.md`.

**Recommended replacement**: Remove the entire `### VimTeX Integration` subsection. No replacement needed - VimTeX is a Neovim plugin and its keybindings are not generic LaTeX compilation. The `### Document Structure` section that follows (line 24) can remain as-is.

**Resulting file** (lines 17-23 removed, rest unchanged):
```markdown
## LaTeX Extension
...
### Document Structure

- Use `\documentclass` appropriate for document type
...
```

---

### 2. `.claude/extensions/core/agents/code-reviewer-agent.md`

**File path**: `/home/benjamin/.config/nvim/.claude/extensions/core/agents/code-reviewer-agent.md`

| Line | Content | Action |
|------|---------|--------|
| 36 | `**Load For Neovim Code**:` | **REMOVE** (entire block, lines 36-38) |
| 37 | `` `@.claude/extensions/nvim/context/project/neovim/standards/lua-style-guide.md` - Lua style guide `` | **REMOVE** |
| 38 | `` `@.claude/extensions/nvim/context/project/neovim/domain/lua-patterns.md` - Lua patterns `` | **REMOVE** |

**Context**: The `**Load For Neovim Code**` block (lines 36-38) hard-codes paths into the `nvim` extension context directory. In any non-nvim project, these paths won't exist. The block creates nvim-specific coupling in a core agent that should be editor-agnostic.

**Recommended replacement**: Remove the entire `**Load For Neovim Code**` block. The agent should load language-specific context only when the relevant extension is loaded, not via hard-coded paths in a core file. If needed, a generic note like "Load domain-specific style guides from the relevant extension's context" can replace the block, or it can simply be omitted.

**Resulting section** (lines 36-38 deleted):
```markdown
**Always Load**:
- `@.claude/context/standards/code-quality.md` - Code quality standards
- `@.claude/context/repo/project-overview.md` - Project context

**Load For Web Code**:
- `@.claude/extensions/web/context/project/web/standards/web-style-guide.md` - Web style guide
- `@.claude/extensions/web/context/project/web/astro-framework.md` - Astro patterns
```

**Note**: The `**Load For Web Code**` block (lines 40-42) has the same pattern with hard-coded `web` extension paths. This is technically out of scope for this task but follows the same problem. Consider removing or generalizing it in a follow-up.

---

### 3. `.claude/extensions/core/docs/README.md`

**File path**: `/home/benjamin/.config/nvim/.claude/extensions/core/docs/README.md`

| Line | Content | Action |
|------|---------|--------|
| 120 | `\| nvim \| Neovim/Lua \| neovim-research-agent, neovim-implementation-agent \|` | **REMOVE** row |
| 191 | `- Neovim Integration - Moved to nvim extension: \`extensions/nvim/context/project/neovim/guides/neovim-integration.md\`` | **REMOVE** line |

**Context**:
- Line 120: The extensions table row for `nvim` is a listing of available extensions. Since this is a core document that may be synced to non-nvim projects, listing nvim explicitly creates nvim-specific contamination. However, the extensions table purpose is to enumerate what's available - a judgment call exists here (see Approach section).
- Line 191: The "Neovim Integration - Moved to nvim extension" is a tombstone entry in the Getting Started guide that references nvim-specific content. It should simply be removed.

**Recommended action**:
- Line 120: **REMOVE** the nvim row from the extensions table entirely. The table describes available extensions - projects that don't use nvim don't need this row.
- Line 191: **REMOVE** the entire line. The tombstone note is not useful in non-nvim projects and creates a broken reference expectation.

---

### 4. `.claude/extensions/core/docs/docs-README.md`

**File path**: `/home/benjamin/.config/nvim/.claude/extensions/core/docs/docs-README.md`

| Line | Content | Action |
|------|---------|--------|
| 18 | `│   ├── (moved to nvim extension: project/neovim/guides/neovim-integration.md)` | **REMOVE** |
| 19 | `│   ├── (moved to nvim extension: project/neovim/guides/tts-stt-integration.md)` | **REMOVE** |
| 56 | `- Neovim Integration - Moved to nvim extension: \`.claude/extensions/nvim/context/project/neovim/guides/neovim-integration.md\`` | **REMOVE** |
| 57 | `- TTS/STT Integration - Moved to nvim extension: \`.claude/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md\`` | **REMOVE** |

**Context**: Lines 18-19 are tombstone entries in the directory tree diagram. Lines 56-57 are tombstone entries in the Getting Started guides list. All four are historical notes that only make sense in the context of the nvim config repo where these guides previously lived. In any other project, these are meaningless and misleading.

**Recommended replacement**: Remove all 4 lines. The directory tree and guide lists read cleanly without them.

---

### 5. `.claude/extensions/core/scripts/validate-wiring.sh`

**File path**: `/home/benjamin/.config/nvim/.claude/extensions/core/scripts/validate-wiring.sh`

| Line | Content | Action |
|------|---------|--------|
| 240 | `            nvim)` | **REMOVE** (entire case block, lines 240-245) |
| 241 | `                validate_agent_exists "$system_dir/$agents_subdir" "neovim-research-agent"` | **REMOVE** |
| 242 | `                validate_agent_exists "$system_dir/$agents_subdir" "neovim-implementation-agent"` | **REMOVE** |
| 243 | `                validate_index_entries "$system_dir" "neovim-research-agent"` | **REMOVE** |
| 244 | `                validate_language_entries "$system_dir" "neovim"` | **REMOVE** |
| 245 | `                ;;` | **REMOVE** |

**Context**: The `nvim)` case block in `validate_extensions_loaded()` (lines 240-245) hard-codes Neovim-specific validation logic into the core validation script. This means whenever the `nvim` extension is listed in `extensions.json`, the script validates `neovim-research-agent` and `neovim-implementation-agent`. This is nvim-specific coupling in a generic script. The validation script should be either generic (checking agent existence based on manifest declarations) or should only contain non-nvim extension cases.

**Recommended action**: Remove the entire `nvim)` case block (lines 240-245). The remaining case blocks for `lean`, `latex`, `typst`, and `formal` can stay if those are intentional. However, for complete editor-agnosticism, a follow-up task might convert the entire switch to manifest-driven validation (Priority 3 concern).

**Note**: This file also has a `lean)` case block at lines 247-252 with similar extension-specific coupling. Out of scope for this task but noted for follow-up.

---

### 6. `.claude/extensions/core/templates/extension-readme-template.md`

**File path**: `/home/benjamin/.config/nvim/.claude/extensions/core/templates/extension-readme-template.md`

| Line | Content | Action |
|------|---------|--------|
| 26 | `Complex extensions (e.g., filetypes, lean, formal, nvim, nix, web, epidemiology) use the` | **REPLACE** |

**Context**: Line 26 lists `nvim` as an example of a complex extension in the comment block header. This comment is inside `<!-- ... -->` that instructs users to delete it when creating a real extension README. However, it still appears in the source file and would propagate to any project that syncs this template.

**Recommended replacement**:
```markdown
Complex extensions (e.g., filetypes, lean, formal, nix, web, epidemiology) use the
```
Simply remove `nvim, ` from the list. The remaining examples are sufficient to illustrate what "complex" means.

---

## Recommended Approach

### Removal Priority (strict order)

1. **`latex/EXTENSION.md`** - HIGHEST PRIORITY. The VimTeX subsection actively injects `<leader>` bindings into CLAUDE.md on every reload. Remove lines 17-22 entirely.

2. **`core/agents/code-reviewer-agent.md`** - HIGH. The nvim context block references paths that won't exist in non-nvim projects. Remove lines 36-38.

3. **`core/docs/README.md`** - HIGH. The nvim extensions row and tombstone entry should both be removed (lines 120 and 191).

4. **`core/docs/docs-README.md`** - HIGH. All four tombstone lines should be removed (lines 18, 19, 56, 57).

5. **`core/scripts/validate-wiring.sh`** - MEDIUM. Remove the `nvim)` case block (lines 240-245).

6. **`core/templates/extension-readme-template.md`** - LOW. Remove `nvim, ` from line 26.

### Mirror Requirement

Every source file change must be mirrored to its deployed copy under `.claude/`. The deployed copies are typically at paths like `.claude/agents/code-reviewer-agent.md`, `.claude/docs/README.md`, etc.

Deployed copies to update:
- `latex/EXTENSION.md` -> mirrored as part of `latex` extension EXTENSION.md (check if it also exists in `.claude/extensions/latex/`)
- `core/agents/code-reviewer-agent.md` -> `.claude/agents/code-reviewer-agent.md`
- `core/docs/README.md` -> `.claude/docs/README.md`
- `core/docs/docs-README.md` -> `.claude/docs/docs-README.md` (if deployed copy exists)
- `core/scripts/validate-wiring.sh` -> `.claude/scripts/validate-wiring.sh`
- `core/templates/extension-readme-template.md` -> `.claude/templates/extension-readme-template.md` (if deployed copy exists)

---

## Confidence Level

**HIGH** for all findings. The references are explicit, unambiguous, and directly confirmed by reading the file content at the specified line numbers. The recommended actions are conservative (remove only what's clearly nvim-specific, leave generic content intact).

**EXCEPTION**: The `docs/README.md` extensions table row for `nvim` (line 120) could be argued as appropriate documentation of available extensions. However, since this is a `core` file that propagates to all projects, listing nvim-specific rows creates contamination. Confidence in removal: **MEDIUM-HIGH**.
