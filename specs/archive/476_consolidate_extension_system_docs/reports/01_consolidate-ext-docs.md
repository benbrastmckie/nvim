# Research Report: Task #476

**Task**: 476 - Consolidate extension system documentation into single source of truth
**Started**: 2026-04-17T00:00:00Z
**Completed**: 2026-04-17T00:30:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**:
- Lua loader implementation (6 source files in `lua/neotex/plugins/ai/shared/extensions/`)
- `.claude/docs/architecture/extension-system.md` (architecture doc)
- `.claude/context/guides/extension-development.md` (agent-facing guide)
- `.claude/docs/guides/creating-extensions.md` (how-to guide)
- `.claude/context/repo/project-overview.md` (project overview)
- `.claude/context/guides/loader-reference.md` (new untracked file)
- `.claude/context/index.schema.json` (new untracked file)
- `.claude/extensions.json` (live state file)
- `.claude/context/index.json` (live index file)
- Three validator scripts in `.claude/scripts/`
**Artifacts**:
- `specs/476_consolidate_extension_system_docs/reports/01_consolidate-ext-docs.md`
**Standards**: report-format.md

## Executive Summary

- The extension system has three documentation files plus two new untracked files that overlap significantly. The Lua implementation is the ground truth and it tells a clear story: CLAUDE.md is a fully computed artifact via `generate_claudemd()`.
- The architecture doc (`extension-system.md`) is the most out-of-date: it still describes section injection with markers, says conflicts cause abort, omits 6 of 12 `provides` categories, and lists only 6 of 12 loader functions.
- The development guide (`extension-development.md`) is mostly correct -- it accurately describes `generate_claudemd()` and lists all 12 `provides` categories -- but contains one contradiction about unload behavior (says "warning + confirm" when the code does a hard block).
- The creating-extensions guide (`creating-extensions.md`) is moderately outdated: says conflicts cause abort, lists only 7 of 12 `provides` categories, marks `task_type` as required.
- The new `loader-reference.md` is accurate and comprehensive. The new `index.schema.json` requires `version` and `generated` fields that the actual `index.json` does not have.
- The `validate-context-index.sh` script also requires `version` and `generated` fields, creating a validator-vs-reality mismatch.

## Context & Scope

This research audits all documentation describing the extension system, comparing each claim against the Lua implementation to identify contradictions, missing coverage, and duplication. The goal is to inform a consolidation plan that establishes a single source of truth.

## Findings

### 1. Ground Truth from Lua Implementation

#### 1.1 CLAUDE.md Generation Strategy

**Implementation**: `merge.lua:generate_claudemd()` (lines 537-660) generates CLAUDE.md as a fully computed artifact. It:
1. Reads state to get loaded extension names
2. Orders them: core first, then remaining extensions sorted
3. For each, reads `merge_targets.{merge_key}.source` file
4. Optionally prepends a header template from core's `templates/claudemd-header.md`
5. Concatenates all fragments and writes the result

**`init.lua` confirms**: Both `manager.load()` (line 513) and `manager.unload()` (line 641) call `generate_claudemd()` after updating state. The `process_merge_targets()` function (line 72) explicitly skips section injection for the config markdown merge key, with a comment explaining that generation handles it.

**Section injection still exists**: `merge.lua` still has `inject_section()` and `remove_section()` functions (lines 101-170). These are NOT dead code -- they could be used by other merge targets -- but they are NOT used for CLAUDE.md generation. The old `section_id` field in manifests is vestigial for the CLAUDE.md use case.

#### 1.2 Conflict Handling

**Implementation**: `loader.lua:check_conflicts()` (lines 527-590) detects conflicts and returns a list. In `init.lua:manager.load()` (lines 327-376), conflicts are NOT used to abort. Instead:
1. Conflicts are counted (overwrite vs merge)
2. The count is shown in the **confirmation dialog** message
3. If the user confirms, loading proceeds and files are overwritten
4. Data directory conflicts are flagged with `merge=true` (informational only)

