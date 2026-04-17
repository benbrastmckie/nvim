# Teammate C (Critic) Findings - Task 469

**Date**: 2026-04-16
**Role**: Critic - Gaps, shortcomings, and blind spots
**Scope**: Agent system in `.claude/` after tasks 464, 465, 467 refactoring

---

## Key Findings

### Finding 1 (HIGH SEVERITY): Stale Path References in Deployed Team Skills

Three deployed skills reference the internal extension source path instead of the deployed path:

- `/home/benjamin/.config/nvim/.claude/skills/skill-team-plan/SKILL.md` (lines 9, 24)
- `/home/benjamin/.config/nvim/.claude/skills/skill-team-research/SKILL.md` (lines 9, 26)
- `/home/benjamin/.config/nvim/.claude/skills/skill-team-implement/SKILL.md` (lines 9, 24)

All three reference:
```
.claude/extensions/core/context/reference/team-wave-helpers.md
```

The correct deployed path is:
```
.claude/context/reference/team-wave-helpers.md
```

The file exists at the correct deployed path. The stale references exist in BOTH the extensions/core source AND the deployed `.claude/skills/` copies (since the loader copies verbatim). Agents using team skills will construct broken file references when loading context.

**Root cause**: These paths were written when files lived in a different location and were never updated after the core extension restructuring in task 465.

---

### Finding 2 (HIGH SEVERITY): 3 Root-Level Context Files Not Deployed

The core extension has three files at `extensions/core/context/` root level that the loader silently skips:

| File | Index Status | Source Exists | Deployed |
|------|-------------|---------------|----------|
| `README.md` | `always: true` (loads every session) | Yes | **NO** |
| `routing.md` | loads for `meta` task type | Yes | **NO** |
| `validation.md` | loads for `meta` task type | Yes | **NO** |

**Root cause**: The loader's `copy_context_dirs()` function (loader.lua line 202) only copies entries where `vim.fn.isdirectory(source_ctx_dir) == 1`. Individual files at the context root are silently skipped because the check uses `isdirectory`, not `filereadable`. The core manifest's `provides.context` only lists subdirectory names, so root files have no deployment path.

**Impact**: `README.md` is marked `always: true` in `index.json`, meaning every agent session attempts to read a file that does not exist. This could cause silent failures in context loading.

---

### Finding 3 (MEDIUM SEVERITY): Stale Entry in context/index.json

The deployed `context/index.json` contains one entry pointing to a file that does not exist anywhere:

```json
{
  "path": "orchestration/routing.md",
  "domain": "core",
  "summary": "Task routing by language and type",
  "load_when": {"task_types": ["meta"], "agents": ["meta-builder-agent"], "commands": []}
}
```

The file `extensions/core/context/orchestration/routing.md` does **not** exist. The `orchestration/` directory contains `validation.md`, `architecture.md`, and others, but no `routing.md`. This is a stale index entry pointing to a file that was either renamed or never created.

**Note**: This is distinct from Finding 2. The root-level `routing.md` exists but is not deployed. The `orchestration/routing.md` entry in the index references a file that doesn't exist at all.

---

### Finding 4 (MEDIUM SEVERITY): Two Scripts Missing Execute Permission

`setup-lean-mcp.sh` and `verify-lean-mcp.sh` are both:
- In the core extension manifest's `provides.scripts`
- Present in `extensions/core/scripts/` with shebangs (`#!/usr/bin/env bash`)
- **NOT executable** (permissions: `-rw-r--r--`) in both source and deployed locations

All other scripts in `extensions/core/scripts/` are executable (`-rwxr-xr-x`). The loader correctly preserves source permissions via `copy_file_permissions`. Since the source lacks `+x`, the deployed copies also lack `+x`.

These scripts are lean-MCP setup utilities included in the core extension (not in the lean extension), but they cannot be executed without `chmod +x`.

**Note**: The lean extension's `manifest.json` lists `"scripts": []` (empty), confirming it delegates lean MCP setup to the core extension. This seems architecturally odd.

---

### Finding 5 (MEDIUM SEVERITY): Core Extension Fails Official Validator

Running `.claude/scripts/check-extension-docs.sh` reports:

```
[core]
  FAIL: README.md missing (/home/benjamin/.config/nvim/.claude/extensions/core//README.md)
  FAIL: manifest declares 16 skill(s) but has no routing block
```

The core extension has no `README.md` and no `routing` block in `manifest.json`. Other extensions (nvim, nix, memory) have `routing` blocks declaring which skills to use for which task types. Core does not because its skills are generic defaults, but the validator still flags this.

This is a documentation debt from task 465 - the core extension was restructured as a "real extension" but was not given the documentation and routing metadata that other extensions have.

---

