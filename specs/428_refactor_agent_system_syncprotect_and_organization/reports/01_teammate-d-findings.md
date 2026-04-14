# Teammate D Findings: Horizons Research
## Task 428 - Refactor Agent System: Syncprotect Integration, Backup Elimination, Organization Review

---

## 1. Picker Integration Analysis

### 1.1 How the Picker Works

The `<leader>ac` picker is a Telescope-based UI at `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/init.lua`. It orchestrates:
- **Entry creation**: `display/entries.lua` builds hierarchical entries per artifact type
- **Preview**: `display/previewer.lua` renders per-type metadata in the preview pane
- **Sync operations**: `operations/sync.lua` handles "Load Core Agent System" batch sync
- **Key mappings**: Enter, `<C-l>`, `<C-u>`, `<C-s>`, `<C-e>`, `<C-n>`, `<C-r>`, `<C-t>`

### 1.2 .syncprotect Visibility - Current State

**Finding**: The picker has NO visibility into `.syncprotect` at all. The feature is completely invisible to users in the picker UI.

Evidence:
- `sync.lua:385-403`: `load_syncprotect()` reads `.syncprotect` but is called only during `load_all_globally()`, not surfaced in the picker UI.
- `sync.lua:337`: Protected files are only reported in the *post-sync* notification message as `"Protected: %d files skipped (.syncprotect)"`.
- `previewer.lua:160-236` (`preview_load_all`): The "Load Core Agent System" preview shows new/replace counts but does NOT show:
  - Whether a `.syncprotect` file exists
  - Which files are protected
  - What will be skipped vs. synced

This means users get no advance warning that files are protected until AFTER they initiate the sync.

### 1.3 Extension Preview - What IS Shown

The extension preview (`previewer.lua:523-588`) shows:
- Extension name, version, status (`active`/`inactive`/`update-available`)
- Description, language
- `Provides` section (agents, skills, commands, rules, context)
- `MCP Servers` section
- `Installed Files` (up to 10, with overflow count)
- `Loaded at` timestamp

This is thorough and useful. The extension entry (`entries.lua:928-975`) shows `[active]`, `[update]`, or `[inactive]` status in the picker row itself.

### 1.4 Backup File Creation - Picker Awareness

**Finding**: Backup files (`.backup` suffix) are created silently with zero picker visibility.

`merge.lua:94-104` (`backup_file()`) creates `filepath.backup` whenever `inject_section()`, `merge_settings()`, or `append_index_entries()` is called. The picker:
- Does not show `.backup` files exist
- Does not offer to clean them up
- Does not warn that a sync will overwrite the `.backup`

There are currently zero `.backup` files in the repository (verified), suggesting the existing cleanup is working or backups aren't accumulating. But the design relies on this being transparent to users.

### 1.5 How syncprotect Would Work in the Picker

Currently, the flow for a user is:
1. Open picker with `<leader>ac`
2. Navigate to `[Load Core Agent System]`
3. See preview showing counts (new: X, replace: Y) - no mention of protection
4. Press Enter
5. Confirm dialog says "Sync all" or "New only" - no mention of protection
6. Post-sync notification says "Protected: N files skipped" - only NOW visible

The user gets NO pre-flight visibility. This is a UX gap.

---

## 2. Strategic Alignment

### 2.1 Project Trajectory

The ROADMAP.md and the extension system show a clear trajectory:
- **Current**: 14 extensions, 96 context index entries, multi-system support (Claude + OpenCode)
- **Short-term**: Manifest-driven README generation, doc-lint CI, extension slim standard enforcement
- **Medium-term**: Extension hot-reload, context discovery caching

The project is building toward a **self-contained, redistributable agent system** that can be deployed to any repository. The `.syncprotect` mechanism is a fundamental primitive for this - it's the bridge between "shared global core" and "project-specific customization."

### 2.2 Backup Elimination Alignment

