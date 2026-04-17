# Teammate A Findings: Extension Loader Architecture

**Task**: 468 - Document extension loader architecture and .claude/ lifecycle
**Role**: Primary approach - code investigation and documentation accuracy audit

---

## Key Findings

### Finding 1: CLAUDE.md is a Fully Computed Artifact (Major Architectural Change)

The most critical inaccuracy across all documentation is the treatment of CLAUDE.md as a
section-injected file. **The code has moved to full regeneration:**

- `merge.lua:generate_claudemd()` (line 549) builds CLAUDE.md from scratch on every
  load/unload operation: header template + all loaded extensions' `merge-sources/claudemd.md`
  fragments, concatenated in dependency order (core first).
- `init.lua:manager.load()` (line 513) and `manager.unload()` (line 642) both call
  `merge_mod.generate_claudemd()` after updating state — never `inject_section()`.
- `init.lua:process_merge_targets()` (lines 80-88) explicitly comments that the `claudemd`
  merge target is **skipped** for section injection: *"Config markdown (CLAUDE.md or OPENCODE.md)
  is now a computed artifact. Section injection is skipped here."*
- The header template is at `.claude/extensions/core/templates/claudemd-header.md`
- Content fragments live at `.claude/extensions/*/merge-sources/claudemd.md` (NOT
  `EXTENSION.md` directly — they use a `merge-sources/` subdirectory)
- The generated CLAUDE.md starts with: `# Agent System\n\nThis file is generated automatically
  from loaded extensions. Do not edit directly.`

**Documents with stale section-injection references:**
- `extension-system.md` (lines 23, 187-189): shows `<!-- SECTION: extension_latex -->` markers
- `extension-system.md` (line 175-180): documents `inject_section()` as the CLAUDE.md merge function
- `extension-development.md` (lines 99-102): "Extension `EXTENSION.md` content is merged into
  `.claude/CLAUDE.md` at the section identified by `section_id`."
- `creating-extensions.md` (lines 113-115): "Content injected into CLAUDE.md when loaded"
- `creating-extensions.md` (line 607): `grep "extension_your_domain" .claude/CLAUDE.md` —
  this test would fail since there are no section markers anymore
- `extensions/README.md` (lines 44-48): step 4 says "Merge targets are processed (CLAUDE.md
  injection, index.json entry merging)"; also says verification checks "EXTENSION.md section
  was injected"

### Finding 2: Source File for CLAUDE.md Content Uses `merge-sources/` Not `EXTENSION.md`

The core extension's manifest.json shows:
```json
"claudemd": {
  "source": "merge-sources/claudemd.md",
  "target": ".claude/CLAUDE.md",
  "section_id": "core"
}
```

Most documentation examples still use `EXTENSION.md` as the source, e.g.:
- `extension-system.md` (line 135): `"source": "EXTENSION.md"`
- `creating-extensions.md` (line 89): `"source": "EXTENSION.md"`
- `extension-development.md` (line 50): `"source": "EXTENSION.md"`

The `section_id` field in `merge_targets.claudemd` is also no longer operative; the code
in `generate_claudemd()` does not use `section_id` at all.

**Note**: Both `EXTENSION.md` (in extension root) and `merge-sources/claudemd.md` exist in
the core extension. The loader code only uses the manifest's `merge_targets.claudemd.source`
field, which for core points to `merge-sources/claudemd.md`. Non-core extensions may still
use `EXTENSION.md` if that is what their manifest declares. This needs clarification.

### Finding 3: Unload Safety Is Stronger Than Documented

`extension-system.md` (line 272-274) says:
> "The user can confirm to proceed. Unload does NOT cascade -- only the named extension is removed."

The actual code (`init.lua` lines 575-587) shows a **hard block** — not a warning with
confirmation:
```lua
if #dependents > 0 then
  helpers.notify(msg, "ERROR")
  return false, msg
end
```
There is no confirmation dialog for the dependent-block; it is an unconditional error. This
differs from what the extension development guide documents.

