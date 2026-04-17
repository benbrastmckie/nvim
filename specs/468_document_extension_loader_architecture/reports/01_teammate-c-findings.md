# Teammate C (Critic) Findings: Task 468

**Task**: Document extension loader architecture and .claude/ lifecycle
**Role**: Critic - identify gaps, shortcomings, and blind spots

---

## Key Findings

### Finding 1: Extension-system.md Has Multiple Factual Errors

The primary documentation file `.claude/docs/architecture/extension-system.md` contains several
inaccuracies relative to the actual code in `init.lua` and `merge.lua`:

**a) CLAUDE.md generation is documented as section injection (stale)**

The doc describes the load/unload process using `inject_section()` and `remove_section()`:
```
6. Merge shared files (process_merge_targets):
   a. inject_section() into CLAUDE.md (claudemd merge target)
3. Remove merged content:
   a. remove_section() from CLAUDE.md
```

The actual code (`init.lua:81-83`, `init.lua:153-155`, `init.lua:511-518`) shows CLAUDE.md is
a **computed artifact** regenerated from scratch via `generate_claudemd()` after every load/unload.
The `inject_section()` approach was replaced. The code comments explicitly say:
```lua
-- Config markdown (CLAUDE.md or OPENCODE.md) is now a computed artifact.
-- Section injection is skipped here; generate_claudemd() regenerates the file
```

**b) Unload "hard block" documented as "proceed with user confirmation" (wrong)**

The doc says:
```
b. If dependents exist, show warning: "Extension 'X' is required by: Y, Z"
c. Proceed with unload if user confirms (dependents are NOT cascade-unloaded)
```

The actual code (`init.lua:575-587`) is a **hard block** with no user-confirmation path:
```lua
-- Hard block: prevent unloading core (or any extension) when dependents are loaded.
-- This is a hard error, not just a warning, to prevent orphaned dependent extensions.
if #dependents > 0 then
  ...
  return false, msg  -- no confirm path, always returns false
end
```

**c) Loader functions list is incomplete**

The doc lists only 6 functions but the actual `loader.lua` has 10 public functions:
- Missing from doc: `copy_hooks()`, `copy_systemd()`, `copy_docs()`, `copy_templates()`,
  `copy_root_files()`, `copy_data_dirs()`

The load sequence in the doc (step 4) also omits these copy functions:
```
4f. copy_scripts()
4g. copy_data_dirs() (merge-copy semantics)
```
Missing: copy_hooks, copy_docs, copy_templates, copy_systemd, copy_root_files.

**d) Extension layout diagram omits multiple categories**

The extension directory structure shown lists only: `manifest.json`, `EXTENSION.md`,
`index-entries.json`, `settings-fragment.json`, `agents/`, `skills/`, `rules/`, `commands/`,
`context/`, `scripts/`. Missing: `hooks/`, `docs/`, `templates/`, `systemd/`, `root-files/`,
`merge-sources/` (used by core).

### Finding 2: Core Extension Differs from Standard Extension Docs Pattern

The `creating-extensions.md` guide states `EXTENSION.md` is required and the manifest
claudemd source points to it. However, the core extension uses a different pattern:
- Source: `merge-sources/claudemd.md` (353 lines) rather than `EXTENSION.md` (exists but
  is the README-style overview, not the claudemd content)
- The core manifest: `"source": "merge-sources/claudemd.md"`
- Other extensions: `"source": "EXTENSION.md"`

The `merge-sources/` directory and the `claudemd.md` filename variant are **not documented
anywhere in the guides**. Only the header comment in `.claude/CLAUDE.md` and
`.claude/templates/claudemd-header.md` mentions it:
```
<!-- Edit source files in .claude/extensions/*/merge-sources/claudemd.md or EXTENSION.md -->
```

This creates confusion for extension creators: which pattern is correct? Why does core diverge?

### Finding 3: The "Layer 1 vs Layer 2" Distinction Is Not Explicitly Stated Anywhere

The task description emphasizes distinguishing:
- Layer 1: Neovim Lua code in `lua/neotex/plugins/ai/shared/extensions/`
- Layer 2: `.claude/` files consumed by Claude Code