Eliminating backups aligns with the trajectory for two reasons:
1. **Reliability**: The `.syncprotect` mechanism is superior to backups - it prevents overwrites rather than recovering from them. Backups are reactive; `.syncprotect` is proactive.
2. **Cleanliness**: Backup files leak into git history if users aren't careful. The `.gitignore` should already exclude them, but the pattern itself is fragile.

### 2.3 At Scale: 30+ Extensions

With 30+ extensions, the system will need:
- **Fast extension discovery**: The current linear scan works at 14 extensions; at 30+ it may need caching (already on the roadmap)
- **Conflict detection across extensions**: Two extensions providing conflicting context or the same agent names will be hard to debug
- **Dependency graph**: The manifest already has a `dependencies` field but it's always empty `[]` — this needs to become functional at scale
- **Namespace isolation**: Context paths like `project/lean4/` work now; at scale, name collisions become more likely

---

## 3. Creative Improvement Proposals (Ranked by Impact/Effort)

### 3.1 HIGH IMPACT / LOW EFFORT: .syncprotect Status in Load Preview

**Proposal**: Before showing the sync confirmation, check if `.syncprotect` exists and add a "Protected Files" section to the `preview_load_all` function in `previewer.lua`.

The preview (currently at `previewer.lua:160-236`) could show:
```
Protected Files (.syncprotect): 3 files
  context/repo/project-overview.md  [protected - will skip]
  commands/custom-workflow.md       [protected - will skip]
  CLAUDE.md                         [protected - will skip]
```

This requires calling `load_syncprotect()` from within the preview function, which already imports `sync_ops`. Low effort because the function already exists; just needs to be called and displayed.

**File**: `previewer.lua:160-236` (preview_load_all function)
**Confidence**: HIGH

### 3.2 HIGH IMPACT / MEDIUM EFFORT: .syncprotect Wizard in Picker

**Proposal**: Add a new picker entry or key binding (e.g., `<C-p>` = "protect") that opens a `.syncprotect` editor overlay. Users can:
1. See all files that would be replaced in a sync
2. Check/uncheck which ones to protect
3. Write the `.syncprotect` file

This is medium effort because it requires a new UI component but builds on existing Telescope infrastructure.

**Confidence**: MEDIUM

### 3.3 HIGH IMPACT / MEDIUM EFFORT: Automatic .syncprotect from Extension State

**Proposal**: When an extension is loaded via `<leader>ac`, automatically add its merge target files to `.syncprotect`. This ensures `CLAUDE.md`, `settings.local.json`, and `context/index.json` (which receive extension-injected content) are never blindly overwritten by a sync.

Currently:
- Extensions inject sections into `CLAUDE.md` (tracked as `merged_sections` in `extensions.json`)
- Sync's section preservation in `sync_files()` handles `CLAUDE.md` and `OPENCODE.md` specially
- The `reinject_loaded_extensions()` function provides defense-in-depth

But this creates a multi-layer defense that's hard to reason about. A single `.syncprotect` that's auto-managed would be cleaner.

**Note**: This is somewhat in tension with the current defense-in-depth approach. Could be opt-in.

**Confidence**: MEDIUM

### 3.4 MEDIUM IMPACT / LOW EFFORT: Backup File Cleanup in /refresh Command

**Proposal**: Have the `/refresh` command scan for and report (optionally delete) `.backup` files created by `merge.lua`. The `/refresh` command already handles orphaned process cleanup - this would be a natural extension.

The pattern is: `find .claude/ -name "*.backup"` - list them, offer to delete.

**Confidence**: HIGH (low risk, addresses cleanup gap)

### 3.5 MEDIUM IMPACT / HIGH EFFORT: Per-File Merge Strategies in .syncprotect

**Proposal**: Evolve `.syncprotect` from a simple blocklist to a per-file merge strategy file:

```
# .syncprotect
# Format: path [strategy]
# Strategies: block (default), merge-ours, merge-theirs, prompt

context/repo/project-overview.md   block
CLAUDE.md                          merge-ours
commands/custom-workflow.md        block
```

