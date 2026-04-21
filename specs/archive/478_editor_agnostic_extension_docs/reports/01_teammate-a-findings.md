# Teammate A Findings: Primary Implementation Approach

## Key Findings

### Part 1: Editor-Agnostic Docs - Scope of Changes

Four files contain hardcoded `<leader>ac` references that need updating:

1. **`.claude/extensions/core/context/guides/extension-development.md` (line 143)**
   - Current: `6. Load via the extension picker (\`<leader>ac\`)`
   - Issue: Ties the "creating an extension" checklist to a Neovim-specific keymap

2. **`.claude/extensions/core/context/guides/loader-reference.md` (line 141)**
   - Current: `| picker.lua | Telescope picker UI. Provides the extension browser launched from \`<leader>ac\`. ...`
   - Issue: This is a technical description of the picker.lua file which is Neovim-specific; this reference may be acceptable but the `<leader>ac` shorthand is not portable

3. **`.claude/extensions/core/templates/extension-readme-template.md` (line 50)**
   - Current: `Loaded via \`<leader>ac\` in Neovim. Once loaded, \`<type>\` becomes a recognized task type...`
   - Issue: Template explicitly names Neovim and its keymap, so every extension README generated from this template will be Neovim-contaminated

4. **`.claude/extensions/core/context/repo/project-overview.md` (line 11)**
   - Current: `The extension picker (\`<leader>ac\`) triggers the loader...`
   - Issue: Also uses Nvim-specific keymap; however, this file itself is the subject of Part 2 (it should not be synced at all)

The `extensions/README.md` already shows the correct multi-editor pattern:
```
Extensions are loaded via the editor's extension picker:
- Neovim: `<leader>ac` | OpenCode: `<leader>ao`
```

This dual-notation format is acceptable for explicit documentation about the system. However, for generic instructions that should work across editors, the preferred pattern should be **"the extension picker"** without any keymap citation. The README.md style (listing both) is good for reference docs; clean generic language is better for how-to guides and templates.

### Part 2: project-overview.md - The Core Problem

**Why this matters**: When `copy_context_dirs()` in `loader.lua` processes the `"repo"` directory entry in the core manifest's `provides.context`, it copies the entire `repo/` directory tree from the extension source. This includes `project-overview.md`, which contains Neovim-specific content:

```
- Layer 1 -- Neovim Lua loader (lua/neotex/...): ... The extension picker (`<leader>ac`) triggers the loader...
```

When the extension system is synced to another project (e.g., a Python repo), `core` is loaded and this Nvim-specific `project-overview.md` overwrites whatever project-specific content should be there.

**Current protection gap**:
- `.syncprotect` at project root already lists `context/repo/project-overview.md` — but this ONLY protects during the sync operation (the Claude picker "Load Core" / Ctrl-l workflow). It does NOT protect during the extension loader's `copy_context_dirs()` call.
- The extension loader (`loader.lua`) has no knowledge of `.syncprotect` — confirmed by inspection; no syncprotect code exists in any shared extensions Lua file.

**The right fix**: Remove `project-overview.md` from what the core extension copies, then add detection/generation guidance.

### Detection Mechanism Analysis

**Best practice context**: Industry patterns for "detect missing config, prompt user to generate" appear in tools like `rails new` (generates project structure), `create-react-app`, and many CLI tools. The cleanest pattern is:

1. **Detection at load time** (when core extension is loaded): Check if `project-overview.md` exists in the target context/repo/ directory. If missing, emit a notification with actionable guidance.
2. **Lightweight check**: A single `vim.fn.filereadable()` call - O(1), zero overhead.
3. **Non-intrusive**: Show a warning notification with the task to create via `/task`, not a blocking modal.
4. **Self-contained**: The `update-project.md` guide already exists at `context/repo/update-project.md` and provides complete generation instructions. No new infrastructure needed.

The detection should happen in `init.lua`'s `manager.load()` function, specifically in the post-load block after a successful core load - parallel to the existing `detect_legacy_core()` pattern.

---

## Recommended Approach

### Part 1: Specific Text Changes

**extension-development.md (line 143)** - Change to generic language:
```
6. Load via the extension picker
```
The step doesn't need a keymap citation; it's a process step, not a quick-reference card.

**loader-reference.md (line 141)** - This file describes Neovim-specific implementation files. The `<leader>ac` reference is part of describing what `picker.lua` does. Change to:
```
| `picker.lua` | Telescope picker UI. Provides the extension browser. Reads manager API from `init.lua` to show status, details, and trigger load/unload. |
```
The keymap is editor-specific implementation detail; the functional description is sufficient.

**extension-readme-template.md (line 50)** - Replace the hardcoded Neovim reference with generic text:
```
Loaded via the extension picker. Once loaded, `<type>` becomes a recognized task type<, and `/<cmd>` becomes available>.
```
Extension READMEs are part of core docs that travel to any project. The template should not bake in Neovim assumptions.

**project-overview.md** - This file should NOT be copied at all (see Part 2 below). The file itself needs to be rewritten to be a generic template/placeholder, not the nvim-specific current content.

### Part 2: Mechanism for project-overview.md

**Three-component solution** (all lightweight, no new infrastructure):

#### Component A: Remove from copy scope in manifest.json

Change the core manifest `provides.context` from listing `"repo"` (which copies the entire repo/ directory including project-overview.md) to an exclusion pattern.