### Finding 4: Additional File Copy Categories Not Documented

The loader (`init.lua` lines 396-451) copies these categories, but `extension-system.md`
and `creating-extensions.md` do not document all of them:

- `hooks` — `.sh` files with execute permissions preserved (documented only in README)
- `docs` — documentation files (not shown in creating-extensions.md template)
- `templates` — template files (not shown in creating-extensions.md template)
- `systemd` — systemd unit files (not documented anywhere in guides)
- `root_files` — files placed at `.claude/` root (not in creating-extensions.md)
- `data` — merge-copy semantics, copied to project root not `.claude/` (partially documented)

The `manifest.lua:VALID_PROVIDES` array (line 12) lists all 12 valid categories:
`agents, skills, commands, rules, context, scripts, hooks, data, docs, templates, systemd, root_files`

Creating-extensions.md only shows 7 in templates.

### Finding 5: extensions/README.md CLAUDE.md Injection Steps Are Stale

`extensions/README.md` (lines 44-52), under "When an extension is loaded", describes:
> "4. Merge targets are processed (CLAUDE.md injection, index.json entry merging, settings merging)
>    - Core index entries are loaded via core's `merge_targets.index`..."

This description conflates old section-injection with new computed artifact generation.
The actual step 4 is: "CLAUDE.md is fully regenerated from all loaded extensions' content."

Additionally the verification step at line 107 says:
> "EXTENSION.md section was injected into CLAUDE.md"

This is outdated. Verify.lua now checks that the extension's source fragment's first
non-empty line is present in CLAUDE.md (fingerprint check), not that section markers exist.

### Finding 6: Extension Development Guide Has Outdated Path References

`extension-development.md` (lines 11-17) shows the extension structure template with
`context/index.json` inside the extension directory, but all other files use
`index-entries.json`. The structure template is inconsistent with the rest of the guide.

The index-entries.json path format section in `extensions/README.md` (lines 72-95) is
accurate for path format requirements (`project/*` canonical form), but the load process
description needs updating.

### Finding 7: Project Overview Is Accurate but Incomplete

`context/repo/project-overview.md` is mostly accurate. It correctly shows the `.claude/extensions/`
structure with `manifest.json` and `index-entries.json`. However, it does not mention:
- The two-layer architecture (Neovim Lua loader vs. agent-consumed .claude/)
- The `extensions.json` state file
- The computed-artifact nature of CLAUDE.md
- The `merge-sources/` subdirectory used for CLAUDE.md fragments

### Finding 8: extension-system.md Conflict Handling Is Wrong

`extension-system.md` (lines 394-396):
> "If loading would overwrite existing files: Loading is aborted"

The actual code (`init.lua` lines 330-378) shows that if conflicts exist, the user is
**shown a confirmation dialog** (with conflict count), and **loading proceeds** if confirmed.
Conflicts cause a warning note in the dialog, not an abort. Only dependency failures or
rollback failures abort loading.

### Finding 9: Settings Merging Source Is Via `merge_targets.settings`, Not `mcp_servers`

`extension-system.md` (lines 350-361) shows settings merging via `mcp_servers` key in
manifest. The actual code (`init.lua` lines 89-100) uses `merge_targets.settings` with a
`source` file path (JSON fragment file) and `target` path. The `mcp_servers` field shown
in extension-system.md documentation does not correspond to any code path in the loader.

---

## Recommended Approach

### Priority 1: Fix CLAUDE.md Architecture Description (All Docs)

Every document that references section injection, `<!-- SECTION: ... -->` markers, or
`section_id` in the context of CLAUDE.md generation must be updated to describe the
computed-artifact model:

1. Extension content lives in `merge-sources/claudemd.md` (or `EXTENSION.md` per manifest)
2. On load/unload, `generate_claudemd()` rebuilds the entire file
3. No section markers; the output is marker-free
4. Verification uses a fingerprint of the first non-empty line of the source fragment

