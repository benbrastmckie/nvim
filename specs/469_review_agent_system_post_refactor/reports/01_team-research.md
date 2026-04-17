# Research Report: Task #469

**Task**: Systematically review agent system post-refactor for errors and improvements
**Date**: 2026-04-16
**Mode**: Team Research (4 teammates)
**Session**: sess_1776406885_fb2cf2

## Summary

The agent system is structurally sound after the 464/465/467 refactoring, with all manifests valid, all declared agents/commands/skills/rules deployed correctly, and no routing conflicts between extensions. However, the refactoring left **bookkeeping gaps** in context indexing and path references. There are 4 broken index entries, 3 stale path references in team skills, a duplicate CLAUDE.md section, and broken validation tooling. All issues are fixable without architectural changes.

## Key Findings (Prioritized)

### P1: 4 Broken Context Index Entries [HIGH] (Confirmed: A, B, C, D)

`context/index.json` has 4 entries pointing to non-existent files:

| Index Path | Root Cause | Fix |
|------------|-----------|-----|
| `README.md` (always: true) | Exists in `extensions/core/context/` but not deployed -- loader's `copy_context_dirs()` only handles directories | Deploy file OR remove entry |
| `routing.md` | Same as above -- root-level file skipped by loader | Deploy file OR remove entry |
| `validation.md` | Same as above -- root-level file skipped by loader | Deploy file OR remove entry |
| `orchestration/routing.md` | File never existed -- stale since task 433 deletion | Remove entry from `core-index-entries.json` |

**Impact**: `README.md` is marked `always: true`, meaning every agent session attempts to read a non-existent file. The other 3 affect meta task type context loading.

**Loader gap**: `copy_context_dirs()` in `loader.lua` checks `vim.fn.isdirectory()`, silently skipping individual files at the context root. The manifest's `provides.context` only lists subdirectory names.

### P2: Stale Path References in 3 Team Skills [HIGH] (Confirmed: C)

Three deployed skills reference the internal extension source path instead of the deployed path:

- `skills/skill-team-plan/SKILL.md`
- `skills/skill-team-research/SKILL.md`
- `skills/skill-team-implement/SKILL.md`

All reference: `.claude/extensions/core/context/reference/team-wave-helpers.md`
Correct path: `.claude/context/reference/team-wave-helpers.md`

The stale references exist in BOTH the extension source AND deployed copies. Agents using team skills will construct broken file references.

### P3: Duplicate Memory Extension Section in CLAUDE.md [HIGH] (Confirmed: A, B, D)

`.claude/CLAUDE.md` contains `## Memory Extension` twice:
- Line ~223: From core's `merge-sources/claudemd.md`
- Line ~411: From memory extension's `EXTENSION.md`

Both cover the same commands/lifecycle/skill mapping with slightly inconsistent wording. This doubles the token cost for memory information in every session.

**Fix**: Remove the Memory Extension section from core's `merge-sources/claudemd.md` (let the memory extension be the single source of truth).

### P4: Broken Validation Tooling [HIGH] (Confirmed: B)

Two validation scripts are non-functional:

1. **`validate-wiring.sh`**: Calls undefined function `validate_language_entries` at lines 244/250/255/260 (for nvim/lean/latex/typst). Script aborts during nvim extension validation, so nix and later extension checks never run.

2. **`validate-context-index.sh`**: Requires `version` and `generated` top-level fields in `index.json`, but the current index only has `entries`. Script exits immediately with "Missing required field: version".

### P5: 6 Context Files Installed But Missing from Index [MEDIUM] (Confirmed: A)

These files exist in `.claude/context/` but have no `index.json` entries, so agents can never auto-discover them:

| File | Significance |
|------|-------------|
| `patterns/artifact-linking-todo.md` | Cross-referenced by research/planning/implementation workflows |
| `patterns/multi-task-operations.md` | Referenced in CLAUDE.md multi-task syntax section |
| `reference/team-wave-helpers.md` | Referenced by team skills |
| `schemas/frontmatter-schema.json` | Schema file |
| `schemas/subagent-frontmatter.yaml` | Schema file |
| `templates/state-template.json` | Template file |

### P6: Core Extension Fails Its Own Validator [MEDIUM] (Confirmed: C)

`check-extension-docs.sh` reports core has no `README.md` and no routing block in manifest. The extension that powers the entire system fails its own documentation standards.

### P7: 13 Stale `subagent-return-format.md` References [MEDIUM] (Confirmed: D)