**There is no abort behavior.** The user sees a confirmation dialog that mentions how many files will be overwritten.

#### 1.3 Complete `provides` Field List

From `manifest.lua` line 11 (`VALID_PROVIDES`):

| # | Category | Loader Function | Notes |
|---|----------|----------------|-------|
| 1 | `agents` | `copy_simple_files()` | Flat .md files |
| 2 | `skills` | `copy_skill_dirs()` | Recursive directory copy |
| 3 | `commands` | `copy_simple_files()` | Flat .md files |
| 4 | `rules` | `copy_simple_files()` | Flat .md files |
| 5 | `context` | `copy_context_dirs()` | Recursive, preserving structure |
| 6 | `scripts` | `copy_scripts()` | .sh permission preservation |
| 7 | `hooks` | `copy_hooks()` | Always preserve execute perms |
| 8 | `data` | `copy_data_dirs()` | Merge-copy semantics |
| 9 | `docs` | `copy_docs()` | Files or recursive directories |
| 10 | `templates` | `copy_templates()` | Flat files, no exec perms |
| 11 | `systemd` | `copy_systemd()` | Flat unit files |
| 12 | `root_files` | `copy_root_files()` | Files at target_dir root |

#### 1.4 Complete Loader Function List

From `loader.lua` (12 public functions):

1. `copy_simple_files(manifest, source_dir, target_dir, category, extension, agents_subdir)`
2. `copy_skill_dirs(manifest, source_dir, target_dir)`
3. `copy_context_dirs(manifest, source_dir, target_dir)`
4. `copy_scripts(manifest, source_dir, target_dir)`
5. `copy_hooks(manifest, source_dir, target_dir)`
6. `copy_docs(manifest, source_dir, target_dir)`
7. `copy_templates(manifest, source_dir, target_dir)`
8. `copy_systemd(manifest, source_dir, target_dir)`
9. `copy_root_files(manifest, source_dir, target_dir)`
10. `copy_data_dirs(manifest, source_dir, project_dir)` -- NOTE: `project_dir` not `target_dir`
11. `check_conflicts(manifest, target_dir, project_dir)`
12. `remove_installed_files(installed_files, installed_dirs)`

#### 1.5 Complete Merge Function List

From `merge.lua` (12 public functions):

1. `inject_section(target_path, section_content, section_id)` -- still exists but unused for CLAUDE.md
2. `remove_section(target_path, section_id)` -- still exists but unused for CLAUDE.md
3. `deep_merge()` -- private helper
4. `merge_settings(target_path, fragment)`
5. `unmerge_settings(target_path, tracked_entries)`
6. `append_index_entries(target_path, entries)`
7. `remove_index_entries_tracked(target_path, tracked)`
8. `remove_index_entries_by_prefix(target_path, prefixes)`
9. `remove_orphaned_index_entries(index_path, valid_prefixes, context_dir)`
10. `generate_claudemd(project_dir, config)`
11. `merge_opencode_agents(target_path, fragment)`
12. `unmerge_opencode_agents(target_path, tracked)`

#### 1.6 Unload Dependency Handling

**Implementation**: `init.lua:manager.unload()` (lines 559-587) performs a **hard block**, not a warning:
- Scans all loaded extensions for ones that declare the target as a dependency
- If dependents exist, calls `helpers.notify(msg, "ERROR")` and returns `false`
- The user cannot proceed -- the function returns before reaching the confirmation dialog
- The error message says: "Cannot unload extension 'X': required by loaded extension(s): Y. Unload dependent extension(s) first."

#### 1.7 Settings Merging

**Implementation**: Settings are merged via `merge_targets.settings` in the manifest, NOT via `mcp_servers`. Looking at `init.lua:process_merge_targets()` (lines 88-101):
- It checks `ext_manifest.merge_targets.settings`
- Reads a JSON fragment from `source` path
- Calls `merge_mod.merge_settings(target_path, fragment)`

