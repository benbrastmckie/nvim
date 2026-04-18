# Teammate C (Critic) Findings - Task 478

## Summary

Task 478 has a fundamentally correct premise: extension core docs contain Neovim-specific
references that would contaminate other projects. However, several assumptions require
correction, and the implementation has a split-path problem that the task description misses.

---

## Key Findings

### Finding 1: project-overview.md IS Copied by the Loader (Confirmed)

**Confidence: HIGH**

The manifest.json `provides.context` array contains `"repo"` (the directory), which causes
`copy_context_dirs()` to recursively copy the entire `extensions/core/context/repo/` directory
-- including `project-overview.md`, `update-project.md`, and `self-healing-implementation-details.md`.

This is confirmed by:
- `manifest.json` line 125: `"repo"` in `provides.context`
- `loader.lua` `copy_context_dirs()`: for directory entries, calls `scan_directory_recursive()`
  and copies all files within
- The deployed `extensions/core/context/repo/` contains exactly these 3 files and all 3 appear
  in `.claude/context/repo/`

**Implication**: project-overview.md is definitely copied on `manager.load("core")`. This
confirms the contamination vector is real.

### Finding 2: The syncprotect File Already Partially Addresses This -- But Only for Sync

**Confidence: HIGH**

The `.syncprotect` file at project root already contains `context/repo/project-overview.md`.
The sync operation (`sync.lua:1029`) auto-seeds `.syncprotect` with this entry when no
syncprotect file exists at a target repo.

**However**, `.syncprotect` only applies to the sync code path (the "Load Core" / Ctrl-l
picker operation in `sync.lua`). It does NOT apply to `manager.load()` in `init.lua`. The
extension loader in `init.lua` has zero syncprotect handling -- confirmed by grepping the
entire `lua/neotex/plugins/ai/shared/extensions/` directory for "syncprotect" with no results.

**Implication**: When a user loads the core extension via `<leader>ac` -> manager.load(), the
project-overview.md IS overwritten regardless of `.syncprotect`. The protection only works
during sync operations, not load operations. This is a real gap -- the task description's
assumption that `.syncprotect` handles this is incorrect for the load path.

### Finding 3: update-project.md Partially Handles the Missing Case -- But Not Detectably

**Confidence: HIGH**

`extensions/core/context/repo/update-project.md` has a "When to Use" section that mentions:
> Generate or update `project-overview.md` when:
> - The agent system is first copied to a new repository

However, this is passive documentation -- it requires the user to know to look for it. There
is no mechanism to actively detect a missing or stale project-overview.md and prompt the user.
The CLAUDE.md merge source (`claudemd.md` line 28) already includes the message:
> "If project-overview.md doesn't exist, see `.claude/context/repo/update-project.md`"

**Implication**: The fallback language in CLAUDE.md is already there. The task needs to decide
whether this passive reference is sufficient or whether active detection (e.g., checking file
existence at preflight, creating a task suggestion) is warranted.

### Finding 4: `always: true` Index Entry Creates a Broken Reference Risk

**Confidence: HIGH**

`index-entries.json` sets `project-overview.md` to `"always": true`. If project-overview.md
is excluded from the copy (either by removing it from the manifest or skipping it in the loader),
the index entry would point to a file that doesn't exist. This would produce a broken context
reference for all agents that try to load it.

There are two sub-scenarios:
- **Scenario A** (file excluded from copy): The index entry must also be conditionally excluded,
  or the file must be replaced with a stub pointing to update-project.md.
- **Scenario B** (file still copied but with generic content): Less clean -- agents get
  an nvim-specific file in non-nvim projects.

**The cleanest solution**: Keep the index entry but replace the source
`extensions/core/context/repo/project-overview.md` with a generic stub that instructs agents
to consult `update-project.md`. The per-project file gets generated separately (via task or
manual step) and protected by `.syncprotect`. This avoids the broken-reference risk.