### Finding 6 (LOW SEVERITY): docs-README.md is a Confusing Artifact

`/home/benjamin/.config/nvim/.claude/docs/docs-README.md` (100 lines) coexists with `docs/README.md` (262 lines). The `docs-README.md` is the original extension source README that was renamed during the docs-flattening fix (commit `e914cfd7`). It is listed in the core manifest's `provides.docs` as `"docs-README.md"`.

There is no user-facing documentation explaining what `docs-README.md` is or that it should be ignored in favor of `README.md`. This will cause confusion for developers reading the docs directory.

---

## Stale References Found

| Location | Stale Reference | Correct Reference | Severity |
|----------|----------------|-------------------|----------|
| `.claude/skills/skill-team-plan/SKILL.md` (lines 9, 24) | `.claude/extensions/core/context/reference/team-wave-helpers.md` | `.claude/context/reference/team-wave-helpers.md` | HIGH |
| `.claude/skills/skill-team-research/SKILL.md` (lines 9, 26) | `.claude/extensions/core/context/reference/team-wave-helpers.md` | `.claude/context/reference/team-wave-helpers.md` | HIGH |
| `.claude/skills/skill-team-implement/SKILL.md` (lines 9, 24) | `.claude/extensions/core/context/reference/team-wave-helpers.md` | `.claude/context/reference/team-wave-helpers.md` | HIGH |
| `context/index.json` (deployed) | `orchestration/routing.md` | file does not exist | MEDIUM |
| `context/index.json` (deployed) | `README.md` (always-loaded) | not deployed | HIGH |
| `context/index.json` (deployed) | `routing.md` | not deployed | MEDIUM |
| `context/index.json` (deployed) | `validation.md` | not deployed | MEDIUM |

---

## Unfinished Work Detected

1. **Core extension README.md missing**: The core extension has no `extensions/core/README.md`. The validator explicitly fails on this. The task 465 implementation restructured core as a "real extension" but skipped the required documentation.

2. **Core extension routing block absent**: The manifest has no `routing` block. While this is architecturally defensible (core provides general routing, not domain-specific routing), the missing block causes validator failures. A note explaining why routing is absent would be appropriate.

3. **Lean MCP scripts in wrong extension**: `setup-lean-mcp.sh` and `verify-lean-mcp.sh` belong to lean tooling but are deployed from core. The lean extension has `"scripts": []`. Either the lean extension should own these scripts, or core should document why it includes lean-specific tools.

4. **Loader does not handle root-level context files**: The `copy_context_dirs()` function in loader.lua treats all `provides.context` entries as directory names. There is no path for deploying root-level context files (README.md, routing.md, validation.md). This is a loader architecture gap.

---

## Questions That Should Be Asked

1. **Are team skills broken in practice?** When an agent uses `skill-team-research` and follows the reference to `.claude/extensions/core/context/reference/team-wave-helpers.md`, does it fail silently or does it fall back to the correct path? Has this ever been tested post-task-465?

2. **Was `orchestration/routing.md` deliberately deleted?** The file is referenced in `core-index-entries.json` but does not exist. Was it deleted and the index entry not cleaned up, or was it never created?

3. **Should README.md, routing.md, validation.md be deployed from core?** These files exist in the source but aren't deployed due to the loader limitation. Were they meant to be deployed? If yes, the loader needs a fix. If no, they should be removed from `core-index-entries.json`.

4. **Is the loader's `copy_context_dirs()` limitation by design or oversight?** If extension developers are expected to only provide context as subdirectories (never as root files), this should be documented. Currently `core-index-entries.json` lists root-level paths, implying they should be deployed.

5. **Why does `docs-README.md` exist as a separate file?** Is this intentional as a "original README backup" or is it a leftover that should be removed or renamed?

6. **Is the core extension README.md requirement being tracked?** The official validator fails on this. If it's a known acceptable gap, the validator should be updated to exempt core (or explain the exception).

---

## Confidence Level

**High** for Findings 1, 2, 3, 4, 5 - each was directly confirmed by examining specific file contents, running the official validator, and checking file existence.

**Medium** for Finding 6 - the docs-README.md situation is confirmed as confusing but its intent requires clarification from the project owner.

---

## Investigation Methodology

1. Examined `git log --oneline -20` to understand what tasks 464, 465, 467 changed
2. Searched all deployed `.claude/` files for `extensions/core/` path references
3. Validated all 134 entries in `context/index.json` against actual file system
4. Checked all scripts in `extensions/core/scripts/` for execute permissions
5. Ran official `.claude/scripts/check-extension-docs.sh` validator
6. Read loader source (`loader.lua`) to understand deployment mechanism
7. Cross-referenced `core-index-entries.json` against deployed files and source files