The `mcp_servers` field in the manifest is NOT directly consumed by the loader. MCP servers must be included in a `settings-fragment.json` file referenced by `merge_targets.settings`.

#### 1.8 `extensions.json` Schema

**On disk** (actual): `{"extensions": {...}}` -- no top-level `version` field.
**In `state.lua:default_state()`**: Returns `{version = "1.0.0", extensions = {}}`.
**Per-extension fields**: `version`, `loaded_at`, `source_dir`, `installed_files`, `installed_dirs`, `merged_sections`, `data_skeleton_files`, `status`.

The architecture doc shows `merged_sections` containing `claudemd: {section_id: "extension_latex"}` -- this is wrong. The actual `merged_sections` for loaded extensions only contains `index` (and possibly `settings`), never `claudemd`, because CLAUDE.md is generated.

#### 1.9 `index.json` Schema

**On disk** (actual): `{"entries": [...]}` -- no `version` or `generated` fields.
**In `index.schema.json`** (new file): Requires `version`, `generated`, and `entries` as top-level required fields.
**In `merge.lua:append_index_entries()`**: Creates `{entries: []}` as default -- no `version` or `generated`.
**In `validate-context-index.sh`**: Checks for `version`, `generated`, and `entries` as required fields.

This is a three-way mismatch: the schema and validator expect fields the loader never writes.

### 2. Documentation Inventory and Coverage

| Document | Location | Audience | Key Topics |
|----------|----------|----------|------------|
| extension-system.md | `.claude/docs/architecture/` | Developers/maintainers | Architecture overview, load/unload process, all components |
| extension-development.md | `.claude/context/guides/` | Agent-facing (loaded by agents) | How to create extensions, manifest format, merge process |
| creating-extensions.md | `.claude/docs/guides/` | Developers (how-to) | Step-by-step guide, templates, testing |
| project-overview.md | `.claude/context/repo/` | Agents | Two-layer architecture, repository structure |
| loader-reference.md (NEW) | `.claude/context/guides/` | Agent-facing reference | Complete loader function reference, source file inventory |
| index.schema.json (NEW) | `.claude/context/` | Validators/tooling | JSON Schema for index.json |

### 3. Contradictions Between Docs and Implementation

#### 3.1 CLAUDE.md Generation vs Section Injection

| Source | Claim |
|--------|-------|
| **Implementation** | `generate_claudemd()` fully regenerates from fragments; no section markers used |
| **extension-system.md** (line 25) | Diagram shows `"(merged section)"` |
| **extension-system.md** (lines 178-179) | Documents `inject_section()` and `remove_section()` as merger functions |
| **extension-system.md** (lines 188-196) | Shows section markers `<!-- SECTION: extension_latex -->` as current behavior |
| **extension-system.md** (line 258) | Load step 6a says "inject_section() into CLAUDE.md" |
| **extension-system.md** (line 279) | Unload step 3a says "remove_section() from CLAUDE.md" |
| **extension-development.md** (line 21-25) | Correctly describes `generate_claudemd()` |
| **extension-development.md** (line 129) | Correctly says `section_id` is vestigial for tracking |
| **creating-extensions.md** (line 117) | Says "Content injected into CLAUDE.md when loaded" |

**Severity**: HIGH. The architecture doc (the most "official" one) is wrong on the core mechanism.

#### 3.2 Conflict Handling

| Source | Claim |
|--------|-------|
| **Implementation** | Conflicts shown in confirmation dialog; user can proceed (overwrite) |
| **extension-system.md** (lines 391-395) | "Loading is aborted... No partial state is created" |
| **creating-extensions.md** (lines 657-660) | "The loader detected existing files that would be overwritten" (implies abort) |
| **extension-development.md** | Does not mention conflict behavior |

**Severity**: MEDIUM. Both docs/architecture and docs/guides describe abort; implementation allows override.

#### 3.3 Unload Dependency Handling