This two-layer framing does **not appear in any existing documentation**. Current docs refer
to "the extension loader" without distinguishing that it is Neovim plugin code operating
at a completely different level than the files it manages. Claude Code agents reading these
docs would not understand this distinction.

The `.claude/context/architecture/context-layers.md` defines context layers (agent context,
project context, memory) but does not explain the meta-architectural distinction between the
Lua loader layer and the agent system layer.

### Finding 4: Sync System Documentation Is Missing

The `sync.lua` module (`lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`)
is a separate, non-trivial system that:
1. Uses `inject_section()` (not `generate_claudemd()`) for sync reinsertion
2. Has its own `.syncprotect` file mechanism
3. Sources core from `extensions/core/` not `.claude/`
4. Is triggered via `Ctrl-l` in the picker

This sync subsystem is referenced in `CLAUDE.md` (Syncprotect section) but:
- There is no architecture doc covering the sync system
- The relationship between "sync" (reinjection using old approach) vs "load/unload"
  (generate_claudemd approach) is not documented
- This represents a latent inconsistency: sync uses `inject_section` while load/unload
  uses `generate_claudemd`

### Finding 5: The extension-development.md Context Guide Is Stale

`.claude/context/guides/extension-development.md` says:
```
### 2. CLAUDE.md Merging
Extension `EXTENSION.md` content is merged into `.claude/CLAUDE.md` at the section
identified by `section_id`.
```

This describes the old section-injection approach. The actual behavior uses `generate_claudemd()`
which rebuilds the entire file from all loaded extension sources. The `section_id` field in
manifests is now vestigial for load/unload operations (still used by sync.lua however).

### Finding 6: Task Description's "~210 files" Claim Is Accurate but the Context Is Misleading

TODO.md line 102 says "Loader copies ~210 files from `extensions/core/`". The actual count
is 218 files (verified: `find .claude/extensions/core -type f | wc -l` = 218).

The ~210 figure is close but should be verified. More importantly, the task description does
not note the distinction between files **tracked by loader** (in `extensions.json`) vs files
**present in the repo** at `.claude/extensions/core/` -- these may differ if some files exist
only in the source but are never installed (e.g., `EXTENSION.md` vs `merge-sources/claudemd.md`
for the core extension).

### Finding 7: Dependency Task 470's Bug Fix Is Only Partially Documented

Task 470 fixed `copy_context_dirs()` to handle root-level context files (not just
subdirectories). This is now implemented with the `elseif vim.fn.filereadable(source_ctx_dir) == 1`
branch in `loader.lua:219-223`. However:
- The existing `extension-system.md` does not document this dual behavior (directory vs file
  in `provides.context`)
- The `creating-extensions.md` guide's `provides.context` examples only show directory paths
- Developers writing extensions would not know they can list individual files in `context`

### Finding 8: README.md for Core Extension Exists (Contrary to Task 466 Description)

The TODO.md task 466 description mentions "Create a README.md for the core extension".
However, there IS already an `EXTENSION.md` in core which serves as its overview document.
The gap is that core has no `README.md` at its extension root. The `check-extension-docs.sh`
script validates this. This is a pre-existing gap, not caused by this task, but the task's
scope should clearly state whether updating `EXTENSION.md` is in scope.

### Finding 9: The CLAUDE.md "Do Not Edit" Header Is Not Documented as a Convention

`.claude/CLAUDE.md` has the header:
```
# Agent System
This file is generated automatically from loaded extensions. Do not edit directly.
```

This "computed artifact" pattern -- where CLAUDE.md should never be hand-edited -- is
important for developers and agents to understand but is not documented as a convention
anywhere. The `claudemd-header.md` template establishes this, but the rule is implicit.

---

## Recommended Approach

### Priority 1: Fix Factual Errors in extension-system.md

These must be corrected first since they are architectural misrepresentations:
1. Replace `inject_section()` with `generate_claudemd()` in load process documentation
2. Change unload dependents behavior from "user confirms" to "hard block, error returned"
3. Expand loader functions list to include all 10 functions
4. Expand load sequence (step 4) to include all copy functions
5. Expand extension directory structure to include all categories