### Finding 5: `<leader>ac` References Are in Four Distinct Files

**Confidence: HIGH**

Files containing `<leader>ac` in core extension (source) that would be deployed to other projects:

1. `extensions/core/context/repo/project-overview.md:11` -- "extension picker (`<leader>ac`)"
2. `extensions/core/context/guides/loader-reference.md:141` -- "`picker.lua`... launched from `<leader>ac`"
3. `extensions/core/context/guides/extension-development.md:143` -- "Load via the extension picker (`<leader>ac`)"
4. `extensions/core/templates/extension-readme-template.md:50` -- "Loaded via `<leader>ac` in Neovim"

Additionally, `extensions/README.md` contains `<leader>ac` (line 42) but this file is NOT in
the `provides` lists and thus not deployed -- it stays local.

The deployed `context/` and `templates/` files (items 1-4) are the contamination sources.

### Finding 6: extensions.json source_dir Paths Are Absolute and Machine-Specific

**Confidence: HIGH**

`extensions.json` contains absolute paths like
`/home/benjamin/.config/nvim/.claude/extensions/core`. These are written by the Lua loader at
load time (`state.lua` writes the path of the extension at load time), NOT hand-written.

The task description mentions "Zed report flagged" source_dir paths. These are auto-generated
by the Lua loader when `manager.load()` runs in Neovim -- they are not a contamination problem
for other projects because `extensions.json` is per-project state, not synced content.

**Implication**: The source_dir issue is not a real problem for this task. It's a local
state artifact.

### Finding 7: Other Neovim-Specific References in Core Extension Docs (Beyond `<leader>ac`)

**Confidence: HIGH**

`loader-reference.md` describes the system in terms of Lua files (`init.lua`, `loader.lua`,
`picker.lua`, `merge.lua`, `state.lua`, `config.lua`, `manifest.lua`, `verify.lua`) and
explicitly references "Telescope picker UI" at line 141. These are implementation details
of the Neovim loader.

`extension-system.md` (in docs/, not context/) references "Layer 1: Neovim Lua Loader" and
lists Lua file names -- but `docs/` is also in the `provides.docs` array and gets copied.

The `extension-readme-template.md` says "Loaded via `<leader>ac` **in Neovim**" -- this is
the most egregious because templates get copied and reused by extension authors.

`docs/architecture/extension-system.md` is more borderline: it describes the loader
architecture truthfully (it IS a Lua loader for Neovim). For non-Neovim contexts, this doc
should probably acknowledge that the system can be loaded via shell scripts
(`install-extension.sh`) as an alternative.

---

## Potential Issues

### Issue 1: Race Condition on Re-Load

If a user loads core (which copies a generic project-overview.md stub), manually generates a
project-specific file, then re-loads core -- the stub will OVERWRITE the custom file. The
`manager.load()` path does not check `.syncprotect`. This race condition exists today for any
file in the `provides.context` list.

**Recommended mitigation**: Extend `manager.load()` to respect `.syncprotect` (read it before
copying context files and skip protected paths). This is the principled fix and makes the
behavior consistent between load and sync paths.

### Issue 2: User Who Intentionally Skips project-overview.md

If the detection mechanism creates a task every time project-overview.md is missing, it will
be noisy for users who run the agent system without customizing project-overview. The CLAUDE.md
passive fallback (already present) may be sufficient; active task creation should be
opt-in or one-shot (e.g., only at first load, not on every command).

**Recommended approach**: Do detection at preflight of the first command run (e.g., via a
hook or preflight check), NOT on every command invocation. Or use a flag in state.json to
record "user acknowledged missing project-overview" to suppress future nudges.

### Issue 3: Broken Index Reference If File Is Excluded

If project-overview.md is removed from the copy list but the `always: true` index entry
remains, agents will attempt to load a missing file. The context loader may silently skip
it or may error -- this depends on how Claude Code handles missing @-referenced files.