| Source | Claim |
|--------|-------|
| **Implementation** | Hard block with `ERROR` notification; returns false before dialog |
| **extension-system.md** (lines 272-273) | "show warning... Proceed with unload if user confirms" |
| **extension-development.md** (lines 254-258) | "triggers a warning... The user can confirm to proceed" |

**Severity**: MEDIUM. Both docs say "warning + confirm"; implementation does hard block.

#### 3.4 `provides` Field Coverage

| Category | extension-system.md | extension-development.md | creating-extensions.md |
|----------|:------------------:|:----------------------:|:---------------------:|
| agents | Y | Y | Y |
| skills | Y | Y | Y |
| commands | Y | Y | Y |
| rules | Y | Y | Y |
| context | Y | Y | Y |
| scripts | Y | Y | Y |
| hooks | Y | Y | Y |
| data | - | Y | - |
| docs | - | Y | - |
| templates | - | Y | - |
| systemd | - | Y | - |
| root_files | - | Y | - |

**extension-system.md** is missing 5 categories (data, docs, templates, systemd, root_files).
**creating-extensions.md** is missing 5 categories (data, docs, templates, systemd, root_files).
**extension-development.md** lists all 12 -- correct.

#### 3.5 Loader Function Lists

| Function | extension-system.md | loader-reference.md (NEW) | extension-development.md |
|----------|:------------------:|:------------------------:|:----------------------:|
| copy_simple_files | Y | Y | Implied |
| copy_skill_dirs | Y | Y | Implied |
| copy_context_dirs | Y | Y | Y (dual behavior noted) |
| copy_scripts | Y | Y | Implied |
| copy_hooks | - | Y | Implied |
| copy_docs | - | Y | Implied |
| copy_templates | - | Y | Implied |
| copy_systemd | - | Y | Implied |
| copy_root_files | - | Y | Implied |
| copy_data_dirs | - | Y | Implied |
| check_conflicts | Y | Y | Implied |
| remove_installed_files | Y | Y | Implied |

**extension-system.md** lists only 6 of 12 functions explicitly.
**loader-reference.md** lists all 12 -- correct and comprehensive.

#### 3.6 `extensions.json` Schema in Docs vs Reality

| Field | extension-system.md | state.lua default | Actual on disk |
|-------|:------------------:|:-----------------:|:--------------:|
| Top-level `version` | Not shown | Yes ("1.0.0") | No |
| `merged_sections.claudemd` | Shows `{section_id: ...}` | Never written | Never present |
| `data_skeleton_files` | Not shown | Written by `mark_loaded()` | Present |

#### 3.7 `index.json` Schema vs Reality

| Field | index.schema.json | validate-context-index.sh | merge.lua default | Actual on disk |
|-------|:-----------------:|:------------------------:|:-----------------:|:--------------:|
| `version` | Required | Required | Not written | Not present |
| `generated` | Required | Required | Not written | Not present |
| `entries` | Required | Required | Written | Present |
| Entry `domain` | Required | Required (validated) | Not enforced | Present in some |
| Entry `summary` | Required | Required | Not enforced | Present in some |
| Entry `line_count` | Required | Required (tolerance check) | Not enforced | Present in some |

#### 3.8 `task_type` Field Requirement

| Source | Claim |
|--------|-------|
| **Implementation** (`manifest.lua`) | Only `name`, `version`, `description` are required |
| **creating-extensions.md** (line 106) | Lists `task_type` as "Yes" (required) |
| **extension-development.md** (line 98) | Lists as just a field (no required marker) |
| **extension-development.md** (lines 263-268) | Correctly notes resource-only extensions can omit `task_type` |

#### 3.9 Settings vs MCP Servers

| Source | Claim |
|--------|-------|
| **Implementation** | Uses `merge_targets.settings` to merge a settings fragment |
| **extension-system.md** (lines 347-368) | Documents `mcp_servers` in manifest as the mechanism |
| **creating-extensions.md** (line 97) | Shows `mcp_servers: {}` in template |

The `mcp_servers` field in manifests is not directly used by the loader. Settings are merged via `merge_targets.settings.source` pointing to a `settings-fragment.json` file.