This would enable intelligent sync behavior instead of binary block/allow. The `sync_files()` function at `sync.lua:232-285` would need to dispatch to different merge handlers.

**Confidence**: LOW-MEDIUM (high value long-term, significant complexity)

### 3.6 MEDIUM IMPACT / MEDIUM EFFORT: Picker as Documentation Surface

**Proposal**: Improve the Help entry (`is_help`) in the picker to serve as discoverable documentation. Currently the help shows keyboard shortcuts. It could also show:
- Current sync protection status
- How many extensions are available vs loaded
- A "quick start" for new users
- Links to README.md files

The help preview is at `previewer.lua:92-153` (preview_help function). It's already moderately rich.

**Confidence**: HIGH

### 3.7 LOW IMPACT / LOW EFFORT: Sync History in Picker Preview

**Proposal**: Log sync operations to a simple `~/.claude/sync-history.json` (timestamps, what was synced, what was protected). Show last sync date/status in the "Load Core Agent System" preview.

This gives users orientation ("Last synced: 3 days ago") without adding complexity.

**Confidence**: MEDIUM

---

## 4. Extension Development Experience

### 4.1 Current Extension Development Workflow

The `extension-development.md` guide describes a 7-step process. In practice, the actual system has diverged from this documentation:

**Documentation says**:
- `merge_targets` is an array: `["...", "..."]`
- Use `scripts/merge-extensions.sh` for merging
- Register in `.claude/extensions/manifest.json`

**Actual system uses**:
- `merge_targets` is an object with named keys (`claudemd`, `settings`, `index`, `opencode_json`)
- No `merge-extensions.sh` script (the loader does this dynamically)
- Extensions in subdirectories, discovered via filesystem, no central manifest file to register in

**Confidence**: HIGH - the guide is significantly outdated.

This is a real friction point for new extension developers. The guide is the primary reference but doesn't match reality.

### 4.2 Manifest Format Inconsistencies

All 14 manifests use `"task_type": "single_string"` but the documentation shows `"task_types": ["array"]`. Two extensions (`filetypes` and `memory`) don't have a `task_type` at all - they're utility extensions without task routing.

The `dependencies` field is present in all manifests but always empty `[]`. This is dead weight and misleads extension developers who might try to use it.

### 4.3 Manifest Validation Gap

There's no validator for manifests before loading. An extension with a typo in `merge_targets` (e.g., `"claudemd"` vs `"claudeMd"`) would silently fail to inject its section into CLAUDE.md. The `verify_extension()` function exists in `shared/extensions/verify.lua` but it only runs post-load.

**Proposal**: Add a `manifest.validate()` function that checks required fields and known key names before attempting to load.

### 4.4 The "Slim Standard" Gap

The `extension-slim-standard.md` standard (max 60 lines for EXTENSION.md) exists as documentation but:
- No automated enforcement exists
- The ROADMAP.md explicitly lists "Extension slim standard enforcement" as a TODO
- Current EXTENSION.md files range significantly in size

The proposed `lint script` in the roadmap would fill this gap.

---

## 5. Discoverability Improvements

### 5.1 New User Experience

Currently, new users have no obvious path to understanding the system:
- `README.md` in `.claude/` is the starting point but references many other files
- The picker (`<leader>ac`) is the primary interaction surface but has no onboarding flow
- No "what is this?" entry in the picker for first-time users

**Proposal**: Add a `[Getting Started]` heading entry in the picker that, when selected, opens `.claude/README.md` in a buffer. This is the picker's Help entry expanded.

### 5.2 Context Index Discoverability

There are 96 context index entries but no way to browse them from the picker or from Neovim. Users who want to know "what context does the lean extension provide?" must read `index-entries.json` manually.

**Proposal**: Add a `[Context Files]` section to the picker (similar to the existing `Docs` section) that lists context files organized by extension, filterable by load_when conditions.

### 5.3 Extension README Quality