### Priority 2: Update Load/Unload Process Steps

`extension-system.md`'s "Loading an Extension" section is largely accurate about the
file-copy steps (Finding 3 is a discrepancy about conflict handling), but the merge step
needs complete rewrite for CLAUDE.md. The unload safety should be corrected to "hard block,
not warning with confirmation".

### Priority 3: Add Missing Copy Categories

`creating-extensions.md` and `extension-system.md` should add documentation for:
- `hooks`, `docs`, `templates`, `systemd`, `root_files` categories
- `data` category (merge-copy semantics, different destination)

### Priority 4: Fix Settings Merging Documentation

Replace `mcp_servers` manifest example with the correct `merge_targets.settings` mechanism.

### Priority 5: Update extension-development.md

- Fix structure template to use `index-entries.json` consistently
- Fix manifest example to remove `section_id` reference (or note it is unused)
- Update merge process section to describe computed artifact

### Priority 6: Verify Extension README Path

The `EXTENSION.md` vs `merge-sources/claudemd.md` question needs resolution: confirm
whether non-core extensions use `EXTENSION.md` or `merge-sources/claudemd.md` as their
source, and document the convention clearly.

---

## Evidence/Examples

### Code Evidence for Computed Artifact (Finding 1)

`init.lua:process_merge_targets()` (lines 80-88):
```lua
-- Config markdown (CLAUDE.md or OPENCODE.md) is now a computed artifact.
-- Section injection is skipped here; generate_claudemd() regenerates the file
-- from all loaded extensions after each load/unload operation.
-- The merge_key entry in merged_sections is intentionally left empty so that
-- reverse_merge_targets has nothing to remove (generation handles removal by
-- regenerating without the unloaded extension's content).
```

`merge.lua:generate_claudemd()` (line 549): builds output as
`header + fragment1 + fragment2 + ...` with no markers.

### Code Evidence for Hard Block (Finding 3)

`init.lua` lines 575-587:
```lua
if #dependents > 0 then
  local msg = string.format(
    "Cannot unload extension '%s': required by loaded extension(s): %s\n"
      .. "Unload dependent extension(s) first.",
    extension_name, dep_list
  )
  helpers.notify(msg, "ERROR")
  return false, msg
end
```
No `vim.fn.confirm()` call for dependents — unconditional return false.

### Stale Documentation Example

`extension-system.md` lines 187-189:
```markdown
**Section Markers**:
Injected sections are wrapped with markers for clean removal:
```markdown
<!-- SECTION: extension_latex -->
## LaTeX Extension
[Extension content here]
<!-- END_SECTION: extension_latex -->
```

These markers are no longer written to CLAUDE.md.

---

## File Inventory (Documents Requiring Updates)

| File | Issues | Priority |
|------|--------|----------|
| `.claude/docs/architecture/extension-system.md` | Section markers, inject_section, conflict abort, mcp_servers | HIGH |
| `.claude/docs/guides/creating-extensions.md` | EXTENSION.md source, section_id, section marker test, missing categories | HIGH |
| `.claude/extensions/core/context/guides/extension-development.md` | inject_section, source file name, structure template | HIGH |
| `.claude/extensions/README.md` | Load step 4 description, verification check | MEDIUM |
| `.claude/extensions/core/context/repo/project-overview.md` | Incomplete - missing loader architecture | LOW |
| `.claude/docs/README.md` | Extension section is mostly accurate | LOW |

---

## Confidence Level: **HIGH**

All findings are based on direct reading of the Lua source files and comparison with the
documentation files. The computed-artifact change is thoroughly commented in the code itself
(`init.lua`, `merge.lua`, `verify.lua`) and the distinction from section injection is
unambiguous. The manifest format discrepancies (`merge-sources/` vs `EXTENSION.md`,
`merge_targets.settings` vs `mcp_servers`) are directly observable from the core manifest.json
and the init.lua process_merge_targets() function.