### 4. Content Duplication

#### 4.1 Two-Layer Architecture Explanation

Described in 3 places:
- `project-overview.md` (lines 8-13)
- `extension-development.md` (lines 10-26)
- `extension-system.md` (lines 9-30, as diagram)

#### 4.2 Directory Structure Listings

Described in 3 places:
- `extension-system.md` (lines 46-67)
- `extension-development.md` (lines 35-47)
- `creating-extensions.md` (line 25, as bash commands)

#### 4.3 Manifest Schema/Template

Full manifest example in 3 places:
- `extension-system.md` (lines 103-143)
- `extension-development.md` (lines 52-89)
- `creating-extensions.md` (lines 50-97)

#### 4.4 Load/Unload Sequence

Described in 2 places:
- `extension-system.md` (lines 230-283, detailed steps)
- `extension-development.md` (lines 17-25, abbreviated)

#### 4.5 Conflict Handling

Described in 2 places:
- `extension-system.md` (lines 389-395)
- `creating-extensions.md` (lines 657-660)

#### 4.6 Dependency System

Described in 2 places:
- `extension-development.md` (lines 215-293)
- `creating-extensions.md` (lines 11, 107)

#### 4.7 Resource-Only Extensions

Described in 2 places:
- `extension-development.md` (lines 260-286)
- `creating-extensions.md` (lines 207-236)

### 5. Validator Assessment

#### 5.1 `validate-context-index.sh`

- **Requires `version` and `generated`**: These fields do not exist in the actual `index.json`. The validator would fail on the real file. This is a bug -- either the validator needs updating or the loader needs to write these fields.
- **Validates `domain` values**: Accepts `core`, `project`, `system`. This matches extension-contributed entries.
- **Checks file existence**: Confirms context files referenced in entries exist on disk.
- **Checks `line_count` accuracy**: With 10% tolerance.
- **Checks deprecated entries**: Validates replacement paths exist.

#### 5.2 `validate-wiring.sh`

- Validates skill-to-agent wiring by grepping SKILL.md for agent names
- Validates agent files exist in the agents directory
- Validates index.json entries exist for agents and task types
- Validates all context files referenced in index.json exist on disk
- Does NOT validate extension manifests or provides fields
- Supports both `.claude` and `.opencode` systems

#### 5.3 `check-extension-docs.sh`

- Checks each extension for `manifest.json`, `EXTENSION.md`, `README.md`
- Validates manifest entries reference files that exist on disk (agents, skills, commands, rules, scripts)
- Checks for routing block when skills are declared
- Warns if README.md is older than manifest.json
- Checks that commands in manifest are mentioned in README.md

### 6. New Untracked Files Assessment

#### 6.1 `loader-reference.md`

This is a comprehensive, accurate reference for the Lua loader. It correctly documents:
- All 12 loader functions with signatures
- Copy semantics for each category
- All 8 source files in the extension system
- The call order in `init.lua`
- Merge-copy vs simple copy vs recursive copy semantics

**Recommendation**: This is a high-quality reference that should be retained.

#### 6.2 `index.schema.json`

Defines a JSON Schema for `index.json` with required fields `version`, `generated`, `entries`. Per-entry required fields: `path`, `domain`, `summary`, `line_count`.

**Problem**: The schema requires `version` and `generated` which the loader never writes. Either:
- The loader should be updated to write these fields, OR
- The schema should be updated to make them optional

The entry-level fields (`domain`, `summary`, `line_count`) are also not enforced by the loader's `append_index_entries()` -- extensions may or may not include them.

## Decisions

- The Lua implementation is the authoritative source. All documentation must align with it.
- `generate_claudemd()` is the correct mechanism; all references to section injection for CLAUDE.md must be updated.
- The `loader-reference.md` file is accurate and should be kept as the canonical loader reference.

## Recommendations

### Priority 1: Fix Critical Contradictions

