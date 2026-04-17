# Teammate B Findings: Cross-Reference Consistency and Inter-Extension Compatibility

**Task**: 469 - Review agent system post-refactor (tasks 464, 465, 467)
**Focus**: Cross-referencing consistency and inter-extension compatibility
**Date**: 2026-04-16

---

## Key Findings

### Finding 1: Duplicate `## Memory Extension` Section in CLAUDE.md (HIGH)

`CLAUDE.md` contains two separate `## Memory Extension` sections:

- **Line 223**: From `core` extension's `merge-sources/claudemd.md` - covers Memory Commands, Memory Skill Mapping, Auto-Retrieval, Memory Lifecycle, Validate-on-Read, State Integration
- **Line 411**: From `memory` extension's `EXTENSION.md` - covers the same topics with slightly different wording and table formats

The two sections describe the same capabilities but with inconsistent descriptions:
- Line 246: `"Memory creation, distillation, and vault management"` (core version)
- Line 419: `"Memory creation, distillation, and management"` (memory EXTENSION.md version)

**Root Cause**: The `core` extension's `merge-sources/claudemd.md` hardcodes a `## Memory Extension` section, and the `memory` extension also merges its own `EXTENSION.md` which contains another `## Memory Extension` section. Both are appended to `CLAUDE.md` during load.

**Impact**: Doubles the length of the memory section, creates inconsistent descriptions, and wastes context budget when CLAUDE.md is read.

---

### Finding 2: `context/index.json` Missing `version` and `generated` Fields (HIGH)

`validate-context-index.sh` requires three top-level fields: `version`, `generated`, and `entries`. The current `index.json` only has `entries`:

```
Top-level keys: ['entries']
```

The validation script exits immediately with `[ERROR] Missing required field: version`, preventing it from completing its path-existence checks. This means the index validation tooling is broken.

---

### Finding 3: Four Stale/Wrong-Path Entries in `context/index.json` (MEDIUM)

Four entries in `context/index.json` reference files that do not exist:

| Index Path | load_when | Status |
|------------|-----------|--------|
| `orchestration/routing.md` | meta, meta-builder-agent | MISSING - `orchestration/` has no `routing.md` |
| `README.md` | `always: true` | MISSING - no `README.md` at `context/` root |
| `routing.md` | meta task_type | MISSING - actual file is in `extensions/core/context/routing.md` |
| `validation.md` | meta task_type | MISSING - actual file is `orchestration/validation.md` |

The `README.md` entry is marked `always: true`, meaning it would be loaded in every agent context. Since the file doesn't exist, agents get a broken reference on every invocation.

The `routing.md` entry points to the context root, but the actual file lives at `.claude/extensions/core/context/routing.md`. After the refactor, it appears this file was not synced from the extension source directory into `.claude/context/`.

`validate-wiring.sh` already catches these four as `[FAIL]` entries when run.

---

### Finding 4: `validate-wiring.sh` Calls Undefined Function `validate_language_entries` (HIGH)

`validate-wiring.sh` references `validate_language_entries` at lines 244, 250, 255, 260 (for nvim, lean, latex, typst extensions), but this function is **never defined** in the script. Defined functions are:

```
log_pass, log_fail, log_warn, log_info,
validate_skill_agent, validate_agent_exists, validate_index_entries,
validate_task_type_entries, validate_context_files,
validate_core_system, validate_extensions_loaded, main
```

When the `nvim` extension is loaded and validated, the script aborts with:
```
.claude/scripts/validate-wiring.sh: line 244: validate_language_entries: command not found
```

This causes `validate-wiring.sh` to exit early during extension validation, so nix, lean, latex, and typst extension checks are never reached.

---

### Finding 5: Inconsistent `Model` Column in Extension Skill-Agent Tables (LOW)

The `nvim` extension's `EXTENSION.md` (and the corresponding CLAUDE.md section) uses a 4-column `Skill | Agent | Model | Purpose` table. The `nix` and `memory` extension sections use a 3-column `Skill | Agent | Purpose` table with no Model column.

**Nix agent frontmatter**: Neither `nix-research-agent.md` nor `nix-implementation-agent.md` declares a `model:` field in their YAML frontmatter, while `neovim-research-agent.md` declares `model: opus` and the nix EXTENSION.md table omits the Model column entirely.

Since agents default to Opus when no `model:` is declared (per CLAUDE.md), this is functionally harmless but inconsistent with the documentation standard defined in `.claude/docs/reference/standards/agent-frontmatter-standard.md`.

---

### Finding 6: `scripts/claude-ready-signal.sh` Path in `settings.json` Is Non-Standard (LOW)

`settings.json` SessionStart hook references:
```
bash scripts/claude-ready-signal.sh 2>/dev/null || echo '{}'
```

This references `scripts/` (repo-relative path, not `.claude/scripts/`). The file exists at `/home/benjamin/.config/nvim/scripts/claude-ready-signal.sh` and is a project-level script. This is intentional design (not a `.claude/` system script), but it is not declared in any extension manifest. It's orphaned from the manifest system.

---

## Cross-Reference Results

### Skill-to-Agent Mapping (CLAUDE.md vs filesystem)

All 21 skills listed in CLAUDE.md's skill-agent table exist in `.claude/skills/`:

| Source | Count | Match |
|--------|-------|-------|
| CLAUDE.md skill table entries | 21 | All 21 exist in filesystem |
| Manifest-declared skills (all extensions combined) | 21 | Full match |
| Skills in filesystem | 21 | No orphans |

No mismatches detected.

### Agent Table Completeness

The core `### Agents` table (lines 197-205) lists 7 agents. Extension agents are listed only in their respective extension sections, not in the main table. This is by design but means the main Agents table is incomplete relative to the full loaded agent set of 11 agents (7 core + 2 nvim + 2 nix).

### Command Cross-Reference (CLAUDE.md vs filesystem vs manifests)

All 16 commands in `.claude/commands/` are declared in manifests and referenced in CLAUDE.md:
- 14 commands from `core` manifest
- 2 commands from `memory` manifest (`learn.md`, `distill.md`)

No orphaned command files detected.

### Rules Cross-Reference

All 8 rule files match their manifest declarations:
- 6 from `core`: artifact-formats, error-handling, git-workflow, plan-format-enforcement, state-management, workflows
- 1 from `nvim`: neovim-lua.md
- 1 from `nix`: nix.md

No orphaned rule files detected.

### Hook Cross-Reference (settings.json vs filesystem vs manifest)

All 11 hooks in `.claude/hooks/` are:
1. Declared in `core` manifest `provides.hooks`
2. Referenced in `settings.json`

One hook appears twice in `settings.json` (`tts-notify.sh` is registered for both Stop and Notification events - this is intentional).

No orphaned hook files detected.

### Extension Routing Conflicts

No task_type conflicts between loaded extensions:
- `core`: routes `general`, `meta`, `markdown`
- `memory`: routes `memory`
- `nvim`: routes `neovim`
- `nix`: routes `nix`

All routing keys are unique across extensions.

### Context @-References in CLAUDE.md

All `@.claude/context/` references in CLAUDE.md resolve to existing files:
- `context/repo/project-overview.md` - exists
- `context/meta/meta-guide.md` - exists
- `context/patterns/multi-task-operations.md` - exists
- `context/patterns/context-discovery.md` - exists
- `context/patterns/jq-escaping-workarounds.md` - exists
- `context/architecture/context-layers.md` - exists
- `context/guides/extension-development.md` - exists

All nvim extension context imports also resolve correctly:
- `context/project/neovim/domain/neovim-api.md` - exists
- `context/project/neovim/patterns/plugin-spec.md` - exists
- `context/project/neovim/tools/lazy-nvim-guide.md` - exists

---

## Orphaned/Missing Files

### Files Declared in Manifests but Missing

None - all agents, commands, skills, rules, scripts, and hooks declared in the four loaded extension manifests exist in the filesystem.

### Files in Filesystem but Not in Any Manifest

None detected for the four loaded extensions.

### Context Index Entries Pointing to Missing Files

Four index entries reference non-existent paths (see Finding 3):
- `orchestration/routing.md` (should be `orchestration/` subdir or the extension source)
- `README.md` (should be created or removed from index)
- `routing.md` (file exists only in `extensions/core/context/routing.md`, not in deployed context)
- `validation.md` (correct path is `orchestration/validation.md`)

### Scripts with Broken References

- `validate-wiring.sh` calls undefined function `validate_language_entries` (Finding 4)
- `validate-context-index.sh` fails immediately due to missing `version` field in index.json (Finding 2)

---

## Recommended Actions

### Priority 1 (Blocking validation tooling)

1. **Fix `context/index.json` missing metadata fields**: Add `version` and `generated` top-level fields so `validate-context-index.sh` can complete its path checks.

2. **Add `validate_language_entries` function to `validate-wiring.sh`**: Either define the function (it should check that `context/index.json` has entries for the given `task_type`/language) or replace calls with `validate_task_type_entries` which already exists and takes similar arguments.

### Priority 2 (Data integrity)

3. **Remove or fix four stale context index entries**:
   - Remove `routing.md` and `orchestration/routing.md` if the file isn't deployed to `.claude/context/`; OR sync `extensions/core/context/routing.md` to `.claude/context/routing.md`
   - Remove `validation.md` (the correct entry `orchestration/validation.md` already exists)
   - Remove `README.md` entry (marked `always: true`) or create the file

4. **Resolve duplicate `## Memory Extension` in `CLAUDE.md`**: Either remove the Memory Extension section from `core`'s `merge-sources/claudemd.md` and let the `memory` EXTENSION.md be the single source of truth, OR remove the memory section from `memory`'s EXTENSION.md and keep only the core version. The core version has slightly more detail (State Integration section).

### Priority 3 (Consistency)

5. **Add `model: opus` to `nix-research-agent.md` frontmatter**: Consistent with all other research agents and the documented standard.

6. **Add `Model` column to nix extension's `Skill-Agent Mapping` table** in `EXTENSION.md`: Match the format used by the nvim extension for consistency.

---

## Confidence Level

**High** for all findings above. All issues were confirmed by:
- Direct filesystem checks
- Cross-referencing index.json against filesystem
- Running `validate-wiring.sh` (confirms Findings 1, 3, 4)
- Inspection of script source code (confirms Finding 4)
- Comparing CLAUDE.md section headers (confirms Finding 1)
- JSON key inspection (confirms Finding 2)