**Recommended approach**: Either replace with a generic stub (always safe), or add a
conditional index entry (complex) -- the stub approach is simpler and more robust.

### Issue 4: loader-reference.md Is Inherently Neovim-Specific

`loader-reference.md` documents the internal Lua implementation of the extension loader.
This document is only meaningful for developers who work on the Neovim-hosted loader.
For a Python project using the agent system, this file is irrelevant noise. Consider
whether it belongs in `context/` (loaded for agents) or `docs/` (architecture reference).

Currently it is in `context/guides/` which means it gets loaded for agents -- this is
probably wrong even for Neovim projects. Agents don't need to know about the internal Lua
implementation to use the extension system.

---

## Recommended Approach

Based on the evidence, the cleanest implementation is:

### Part 1: Replace `<leader>ac` with Generic Language

In all four deployed files, replace `<leader>ac` (and similar Neovim-specific phrasing) with
"extension picker" or "via the extension loader". The `extensions/README.md` already uses
this pattern at line 39: "Extensions are loaded via the editor's extension picker".

Specific replacements:
- `project-overview.md:11`: Replace "`<leader>ac`" with "the extension picker"
- `loader-reference.md:141`: Replace "`<leader>ac`" with "the extension picker"
- `extension-development.md:143`: Replace "`<leader>ac` " with "the extension picker"
- `extension-readme-template.md:50`: Replace "Loaded via `<leader>ac` in Neovim." with
  "Loaded via the extension picker."

### Part 2: Replace project-overview.md Source With a Generic Stub

Replace `extensions/core/context/repo/project-overview.md` content with a generic stub that:
- Explains what project-overview.md is for
- Instructs agents to read `update-project.md` if the file seems generic
- Notes that a project-specific version should be generated for this repository

This stub will be copied to all projects. The per-project customization stays protected
by `.syncprotect`. The index entry remains valid (always points to an existing file).

### Part 3: Extend manager.load() to Respect .syncprotect

Add syncprotect checking to `manager.load()` for context file copying. This makes the
protection consistent across both code paths (load and sync). Implementation: before
`copy_context_dirs()`, read `.syncprotect` and skip any file whose relative path matches.

### Part 4: Active Detection Mechanism (Keep It Light)

The CLAUDE.md merge source already has the passive fallback message. For active detection:
- Add a check in the preflight hook or a new hook that fires once per session
- If `.claude/context/repo/project-overview.md` contains the generic stub marker (e.g.,
  a header like `# Project Overview (Generic Stub)`), offer to create a task for generation
- Store "offered_project_overview_task: true" in state.json to avoid repeated prompts
- This is a low-noise, one-shot nudge rather than continuous nagging

---

## Evidence References

| Claim | Evidence Location |
|-------|-------------------|
| project-overview.md IS copied | `manifest.json:125` (repo in provides.context), `loader.lua:copy_context_dirs()` |
| syncprotect not in load path | grep of `lua/neotex/plugins/ai/shared/extensions/` returns no syncprotect hits |
| syncprotect IS in sync path | `sync.lua:1023-1073` (loads and applies .syncprotect) |
| `<leader>ac` in 4 deployed files | grep output above |
| `always: true` on index entry | `index-entries.json` grep output |
| update-project.md passive fallback | `claudemd.md:28` |
| extensions.json source_dir auto-generated | `state.lua` (written at load time by Lua loader) |

---

## Confidence Summary

| Finding | Confidence |
|---------|-----------|
| project-overview.md is copied by loader | HIGH |
| syncprotect does NOT apply to load path | HIGH |
| 4 files need `<leader>ac` replacement | HIGH |
| `always: true` creates broken-reference risk | HIGH |
| extensions.json source_dir is auto-generated, not a problem | HIGH |
| update-project.md passive fallback already exists | HIGH |
| loader-reference.md is implementation-specific, borderline for context/ | MEDIUM |