1. **extension-system.md**: Remove all section injection language for CLAUDE.md. Update the diagram, merger function list, load/unload sequences, and section marker examples. Add `generate_claudemd()` documentation.
2. **extension-system.md**: Fix conflict handling from "abort" to "confirmation dialog with override".
3. **extension-system.md**: Fix unload dependency handling from "warning + confirm" to "hard block".
4. **extension-system.md**: Add missing `provides` categories (data, docs, templates, systemd, root_files) and loader functions.
5. **extension-system.md**: Fix `extensions.json` schema example (remove `merged_sections.claudemd`, add `data_skeleton_files`).

### Priority 2: Fix Moderate Contradictions

6. **creating-extensions.md**: Fix conflict handling language. Fix `task_type` from required to optional. Add missing provides categories. Update EXTENSION.md description from "injected" to "included via generation".
7. **extension-development.md**: Fix unload dependency handling from "warning + confirm" to "hard block".
8. **index.schema.json**: Either make `version`/`generated` optional, or update the loader to write them. Given that `index.json` is dynamically managed by the loader, making them optional seems more appropriate.
9. **validate-context-index.sh**: Align with actual `index.json` schema (remove `version`/`generated` requirement, or add them to the loader).

### Priority 3: Reduce Duplication

10. **Consolidation strategy**: Make `extension-system.md` the single comprehensive source. Reduce `extension-development.md` to a concise agent-facing guide that references the architecture doc. Reduce `creating-extensions.md` to a step-by-step tutorial that references the architecture doc for details.
11. **Manifest schema**: Define once in `extension-system.md`, reference from other docs.
12. **Two-layer architecture**: Define once in `extension-system.md` or `project-overview.md`, reference from other docs.

### Priority 4: Clean Up Vestigial Code

13. **`section_id` in manifests**: Document that this field is vestigial for CLAUDE.md (used only for backward compatibility or potential future use). Consider removing from manifest templates.
14. **`mcp_servers` in manifests**: Clarify relationship to `merge_targets.settings`. Document whether `mcp_servers` is consumed directly or must be in a settings fragment.

## Risks & Mitigations

- **Risk**: Updating docs may break agent context loading if paths change. **Mitigation**: Keep file paths stable; only update content.
- **Risk**: Removing duplicate content may leave agents without sufficient context. **Mitigation**: Ensure `extension-development.md` (agent-loaded) retains all information agents need.
- **Risk**: Schema/validator changes may reveal actual data issues. **Mitigation**: Run validators after changes to confirm alignment.

## Appendix

### Search Queries Used

- Read all 6 Lua source files in `lua/neotex/plugins/ai/shared/extensions/`
- Read all 3 documentation files in `.claude/docs/` and `.claude/context/guides/`
- Read all 3 validator scripts in `.claude/scripts/`
- Read 2 new untracked files (`loader-reference.md`, `index.schema.json`)
- Examined live `extensions.json` and `index.json` on disk
- Read `project-overview.md` and `ROADMAP.md` for context

### File-to-Contradiction Index

| File | Line(s) | Contradiction ID |
|------|---------|-----------------|
| extension-system.md | 25 | 3.1 (section injection diagram) |
| extension-system.md | 178-179 | 3.1 (inject/remove functions) |
| extension-system.md | 188-196 | 3.1 (section markers) |
| extension-system.md | 258 | 3.1 (load step 6a) |
| extension-system.md | 279 | 3.1 (unload step 3a) |
| extension-system.md | 391-395 | 3.2 (conflict abort) |
| extension-system.md | 272-273 | 3.3 (unload warning) |
| creating-extensions.md | 117 | 3.1 (content injected) |
| creating-extensions.md | 657-660 | 3.2 (conflict abort) |
| creating-extensions.md | 106 | 3.8 (task_type required) |
| extension-development.md | 254-258 | 3.3 (unload warning) |
| index.schema.json | 7 | 3.7 (version/generated required) |
| validate-context-index.sh | 61 | 3.7 (version/generated required) |
