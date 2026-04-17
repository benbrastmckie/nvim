# Phase 6 Results: Migration Support and Cleanup

- **Phase**: 6 of 6
- **Status**: COMPLETED
- **Date**: 2026-04-16

## Summary

Migration detection, sync migration notices, manifest finalization, documentation
updates, and virtual-reference cleanup are complete. The core extension is now a
fully real, physical extension with no remaining virtual-era artifacts.

## Changes Made

### 1. Migration Detection Helper (`init.lua`)

Added `detect_legacy_core(project_dir, config)` function that checks for legacy
core repos: `.claude/agents/` contains `.md` files but `extensions.json` does not
list core as loaded. Returns `(is_legacy, detail_string)`.

### 2. Migration Behavior in Load Function (`init.lua`)

When `manager.load("core", ...)` is called, the function now runs
`detect_legacy_core()` before proceeding. If a legacy layout is detected, a
`vim.notify` INFO message is shown explaining that the loader will migrate the
files. The actual file overwrite uses the existing conflict-detection/overwrite
path (unchanged) -- the confirmation dialog shows the conflict count.

### 3. Sync Migration Notice (`sync.lua`)

In `load_all_globally()`, after scanning artifacts, added a legacy detection block
that checks `project_dir/.claude/agents/` existence and whether core appears in
`extensions.json`. If the repo is legacy (agents dir present, core not tracked), a
formatted INFO notice is shown before the sync confirmation dialog, directing users
to load core via the extension picker after syncing.

### 4. Manifest Final State (`manifest.json`)

Added `claudemd-header.md` to the `templates` provides array (it was present in
the filesystem but missing from the manifest). The `"docs": "docs"` entry is
intentionally left as-is -- docs are synced via the sync system, not per-project
extension load, so the string-format marker is harmless.

### 5. Virtual Reference Cleanup (`EXTENSION.md`)

Removed the legacy note "virtual in pre-migration systems, real extension
post-migration" from `EXTENSION.md`. Replaced with a clean forward-looking
statement.

### 6. Documentation Update (`README.md`)

Updated `.claude/README.md` extensions table to highlight core as the foundational
extension. Added explanatory paragraph describing the real-extension architecture,
where core files live in `extensions/core/` and sync sources from there.

### 7. Plan Status

Updated `plans/01_restructure-core-extension.md`:
- Top-level status: [NOT STARTED] -> [COMPLETED]
- Phase 6 heading: [NOT STARTED] -> [COMPLETED]

## Skipped Items (Per Plan Instructions)

- `core-index-entries.json` loading code in `init.lua`: kept as-is per plan
  instruction ("keep as static fixture -- task 466 will handle converting it")

## Verification Notes

- `grep -rn "virtual" lua/neotex/plugins/ai/shared/extensions/` returns zero hits
- `detect_legacy_core()` guards against false positives via extensions.json check
- Migration notice in sync.lua is non-blocking (INFO level, does not prevent sync)
- All existing extensions with `"dependencies": ["core"]` unaffected (no interface changes)