### Priority 2: Document the Two-Layer Architecture Distinction

Create or update a doc (possibly in `.claude/context/architecture/`) that explicitly explains:
- Layer 1: Neovim plugin code at `lua/neotex/plugins/ai/shared/extensions/` - manages which
  files are present in `.claude/`
- Layer 2: `.claude/` files consumed by Claude Code agents
- The loader has no Claude Code dependency and no `.claude/` runtime dependency
- This distinction matters because changing Layer 1 requires Neovim reload; changing Layer 2
  requires extension reload

### Priority 3: Clarify the EXTENSION.md vs merge-sources/claudemd.md Pattern

Document explicitly:
- Standard extensions: use `EXTENSION.md` as claudemd source
- Core extension diverges: uses `merge-sources/claudemd.md` due to its much larger content
- The `merge-sources/` directory pattern enables separation of the README (EXTENSION.md) from
  the injected system content (merge-sources/claudemd.md)

### Priority 4: Document Sync vs Load/Unload CLAUDE.md Strategy

Clarify the relationship between:
- `generate_claudemd()` used by load/unload (full regeneration, no markers)
- `inject_section()` used by sync/reinject operations (section-based with markers)
- Whether this represents technical debt or intentional design

### Priority 5: Document copy_context_dirs() Dual Behavior

Update `provides.context` documentation to show it supports both directory names and
individual file paths (post-task-470 fix).

---

## Evidence / Examples

**CLAUDE.md header comment** (`.claude/CLAUDE.md:6`):
```
<!-- Edit source files in .claude/extensions/*/merge-sources/claudemd.md or EXTENSION.md -->
```
This is the only place `merge-sources/claudemd.md` is mentioned.

**Hard block code** (`init.lua:575-587`):
```lua
if #dependents > 0 then
  ...
  return false, msg
end
```
vs doc claim: "Proceed with unload if user confirms"

**Computed artifact comments** (`init.lua:81-83`):
```lua
-- Config markdown (CLAUDE.md or OPENCODE.md) is now a computed artifact.
-- Section injection is skipped here; generate_claudemd() regenerates the file
-- from all loaded extensions after each load/unload operation.
```
vs doc: "inject_section() into CLAUDE.md"

**Full loader function list** from `loader.lua`:
- `copy_simple_files()` (agents, commands, rules)
- `copy_skill_dirs()`
- `copy_context_dirs()`
- `copy_scripts()`
- `copy_hooks()`
- `copy_systemd()`
- `copy_docs()`
- `copy_templates()`
- `copy_root_files()`
- `copy_data_dirs()`
- `check_conflicts()`
- `remove_installed_files()`

**Docs list only**: copy_simple_files, copy_skill_dirs, copy_context_dirs, copy_scripts,
check_conflicts, remove_installed_files.

**Files not in scope per task 468 but needing updates**:
- `.claude/docs/architecture/extension-system.md` - primary target, multiple issues
- `.claude/docs/guides/creating-extensions.md` - incomplete provides, EXTENSION.md pattern
- `.claude/context/guides/extension-development.md` - stale CLAUDE.md merge description
- `.claude/extensions/README.md` - partially current, but load steps omit hooks/systemd/docs
- `.claude/context/architecture/context-layers.md` - doesn't explain loader vs agent layers
- No doc exists for the sync subsystem at all

---

## Confidence Level

**High confidence** for findings 1, 2, 5, and 7 -- verified directly by reading both the
code (`init.lua`, `loader.lua`, `merge.lua`) and the corresponding documentation.

**High confidence** for finding 3 -- searched all docs for "Layer 1", "Layer 2", "two-layer",
"Lua loader" etc. and found no matches.

**Medium confidence** for finding 4 (sync system) -- found the code paths but did not read
all of sync.lua; the architectural concern is real but the sync/generate_claudemd relationship
needs validation to confirm it's truly inconsistent rather than intentional.

**Medium confidence** for finding 8 (core README) -- the check-extension-docs.sh behavior
would need to be run to confirm what exactly it validates.