Pre-existing known issue tracked in ROADMAP. 13 context files reference old filename `subagent-return-format.md`; actual file is `formats/subagent-return.md`. A simple find-and-replace fix.

### P8: Nix Agents Missing model: opus Frontmatter [LOW] (Confirmed: B)

`nix-research-agent.md` and `nix-implementation-agent.md` lack `model: opus` frontmatter, inconsistent with all other research/implementation agents and the documented agent-frontmatter standard. Functionally harmless (defaults to opus) but inconsistent.

### P9: Scripts Missing Execute Permission [LOW] (Confirmed: C)

`setup-lean-mcp.sh` and `verify-lean-mcp.sh` have shebangs but are `-rw-r--r--` in both source and deployed locations. All other scripts are executable.

### P10: Minor Issues [LOW]

- **`merged_sections` type inconsistency**: Core has `[]` (array) vs other extensions have `{}` (object) in `extensions.json` (A)
- **`docs-README.md` confusion**: Renamed artifact from docs-flattening coexists with proper `docs/README.md` (C)
- **Lean MCP scripts in wrong extension**: Core owns lean-specific scripts; lean extension has `"scripts": []` (C)
- **Memory MCP not configured**: `obsidian-memory` MCP server declared in manifest but not in settings.json/settings.local.json (A)
- **Stale permissions in settings.local.json**: 40+ accumulated permission entries from past agent sessions (A)

## Synthesis

### Conflicts Resolved

1. **Teammate B said `validation.md` correct path is `orchestration/validation.md`; Teammate A/C/D said it's a root-level file**: Both are correct -- there are two entries. The root-level `validation.md` exists in extension source but isn't deployed. The `orchestration/validation.md` entry in the index correctly points to an existing deployed file. The stale entry is the root-level `validation.md` in the index (which should either deploy the file or remove the entry).

2. **Fix approach for broken index entries**: Teammates disagreed on whether to deploy the 3 root files or remove their index entries. The cleaner fix is to add the files to the core manifest's `provides.context` as explicit root-level files AND fix the loader to handle them. However, the quick fix is to manually copy them and update the manifest.

### Gaps Identified

1. **No automated integrity check**: Finding P1 would have been caught immediately if `/refresh` or CI checked that every `index.json` entry has a corresponding file.

2. **Task 468 scope overlap**: Substantial documentation already exists (`extension-system.md` at 416 lines, `extension-development.md`, `extensions/README.md`). Task 468 should be narrowed to the loader's internal lifecycle state machine.

3. **Loader architecture gap**: The `copy_context_dirs()` function cannot handle root-level files. This is a design limitation that should be documented or fixed.

### Recommendations

**Immediate fixes** (can be done in one task):
1. Remove `orchestration/routing.md` stale entry from `core-index-entries.json`
2. Deploy 3 root-level context files (README.md, routing.md, validation.md) manually
3. Fix 3 team skill path references (find-replace in source + deployed)
4. Remove duplicate Memory Extension from core's `merge-sources/claudemd.md`
5. Add `version` and `generated` fields to `context/index.json`
6. Fix `validate_language_entries` in `validate-wiring.sh`

**Short-term** (separate tasks):
7. Add 6 missing index entries for installed-but-unindexed files
8. Fix 13 stale `subagent-return-format.md` references
9. Add `model: opus` to nix agent frontmatter
10. Create core extension `README.md`
11. Fix loader to handle root-level context files

**Strategic**:
12. Add automated index integrity check to `/refresh`
13. Narrow task 468 scope based on existing documentation

## Teammate Contributions

| Teammate | Angle | Status | Confidence | Key Contribution |
|----------|-------|--------|------------|-----------------|
| A | Structural integrity | completed | high | Found 6 unindexed files, memory MCP gap |
| B | Cross-reference consistency | completed | high | Found broken validators, confirmed no orphans |
| C | Critic | completed | high | Found team skill stale paths, loader gap root cause |
| D | Horizons | completed | high | Complexity numbers, task 468 overlap, strategic assessment |

## Complexity Snapshot

| Metric | Value |
|--------|-------|
| Extensions loaded | 4 (core, nvim, memory, nix) |
| Context index entries | 134 (94 core + 40 extensions) |
| Total indexed lines | 34,668 |
| Installed markdown files | 219 |
| Total .claude/ files | 343 |
| Core extension files | 214 (~56,841 md lines) |
| Issues found (all severities) | 16 |
| HIGH severity | 4 |
| MEDIUM severity | 3 |
| LOW severity | 9 |