All 14 extensions have README files (achieved via task 396). However, the `check-extension-docs.sh` lint script validates structure but not content quality. Users trying to understand what an extension does have to read both `README.md` and `EXTENSION.md` to get a complete picture.

**The picker already serves as documentation** via the extension preview (showing provides, installed files, etc.). This is actually better than the README for active users.

### 5.4 System Health Check

The ROADMAP mentions no "system health check" command but it would be valuable. A `/health` command could:
- Check all loaded extensions are current (vs `update-available`)
- Verify index.json has no orphaned entries
- Check for `.backup` file accumulation
- Verify all merge targets are intact (using the existing `verify_all()` function in `shared/extensions/init.lua:644-659`)

---

## 6. Long-Term Vision

### 6.1 The Picker as Control Plane

The `<leader>ac` picker is evolving toward being the complete control plane for the agent system. Currently it handles:
- Extension load/unload
- Artifact sync
- Command execution
- File editing

The natural evolution is for it to also handle:
- `.syncprotect` management
- System health status
- Sync history and rollback
- Extension dependency visualization

### 6.2 .syncprotect as a Declarative Layer

The current `.syncprotect` is imperative (list of blocked files). The long-term vision should be declarative: a file that declares the *intent* of the project's customizations.

A project that's done significant customization might have:
```
# Intent: This project uses custom task routing for epidemiology work
# The epi extension's routing is customized and must not be overwritten
CLAUDE.md                              merge-ours    # custom routing added
.claude/commands/research.md           block         # custom research command
.claude/context/index.json             merge-ours    # extension entries must survive
```

This aligns with the trend in the codebase toward tracking intent (e.g., `merged_sections` tracking in `extensions.json`).

### 6.3 Extension Dependency Management

The `dependencies` field in manifests is universally empty. At 14 extensions this is fine. At 30+ extensions, some natural dependencies emerge:
- `formal` + `lean` are often loaded together (Lean theorem provers for formal logic)
- `latex` + `present` overlap (presentation generation often needs LaTeX)
- `founder` might depend on `python` for data analysis scripts

A real dependency graph would enable:
- Automatic load-order resolution
- Conflict detection
- Bulk operations ("load all dependencies of lean")

This is medium-term work but the manifest schema already has the field.

### 6.4 Backup Elimination - The Right Design

The backup mechanism in `merge.lua` exists as safety net for merge operations. The right long-term design:

1. **`.syncprotect` handles pre-sync protection** (preventing overwrites before they happen)
2. **Git handles post-sync recovery** (users can `git diff` and `git checkout` if something goes wrong)
3. **Extension tracking handles section injection recovery** (`merged_sections` in `extensions.json` + `reinject_loaded_extensions()`)

Backups are a fourth layer that duplicates git's role. They could be eliminated if:
- `.syncprotect` is reliably populated (manually or auto-generated)
- The "New only" sync option is the default (not "Sync all")
- The picker preview shows what will change before confirming

---

## 7. Confidence Levels by Finding

| Finding | Confidence | Notes |
|---------|-----------|-------|
| Picker has NO .syncprotect visibility | HIGH | Verified via code inspection |
| Backup files created silently | HIGH | `merge.lua:94-104` confirmed |
| No existing .backup files | HIGH | Verified via filesystem check |
| extension-development.md is outdated | HIGH | Manifest format mismatch confirmed |
| `dependencies` field always empty | HIGH | Verified across all 14 manifests |
| `task_type` vs `task_types` inconsistency | HIGH | Only 2 extensions lack task_type |
| Extension slim standard not enforced | HIGH | No lint script exists |
| 96 context entries, no picker browsing | HIGH | Verified via index.json |
| Auto-.syncprotect from extension state | MEDIUM | Design pattern, not yet validated |
| Per-file merge strategies viable | LOW-MEDIUM | Significant rework required |
| Extension dependency graph needed at scale | MEDIUM | Speculative, based on current growth |
