# Teammate D Findings: Strategic Horizons for Task 480

## Key Findings

### Extension Loader Architecture (Source-to-Deploy Mapping)

The Neovim Lua extension system uses `loader.lua` and `merge.lua` to copy files from
`.claude/extensions/*/` into the `.claude/` runtime on every extension load. The copy is
**unconditional** (overwrites target), so any nvim reference in a source file will
re-appear in the deployed copy every time the extension is loaded.

The copy model is: **source path in extension dir** -> **deployed path in .claude/**

| Source (extensions/core/) | Target (.claude/) |
|---------------------------|-------------------|
| `agents/*.md` | `agents/*.md` |
| `commands/*.md` | `commands/*.md` |
| `rules/*.md` | `rules/*.md` |
| `skills/skill-*/` | `skills/skill-*/` |
| `scripts/*.sh` (incl. `lint/`) | `scripts/*.sh` (incl. `lint/`) |
| `hooks/*.sh` | `hooks/*.sh` |
| `docs/README.md` | `docs/README.md` |
| `docs/docs-README.md` | `docs/docs-README.md` |
| `docs/architecture/` | `docs/architecture/` |
| `templates/*.md` | `templates/*.md` |
| `context/**` | `context/**` |
| `root-files/settings.local.json` | `settings.local.json` |

**Critical**: `root-files/settings.local.json` deploys to `.claude/settings.local.json` via
`copy_root_files()` -- unconditional overwrite. It contains historical nvim migration paths
(14 occurrences). This would contaminate any other project on load.

**Note**: `extensions/core/README.md` and `extensions/core/EXTENSION.md` are the extension's
own documentation files and do NOT deploy anywhere. They are safe to leave as informational.

### Complete nvim Reference Inventory (Sources Only)

**Priority 1 -- Core extension source files with nvim refs that propagate:**

| File | References | Type |
|------|-----------|------|
| `extensions/core/agents/code-reviewer-agent.md` | 2 | "Load For Neovim Code" block with nvim extension paths |
| `extensions/core/docs/README.md` | 2 | nvim routing row in table; "Moved to nvim extension" link |
| `extensions/core/docs/docs-README.md` | 4 | 2 "moved to nvim extension" tree entries + 2 in Guides |
| `extensions/core/scripts/validate-wiring.sh` | 1 | nvim case block with 4 validation calls |
| `extensions/core/templates/extension-readme-template.md` | 1 | "nvim" in example list |
| `extensions/latex/EXTENSION.md` | 5 | Full VimTeX Integration subsection + 4 keymaps |
| `extensions/core/root-files/settings.local.json` | 14 | Historical nvim migration `mv` commands |

**Priority 2 -- Memory extension source files with neovim topic examples:**

| File | References | Type |
|------|-----------|------|
| `extensions/memory/skills/skill-memory/SKILL.md` | ~9 | neovim/telescope topic examples |
| `extensions/memory/context/project/memory/learn-usage.md` | ~12 | neovim/lua topic paths |
| `extensions/memory/context/project/memory/knowledge-capture-usage.md` | ~1 | neovim pattern example |
| `extensions/memory/context/project/memory/memory-setup.md` | ~1 | MEM-neovim-lsp path example |
| `extensions/memory/context/project/memory/domain/memory-reference.md` | ~1 | neovim topic example |
| `extensions/memory/data/.memory/README.md` | ~3 | MEM-neovim examples |
| `extensions/memory/README.md` | ~6 | neovim topic examples |
| `extensions/memory/commands/learn.md` | ~1 | ~/notes/neovim/ path example |

**Priority 3 -- Core source files with minimal nvim refs (build tool context):**

| File | References | Type |
|------|-----------|------|
| `extensions/core/context/standards/postflight-tool-restrictions.md` | 1 | `nvim --headless` in table |
| `extensions/core/scripts/lint/lint-postflight-boundary.sh` | 2 | `nvim --headless` in pattern string |
| `extensions/core/docs/architecture/extension-system.md` | 2 | "VimTeX integration" in latex description |

**Deployed copies that match sources (same counts, all needing sync after source fixes):**

- `.claude/agents/code-reviewer-agent.md` (2)
- `.claude/docs/README.md` (2)
- `.claude/docs/docs-README.md` (4)
- `.claude/scripts/validate-wiring.sh` (1)
- `.claude/templates/extension-readme-template.md` (1)
- `.claude/context/standards/postflight-tool-restrictions.md` (1)
- `.claude/scripts/lint/lint-postflight-boundary.sh` (2)
- `.claude/context/project/memory/learn-usage.md` (12)
- `.claude/context/project/memory/knowledge-capture-usage.md` (1)
- `.claude/context/project/memory/memory-setup.md` (1)
- `.claude/context/project/memory/domain/memory-reference.md` (1)

---

## Source-to-Deploy Mapping Analysis

### How the Loader Works

1. `copy_simple_files()` -- flat copies agents, commands, rules (individual .md files)
2. `copy_skill_dirs()` -- recursively copies skill directories
3. `copy_context_dirs()` -- recursively copies context subdirectories
4. `copy_scripts()` -- flat copies scripts (preserves execute permissions for .sh)
5. `copy_docs()` -- flat + recursive copy for docs
6. `copy_templates()` -- flat copies templates
7. `copy_root_files()` -- copies from `root-files/` directly to `.claude/` root

### Critical Insight: settings.local.json Deployment

`settings.local.json` in `root-files/` deploys to `.claude/settings.local.json` via
unconditional overwrite. This file contains 14+ nvim-specific permission entries (historical
migration `mv` commands). This is a cross-project contamination risk that previous tasks
completely missed.

However, `.syncprotect` only applies to sync operations (Ctrl-l), NOT to the extension Load
operation. So even with `.syncprotect`, `settings.local.json` would be overwritten on load.

**Recommended action**: Remove the stale `mv` migration commands from `settings.local.json`.
They have already run (the target paths no longer need moving), and they expose nvim paths.

### CLAUDE.md Generation Path

`generate_claudemd()` in `merge.lua` concatenates:
1. `extensions/core/templates/claudemd-header.md` (fixed)
2. Each loaded extension's `merge-sources/claudemd.md` or `EXTENSION.md`

For latex: `extensions/latex/EXTENSION.md` is the claudemd source. The VimTeX Integration
subsection in EXTENSION.md will be injected into CLAUDE.md on every latex reload. This is
the "Priority 1" contamination path.

---

## Why Previous Tasks Were Incomplete

### Task 478 (Editor-agnostic docs)
- Focused narrowly on `<leader>ac` keybinding references
- Fixed: extension-development.md, loader-reference.md, extension-readme-template.md
- Missed: code-reviewer-agent.md, docs/README.md, docs/docs-README.md, validate-wiring.sh,
  latex/EXTENSION.md, postflight-tool-restrictions.md, all memory files

### Task 479 (Fix remaining nvim refs in core ext sources)
- Focused on items from a specific Zed audit report
- Fixed: claudemd-header.md, extension-development.md, extension-system.md box diagram,
  system-overview.md, meta-guide.md bug
- Missed: code-reviewer-agent.md, docs/README.md, docs/docs-README.md, validate-wiring.sh,
  latex/EXTENSION.md, memory extension files, postflight-tool-restrictions.md,
  lint-postflight-boundary.sh, settings.local.json

### Root Cause Pattern

Both tasks used partial grep scopes or relied on specific audit reports. Neither:
1. Searched the **full** extension directory tree (`grep -riE 'nvim|neovim|vimtex'`)
2. Audited **both** the core extension **and** the memory/latex extensions
3. Examined `root-files/settings.local.json` as a contamination vector
4. Checked deployed copies for sync with sources

Task 480 must use a complete grep-first approach with no assumed scope.

---

## Prevention Strategy

### Option A: Extend check-extension-docs.sh (Recommended)

Add a `check_core_extension_purity()` function to `check-extension-docs.sh` that:
1. Runs `grep -riE 'nvim|neovim|neotex|vimtex' extensions/core/` (excluding nvim extension)
2. Applies an allowlist for expected occurrences (validate-wiring.sh case blocks, etc.)
3. Fails with exit code 1 if any new occurrences appear

This script already runs as a pre-commit hook (it appears in `settings.local.json`
permissions). Adding the purity check would catch future contamination automatically.

**Allowlist approach** for files that legitimately reference other extensions:
```bash
# In check-extension-docs.sh, add:
check_core_purity() {
  local allowed_files=(
    "scripts/validate-wiring.sh"  # Extension registry - expected to list nvim
  )
  # Grep core/ for nvim refs, exclude allowed files
}
```

### Option B: Structured Lint Rule

Add a `.claude/rules/extension-purity.md` or entry in `check-extension-docs.sh` that
defines which files may contain cross-extension references. This is more maintainable than
an implicit allowlist.

### Option C: CI Pre-Commit Hook

The `check-extension-docs.sh` is already called in settings.local.json. Extending it is
the lowest-friction prevention path.

**Recommendation**: Option A is best. Extend `check-extension-docs.sh` with a
`check_core_purity()` function. Apply to both `core/` and `memory/` extensions since they
both currently have leaked references.

---

## Replacement Patterns Guide

### For functional code (case blocks in scripts)

`validate-wiring.sh` nvim case block:
- **Option 1 (Clean)**: Remove entirely. The nvim extension's own manifest and routing
  declare its wiring; the core script doesn't need to know about it.
- **Option 2 (Delegate)**: Replace with a comment: "Extension-specific wiring validated
  by each extension's own check." Keep only core (general, meta, markdown) routing.

**Recommended**: Remove the nvim case block. The script should validate extensions that
are actually loaded, not hardcode extension-specific agents.

### For example topics in memory documentation

Replace `neovim/plugins/telescope` and similar with generic alternatives:
- `python/data-analysis` -- common across many projects
- `nix/home-manager` -- another loaded extension
- `git/workflow` -- universal
- `typescript/react-patterns` -- web domain

For `MEM-neovim-lsp-best-practices.md` filename examples:
- Replace with `MEM-python-typing-best-practices.md` or `MEM-nix-module-patterns.md`

For `/learn ~/notes/neovim/` path examples:
- Replace with `/learn ~/notes/python/` or `/learn ~/notes/git/`

### For documentation (moved-to-nvim entries)

`docs/docs-README.md` and `docs/README.md` contain:
```
(moved to nvim extension: project/neovim/guides/neovim-integration.md)
```

Options:
1. **Remove entirely** -- these were migration breadcrumbs for people who knew the old path.
   Now that the nvim extension exists, users know to look there.
2. **Replace with generic note** -- "Domain-specific integrations live in their respective
   extensions under `extensions/{domain}/context/`."

**Recommended**: Remove the "moved to nvim extension" entries (both in tree view and in
Guides list). The nvim extension's own README covers those guides.

### For postflight-tool-restrictions.md and lint-postflight-boundary.sh

`nvim --headless` as an example of a prohibited build tool:
- Replace with `nvim --headless` -> `helix --headless` OR simply remove the row
- The table already has `lake build`, `pdflatex`, `nix build` as examples
- Alternative: use a generic `<editor> --headless` representation
- **Best**: Replace `nvim --headless` with `helix --headless` in the table row
  (helix is another terminal editor, equally illustrative)

### For code-reviewer-agent.md "Load For Neovim Code" block

The block loads nvim-extension-specific context:
```markdown
**Load For Neovim Code**:
- `@.claude/extensions/nvim/context/...`
```

**Recommended**: Remove the entire "Load For Neovim Code" section. The code-reviewer-agent
is in core -- it should be editor-agnostic. Neovim-specific review guidelines live in the
nvim extension itself (which provides its own rules). The code reviewer should use project
context, not hardcode nvim extension paths.

### For extension-readme-template.md

Current: `Complex extensions (e.g., filetypes, lean, formal, nvim, nix, web, epidemiology)`

Replace `nvim` with another complex extension like `memory` or rearrange:
`Complex extensions (e.g., filetypes, lean, formal, memory, nix, web, epidemiology)`

### For docs/architecture/extension-system.md VimTeX references

Two occurrences of `"LaTeX document development with VimTeX integration"`:
- These are in code examples showing a manifest description field
- Replace with: `"LaTeX document development with latexmk/pdflatex toolchain"`

### For latex/EXTENSION.md VimTeX Integration subsection

The VimTeX Integration section with `<leader>l*` keymaps should be removed.
- These are Neovim-specific keybindings (VimTeX plugin for Neovim/Vim)
- The latex extension should document editor-agnostic compilation workflows
- Recommended replacement: brief note "For Neovim users, see the nvim extension for
  VimTeX keymaps" OR remove entirely and let the nvim extension handle it

### For settings.local.json nvim migration paths

Remove the historical `mv` commands that relocate neovim context files. These have already
been executed and the paths are now correct. The commands serve no future purpose and
expose nvim-specific paths to other projects.

---

## Confidence Level

**High confidence** on:
- Complete inventory (grep-verified, no hidden files)
- Source-to-deploy mapping (read loader.lua directly)
- Root cause of previous task incompleteness
- settings.local.json as unrecognized contamination vector

**Medium confidence** on:
- Whether settings.local.json migration commands have actually all been run
  (some may still be needed for people migrating from older setups)
- Whether removing nvim from validate-wiring.sh breaks any workflow
  (the script is run as a hook but the nvim extension installs its own validators)

**Recommended verification** after fixes:
```bash
grep -riE 'nvim|neovim|neotex|vimtex' \
  .claude/extensions/core/ \
  .claude/extensions/latex/ \
  .claude/extensions/memory/ \
  | grep -v "Binary file" \
  | grep -v "extensions/core/README.md" \
  | grep -v "extensions/core/EXTENSION.md"
```
Expected: zero results for actionable files.