Since `copy_context_dirs()` processes directory entries by copying all files recursively, the cleanest approach is to **list individual files** instead of the whole `repo/` directory. Change the manifest from:
```json
"context": [
  ...
  "repo",
  ...
]
```
To list `repo` subdirectory files individually, excluding `project-overview.md`:
```json
"context": [
  ...
  "repo/update-project.md",
  "repo/self-healing-implementation-details.md",
  ...
]
```

This is clean, explicit, and leverages the existing `copy_context_dirs()` individual-file support (which already handles `vim.fn.filereadable()` for non-directory entries). No code changes needed - the loader already supports this pattern.

#### Component B: Replace project-overview.md source with a placeholder

The source file at `.claude/extensions/core/context/repo/project-overview.md` should be replaced with a **generic placeholder** that:
- Works as starter documentation if somehow copied (belt-and-suspenders)
- Is clearly marked as needing project-specific replacement
- Points to `update-project.md` for instructions

Example content:
```markdown
# Project Overview

> **Note**: This file should be replaced with project-specific content.
> See `.claude/context/repo/update-project.md` for generation instructions,
> or run `/task "Generate project-overview.md"` to create a task for this.

## Purpose

This file describes the repository structure for agent context. Generate a
project-specific version using the guide in `update-project.md`.
```

#### Component C: Post-load detection in init.lua

After a successful core load, check whether `project-overview.md` exists in the target context:

```lua
-- After core loads successfully, check for project-overview.md
if extension_name == "core" then
  local overview_path = target_dir .. "/context/repo/project-overview.md"
  if vim.fn.filereadable(overview_path) ~= 1 then
    vim.schedule(function()
      vim.notify(
        "Project setup: .claude/context/repo/project-overview.md is missing.\n"
          .. "Run: /task \"Generate project-overview.md for this project\"\n"
          .. "Then follow the guide in .claude/context/repo/update-project.md",
        vim.log.levels.WARN
      )
    end)
  end
end
```

This check is:
- Zero overhead (single filereadable check)
- Non-blocking (vim.schedule defers notification)
- Actionable (gives exact command to run)
- Mirrors existing `detect_legacy_core()` placement and style

**Where to place in init.lua**: After the `verify_mod.verify_extension()` call (line ~526), before `return true, nil`. The existing `detect_legacy_core()` check runs before loading; this detection runs after, once we know the core loaded successfully.

### What NOT to do

- **Do not** add a new `exclude` field to the manifest schema - it adds complexity without benefit. Individual file listing is cleaner and more explicit.
- **Do not** make the detection blocking or modal - a warning notification is sufficient. Users should be able to ignore it and handle later.
- **Do not** auto-generate project-overview.md during load - Claude cannot run slash commands from Lua code, and auto-generation would be wrong content anyway.
- **Do not** modify `copy_context_dirs()` to support per-file exclusions - unnecessary complexity when individual listing already works.
- **Do not** update the index-entries.json entry for `repo/project-overview.md` - it should remain with `"always": true` so that when the file DOES exist (project-specific version), it's always loaded. The index entry is about runtime loading behavior, not about what gets copied.

---

## Evidence and Examples

### Existing individual-file pattern in copy_context_dirs()
From `loader.lua` lines 218-223:
```lua
elseif vim.fn.filereadable(source_ctx_dir) == 1 then
  -- Handle individual files at context root (mirrors copy_docs pattern)
  if copy_file(source_ctx_dir, target_ctx_dir, false) then
    table.insert(copied_files, target_ctx_dir)
  end
end
```
This confirms individual file entries already work in the manifest `provides.context` array.

### Existing detection pattern in init.lua
The `detect_legacy_core()` function (lines 179-221 in init.lua) demonstrates the established pattern for conditional detection with `vim.notify`. The proposed project-overview detection follows the same idiom, keeping code consistent.

### .syncprotect already protects during sync
The `.syncprotect` file at the project root already lists:
```
context/repo/project-overview.md
```
This confirms the existing intent: project-overview.md is known to be project-specific. The sync operation already respects this. We're just extending the same protection to the extension loader copy operation.

### What travels to other projects
The core manifest `provides.context` lists `"repo"` as a directory, which means ALL files in `context/repo/` get copied - currently: `project-overview.md`, `update-project.md`, and `self-healing-implementation-details.md`. The first is project-specific; the last two are genuinely portable. The fix makes this distinction explicit in the manifest.

---

## Confidence Level

**Part 1 (editor-agnostic text)**: HIGH
- Exact files and line numbers confirmed by direct inspection
- Replacement text is clear and unambiguous
- The extensions/README.md multi-editor pattern serves as precedent

**Part 2 (project-overview.md mechanism)**: HIGH
- The individual-file-listing approach leverages existing loader code (no changes needed)
- The post-load detection pattern mirrors existing `detect_legacy_core()` exactly
- The `.syncprotect` file already demonstrates the project owner's intent
- `update-project.md` already provides complete generation guidance - no new content needed
- Zero new infrastructure: manifest change + placeholder source + 8-line Lua block

**Risk assessment**: LOW
- All changes are additive or subtractive to manifest/docs; no logic changes to the copy engine
- The notification is non-blocking and easily ignored
- The individual file listing is more explicit than directory listing (smaller blast radius)
- Rollback is trivial: restore manifest, restore source file, remove 8 Lua lines
